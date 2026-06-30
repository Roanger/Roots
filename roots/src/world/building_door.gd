extends StaticBody3D
class_name BuildingDoor
## Door trigger — interact to enter/exit a building.
## Placed just in front of a building's door opening.
## Player raycast hits this before the building collision.

var interior_manager: Node = null

@export var building_name: String = "Building"
@export var is_exit: bool = false
@export var interior_id: String = ""
@export var interior_scene_path: String = ""
@export var spawn_offset: Vector3 = Vector3(0, 0.5, 0)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	if not _has_collision_shape():
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.2, 2.0, 0.3)
		col.shape = shape
		col.position.y = 1.0
		add_child(col)

func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			return true
	return false

func _get_interior_manager() -> Node:
	if not interior_manager or not is_instance_valid(interior_manager):
		interior_manager = get_node_or_null("/root/MainWorld/InteriorManager")
	return interior_manager

func on_interact(player: Node3D) -> void:
	var im = _get_interior_manager()
	if not im:
		return
	if is_exit:
		im.exit_interior(player, interior_id)
	else:
		im.enter_interior(player, interior_id, interior_scene_path, spawn_offset, player.global_position, player.rotation.y)

func get_interaction_text() -> String:
	if is_exit:
		return "Exit " + building_name
	return "Enter " + building_name

func get_target_type() -> int:
	return ToolAffinity.TargetType.BUILDING

func on_hit(_player: Node3D, _tool_type: String, _power: float = 0.0) -> void:
	pass
