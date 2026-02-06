extends Node
## Manages chunk loading/unloading based on player position

const HarvestableResource = preload("res://src/world/harvestable_resource.gd")

signal chunk_loaded(chunk_pos: Vector2i)
signal chunk_unloaded(chunk_pos: Vector2i)
signal chunk_mesh_updated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var view_distance: int = 20
@export var height_scale: float = 1.0
@export var generate_objects: bool = true
@export var save_chunks: bool = true

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
# Terrain ground shader (vertex color + procedural detail, no assets)
var _terrain_ground_shader: Shader = null

# Explicit reference to autoload
@onready var game_manager: Node = get_node_or_null("/root/GameManager")

# Update timing
var update_interval: float = 0.1
var last_update_time: float = 0.0
var is_updating: bool = false

# Multithreading
var thread: Thread = null
var mutex: Mutex = Mutex.new()
var generation_queue: Array[Vector2i] = []
var pending_chunks: Dictionary = {}  # Vector2i -> ChunkData

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
	# Terrain ground shader: preserves vertex (biome) color, adds solid-ground variation
	_terrain_ground_shader = load("res://src/world/terrain/terrain_ground.gdshader") as Shader

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

func _process_generation_queue() -> void:
	var processed_count = 0
	var max_per_frame = 64
	
	while generation_queue.size() > 0 and processed_count < max_per_frame:
		var chunk_pos = generation_queue.pop_front()
		processed_count += 1
		
		# Generate chunk data
		var chunk_data = _generate_chunk_data(chunk_pos)
		if chunk_data:
			mutex.lock()
			loaded_chunks[chunk_pos] = chunk_data
			pending_chunks.erase(chunk_pos)
			mutex.unlock()
			
			# Create mesh for chunk
			_create_chunk_mesh(chunk_data)
			emit_signal("chunk_loaded", chunk_pos)

