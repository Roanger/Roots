extends Node
## Noise utilities for procedural generation using simplex noise

# Singleton reference for random number generation
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Pre-generated noise seeds for different terrain features
var elevation_seed: int = 0
var moisture_seed: int = 0
var temperature_seed: int = 0
var detail_seed: int = 0
var continent_seed: int = 0
var cave_seed: int = 0
var ore_seed: int = 0

# Cached noise generators for better performance
var elevation_noise: FastNoiseLite = null
var detail_noise: FastNoiseLite = null
var moisture_noise: FastNoiseLite = null
var temperature_noise: FastNoiseLite = null
var continent_noise: FastNoiseLite = null
var cave_noise: FastNoiseLite = null
var ore_noise: FastNoiseLite = null

# Underground layer depth constants (Y world units, surface ~5-65)
const UNDERGROUND_TOP: float = 0.0       # Top of dirt layer (below min surface)
const DIRT_BOTTOM: float = -15.0         # Dirt → Stone transition
const STONE_BOTTOM: float = -45.0        # Stone → Deep Rock transition
const DEEP_BOTTOM: float = -80.0         # Floor of the world

# Cave thresholds per layer (higher = more open caves)
const CAVE_THRESHOLD_DIRT: float = 0.62
const CAVE_THRESHOLD_STONE: float = 0.58
const CAVE_THRESHOLD_DEEP: float = 0.55

func _ready() -> void:
	_generate_seeds()

func _generate_seeds() -> void:
	elevation_seed = randi()
	moisture_seed = randi()
	temperature_seed = randi()
	detail_seed = randi()
	continent_seed = randi()
	cave_seed = randi()
	ore_seed = randi()

func set_seed_from_world(world_seed: int) -> void:
	rng.seed = world_seed
	elevation_seed = rng.randi()
	moisture_seed = rng.randi()
	temperature_seed = rng.randi()
	detail_seed = rng.randi()
	continent_seed = rng.randi()
	cave_seed = rng.randi()
	ore_seed = rng.randi()
	
	# Initialize noise generators
	_init_noise_generators()

func _init_noise_generators() -> void:
	# Continent noise - very low frequency for large-scale landmass variation
	continent_noise = FastNoiseLite.new()
	continent_noise.seed = continent_seed
	continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continent_noise.frequency = 0.0015  # Very large features
	continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	continent_noise.fractal_octaves = 2
	continent_noise.fractal_lacunarity = 2.0
	continent_noise.fractal_gain = 0.5
	
	# Elevation noise - medium frequency for hills and mountains
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = elevation_seed
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = 0.004
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation_noise.fractal_octaves = 4  # More octaves for varied terrain
	elevation_noise.fractal_lacunarity = 2.0
	elevation_noise.fractal_gain = 0.45
	
	# Detail noise - higher frequency for small terrain variation
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = detail_seed
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.05
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_lacunarity = 2.0
	detail_noise.fractal_gain = 0.5
	
	# Moisture noise - cached to avoid per-call allocation
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = moisture_seed
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.025
	moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = 3
	moisture_noise.fractal_lacunarity = 2.0
	moisture_noise.fractal_gain = 0.5
	
	# Temperature noise - cached to avoid per-call allocation
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = temperature_seed
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temperature_noise.frequency = 0.03
	temperature_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	temperature_noise.fractal_octaves = 3
	temperature_noise.fractal_lacunarity = 2.0
	temperature_noise.fractal_gain = 0.5
	
	# Cave noise - 3D, medium frequency for organic tunnel networks
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = cave_seed
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_noise.frequency = 0.035
	cave_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	cave_noise.fractal_octaves = 2  # Reduced from 3 — halves cave sampling cost
	cave_noise.fractal_lacunarity = 2.0
	cave_noise.fractal_gain = 0.5
	
	# Ore noise - 3D, higher frequency for tight vein clusters
	ore_noise = FastNoiseLite.new()
	ore_noise.seed = ore_seed
	ore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ore_noise.frequency = 0.08
	ore_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	ore_noise.fractal_octaves = 2
	ore_noise.fractal_lacunarity = 2.0
	ore_noise.fractal_gain = 0.5

