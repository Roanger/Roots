extends Node3D
## Shared interior shell for counter-shaped buildings: General Store,
## Blacksmith, Bakery, Herbalist. Furnishing varies by role_id (the
## interior_id passed by InteriorManager) so each shop feels distinct despite
## sharing the same room shell.

const GRID: float = 2.0
const BuildingDoorScript = preload("res://src/world/building_door.gd")

func setup(role_id: String) -> void:
	_generate_interior()
	_furnish(role_id)
	_add_exit_door()
	_add_light()

func _add_light() -> void:
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.8)
	light.light_energy = 2.2
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.4, 0)
	add_child(light)

func _generate_interior() -> void:
	# Floor
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.45, 0.35, 0.25)
	_add_box(Vector3(3.6, 0.05, 3.6), floor_mat, Vector3(0, -0.025, 0))

	# Walls
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.7, 0.65, 0.55)
	_add_box(Vector3(3.6, 2.8, 0.1), wall_mat, Vector3(0, 1.4, -1.8))
	_add_box(Vector3(3.6, 2.8, 0.1), wall_mat, Vector3(0, 1.4, 1.8))
	_add_box(Vector3(0.1, 2.8, 3.6), wall_mat, Vector3(-1.8, 1.4, 0))
	_add_box(Vector3(0.1, 2.8, 3.6), wall_mat, Vector3(1.8, 1.4, 0))

	# Ceiling
	var ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.8, 0.75, 0.65)
	_add_box(Vector3(3.6, 0.05, 3.6), ceiling_mat, Vector3(0, 2.8, 0))

	# Counter
	var counter_mat = StandardMaterial3D.new()
	counter_mat.albedo_color = Color(0.5, 0.35, 0.2)
	_add_box(Vector3(1.2, 1.0, 0.5), counter_mat, Vector3(0, 0.5, -0.8))

func _furnish(role_id: String) -> void:
	match role_id:
		"general_store":
			_furnish_general_store()
		"blacksmith":
			_furnish_blacksmith()
		"bakery":
			_furnish_bakery()
		"herbalist":
			_furnish_herbalist()
		_:
			pass

func _add_shelf(back_z: float) -> void:
	var shelf_mat = StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.38, 0.25, 0.14)
	_add_box(Vector3(2.6, 1.6, 0.18), shelf_mat, Vector3(0, 1.0, back_z))

func _furnish_general_store() -> void:
	_add_shelf(-1.65)
	var crate_mat = StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.55, 0.4, 0.22)
	var goods := [Color(0.6, 0.2, 0.2), Color(0.2, 0.5, 0.25), Color(0.65, 0.6, 0.2), Color(0.3, 0.3, 0.6)]
	for i in range(4):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = goods[i]
		_add_box(Vector3(0.3, 0.3, 0.25), mat, Vector3(-1.0 + i * 0.65, 1.55, -1.68))
	_add_box(Vector3(0.5, 0.4, 0.5), crate_mat, Vector3(1.35, 0.2, 1.3))
	_add_box(Vector3(0.5, 0.4, 0.5), crate_mat, Vector3(1.35, 0.2, 0.7))

func _furnish_blacksmith() -> void:
	var forge_mat = StandardMaterial3D.new()
	forge_mat.albedo_color = Color(0.3, 0.28, 0.28)
	_add_box(Vector3(0.8, 0.9, 0.6), forge_mat, Vector3(1.3, 0.45, -1.4))
	var ember_mat = StandardMaterial3D.new()
	ember_mat.albedo_color = Color(1.0, 0.4, 0.05)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.35, 0.05)
	ember_mat.emission_energy_multiplier = 1.5
	_add_box(Vector3(0.55, 0.1, 0.35), ember_mat, Vector3(1.3, 0.91, -1.4))
	var anvil_mat = StandardMaterial3D.new()
	anvil_mat.albedo_color = Color(0.4, 0.41, 0.44)
	anvil_mat.metallic = 0.6
	_add_box(Vector3(0.5, 0.5, 0.25), anvil_mat, Vector3(-1.0, 0.25, -1.5))
	var rack_mat = StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.35, 0.25, 0.15)
	_add_box(Vector3(0.9, 1.2, 0.1), rack_mat, Vector3(-1.6, 0.85, 1.0))
	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.62, 0.63, 0.66)
	blade_mat.metallic = 0.7
	for i in range(2):
		_add_box(Vector3(0.06, 0.9, 0.06), blade_mat, Vector3(-1.5, 1.0, 0.7 + i * 0.5))

func _furnish_bakery() -> void:
	var oven_mat = StandardMaterial3D.new()
	oven_mat.albedo_color = Color(0.35, 0.32, 0.3)
	_add_box(Vector3(0.9, 1.0, 0.6), oven_mat, Vector3(1.3, 0.5, -1.4))
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.65, 0.35, 0.1)
	door_mat.emission_enabled = true
	door_mat.emission = Color(0.9, 0.4, 0.1)
	door_mat.emission_energy_multiplier = 0.8
	_add_box(Vector3(0.4, 0.4, 0.05), door_mat, Vector3(1.3, 0.45, -1.09))
	_add_shelf(-1.65)
	var bread_mat = StandardMaterial3D.new()
	bread_mat.albedo_color = Color(0.72, 0.5, 0.25)
	for i in range(3):
		_add_box(Vector3(0.35, 0.2, 0.22), bread_mat, Vector3(-1.1 + i * 0.5, 1.5, -1.68))

func _furnish_herbalist() -> void:
	_add_shelf(-1.65)
	var bottle_colors := [Color(0.3, 0.7, 0.3), Color(0.6, 0.3, 0.7), Color(0.8, 0.7, 0.2)]
	for i in range(6):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = bottle_colors[i % bottle_colors.size()]
		_add_box(Vector3(0.14, 0.28, 0.14), mat, Vector3(-1.3 + i * 0.5, 1.5, -1.68))
	var herb_mat = StandardMaterial3D.new()
	herb_mat.albedo_color = Color(0.3, 0.5, 0.2)
	for i in range(3):
		_add_box(Vector3(0.15, 0.35, 0.1), herb_mat, Vector3(-1.6, 2.2, 0.6 + i * 0.4))

func _add_exit_door() -> void:
	var door = BuildingDoorScript.new()
	door.name = "ExitDoor"
	door.building_name = "Shop"
	door.is_exit = true
	door.position = Vector3(0, 1.0, -1.0)
	add_child(door)

func _add_box(size: Vector3, material: Material, position: Vector3) -> void:
	var body = StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0

	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = material
	body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	add_child(body)
