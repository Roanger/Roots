extends Node
## Spawns trees, rocks, grass, bushes, and biome decorations per virtual
## 32×32 chunk.  Listens to TerrainService.chunk_loaded/chunk_unloaded signals
## and instantiates FBX scene assets at procedurally placed positions.

const HarvestableResource = preload("res://src/world/harvestable_resource.gd")
const FishingSpot = preload("res://src/world/fishing_spot.gd")

const VIRTUAL_CHUNK_SIZE: int = 32

var terrain_service: Node = null
var world_noise: WorldNoise = null

# Spawned objects keyed by virtual chunk position
var _chunk_objects: Dictionary = {}

# FBX scene pools
var _tree_scenes: Array[PackedScene] = []
var _dead_tree_scenes: Array[PackedScene] = []
var _pine_scenes: Array[PackedScene] = []
var _rock_scenes: Array[PackedScene] = []
var _pebble_scenes: Array[PackedScene] = []
var _forest_grass_scenes: Array[PackedScene] = []
var _bush_scenes: Array[PackedScene] = []
var _flower_scenes: Array[PackedScene] = []
var _fern_scenes: Array[PackedScene] = []
var _mushroom_scenes: Array[PackedScene] = []
var _clover_scenes: Array[PackedScene] = []
var _bush_common_scenes: Array[PackedScene] = []


func _ready() -> void:
	_load_assets()
	terrain_service = get_node_or_null("../ChunkManager")
	if not terrain_service:
		terrain_service = get_tree().get_first_node_in_group("chunk_manager")
	if terrain_service:
		world_noise = terrain_service.world_noise
		if terrain_service.chunk_loaded.is_connected(_on_chunk_loaded):
			terrain_service.chunk_loaded.disconnect(_on_chunk_loaded)
		terrain_service.chunk_loaded.connect(_on_chunk_loaded)
		if terrain_service.chunk_unloaded.is_connected(_on_chunk_unloaded):
			terrain_service.chunk_unloaded.disconnect(_on_chunk_unloaded)
		terrain_service.chunk_unloaded.connect(_on_chunk_unloaded)


