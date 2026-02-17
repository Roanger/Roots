extends Resource
class_name ChunkData

## Voxel-based chunk data. Each chunk is SIZE x CHUNK_HEIGHT x SIZE voxels.
## Voxel grid index: x + z * SIZE + y * SIZE * SIZE
## World Y = world_position.y + VOXEL_Y_OFFSET + local_y

# ── Voxel type constants ──────────────────────────────────────────────────────
const VOXEL_AIR:       int = 0
const VOXEL_GRASS:     int = 1
const VOXEL_DIRT:      int = 2
const VOXEL_STONE:     int = 3
const VOXEL_DEEP_ROCK: int = 4
const VOXEL_BEDROCK:   int = 5
const VOXEL_SAND:      int = 6
const VOXEL_SNOW:      int = 7
const VOXEL_ORE_COAL:  int = 9
const VOXEL_ORE_COPPER:int = 10
const VOXEL_ORE_IRON:  int = 11
const VOXEL_ORE_GOLD:  int = 12
const VOXEL_ORE_MYTHRIL:int = 13

# ── Chunk dimensions ──────────────────────────────────────────────────────────
const CHUNK_HEIGHT: int = 145  # Local Y 0..144 → world Y -80..+64 (covers full terrain range)
const VOXEL_Y_OFFSET: int = -80  # Local Y 0 = world Y -80 (bedrock floor)

@export var chunk_position: Vector2i = Vector2i.ZERO
@export var world_position: Vector3 = Vector3.ZERO
@export var size: int = 32

# 3D voxel grid: flat PackedByteArray, index = x + z*size + y*size*size
var voxels: PackedByteArray = PackedByteArray()

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
	voxels.resize(size * size * CHUNK_HEIGHT)
	voxels.fill(VOXEL_AIR)
	biomes.resize(size * size)
	biomes.fill(0)
	is_modified = false  # Don't count initial allocation as a modification

# ── Voxel access ──────────────────────────────────────────────────────────────
func _voxel_index(x: int, y: int, z: int) -> int:
	return x + z * size + y * size * size

func get_voxel(x: int, y: int, z: int) -> int:
	if x < 0 or x >= size or z < 0 or z >= size or y < 0 or y >= CHUNK_HEIGHT:
		return VOXEL_AIR
	return voxels[_voxel_index(x, y, z)]

func set_voxel(x: int, y: int, z: int, type: int) -> void:
	if x < 0 or x >= size or z < 0 or z >= size or y < 0 or y >= CHUNK_HEIGHT:
		return
	voxels[_voxel_index(x, y, z)] = type
	is_modified = true

func is_solid(x: int, y: int, z: int) -> bool:
	return get_voxel(x, y, z) != VOXEL_AIR

# ── World ↔ local Y conversion ────────────────────────────────────────────────
func world_y_to_local(world_y: float) -> int:
	return int(world_y) - VOXEL_Y_OFFSET

func local_y_to_world(local_y: int) -> float:
	return float(local_y + VOXEL_Y_OFFSET)

# ── Surface height query (top solid voxel in column) ─────────────────────────
func get_surface_local_y(x: int, z: int) -> int:
	## Returns the local Y of the topmost solid voxel in column (x,z), or -1 if all air.
	for y in range(CHUNK_HEIGHT - 1, -1, -1):
		if get_voxel(x, y, z) != VOXEL_AIR:
			return y
	return -1

func get_surface_world_y(x: int, z: int) -> float:
	## Returns the world Y of the TOP of the topmost solid voxel (i.e. standing height).
	var ly = get_surface_local_y(x, z)
	if ly < 0:
		return float(VOXEL_Y_OFFSET)
	return local_y_to_world(ly) + 1.0  # +1 = top face of the voxel

func get_world_height(world_x: float, world_z: float) -> float:
	## Query surface height at arbitrary world XZ (used by player grounding).
	var lx = int(world_x - world_position.x)
	var lz = int(world_z - world_position.z)
	lx = clampi(lx, 0, size - 1)
	lz = clampi(lz, 0, size - 1)
	return get_surface_world_y(lx, lz)

# ── Digging ───────────────────────────────────────────────────────────────────
func dig_at(local_x: int, local_z: int) -> bool:
	## Remove the topmost solid voxel in column (x,z). Returns true if something was dug.
	var ly = get_surface_local_y(local_x, local_z)
	if ly < 0:
		return false
	set_voxel(local_x, ly, local_z, VOXEL_AIR)
	set_tile_mod(local_x, local_z, TileMod.DUG)
	return true

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
func serialize() -> Dictionary:
	return {
		"chunk_position": {"x": chunk_position.x, "y": chunk_position.y},
		"size": size,
		"voxels": Array(voxels),
		"biomes": Array(biomes),
		"tree_positions": tree_positions,
		"rock_positions": rock_positions,
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
	if data.has("voxels"):
		voxels = PackedByteArray(data.voxels)
	else:
		voxels.resize(size * size * CHUNK_HEIGHT)
		voxels.fill(VOXEL_AIR)
	if data.has("biomes"):
		biomes = PackedByteArray(data.biomes)
	else:
		biomes.resize(size * size)
		biomes.fill(0)
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
