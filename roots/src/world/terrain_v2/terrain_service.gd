extends Node
## TerrainService — VoxelLodTerrain facade that replaces the old heightmap
## ChunkManager.  Wraps VoxelLodTerrain + WorldNoise with the same public API
## that main_world.gd, player_controller.gd, base_animal.gd, town_builder.gd
## and friends expect.
##
## The old system used per-chunk heightmap + manual mesh building.  Now
## VoxelLodTerrain handles streaming, meshing, and collision natively.
## This node owns the VoxelLodTerrain, creates a VoxelViewer that follows
## the player, and answers CPU-side height/biome queries via WorldNoise.

signal chunk_loaded(chunk_pos: Vector2i)
signal chunk_unloaded(chunk_pos: Vector2i)
signal chunk_mesh_updated(chunk_pos: Vector2i)

@export var view_distance: int = 6
@export var chunk_size: int = 32
@export var generate_objects: bool = true
@export var save_chunks: bool = true

var terrain_container: Node3D:
	set(value):
		pass  # VoxelLodTerrain manages its own meshes
	get:
		return null

var player_node: Node3D
var chunk_save_dir: String = "":
	set(value):
		pass  # VoxelStreamSQLite handles persistence
	get:
		return ""

var world_noise: WorldNoise
var voxel_terrain: VoxelLodTerrain
var voxel_stream: VoxelStreamSQLite
var _world_seed: int = 0

# Exclusion zones forwarded to WorldNoise for flattening
var exclusion_zones: Array[Dictionary] = []

# ── Farm plot overlay (tilling, no voxel edit) ────────────────────────────
const FarmPlotScene = preload("res://src/world/crops/farm_plot.tscn")
var dynamic_farm_plots: Dictionary = {}

# Tracked dug positions for idempotency
var _dug_positions: Dictionary = {}

# Virtual-chunk polling for chunk_loaded/chunk_unloaded signals.
# VoxelLodTerrain does not emit per-block signals, so we poll the viewer
# position and emit signals when the set of visible "virtual 32m regions"
# changes (matching the old chunk_manager's 32m chunk convention).
var _active_virtual_chunks: Dictionary = {}  # Vector2i -> true
const VIRTUAL_CHUNK_SIZE: int = 32
var _last_viewer_vc: Vector2i = Vector2i(-9999, -9999)
var _initial_load_done: bool = false

# Viewer
var _viewer: VoxelViewer = null


func _ready() -> void:
	world_noise = WorldNoise.new()
	var game_manager: Node = get_node_or_null("/root/GameManager")
	_world_seed = game_manager.world_seed if game_manager else 0
	world_noise.setup(_world_seed)

	# VoxelStreamSQLite: persistent save of modified blocks (e.g. digging).
	# Set before VoxelLodTerrain so blocks loaded from disk take priority
	# over the generator.
	voxel_stream = VoxelStreamSQLite.new()
	var save_dir := "user://saves/world_%d/" % _world_seed
	DirAccess.make_dir_recursive_absolute(save_dir)
	voxel_stream.set_database_path(save_dir + "voxels.sqlite")
	voxel_stream.set_save_generator_output(false)

	# Create VoxelLodTerrain AFTER the generator is ready — if it enters
	# the tree without a generator, already-loaded blocks will never
	# re-generate when we set one later.
	voxel_terrain = VoxelLodTerrain.new()
	voxel_terrain.name = "VoxelLodTerrain"
	_configure_voxel_terrain()
	add_child(voxel_terrain)

	# Create VoxelViewer (tracks the player camera automatically)
	_viewer = VoxelViewer.new()
	_viewer.name = "VoxelViewer"
	_viewer.view_distance = view_distance * VIRTUAL_CHUNK_SIZE
	_viewer.requires_visuals = true
	_viewer.requires_collisions = true
	# Viewer must be a child of VoxelLodTerrain to trigger block generation
	voxel_terrain.add_child(_viewer)


