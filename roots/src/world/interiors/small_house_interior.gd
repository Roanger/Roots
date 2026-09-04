extends Node3D
## Shared interior shell for house-shaped buildings: Town Hall, Farmer House,
## Guard Post, the player's own crafted `house`, and any unrecognized building
## (fallback). Furnishing varies by role_id (the interior_id passed by
## InteriorManager) so each building type feels distinct despite sharing the
## same room shell.

const GRID: float = 2.0
const H: float = 1.0
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

	# Center table (simple box)
	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.5, 0.35, 0.2)
	_add_box(Vector3(0.8, 0.05, 0.5), table_mat, Vector3(0, 0.8, 0))

func _furnish(role_id: String) -> void:
	match role_id:
		"town_hall":
			_furnish_town_hall()
		"farmer_house":
			_furnish_farmer_house()
		"guard_post":
			_furnish_guard_post()
		_:
			pass  # player-crafted house / unrecognized building: plain table only

func _furnish_town_hall() -> void:
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.28, 0.16)
	# Mayor's desk against the back wall
	_add_box(Vector3(1.2, 0.05, 0.55), wood_mat, Vector3(0, 0.8, -1.45))
	_add_box(Vector3(1.1, 0.75, 0.05), wood_mat, Vector3(0, 0.375, -1.7))
	# Bookshelf against the side wall
	var shelf_mat = StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.35, 0.22, 0.12)
	_add_box(Vector3(0.3, 1.8, 1.2), shelf_mat, Vector3(-1.6, 0.9, 0.4))
	var book_mat = StandardMaterial3D.new()
	book_mat.albedo_color = Color(0.55, 0.15, 0.15)
	for i in range(3):
		_add_box(Vector3(0.22, 0.25, 0.15), book_mat, Vector3(-1.55, 0.5 + i * 0.5, -0.1 + i * 0.3))

func _furnish_farmer_house() -> void:
	var bed_mat = StandardMaterial3D.new()
	bed_mat.albedo_color = Color(0.55, 0.5, 0.4)
	_add_box(Vector3(0.9, 0.35, 1.7), bed_mat, Vector3(-1.25, 0.175, -1.05))
	var pillow_mat = StandardMaterial3D.new()
	pillow_mat.albedo_color = Color(0.85, 0.82, 0.75)
	_add_box(Vector3(0.75, 0.12, 0.35), pillow_mat, Vector3(-1.25, 0.41, -1.7))
	var chest_mat = StandardMaterial3D.new()
	chest_mat.albedo_color = Color(0.4, 0.26, 0.14)
	_add_box(Vector3(0.6, 0.45, 0.4), chest_mat, Vector3(1.35, 0.225, 1.35))

func _furnish_guard_post() -> void:
	var rack_mat = StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.35, 0.25, 0.15)
	_add_box(Vector3(0.9, 1.3, 0.12), rack_mat, Vector3(1.6, 0.9, -0.6))
	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.62, 0.63, 0.66)
	blade_mat.metallic = 0.7
	for i in range(2):
		_add_box(Vector3(0.08, 1.0, 0.08), blade_mat, Vector3(1.5, 1.1, -0.85 + i * 0.5))
	var cot_mat = StandardMaterial3D.new()
	cot_mat.albedo_color = Color(0.5, 0.45, 0.38)
	_add_box(Vector3(0.7, 0.3, 1.6), cot_mat, Vector3(-1.3, 0.15, 1.0))

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