func _load_assets() -> void:
	# Trees
	for path in [
		"res://assets/Ultimate_Trees/CommonTree_1.blend", "res://assets/Ultimate_Trees/CommonTree_2.blend",
		"res://assets/Ultimate_Trees/CommonTree_3.blend", "res://assets/Ultimate_Trees/CommonTree_4.blend",
		"res://assets/Ultimate_Trees/CommonTree_5.blend"]:
		var s := load(path) as PackedScene
		if s: _tree_scenes.append(s)
	# Dead trees
	for path in [
		"res://assets/Trees/DeadTree_1.blend", "res://assets/Trees/DeadTree_2.blend",
		"res://assets/Trees/DeadTree_3.blend", "res://assets/Trees/DeadTree_4.blend",
		"res://assets/Trees/DeadTree_5.blend"]:
		var s := load(path) as PackedScene
		if s: _dead_tree_scenes.append(s)
	# Rocks
	for path in [
		"res://assets/Ultimate_Trees/Rock_1.blend", "res://assets/Ultimate_Trees/Rock_2.blend",
		"res://assets/Ultimate_Trees/Rock_3.blend", "res://assets/Ultimate_Trees/Rock_4.blend",
		"res://assets/Ultimate_Trees/Rock_5.blend"]:
		var s := load(path) as PackedScene
		if s: _rock_scenes.append(s)
	# Pine trees
	for path in [
		"res://assets/Ultimate_Trees/PineTree_1.blend", "res://assets/Ultimate_Trees/PineTree_2.blend",
		"res://assets/Ultimate_Trees/PineTree_3.blend", "res://assets/Ultimate_Trees/PineTree_4.blend",
		"res://assets/Ultimate_Trees/PineTree_5.blend"]:
		var s := load(path) as PackedScene
		if s: _pine_scenes.append(s)
	# Pebbles
	for path in [
		"res://assets/Ultimate_Trees/Rock_1.blend", "res://assets/Ultimate_Trees/Rock_2.blend",
		"res://assets/Ultimate_Trees/Rock_3.blend", "res://assets/Ultimate_Trees/Rock_Moss_1.blend",
		"res://assets/Ultimate_Trees/Rock_Moss_2.blend", "res://assets/Ultimate_Trees/Rock_Snow_1.blend",
		"res://assets/Ultimate_Trees/Rock_Snow_2.blend"]:
		var s := load(path) as PackedScene
		if s: _pebble_scenes.append(s)
	# Flowers
	for path in [
		"res://assets/Ultimate_Trees/Flowers.blend",
		"res://assets/Farm/Flower_1.blend", "res://assets/Farm/Flower_2.blend",
		"res://assets/Farm/Flower_3.blend"]:
		var s := load(path) as PackedScene
		if s: _flower_scenes.append(s)
	# Ferns
	for path in [
		"res://assets/Ultimate_Trees/Plant_1.blend", "res://assets/Ultimate_Trees/Plant_2.blend"]:
		var s := load(path) as PackedScene
		if s: _fern_scenes.append(s)
	# Mushrooms
	for path in [
		"res://assets/Farm/Mushroom_1.blend", "res://assets/Farm/Mushroom_2.blend",
		"res://assets/Farm/Mushroom_3.blend", "res://assets/Farm/Mushroom_4.blend"]:
		var s := load(path) as PackedScene
		if s: _mushroom_scenes.append(s)
	# Clovers
	for path in [
		"res://assets/Ultimate_Trees/Plant_3.blend", "res://assets/Ultimate_Trees/Plant_4.blend"]:
		var s := load(path) as PackedScene
		if s: _clover_scenes.append(s)
	# Common bushes
	for path in [
		"res://assets/Ultimate_Trees/Bush_1.blend", "res://assets/Ultimate_Trees/Bush_2.blend",
		"res://assets/Ultimate_Trees/BushBerries_1.blend", "res://assets/Ultimate_Trees/BushBerries_2.blend"]:
		var s := load(path) as PackedScene
		if s: _bush_common_scenes.append(s)
	# 3D grass
	for path in [
		"res://assets/Ultimate_Trees/Grass.blend", "res://assets/Ultimate_Trees/Grass_2.blend",
		"res://assets/Ultimate_Trees/Grass_Short.blend"]:
		var s := load(path) as PackedScene
		if s: _forest_grass_scenes.append(s)


func _on_chunk_loaded(chunk_pos: Vector2i) -> void:
	if not world_noise:
		return
	_spawn_chunk_objects(chunk_pos)


func _on_chunk_unloaded(chunk_pos: Vector2i) -> void:
	_despawn_chunk_objects(chunk_pos)


func _spawn_chunk_objects(chunk_pos: Vector2i) -> void:
	if _chunk_objects.has(chunk_pos):
		return
	var container := Node3D.new()
	container.name = "Objects_%d_%d" % [chunk_pos.x, chunk_pos.y]
	add_child(container)
	_chunk_objects[chunk_pos] = container

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos) ^ hash(chunk_pos.x * 73856093 + chunk_pos.y * 19349663)

	var wx := chunk_pos.x * VIRTUAL_CHUNK_SIZE
	var wz := chunk_pos.y * VIRTUAL_CHUNK_SIZE
	var is_exclusion := terrain_service and terrain_service.has_method("is_in_exclusion_zone")

	for i in range(60):
		var lx := rng.randf_range(1.0, VIRTUAL_CHUNK_SIZE - 1.0)
		var lz := rng.randf_range(1.0, VIRTUAL_CHUNK_SIZE - 1.0)
		var world_x := wx + lx
		var world_z := wz + lz

		if is_exclusion and terrain_service.is_in_exclusion_zone(world_x, world_z):
			continue

		var biome := world_noise.get_biome(world_x, world_z)
		if biome <= 1:
			continue
		var height := world_noise.get_height(world_x, world_z)
		if height < 0:
			continue
		var world_pos := Vector3(world_x, height, world_z)

		var roll := rng.randf()
		var tree_density := world_noise.get_tree_density(world_x, world_z)
		var rock_density := world_noise.get_rock_density(world_x, world_z)

		if roll < tree_density:
			var tree := _create_tree(world_pos, biome, rng)
			if tree:
				container.add_child(tree)
		elif roll < tree_density + rock_density:
			var rock := _create_rock(world_pos, biome, rng)
			if rock:
				container.add_child(rock)

	_spawn_grass_and_decorations(container, chunk_pos, rng)
	_spawn_fishing_spots(container, chunk_pos, rng)


