extends Resource
class_name Inventory
## Player inventory system with grid-based slots

signal inventory_changed(slot_index: int)
signal item_added(item: InventoryItem, slot_index: int)
signal item_removed(slot_index: int)
signal item_moved(from_slot: int, to_slot: int)
signal hotbar_changed(slot_index: int)

@export var slots: Array[InventoryItem] = []
@export var max_slots: int = 36
@export var hotbar_size: int = 8

var item_database: ItemDatabase = null
var hotbar_slots: Array = []  # 8 slots, independent of bag; indices 0..7

func _init(p_max_slots: int = 36) -> void:
	max_slots = p_max_slots
	slots.resize(max_slots)
	for i in range(max_slots):
		slots[i] = null
	for i in range(hotbar_size):
		hotbar_slots.append(null)

func initialize(database: ItemDatabase) -> void:
	item_database = database
	if hotbar_slots.size() != hotbar_size:
		hotbar_slots.resize(hotbar_size)

# Add item to inventory, returns remaining quantity that couldn't fit
func add_item(item_data: ItemData, quantity: int = 1, quality: ItemData.ItemQuality = ItemData.ItemQuality.NORMAL) -> int:
	if not item_data:
		return quantity
	
	var remaining = quantity
	
	# First, try to stack with existing items
	if item_data.is_stackable:
		for i in range(max_slots):
			if slots[i] and slots[i].can_stack_with(InventoryItem.new(item_data)):
				remaining = slots[i].add_amount(remaining)
				inventory_changed.emit(i)
				item_added.emit(slots[i], i)
				if remaining <= 0:
					return 0
	
	# Then, fill empty slots
	for i in range(max_slots):
		if slots[i] == null or slots[i].is_empty():
			var new_item = InventoryItem.new(item_data, min(remaining, item_data.max_stack_size))
			new_item.quality = quality
			slots[i] = new_item
			remaining -= new_item.quantity
			inventory_changed.emit(i)
			item_added.emit(new_item, i)
			if remaining <= 0:
				return 0
	
	return remaining  # Return overflow

# Remove item from slot, returns amount actually removed
func remove_from_slot(slot_index: int, amount: int = 1) -> int:
	if slot_index < 0 or slot_index >= max_slots:
		return 0
	
	if not slots[slot_index]:
		return 0
	
	var removed = slots[slot_index].remove_amount(amount)
	if slots[slot_index].is_empty():
		slots[slot_index] = null
		item_removed.emit(slot_index)
	else:
		inventory_changed.emit(slot_index)
	
	return removed

# Remove specific item by ID, returns amount removed
func remove_item(item_id: String, amount: int = 1) -> int:
	var to_remove = amount
	
	for i in range(max_slots):
		if slots[i] and slots[i].item_data and slots[i].item_data.item_id == item_id:
			var removed = remove_from_slot(i, to_remove)
			to_remove -= removed
			if to_remove <= 0:
				return amount
	
	return amount - to_remove

# Check if inventory has enough of an item
func has_item(item_id: String, amount: int = 1) -> bool:
	var count = 0
	for slot in slots:
		if slot and slot.item_data and slot.item_data.item_id == item_id:
			count += slot.quantity
			if count >= amount:
				return true
	return false

# Get total count of an item
func get_item_count(item_id: String) -> int:
	var count = 0
	for slot in slots:
		if slot and slot.item_data and slot.item_data.item_id == item_id:
			count += slot.quantity
	return count

# Get item at slot
func get_slot(slot_index: int) -> InventoryItem:
	if slot_index < 0 or slot_index >= max_slots:
		return null
	return slots[slot_index]