func _configure_voxel_terrain() -> void:
	voxel_terrain.mesher = VoxelMesherTransvoxel.new()
	voxel_terrain.generator = world_noise.build_generator()
	voxel_terrain.material = _make_terrain_material()
	voxel_terrain.stream = voxel_stream
	voxel_terrain.generate_collisions = true
	voxel_terrain.lod_count = 6
	voxel_terrain.view_distance = 512
	voxel_terrain.mesh_block_size = 16


func _make_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/terrain_v2/terrain_v2.gdshader")
	return mat


func _process(delta: float) -> void:
	if not player_node:
		player_node = get_tree().get_first_node_in_group("player")
		return

	# Keep the viewer on the player
	_viewer.global_position = player_node.global_position

	# Poll virtual chunks for wildlife-spawning signals
	_poll_virtual_chunks()


func _exit_tree() -> void:
	if voxel_terrain:
		voxel_terrain.save_modified_blocks()


func _poll_virtual_chunks() -> void:
	if not player_node:
		return
	var vc := Vector2i(
		int(floori(player_node.global_position.x / VIRTUAL_CHUNK_SIZE)),
		int(floori(player_node.global_position.z / VIRTUAL_CHUNK_SIZE))
	)
	if vc == _last_viewer_vc:
		return
	_last_viewer_vc = vc

	var radius := view_distance + 2
	var now_visible: Dictionary = {}
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			now_visible[vc + Vector2i(dx, dz)] = true

	# Emit loaded for new virtual chunks
	for k in now_visible:
		if not _active_virtual_chunks.has(k):
			_active_virtual_chunks[k] = true
			chunk_loaded.emit(k)

	# Emit unloaded for gone virtual chunks
	var to_remove: Array[Vector2i] = []
	for k in _active_virtual_chunks:
		if not now_visible.has(k):
			to_remove.append(k)
	for k in to_remove:
		_active_virtual_chunks.erase(k)
		chunk_unloaded.emit(k)

	if not _initial_load_done and _active_virtual_chunks.size() > 0:
		_initial_load_done = true


# ============================================================================
# Public API (matches old ChunkManager)
# ============================================================================

func get_terrain_height(world_pos: Vector3) -> float:
	## Returns the terrain height at any world XZ using WorldNoise (CPU).
	return world_noise.get_height(world_pos.x, world_pos.z)


func get_biome_at(world_pos: Vector3) -> int:
	## Returns biome type at a world position, or -1 if unavailable.
	return world_noise.get_biome(world_pos.x, world_pos.z)


func get_water_level() -> float:
	## Returns the global sea level.
	return 0.0


func get_chunk_at_position(world_pos: Vector3):
	## Compat stub — returns null (no ChunkData in voxel system).
	return null


func set_view_distance(new_distance: int) -> void:
	view_distance = maxi(1, new_distance)


func force_update() -> void:
	pass


func clear_all_chunks() -> void:
	_active_virtual_chunks.clear()
	_last_viewer_vc = Vector2i(-9999, -9999)
	_initial_load_done = false
	# VoxelLodTerrain manages its own memory


func is_in_any_claim_zone(world_pos: Vector3) -> bool:
	## Returns true if world_pos falls within any established claim zone.
	var main_world = get_node_or_null("/root/MainWorld")
	if not main_world:
		return false
	for child in main_world.get_children():
		if child.has_meta("claim_radius"):
			var center = child.global_position
			var radius = child.get_meta("claim_radius", 8.0)
			if world_pos.distance_to(center) <= radius:
				return true
	return false


# ── Exclusion zones ────────────────────────────────────────────────────

func add_exclusion_zone(center: Vector3, radius: float) -> void:
	var flat_h = world_noise.get_height(center.x, center.z)
	exclusion_zones.append({"center": center, "radius": radius, "flat_height": flat_h})
	# Flatten zone disabled: the Voxel generator cannot apply it yet
	# (graph-based SDF flattening is unstable, deferred to Phase 5).
	# Without it the actual terrain mesh stays at raw height while CPU
	# queries return the flattened height, causing buildings to float or
	# sink.  Until both paths match, keep the raw terrain and let
	# buildings conform to the natural slope.


