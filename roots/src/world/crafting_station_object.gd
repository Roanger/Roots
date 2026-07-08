extends StaticBody3D
class_name CraftingStationObject
## A placeable crafting station in the world (workbench, forge, anvil, etc.)
## Players interact with E to open the crafting UI filtered to this station type.
## Optionally requires a specific tool type to be equipped.

@export var station_type: int = 1  # CraftingRecipe.CraftingStation enum value
@export var station_name: String = "Workbench"
@export var required_tool_type: String = ""  # Empty = no tool required, e.g. "hammer", "saw", "knife"

@onready var event_bus: Node = get_node_or_null("/root/EventBus")

## Collision size per station type (matching _create_station in main_world.gd).
const COLLISION_SIZES: Dictionary = {
	1: Vector3(1.2, 0.8, 0.8),
	2: Vector3(1.0, 1.5, 1.0),
	3: Vector3(0.7, 0.75, 0.4),
	4: Vector3(1.0, 0.75, 1.0),
	5: Vector3(1.1, 1.1, 0.7),
	6: Vector3(1.0, 1.1, 0.5),
	7: Vector3(1.3, 0.9, 0.5),
}

const COLLISION_Y: Dictionary = {
	1: 0.4,
	2: 0.75,
	3: 0.375,
	4: 0.375,
	5: 0.55,
	6: 0.55,
	7: 0.45,
}

const LABEL_Y: Dictionary = {
	1: 1.2,
	2: 1.8,
	3: 1.2,
	4: 1.2,
	5: 1.4,
	6: 1.4,
	7: 1.4,
}

func setup(stype: int, sname: String, tool: String = "") -> void:
	station_type = stype
	station_name = sname
	required_tool_type = tool

	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var csize: Vector3 = COLLISION_SIZES.get(stype, Vector3(1.2, 0.8, 0.8))
	shape.size = csize
	col_shape.shape = shape
	col_shape.position.y = COLLISION_Y.get(stype, 0.4) as float
	add_child(col_shape)

	var label := Label3D.new()
	label.text = station_name
	label.font_size = 32
	label.position.y = LABEL_Y.get(stype, 1.2) as float
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func get_target_type() -> int:
	return ToolAffinity.TargetType.CRAFTING_STATION

func on_interact(player: Node3D) -> void:
	if required_tool_type != "":
		var tool_type = ""
		if player and "current_tool" in player:
			tool_type = player.current_tool
		if tool_type != required_tool_type:
			var feedback = "Need a " + required_tool_type + " to use this station."
			if player.has_method("_show_tool_feedback"):
				player._show_tool_feedback(feedback)
			else:
				print("[Station] ", feedback)
			return
	if event_bus:
		event_bus.emit_signal("open_crafting_station", station_type)

func get_interaction_text() -> String:
	if required_tool_type != "":
		return "Use " + station_name + " (need " + required_tool_type + ")"
	return "Use " + station_name
