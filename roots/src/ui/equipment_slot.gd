extends PanelContainer
class_name EquipmentSlotUI
## Equipment slot UI component for character UI

signal slot_clicked(slot_type: int, button_index: int)
signal slot_hovered(slot_type: int)

@export var slot_type: int = Equipment.EquipmentSlot.GEAR_HEAD
@export var slot_size: int = 64
@export var slot_label: String = ""

@onready var item_icon: TextureRect = $MarginContainer/VBoxContainer/ItemIcon
@onready var placeholder_rect: ColorRect = $MarginContainer/VBoxContainer/PlaceholderRect
@onready var label: Label = $MarginContainer/VBoxContainer/Label
@onready var durability_bar: ProgressBar = $MarginContainer/VBoxContainer/DurabilityBar

var item: InventoryItem = null
var equipment: Equipment = null
var inventory: Inventory = null

func _ready() -> void:
	# Set up slot appearance
	custom_minimum_size = Vector2(slot_size, slot_size + 30)
	
	# Enable mouse input for drag-and-drop; children should not block
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(self)
	
	# Ensure slot processes input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set label text
	if slot_label != "":
		label.text = slot_label
	else:
		# Use Equipment class to get slot name
		var slot_name = ""
		match slot_type:
			Equipment.EquipmentSlot.GEAR_HEAD: slot_name = "Head"
			Equipment.EquipmentSlot.GEAR_CHEST: slot_name = "Chest"
			Equipment.EquipmentSlot.GEAR_LEGS: slot_name = "Legs"
			Equipment.EquipmentSlot.GEAR_FEET: slot_name = "Feet"
			Equipment.EquipmentSlot.TOOL_1: slot_name = "Tool 1"
			Equipment.EquipmentSlot.TOOL_2: slot_name = "Tool 2"
			Equipment.EquipmentSlot.TOOL_3: slot_name = "Tool 3"
			Equipment.EquipmentSlot.WEAPON: slot_name = "Weapon"
		label.text = slot_name
	
	# Connect mouse signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initialize as empty
	update_slot(null)
	
	# Hide durability bar initially
	durability_bar.visible = false

func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)

func update_slot(p_item: InventoryItem) -> void:
	print("[EquipmentSlot %d] update_slot called with item: %s" % [slot_type, p_item.get_item_name() if p_item else "null"])
	item = p_item
	
	if item and not item.is_empty():
		print("[EquipmentSlot %d] Showing item: %s" % [slot_type, item.get_item_name()])
		# Show item
		item_icon.visible = true
		placeholder_rect.visible = false
		label.modulate = Color.WHITE
		
		# Set icon (use placeholder for now)
		var icon = item.get_icon()
		if icon:
			print("[EquipmentSlot %d] Setting icon texture" % slot_type)
			item_icon.texture = icon
			placeholder_rect.visible = false
		else:
			print("[EquipmentSlot %d] No icon, showing placeholder" % slot_type)
			# Use placeholder color based on item type
			item_icon.texture = null
			placeholder_rect.color = _get_placeholder_color()
			placeholder_rect.visible = true
		
		# Show durability bar if item has durability
		if item.item_data and item.item_data.has_durability:
			durability_bar.visible = true
			durability_bar.value = item.get_durability_percent()
		else:
			durability_bar.visible = false
	else:
		print("[EquipmentSlot %d] Showing empty slot" % slot_type)
		# Show empty slot
		item_icon.visible = false
		placeholder_rect.visible = false
		durability_bar.visible = false
		label.modulate = Color(0.6, 0.6, 0.6)

func _get_placeholder_color() -> Color:
	# Return different colors based on item type for placeholder
	if not item or not item.item_data:
		return Color.WHITE
	
	match item.item_data.item_type:
		ItemData.ItemType.TOOL:
			return Color(0.8, 0.6, 0.4)  # Brown
		ItemData.ItemType.WEAPON:
			return Color(0.8, 0.2, 0.2)  # Dark red
		ItemData.ItemType.EQUIPMENT:
			return Color(0.4, 0.6, 0.8)  # Blue
		_:
			return Color.WHITE

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

var _last_drag_data: DragData = null
var _last_can_drop: bool = false

# Use Engine meta to share state across all slot types (shared with InventorySlot)
const DROP_COUNTER_KEY = "_global_drop_counter"
const LAST_DROP_SLOT_KEY = "_last_drop_slot_id"

func _get_drop_counter() -> int:
	if Engine.has_meta(DROP_COUNTER_KEY):
		return Engine.get_meta(DROP_COUNTER_KEY)
	return 0

func _set_drop_counter(value: int) -> void:
	Engine.set_meta(DROP_COUNTER_KEY, value)

