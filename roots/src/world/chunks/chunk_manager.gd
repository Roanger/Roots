extends Node
## Manages chunk loading/unloading based on player position

const HarvestableResource = preload("res://src/world/harvestable_resource.gd")
const FishingSpot = preload("res://src/world/fishing_spot.gd")

signal chunk_loaded(chunk_pos: Vector2i)
signal chunk_unloaded(chunk_pos: Vector2i)
signal chunk_mesh_updated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var view_distance: int = 6  # Voxel chunks are expensive — keep this low
@export var generate_objects: bool = true
@export var save_chunks: bool = true

var chunk_save_dir: String = ""  # Set by main_world from world seed; e.g. "user://saves/world_<seed>/chunks/"

var loaded_chunks: Dictionary = {}  # Vector2i -> ChunkData
var chunk_cache: Dictionary = {}  # For pending chunk generation
var active_chunks: Dictionary = {}  # Currently visible chunks

var noise_util: Node = null
var player_node: Node3D = null
var terrain_container: Node3D = null

# World object scenes (FBX assets)
var _tree_scenes: Array[PackedScene] = []      # Live trees (Common, Twisted)
var _dead_tree_scenes: Array[PackedScene] = [] # Dead trees (biome-based)
var _pine_scenes: Array[PackedScene] = []      # Pine trees (Taiga, mountain)
var _rock_scenes: Array[PackedScene] = []
var _pebble_scenes: Array[PackedScene] = []    # Small pebbles (beach, mountain)
var _grass_texture: Texture2D = null
# KayKit Forest Nature Pack (bushes + 3D grass)
var _forest_grass_scenes: Array[PackedScene] = []
var _bush_scenes: Array[PackedScene] = []
# Biome-specific decoration scenes
var _flower_scenes: Array[PackedScene] = []    # Flowers (meadow, plains)
var _fern_scenes: Array[PackedScene] = []      # Ferns (forest, jungle)
var _mushroom_scenes: Array[PackedScene] = []  # Mushrooms (forest floor)
var _clover_scenes: Array[PackedScene] = []    # Clovers (plains ground cover)
var _bush_common_scenes: Array[PackedScene] = [] # Common bushes (plains variety)

# Explicit reference to autoload
@onready var game_manager: Node = get_node_or_null("/root/GameManager")

# Update timing
var update_interval: float = 0.1
var last_update_time: float = 0.0
var is_updating: bool = false

# Town exclusion zones: Array of { "center": Vector3, "radius": float, "flat_height": float }
# Positions inside a zone get flattened terrain and no trees/rocks/grass/decorations
var exclusion_zones: Array[Dictionary] = []

# Multithreading
var mutex: Mutex = Mutex.new()
var generation_queue: Array[Vector2i] = []
var pending_chunks: Dictionary = {}  # Vector2i -> true (queued or in-flight)
var _ready_to_mesh: Array[ChunkData] = []  # Completed data waiting for main-thread mesh build
var _active_jobs: int = 0  # Number of background generation jobs in flight
const MAX_CONCURRENT_JOBS: int = 4  # How many chunks to generate in parallel

func _ready() -> void:
	# Find noise utilities
	noise_util = get_node_or_null("/root/Core/NoiseUtilities")
	if not noise_util:
		noise_util = preload("res://src/world/terrain/noise_utilities.gd").new()
		add_child(noise_util)
	
	# Initialize noise with world seed
	if game_manager and game_manager.world_seed != 0:
		noise_util.set_seed_from_world(game_manager.world_seed)
	
	# Load tree and rock FBX scenes
	var tree_paths := [
		"res://FBX/CommonTree_1.fbx", "res://FBX/CommonTree_2.fbx", "res://FBX/CommonTree_3.fbx",
		"res://FBX/CommonTree_4.fbx", "res://FBX/CommonTree_5.fbx",
		"res://FBX/TwistedTree_1.fbx", "res://FBX/TwistedTree_2.fbx", "res://FBX/TwistedTree_3.fbx",
		"res://FBX/TwistedTree_4.fbx", "res://FBX/TwistedTree_5.fbx"
	]
	var dead_tree_paths := [
		"res://FBX/DeadTree_1.fbx", "res://FBX/DeadTree_2.fbx", "res://FBX/DeadTree_3.fbx",
		"res://FBX/DeadTree_4.fbx", "res://FBX/DeadTree_5.fbx"
	]
	var rock_paths := [
		"res://FBX/Rock_Medium_1.fbx", "res://FBX/Rock_Medium_2.fbx", "res://FBX/Rock_Medium_3.fbx"
	]
	for path in tree_paths:
		var scene = load(path) as PackedScene
		if scene:
			_tree_scenes.append(scene)
	for path in dead_tree_paths:
		var scene = load(path) as PackedScene
		if scene:
			_dead_tree_scenes.append(scene)
	for path in rock_paths:
		var scene = load(path) as PackedScene
		if scene:
			_rock_scenes.append(scene)
	# Pine trees for taiga and mountain biomes
	var pine_paths := [
		"res://FBX/Pine_1.fbx", "res://FBX/Pine_2.fbx", "res://FBX/Pine_3.fbx",
		"res://FBX/Pine_4.fbx", "res://FBX/Pine_5.fbx"
	]
	for path in pine_paths:
		var scene = load(path) as PackedScene
		if scene:
			_pine_scenes.append(scene)
	# Pebbles for beach and mountain scatter
	var pebble_paths := [
		"res://FBX/Pebble_Round_1.fbx", "res://FBX/Pebble_Round_2.fbx",
		"res://FBX/Pebble_Round_3.fbx", "res://FBX/Pebble_Round_4.fbx",
		"res://FBX/Pebble_Round_5.fbx", "res://FBX/Pebble_Square_1.fbx",
		"res://FBX/Pebble_Square_2.fbx", "res://FBX/Pebble_Square_3.fbx",
		"res://FBX/Pebble_Square_4.fbx", "res://FBX/Pebble_Square_5.fbx",
		"res://FBX/Pebble_Square_6.fbx"
	]
	for path in pebble_paths:
		var scene = load(path) as PackedScene
		if scene:
			_pebble_scenes.append(scene)
	# Flowers for meadow and plains
	var flower_paths := [
		"res://FBX/Flower_3_Group.fbx", "res://FBX/Flower_3_Single.fbx",
		"res://FBX/Flower_4_Group.fbx", "res://FBX/Flower_4_Single.fbx"
	]
	for path in flower_paths:
		var scene = load(path) as PackedScene
		if scene:
			_flower_scenes.append(scene)
	# Ferns for forest and jungle undergrowth
	var fern_paths := ["res://FBX/Fern_1.fbx"]
	for path in fern_paths:
		var scene = load(path) as PackedScene
		if scene:
			_fern_scenes.append(scene)
	# Mushrooms for forest floor
	var mushroom_paths := ["res://FBX/Mushroom_Common.fbx", "res://FBX/Mushroom_Laetiporus.fbx"]
	for path in mushroom_paths:
		var scene = load(path) as PackedScene
		if scene:
			_mushroom_scenes.append(scene)
	# Clovers for plains ground cover
	var clover_paths := ["res://FBX/Clover_1.fbx", "res://FBX/Clover_2.fbx"]
	for path in clover_paths:
		var scene = load(path) as PackedScene
		if scene:
			_clover_scenes.append(scene)
	# Common bushes for plains variety
	var common_bush_paths := ["res://FBX/Bush_Common.fbx", "res://FBX/Bush_Common_Flowers.fbx"]
	for path in common_bush_paths:
		var scene = load(path) as PackedScene
		if scene:
			_bush_common_scenes.append(scene)
	_grass_texture = load("res://Textures/Grass.png") as Texture2D
	# KayKit Forest Nature Pack: grass and bushes
	var forest_base = "res://KayKit_Forest_Nature_Pack_1.0_FREE/Assets/fbx(unity)/"
	var grass_paths := [
		"Grass_1_A_Color1.fbx", "Grass_1_B_Color1.fbx", "Grass_1_C_Color1.fbx", "Grass_1_D_Color1.fbx",
		"Grass_2_A_Color1.fbx", "Grass_2_B_Color1.fbx", "Grass_2_C_Color1.fbx", "Grass_2_D_Color1.fbx"
	]
	var bush_paths := [
		"Bush_1_A_Color1.fbx", "Bush_1_B_Color1.fbx", "Bush_1_C_Color1.fbx", "Bush_1_D_Color1.fbx",
		"Bush_1_E_Color1.fbx", "Bush_1_F_Color1.fbx", "Bush_1_G_Color1.fbx",
		"Bush_2_A_Color1.fbx", "Bush_2_B_Color1.fbx", "Bush_2_C_Color1.fbx", "Bush_2_D_Color1.fbx",
		"Bush_2_E_Color1.fbx", "Bush_2_F_Color1.fbx",
		"Bush_3_A_Color1.fbx", "Bush_3_B_Color1.fbx", "Bush_3_C_Color1.fbx",
		"Bush_4_A_Color1.fbx", "Bush_4_B_Color1.fbx", "Bush_4_C_Color1.fbx",
		"Bush_4_D_Color1.fbx", "Bush_4_E_Color1.fbx", "Bush_4_F_Color1.fbx"
	]
	for grass_name in grass_paths:
		var scene = load(forest_base + grass_name) as PackedScene
		if scene:
			_forest_grass_scenes.append(scene)
	for bush_name in bush_paths:
		var scene = load(forest_base + bush_name) as PackedScene
		if scene:
			_bush_scenes.append(scene)

