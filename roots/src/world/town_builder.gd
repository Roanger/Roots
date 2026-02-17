extends Node3D
class_name TownBuilder
## Assembles a starter village from Medieval Village MegaKit glTF pieces.
## Buildings are prefab functions that snap modular walls, floors, roofs, and props together.
## The village is placed at a given center position, snapped to terrain.

const GLTF_BASE = "res://Medieval Village MegaKit[Standard]/glTF/"
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
const H: float = 1.0  # half-wall centering offset

func _build_small_house(pos: Vector3, rot_y: float, label_text: String) -> void:
	var building = Node3D.new()
	building.name = label_text.replace(" ", "_")
	pos.y = _get_terrain_y(pos)
	building.position = pos
	building.rotation.y = rot_y
	
	# Floor (2x2 grid = 4x4m) — floors are centered on origin (-1 to +1), shift +H on both axes
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(H, 0, H))
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(GRID + H, 0, H))
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(H, 0, GRID + H))
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(GRID + H, 0, GRID + H))
	
	# Back wall (Z = 0 side, rot_y=0 → wall extends along X, shift +H on X)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(H, 0, 0))
	_add_piece(building, "Wall_Plaster_Window_Wide_Round.gltf", Vector3(GRID + H, 0, 0))
	
	# Front wall (Z = 4m side, rot_y=PI → wall extends along X, shift +H on X)
	_add_piece(building, "Wall_Plaster_Door_Round.gltf", Vector3(H, 0, GRID * 2), PI)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(GRID + H, 0, GRID * 2), PI)
	
	# Left wall (X = 0 side, rot_y=PI/2 → wall extends along Z, shift +H on Z)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(0, 0, H), PI / 2.0)
	_add_piece(building, "Wall_Plaster_Window_Thin_Round.gltf", Vector3(0, 0, GRID + H), PI / 2.0)
	
	# Right wall (X = 4m side, rot_y=-PI/2 → wall extends along Z, shift +H on Z)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(GRID * 2, 0, GRID * 2 - H), -PI / 2.0)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(GRID * 2, 0, GRID - H), -PI / 2.0)
	
	# Corners
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(0, 0, 0))
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(GRID * 2, 0, 0), -PI / 2.0)
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(GRID * 2, 0, GRID * 2), PI)
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(0, 0, GRID * 2), PI / 2.0)
	
	# Roof
	_add_piece(building, "Roof_RoundTiles_4x6.gltf", Vector3(GRID, WALL_H, GRID), 0.0)
	
	# Door — door mesh extends from origin to +X (~1m), place at wall door cutout
	_add_piece(building, "Door_1_Round.gltf", Vector3(H, 0, GRID * 2), PI)
	
	# Chimney — raise so angled cap sits on roof slope, outside back wall
	_add_piece(building, "Prop_Chimney.gltf", Vector3(GRID * 1.5, WALL_H - 2.84, -0.5))
	
	# Building label
	_add_label(building, label_text, Vector3(GRID, WALL_H + 1.5, GRID))
	
	# Collision box for the whole building
	_add_building_collision(building, Vector3(GRID * 2, WALL_H, GRID * 2), Vector3(GRID, WALL_H * 0.5, GRID))
	
	add_child(building)

