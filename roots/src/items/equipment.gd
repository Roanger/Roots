extends Resource
class_name Equipment
## Player equipment system for gear, tools, and weapons

signal equipment_changed(slot_type: String)
signal item_equipped(item: InventoryItem, slot_type: String)
signal item_unequipped(slot_type: String)

enum EquipmentSlot {
	GEAR_HEAD,
	GEAR_CHEST,
	GEAR_LEGS,
	GEAR_FEET,
	TOOL_1,
	TOOL_2,
	TOOL_3,
	WEAPON
}

var equipped_items: Dictionary = {}

func _init() -> void:
	# Initialize all slots as empty
	equipped_items[EquipmentSlot.GEAR_HEAD] = null
	equipped_items[EquipmentSlot.GEAR_CHEST] = null
	equipped_items[EquipmentSlot.GEAR_LEGS] = null
	equipped_items[EquipmentSlot.GEAR_FEET] = null
	equipped_items[EquipmentSlot.TOOL_1] = null
	equipped_items[EquipmentSlot.TOOL_2] = null
	equipped_items[EquipmentSlot.TOOL_3] = null
	equipped_items[EquipmentSlot.WEAPON] = null

func get_slot_name(slot: int) -> String:
	match slot:
		EquipmentSlot.GEAR_HEAD: return "Head"
		EquipmentSlot.GEAR_CHEST: return "Chest"
		EquipmentSlot.GEAR_LEGS: return "Legs"
		EquipmentSlot.GEAR_FEET: return "Feet"
		EquipmentSlot.TOOL_1: return "Tool 1"
		EquipmentSlot.TOOL_2: return "Tool 2"
		EquipmentSlot.TOOL_3: return "Tool 3"
		EquipmentSlot.WEAPON: return "Weapon"
		_: return "Unknown"

func equip_item(item: InventoryItem, slot: int) -> bool:
	if not item or item.is_empty():
		return false
	
	var item_data = item.item_data
	if not item_data:
		return false
	
	# Validate item type matches slot
	if not _can_equip_in_slot(item_data, slot):
		return false
	
	# Unequip existing item if any
	var old_item = equipped_items[slot]
	if old_item:
		unequip_item(slot)
	
	# Equip new item
	equipped_items[slot] = item
	equipment_changed.emit(get_slot_name(slot))
	item_equipped.emit(item, get_slot_name(slot))
	return true

func unequip_item(slot: int) -> InventoryItem:
	var item = equipped_items[slot]
	if item:
		equipped_items[slot] = null
		equipment_changed.emit(get_slot_name(slot))
		item_unequipped.emit(get_slot_name(slot))
	return item

func get_equipped_item(slot: int) -> InventoryItem:
	return equipped_items.get(slot, null)

func _can_equip_in_slot(item_data: ItemData, slot: int) -> bool:
	match slot:
		EquipmentSlot.GEAR_HEAD, EquipmentSlot.GEAR_CHEST, EquipmentSlot.GEAR_LEGS, EquipmentSlot.GEAR_FEET:
			return item_data.item_type == ItemData.ItemType.EQUIPMENT
		EquipmentSlot.TOOL_1, EquipmentSlot.TOOL_2, EquipmentSlot.TOOL_3:
			return item_data.item_type == ItemData.ItemType.TOOL
		EquipmentSlot.WEAPON:
			return item_data.item_type == ItemData.ItemType.WEAPON
		_:
			return false

func get_all_equipped_tools() -> Array[InventoryItem]:
	var tools: Array[InventoryItem] = []
	var tool1 = get_equipped_item(EquipmentSlot.TOOL_1)
	var tool2 = get_equipped_item(EquipmentSlot.TOOL_2)
	var tool3 = get_equipped_item(EquipmentSlot.TOOL_3)
	if tool1: tools.append(tool1)
	if tool2: tools.append(tool2)
	if tool3: tools.append(tool3)
	return tools

func get_equipped_weapon() -> InventoryItem:
	return get_equipped_item(EquipmentSlot.WEAPON)

func serialize() -> Dictionary:
	var data = {}
	for slot in EquipmentSlot.values():
		var item = equipped_items[slot]
		if item:
			data[get_slot_name(slot)] = item.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	for slot_name in data.keys():
		var slot = _get_slot_from_name(slot_name)
		if slot != -1:
			# Item deserialization would need item database
			# For now, leave as null
			pass

func _get_slot_from_name(name: String) -> int:
	for slot in EquipmentSlot.values():
		if get_slot_name(slot) == name:
			return slot
	return -1
