extends Node3D

const GRID: float = 2.0
const BuildingDoorScript = preload("res://src/world/building_door.gd")

func setup(_role_id: String) -> void:
	_generate_interior()
	_furnish()
	_add_exit_door()
	_add_light()

func _add_light() -> void:
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.8)
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.4, 0)
	add_child(light)

func _generate_interior() -> void:
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.5, 0.4, 0.3)
	_add_box(Vector3(5.6, 0.05, 5.6), floor_mat, Vector3(0, -0.025, 0))

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.65, 0.6, 0.5)
	_add_box(Vector3(5.6, 2.8, 0.1), wall_mat, Vector3(0, 1.4, -2.8))
	_add_box(Vector3(5.6, 2.8, 0.1), wall_mat, Vector3(0, 1.4, 2.8))
	_add_box(Vector3(0.1, 2.8, 5.6), wall_mat, Vector3(-2.8, 1.4, 0))
	_add_box(Vector3(0.1, 2.8, 5.6), wall_mat, Vector3(2.8, 1.4, 0))

	var ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.8, 0.75, 0.65)
	_add_box(Vector3(5.6, 0.05, 5.6), ceiling_mat, Vector3(0, 2.8, 0))

	# Notice board (on wall)
	var board_mat = StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.6, 0.5, 0.3)
	_add_box(Vector3(1.2, 0.8, 0.05), board_mat, Vector3(0, 1.6, -2.75))

	# Benches
	var bench_mat = StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.5, 0.35, 0.2)
	_add_box(Vector3(1.0, 0.1, 0.4), bench_mat, Vector3(-1.0, 0.55, 0))
	_add_box(Vector3(0.1, 0.5, 0.4), bench_mat, Vector3(-1.0, 0.25, -0.4))
	_add_box(Vector3(0.1, 0.5, 0.4), bench_mat, Vector3(-1.0, 0.25, 0.4))
	_add_box(Vector3(1.0, 0.1, 0.4), bench_mat, Vector3(1.0, 0.55, 0))
	_add_box(Vector3(0.1, 0.5, 0.4), bench_mat, Vector3(1.0, 0.25, -0.4))
	_add_box(Vector3(0.1, 0.5, 0.4), bench_mat, Vector3(1.0, 0.25, 0.4))

func _furnish() -> void:
	# Lectern for addressing the room
	var lectern_mat = StandardMaterial3D.new()
	lectern_mat.albedo_color = Color(0.4, 0.26, 0.14)
	_add_box(Vector3(0.5, 1.0, 0.4), lectern_mat, Vector3(0, 0.5, -2.4))
	# Bookshelf with the town's records
	var shelf_mat = StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.38, 0.25, 0.14)
	_add_box(Vector3(0.3, 1.8, 1.4), shelf_mat, Vector3(2.6, 0.9, -1.8))
	var book_mat = StandardMaterial3D.new()
	book_mat.albedo_color = Color(0.5, 0.4, 0.2)
	for i in range(3):
		_add_box(Vector3(0.22, 0.25, 0.2), book_mat, Vector3(2.55, 0.5 + i * 0.5, -2.3 + i * 0.4))

func _add_exit_door() -> void:
	var door = BuildingDoorScript.new()
	door.name = "ExitDoor"
	door.building_name = "Community Center"
	door.is_exit = true
	door.position = Vector3(0, 1.0, -1.5)
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
