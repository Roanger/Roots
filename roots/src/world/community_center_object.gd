extends PlaceableObject
class_name CommunityCenterObject

const INTERIOR_SCENE = "res://src/world/interiors/community_center_interior.tscn"
const GRID: float = 2.0
const WALL_H: float = 3.12
const H: float = 1.0

var _interior_id: String = ""
var _door: BuildingDoor = null

func setup(p_item_id: String, p_name: String, model_path: String, model_scale: float, collision_size: Vector3, p_is_gate: bool = false, p_interior_id: String = "") -> void:
	_interior_id = p_interior_id if p_interior_id != "" else "community_center_" + str(randi())
	super.setup(p_item_id, p_name, model_path, model_scale, collision_size, p_is_gate)
	_build_shell()
	_add_entrance_door()

func _build_shell() -> void:
	var building = Node3D.new()
	building.name = "Shell"
	
	var path = "res://assets/Buildings/Blends/Inn.blend"
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		if scene:
			var inst = scene.instantiate() as Node3D
			if inst:
				inst.position = Vector3(GRID, 0, GRID)
				building.add_child(inst)
	
	var label = Label3D.new()
	label.text = object_name
	label.font_size = 24
	label.position = Vector3(GRID, WALL_H + 1.0, GRID)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.9, 0.85, 0.6)
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.outline_size = 3
	building.add_child(label)
	
	add_child(building)

func _add_box(parent: Node3D, size: Vector3, material: Material, position: Vector3) -> void:
	var box = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position = position
	parent.add_child(box)

func _add_entrance_door() -> void:
	_door = BuildingDoor.new()
	_door.name = "EntranceDoor"
	_door.building_name = object_name
	_door.is_exit = false
	_door.interior_id = _interior_id
	_door.interior_scene_path = INTERIOR_SCENE
	_door.spawn_offset = Vector3(0, 0.5, -0.5)
	_door.position = Vector3(H, 1.0, GRID * 2 + 0.15)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 2.0, 0.3)
	col.shape = shape
	col.position.y = 1.0
	_door.add_child(col)

	add_child(_door)

func _load_gltf(_gltf_name: String) -> PackedScene:
	return null

func _add_piece(parent: Node3D, _gltf_name: String, local_pos: Vector3, rot_y: float = 0.0) -> void:
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.45, 0.35)
	_add_box(parent, Vector3(1.8, 2.6, 0.2), wall_mat, local_pos)

func get_interaction_text() -> String:
	if _door:
		return _door.get_interaction_text()
	return "Enter " + object_name

func on_interact(player: Node3D) -> void:
	if _door:
		_door.on_interact(player)

func on_hit(player: Node3D, tool_type: String, power: float = 0.0) -> void:
	if tool_type == "hammer":
		super.on_hit(player, tool_type, power)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["interior_id"] = _interior_id
	return data

static func deserialize_with_interior(data: Dictionary) -> Dictionary:
	return data