func _process(delta: float) -> void:
	if not player_node:
		# Try to find player
		player_node = get_tree().get_first_node_in_group("player")
		return
	
	# Update timing
	last_update_time += delta
	
	# Always process generation queue (throttled)
	_process_generation_queue()
	
	if is_updating or last_update_time < update_interval:
		return
	
	last_update_time = 0.0 # Reset timer
	_update_visible_chunks()

func _update_visible_chunks() -> void:
	is_updating = true
	
	# Calculate current chunk position
	var player_chunk_x = int(floor(player_node.global_position.x / chunk_size))
	var player_chunk_z = int(floor(player_node.global_position.z / chunk_size))
	var current_chunk = Vector2i(player_chunk_x, player_chunk_z)
	
	# Determine which chunks should be visible
	var chunks_to_load: Array[Vector2i] = []
	var chunks_to_unload: Array[Vector2i] = []
	
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			var chunk_pos = current_chunk + Vector2i(x, z)
			
			# Square loading logic - load everything in range
			if not loaded_chunks.has(chunk_pos):
				chunks_to_load.append(chunk_pos)
	
	# Find chunks to unload
	for chunk_pos in loaded_chunks.keys():
		# Square unloading logic (Chebyshev distance)
		var dist_x = abs(chunk_pos.x - player_chunk_x)
		var dist_z = abs(chunk_pos.y - player_chunk_z)
		
		# Unload if outside square view distance + buffer
		if max(dist_x, dist_z) > view_distance + 4:
			chunks_to_unload.append(chunk_pos)
	
	# Queue chunks for generation
	for chunk_pos in chunks_to_load:
		if not pending_chunks.has(chunk_pos):
			pending_chunks[chunk_pos] = true
			generation_queue.append(chunk_pos)
	
	# Process generation queue - DONE in _process now
	# _process_generation_queue()
	
	# Unload distant chunks (skip any still pending generation)
	var unloaded_count: int = 0
	var max_unloads_per_update: int = 8
	for chunk_pos in chunks_to_unload:
		if unloaded_count >= max_unloads_per_update:
			break
		if not pending_chunks.has(chunk_pos):
			_unload_chunk(chunk_pos)
			unloaded_count += 1
	
	is_updating = false

# Diagnostics accumulators
var _diag_chunks_timed: int = 0
var _diag_total_gen_ms: float = 0.0
var _diag_total_mesh_ms: float = 0.0
var _diag_report_interval: int = 10

func _process_generation_queue() -> void:
	# Dispatch background generation jobs up to MAX_CONCURRENT_JOBS
	while generation_queue.size() > 0 and _active_jobs < MAX_CONCURRENT_JOBS:
		var chunk_pos: Vector2i = generation_queue.pop_front()
		# Snapshot exclusion_zones on main thread before handing off to worker
		var excl_snapshot: Array = exclusion_zones.duplicate(true)
		mutex.lock()
		_active_jobs += 1
		mutex.unlock()
		WorkerThreadPool.add_task(_generate_chunk_threaded.bind(chunk_pos, excl_snapshot))

	# Drain ready-to-mesh queue on main thread (max 2 per frame to stay smooth)
	var meshed := 0
	while meshed < 2:
		mutex.lock()
		var chunk_data: ChunkData = null
		if _ready_to_mesh.size() > 0:
			chunk_data = _ready_to_mesh.pop_front()
		mutex.unlock()
		if chunk_data == null:
			break
		
		# --- Timed: mesh build (main thread) ---
		var t1 = Time.get_ticks_msec()
		_create_chunk_mesh(chunk_data)
		var t_mesh = Time.get_ticks_msec() - t1
		restore_tilled_plots_for_chunk(chunk_data)
		
		# Diagnostics
		var t_gen = chunk_data.get_meta("diag_gen_ms", 0)
		_diag_chunks_timed += 1
		_diag_total_gen_ms += t_gen
		_diag_total_mesh_ms += t_mesh
		if t_gen + t_mesh > 50:
			var noise_ms = chunk_data.get_meta("diag_noise_us", 0) / 1000.0
			print("[CHUNK] %s | gen=%dms(noise=%.0fms) mesh=%dms | jobs=%d queue=%d" % [
				chunk_data.chunk_position, t_gen, noise_ms,
				t_mesh, _active_jobs, generation_queue.size()])
		if _diag_chunks_timed % _diag_report_interval == 0:
			var n = float(_diag_chunks_timed)
			print("[CHUNK PERF] avg/%d | gen=%.1fms mesh=%.1fms | jobs=%d queue=%d" % [
				_diag_chunks_timed, _diag_total_gen_ms / n, _diag_total_mesh_ms / n,
				_active_jobs, generation_queue.size()])
		emit_signal("chunk_loaded", chunk_data.chunk_position)
		meshed += 1

func _generate_chunk_threaded(chunk_pos: Vector2i, excl_snapshot: Array) -> void:
	# Create a thread-local NoiseBundle — FastNoiseLite is NOT thread-safe across threads
	var local_noise: RefCounted = noise_util.create_thread_local_copy()
	var t0 = Time.get_ticks_msec()
	var chunk_data = _generate_chunk_data(chunk_pos, local_noise, excl_snapshot)
	var t_gen = Time.get_ticks_msec() - t0
	if chunk_data:
		chunk_data.set_meta("diag_gen_ms", t_gen)
		# Build ArrayMesh on background thread — only add_child needs main thread
		var t_mesh0 = Time.get_ticks_msec()
		var built_mesh = _build_heightmap_mesh_data(chunk_data, local_noise, excl_snapshot)
		chunk_data.set_meta("built_mesh", built_mesh)
		chunk_data.set_meta("diag_mesh_bg_ms", Time.get_ticks_msec() - t_mesh0)
		mutex.lock()
		loaded_chunks[chunk_pos] = chunk_data
		pending_chunks.erase(chunk_pos)
		_ready_to_mesh.append(chunk_data)
		_active_jobs -= 1
		mutex.unlock()
	else:
		mutex.lock()
		pending_chunks.erase(chunk_pos)
		_active_jobs -= 1
		mutex.unlock()

func add_exclusion_zone(center: Vector3, radius: float) -> void:
	# Compute flat height at center from noise (before any flattening)
	var flat_h = noise_util.get_terrain_height(center.x, center.z) if noise_util else 0.0
	exclusion_zones.append({"center": center, "radius": radius, "flat_height": flat_h})

func is_in_exclusion_zone(world_x: float, world_z: float) -> bool:
	for zone in exclusion_zones:
		var c: Vector3 = zone["center"]
		var r: float = zone["radius"]
		var dx = world_x - c.x
		var dz = world_z - c.z
		if dx * dx + dz * dz < r * r:
			return true
	return false

func _get_exclusion_height(world_x: float, world_z: float, zones: Array = [], nu = null) -> float:
	# Returns the flat height if inside a zone, blending at edges. -1 if not in any zone.
	var z_list = zones if zones.size() > 0 else exclusion_zones
	var noise_ref = nu if nu != null else noise_util
	for zone in z_list:
		var c: Vector3 = zone["center"]
		var r: float = zone["radius"]
		var dx = world_x - c.x
		var dz = world_z - c.z
		var dist_sq = dx * dx + dz * dz
		if dist_sq < r * r:
			var dist = sqrt(dist_sq)
			var flat_h: float = zone["flat_height"]
			var blend_start = r * 0.7
			if dist < blend_start:
				return flat_h
			else:
				var t = (dist - blend_start) / (r - blend_start)
				var natural_h = noise_ref.get_terrain_height(world_x, world_z)
				return lerp(flat_h, natural_h, t)
	return -1.0

