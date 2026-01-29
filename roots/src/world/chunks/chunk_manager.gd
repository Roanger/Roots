extends Node
## Manages chunk loading/unloading based on player position

signal chunk_loaded(chunk_pos: Vector2i)
signal chunk_unloaded(chunk_pos: Vector2i)
signal chunk_mesh_updated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var view_distance: int = 4
@export var height_scale: float = 1.0
@export var generate_objects: bool = true
@export var save_chunks: bool = true

var loaded_chunks: Dictionary = {}  # Vector2i -> ChunkData
var chunk_cache: Dictionary = {}  # For pending chunk generation
var active_chunks: Dictionary = {}  # Currently visible chunks

var noise_util: Node = null
var player_node: Node3D = null
var terrain_container: Node3D = null

# Explicit reference to autoload
@onready var game_manager: Node = get_node_or_null("/root/GameManager")

# Update timing
var update_interval: float = 0.5
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

func _process(delta: float) -> void:
	if not player_node:
		# Try to find player
		player_node = get_tree().get_first_node_in_group("player")
		return
	
	# Update chunks based on player position
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_update_time >= update_interval and not is_updating:
		last_update_time = current_time
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
			
			# Calculate distance for circular view distance
			var distance = Vector2(x, z).length()
			if distance <= view_distance:
				if not loaded_chunks.has(chunk_pos):
					chunks_to_load.append(chunk_pos)
	
	# Find chunks to unload
	for chunk_pos in loaded_chunks.keys():
		var chunk_center = chunk_pos * chunk_size
		var player_pos = Vector2(player_node.global_position.x, player_node.global_position.z)
		var chunk_center_vec = Vector2(chunk_center.x + chunk_size / 2.0, chunk_center.y + chunk_size / 2.0)
		
		if player_pos.distance_to(chunk_center_vec) > (view_distance + 2) * chunk_size:
			chunks_to_unload.append(chunk_pos)
	
	# Queue chunks for generation
	for chunk_pos in chunks_to_load:
		if not pending_chunks.has(chunk_pos):
			pending_chunks[chunk_pos] = true
			generation_queue.append(chunk_pos)
	
	# Process generation queue
	_process_generation_queue()
	
	# Unload old chunks
	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)
	
	is_updating = false

func _process_generation_queue() -> void:
	while generation_queue.size() > 0:
		var chunk_pos = generation_queue.pop_front()
		
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
			if randf() > object_density:
				continue
			
			var world_x = chunk.world_position.x + x + 0.5
			var world_z = chunk.world_position.z + z + 0.5
			var height = chunk.get_height(x, z)
			
			var biome = chunk.get_biome(x, z)
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
	
	if not terrain_container:
		return
	
	# Create mesh instance for this chunk
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Chunk_%d_%d" % [chunk.chunk_position.x, chunk.chunk_position.y]
	mesh_instance.position = chunk.world_position
	
	# Create surface tool for mesh generation
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Generate terrain mesh
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
			
			# Create quad (two triangles)
			var v0 = Vector3(x, h00, z)
			var v1 = Vector3(x + 1, h10, z)
			var v2 = Vector3(x, h01, z + 1)
			var v3 = Vector3(x + 1, h11, z + 1)
			
			# Calculate normals
			var normal = (v1 - v0).cross(v2 - v0).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(x, z) / float(chunk.size))
			st.set_color(_get_biome_color(biome00))
			st.add_vertex(v0)
			
			normal = (v2 - v1).cross(v0 - v1).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(x + 1, z) / float(chunk.size))
			st.set_color(_get_biome_color(biome10))
			st.add_vertex(v1)
			
			normal = (v3 - v2).cross(v1 - v2).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(x, z + 1) / float(chunk.size))
			st.set_color(_get_biome_color(biome01))
			st.add_vertex(v2)
			
			normal = (v3 - v1).cross(v2 - v1).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(x + 1, z + 1) / float(chunk.size))
			st.set_color(_get_biome_color(biome11))
			st.add_vertex(v3)
			
			normal = (v3 - v2).cross(v1 - v2).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(x + 1, z) / float(chunk.size))
			st.set_color(_get_biome_color(biome10))
			st.add_vertex(v1)
			
			normal = (v3 - v2).cross(v1 - v2).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(x, z + 1) / float(chunk.size))
			st.set_color(_get_biome_color(biome01))
			st.add_vertex(v2)
	
	st.generate_normals()
	var mesh = st.commit()
	mesh_instance.mesh = mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh_instance.material_override = material
	
	terrain_container.add_child(mesh_instance)
	
	# Store reference to chunk data
	mesh_instance.set_meta("chunk_data", chunk)
	
	# Create object instances
	_create_chunk_objects(chunk, mesh_instance)

func _create_chunk_objects(chunk: ChunkData, parent: Node) -> void:
	# Create tree instances
	for tree_pos in chunk.tree_positions:
		# Convert world position to local position relative to chunk
		var local_pos = tree_pos - chunk.world_position
		var tree = _create_tree_mesh(local_pos)
		if tree:
			parent.add_child(tree)
	
	# Create rock instances
	for rock_pos in chunk.rock_positions:
		# Convert world position to local position relative to chunk
		var local_pos = rock_pos - chunk.world_position
		var rock = _create_rock_mesh(local_pos)
		if rock:
			parent.add_child(rock)

func _create_tree_mesh(pos: Vector3) -> Node3D:
	var tree_container = Node3D.new()
	tree_container.name = "Tree"
	tree_container.position = pos
	
	# Trunk mesh
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
	
	# Leaves mesh
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
	
	# Collision body for trunk
	var static_body = StaticBody3D.new()
	static_body.name = "Collision"
	static_body.collision_layer = 2  # Environment layer
	static_body.collision_mask = 0   # Doesn't need to detect collisions
	
	var collision_shape = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 2.0
	collision_shape.shape = trunk_shape
	collision_shape.position.y = 1.0
	
	static_body.add_child(collision_shape)
	tree_container.add_child(static_body)
	
	return tree_container

func _create_rock_mesh(pos: Vector3) -> Node3D:
	var rock_container = Node3D.new()
	rock_container.name = "Rock"
	rock_container.position = pos
	
	var radius = randf_range(0.3, 0.6)
	
	# Rock mesh
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
	
	# Collision body
	var static_body = StaticBody3D.new()
	static_body.name = "Collision"
	static_body.collision_layer = 2  # Environment layer
	static_body.collision_mask = 0   # Doesn't need to detect collisions
	
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	static_body.add_child(collision_shape)
	rock_container.add_child(static_body)
	
	return rock_container

func _get_biome_color(biome: int) -> Color:
	match biome:
		0: return Color(0.2, 0.3, 0.7)  # Water
		1: return Color(0.76, 0.7, 0.5)  # Beach
		2: return Color(0.5, 0.7, 0.2)  # Plains (dry)
		3: return Color(0.25, 0.55, 0.2)  # Forest
		4: return Color(0.15, 0.45, 0.15)  # Jungle
		5: return Color(0.35, 0.45, 0.35)  # Taiga
		6: return Color(0.5, 0.45, 0.4)  # Mountains
		7: return Color(0.9, 0.9, 1.0)  # Snow
		_: return Color(0.3, 0.5, 0.2)

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
	var chunk_data = chunk.serialize()
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
	last_update_time = 0.0

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