func _generate_chunk_data(chunk_pos: Vector2i) -> ChunkData:
	var chunk = ChunkData.new()
	chunk.initialize(chunk_pos, chunk_size, height_scale)
	
	# Generate heightmap using noise
	for z in range(chunk.size + 1):
		for x in range(chunk.size + 1):
			var world_x = chunk.world_position.x + x
			var world_z = chunk.world_position.z + z
			
			var height = noise_util.get_terrain_height(world_x, world_z)
			chunk.set_height(x, z, height)
			
			var biome = noise_util.get_biome_type(world_x, world_z)
			chunk.set_biome(x, z, biome)
	
	# Generate objects if enabled
	if generate_objects:
		_generate_chunk_objects(chunk)
	
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
			var height = chunk.get_height(x, z)
			
			var _biome = chunk.get_biome(x, z)
			var tree_density = noise_util.get_tree_density(world_x, world_z)
			var rock_density = noise_util.get_rock_density(world_x, world_z)
			
			var world_pos = Vector3(world_x, height, world_z)
			
			# Determine if this is a valid spot (not underwater, etc.)
			if height < noise_util.get_water_level() - 1.0:
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
	
	# Create mesh instance for this chunk
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Chunk_%d_%d" % [chunk.chunk_position.x, chunk.chunk_position.y]
	mesh_instance.position = chunk.world_position
	
	# Create surface tool for mesh generation
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# World origin for noise sampling (vertex color variation)
	var world_ox = chunk.world_position.x
	var world_oz = chunk.world_position.z
	# Generate terrain mesh with biome + grass color variation
	for z in range(chunk.size):
		for x in range(chunk.size):
			var h00 = chunk.get_height(x, z)
			var h10 = chunk.get_height(x + 1, z)
			var h01 = chunk.get_height(x, z + 1)
			var h11 = chunk.get_height(x + 1, z + 1)
			
			var biome00 = chunk.get_biome(x, z)
			var biome10 = chunk.get_biome(x + 1, z)
			var biome01 = chunk.get_biome(x, z + 1)
			var biome11 = chunk.get_biome(x + 1, z + 1)
			
			# Blend biome base color with grass/moisture variation (non-water biomes)
			var c00 = _get_terrain_vertex_color(biome00, world_ox + x, world_oz + z)
			var c10 = _get_terrain_vertex_color(biome10, world_ox + x + 1, world_oz + z)
			var c01 = _get_terrain_vertex_color(biome01, world_ox + x, world_oz + z + 1)
			var c11 = _get_terrain_vertex_color(biome11, world_ox + x + 1, world_oz + z + 1)
			
			# Quad: v0=bl, v1=br, v2=tl, v3=tr. Normals point UP (top face).
			# Uses standard CCW winding and cull_back for opaque terrain rendering.
			var v0 = Vector3(x, h00, z)
			var v1 = Vector3(x + 1, h10, z)
			var v2 = Vector3(x, h01, z + 1)
			var v3 = Vector3(x + 1, h11, z + 1)
			
			# Tri 1: v0, v1, v2 — CCW winding for top face (normal UP)
			# Cross product for Normal UP: (v2 - v0) x (v1 - v0) = (0,0,1) x (1,0,0) = (0,1,0)
			var n1 = (v2 - v0).cross(v1 - v0).normalized()
			st.set_normal(n1)
			st.set_uv(Vector2(x, z) / float(chunk.size))
			st.set_color(c00)
			st.add_vertex(v0)
			st.set_normal(n1)
			st.set_uv(Vector2(x + 1, z) / float(chunk.size))
			st.set_color(c10)
			st.add_vertex(v1)
			st.set_normal(n1)
			st.set_uv(Vector2(x, z + 1) / float(chunk.size))
			st.set_color(c01)
			st.add_vertex(v2)
			
			# Tri 2: v1, v3, v2 — CCW winding for top face (normal UP)
			var n2 = (v2 - v1).cross(v3 - v1).normalized()
			st.set_normal(n2)
			st.set_uv(Vector2(x + 1, z) / float(chunk.size))
			st.set_color(c10)
			st.add_vertex(v1)
			st.set_normal(n2)
			st.set_uv(Vector2(x + 1, z + 1) / float(chunk.size))
			st.set_color(c11)
			st.add_vertex(v3)
			st.set_normal(n2)
			st.set_uv(Vector2(x, z + 1) / float(chunk.size))
			st.set_color(c01)
			st.add_vertex(v2)
	
	# Standard CCW winding for front-facing (top) rendering.
	var mesh = st.commit()
	mesh_instance.mesh = mesh
	
	# Material: shader preserves biome vertex color and adds procedural ground detail (no assets)
	if _terrain_ground_shader:
		var material = ShaderMaterial.new()
		material.shader = _terrain_ground_shader
		mesh_instance.material_override = material
	else:
		# Fallback: default cull_back; mesh normals point up so front face = top
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.9
		mesh_instance.material_override = material
	
	terrain_container.add_child(mesh_instance)
	
	# Store reference to chunk data
	mesh_instance.set_meta("chunk_data", chunk)
	
	# Create object instances (pass seeded RNG for deterministic placement)
	var obj_rng = RandomNumberGenerator.new()
	obj_rng.seed = hash(chunk.chunk_position) + 7919
	_create_chunk_objects(chunk, mesh_instance, obj_rng)

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
		var rock = _create_rock_mesh(local_pos, rng)
		if rock:
			parent.add_child(rock)
	
	# Grass patches on grass-friendly biomes (3D from pack or quad fallback)
	_create_grass_patches(chunk, parent)
	# Bushes (KayKit Forest Nature Pack)
	_create_bush_patches(chunk, parent)
	# Biome-specific decorations
	_create_biome_decorations(chunk, parent)

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
		return _create_tree_mesh_procedural(pos)
	var scene: PackedScene = scenes[rng.randi() % scenes.size()]
	var tree_container: Node3D = scene.instantiate() as Node3D
	if not tree_container:
		return _create_tree_mesh_procedural(pos)
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
	harvestable.loot_table = [
		{"item_id": "wood_log", "min_amount": 2, "max_amount": 4, "chance": 1.0},
		{"item_id": "stick", "min_amount": 1, "max_amount": 3, "chance": 0.7},
	]
	var collision_shape = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.5 * scale_factor
	trunk_shape.height = 3.0 * scale_factor
	collision_shape.shape = trunk_shape
	collision_shape.position.y = 1.5 * scale_factor
	harvestable.add_child(collision_shape)
	tree_container.add_child(harvestable)
	return tree_container

