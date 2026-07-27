extends PlaceableObject
class_name HouseObject
## A player-placed house — like a normal PlaceableObject exterior, but with its
## own entrance door leading to a private interior (reuses small_house_interior).

const INTERIOR_SCENE = "res://src/world/interiors/small_house_interior.tscn"

var _interior_id: String = ""
var _door: BuildingDoor = null

func setup(p_item_id: String, p_name: String, model_path: String, model_scale: float, collision_size: Vector3, p_is_gate: bool = false, p_interior_id: String = "") -> void:
	_interior_id = p_interior_id if p_interior_id != "" else "house_" + str(randi())
	super.setup(p_item_id, p_name, model_path, model_scale, collision_size, p_is_gate)
	_add_entrance_door(collision_size, model_scale)

func _add_entrance_door(collision_size: Vector3, model_scale: float) -> void:
	_door = BuildingDoor.new()
	_door.name = "EntranceDoor"
	_door.building_name = object_name
	_door.is_exit = false
	_door.interior_id = _interior_id
	_door.interior_scene_path = INTERIOR_SCENE
	_door.spawn_offset = Vector3(0, 0.5, -0.5)
	_door.position = Vector3(0, 1.0, collision_size.z * model_scale * 0.5 + 0.2)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 2.0, 0.3)
	col.shape = shape
	col.position.y = 1.0
	_door.add_child(col)

	add_child(_door)

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