func _despawn_chunk_objects(chunk_pos: Vector2i) -> void:
	var container = _chunk_objects.get(chunk_pos)
	if container:
		container.queue_free()
	_chunk_objects.erase(chunk_pos)


# ── Tree creation ─────────────────────────────────────────────────────

func _create_tree(world_pos: Vector3, biome: int, rng: RandomNumberGenerator) -> Node3D:
	var scenes: Array[PackedScene]
	match biome:
		5:  scenes = _pine_scenes
		6:  scenes = _pine_scenes if rng.randf() < 0.6 and not _pine_scenes.is_empty() else (_dead_tree_scenes if not _dead_tree_scenes.is_empty() else _tree_scenes)
		7:  scenes = _pine_scenes if rng.randf() < 0.3 and not _pine_scenes.is_empty() else (_dead_tree_scenes if not _dead_tree_scenes.is_empty() else _tree_scenes)
		9:  scenes = _dead_tree_scenes if rng.randf() < 0.5 and not _dead_tree_scenes.is_empty() else _tree_scenes
		2:  scenes = _dead_tree_scenes if rng.randf() < 0.2 and not _dead_tree_scenes.is_empty() else _tree_scenes
		_:  scenes = _tree_scenes

	if scenes.is_empty():
		return _create_tree_procedural(world_pos, biome, rng)
	var tree: Node3D = scenes[rng.randi() % scenes.size()].instantiate()
	if not tree:
		return _create_tree_procedural(world_pos, biome, rng)
	tree.name = "Tree"
	tree.position = world_pos
	tree.rotation.y = rng.randf_range(0.0, TAU)
	var scale_factor := rng.randf_range(1.6, 2.2)
	if biome == 6 or biome == 7:
		scale_factor *= 0.7
	tree.scale = Vector3(scale_factor, scale_factor, scale_factor)
	_add_tree_harvestable(tree, biome, scale_factor, rng)
	return tree


func _create_tree_procedural(world_pos: Vector3, biome: int, rng: RandomNumberGenerator) -> Node3D:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = world_pos
	var trunk := MeshInstance3D.new()
	trunk.mesh = CylinderMesh.new()
	trunk.mesh.top_radius = 0.2
	trunk.mesh.bottom_radius = 0.3
	trunk.mesh.height = 2.0
	trunk.position.y = 1.0
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)
	trunk.material_override = trunk_mat
	tree.add_child(trunk)
	var leaves := MeshInstance3D.new()
	leaves.mesh = SphereMesh.new()
	leaves.mesh.radius = 1.2
	leaves.mesh.height = 2.0
	leaves.position.y = 2.5
	var leaves_mat := StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.2, 0.5, 0.15)
	leaves.material_override = leaves_mat
	tree.add_child(leaves)
	_add_tree_harvestable(tree, biome, 1.0, rng)
	return tree


func _add_tree_harvestable(tree: Node3D, biome: int, scale: float, rng: RandomNumberGenerator) -> void:
	var h := HarvestableResource.new()
	h.name = "Collision"
	h.collision_layer = 2
	h.collision_mask = 0
	h.resource_type = ToolAffinity.TargetType.TREE
	h.max_health = 15.0
	h.xp_action_id = "chop_tree"
	h.loot_table = _get_tree_loot(biome, rng)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5 * scale
	shape.height = 3.0 * scale
	cs.shape = shape
	cs.position.y = 1.5 * scale
	h.add_child(cs)
	tree.add_child(h)


# ── Rock creation ─────────────────────────────────────────────────────