func _get_last_drop_slot() -> int:
	if Engine.has_meta(LAST_DROP_SLOT_KEY):
		return Engine.get_meta(LAST_DROP_SLOT_KEY)
	return -1

func _set_last_drop_slot(slot_id: int) -> void:
	Engine.set_meta(LAST_DROP_SLOT_KEY, slot_id)

var _my_drop_counter: int = 0
var _slot_id: int = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		var global_counter = _get_drop_counter()
		print("[DragDebug] EquipmentSlot NOTIFICATION_DRAG_END received on slot %d (my_counter=%d, global=%d)" % [slot_type, _my_drop_counter, global_counter])
		
		# Only process if this slot was the LAST one to have can_drop_data called
		if _last_drag_data != null and _last_can_drop and _my_drop_counter == global_counter and _get_last_drop_slot() == _slot_id:
			print("[DragDebug] Executing manual drop on equipment slot %d" % slot_type)
			# Increment counter to prevent other slots from processing
			_set_drop_counter(global_counter + 1)
			_set_last_drop_slot(-1)
			# Execute drop logic directly
			if _last_drag_data.source_type == DragData.DragSource.INVENTORY or _last_drag_data.source_type == DragData.DragSource.HOTBAR:
				_handle_inventory_to_equipment_drop(_last_drag_data)
			elif _last_drag_data.source_type == DragData.DragSource.EQUIPMENT:
				_handle_equipment_swap(_last_drag_data)
		
		# Always clear this slot's state
		_last_drag_data = null
		_last_can_drop = false
		_my_drop_counter = 0
		_slot_id = 0
		# Reset visual state after drag ends
		modulate = Color.WHITE

func _handle_inventory_to_equipment_drop(drag_data: DragData) -> void:
	# This is the same logic from drop_data for inventory->equipment drops
	if equipment and drag_data.inventory:
		var item_to_equip = drag_data.inventory.get_slot(drag_data.source_slot_index)
		if item_to_equip and not item_to_equip.is_empty():
			var currently_equipped = equipment.get_equipped_item(slot_type)
			if equipment.equip_item(item_to_equip, slot_type):
				drag_data.inventory.remove_from_slot(drag_data.source_slot_index, 1)
				if currently_equipped and not currently_equipped.is_empty():
					var source_slot_item = drag_data.inventory.get_slot(drag_data.source_slot_index)
					if not source_slot_item or source_slot_item.is_empty():
						drag_data.inventory.slots[drag_data.source_slot_index] = currently_equipped
						drag_data.inventory.inventory_changed.emit(drag_data.source_slot_index)
					else:
						for i in range(drag_data.inventory.max_slots):
							var slot_item = drag_data.inventory.get_slot(i)
							if not slot_item or slot_item.is_empty():
								drag_data.inventory.slots[i] = currently_equipped
								drag_data.inventory.inventory_changed.emit(i)
								break

func _handle_equipment_swap(drag_data: DragData) -> void:
	# Handle swapping between equipment slots
	if equipment and drag_data.equipment:
		var source_item = drag_data.equipment.get_equipped_item(drag_data.source_slot_index)
		var target_item = equipment.get_equipped_item(slot_type)
		if source_item:
			drag_data.equipment.equip_item(source_item, slot_type)
			if target_item:
				drag_data.equipment.equip_item(target_item, drag_data.source_slot_index)
			else:
				drag_data.equipment.unequip_item(drag_data.source_slot_index)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drag_start_pos = get_global_mouse_position()
			_is_dragging = true
			print("[DragDebug] Equipment slot %d: Mouse pressed, starting drag watch" % slot_type)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = false
			print("[DragDebug] Equipment slot %d: Mouse released" % slot_type)
			slot_clicked.emit(slot_type, event.button_index)

func _process(delta: float) -> void:
	if _is_dragging:
		var current_pos = get_global_mouse_position()
		var distance = _drag_start_pos.distance_to(current_pos)
		if distance > DRAG_THRESHOLD:
			_is_dragging = false
			print("[DragDebug] Equipment slot %d: Drag threshold reached, starting drag" % slot_type)
			_start_drag()

func _start_drag() -> void:
	if not item or item.is_empty():
		print("[DragDebug] Equipment slot %d: Cannot drag - no item" % slot_type)
		return
	if not equipment:
		print("[DragDebug] Equipment slot %d: Cannot drag - no equipment reference" % slot_type)
		return
	
	var drag_data = DragData.new(DragData.DragSource.EQUIPMENT, slot_type, item, inventory, equipment)
	var preview = _create_drag_preview()
	if preview:
		set_drag_preview(preview)
		print("[DragDebug] Equipment slot %d: Drag preview created" % slot_type)
	print("[DragDebug] Equipment slot %d: Starting force_drag" % slot_type)
	force_drag(drag_data, preview)

