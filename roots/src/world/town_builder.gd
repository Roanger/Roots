extends Node3D
class_name TownBuilder
## Assembles a starter village from modular pieces.
## Buildings are prefab functions that snap modular walls, floors, roofs, and props together.
## The village is placed at a given center position, snapped to terrain.

const SCENE_DIR = "res://src/world/town_buildings/"

# Wall height ~3.1m, wall width = 2m grid
const WALL_H: float = 3.12
const GRID: float = 2.0

var chunk_manager: Node = null
var _scene_cache: Dictionary = {}
var _building_scene_cache: Dictionary = {}

func setup(p_chunk_manager: Node) -> void:
	chunk_manager = p_chunk_manager

func build_village(center: Vector3) -> void:
	# Snap center to terrain
	center.y = _get_terrain_y(center)
	
	# === Town Center: open market square ===
	_place_or_load("town_well", center, 0.0, "Town Well", "well")
	
	# === Buildings arranged around the square ===
	_place_or_load("small_house", center + Vector3(0, 0, -14), 0.0, "General Store", "small")
	_place_or_load("large_house", center + Vector3(10, 0, -10), -PI / 4.0, "Tavern", "large")
	_place_or_load("small_house", center + Vector3(14, 0, 0), -PI / 2.0, "Blacksmith", "small")
	_place_or_load("small_house", center + Vector3(10, 0, 10), -PI * 0.75, "Bakery", "small")
	_place_or_load("large_house", center + Vector3(0, 0, 14), PI, "Town Hall", "large")
	_place_or_load("small_house", center + Vector3(-10, 0, 10), PI * 0.75, "Herbalist", "small")
	_place_or_load("small_house", center + Vector3(-14, 0, 0), PI / 2.0, "Farmer House", "small")
	_place_or_load("small_house", center + Vector3(-10, 0, -10), PI / 4.0, "Guard Post", "small")
	
	# === Market Stalls in the center area ===
	_place_or_load("market_stall", center + Vector3(-3, 0, -3), 0.0, "Produce", "stall")
	_place_or_load("market_stall", center + Vector3(3, 0, -3), 0.0, "Goods", "stall")
	_place_or_load("market_stall", center + Vector3(-3, 0, 3), PI, "Potions", "stall")
	_place_or_load("market_stall", center + Vector3(3, 0, 3), PI, "Weapons", "stall")
	
	# === Props: crates, barrels near buildings ===
	_scatter_props(center)
	
	print("Village built at ", center)

## Try to load a saved .tscn scene; if not found, fall back to code assembly.
func _place_or_load(scene_id: String, pos: Vector3, rot_y: float, label_text: String, fallback: String) -> void:
	pos.y = _get_terrain_y(pos)
	
	# Check for a saved scene override (e.g. "small_house.tscn")
	var scene = _load_building_scene(scene_id)
	if scene:
		var inst = scene.instantiate() as Node3D
		inst.name = label_text.replace(" ", "_")
		inst.position = pos
		inst.rotation.y = rot_y
		_add_label(inst, label_text, _get_label_offset(fallback))
		add_child(inst)
		_add_scene_door(inst, fallback, label_text)
		# Well needs terrain-relative border stones even when loaded from scene
		if fallback == "well":
			_place_border_stones(pos)
		return
	
	# Fallback to code assembly
	match fallback:
		"small":
			_build_small_house(pos, rot_y, label_text)
		"large":
			_build_large_house(pos, rot_y, label_text)
		"stall":
			_build_market_stall(pos, rot_y, label_text)
		"well":
			_place_market_center(pos)

func _load_building_scene(scene_id: String) -> PackedScene:
	if _building_scene_cache.has(scene_id):
		return _building_scene_cache[scene_id]
	var path = SCENE_DIR + scene_id + ".tscn"
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		_building_scene_cache[scene_id] = scene
		return scene
	_building_scene_cache[scene_id] = null
	return null

func _get_label_offset(building_type: String) -> Vector3:
	match building_type:
		"small":
			return Vector3(GRID, WALL_H + 1.5, GRID)
		"large":
			return Vector3(GRID * 1.5, WALL_H + 2.0, GRID)
		"stall":
			return Vector3(0.5, 2.8, 0)
		"well":
			return Vector3(0, 3.0, 0)
		_:
			return Vector3(0, 3.0, 0)

# ─── Prefab: Small House (4x4m footprint, 1 story) ───
# Wall pieces are 2m wide centered on origin (X: -1 to +1).
# H = half-wall offset (1m) to center wall on grid edge.
const H: float = 1.0

