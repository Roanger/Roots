extends Resource
class_name ChunkData

## Represents a single chunk of terrain data

@export var chunk_position: Vector2i = Vector2i.ZERO
@export var world_position: Vector3 = Vector3.ZERO
@export var size: int = 32
@export var height_scale: float = 1.0

# Terrain data arrays
var heights: PackedFloat32Array = PackedFloat32Array()
var biomes: PackedByteArray = PackedByteArray()
var materials: PackedByteArray = PackedByteArray()

# Object placement data
var tree_positions: Array[Vector3] = []
var rock_positions: Array[Vector3] = []
var prop_positions: Array[Dictionary] = []

# Modification tracking
var is_modified: bool = false
var last_saved: float = 0.0

func _init() -> void:
	pass

func initialize(chunk_pos: Vector2i, chunk_size: int, chunk_height_scale: float) -> void:
	chunk_position = chunk_pos
	size = chunk_size
	height_scale = chunk_height_scale
	
	# Calculate world position
	var offset = Vector2(chunk_pos.x, chunk_pos.y) * size
	world_position = Vector3(offset.x, 0, offset.y)
	
	# Initialize arrays
	var total_points = (size + 1) * (size + 1)
	heights.resize(total_points)
	biomes.resize(total_points)
	materials.resize(total_points)
	
	heights.fill(0.0)
	biomes.fill(0)
	materials.fill(0)

func get_height(x: int, z: int) -> float:
	var index = z * (size + 1) + x
	if index >= 0 and index < heights.size():
		return heights[index]
	return 0.0

func set_height(x: int, z: int, value: float) -> void:
	var index = z * (size + 1) + x
	if index >= 0 and index < heights.size():
		heights[index] = value
		is_modified = true

func get_biome(x: int, z: int) -> int:
	var index = z * (size + 1) + x
	if index >= 0 and index < biomes.size():
		return biomes[index]
	return 0

func set_biome(x: int, z: int, value: int) -> void:
	var index = z * (size + 1) + x
	if index >= 0 and index < biomes.size():
		biomes[index] = value
		is_modified = true

func get_material(x: int, z: int) -> int:
	var index = z * (size + 1) + x
	if index >= 0 and index < materials.size():
		return materials[index]
	return 0

func set_material(x: int, z: int, value: int) -> void:
	var index = z * (size + 1) + x
	if index >= 0 and index < materials.size():
		materials[index] = value
		is_modified = true

func get_world_height(world_x: float, world_z: float) -> float:
	# Convert world coordinates to local chunk coordinates
	var local_x = world_x - world_position.x
	var local_z = world_z - world_position.z
	
	# Get the four corners for bilinear interpolation
	var x0 = int(local_x)
	var z0 = int(local_z)
	var x1 = min(x0 + 1, size)
	var z1 = min(z0 + 1, size)
	
	var h00 = get_height(x0, z0)
	var h10 = get_height(x1, z0)
	var h01 = get_height(x0, z1)
	var h11 = get_height(x1, z1)
	
	# Bilinear interpolation
	var fx = local_x - x0
	var fz = local_z - z0
	
	var h0 = lerp(h00, h10, fx)
	var h1 = lerp(h01, h11, fx)
	
	return lerp(h0, h1, fz)

func add_tree(position: Vector3) -> void:
	tree_positions.append(position)
	is_modified = true

func add_rock(position: Vector3) -> void:
	rock_positions.append(position)
	is_modified = true

func add_prop(data: Dictionary) -> void:
	prop_positions.append(data)
	is_modified = true

func has_object_at(world_pos: Vector3, radius: float = 0.5) -> bool:
	# Check tree positions
	for tree_pos in tree_positions:
		if tree_pos.distance_to(world_pos) < radius:
			return true
	
	# Check rock positions
	for rock_pos in rock_positions:
		if rock_pos.distance_to(world_pos) < radius:
			return true
	
	# Check props
	for prop in prop_positions:
		var prop_pos = prop.get("position", Vector3.ZERO)
		if prop_pos.distance_to(world_pos) < radius:
			return true
	
	return false

func serialize() -> Dictionary:
	return {
		"chunk_position": {"x": chunk_position.x, "y": chunk_position.y},
		"size": size,
		"height_scale": height_scale,
		"heights": Array(heights),
		"biomes": Array(biomes),
		"materials": Array(materials),
		"tree_positions": tree_positions,
		"rock_positions": rock_positions,
		"prop_positions": prop_positions,
		"timestamp": Time.get_unix_time_from_system()
	}

func deserialize(data: Dictionary) -> void:
	if data.has("chunk_position"):
		chunk_position = Vector2i(data.chunk_position.x, data.chunk_position.y)
	
	size = data.get("size", 32)
	height_scale = data.get("height_scale", 1.0)
	
	if data.has("heights"):
		heights = PackedFloat32Array(data.heights)
	if data.has("biomes"):
		biomes = PackedByteArray(data.biomes)
	if data.has("materials"):
		materials = PackedByteArray(data.materials)
	
	if data.has("tree_positions"):
		tree_positions = []
		for pos in data.tree_positions:
			tree_positions.append(Vector3(pos.x, pos.y, pos.z))
	
	if data.has("rock_positions"):
		rock_positions = []
		for pos in data.rock_positions:
			rock_positions.append(Vector3(pos.x, pos.y, pos.z))
	
	if data.has("prop_positions"):
		prop_positions = data.prop_positions
	
	is_modified = false
	last_saved = Time.get_unix_time_from_system()

func clear_objects() -> void:
	tree_positions.clear()
	rock_positions.clear()
	prop_positions.clear()
	is_modified = true

func get_center() -> Vector3:
	return world_position + Vector3(size / 2.0, 0, size / 2.0)

func contains_point(point: Vector3) -> bool:
	var min_x = world_position.x
	var max_x = world_position.x + size
	var min_z = world_position.z
	var max_z = world_position.z + size
	
	return point.x >= min_x and point.x < max_x and point.z >= min_z and point.z < max_z