func is_in_exclusion_zone(world_x: float, world_z: float) -> bool:
	for zone in exclusion_zones:
		var c: Vector3 = zone["center"]
		var r: float = zone["radius"]
		var dx = world_x - c.x
		var dz = world_z - c.z
		if dx * dx + dz * dz < r * r:
			return true
	return false


# ── Terrain modification (tilling / digging) ───────────────────────────

func modify_terrain_at(world_pos: Vector3, mod_type: int) -> bool:
	## Called by hoe swing.  Spawns a FarmPlot overlay at the tilled
	## position.  Returns false if the cell is water, beach, or obstructed.
	if mod_type != 1:  # TileMod.TILLED
		return false

	# Reject water
	var biome := world_noise.get_biome(world_pos.x, world_pos.z)
	if biome == 0 or biome == 1:
		return false

	# Reject if already tilled here
	var key := "%d,%d" % [int(floorf(world_pos.x)), int(floorf(world_pos.z))]
	if dynamic_farm_plots.has(key):
		return false

	var terrain_h := world_noise.get_height(world_pos.x, world_pos.z)
	var cell_world := Vector3(
		int(floorf(world_pos.x)) + 0.5,
		terrain_h + 0.05,
		int(floorf(world_pos.z)) + 0.5
	)
	_spawn_farm_plot_at(cell_world)
	return true


func dig_terrain_at(world_pos: Vector3) -> bool:
	## Called by shovel swing.  Uses VoxelTool.do_sphere() for persistent
	## SDF deformation.
	var key := "%d,%d" % [int(floorf(world_pos.x)), int(floorf(world_pos.z))]
	if _dug_positions.has(key):
		return false

	var biome := world_noise.get_biome(world_pos.x, world_pos.z)
	if biome == 0 or biome == 1:
		return false

	if not voxel_terrain or not is_instance_valid(voxel_terrain):
		return false

	var tool := voxel_terrain.get_voxel_tool()
	if not tool:
		return false

	var dig_y := world_noise.get_height(world_pos.x, world_pos.z)
	tool.mode = 1  # MODE_REMOVE
	tool.do_sphere(Vector3(world_pos.x, dig_y, world_pos.z), 2.5)
	if voxel_terrain:
		voxel_terrain.save_modified_blocks()
	_dug_positions[key] = true
	return true


func get_tile_mod_at(world_pos: Vector3) -> int:
	## Returns the tile modification type at a world position.
	## 0 = NONE, 1 = TILLED (has farm plot), 2 = DUG
	var key := "%d,%d" % [int(floorf(world_pos.x)), int(floorf(world_pos.z))]
	if dynamic_farm_plots.has(key):
		return 1  # TILLED
	if _dug_positions.has(key):
		return 2  # DUG
	return 0  # NONE


# ── Farm plots (tilling overlay) ───────────────────────────────────────

func _spawn_farm_plot_at(world_pos: Vector3) -> void:
	var key := "%d,%d" % [int(floorf(world_pos.x)), int(floorf(world_pos.z))]
	if dynamic_farm_plots.has(key):
		return

	var plot = FarmPlotScene.instantiate()
	plot.global_position = world_pos
	plot.state = 1  # PlotState.TILLED

	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(plot)
		dynamic_farm_plots[key] = plot


func remove_farm_plot_at(world_pos: Vector3) -> void:
	var key := "%d,%d" % [int(floorf(world_pos.x)), int(floorf(world_pos.z))]
	if dynamic_farm_plots.has(key):
		var plot = dynamic_farm_plots[key]
		if is_instance_valid(plot):
			plot.queue_free()
		dynamic_farm_plots.erase(key)


func restore_tilled_plots_for_chunk(chunk_pos: Vector2i) -> void:
	## Compat stub: farm plots are persistent overlays now.
	pass


# ── Diagnostics ────────────────────────────────────────────────────────

func get_chunk_manager() -> Node:
	return self