func _create_rock(world_pos: Vector3, biome: int, rng: RandomNumberGenerator) -> Node3D:
	if _rock_scenes.is_empty():
		return _create_rock_procedural(world_pos, biome, rng)
	var rock: Node3D = _rock_scenes[rng.randi() % _rock_scenes.size()].instantiate()
	if not rock:
		return _create_rock_procedural(world_pos, biome, rng)
	rock.name = "Rock"
	rock.position = world_pos
	rock.rotation.y = rng.randf_range(0.0, TAU)
	rock.rotation.x = rng.randf_range(-0.12, 0.12)
	rock.rotation.z = rng.randf_range(-0.12, 0.12)
	var scale_factor := rng.randf_range(0.5, 1.5)
	rock.scale = Vector3(scale_factor, scale_factor, scale_factor)
	_add_rock_harvestable(rock, biome, scale_factor, rng)
	return rock


func _create_rock_procedural(world_pos: Vector3, biome: int, rng: RandomNumberGenerator) -> Node3D:
	var rock := Node3D.new()
	rock.name = "Rock"
	rock.position = world_pos
	var radius := rng.randf_range(0.3, 0.6)
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radius = radius
	mesh.mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mesh.material_override = mat
	rock.add_child(mesh)
	_add_rock_harvestable(rock, biome, radius, rng)
	return rock


func _add_rock_harvestable(rock: Node3D, biome: int, scale: float, rng: RandomNumberGenerator) -> void:
	var h := HarvestableResource.new()
	h.name = "Collision"
	h.collision_layer = 2
	h.collision_mask = 0
	h.resource_type = ToolAffinity.TargetType.ROCK
	h.max_health = 20.0
	h.xp_action_id = "mine_ore"
	h.loot_table = _get_rock_loot(biome, rng)
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = max(scale * 0.5, 0.3)
	cs.shape = shape
	h.add_child(cs)
	rock.add_child(h)


# ── Grass, bushes, decorations ────────────────────────────────────────