func set_equipment(p_equipment: Equipment) -> void:
	equipment = p_equipment

func set_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory

func get_drag_data(position: Vector2) -> Variant:
	# Start drag operation from equipment slot
	if not item or item.is_empty():
		return null
	
	if not equipment:
		return null
	
	# Create drag data
	var drag_data = DragData.new(DragData.DragSource.EQUIPMENT, slot_type, item, inventory, equipment)
	
	# Create drag preview
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	return drag_data

func can_drop_data(position: Vector2, data: Variant) -> bool:
	print("[DragDebug] EquipmentSlot.can_drop_data called on slot_type=%d" % slot_type)
	# Clear previous state
	_last_drag_data = null
	_last_can_drop = false
	
	if data == null:
		print("[DragDebug]   -> false: data is null")
		return false
	var drag_data = data as DragData
	if drag_data == null:
		print("[DragDebug]   -> false: data is not DragData (type=%s)" % typeof(data))
		return false
	
	print("[DragDebug]   drag_data: source_type=%d, source_slot=%d, item=%s" % [drag_data.source_type, drag_data.source_slot_index, drag_data.item.get_item_name() if drag_data.item else "null"])
	
	# Can't drop on itself
	if drag_data.source_type == DragData.DragSource.EQUIPMENT and drag_data.source_slot_index == slot_type:
		print("[DragDebug]   -> false: same slot")
		return false
	
	# Can only drop items from inventory (or hotbar for tools)
	if drag_data.source_type != DragData.DragSource.INVENTORY and drag_data.source_type != DragData.DragSource.HOTBAR:
		print("[DragDebug]   -> false: source type not allowed (%d)" % drag_data.source_type)
		return false
	
	# Check if item type matches slot type
	if not drag_data.item or not drag_data.item.item_data:
		print("[DragDebug]   -> false: no item data")
		return false
	
	var item_data = drag_data.item.item_data
	print("[DragDebug]   item_type=%d, slot_type=%d" % [item_data.item_type, slot_type])
	
	# Validate item type matches slot
	var valid = false
	match slot_type:
		Equipment.EquipmentSlot.GEAR_HEAD, Equipment.EquipmentSlot.GEAR_CHEST, Equipment.EquipmentSlot.GEAR_LEGS, Equipment.EquipmentSlot.GEAR_FEET:
			valid = item_data.item_type == ItemData.ItemType.EQUIPMENT
			print("[DragDebug]   -> equipment slot valid=%s" % valid)
		Equipment.EquipmentSlot.TOOL_1, Equipment.EquipmentSlot.TOOL_2, Equipment.EquipmentSlot.TOOL_3:
			valid = item_data.item_type == ItemData.ItemType.TOOL
			print("[DragDebug]   -> tool slot valid=%s" % valid)
		Equipment.EquipmentSlot.WEAPON:
			valid = item_data.item_type == ItemData.ItemType.WEAPON
			print("[DragDebug]   -> weapon slot valid=%s" % valid)
		_:
			print("[DragDebug]   -> false: unknown slot type")
	
	# Store for potential manual drop handling
	if valid:
		_last_drag_data = drag_data
		_last_can_drop = true
		# Tag this slot with current global counter and unique slot ID
		var global_counter = _get_drop_counter()
		_my_drop_counter = global_counter
		_slot_id = 2000 + slot_type  # Equipment slots start at 2000 to avoid collision with inventory
		_set_last_drop_slot(_slot_id)
		print("[DragDebug]   -> slot tagged with counter=%d, slot_id=%d" % [_my_drop_counter, _slot_id])
	
	return valid

