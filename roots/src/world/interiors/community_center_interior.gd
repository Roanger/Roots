extends Node3D

const GRID: float = 2.0

func _ready() -> void:
	_generate_interior()

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

func _add_box(size: Vector3, material: Material, position: Vector3) -> void:
	var box = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position = position
	add_child(box)
