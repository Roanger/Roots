extends Node3D

func _ready() -> void:
	_generate_interior()

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

func _add_box(size: Vector3, material: Material, position: Vector3) -> void:
	var box = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position = position
	add_child(box)