func _generate_chunk_data(chunk_pos: Vector2i, local_noise = null, excl_zones: Array = []) -> ChunkData:
	# Try loading a saved chunk from disk first (restores heights + tile mods + objects)
	var saved_chunk = _load_chunk_from_disk(chunk_pos)
	if saved_chunk:
		return saved_chunk

	var nu = local_noise if local_noise != null else noise_util
	var _excl = excl_zones if excl_zones.size() > 0 else exclusion_zones
	var chunk = ChunkData.new()
	chunk.initialize(chunk_pos, chunk_size)
	var sz = chunk.size

	# ── Pass 1: surface heights + biomes (2D, 1024 samples) ──────────────────
	var _t0 = Time.get_ticks_msec()
	for z in range(sz):
		for x in range(sz):
			var world_x = chunk.world_position.x + x
			var world_z = chunk.world_position.z + z
			var surface_h = nu.get_terrain_height(world_x, world_z)
			var excl_h = _get_exclusion_height(world_x, world_z, _excl, nu)
			if excl_h >= 0.0:
				surface_h = excl_h
			var biome = nu.get_biome_type(world_x, world_z)
			chunk.set_biome(x, z, biome)
			chunk.set_height(x, z, surface_h)
	var _t_noise = Time.get_ticks_msec() - _t0

	# Store sub-timings for diagnostics
	chunk.set_meta("diag_noise_us", _t_noise * 1000)

	# Generate objects if enabled
	var _to2 = Time.get_ticks_msec()
	if generate_objects:
		_generate_chunk_objects(chunk)
	chunk.set_meta("diag_objgen_ms", Time.get_ticks_msec() - _to2)

	# Reset modification flag — initial generation is not a player edit
	chunk.is_modified = false
	return chunk

func _generate_chunk_objects(chunk: ChunkData) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk.chunk_position)
	
	var object_density = 0.1  # 10% of valid positions
	
	for z in range(chunk.size):
		for x in range(chunk.size):
			if rng.randf() > object_density:
				continue
			
			var world_x = chunk.world_position.x + x + 0.5
			var world_z = chunk.world_position.z + z + 0.5
			var height = chunk.get_surface_world_y(x, z)
			
			var _biome = chunk.get_biome(x, z)
			var tree_density = noise_util.get_tree_density(world_x, world_z)
			var rock_density = noise_util.get_rock_density(world_x, world_z)
			
			var world_pos = Vector3(world_x, height, world_z)
			
			# Determine if this is a valid spot (not underwater, etc.)
			if height < noise_util.get_water_level() - 1.0:
				continue
			
			# Skip objects inside town exclusion zones
			if is_in_exclusion_zone(world_x, world_z):
				continue
			
			# Check if too close to chunk edge
			if x < 2 or x > chunk.size - 3 or z < 2 or z > chunk.size - 3:
				continue
			
			# Try to place tree
			if rng.randf() < tree_density * 0.3:
				if not chunk.has_object_at(world_pos, 1.5):
					chunk.add_tree(world_pos)
			
			# Try to place rocks
			elif rng.randf() < rock_density * 0.5:
				if not chunk.has_object_at(world_pos, 1.0):
					chunk.add_rock(world_pos)

func _create_chunk_mesh(chunk: ChunkData) -> void:
	if not terrain_container:
		terrain_container = get_node_or_null("../TerrainContainer")
		print("WARN: terrain_container was null, tried fallback: ", terrain_container)
	if not terrain_container:
		print("ERROR: terrain_container still null! Cannot create mesh for chunk ", chunk.chunk_position)
		return

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Chunk_%d_%d" % [chunk.chunk_position.x, chunk.chunk_position.y]
	mesh_instance.position = chunk.world_position

	# Use pre-built mesh from background thread if available, else build now
	if chunk.has_meta("built_mesh") and chunk.get_meta("built_mesh") != null:
		var prebuilt: ArrayMesh = chunk.get_meta("built_mesh")
		mesh_instance.mesh = prebuilt
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.9
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = material
	else:
		_build_heightmap_mesh_into(chunk, mesh_instance)

	terrain_container.add_child(mesh_instance)
	mesh_instance.set_meta("chunk_data", chunk)
	
	# Create water mesh for water biomes
	_create_water_mesh(chunk, mesh_instance)

	var obj_rng = RandomNumberGenerator.new()
	obj_rng.seed = hash(chunk.chunk_position) + 7919
	_create_chunk_objects(chunk, mesh_instance, obj_rng)
	
	_create_chunk_collision(chunk, mesh_instance)

func _create_chunk_collision(chunk: ChunkData, parent: Node) -> void:
	if not parent.get("mesh"):
		return
	var mesh = parent.mesh as Mesh
	if not mesh:
		return
		
	var static_body = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	collision_shape.shape = mesh.create_trimesh_shape()
	
	static_body.add_child(collision_shape)
	parent.add_child(static_body)

func _sample_height_at_world(world_x: float, world_z: float, nu, excl_zones: Array) -> float:
	## Sample terrain height at any world XZ using noise — same formula as _generate_chunk_data.
	## Used to stitch chunk edges to their neighbors.
	var h = nu.get_terrain_height(world_x, world_z)
	var excl_h = _get_exclusion_height(world_x, world_z, excl_zones, nu)
	if excl_h >= 0.0:
		h = excl_h
	return h

func _build_heightmap_mesh_data(chunk: ChunkData, nu = null, excl_zones: Array = []) -> ArrayMesh:
	## Builds and returns a 2D grid ArrayMesh from chunk heightmap data.
	## Safe to call from a background thread.
	## nu: noise utility (thread-local copy). excl_zones: exclusion zone snapshot.
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	var wx_off = chunk.world_position.x
	var wz_off = chunk.world_position.z
	var sz = chunk.size
	var _nu = nu if nu != null else noise_util
	var _excl = excl_zones if excl_zones.size() > 0 else exclusion_zones

	# We build a grid of (sz) x (sz) quads, requiring (sz+1) x (sz+1) vertices.
	# To keep things simple and allow for flat shading, we'll generate distinct vertices per quad.
	var vi := 0
	for z in range(sz):
		for x in range(sz):
			var h00 = chunk.get_height(x, z)
			# For edge vertices, sample noise directly so they match the neighbor chunk.
			var h10: float
			if x + 1 < sz:
				h10 = chunk.get_height(x + 1, z)
			else:
				h10 = _sample_height_at_world(wx_off + x + 1, wz_off + z, _nu, _excl)
			var h01: float
			if z + 1 < sz:
				h01 = chunk.get_height(x, z + 1)
			else:
				h01 = _sample_height_at_world(wx_off + x, wz_off + z + 1, _nu, _excl)
			var h11: float
			if x + 1 < sz and z + 1 < sz:
				h11 = chunk.get_height(x + 1, z + 1)
			else:
				h11 = _sample_height_at_world(wx_off + x + 1, wz_off + z + 1, _nu, _excl)

			var v00 = Vector3(x, h00, z)
			var v10 = Vector3(x + 1, h10, z)
			var v01 = Vector3(x, h01, z + 1)
			var v11 = Vector3(x + 1, h11, z + 1)

			# Calculate normal for the quad (using cross product of diagonals)
			var nrm = (v01 - v10).cross(v11 - v00).normalized()
			if nrm.y < 0: nrm = -nrm

			# Get color
			var biome = chunk.get_biome(x, z)
			var color = _get_terrain_vertex_color(biome, wx_off + x, wz_off + z)
			
			# A quad at (x,z) has 4 corner vertices: (x,z),(x+1,z),(x,z+1),(x+1,z+1).
			# Color it if ANY of those 4 corner cells has a tile modification.
			var tm00 = chunk.get_tile_mod(x, z)
			var tm10 = chunk.get_tile_mod(mini(x + 1, sz - 1), z)
			var tm01 = chunk.get_tile_mod(x, mini(z + 1, sz - 1))
			var tm11 = chunk.get_tile_mod(mini(x + 1, sz - 1), mini(z + 1, sz - 1))
			var active_mod = tm00
			if active_mod == ChunkData.TileMod.NONE: active_mod = tm10
			if active_mod == ChunkData.TileMod.NONE: active_mod = tm01
			if active_mod == ChunkData.TileMod.NONE: active_mod = tm11
			if active_mod != ChunkData.TileMod.NONE:
				color = _get_tile_mod_color(active_mod)

			# Triangle 1: 00 -> 10 -> 01
			verts.append(v00); verts.append(v10); verts.append(v01)
			normals.append(nrm); normals.append(nrm); normals.append(nrm)
			colors.append(color); colors.append(color); colors.append(color)
			indices.append(vi); indices.append(vi+1); indices.append(vi+2)
			vi += 3

			# Triangle 2: 10 -> 11 -> 01
			verts.append(v10); verts.append(v11); verts.append(v01)
			normals.append(nrm); normals.append(nrm); normals.append(nrm)
			colors.append(color); colors.append(color); colors.append(color)
			indices.append(vi); indices.append(vi+1); indices.append(vi+2)
			vi += 3

	if vi == 0:
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]  = verts
	arrays[Mesh.ARRAY_NORMAL]  = normals
	arrays[Mesh.ARRAY_COLOR]   = colors
	arrays[Mesh.ARRAY_INDEX]   = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_heightmap_mesh_into(chunk: ChunkData, mesh_instance: MeshInstance3D) -> void:
	## Wrapper: builds mesh data and assigns to mesh_instance (main thread only).
	var mesh = _build_heightmap_mesh_data(chunk)
	if mesh == null:
		return
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

