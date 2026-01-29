extends RefCounted
class_name DragData
## Data structure for drag-and-drop operations

enum DragSource {
	INVENTORY,
	EQUIPMENT,
	HOTBAR
}

var source_type: DragSource
var source_slot_index: int
var item: InventoryItem
var inventory: Inventory = null
var equipment: Equipment = null

func _init(p_source_type: DragSource, p_source_slot_index: int, p_item: InventoryItem, p_inventory: Inventory = null, p_equipment: Equipment = null) -> void:
	source_type = p_source_type
	source_slot_index = p_source_slot_index
	item = p_item
	inventory = p_inventory
	equipment = p_equipment