# ─── Prefab: Large House (6x4m footprint, 1 story + overhang) ───
func _build_large_house(pos: Vector3, rot_y: float, label_text: String) -> void:
	var building = Node3D.new()
	building.name = label_text.replace(" ", "_")
	pos.y = _get_terrain_y(pos)
	building.position = pos
	building.rotation.y = rot_y
	
	# Floor (3x2 grid = 6x4m) — floors centered on origin, shift +H on both axes
	for x in range(3):
		for z in range(2):
			_add_piece(building, "Floor_WoodDark.gltf", Vector3(x * GRID + H, 0, z * GRID + H))
	
	# Back wall (Z = 0, rot_y=0 → shift +H on X)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(H, 0, 0))
	_add_piece(building, "Wall_UnevenBrick_Window_Wide_Round.gltf", Vector3(GRID + H, 0, 0))
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(GRID * 2 + H, 0, 0))
	
	# Front wall (Z = 4m, rot_y=PI → shift +H on X)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(H, 0, GRID * 2), PI)
	_add_piece(building, "Wall_UnevenBrick_Door_Round.gltf", Vector3(GRID + H, 0, GRID * 2), PI)
	_add_piece(building, "Wall_UnevenBrick_Window_Wide_Flat.gltf", Vector3(GRID * 2 + H, 0, GRID * 2), PI)
	
	# Left wall (X = 0, rot_y=PI/2 → shift +H on Z)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(0, 0, H), PI / 2.0)
	_add_piece(building, "Wall_UnevenBrick_Window_Thin_Round.gltf", Vector3(0, 0, GRID + H), PI / 2.0)
	
	# Right wall (X = 6m, rot_y=-PI/2 → shift +H on Z)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(GRID * 3, 0, GRID * 2 - H), -PI / 2.0)
	_add_piece(building, "Wall_UnevenBrick_Window_Thin_Round.gltf", Vector3(GRID * 3, 0, GRID - H), -PI / 2.0)
	
	# Corners
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(0, 0, 0))
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(GRID * 3, 0, 0), -PI / 2.0)
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(GRID * 3, 0, GRID * 2), PI)
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(0, 0, GRID * 2), PI / 2.0)
	
	# Roof
	_add_piece(building, "Roof_RoundTiles_6x6.gltf", Vector3(GRID * 1.5, WALL_H, GRID), 0.0)
	
	# Door — door mesh extends from origin to +X, place at wall door cutout
	_add_piece(building, "Door_2_Round.gltf", Vector3(GRID + H, 0, GRID * 2), PI)
	
	# Chimney — raise so angled cap sits on roof slope, outside back wall
	_add_piece(building, "Prop_Chimney2.gltf", Vector3(GRID * 2.5, WALL_H - 2.84, -0.5))
	
	# Overhang on front
	_add_piece(building, "Overhang_UnevenBrick_Long.gltf", Vector3(GRID * 1.5, WALL_H, GRID * 2))
	
	# Balcony on front (decorative) — spans X:-1 to +1, Z:~0.9 to ~1.1 (sticks outward)
	_add_piece(building, "Balcony_Simple_Straight.gltf", Vector3(GRID * 1.5, WALL_H * 0.65, GRID * 2))
	
	# Vines on side
	_add_piece(building, "Prop_Vine1.gltf", Vector3(0, WALL_H * 0.3, GRID))
	
	# Label
	_add_label(building, label_text, Vector3(GRID * 1.5, WALL_H + 2.0, GRID))
	
	# Collision
	_add_building_collision(building, Vector3(GRID * 3, WALL_H, GRID * 2), Vector3(GRID * 1.5, WALL_H * 0.5, GRID))
	
	add_child(building)

# ─── Prefab: Market Stall (open-air, 2x2m) ───
func _build_market_stall(pos: Vector3, rot_y: float, label_text: String) -> void:
	var stall = Node3D.new()
	stall.name = "Stall_" + label_text.replace(" ", "_")
	pos.y = _get_terrain_y(pos)
	stall.position = pos
	stall.rotation.y = rot_y
	
	# Crate as counter
	_add_piece(stall, "Prop_Crate.gltf", Vector3(0, 0, 0))
	_add_piece(stall, "Prop_Crate.gltf", Vector3(0.8, 0, 0))
	
	# Support posts + roof — same approach as the Town Well
	_add_piece(stall, "Prop_Support.gltf", Vector3(-0.8, 0, 0))
	_add_piece(stall, "Prop_Support.gltf", Vector3(1.8, 0, 0))
	_add_piece(stall, "Roof_Wooden_2x1.gltf", Vector3(0.4, 2.2, 0))
	
	# Label
	_add_label(stall, label_text, Vector3(0.5, 2.8, 0))
	
	# Small collision
	_add_building_collision(stall, Vector3(2.0, 1.0, 1.0), Vector3(0.5, 0.5, 0))
	
	add_child(stall)

# ─── Market Center (well + path markers) ───
func _place_market_center(center: Vector3) -> void:
	# Central well placeholder (stone cylinder + label)
	var well = Node3D.new()
	well.name = "Town_Well"
	well.position = center
	
	var mesh_inst = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.2
	mesh_inst.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.4)
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.6
	well.add_child(mesh_inst)
	
	# Well roof (small wooden roof)
	_add_piece(well, "Roof_Wooden_2x1.gltf", Vector3(0, 2.2, 0))
	
	# Support posts for well roof
	_add_piece(well, "Prop_Support.gltf", Vector3(-0.8, 0, 0))
	_add_piece(well, "Prop_Support.gltf", Vector3(0.8, 0, 0))
	
	_add_label(well, "Town Well", Vector3(0, 3.0, 0))
	
	# Collision for well
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.2
	col.shape = shape
	col.position.y = 0.6
	body.add_child(col)
	well.add_child(body)
	
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

func _load_gltf(gltf_name: String) -> PackedScene:
	if _scene_cache.has(gltf_name):
		return _scene_cache[gltf_name]
	var path = GLTF_BASE + gltf_name
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		_scene_cache[gltf_name] = scene
		return scene
	else:
		push_warning("TownBuilder: glTF not found: " + path)
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

func _get_terrain_y(world_pos: Vector3) -> float:
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		return chunk_manager.get_terrain_height(world_pos)
	return 0.0