func _create_chunk_objects(chunk: ChunkData, parent: Node, rng: RandomNumberGenerator) -> void:
	# Create tree instances (biome-aware, scale/rotation variation)
	for tree_pos in chunk.tree_positions:
		var local_pos = tree_pos - chunk.world_position
		var tree = _create_tree_mesh(chunk, local_pos, rng)
		if tree:
			parent.add_child(tree)
	
	# Create rock instances (scale and tilt variation)
	for rock_pos in chunk.rock_positions:
		var local_pos = rock_pos - chunk.world_position
		var rlx = clampi(int(local_pos.x), 0, chunk.size)
		var rlz = clampi(int(local_pos.z), 0, chunk.size)
		var rock_biome = chunk.get_biome(rlx, rlz)
		var rock = _create_rock_mesh(local_pos, rng, rock_biome)
		if rock:
			parent.add_child(rock)
	
	# Grass patches on grass-friendly biomes (3D from pack or quad fallback)
	_create_grass_patches(chunk, parent)
	# Bushes (KayKit Forest Nature Pack)
	_create_bush_patches(chunk, parent)
	# Biome-specific decorations
	_create_biome_decorations(chunk, parent)

func _create_fishing_spots(chunk: ChunkData, parent: Node, rng: RandomNumberGenerator) -> void:
	if not generate_objects:
		return
	var water_level := 16.0
	if noise_util and noise_util.has_method("get_water_level"):
		water_level = noise_util.get_water_level()
	for z in range(0, chunk.size, 2):
		for x in range(0, chunk.size, 2):
			if chunk.get_biome(x, z) != 0:
				continue
			if rng.randf() > 0.08:
				continue
			var world_x = chunk.world_position.x + x + 0.5
			var world_z = chunk.world_position.z + z + 0.5
			if is_in_exclusion_zone(world_x, world_z):
				continue
			var spot := FishingSpot.new()
			spot.name = "FishingSpot"
			spot.position = Vector3(x + 0.5, water_level, z + 0.5)
			spot.set_default_loot()
			parent.add_child(spot)

func _get_tree_loot_for_biome(biome: int, rng: RandomNumberGenerator) -> Array:
	match biome:
		5:  # Taiga - pine trees: more wood + sap
			return [
				{"item_id": "wood_log", "min_amount": 3, "max_amount": 6, "chance": 1.0},
				{"item_id": "stick", "min_amount": 1, "max_amount": 2, "chance": 0.5},
				{"item_id": "sap", "min_amount": 1, "max_amount": 2, "chance": 0.4},
			]
		6, 7:  # Mountains/Snow - stunted trees: less wood, no sticks
			return [
				{"item_id": "wood_log", "min_amount": 1, "max_amount": 2, "chance": 1.0},
			]
		9:  # Highland - sparse trees: moderate wood, few sticks
			return [
				{"item_id": "wood_log", "min_amount": 1, "max_amount": 3, "chance": 1.0},
				{"item_id": "stick", "min_amount": 1, "max_amount": 2, "chance": 0.4},
			]
		4:  # Jungle/Swamp - dense trees: more wood, more sticks
			return [
				{"item_id": "wood_log", "min_amount": 3, "max_amount": 5, "chance": 1.0},
				{"item_id": "stick", "min_amount": 2, "max_amount": 4, "chance": 0.8},
			]
		_:  # Plains(2), Forest(3), Meadow(8) and others: standard
			return [
				{"item_id": "wood_log", "min_amount": 2, "max_amount": 4, "chance": 1.0},
				{"item_id": "stick", "min_amount": 1, "max_amount": 3, "chance": 0.7},
			]