func _build_small_house(pos: Vector3, rot_y: float, label_text: String) -> void:
	var building = Node3D.new()
	building.name = label_text.replace(" ", "_")
	pos.y = _get_terrain_y(pos)
	building.position = pos
	building.rotation.y = rot_y
	
	var path = "res://assets/Buildings/Blends/House_1.blend"
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		if scene:
			var inst = scene.instantiate() as Node3D
			if inst:
				inst.position = Vector3(GRID, 0, GRID)
				inst.scale = Vector3(2.0, 2.0, 2.0)
				building.add_child(inst)
	
	_add_label(building, label_text, Vector3(GRID, WALL_H + 1.5, GRID))
	_add_building_collision(building, Vector3(GRID * 2, WALL_H, GRID * 2), Vector3(GRID, WALL_H * 0.5, GRID))
	_add_entrance_door(building, label_text, Vector3(H, 0, GRID * 2 + 0.15))
	add_child(building)

# ─── Prefab: Large House (6x4m footprint, 1 story + overhang) ───
func _build_large_house(pos: Vector3, rot_y: float, label_text: String) -> void:
	var building = Node3D.new()
	building.name = label_text.replace(" ", "_")
	pos.y = _get_terrain_y(pos)
	building.position = pos
	building.rotation.y = rot_y
	
	var path = "res://assets/Buildings/Blends/House_2.blend"
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		if scene:
			var inst = scene.instantiate() as Node3D
			if inst:
				inst.position = Vector3(GRID * 1.5, 0, GRID)
				inst.scale = Vector3(2.0, 2.0, 2.0)
				building.add_child(inst)
	
	_add_label(building, label_text, Vector3(GRID * 1.5, WALL_H + 2.0, GRID))
	_add_building_collision(building, Vector3(GRID * 3, WALL_H, GRID * 2), Vector3(GRID * 1.5, WALL_H * 0.5, GRID))
	_add_entrance_door(building, label_text, Vector3(GRID + H, 0, GRID * 2 + 0.15))
	add_child(building)

# ─── Prefab: Market Stall (open-air, 2x2m) ───
func _build_market_stall(pos: Vector3, rot_y: float, label_text: String) -> void:
	var stall = Node3D.new()
	stall.name = "Stall_" + label_text.replace(" ", "_")
	pos.y = _get_terrain_y(pos)
	stall.position = pos
	stall.rotation.y = rot_y
	
	_add_piece(stall, "Prop_Crate.gltf", Vector3(0, 0, 0))
	_add_piece(stall, "Prop_Crate.gltf", Vector3(0.8, 0, 0))
	_add_piece(stall, "Corner_Exterior_Wood.gltf", Vector3(-0.8, 0, 0))
	_add_piece(stall, "Corner_Exterior_Wood.gltf", Vector3(1.8, 0, 0))
	_add_piece(stall, "Roof_Wooden_2x1.gltf", Vector3(0.4, 2.5, 0))
	
	_add_label(stall, label_text, Vector3(0.5, 2.8, 0))
	_add_building_collision(stall, Vector3(2.0, 1.0, 1.0), Vector3(0.5, 0.5, 0))
	add_child(stall)

# ─── Market Center (well + path markers) ───
func _place_market_center(center: Vector3) -> void:
	var well = Node3D.new()
	well.name = "Town_Well"
	well.position = center
	
	var path = "res://assets/Buildings/Blends/Bell_Tower.blend"
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		if scene:
			var inst = scene.instantiate() as Node3D
			if inst:
				inst.scale = Vector3(1.2, 1.2, 1.2)
				well.add_child(inst)
	
	_add_label(well, "Town Well", Vector3(0, 3.0, 0))
	add_child(well)
	_place_border_stones(center)

func _place_border_stones(center: Vector3) -> void:
	for i in range(4):
		var angle = i * PI / 2.0
		for j in range(3):
			var offset = j * 2.5 - 2.5
			var border_pos = Vector3(
				cos(angle) * 7.0 + sin(angle) * offset,
				0,
				sin(angle) * 7.0 - cos(angle) * offset
			)
			var world_pos = center + border_pos
			world_pos.y = _get_terrain_y(world_pos)
			_add_piece(self, "Prop_ExteriorBorder_Straight1.gltf", world_pos - position, angle)

