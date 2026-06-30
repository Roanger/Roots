extends Node3D

const GRID: float = 2.0
const H: float = 1.0

func _ready() -> void:
	_generate_interior()

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

	# Center table (simple box)
	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.5, 0.35, 0.2)
	_add_box(Vector3(0.8, 0.05, 0.5), table_mat, Vector3(0, 0.8, 0))

func _add_box(size: Vector3, material: Material, position: Vector3) -> void:
	var box = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position = position
	add_child(box)