func _spawn_grass_and_decorations(container: Node3D, chunk_pos: Vector2i, rng: RandomNumberGenerator) -> void:
	var wx := chunk_pos.x * VIRTUAL_CHUNK_SIZE
	var wz := chunk_pos.y * VIRTUAL_CHUNK_SIZE
	var is_exclusion := terrain_service and terrain_service.has_method("is_in_exclusion_zone")

	for i in range(40):
		var lx := rng.randf_range(1.0, VIRTUAL_CHUNK_SIZE - 1.0)
		var lz := rng.randf_range(1.0, VIRTUAL_CHUNK_SIZE - 1.0)
		var world_x := wx + lx
		var world_z := wz + lz
		if is_exclusion and terrain_service.is_in_exclusion_zone(world_x, world_z):
			continue
		var biome := world_noise.get_biome(world_x, world_z)
		if biome <= 1:
			continue
		var height := world_noise.get_height(world_x, world_z)
		if height < 0:
			continue

		if biome in [2, 3, 4, 5, 8, 9] and not _forest_grass_scenes.is_empty():
			var grass: Node3D = _forest_grass_scenes[rng.randi() % _forest_grass_scenes.size()].instantiate()
			if grass:
				grass.name = "GrassPatch"
				grass.position = Vector3(world_x, height + 0.02, world_z)
				grass.rotation.y = rng.randf_range(0.0, TAU)
				var sf := rng.randf_range(0.85, 1.15)
				grass.scale = Vector3(sf, sf, sf)
				container.add_child(grass)

	# Bushes
	if _bush_scenes.is_empty() and _bush_common_scenes.is_empty():
		return
	for i in range(24):
		var lx := rng.randf_range(2.0, VIRTUAL_CHUNK_SIZE - 2.0)
		var lz := rng.randf_range(2.0, VIRTUAL_CHUNK_SIZE - 2.0)
		var world_x := wx + lx
		var world_z := wz + lz
		if is_exclusion and terrain_service.is_in_exclusion_zone(world_x, world_z):
			continue
		var biome := world_noise.get_biome(world_x, world_z)
		if biome not in [2, 3, 4, 8, 9]:
			continue
		var height := world_noise.get_height(world_x, world_z)
		var pool := _bush_common_scenes if biome in [2, 8] and not _bush_common_scenes.is_empty() else _bush_scenes
		if pool.is_empty():
			continue
		var bush: Node3D = pool[rng.randi() % pool.size()].instantiate()
		if bush:
			bush.name = "Bush"
			bush.position = Vector3(world_x, height + 0.02, world_z)
			bush.rotation.y = rng.randf_range(0.0, TAU)
			var sf := rng.randf_range(0.9, 1.2)
			bush.scale = Vector3(sf, sf, sf)
			container.add_child(bush)

	# Decorations (flowers, ferns, mushrooms, clovers)
	for i in range(30):
		var lx := rng.randf_range(1.0, VIRTUAL_CHUNK_SIZE - 1.0)
		var lz := rng.randf_range(1.0, VIRTUAL_CHUNK_SIZE - 1.0)
		var world_x := wx + lx
		var world_z := wz + lz
		if is_exclusion and terrain_service.is_in_exclusion_zone(world_x, world_z):
			continue
		var biome := world_noise.get_biome(world_x, world_z)
		if biome <= 1:
			continue
		var height := world_noise.get_height(world_x, world_z)
		if height < 0:
			continue

		var pool: Array[PackedScene] = []
		var node_name := "Decoration"
		var smin := 0.8
		var smax := 1.2
		var is_herb := false

		match biome:
			8:
				pool = _flower_scenes; node_name = "Flower"; smin = 0.7; smax = 1.3; is_herb = true
			2:
				if rng.randf() < 0.6 and not _clover_scenes.is_empty():
					pool = _clover_scenes; node_name = "Clover"
				else:
					pool = _flower_scenes; node_name = "Flower"; is_herb = true
			3:
				pool = _fern_scenes if rng.randf() < 0.6 else _mushroom_scenes
				node_name = "Fern" if rng.randf() < 0.6 else "Mushroom"
				smin = 0.7 if node_name == "Fern" else 0.6; smax = 1.4 if node_name == "Fern" else 1.0
				is_herb = true
			4:
				pool = _fern_scenes; node_name = "Fern"; smin = 0.9; smax = 1.6; is_herb = true
			1: pool = _pebble_scenes; node_name = "Pebble"; smin = 0.5; smax = 1.0
			6: pool = _pebble_scenes; node_name = "Pebble"; smin = 0.6; smax = 1.5
			7: if rng.randf() < 0.4: pool = _pebble_scenes; node_name = "Pebble"; smin = 0.5; smax = 1.2
			9:
				if rng.randf() < 0.5 and not _pebble_scenes.is_empty():
					pool = _pebble_scenes; node_name = "Pebble"; smin = 0.5; smax = 1.0
				elif not _clover_scenes.is_empty():
					pool = _clover_scenes; node_name = "Clover"; is_herb = true
			5:
				if rng.randf() < 0.3 and not _mushroom_scenes.is_empty():
					pool = _mushroom_scenes; node_name = "Mushroom"; smin = 0.5; smax = 0.9; is_herb = true

		if pool.is_empty():
			continue
		var node: Node3D = pool[rng.randi() % pool.size()].instantiate()
		if not node:
			continue
		node.name = node_name
		node.position = Vector3(world_x, height + 0.02, world_z)
		node.rotation.y = rng.randf_range(0.0, TAU)
		var sf := rng.randf_range(smin, smax)
		node.scale = Vector3(sf, sf, sf)
		if is_herb and node_name in ["Mushroom", "Flower", "Fern", "Clover"]:
			_add_herb_harvestable(node, node_name, sf, rng, biome)
		container.add_child(node)


func _add_herb_harvestable(node: Node3D, herb_type: String, scale: float, rng: RandomNumberGenerator, biome: int) -> void:
	var h := HarvestableResource.new()
	h.name = "Collision"
	h.collision_layer = 4
	h.collision_mask = 0
	h.resource_type = ToolAffinity.TargetType.HERB
	h.max_health = 1.0
	match herb_type:
		"Mushroom":
			h.xp_action_id = "pick_mushroom"
			h.loot_table = [{"item_id": "golden_mushroom", "min_amount": 1, "max_amount": 1, "chance": 1.0}] \
				if rng.randf() < (0.3 if biome == 4 else 0.15) \
				else [{"item_id": "common_mushroom", "min_amount": 1, "max_amount": 2, "chance": 1.0}]
		"Flower":
			h.xp_action_id = "forage_item"
			if biome in [8, 2]:
				h.loot_table = [{"item_id": "lavender", "min_amount": 1, "max_amount": 2, "chance": 1.0}]
			else:
				h.loot_table = [{"item_id": "chamomile", "min_amount": 1, "max_amount": 2, "chance": 1.0}]
		"Fern":
			h.xp_action_id = "forage_item"
			h.loot_table = [{"item_id": "fern_frond", "min_amount": 1, "max_amount": 2, "chance": 1.0}]
		"Clover":
			h.xp_action_id = "forage_item"
			h.loot_table = [{"item_id": "wild_clover", "min_amount": 1, "max_amount": 3, "chance": 1.0}]
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4 * scale
	cs.shape = shape
	cs.position.y = 0.2 * scale
	h.add_child(cs)
	node.add_child(h)