# ─── Scatter decorative props near buildings ───
func _scatter_props(center: Vector3) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(center)
	
	# Crates near buildings — positioned in open areas between buildings, not inside walls
	var crate_positions = [
		Vector3(3, 0, -11), Vector3(12, 0, 3), Vector3(-12, 0, 3),
		Vector3(3, 0, 12), Vector3(6, 0, -6), Vector3(-6, 0, 6),
	]
	for cpos in crate_positions:
		var world_pos = center + cpos
		world_pos.y = _get_terrain_y(world_pos)
		_add_piece(self, "Prop_Crate.gltf", world_pos - position, rng.randf() * TAU)
	
	# Brick piles
	var brick_positions = [
		Vector3(-13, 0, -2), Vector3(13, 0, 2), Vector3(0, 0, -16),
	]
	for bpos in brick_positions:
		var world_pos = center + bpos
		world_pos.y = _get_terrain_y(world_pos)
		var brick_name = "Prop_Brick%d.gltf" % (rng.randi_range(1, 4))
		_add_piece(self, brick_name, world_pos - position, rng.randf() * TAU)

# ─── Helpers ───

func _add_piece(parent: Node3D, gltf_name: String, local_pos: Vector3, rot_y: float = 0.0) -> void:
	var scene = _load_gltf(gltf_name)
	if not scene:
		return
	var inst = scene.instantiate() as Node3D
	if inst:
		inst.position = local_pos
		if rot_y != 0.0:
			inst.rotation.y = rot_y
		parent.add_child(inst)

const MEDIEVAL_KIT_DIR = "res://assets/Medieval Village MegaKit[Standard]/glTF/"

func _load_gltf(gltf_name: String) -> PackedScene:
	if _scene_cache.has(gltf_name):
		return _scene_cache[gltf_name]
	var path = MEDIEVAL_KIT_DIR + gltf_name
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		_scene_cache[gltf_name] = scene
		return scene
	push_warning("TownBuilder: asset not found: " + path)
	_scene_cache[gltf_name] = null
	return null

func _add_label(parent: Node3D, text: String, local_pos: Vector3) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 28
	label.position = local_pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.95, 0.8)
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.outline_size = 4
	parent.add_child(label)

func _add_scene_door(inst: Node3D, fallback: String, label_text: String) -> void:
	match fallback:
		"small":
			_add_entrance_door(inst, label_text, Vector3(H, 0, GRID * 2 + 0.15))
		"large":
			_add_entrance_door(inst, label_text, Vector3(GRID + H, 0, GRID * 2 + 0.15))

func _add_building_collision(parent: Node3D, box_size: Vector3, center_offset: Vector3) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = center_offset
	body.add_child(col)
	parent.add_child(body)

const BuildingDoorScript = preload("res://src/world/building_door.gd")

## Interior scene mapping: building label -> { interior_id, scene_path }
func _get_interior_map(label: String) -> Dictionary:
	match label:
		"General Store":    return {"id": "general_store", "scene": "res://src/world/interiors/shop_interior.tscn"}
		"Tavern":           return {"id": "tavern",        "scene": "res://src/world/interiors/tavern_interior.tscn"}
		"Blacksmith":       return {"id": "blacksmith",    "scene": "res://src/world/interiors/shop_interior.tscn"}
		"Bakery":           return {"id": "bakery",        "scene": "res://src/world/interiors/shop_interior.tscn"}
		"Town Hall":        return {"id": "town_hall",     "scene": "res://src/world/interiors/small_house_interior.tscn"}
		"Herbalist":        return {"id": "herbalist",     "scene": "res://src/world/interiors/shop_interior.tscn"}
		"Farmer House":     return {"id": "farmer_house",  "scene": "res://src/world/interiors/small_house_interior.tscn"}
		"Guard Post":       return {"id": "guard_post",    "scene": "res://src/world/interiors/small_house_interior.tscn"}
		_:                  return {"id": label.to_lower().replace(" ", "_"), "scene": "res://src/world/interiors/small_house_interior.tscn"}

func _add_entrance_door(building: Node3D, label_text: String, local_pos: Vector3) -> void:
	var imap = _get_interior_map(label_text)
	var door = BuildingDoorScript.new()
	door.name = "Door_" + label_text.replace(" ", "_")
	door.building_name = label_text
	door.is_exit = false
	door.interior_id = imap.id
	door.interior_scene_path = imap.scene
	door.spawn_offset = Vector3(0, 0.5, -0.5)
	door.position = local_pos
	door.rotation.y = PI  # Faces outward

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 2.0, 0.3)
	col.shape = shape
	col.position.y = 1.0
	door.add_child(col)

	building.add_child(door)

func _get_terrain_y(world_pos: Vector3) -> float:
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		return chunk_manager.get_terrain_height(world_pos)
	return 0.0