func _create_tree_mesh_procedural(pos: Vector3) -> Node3D:
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
	harvestable.loot_table = [
		{"item_id": "wood_log", "min_amount": 1, "max_amount": 3, "chance": 1.0},
		{"item_id": "stick", "min_amount": 1, "max_amount": 2, "chance": 0.6},
	]
	var collision_shape = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 2.0
	collision_shape.shape = trunk_shape
	collision_shape.position.y = 1.0
	harvestable.add_child(collision_shape)
	tree_container.add_child(harvestable)
	return tree_container

func _create_rock_mesh(pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	if _rock_scenes.is_empty():
		return _create_rock_mesh_procedural(pos)
	var scene: PackedScene = _rock_scenes[rng.randi() % _rock_scenes.size()]
	var rock_container: Node3D = scene.instantiate() as Node3D
	if not rock_container:
		return _create_rock_mesh_procedural(pos)
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
	harvestable.loot_table = [
		{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0},
		{"item_id": "coal", "min_amount": 1, "max_amount": 2, "chance": 0.3},
		{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.2},
		{"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.15},
	]
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	harvestable.add_child(collision_shape)
	rock_container.add_child(harvestable)
	return rock_container

func _create_rock_mesh_procedural(pos: Vector3) -> Node3D:
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
	harvestable.loot_table = [
		{"item_id": "stone", "min_amount": 1, "max_amount": 3, "chance": 1.0},
		{"item_id": "coal", "min_amount": 1, "max_amount": 1, "chance": 0.25},
	]
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
		quad.position = Vector3(lx, height + y_offset, lz)
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
		parent.add_child(node)

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
	
	# Remove chunk mesh
	var mesh_name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	if terrain_container:
		var mesh_instance = terrain_container.get_node_or_null(mesh_name)
		if mesh_instance:
			mesh_instance.queue_free()
	
	loaded_chunks.erase(chunk_pos)
	emit_signal("chunk_unloaded", chunk_pos)

func _save_chunk(chunk: ChunkData) -> void:
	# Save chunk data to disk or cloud
	var _chunk_data = chunk.serialize()
	# TODO: Implement actual saving
	print("Saving chunk: ", chunk.chunk_position)

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

func set_view_distance(new_distance: int) -> void:
	view_distance = max(1, new_distance)

func force_update() -> void:
	# Generate chunks around the spawn point synchronously
	_update_visible_chunks()
	
	# Drain the generation queue completely - this ensures terrain
	# is fully loaded BEFORE the player spawns
	while generation_queue.size() > 0:
		var chunk_pos = generation_queue.pop_front()
		
		# Generate chunk data
		var chunk_data = _generate_chunk_data(chunk_pos)
		if chunk_data:
			loaded_chunks[chunk_pos] = chunk_data
			pending_chunks.erase(chunk_pos)
			
			# Create mesh for chunk
			_create_chunk_mesh(chunk_data)
			emit_signal("chunk_loaded", chunk_pos)
	
	print("Force update complete: ", loaded_chunks.size(), " chunks loaded")

func clear_all_chunks() -> void:
	for chunk_pos in loaded_chunks.keys():
		_unload_chunk(chunk_pos)
	
	loaded_chunks.clear()
	pending_chunks.clear()
	generation_queue.clear()

func _exit_tree() -> void:
	# Save all modified chunks on exit
	for chunk_pos in loaded_chunks.keys():
		var chunk = loaded_chunks[chunk_pos]
		if chunk.is_modified:
			_save_chunk(chunk)
	
	clear_all_chunks()
