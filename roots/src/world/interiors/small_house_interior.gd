extends Node3D

const GRID: float = 2.0
const H: float = 1.0
const BuildingDoorScript = preload("res://src/world/building_door.gd")

func _ready() -> void:
	_generate_interior()
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

	# Center table (simple box)
	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.5, 0.35, 0.2)
	_add_box(Vector3(0.8, 0.05, 0.5), table_mat, Vector3(0, 0.8, 0))

func _add_exit_door() -> void:
	var door = BuildingDoorScript.new()
	door.name = "ExitDoor"
	door.building_name = "House"
	door.is_exit = true
	door.position = Vector3(0, 1.0, -1.0)
	add_child(door)

func _add_box(size: Vector3, material: Material, position: Vector3) -> void:
	# StaticBody3D wrapper so floor/walls/furniture are actually solid — without
	# this the player falls straight through into the real outdoor terrain far
	# below the interior's hidden y=500 pocket-dimension offset.
	var body = StaticBody3D.new()
	body.position = position
	body.collision_layer = 1  # Terrain layer, matches what the player collides with
	body.collision_mask = 0

	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	# Room walls/ceiling are only ever seen from inside (their outward-facing
	# normals would otherwise be backface-culled from the player's viewpoint).
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