# Move item between slots
func move_item(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= max_slots or to_slot < 0 or to_slot >= max_slots:
		return false
	if from_slot == to_slot:
		return false
	
	var from_item = slots[from_slot]
	var to_item = slots[to_slot]
	
	# If target slot is empty, just move
	if not to_item or to_item.is_empty():
		slots[to_slot] = from_item
		slots[from_slot] = null
		inventory_changed.emit(from_slot)
		inventory_changed.emit(to_slot)
		item_moved.emit(from_slot, to_slot)
		return true
	
	# If items can stack, combine them
	if from_item and to_item and from_item.can_stack_with(to_item):
		var overflow = to_item.add_amount(from_item.quantity)
		if overflow > 0:
			from_item.quantity = overflow
		else:
			slots[from_slot] = null
			item_removed.emit(from_slot)
		inventory_changed.emit(from_slot)
		inventory_changed.emit(to_slot)
		return true
	
	# Otherwise, swap items
	slots[from_slot] = to_item
	slots[to_slot] = from_item
	inventory_changed.emit(from_slot)
	inventory_changed.emit(to_slot)
	item_moved.emit(from_slot, to_slot)
	return true

# Split a stack
func split_stack(slot_index: int, amount: int) -> bool:
	if slot_index < 0 or slot_index >= max_slots:
		return false
	
	var item = slots[slot_index]
	if not item or item.quantity <= 1 or amount >= item.quantity:
		return false
	
	# Find empty slot
	for i in range(max_slots):
		if i != slot_index and (not slots[i] or slots[i].is_empty()):
			# Remove from original
			item.remove_amount(amount)
			# Create new stack
			var new_item = InventoryItem.new(item.item_data, amount)
			new_item.durability = item.durability
			new_item.quality = item.quality
			slots[i] = new_item
			inventory_changed.emit(slot_index)
			inventory_changed.emit(i)
			item_added.emit(new_item, i)
			return true
	
	return false

# Hotbar: 8 separate slots (not the first 8 bag slots)
func get_hotbar_slot(slot_index: int) -> InventoryItem:
	if slot_index < 0 or slot_index >= hotbar_size:
		return null
	if slot_index >= hotbar_slots.size():
		return null
	var v = hotbar_slots[slot_index]
	return v if v is InventoryItem else null

func set_hotbar_slot(slot_index: int, item: InventoryItem) -> void:
	if slot_index < 0 or slot_index >= hotbar_size:
		return
	hotbar_slots[slot_index] = item
	hotbar_changed.emit(slot_index)

# Move one item from bag slot to hotbar slot (or swap if hotbar slot has item)
func move_to_hotbar(from_bag_slot: int, to_hotbar_slot: int) -> bool:
	if from_bag_slot < 0 or from_bag_slot >= max_slots or to_hotbar_slot < 0 or to_hotbar_slot >= hotbar_size:
		print("[Inventory] move_to_hotbar: bad indices bag=%d hotbar=%d" % [from_bag_slot, to_hotbar_slot])
		return false
	# Ensure hotbar_slots is sized (in case of older save / init order)
	while hotbar_slots.size() < hotbar_size:
		hotbar_slots.append(null)
	var item = get_slot(from_bag_slot)
	if not item or item.is_empty():
		print("[Inventory] move_to_hotbar: no item in bag slot %d" % from_bag_slot)
		return false
	var existing = get_hotbar_slot(to_hotbar_slot)
	if existing and not existing.is_empty():
		# Swap whole stacks
		slots[from_bag_slot] = existing
		hotbar_slots[to_hotbar_slot] = item
		inventory_changed.emit(from_bag_slot)
		hotbar_changed.emit(to_hotbar_slot)
		return true
	# Move one to hotbar
	var one = InventoryItem.new(item.item_data, 1)
	one.durability = item.durability
	one.quality = item.quality
	remove_from_slot(from_bag_slot, 1)
	hotbar_slots[to_hotbar_slot] = one
	hotbar_changed.emit(to_hotbar_slot)
	return true

# Move between hotbar slots (swap)
func move_hotbar_to_hotbar(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= hotbar_size or to_slot < 0 or to_slot >= hotbar_size or from_slot == to_slot:
		return false
	var a = hotbar_slots[from_slot]
	hotbar_slots[from_slot] = hotbar_slots[to_slot]
	hotbar_slots[to_slot] = a
	hotbar_changed.emit(from_slot)
	hotbar_changed.emit(to_slot)
	return true

# Move item from hotbar slot to bag (find empty or swap at bag_slot)
func move_to_bag(from_hotbar_slot: int, to_bag_slot: int = -1) -> bool:
	if from_hotbar_slot < 0 or from_hotbar_slot >= hotbar_size:
		return false
	var item = get_hotbar_slot(from_hotbar_slot)
	if not item or item.is_empty():
		return false
	if to_bag_slot >= 0 and to_bag_slot < max_slots:
		var existing = get_slot(to_bag_slot)
		if existing and not existing.is_empty():
			# Swap
			hotbar_slots[from_hotbar_slot] = existing
			slots[to_bag_slot] = item
			inventory_changed.emit(to_bag_slot)
			hotbar_changed.emit(from_hotbar_slot)
			return true
		slots[to_bag_slot] = item
		hotbar_slots[from_hotbar_slot] = null
		inventory_changed.emit(to_bag_slot)
		hotbar_changed.emit(from_hotbar_slot)
		return true
	# Find first empty bag slot
	for i in range(max_slots):
		if not slots[i] or slots[i].is_empty():
			slots[i] = item
			hotbar_slots[from_hotbar_slot] = null
			inventory_changed.emit(i)
			hotbar_changed.emit(from_hotbar_slot)
			return true
	return false

# Get hotbar items (the 8 hotbar slots)
func get_hotbar_items() -> Array[InventoryItem]:
	var hotbar: Array[InventoryItem] = []
	for i in range(hotbar_size):
		var it = get_hotbar_slot(i)
		hotbar.append(it if it else null)
	return hotbar

# Use item from slot (for consumables, tools, etc.)
func use_item(slot_index: int, user: Node = null) -> bool:
	if slot_index < 0 or slot_index >= max_slots:
		return false
	
	var item = slots[slot_index]
	if not item or not item.item_data:
		return false
	
	var item_data = item.item_data
	
	# Handle consumables
	if item_data.is_consumable:
		# Apply effects
		if user and user.has_method("restore_hunger"):
			user.restore_hunger(item_data.hunger_restore)
		if user and user.has_method("restore_health"):
			user.restore_health(item_data.health_restore)
		if user and user.has_method("restore_stamina"):
			user.restore_stamina(item_data.stamina_restore)
		
		# Remove one from stack
		remove_from_slot(slot_index, 1)
		return true
	
	# Handle tools (equip/use)
	if item_data.item_type == ItemData.ItemType.TOOL:
		# Tool use is handled by the tool system
		return true
	
	return false

# Use item from hotbar slot (consumables, tools)
func use_hotbar_item(slot_index: int, user: Node = null) -> bool:
	if slot_index < 0 or slot_index >= hotbar_size:
		return false
	var item = get_hotbar_slot(slot_index)
	if not item or not item.item_data:
		return false
	var item_data = item.item_data
	if item_data.is_consumable:
		if user and user.has_method("restore_hunger"):
			user.restore_hunger(item_data.hunger_restore)
		if user and user.has_method("restore_health"):
			user.restore_health(item_data.health_restore)
		if user and user.has_method("restore_stamina"):
			user.restore_stamina(item_data.stamina_restore)
		item.remove_amount(1)
		if item.is_empty():
			hotbar_slots[slot_index] = null
		hotbar_changed.emit(slot_index)
		return true
	if item_data.item_type == ItemData.ItemType.TOOL:
		return true
	return false

# Serialize for saving
func serialize() -> Dictionary:
	var slot_data = []
	for i in range(max_slots):
		if slots[i] and not slots[i].is_empty():
			slot_data.append({"slot": i, "item": slots[i].serialize()})
	var hotbar_data = []
	for i in range(hotbar_size):
		var it = get_hotbar_slot(i)
		if it and not it.is_empty():
			hotbar_data.append({"slot": i, "item": it.serialize()})
	return {
		"max_slots": max_slots,
		"slots": slot_data,
		"hotbar_slots": hotbar_data
	}

# Deserialize from save
func deserialize(data: Dictionary) -> void:
	if not item_database:
		push_error("Cannot deserialize inventory without item database")
		return
	max_slots = data.get("max_slots", 36)
	slots.resize(max_slots)
	for i in range(max_slots):
		slots[i] = null
	for slot_info in data.get("slots", []):
		var slot_index = slot_info.get("slot", -1)
		var item_data = slot_info.get("item", {})
		if slot_index >= 0 and slot_index < max_slots:
			slots[slot_index] = InventoryItem.deserialize(item_data, item_database)
	hotbar_slots.clear()
	for i in range(hotbar_size):
		hotbar_slots.append(null)
	for slot_info in data.get("hotbar_slots", []):
		var slot_index = slot_info.get("slot", -1)
		var item_data = slot_info.get("item", {})
		if slot_index >= 0 and slot_index < hotbar_size:
			hotbar_slots[slot_index] = InventoryItem.deserialize(item_data, item_database)
