extends Resource
class_name ChunkData

## Data container for a single 2D heightmap chunk.

@export var chunk_position: Vector2i = Vector2i.ZERO
@export var world_position: Vector3 = Vector3.ZERO
@export var size: int = 32

# 2D Heightmap grid: flat PackedFloat32Array, index = x + z*size
var heights: PackedFloat32Array = PackedFloat32Array()

# Per-column biome (surface biome, indexed x + z*size)
var biomes: PackedByteArray = PackedByteArray()

# Object placement data
var tree_positions: Array[Vector3] = []
var rock_positions: Array[Vector3] = []
var prop_positions: Array[Dictionary] = []

# Terrain tile modifications: { "x,z" -> TileMod enum value }
enum TileMod {
	NONE = 0,
	TILLED = 1,
	DUG = 2,
	PATH = 3,
	FOUNDATION = 4
}
var tile_modifications: Dictionary = {}

# Modification tracking
var is_modified: bool = false
var last_saved: float = 0.0

func _init() -> void:
	pass

func initialize(chunk_pos: Vector2i, chunk_size: int, _height_scale: float = 1.0) -> void:
	chunk_position = chunk_pos
	size = chunk_size
	var offset = Vector2(chunk_pos.x, chunk_pos.y) * size
	world_position = Vector3(offset.x, 0.0, offset.y)
	heights.resize(size * size)
	heights.fill(0.0)
	biomes.resize(size * size)
	biomes.fill(0)
	is_modified = false  # Don't count initial allocation as a modification

# ── Heightmap access ────────────────────────────────────────────────────────
func _height_index(x: int, z: int) -> int:
	return x + z * size

func get_height(x: int, z: int) -> float:
	if x < 0 or x >= size or z < 0 or z >= size:
		return 0.0
	return heights[_height_index(x, z)]

func set_height(x: int, z: int, h: float) -> void:
	if x < 0 or x >= size or z < 0 or z >= size:
		return
	heights[_height_index(x, z)] = h
	is_modified = true

func get_surface_world_y(x: int, z: int) -> float:
	return get_height(x, z)

func get_world_height(world_x: float, world_z: float) -> float:
	## Query surface height at arbitrary world XZ.
	var lx = int(world_x - world_position.x)
	var lz = int(world_z - world_position.z)
	lx = clampi(lx, 0, size - 1)
	lz = clampi(lz, 0, size - 1)
	return get_height(lx, lz)

# ── Terrain Modification ──────────────────────────────────────────────────────
func set_height_at(local_x: int, local_z: int, h: float) -> void:
	set_height(local_x, local_z, h)

# ── Biome access ──────────────────────────────────────────────────────────────
func get_biome(x: int, z: int) -> int:
	var idx = x + z * size
	if idx >= 0 and idx < biomes.size():
		return biomes[idx]
	return 0

func set_biome(x: int, z: int, value: int) -> void:
	var idx = x + z * size
	if idx >= 0 and idx < biomes.size():
		biomes[idx] = value

# ── Object placement ──────────────────────────────────────────────────────────
func add_tree(position: Vector3) -> void:
	tree_positions.append(position)
	is_modified = true

func add_rock(position: Vector3) -> void:
	rock_positions.append(position)
	is_modified = true

func add_prop(data: Dictionary) -> void:
	prop_positions.append(data)
	is_modified = true

# ── Tile modifications ────────────────────────────────────────────────────────
func set_tile_mod(local_x: int, local_z: int, mod_type: int) -> void:
	var key = "%d,%d" % [local_x, local_z]
	if mod_type == TileMod.NONE:
		tile_modifications.erase(key)
	else:
		tile_modifications[key] = mod_type
	is_modified = true

func get_tile_mod(local_x: int, local_z: int) -> int:
	var key = "%d,%d" % [local_x, local_z]
	return tile_modifications.get(key, TileMod.NONE)

func has_tile_mod(local_x: int, local_z: int) -> bool:
	var key = "%d,%d" % [local_x, local_z]
	return tile_modifications.has(key)

func get_all_tilled_positions() -> Array:
	var result := []
	for key in tile_modifications:
		if tile_modifications[key] == TileMod.TILLED:
			var parts = key.split(",")
			var lx = int(parts[0])
			var lz = int(parts[1])
			var wx = world_position.x + lx + 0.5
			var wz = world_position.z + lz + 0.5
			var h = get_surface_world_y(lx, lz)
			result.append(Vector3(wx, h, wz))
	return result

func has_object_at(world_pos: Vector3, radius: float = 0.5) -> bool:
	for tree_pos in tree_positions:
		if tree_pos.distance_to(world_pos) < radius:
			return true
	for rock_pos in rock_positions:
		if rock_pos.distance_to(world_pos) < radius:
			return true
	for prop in prop_positions:
		var prop_pos = prop.get("position", Vector3.ZERO)
		if prop_pos.distance_to(world_pos) < radius:
			return true
	return false

# ── Serialization ─────────────────────────────────────────────────────────────
func _vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}

func _dict_to_vec3(d) -> Vector3:
	if d is Dictionary:
		return Vector3(d.x, d.y, d.z)
	if d is Vector3:
		return d
	return Vector3.ZERO

func serialize() -> Dictionary:
	var trees: Array = []
	for pos in tree_positions:
		trees.append(_vec3_to_dict(pos))
	var rocks: Array = []
	for pos in rock_positions:
		rocks.append(_vec3_to_dict(pos))
	return {
		"chunk_position": {"x": chunk_position.x, "y": chunk_position.y},
		"size": size,
		"heights": Array(heights),
		"biomes": Array(biomes),
		"tree_positions": trees,
		"rock_positions": rocks,
		"prop_positions": prop_positions,
		"tile_modifications": tile_modifications,
		"timestamp": Time.get_unix_time_from_system()
	}

func deserialize(data: Dictionary) -> void:
	if data.has("chunk_position"):
		chunk_position = Vector2i(data.chunk_position.x, data.chunk_position.y)
	size = data.get("size", 32)
	var offset = Vector2(chunk_position.x, chunk_position.y) * size
	world_position = Vector3(offset.x, 0.0, offset.y)
	if data.has("heights"):
		heights = PackedFloat32Array(data.heights)
	else:
		heights.resize(size * size)
		heights.fill(0.0)
	if data.has("biomes"):
		biomes = PackedByteArray(data.biomes)
	else:
		biomes.resize(size * size)
		biomes.fill(0)
	if data.has("tree_positions"):
		tree_positions = []
		for pos in data.tree_positions:
			tree_positions.append(_dict_to_vec3(pos))
	if data.has("rock_positions"):
		rock_positions = []
		for pos in data.rock_positions:
			rock_positions.append(_dict_to_vec3(pos))
	if data.has("prop_positions"):
		prop_positions = []
		for prop in data.prop_positions:
			if prop is Dictionary:
				prop_positions.append(prop)
	if data.has("tile_modifications"):
		tile_modifications = data.tile_modifications
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
	return point.x >= world_position.x and point.x < world_position.x + size \
		and point.z >= world_position.z and point.z < world_position.z + size