# ── Fishing spots ─────────────────────────────────────────────────────

func _spawn_fishing_spots(container: Node3D, chunk_pos: Vector2i, rng: RandomNumberGenerator) -> void:
	var wx := chunk_pos.x * VIRTUAL_CHUNK_SIZE
	var wz := chunk_pos.y * VIRTUAL_CHUNK_SIZE
	var is_exclusion := terrain_service and terrain_service.has_method("is_in_exclusion_zone")

	for _i in range(4):
		var lx := rng.randf_range(0.0, VIRTUAL_CHUNK_SIZE)
		var lz := rng.randf_range(0.0, VIRTUAL_CHUNK_SIZE)
		var world_x := wx + lx
		var world_z := wz + lz
		if is_exclusion and terrain_service.is_in_exclusion_zone(world_x, world_z):
			continue
		var biome := world_noise.get_biome(world_x, world_z)
		if biome != 0:
			continue
		if rng.randf() > 0.08:
			continue
		var spot := FishingSpot.new()
		spot.name = "FishingSpot"
		spot.position = Vector3(world_x, 0, world_z)
		spot.set_default_loot()
		container.add_child(spot)


# ── Loot tables ───────────────────────────────────────────────────────

func _get_tree_loot(biome: int, rng: RandomNumberGenerator) -> Array:
	match biome:
		5: return [{"item_id": "wood_log", "min_amount": 3, "max_amount": 6, "chance": 1.0}, {"item_id": "stick", "min_amount": 1, "max_amount": 2, "chance": 0.5}, {"item_id": "sap", "min_amount": 1, "max_amount": 2, "chance": 0.4}]
		6, 7: return [{"item_id": "wood_log", "min_amount": 1, "max_amount": 2, "chance": 1.0}]
		9: return [{"item_id": "wood_log", "min_amount": 1, "max_amount": 3, "chance": 1.0}, {"item_id": "stick", "min_amount": 1, "max_amount": 2, "chance": 0.4}]
		4: return [{"item_id": "wood_log", "min_amount": 3, "max_amount": 5, "chance": 1.0}, {"item_id": "stick", "min_amount": 2, "max_amount": 4, "chance": 0.8}]
		_: return [{"item_id": "wood_log", "min_amount": 2, "max_amount": 4, "chance": 1.0}, {"item_id": "stick", "min_amount": 1, "max_amount": 3, "chance": 0.7}]


func _get_rock_loot(biome: int, rng: RandomNumberGenerator) -> Array:
	var common := [{"item_id": "small_stone", "min_amount": 1, "max_amount": 3, "chance": 1.0}]
	match biome:
		6, 9: common += [{"item_id": "stone", "min_amount": 3, "max_amount": 6, "chance": 1.0}, {"item_id": "coal", "min_amount": 1, "max_amount": 3, "chance": 0.5}, {"item_id": "iron_nugget", "min_amount": 1, "max_amount": 3, "chance": 0.4}, {"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.3}, {"item_id": "gold_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.1}]
		5, 7: common += [{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0}, {"item_id": "coal", "min_amount": 1, "max_amount": 3, "chance": 0.6}, {"item_id": "iron_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.15}]
		2: common += [{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0}]
		1: common += [{"item_id": "stone", "min_amount": 1, "max_amount": 3, "chance": 1.0}, {"item_id": "copper_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.2}]
		_: common += [{"item_id": "stone", "min_amount": 2, "max_amount": 4, "chance": 1.0}, {"item_id": "coal", "min_amount": 1, "max_amount": 2, "chance": 0.3}, {"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.2}, {"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.15}]
	return common