func get_elevation(x: float, z: float) -> float:
	"""Get terrain elevation at world coordinates using multi-octave noise"""
	if elevation_noise == null:
		_init_noise_generators()
	
	# Continent-scale variation: determines if area is lowland or highland
	var continent = (continent_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	# Local elevation variation
	var local = (elevation_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	# Blend: continent shapes the overall landscape, local adds hills/valleys
	# Continent weight 0.55 means large regions trend high or low
	var combined = continent * 0.55 + local * 0.45
	
	# Redistribution curve: flattens lowlands, creates steeper mountains
	# S-curve: pushes mid-values apart, making plains flatter and peaks sharper
	var e = combined
	if e < 0.4:
		# Lowlands: flatten out (more plains/valleys)
		e = e * 0.8
	elif e < 0.6:
		# Midlands: gentle transition
		e = 0.32 + (e - 0.4) * 1.4
	else:
		# Highlands: steepen for dramatic mountains
		e = 0.60 + (e - 0.6) * 2.0
	
	return clampf(e, 0.0, 1.0)

func get_moisture(x: float, z: float) -> float:
	## Get moisture level at world coordinates (0.0 = dry, 1.0 = wet)
	if moisture_noise == null:
		_init_noise_generators()
	var value = moisture_noise.get_noise_2d(x, z)
	return (value + 1.0) / 2.0

func get_temperature(x: float, z: float) -> float:
	## Get temperature at world coordinates (0.0 = cold, 1.0 = hot)
	if temperature_noise == null:
		_init_noise_generators()
	var value = temperature_noise.get_noise_2d(x, z)
	return (value + 1.0) / 2.0

func get_detail(x: float, z: float) -> float:
	"""Get detail noise for terrain variation"""
	if detail_noise == null:
		_init_noise_generators()
	
	var value = detail_noise.get_noise_2d(x, z)
	return (value + 1.0) / 2.0 * 0.3  # Reduced amplitude for detail

# NOTE: _get_noise_2d kept for any future callers but moisture/temperature now use cached noise
func _get_noise_2d(x: float, z: float, noise_seed: int, scale: float, amplitude: float) -> float:
	## Generate 2D noise value using simplex-like algorithm
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	
	var value = noise.get_noise_2d(x, z)
	# Normalize from [-1, 1] to [0, 1]
	return (value + 1.0) / 2.0 * amplitude

# Biome IDs:
# 0 = Water, 1 = Beach, 2 = Plains, 3 = Forest, 4 = Jungle/Swamp,
# 5 = Taiga, 6 = Mountains, 7 = Snow, 8 = Meadow, 9 = Highland

func get_biome_type(x: float, z: float) -> int:
	"""Determine biome type based on elevation, moisture, and temperature"""
	var elevation = get_elevation(x, z)
	var moisture = get_moisture(x, z)
	var temperature = get_temperature(x, z)
	
	# Deep water / lakes
	if elevation < 0.22:
		return 0  # Water
	# Shoreline
	elif elevation < 0.27:
		return 1  # Beach/Coast
	# Lowlands (plains, meadow, forest, jungle)
	elif elevation < 0.50:
		if moisture < 0.25:
			return 2  # Plains (dry grassland)
		elif moisture < 0.45:
			if temperature > 0.55:
				return 8  # Meadow (warm, moderate moisture - flowers)
			else:
				return 2  # Plains (cool, dry)
		elif moisture < 0.65:
			return 3  # Forest
		else:
			return 4  # Jungle / Swamp (wet)
	# Midlands (forest, taiga, highland)
	elif elevation < 0.65:
		if temperature < 0.35:
			return 5  # Taiga (cold mid-elevation)
		elif moisture > 0.5:
			return 3  # Forest (moist mid-elevation)
		else:
			return 9  # Highland (dry, warm mid-elevation - rocky grassland)
	# Mountains
	elif elevation < 0.82:
		if temperature < 0.35:
			return 5  # Taiga (cold mountains with pines)
		else:
			return 6  # Mountains (rocky)
	# Peaks
	else:
		return 7  # Snow peaks

func get_terrain_height(x: float, z: float) -> float:
	"""Get final terrain height with varied terrain from valleys to mountains"""
	var base_height = get_elevation(x, z)
	
	# Wider height range: valleys at 5, mountains up to 65
	var min_height = 5.0
	var max_height = 65.0
	var height = min_height + base_height * (max_height - min_height)
	
	# Add detail variation scaled by elevation (more detail on mountains)
	var detail = get_detail(x, z)
	var detail_scale = lerp(0.3, 1.5, base_height)  # More rugged at higher elevations
	height += detail * detail_scale
	
	return height

func get_tree_density(x: float, z: float) -> float:
	"""Get tree density at position (0.0 = no trees, 1.0 = dense forest)"""
	var biome = get_biome_type(x, z)
	var moisture = get_moisture(x, z)
	match biome:
		3:  # Forest
			return moisture * 0.6 + 0.15
		4:  # Jungle/Swamp
			return moisture * 0.5 + 0.25
		5:  # Taiga (pine trees)
			return 0.35 + moisture * 0.2
		8:  # Meadow (scattered trees)
			return 0.08
		9:  # Highland (sparse trees)
			return 0.05
		2:  # Plains (occasional lone trees)
			return 0.03
		6:  # Mountains (very sparse, stunted)
			return 0.02
		_:
			return 0.0

func get_rock_density(x: float, z: float) -> float:
	"""Get rock/stone density at position"""
	var biome = get_biome_type(x, z)
	var elevation = get_elevation(x, z)
	match biome:
		6:  # Mountains
			return 0.4 + elevation * 0.3
		7:  # Snow peaks
			return 0.5 + elevation * 0.2
		9:  # Highland
			return 0.2 + elevation * 0.15
		5:  # Taiga
			return 0.15
		1:  # Beach (pebbles)
			return 0.2
		_:
			return 0.0

func get_grass_color(x: float, z: float) -> Color:
	"""Get grass color based on moisture and temperature"""
	var moisture = get_moisture(x, z)
	var temperature = get_temperature(x, z)
	
	var base_green = Color(0.3, 0.6, 0.2)
	var dry_green = Color(0.6, 0.55, 0.3)
	var cold_green = Color(0.35, 0.45, 0.35)
	
	var color = base_green.lerp(dry_green, 1.0 - moisture)
	color = color.lerp(cold_green, 1.0 - temperature)
	return color

func get_water_level() -> float:
	"""Get the water level for this world"""
	return 16.0  # Water level adjusted for new height range

func get_seeds() -> Dictionary:
	## Returns all noise seeds for creating thread-local copies.
	return {
		"elevation": elevation_seed, "detail": detail_seed,
		"moisture": moisture_seed, "temperature": temperature_seed,
		"continent": continent_seed, "cave": cave_seed, "ore": ore_seed
	}

func create_thread_local_copy() -> RefCounted:
	## Creates a thread-safe noise wrapper with the same seeds.
	## Returns a NoiseBundle (inner class) — call the same methods on it.
	var bundle = NoiseBundle.new()
	bundle.setup(elevation_seed, detail_seed, moisture_seed, temperature_seed,
		continent_seed, cave_seed, ore_seed)
	return bundle

class NoiseBundle extends RefCounted:
	var elevation_noise: FastNoiseLite
	var detail_noise: FastNoiseLite
	var moisture_noise: FastNoiseLite
	var temperature_noise: FastNoiseLite
	var continent_noise: FastNoiseLite
	var cave_noise: FastNoiseLite
	var ore_noise: FastNoiseLite

	const DIRT_BOTTOM: float = -15.0
	const STONE_BOTTOM: float = -45.0
	const CAVE_THRESHOLD_DIRT: float = 0.62
	const CAVE_THRESHOLD_STONE: float = 0.58
	const CAVE_THRESHOLD_DEEP: float = 0.55

	func setup(eseed:int, dseed:int, mseed:int, tseed:int, cseed:int, cavseed:int, oreseed:int) -> void:
		continent_noise = FastNoiseLite.new()
		continent_noise.seed = cseed
		continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		continent_noise.frequency = 0.0015
		continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		continent_noise.fractal_octaves = 2
		continent_noise.fractal_lacunarity = 2.0
		continent_noise.fractal_gain = 0.5

		elevation_noise = FastNoiseLite.new()
		elevation_noise.seed = eseed
		elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		elevation_noise.frequency = 0.004
		elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		elevation_noise.fractal_octaves = 4
		elevation_noise.fractal_lacunarity = 2.0
		elevation_noise.fractal_gain = 0.45

		detail_noise = FastNoiseLite.new()
		detail_noise.seed = dseed
		detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		detail_noise.frequency = 0.05
		detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		detail_noise.fractal_octaves = 2
		detail_noise.fractal_lacunarity = 2.0
		detail_noise.fractal_gain = 0.5

		moisture_noise = FastNoiseLite.new()
		moisture_noise.seed = mseed
		moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		moisture_noise.frequency = 0.025
		moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		moisture_noise.fractal_octaves = 3
		moisture_noise.fractal_lacunarity = 2.0
		moisture_noise.fractal_gain = 0.5

		temperature_noise = FastNoiseLite.new()
		temperature_noise.seed = tseed
		temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		temperature_noise.frequency = 0.03
		temperature_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		temperature_noise.fractal_octaves = 3
		temperature_noise.fractal_lacunarity = 2.0
		temperature_noise.fractal_gain = 0.5

		cave_noise = FastNoiseLite.new()
		cave_noise.seed = cavseed
		cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		cave_noise.frequency = 0.035
		cave_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		cave_noise.fractal_octaves = 2
		cave_noise.fractal_lacunarity = 2.0
		cave_noise.fractal_gain = 0.5

		ore_noise = FastNoiseLite.new()
		ore_noise.seed = oreseed
		ore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		ore_noise.frequency = 0.08
		ore_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		ore_noise.fractal_octaves = 2
		ore_noise.fractal_lacunarity = 2.0
		ore_noise.fractal_gain = 0.5

	func get_elevation(x: float, z: float) -> float:
		var continent = (continent_noise.get_noise_2d(x, z) + 1.0) / 2.0
		var local = (elevation_noise.get_noise_2d(x, z) + 1.0) / 2.0
		var combined = continent * 0.55 + local * 0.45
		var e = combined
		if e < 0.4:    e = e * 0.8
		elif e < 0.6:  e = 0.32 + (e - 0.4) * 1.4
		else:          e = 0.60 + (e - 0.6) * 2.0
		return clampf(e, 0.0, 1.0)

	func get_terrain_height(x: float, z: float) -> float:
		var base_height = get_elevation(x, z)
		var height = 5.0 + base_height * 60.0
		var detail = (detail_noise.get_noise_2d(x, z) + 1.0) / 2.0 * 0.3
		height += detail * lerp(0.3, 1.5, base_height)
		return height

	func get_biome_type(x: float, z: float) -> int:
		var elevation = get_elevation(x, z)
		var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
		var temperature = (temperature_noise.get_noise_2d(x, z) + 1.0) / 2.0
		if elevation < 0.22:   return 0
		elif elevation < 0.27: return 1
		elif elevation < 0.50:
			if moisture < 0.25:    return 2
			elif moisture < 0.45:  return 8 if temperature > 0.55 else 2
			elif moisture < 0.65:  return 3
			else:                  return 4
		elif elevation < 0.65:
			if temperature < 0.35: return 5
			elif moisture > 0.5:   return 3
			else:                  return 9
		elif elevation < 0.82:
			return 5 if temperature < 0.35 else 6
		else:                  return 7

	func get_cave_density(x: float, y: float, z: float) -> float:
		var large = (cave_noise.get_noise_3d(x, y * 0.5, z) + 1.0) / 2.0
		var detail_offset = (ore_noise.get_noise_3d(x * 2.0, y, z * 2.0) + 1.0) / 2.0 * 0.15
		return clampf(large + detail_offset, 0.0, 1.0)

	func is_cave_at(x: float, y: float, z: float) -> bool:
		var threshold: float
		if y >= DIRT_BOTTOM:        threshold = CAVE_THRESHOLD_DIRT
		elif y >= STONE_BOTTOM:     threshold = CAVE_THRESHOLD_STONE
		else:                       threshold = CAVE_THRESHOLD_DEEP
		return get_cave_density(x, y, z) > threshold

	func get_ore_type_at(x: float, y: float, z: float) -> String:
		var density = (ore_noise.get_noise_3d(x * 3.0, y * 2.0, z * 3.0) + 1.0) / 2.0
		if density < 0.72:
			return ""
		var selector = fmod(abs(x * 0.37 + z * 0.29), 1.0)
		if y >= DIRT_BOTTOM:
			return "coal" if selector < 0.55 else "copper_nugget"
		elif y >= STONE_BOTTOM:
			if selector < 0.40:    return "iron_nugget"
			elif selector < 0.70:  return "copper_nugget"
			else:                  return "coal"
		else:
			if selector < 0.35:    return "gold_nugget"
			elif selector < 0.65:  return "mythril_ore"
			else:                  return "iron_nugget"

func seed_changed() -> void:
	_generate_seeds()
	_init_noise_generators()

func _ensure_cave_noise() -> void:
	if cave_noise == null:
		_init_noise_generators()

func get_cave_density(x: float, y: float, z: float) -> float:
	## Returns 0.0-1.0 cave density at a 3D world point.
	## Values above the layer threshold = hollow (cave space).
	_ensure_cave_noise()
	# Two-frequency blend: large tunnels + small pockets
	var large = (cave_noise.get_noise_3d(x, y * 0.5, z) + 1.0) / 2.0
	# Warp the large noise slightly with a detail offset for organic shapes
	var detail_offset = (ore_noise.get_noise_3d(x * 2.0, y, z * 2.0) + 1.0) / 2.0 * 0.15
	return clampf(large + detail_offset, 0.0, 1.0)

func is_cave_at(x: float, y: float, z: float) -> bool:
	## Returns true if the given 3D world point is inside a cave.
	var depth = y
	var threshold: float
	if depth >= DIRT_BOTTOM:
		threshold = CAVE_THRESHOLD_DIRT
	elif depth >= STONE_BOTTOM:
		threshold = CAVE_THRESHOLD_STONE
	else:
		threshold = CAVE_THRESHOLD_DEEP
	return get_cave_density(x, y, z) > threshold

func get_ore_density(x: float, y: float, z: float) -> float:
	## Returns 0.0-1.0 ore vein density at a 3D world point.
	_ensure_cave_noise()
	var v = (ore_noise.get_noise_3d(x * 3.0, y * 2.0, z * 3.0) + 1.0) / 2.0
	return v

func get_ore_type_at(x: float, y: float, z: float) -> String:
	## Returns the ore item_id for the richest ore at this depth, or empty if none.
	var depth = y
	var density = get_ore_density(x, y, z)
	if density < 0.72:
		return ""
	# Ore type determined by depth + a secondary noise offset
	var selector = fmod(abs(x * 0.37 + z * 0.29), 1.0)
	if depth >= DIRT_BOTTOM:  # Dirt layer: coal + copper
		return "coal" if selector < 0.55 else "copper_nugget"
	elif depth >= STONE_BOTTOM:  # Stone layer: iron + copper + coal
		if selector < 0.40:
			return "iron_nugget"
		elif selector < 0.70:
			return "copper_nugget"
		else:
			return "coal"
	else:  # Deep layer: gold + mythril + iron
		if selector < 0.35:
			return "gold_nugget"
		elif selector < 0.65:
			return "mythril_ore"
		else:
			return "iron_nugget"