func _get_rock_loot_for_biome(biome: int, rng: RandomNumberGenerator) -> Array:
	match biome:
		6, 9:  # Mountains, Highland: more ore
			return [
				{"item_id": "stone", "min_amount": 3, "max_amount": 6, "chance": 1.0},
				{"item_id": "coal", "min_amount": 1, "max_amount": 3, "chance": 0.5},
				{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 3, "chance": 0.4},
				{"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.3},
				{"item_id": "gold_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.1},
			]
		5, 7:  # Taiga, Snow: coal-heavy
			return [
				{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0},
				{"item_id": "coal", "min_amount": 1, "max_amount": 3, "chance": 0.6},
				{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.15},
			]
		2:  # Plains: stone only
			return [
				{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0},
			]
		1:  # Beach: stone + some copper
			return [
				{"item_id": "stone", "min_amount": 1, "max_amount": 3, "chance": 1.0},
				{"item_id": "copper_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.2},
			]
		_:  # Forest(3), Jungle(4), Meadow(8): standard
			return [
				{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0},
				{"item_id": "coal", "min_amount": 1, "max_amount": 2, "chance": 0.3},
				{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.2},
				{"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.15},
			]

func _create_tree_mesh(chunk: ChunkData, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var lx = clampi(int(pos.x), 0, chunk.size)
	var lz = clampi(int(pos.z), 0, chunk.size)
	var biome = chunk.get_biome(lx, lz)
	
	# Select tree type based on biome
	var scenes: Array[PackedScene] = []
	match biome:
		5:  # Taiga - pine trees
			scenes = _pine_scenes
		6:  # Mountains - mix of pine and dead trees
			if rng.randf() < 0.6 and not _pine_scenes.is_empty():
				scenes = _pine_scenes
			elif not _dead_tree_scenes.is_empty():
				scenes = _dead_tree_scenes
			else:
				scenes = _tree_scenes
		7:  # Snow - mostly dead, occasional pine
			if rng.randf() < 0.3 and not _pine_scenes.is_empty():
				scenes = _pine_scenes
			elif not _dead_tree_scenes.is_empty():
				scenes = _dead_tree_scenes
		9:  # Highland - dead trees and sparse common
			if rng.randf() < 0.5 and not _dead_tree_scenes.is_empty():
				scenes = _dead_tree_scenes
			else:
				scenes = _tree_scenes
		2:  # Plains - occasional lone tree, sometimes dead
			if rng.randf() < 0.2 and not _dead_tree_scenes.is_empty():
				scenes = _dead_tree_scenes
			else:
				scenes = _tree_scenes
		_:  # Forest (3), Jungle (4), Meadow (8) - common/twisted trees
			scenes = _tree_scenes
	
	if scenes.is_empty():
		return _create_tree_mesh_procedural(pos, biome)
	var scene: PackedScene = scenes[rng.randi() % scenes.size()]
	var tree_container: Node3D = scene.instantiate() as Node3D
	if not tree_container:
		return _create_tree_mesh_procedural(pos, biome)
	tree_container.name = "Tree"
	tree_container.position = pos
	tree_container.rotation.y = rng.randf_range(0.0, TAU)
	var scale_factor := rng.randf_range(0.88, 1.15)
	# Mountain/snow trees are smaller (stunted)
	if biome == 6 or biome == 7:
		scale_factor *= 0.7
	tree_container.scale = Vector3(scale_factor, scale_factor, scale_factor)
	# Add harvestable collision for player/world interaction
	var harvestable = HarvestableResource.new()
	harvestable.name = "Collision"
	harvestable.collision_layer = 2
	harvestable.collision_mask = 0
	harvestable.resource_type = ToolAffinity.TargetType.TREE
	harvestable.max_health = 15.0
	harvestable.xp_action_id = "chop_tree"
	harvestable.loot_table = _get_tree_loot_for_biome(biome, rng)
	var collision_shape = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.5 * scale_factor
	trunk_shape.height = 3.0 * scale_factor
	collision_shape.shape = trunk_shape
	collision_shape.position.y = 1.5 * scale_factor
	harvestable.add_child(collision_shape)
	tree_container.add_child(harvestable)
	return tree_container

func _create_tree_mesh_procedural(pos: Vector3, biome: int = 2, rng: RandomNumberGenerator = null) -> Node3D:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var tree_container = Node3D.new()
	tree_container.name = "Tree"
	tree_container.position = pos
	var trunk = MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 2.0
	trunk.mesh = trunk_mesh
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)
	trunk.material_override = trunk_mat
	trunk.position.y = 1.0
	tree_container.add_child(trunk)
	var leaves = MeshInstance3D.new()
	leaves.name = "Leaves"
	var leaves_mesh = SphereMesh.new()
	leaves_mesh.radius = 1.2
	leaves_mesh.height = 2.0
	leaves.mesh = leaves_mesh
	var leaves_mat = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.2, 0.5, 0.15)
	leaves.material_override = leaves_mat
	leaves.position.y = 2.5
	tree_container.add_child(leaves)
	var harvestable = HarvestableResource.new()
	harvestable.name = "Collision"
	harvestable.collision_layer = 2
	harvestable.collision_mask = 0
	harvestable.resource_type = ToolAffinity.TargetType.TREE
	harvestable.max_health = 10.0
	harvestable.xp_action_id = "chop_tree"
	harvestable.loot_table = _get_tree_loot_for_biome(biome, rng)
	var collision_shape = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 2.0
	collision_shape.shape = trunk_shape
	collision_shape.position.y = 1.0
	harvestable.add_child(collision_shape)
	tree_container.add_child(harvestable)
	return tree_container

func _create_rock_mesh(pos: Vector3, rng: RandomNumberGenerator, biome: int = 2) -> Node3D:
	if _rock_scenes.is_empty():
		return _create_rock_mesh_procedural(pos, biome)
	var scene: PackedScene = _rock_scenes[rng.randi() % _rock_scenes.size()]
	var rock_container: Node3D = scene.instantiate() as Node3D
	if not rock_container:
		return _create_rock_mesh_procedural(pos, biome)
	rock_container.name = "Rock"
	rock_container.position = pos
	rock_container.rotation.y = rng.randf_range(0.0, TAU)
	rock_container.rotation.x = rng.randf_range(-0.12, 0.12)
	rock_container.rotation.z = rng.randf_range(-0.12, 0.12)
	var scale_factor := rng.randf_range(0.82, 1.18)
	rock_container.scale = Vector3(scale_factor, scale_factor, scale_factor)
	var radius := 0.5 * scale_factor
	var harvestable = HarvestableResource.new()
	harvestable.name = "Collision"
	harvestable.collision_layer = 2
	harvestable.collision_mask = 0
	harvestable.resource_type = ToolAffinity.TargetType.ROCK
	harvestable.max_health = 20.0
	harvestable.xp_action_id = "mine_ore"
	harvestable.loot_table = _get_rock_loot_for_biome(biome, rng)
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	harvestable.add_child(collision_shape)
	rock_container.add_child(harvestable)
	return rock_container

func _create_rock_mesh_procedural(pos: Vector3, biome: int = 2) -> Node3D:
	var rock_container = Node3D.new()
	rock_container.name = "Rock"
	rock_container.position = pos
	var radius = randf_range(0.3, 0.6)
	var rock = MeshInstance3D.new()
	rock.name = "RockMesh"
	var rock_mesh = SphereMesh.new()
	rock_mesh.radius = radius
	rock_mesh.height = radius * 2.0
	rock.mesh = rock_mesh
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.5, 0.5)
	rock.material_override = rock_mat
	rock_container.add_child(rock)
	var harvestable = HarvestableResource.new()
	harvestable.name = "Collision"
	harvestable.collision_layer = 2
	harvestable.collision_mask = 0
	harvestable.resource_type = ToolAffinity.TargetType.ROCK
	harvestable.max_health = 12.0
	harvestable.xp_action_id = "mine_ore"
	var rng_loot := RandomNumberGenerator.new()
	harvestable.loot_table = _get_rock_loot_for_biome(biome, rng_loot)
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	harvestable.add_child(collision_shape)
	rock_container.add_child(harvestable)
	return rock_container

func _create_grass_patches(chunk: ChunkData, parent: Node) -> void:
	if chunk.size <= 0:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk.chunk_position.x * 73856093 + chunk.chunk_position.y * 19349663
	var num_patches: int = int(chunk.size * chunk.size) / 8
	num_patches = mini(num_patches, 28)
	for i in num_patches:
		var lx = rng.randf_range(1.0, float(chunk.size) - 1.0)
		var lz = rng.randf_range(1.0, float(chunk.size) - 1.0)
		var gx = clampi(int(lx), 0, chunk.size)
		var gz = clampi(int(lz), 0, chunk.size)
		var biome = chunk.get_biome(gx, gz)
		# Grass grows in plains, forest, jungle, meadow, highland, taiga
		if biome not in [2, 3, 4, 5, 8, 9]:
			continue
		var world_x = chunk.world_position.x + lx
		var world_z = chunk.world_position.z + lz
		if is_in_exclusion_zone(world_x, world_z):
			continue
		var height = chunk.get_world_height(world_x, world_z)
		# Prefer 3D grass from KayKit Forest Nature Pack
		if not _forest_grass_scenes.is_empty():
			var scene: PackedScene = _forest_grass_scenes[rng.randi() % _forest_grass_scenes.size()]
			var grass_node: Node3D = scene.instantiate() as Node3D
			if grass_node:
				grass_node.name = "GrassPatch"
				grass_node.position = Vector3(lx, height + 0.02, lz)
				grass_node.rotation.y = rng.randf_range(0.0, TAU)
				var scale_factor := rng.randf_range(0.85, 1.15)
				grass_node.scale = Vector3(scale_factor, scale_factor, scale_factor)
				parent.add_child(grass_node)
			continue
		# Fallback: quad with texture
		if not _grass_texture:
			continue
		var qm = QuadMesh.new()
		qm.size = Vector2(rng.randf_range(0.5, 1.0), rng.randf_range(0.5, 1.0))
		var quad = MeshInstance3D.new()
		quad.name = "GrassPatch"
		quad.mesh = qm
		var y_offset = qm.size.y * 0.5 + 0.04
		quad.position = Vector3(lx, height + y_offset, lz)  # height already mesh-local
		quad.rotation.y = rng.randf_range(0.0, TAU)
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = _grass_texture
		mat.albedo_color = Color.WHITE
		mat.vertex_color_use_as_albedo = false
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material_override = mat
		parent.add_child(quad)

func _create_bush_patches(chunk: ChunkData, parent: Node) -> void:
	if _bush_scenes.is_empty() or chunk.size <= 0:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk.chunk_position.x * 19349663 + chunk.chunk_position.y * 73856093
	var num_bushes = mini(chunk.size * 2, 18)
	for i in num_bushes:
		var lx = rng.randf_range(2.0, float(chunk.size) - 2.0)
		var lz = rng.randf_range(2.0, float(chunk.size) - 2.0)
		var gx = clampi(int(lx), 0, chunk.size)
		var gz = clampi(int(lz), 0, chunk.size)
		var biome = chunk.get_biome(gx, gz)
		# Bushes grow in plains, forest, jungle, meadow, highland
		if biome not in [2, 3, 4, 8, 9]:
			continue
		var world_x = chunk.world_position.x + lx
		var world_z = chunk.world_position.z + lz
		if is_in_exclusion_zone(world_x, world_z):
			continue
		var height = chunk.get_world_height(world_x, world_z)
		# Use common bushes for plains/meadow, forest pack bushes for forest/jungle
		var bush_pool: Array[PackedScene] = []
		if biome in [2, 8] and not _bush_common_scenes.is_empty():
			bush_pool = _bush_common_scenes
		else:
			bush_pool = _bush_scenes
		if bush_pool.is_empty():
			continue
		var scene: PackedScene = bush_pool[rng.randi() % bush_pool.size()]
		var bush_node: Node3D = scene.instantiate() as Node3D
		if not bush_node:
			continue
		bush_node.name = "Bush"
		bush_node.position = Vector3(lx, height + 0.02, lz)
		bush_node.rotation.y = rng.randf_range(0.0, TAU)
		var scale_factor := rng.randf_range(0.9, 1.2)
		bush_node.scale = Vector3(scale_factor, scale_factor, scale_factor)
		parent.add_child(bush_node)

func _create_biome_decorations(chunk: ChunkData, parent: Node) -> void:
	if chunk.size <= 0:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk.chunk_position.x * 83492791 + chunk.chunk_position.y * 47165893
	var num_decorations: int = mini(chunk.size * 3, 40)
	
	for i in num_decorations:
		var lx = rng.randf_range(1.0, float(chunk.size) - 1.0)
		var lz = rng.randf_range(1.0, float(chunk.size) - 1.0)
		var gx = clampi(int(lx), 0, chunk.size)
		var gz = clampi(int(lz), 0, chunk.size)
		var biome = chunk.get_biome(gx, gz)
		var world_x = chunk.world_position.x + lx
		var world_z = chunk.world_position.z + lz
		if is_in_exclusion_zone(world_x, world_z):
			continue
		var height = chunk.get_world_height(world_x, world_z)
		
		var scene_pool: Array[PackedScene] = []
		var node_name := "Decoration"
		var scale_min := 0.8
		var scale_max := 1.2
		
		match biome:
			8:  # Meadow - flowers
				if not _flower_scenes.is_empty():
					scene_pool = _flower_scenes
					node_name = "Flower"
					scale_min = 0.7
					scale_max = 1.3
			2:  # Plains - clovers and occasional flowers
				if rng.randf() < 0.6 and not _clover_scenes.is_empty():
					scene_pool = _clover_scenes
					node_name = "Clover"
					scale_min = 0.8
					scale_max = 1.1
				elif not _flower_scenes.is_empty():
					scene_pool = _flower_scenes
					node_name = "Flower"
			3:  # Forest - ferns and mushrooms
				if rng.randf() < 0.6 and not _fern_scenes.is_empty():
					scene_pool = _fern_scenes
					node_name = "Fern"
					scale_min = 0.7
					scale_max = 1.4
				elif not _mushroom_scenes.is_empty():
					scene_pool = _mushroom_scenes
					node_name = "Mushroom"
					scale_min = 0.6
					scale_max = 1.0
			4:  # Jungle/Swamp - dense ferns
				if not _fern_scenes.is_empty():
					scene_pool = _fern_scenes
					node_name = "Fern"
					scale_min = 0.9
					scale_max = 1.6
			1:  # Beach - pebbles
				if not _pebble_scenes.is_empty():
					scene_pool = _pebble_scenes
					node_name = "Pebble"
					scale_min = 0.5
					scale_max = 1.0
			6:  # Mountains - pebbles and rocks
				if not _pebble_scenes.is_empty():
					scene_pool = _pebble_scenes
					node_name = "Pebble"
					scale_min = 0.6
					scale_max = 1.5
			7:  # Snow - sparse pebbles
				if rng.randf() < 0.4 and not _pebble_scenes.is_empty():
					scene_pool = _pebble_scenes
					node_name = "Pebble"
					scale_min = 0.5
					scale_max = 1.2
			9:  # Highland - pebbles and clovers
				if rng.randf() < 0.5 and not _pebble_scenes.is_empty():
					scene_pool = _pebble_scenes
					node_name = "Pebble"
					scale_min = 0.5
					scale_max = 1.0
				elif not _clover_scenes.is_empty():
					scene_pool = _clover_scenes
					node_name = "Clover"
			5:  # Taiga - mushrooms (sparse)
				if rng.randf() < 0.3 and not _mushroom_scenes.is_empty():
					scene_pool = _mushroom_scenes
					node_name = "Mushroom"
					scale_min = 0.5
					scale_max = 0.9
		
		if scene_pool.is_empty():
			continue
		
		var scene: PackedScene = scene_pool[rng.randi() % scene_pool.size()]
		var node: Node3D = scene.instantiate() as Node3D
		if not node:
			continue
		node.name = node_name
		node.position = Vector3(lx, height + 0.02, lz)
		node.rotation.y = rng.randf_range(0.0, TAU)
		var scale_factor := rng.randf_range(scale_min, scale_max)
		node.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		# Add harvestable collision to herbs (not pebbles)
		if node_name in ["Mushroom", "Flower", "Fern", "Clover"]:
			_add_herb_harvestable(node, node_name, scale_factor, rng, biome)
		
		parent.add_child(node)

func _add_herb_harvestable(node: Node3D, herb_type: String, scale_factor: float, rng: RandomNumberGenerator, biome: int = -1) -> void:
	var harvestable = HarvestableResource.new()
	harvestable.name = "Collision"
	harvestable.collision_layer = 2
	harvestable.collision_mask = 0
	harvestable.resource_type = ToolAffinity.TargetType.HERB
	harvestable.max_health = 1.0  # Herbs are one-hit with proper tool
	
	match herb_type:
		"Mushroom":
			harvestable.xp_action_id = "pick_mushroom"
			# Swamp/jungle mushrooms have higher rare chance
			var rare_chance := 0.15
			if biome == 4:
				rare_chance = 0.3
			if rng.randf() < rare_chance:
				harvestable.loot_table = [
					{"item_id": "golden_mushroom", "min_amount": 1, "max_amount": 1, "chance": 1.0},
				]
			else:
				harvestable.loot_table = [
					{"item_id": "common_mushroom", "min_amount": 1, "max_amount": 2, "chance": 1.0},
				]
		"Flower":
			harvestable.xp_action_id = "forage_item"
			var flower_roll = rng.randf()
			if biome == 8 or biome == 2:  # Meadow/Plains: more lavender, less nightshade
				if flower_roll < 0.5:
					harvestable.loot_table = [
						{"item_id": "lavender", "min_amount": 1, "max_amount": 2, "chance": 1.0},
					]
				elif flower_roll < 0.8:
					harvestable.loot_table = [
						{"item_id": "chamomile", "min_amount": 1, "max_amount": 2, "chance": 1.0},
					]
				else:
					harvestable.loot_table = [
						{"item_id": "wild_clover", "min_amount": 1, "max_amount": 2, "chance": 1.0},
					]
			else:  # Forest/Jungle: more chamomile, nightshade possible
				if flower_roll < 0.3:
					harvestable.loot_table = [
						{"item_id": "lavender", "min_amount": 1, "max_amount": 2, "chance": 1.0},
					]
				elif flower_roll < 0.6:
					harvestable.loot_table = [
						{"item_id": "chamomile", "min_amount": 1, "max_amount": 2, "chance": 1.0},
					]
				else:
					harvestable.loot_table = [
						{"item_id": "nightshade", "min_amount": 1, "max_amount": 1, "chance": 0.5},
						{"item_id": "lavender", "min_amount": 1, "max_amount": 1, "chance": 0.5},
					]
		"Fern":
			harvestable.xp_action_id = "forage_item"
			# Jungle/swamp ferns yield more mint
			if biome == 4:
				harvestable.loot_table = [
					{"item_id": "fern_frond", "min_amount": 1, "max_amount": 3, "chance": 1.0},
					{"item_id": "mint_leaf", "min_amount": 1, "max_amount": 2, "chance": 0.6},
				]
			else:
				harvestable.loot_table = [
					{"item_id": "fern_frond", "min_amount": 1, "max_amount": 2, "chance": 1.0},
					{"item_id": "mint_leaf", "min_amount": 1, "max_amount": 1, "chance": 0.3},
				]
		"Clover":
			harvestable.xp_action_id = "forage_item"
			# Meadow clovers have higher sage chance
			if biome == 8:
				harvestable.loot_table = [
					{"item_id": "wild_clover", "min_amount": 2, "max_amount": 4, "chance": 1.0},
					{"item_id": "sage_leaf", "min_amount": 1, "max_amount": 2, "chance": 0.4},
				]
			else:
				harvestable.loot_table = [
					{"item_id": "wild_clover", "min_amount": 1, "max_amount": 3, "chance": 1.0},
					{"item_id": "sage_leaf", "min_amount": 1, "max_amount": 1, "chance": 0.2},
				]
	
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.4 * scale_factor
	collision_shape.shape = shape
	collision_shape.position.y = 0.2 * scale_factor
	harvestable.add_child(collision_shape)
	node.add_child(harvestable)

func _create_water_mesh(chunk: ChunkData, parent: Node) -> void:
	## Creates an animated water mesh for water biome cells
	var water_level := 16.0
	if noise_util and noise_util.has_method("get_water_level"):
		water_level = noise_util.get_water_level()
	
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var vi := 0
	var has_water := false
	
	for z in range(chunk.size):
		for x in range(chunk.size):
			if chunk.get_biome(x, z) != 0:  # Not water biome
				continue
			
			has_water = true
			# Create a quad at water level
			var v00 = Vector3(x, water_level, z)
			var v10 = Vector3(x + 1, water_level, z)
			var v01 = Vector3(x, water_level, z + 1)
			var v11 = Vector3(x + 1, water_level, z + 1)
			
			# Triangle 1
			verts.append(v00); verts.append(v10); verts.append(v01)
			indices.append(vi); indices.append(vi+1); indices.append(vi+2)
			vi += 3
			
			# Triangle 2
			verts.append(v10); verts.append(v11); verts.append(v01)
			indices.append(vi); indices.append(vi+1); indices.append(vi+2)
			vi += 3
	
	if not has_water:
		return
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var water_instance := MeshInstance3D.new()
	water_instance.name = "WaterMesh"
	water_instance.mesh = mesh
	water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Apply water shader
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://src/shaders/water_shader.gdshader")
	water_instance.material_override = shader_material
	
	parent.add_child(water_instance)

func _get_biome_color(biome: int) -> Color:
	match biome:
		0: return Color(0.18, 0.28, 0.65)  # Water (deeper blue)
		1: return Color(0.82, 0.75, 0.55)  # Beach (warm sand)
		2: return Color(0.5, 0.68, 0.22)   # Plains (dry grassland)
		3: return Color(0.2, 0.5, 0.18)    # Forest (rich green)
		4: return Color(0.12, 0.42, 0.14)  # Jungle/Swamp (dark lush)
		5: return Color(0.3, 0.42, 0.32)   # Taiga (muted cold green)
		6: return Color(0.52, 0.48, 0.42)  # Mountains (grey-brown rock)
		7: return Color(0.92, 0.92, 0.98)  # Snow (bright white-blue)
		8: return Color(0.45, 0.65, 0.25)  # Meadow (lush warm green)
		9: return Color(0.55, 0.52, 0.38)  # Highland (dry rocky grass)
		_: return Color(0.3, 0.5, 0.2)

func _get_terrain_vertex_color(biome: int, world_x: float, world_z: float) -> Color:
	var base_color := _get_biome_color(biome)
	if biome == 0:
		return base_color
	if not noise_util or not noise_util.has_method("get_grass_color"):
		return base_color
	var grass_color: Color = noise_util.get_grass_color(world_x, world_z)
	# Blend base biome color with moisture/temperature grass variation (40% grass)
	return base_color.lerp(grass_color, 0.4)

func _unload_chunk(chunk_pos: Vector2i) -> void:
	if not loaded_chunks.has(chunk_pos):
		return
	
	var chunk = loaded_chunks[chunk_pos]
	
	# Save chunk if modified
	if save_chunks and chunk.is_modified:
		_save_chunk(chunk)
	
	# Remove dynamic farm plots in this chunk
	_remove_farm_plots_for_chunk(chunk)
	
	# Remove chunk mesh (voxel mesh contains everything)
	var mesh_name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	if terrain_container:
		var mesh_instance = terrain_container.get_node_or_null(mesh_name)
		if mesh_instance:
			mesh_instance.queue_free()
	
	loaded_chunks.erase(chunk_pos)
	emit_signal("chunk_unloaded", chunk_pos)

func _save_chunk(chunk: ChunkData) -> void:
	if chunk_save_dir == "":
		return
	_ensure_chunk_save_dir()
	var filename = "chunk_%d_%d.json" % [chunk.chunk_position.x, chunk.chunk_position.y]
	var filepath = chunk_save_dir + filename
	var chunk_data = chunk.serialize()
	var json_string = JSON.stringify(chunk_data, "\t")
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		chunk.is_modified = false
	else:
		push_error("Failed to save chunk to: " + filepath)

func _ensure_chunk_save_dir() -> void:
	if chunk_save_dir == "":
		return
	if not DirAccess.dir_exists_absolute(chunk_save_dir):
		DirAccess.make_dir_recursive_absolute(chunk_save_dir)

func _load_chunk_from_disk(chunk_pos: Vector2i) -> ChunkData:
	if chunk_save_dir == "":
		return null
	var filename = "chunk_%d_%d.json" % [chunk_pos.x, chunk_pos.y]
	var filepath = chunk_save_dir + filename
	if not FileAccess.file_exists(filepath):
		return null
	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		return null
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse chunk file: " + filepath)
		return null
	var chunk = ChunkData.new()
	chunk.deserialize(json.data)
	return chunk

func get_chunk_at_position(world_pos: Vector3) -> ChunkData:
	var chunk_x = int(floor(world_pos.x / chunk_size))
	var chunk_z = int(floor(world_pos.z / chunk_size))
	var chunk_pos = Vector2i(chunk_x, chunk_z)
	
	return loaded_chunks.get(chunk_pos, null)

func get_terrain_height(world_pos: Vector3) -> float:
	var chunk = get_chunk_at_position(world_pos)
	if chunk:
		return chunk.get_world_height(world_pos.x, world_pos.z)
	return 0.0

func get_biome_at(world_pos: Vector3) -> int:
	## Returns biome type at a world position, or -1 if unavailable.
	if noise_util and noise_util.has_method("get_biome_type"):
		return noise_util.get_biome_type(world_pos.x, world_pos.z)
	return -1

func set_view_distance(new_distance: int) -> void:
	view_distance = max(1, new_distance)

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

func force_update() -> void:
	# Queue all visible chunks for async streaming
	_update_visible_chunks()
	
	# Synchronously generate only the immediate 3x3 around spawn (Y=0 column)
	# so the player has solid ground to land on. The rest streams in via _process.
	var origin_chunk = Vector2i(0, 0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cp = origin_chunk + Vector2i(dx, dz)
			if not loaded_chunks.has(cp):
				generation_queue.erase(cp)
				pending_chunks.erase(cp)
				var chunk_data = _generate_chunk_data(cp)
				if chunk_data:
					loaded_chunks[cp] = chunk_data
					_create_chunk_mesh(chunk_data)
					restore_tilled_plots_for_chunk(chunk_data)
					emit_signal("chunk_loaded", cp)
	
	print("Force update: spawn area ready, ", loaded_chunks.size(), " chunks loaded, ",
		generation_queue.size(), " queued for streaming")

func clear_all_chunks() -> void:
	for chunk_pos in loaded_chunks.keys():
		_unload_chunk(chunk_pos)
	
	loaded_chunks.clear()
	pending_chunks.clear()
	generation_queue.clear()

# =====================
# TERRAIN MODIFICATION
# =====================

const FarmPlotScene = preload("res://src/world/crops/farm_plot.tscn")

# Active dynamic farm plots: { "wx,wz" -> FarmPlot node }
var dynamic_farm_plots: Dictionary = {}

func world_to_chunk_local(world_pos: Vector3) -> Dictionary:
	var chunk_x = int(floor(world_pos.x / chunk_size))
	var chunk_z = int(floor(world_pos.z / chunk_size))
	var chunk_pos = Vector2i(chunk_x, chunk_z)
	var local_x = int(floor(world_pos.x)) - chunk_x * chunk_size
	var local_z = int(floor(world_pos.z)) - chunk_z * chunk_size
	return {"chunk_pos": chunk_pos, "local_x": local_x, "local_z": local_z}

func modify_terrain_at(world_pos: Vector3, mod_type: int) -> bool:
	var info = world_to_chunk_local(world_pos)
	var chunk = loaded_chunks.get(info.chunk_pos, null) as ChunkData
	if not chunk:
		return false
	
	var lx: int = info.local_x
	var lz: int = info.local_z
	
	# Don't modify if already modified with same type
	if chunk.get_tile_mod(lx, lz) == mod_type:
		return false
	
	# Don't till/dig on water
	var biome = chunk.get_biome(lx, lz)
	if biome == 0 or biome == 1:  # Water or Beach
		return false
	
	# Don't till if there's an object here
	var cell_world = Vector3(
		chunk.world_position.x + lx + 0.5,
		chunk.get_surface_world_y(lx, lz),
		chunk.world_position.z + lz + 0.5
	)
	if chunk.has_object_at(cell_world, 0.8):
		return false
	
	# Apply modification
	chunk.set_tile_mod(lx, lz, mod_type)
	
	# Rebuild chunk mesh to show visual change
	_rebuild_chunk_mesh(chunk)
	
	# Spawn farm plot for tilled cells
	if mod_type == ChunkData.TileMod.TILLED:
		_spawn_farm_plot_at(cell_world)
	
	return true

func _rebuild_chunk_mesh(chunk: ChunkData) -> void:
	var mesh_name = "Chunk_%d_%d" % [chunk.chunk_position.x, chunk.chunk_position.y]
	if not terrain_container:
		return
	var old_mesh = terrain_container.get_node_or_null(mesh_name)
	if not old_mesh:
		return
	# Preserve child objects (trees, rocks, etc.)
	var children_to_keep: Array[Node] = []
	for child in old_mesh.get_children():
		if child is StaticBody3D: continue # Don't keep the old collision body
		if child.name == "WaterMesh": continue # Water mesh will be recreated
		children_to_keep.append(child)
		old_mesh.remove_child(child)
	old_mesh.queue_free()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.position = chunk.world_position
	_build_heightmap_mesh_into(chunk, mesh_instance)
	terrain_container.add_child(mesh_instance)
	mesh_instance.set_meta("chunk_data", chunk)
	
	# Recreate water mesh
	_create_water_mesh(chunk, mesh_instance)
	
	for child in children_to_keep:
		mesh_instance.add_child(child)
	
	# Rebuild collision
	_create_chunk_collision(chunk, mesh_instance)

func _get_tile_mod_color(mod_type: int) -> Color:
	match mod_type:
		ChunkData.TileMod.TILLED:
			return Color(0.30, 0.20, 0.12)  # Dark tilled soil
		ChunkData.TileMod.DUG:
			return Color(0.35, 0.28, 0.18)  # Dug earth
		ChunkData.TileMod.PATH:
			return Color(0.50, 0.42, 0.30)  # Packed dirt path
		ChunkData.TileMod.FOUNDATION:
			return Color(0.40, 0.38, 0.35)  # Stone-ish foundation
	return Color(0.3, 0.5, 0.2)

func _spawn_farm_plot_at(world_pos: Vector3) -> void:
	var key = "%d,%d" % [int(floor(world_pos.x)), int(floor(world_pos.z))]
	if dynamic_farm_plots.has(key):
		return  # Already has a plot here
	
	var plot = FarmPlotScene.instantiate() as FarmPlot
	plot.global_position = Vector3(world_pos.x, world_pos.y + 0.05, world_pos.z)
	
	# Start as tilled (terrain is already tilled visually)
	plot.state = FarmPlot.PlotState.TILLED
	
	# Set up references
	var crop_db = get_node_or_null("/root/CropDatabase")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if crop_db:
		plot.crop_database = crop_db
	if item_db:
		plot.item_database = item_db
	
	# Add to scene
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(plot)
		dynamic_farm_plots[key] = plot
		print("[Terrain] Spawned farm plot at ", world_pos)

func _remove_farm_plots_for_chunk(chunk: ChunkData) -> void:
	var keys_to_remove := []
	for key in dynamic_farm_plots:
		var parts = key.split(",")
		var wx = int(parts[0])
		var wz = int(parts[1])
		var cx = int(floor(float(wx) / chunk_size))
		var cz = int(floor(float(wz) / chunk_size))
		if cx == chunk.chunk_position.x and cz == chunk.chunk_position.y:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		var plot = dynamic_farm_plots[key]
		if is_instance_valid(plot):
			plot.queue_free()
		dynamic_farm_plots.erase(key)

func remove_farm_plot_at(world_pos: Vector3) -> void:
	var key = "%d,%d" % [int(floor(world_pos.x)), int(floor(world_pos.z))]
	if dynamic_farm_plots.has(key):
		var plot = dynamic_farm_plots[key]
		if is_instance_valid(plot):
			plot.queue_free()
		dynamic_farm_plots.erase(key)

func get_tile_mod_at(world_pos: Vector3) -> int:
	var info = world_to_chunk_local(world_pos)
	var chunk = loaded_chunks.get(info.chunk_pos, null) as ChunkData
	if not chunk:
		return ChunkData.TileMod.NONE
	return chunk.get_tile_mod(info.local_x, info.local_z)

func restore_tilled_plots_for_chunk(chunk: ChunkData) -> void:
	var tilled = chunk.get_all_tilled_positions()
	for pos in tilled:
		_spawn_farm_plot_at(pos)

func _exit_tree() -> void:
	# Save all modified chunks on exit
	for chunk_pos in loaded_chunks.keys():
		var chunk = loaded_chunks[chunk_pos]
		if chunk.is_modified:
			_save_chunk(chunk)
	
	clear_all_chunks()

const DIG_DEPTH: float = 0.6
const DIG_RADIUS: int = 1

func dig_terrain_at(world_pos: Vector3) -> bool:
	## Called by player shovel swing. Digs a bowl-shaped depression in a 3x3 area.
	## Center is lowered by DIG_DEPTH; cosine falloff blends edges to unchanged terrain.
	## Works in world space so it correctly crosses chunk boundaries.
	var center_info = world_to_chunk_local(world_pos)
	var center_chunk = loaded_chunks.get(center_info.chunk_pos, null) as ChunkData
	if not center_chunk:
		return false

	# Idempotency: skip if center is already dug
	if center_chunk.get_tile_mod(center_info.local_x, center_info.local_z) == ChunkData.TileMod.DUG:
		return false

	var base_wx := int(floor(world_pos.x))
	var base_wz := int(floor(world_pos.z))

	# Pass 1: validate all 9 cells — reject water/beach biome and objects
	for dz in range(-DIG_RADIUS, DIG_RADIUS + 1):
		for dx in range(-DIG_RADIUS, DIG_RADIUS + 1):
			var sample = world_to_chunk_local(Vector3(base_wx + dx, 0, base_wz + dz))
			var c = loaded_chunks.get(sample.chunk_pos, null) as ChunkData
			if not c:
				return false
			var biome = c.get_biome(sample.local_x, sample.local_z)
			if biome == 0 or biome == 1:  # Water or Beach
				return false
			var cell_world = Vector3(
				c.world_position.x + sample.local_x + 0.5,
				c.get_surface_world_y(sample.local_x, sample.local_z),
				c.world_position.z + sample.local_z + 0.5
			)
			if c.has_object_at(cell_world, 0.8):
				return false

	# Pass 2: apply cosine-falloff bowl depression, mark DUG, track dirty chunks
	var max_dist := sqrt(2.0)  # corner distance
	var dirty_chunks: Dictionary = {}
	for dz in range(-DIG_RADIUS, DIG_RADIUS + 1):
		for dx in range(-DIG_RADIUS, DIG_RADIUS + 1):
			var dist = sqrt(float(dx * dx + dz * dz))
			var depth_factor = cos(dist / max_dist * PI / 2.0)
			if depth_factor < 0.08:
				continue  # corners barely change — leave untouched
			var sample = world_to_chunk_local(Vector3(base_wx + dx, 0, base_wz + dz))
			var c = loaded_chunks.get(sample.chunk_pos, null) as ChunkData
			if c:
				var old_h = c.get_height(sample.local_x, sample.local_z)
				c.set_height(sample.local_x, sample.local_z, old_h - DIG_DEPTH * depth_factor)
				c.set_tile_mod(sample.local_x, sample.local_z, ChunkData.TileMod.DUG)
				dirty_chunks[sample.chunk_pos] = c

	for c in dirty_chunks.values():
		_rebuild_chunk_mesh(c)

	return true
