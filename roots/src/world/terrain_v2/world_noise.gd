class_name WorldNoise
extends RefCounted
## Terrain v2 noise stack. Single source of truth for the world's shape:
## builds the VoxelGeneratorGraph used by VoxelLodTerrain and mirrors the
## same math on the CPU for gameplay queries (heights, biomes).

const SEA_LEVEL: float = 0.0
const RIVER_BED: float = -3.0

const BIOME_WATER: int = 0
const BIOME_BEACH: int = 1
const BIOME_PLAINS: int = 2
const BIOME_FOREST: int = 3
const BIOME_JUNGLE: int = 4
const BIOME_TAIGA: int = 5
const BIOME_MOUNTAINS: int = 6
const BIOME_SNOW: int = 7
const BIOME_MEADOW: int = 8
const BIOME_HIGHLAND: int = 9

var continent_noise: FastNoiseLite
var hills_noise: FastNoiseLite
var mountain_noise: FastNoiseLite
var mountain_mask_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var river_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite

# Flatten zones (e.g. village): { "center": Vector3, "radius": float, "flat_height": float }
var flatten_zones: Array[Dictionary] = []


func setup(world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	continent_noise = _make_noise(rng.randi(), 0.0009, 3)
	hills_noise = _make_noise(rng.randi(), 0.004, 4, FastNoiseLite.FRACTAL_FBM, 0.45)
	mountain_noise = _make_noise(rng.randi(), 0.0025, 4, FastNoiseLite.FRACTAL_RIDGED)
	mountain_mask_noise = _make_noise(rng.randi(), 0.0012, 2)
	detail_noise = _make_noise(rng.randi(), 0.03, 2)
	river_noise = _make_noise(rng.randi(), 0.0018, 2)
	moisture_noise = _make_noise(rng.randi(), 0.0035, 3)
	temperature_noise = _make_noise(rng.randi(), 0.003, 3)


func _make_noise(noise_seed: int, frequency: float, octaves: int,
		fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_FBM, gain: float = 0.5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_type = fractal_type
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = gain
	return n


func add_flatten_zone(center: Vector3, radius: float) -> void:
	var flat_h := _get_height_raw(center.x, center.z)
	flatten_zones.append({"center": center, "radius": radius, "flat_height": flat_h})


func get_height(x: float, z: float) -> float:
	var h := _get_height_raw(x, z)
	for zone in flatten_zones:
		var c: Vector3 = zone["center"]
		var r: float = zone["radius"]
		var dist := Vector2(x - c.x, z - c.z).length()
		var t := smoothstep(r * 0.7, r * 1.3, dist)
		h = lerpf(zone["flat_height"], h, t)
	return h


func _get_height_raw(x: float, z: float) -> float:
	var c := continent_noise.get_noise_2d(x, z)
	var hl := hills_noise.get_noise_2d(x, z)
	var m := mountain_noise.get_noise_2d(x, z)
	var mm := mountain_mask_noise.get_noise_2d(x, z)
	var d := detail_noise.get_noise_2d(x, z)
	var r := river_noise.get_noise_2d(x, z)

	var base := c * 18.0 + 6.0
	var land := clampf(base / 8.0, 0.0, 1.0)
	var mmask := smoothstep(0.1, 0.45, mm)
	var ridge := (1.0 - absf(m)) * (1.0 - absf(m))
	var rch := absf(r)
	var valley := 1.0 - smoothstep(0.03, 0.18, rch)
	var h_pre := base + hl * 10.0 * land + ridge * 55.0 * mmask * land \
			+ d * 1.5 - valley * 6.0 * land * (1.0 - mmask)
	var rf := (1.0 - smoothstep(0.025, 0.06, rch)) * land * (1.0 - mmask * 0.85)
	return lerpf(h_pre, minf(h_pre, RIVER_BED), rf)


func get_moisture(x: float, z: float) -> float:
	return (moisture_noise.get_noise_2d(x, z) + 1.0) * 0.5


func get_temperature(x: float, z: float) -> float:
	return (temperature_noise.get_noise_2d(x, z) + 1.0) * 0.5


func get_biome(x: float, z: float) -> int:
	var h := get_height(x, z)
	if h < SEA_LEVEL + 0.3:
		return BIOME_WATER
	if h < SEA_LEVEL + 2.0:
		return BIOME_BEACH
	var moisture := get_moisture(x, z)
	var temperature := get_temperature(x, z)
	if h < 18.0:
		if moisture < 0.25:
			return BIOME_PLAINS
		elif moisture < 0.45:
			return BIOME_MEADOW if temperature > 0.55 else BIOME_PLAINS
		elif moisture < 0.65:
			return BIOME_FOREST
		return BIOME_JUNGLE
	if h < 32.0:
		if temperature < 0.35:
			return BIOME_TAIGA
		return BIOME_FOREST if moisture > 0.5 else BIOME_HIGHLAND
	if h < 48.0:
		return BIOME_TAIGA if temperature < 0.35 else BIOME_MOUNTAINS
	return BIOME_SNOW


# ── Compatibility API (matches old NoiseUtilities surface) ─────────────────

func get_terrain_height(x: float, z: float) -> float:
	return get_height(x, z)


func get_biome_type(x: float, z: float) -> int:
	return get_biome(x, z)


func get_water_level() -> float:
	return SEA_LEVEL


func get_tree_density(x: float, z: float) -> float:
	var biome := get_biome(x, z)
	var moisture := get_moisture(x, z)
	match biome:
		BIOME_FOREST:
			return moisture * 0.6 + 0.15
		BIOME_JUNGLE:
			return moisture * 0.5 + 0.25
		BIOME_TAIGA:
			return 0.35 + moisture * 0.2
		BIOME_MEADOW:
			return 0.08
		BIOME_HIGHLAND:
			return 0.05
		BIOME_PLAINS:
			return 0.03
		BIOME_MOUNTAINS:
			return 0.02
		_:
			return 0.0


func get_rock_density(x: float, z: float) -> float:
	var biome := get_biome(x, z)
	var e := clampf(get_height(x, z) / 60.0, 0.0, 1.0)
	match biome:
		BIOME_MOUNTAINS:
			return 0.4 + e * 0.3
		BIOME_SNOW:
			return 0.5 + e * 0.2
		BIOME_HIGHLAND:
			return 0.2 + e * 0.15
		BIOME_TAIGA:
			return 0.15
		BIOME_BEACH:
			return 0.2
		_:
			return 0.0


func get_grass_color(x: float, z: float) -> Color:
	var moisture := get_moisture(x, z)
	var temperature := get_temperature(x, z)
	var base_green := Color(0.3, 0.6, 0.2)
	var dry_green := Color(0.6, 0.55, 0.3)
	var cold_green := Color(0.35, 0.45, 0.35)
	var color := base_green.lerp(dry_green, 1.0 - moisture)
	return color.lerp(cold_green, 1.0 - temperature)


func build_generator() -> VoxelGeneratorGraph:
	var gen := VoxelGeneratorGraph.new()
	var g := gen.get_main_function()
	g.clear()

	var n_x := g.create_node(VoxelGraphFunction.NODE_INPUT_X, Vector2(0, 0))
	var n_y := g.create_node(VoxelGraphFunction.NODE_INPUT_Y, Vector2(0, 100))
	var n_z := g.create_node(VoxelGraphFunction.NODE_INPUT_Z, Vector2(0, 200))

	var n_c := _add_noise_node(g, continent_noise, Vector2(200, 0))
	var n_hl := _add_noise_node(g, hills_noise, Vector2(200, 100))
	var n_m := _add_noise_node(g, mountain_noise, Vector2(200, 200))
	var n_mm := _add_noise_node(g, mountain_mask_noise, Vector2(200, 300))
	var n_d := _add_noise_node(g, detail_noise, Vector2(200, 400))
	var n_r := _add_noise_node(g, river_noise, Vector2(200, 500))
	for n in [n_c, n_hl, n_m, n_mm, n_d, n_r]:
		g.add_connection(n_x, 0, n, 0)
		g.add_connection(n_z, 0, n, 1)

	var n_absr := g.create_node(VoxelGraphFunction.NODE_ABS, Vector2(400, 500))
	g.add_connection(n_r, 0, n_absr, 0)

	var n_mmask := g.create_node(VoxelGraphFunction.NODE_SMOOTHSTEP, Vector2(400, 300))
	g.set_node_param(n_mmask, 0, 0.1)
	g.set_node_param(n_mmask, 1, 0.45)
	g.add_connection(n_mm, 0, n_mmask, 0)

	var n_vs := g.create_node(VoxelGraphFunction.NODE_SMOOTHSTEP, Vector2(500, 450))
	g.set_node_param(n_vs, 0, 0.03)
	g.set_node_param(n_vs, 1, 0.18)
	g.add_connection(n_absr, 0, n_vs, 0)

	var n_rfs := g.create_node(VoxelGraphFunction.NODE_SMOOTHSTEP, Vector2(500, 550))
	g.set_node_param(n_rfs, 0, 0.025)
	g.set_node_param(n_rfs, 1, 0.06)
	g.add_connection(n_absr, 0, n_rfs, 0)

	var n_hpre := g.create_node(VoxelGraphFunction.NODE_EXPRESSION, Vector2(700, 100))
	g.set_node_param(n_hpre, 0,
		"c*18.0 + 6.0"
		+ " + hl*10.0*clamp((c*18.0+6.0)/8.0, 0.0, 1.0)"
		+ " + (1.0-abs(m))*(1.0-abs(m))*55.0*mmask*clamp((c*18.0+6.0)/8.0, 0.0, 1.0)"
		+ " + d*1.5"
		+ " - (1.0-vs)*6.0*clamp((c*18.0+6.0)/8.0, 0.0, 1.0)*(1.0-mmask)")
	g.set_expression_node_inputs(n_hpre, PackedStringArray(["c", "hl", "m", "mmask", "d", "vs"]))
	g.add_connection(n_c, 0, n_hpre, g.get_node_input_index(n_hpre, "c"))
	g.add_connection(n_hl, 0, n_hpre, g.get_node_input_index(n_hpre, "hl"))
	g.add_connection(n_m, 0, n_hpre, g.get_node_input_index(n_hpre, "m"))
	g.add_connection(n_mmask, 0, n_hpre, g.get_node_input_index(n_hpre, "mmask"))
	g.add_connection(n_d, 0, n_hpre, g.get_node_input_index(n_hpre, "d"))
	g.add_connection(n_vs, 0, n_hpre, g.get_node_input_index(n_hpre, "vs"))

	var n_h := g.create_node(VoxelGraphFunction.NODE_EXPRESSION, Vector2(900, 100))
	g.set_node_param(n_h, 0,
		"lerp(hpre, min(hpre, 0.0 - 3.0),"
		+ " (1.0-rfs)"
		+ " * clamp((c*18.0+6.0)/8.0, 0.0, 1.0)"
		+ " * (1.0-mmask*0.85))")
	g.set_expression_node_inputs(n_h, PackedStringArray(["hpre", "rfs", "c", "mmask"]))
	g.add_connection(n_hpre, 0, n_h, g.get_node_input_index(n_h, "hpre"))
	g.add_connection(n_rfs, 0, n_h, g.get_node_input_index(n_h, "rfs"))
	g.add_connection(n_c, 0, n_h, g.get_node_input_index(n_h, "c"))
	g.add_connection(n_mmask, 0, n_h, g.get_node_input_index(n_h, "mmask"))

	var n_height := n_h
	# Flatten zones deferred to Phase 5 (graph-based SDF flattening is unstable).
	# CPU-side get_height() still applies flatten zones for gameplay queries.

	var n_sdf := g.create_node(VoxelGraphFunction.NODE_SUBTRACT, Vector2(1200, 100))
	g.add_connection(n_y, 0, n_sdf, 0)
	g.add_connection(n_height, 0, n_sdf, 1)

	var n_out := g.create_node(VoxelGraphFunction.NODE_OUTPUT_SDF, Vector2(1100, 100))
	g.add_connection(n_sdf, 0, n_out, 0)

	var result: Dictionary = gen.compile()
	if not result.get("success", false):
		push_error("WorldNoise: generator graph compile failed: %s (node %s)" % [
			result.get("message", "?"), result.get("node_id", -1)])
	return gen


func _add_noise_node(g: VoxelGraphFunction, noise: FastNoiseLite, pos: Vector2) -> int:
	var id := g.create_node(VoxelGraphFunction.NODE_NOISE_2D, pos)
	g.set_node_param(id, 0, noise)
	return id
