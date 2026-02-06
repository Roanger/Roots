extends StaticBody3D
class_name CraftingStationObject
## A placeable crafting station in the world (workbench, forge, anvil, etc.)
## Players interact with E to open the crafting UI filtered to this station type.

@export var station_type: int = 1  # CraftingRecipe.CraftingStation enum value
@export var station_name: String = "Workbench"

@onready var event_bus: Node = get_node_or_null("/root/EventBus")

func get_target_type() -> int:
	return ToolAffinity.TargetType.CRAFTING_STATION

func on_interact(_player: Node3D) -> void:
	# Open crafting UI at this station type via EventBus
	if event_bus:
		event_bus.emit_signal("open_crafting_station", station_type)
		print("Opened crafting station: ", station_name)

func get_interaction_text() -> String:
	return "Use " + station_name
