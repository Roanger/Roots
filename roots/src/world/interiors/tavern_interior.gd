extends Node3D

const BuildingDoorScript = preload("res://src/world/building_door.gd")

func setup(_role_id: String) -> void:
	_generate_interior()
	_furnish()
	_add_exit_door()
	_add_light()

func _add_light() -> void:
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.8)
	light.light_energy = 2.2
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.4, 0)
	add_child(light)

func _generate_interior() -> void:
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.4, 0.3, 0.2)
	_add_box(Vector3(5.6, 0.05, 3.6), floor_mat, Vector3(0, -0.025, 0))

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.6, 0.55, 0.45)
	_add_box(Vector3(5.6, 2.8, 0.1), wall_mat, Vector3(0, 1.4, -1.8))
	_add_box(Vector3(5.6, 2.8, 0.1), wall_mat, Vector3(0, 1.4, 1.8))
	_add_box(Vector3(0.1, 2.8, 3.6), wall_mat, Vector3(-2.8, 1.4, 0))
	_add_box(Vector3(0.1, 2.8, 3.6), wall_mat, Vector3(2.8, 1.4, 0))

	var ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.75, 0.7, 0.6)
	_add_box(Vector3(5.6, 0.05, 3.6), ceiling_mat, Vector3(0, 2.8, 0))

	# Bar counter
	var counter_mat = StandardMaterial3D.new()
	counter_mat.albedo_color = Color(0.45, 0.3, 0.15)
	_add_box(Vector3(2.0, 1.2, 0.5), counter_mat, Vector3(0, 0.6, 1.2))

	var stool_mat = StandardMaterial3D.new()
	stool_mat.albedo_color = Color(0.5, 0.35, 0.2)
	_add_box(Vector3(0.3, 0.6, 0.3), stool_mat, Vector3(-0.8, 0.3, 0.8))
	_add_box(Vector3(0.3, 0.6, 0.3), stool_mat, Vector3(0.8, 0.3, 0.8))

func _furnish() -> void:
	# Kegs stacked behind the bar
	var keg_mat = StandardMaterial3D.new()
	keg_mat.albedo_color = Color(0.4, 0.26, 0.14)
	_add_box(Vector3(0.4, 0.5, 0.4), keg_mat, Vector3(-1.5, 0.25, 1.5))
	_add_box(Vector3(0.4, 0.5, 0.4), keg_mat, Vector3(-1.0, 0.25, 1.5))

	# A couple of dining tables with chairs on the open floor
	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.5, 0.35, 0.2)
	var chair_mat = StandardMaterial3D.new()
	chair_mat.albedo_color = Color(0.45, 0.3, 0.18)
	for tx in [-1.8, 1.8]:
		_add_box(Vector3(0.7, 0.05, 0.7), table_mat, Vector3(tx, 0.75, -0.9))
		_add_box(Vector3(0.35, 0.6, 0.35), chair_mat, Vector3(tx, 0.3, -1.5))
		_add_box(Vector3(0.35, 0.6, 0.35), chair_mat, Vector3(tx, 0.3, -0.3))

	# Fireplace on the back wall
	var hearth_mat = StandardMaterial3D.new()
	hearth_mat.albedo_color = Color(0.35, 0.33, 0.33)
	_add_box(Vector3(1.0, 1.2, 0.3), hearth_mat, Vector3(2.6, 0.6, 0))
	var fire_mat = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.4, 0.05)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.35, 0.05)
	fire_mat.emission_energy_multiplier = 1.5
	_add_box(Vector3(0.6, 0.4, 0.15), fire_mat, Vector3(2.55, 0.4, 0))

func _add_exit_door() -> void:
	var door = BuildingDoorScript.new()
	door.name = "ExitDoor"
	door.building_name = "Tavern"
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