func drop_data(position: Vector2, data: Variant) -> void:
	print("[DragDebug] EquipmentSlot.drop_data called on slot_type=%d" % slot_type)
	if data == null:
		print("[DragDebug]   -> data is null, returning")
		return
	var drag_data = data as DragData
	if drag_data == null:
		print("[DragDebug]   -> data is not DragData, returning")
		return
	
	print("[DragDebug]   source_type=%d, source_slot=%d" % [drag_data.source_type, drag_data.source_slot_index])
	
	if drag_data.source_type == DragData.DragSource.INVENTORY or drag_data.source_type == DragData.DragSource.HOTBAR:
		# Equipping item from inventory
		if equipment and drag_data.inventory:
			var item_to_equip = drag_data.inventory.get_slot(drag_data.source_slot_index)
			if item_to_equip and not item_to_equip.is_empty():
				print("[DragDebug]   Equipping %s to slot %d" % [item_to_equip.get_item_name(), slot_type])
				# Check if there's already an item equipped
				var currently_equipped = equipment.get_equipped_item(slot_type)
				
				# Try to equip the new item
				if equipment.equip_item(item_to_equip, slot_type):
					print("[DragDebug]   -> Equip successful")
					# Remove from inventory
					drag_data.inventory.remove_from_slot(drag_data.source_slot_index, 1)
					
					# If there was an equipped item, return it to inventory
					if currently_equipped and not currently_equipped.is_empty():
						print("[DragDebug]   -> Returning equipped item to inventory: %s" % currently_equipped.get_item_name())
						# Try to add back to the source slot first (swap)
						var source_slot_item = drag_data.inventory.get_slot(drag_data.source_slot_index)
						if not source_slot_item or source_slot_item.is_empty():
							# Source slot is empty, put the equipped item there
							drag_data.inventory.slots[drag_data.source_slot_index] = currently_equipped
							drag_data.inventory.inventory_changed.emit(drag_data.source_slot_index)
						else:
							# Find another empty slot
							for i in range(drag_data.inventory.max_slots):
								var slot_item = drag_data.inventory.get_slot(i)
								if not slot_item or slot_item.is_empty():
									drag_data.inventory.slots[i] = currently_equipped
									drag_data.inventory.inventory_changed.emit(i)
									break
				else:
					print("[DragDebug]   -> Equip FAILED")
			else:
				print("[DragDebug]   -> No item to equip or item is empty")
		else:
			print("[DragDebug]   -> Missing equipment or inventory reference")
	
	elif drag_data.source_type == DragData.DragSource.EQUIPMENT:
		# Swapping between equipment slots
		if equipment and drag_data.equipment:
			# Get the item from source slot
			var source_item = drag_data.equipment.get_equipped_item(drag_data.source_slot_index)
			var target_item = equipment.get_equipped_item(slot_type)
			
			if source_item and not source_item.is_empty():
				# Check if items can be swapped (item types match respective slots)
				var can_swap = true
				
				# Validate source item can go in target slot
				if not equipment._can_equip_in_slot(source_item.item_data, slot_type):
					can_swap = false
				
				# Validate target item can go in source slot (if there is one)
				if target_item and not target_item.is_empty():
					if not drag_data.equipment._can_equip_in_slot(target_item.item_data, drag_data.source_slot_index):
						can_swap = false
				
				if can_swap:
					# Perform the swap
					drag_data.equipment.equipped_items[drag_data.source_slot_index] = target_item
					equipment.equipped_items[slot_type] = source_item
					
					# Emit signals for both slots
					drag_data.equipment.equipment_changed.emit(drag_data.equipment.get_slot_name(drag_data.source_slot_index))
					drag_data.equipment.item_equipped.emit(source_item, equipment.get_slot_name(slot_type))
					if target_item:
						drag_data.equipment.item_equipped.emit(target_item, drag_data.equipment.get_slot_name(drag_data.source_slot_index))
					else:
						drag_data.equipment.item_unequipped.emit(drag_data.equipment.get_slot_name(drag_data.source_slot_index))
					equipment.equipment_changed.emit(equipment.get_slot_name(slot_type))
					if source_item:
						equipment.item_equipped.emit(source_item, equipment.get_slot_name(slot_type))
					else:
						equipment.item_unequipped.emit(equipment.get_slot_name(slot_type))

func _create_drag_preview() -> Control:
	# Create visual preview for dragging
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(slot_size, slot_size)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.4, 0.8)
	style.border_color = Color(0.6, 0.6, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	preview.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	preview.add_child(margin)
	
	if item and not item.is_empty():
		# Show item icon or placeholder
		if item.get_icon():
			var icon = TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = item.get_icon()
			margin.add_child(icon)
		else:
			var color_rect = ColorRect.new()
			color_rect.color = _get_placeholder_color()
			margin.add_child(color_rect)
	
	return preview

func _on_mouse_entered() -> void:
	slot_hovered.emit(slot_type)
	var drag_data = get_viewport().gui_get_drag_data()
	if drag_data:
		# Show valid drop highlight
		if can_drop_data(Vector2.ZERO, drag_data):
			modulate = Color(0.8, 1.0, 0.8)  # Greenish tint for valid drop
		else:
			modulate = Color(1.0, 0.8, 0.8)  # Reddish tint for invalid drop
	else:
		modulate = Color(1.2, 1.2, 1.2)  # Highlight on hover

func _on_mouse_exited() -> void:
	var drag_data = get_viewport().gui_get_drag_data()
	if not drag_data:
		modulate = Color.WHITE  # Reset color
