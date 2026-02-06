extends PanelContainer
class_name InventorySlot
## Individual inventory slot UI component

signal slot_clicked(slot_index: int, button_index: int)
signal slot_hovered(slot_index: int)
signal item_dropped(from_slot: int, to_slot: int)

@export var slot_index: int = 0
@export var slot_size: int = 64
@export var is_hotbar_slot: bool = false

@onready var item_icon: TextureRect = $MarginContainer/ItemIcon
@onready var placeholder_rect: ColorRect = $MarginContainer/PlaceholderRect
@onready var quantity_label: Label = $MarginContainer/QuantityLabel
@onready var empty_label: Label = $MarginContainer/EmptyLabel

var item: InventoryItem = null
var inventory: Inventory = null
var _default_panel_style: StyleBoxFlat = null

func _ready() -> void:
	# Set up slot appearance
	custom_minimum_size = Vector2(slot_size, slot_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Let this slot receive all mouse input; children would otherwise eat hover/click/drag
	SlotUtils.set_children_mouse_filter_ignore(self)
	# Ensure slot processes input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	var existing = get_theme_stylebox("panel")
	if existing is StyleBoxFlat:
		_default_panel_style = (existing as StyleBoxFlat).duplicate()
	else:
		_default_panel_style = StyleBoxFlat.new()
		_default_panel_style.bg_color = Color(0.2, 0.2, 0.25, 1)
		_default_panel_style.border_color = Color(0.4, 0.4, 0.5, 1)
		_default_panel_style.set_border_width_all(2)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_slot(null)

func update_slot(p_item: InventoryItem) -> void:
	item = p_item
	
	if item and not item.is_empty():
		# Show item
		item_icon.visible = true
		quantity_label.visible = true
		empty_label.visible = false
		
		# Set icon (use placeholder for now)
		if item.get_icon():
			item_icon.texture = item.get_icon()
			placeholder_rect.visible = false
		else:
			# Use placeholder color based on item type
			item_icon.texture = null
			placeholder_rect.color = _get_placeholder_color()
			placeholder_rect.visible = true
		
		# Set quantity
		if item.quantity > 1:
			quantity_label.text = str(item.quantity)
			quantity_label.visible = true
		else:
			quantity_label.visible = false
	else:
		# Show empty slot
		item_icon.visible = false
		placeholder_rect.visible = false
		quantity_label.visible = false
		empty_label.visible = true

func _get_placeholder_color() -> Color:
	return SlotUtils.get_placeholder_color(item)

func set_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory

func get_drag_data(position: Vector2) -> Variant:
	print("[DragDebug] get_drag_data called on slot %d (hotbar=%s)" % [slot_index, is_hotbar_slot])
	print("[DragDebug]   item=%s, empty=%s, inventory=%s" % [item, item.is_empty() if item else "N/A", inventory])
	
	if not item or item.is_empty():
		print("[DragDebug]   -> returning null: no item")
		return null
	if not inventory:
		print("[DragDebug]   -> returning null: no inventory")
		return null
	
	var source = DragData.DragSource.HOTBAR if is_hotbar_slot else DragData.DragSource.INVENTORY
	var drag_data = DragData.new(source, slot_index, item, inventory)
	var preview = _create_drag_preview()
	if preview:
		set_drag_preview(preview)
		print("[DragDebug]   -> drag preview set")
	else:
		print("[DragDebug]   -> WARNING: preview is null")
	print("[DragDebug]   -> drag started successfully with data: source=%d, slot=%d" % [source, slot_index])
	return drag_data

func can_drop_data(position: Vector2, data: Variant) -> bool:
	print("[DragDebug] can_drop_data called on slot %d (hotbar=%s)" % [slot_index, is_hotbar_slot])
	# Clear previous state
	_last_drag_data = null
	_last_can_drop = false
	
	if data == null:
		print("[DragDebug]   -> false: data is null")
		return false
	var drag_data = data as DragData
	if drag_data == null:
		print("[DragDebug]   -> false: data is not DragData (type=%s)" % [typeof(data)])
		return false
	
	print("[DragDebug]   drag_data: source_type=%d, source_slot=%d" % [drag_data.source_type, drag_data.source_slot_index])
	
	# Prevent dropping on same slot
	if drag_data.source_type == DragData.DragSource.INVENTORY and drag_data.source_slot_index == slot_index and not is_hotbar_slot:
		print("[DragDebug]   -> false: same inventory slot")
		return false
	if drag_data.source_type == DragData.DragSource.HOTBAR and drag_data.source_slot_index == slot_index and is_hotbar_slot:
		print("[DragDebug]   -> false: same hotbar slot")
		return false
	
	# Store for potential manual drop handling
	_last_drag_data = drag_data
	_last_can_drop = true
	# Tag this slot with current global counter and unique slot ID
	var global_counter = SlotUtils.get_drop_counter()
	_my_drop_counter = global_counter
	_slot_id = slot_index + (1000 if is_hotbar_slot else 0)  # Unique ID
	SlotUtils.set_last_drop_slot(_slot_id)
	
	print("[DragDebug]   -> true: accepting drop (counter=%d, slot_id=%d)" % [_my_drop_counter, _slot_id])
	return true

var _last_drag_data: DragData = null
var _last_can_drop: bool = false


var _my_drop_counter: int = 0
var _slot_id: int = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
		_clear_hover_style()
		var global_counter = SlotUtils.get_drop_counter()
		print("[DragDebug] NOTIFICATION_DRAG_END received on slot %d (my_counter=%d, global=%d)" % [slot_index, _my_drop_counter, global_counter])
		
		# Only process if this slot was the LAST one to have can_drop_data called
		# and it was called in this drag operation
		if _last_drag_data != null and _last_can_drop and _my_drop_counter == global_counter and SlotUtils.get_last_drop_slot() == _slot_id:
			print("[DragDebug] Executing manual drop on slot %d" % slot_index)
			# Increment counter to prevent other slots from processing
			SlotUtils.set_drop_counter(global_counter + 1)
			SlotUtils.set_last_drop_slot(-1)
			# Execute the drop logic directly
			if is_hotbar_slot:
				_handle_hotbar_drop(_last_drag_data)
			else:
				_handle_inventory_drop(_last_drag_data)
		
		# Always clear this slot's state
		_last_drag_data = null
		_last_can_drop = false
		_my_drop_counter = 0
		_slot_id = 0

func drop_data(position: Vector2, data: Variant) -> void:
	print("[DragDebug] drop_data called on slot %d (hotbar=%s)" % [slot_index, is_hotbar_slot])
	if data == null:
		print("[DragDebug]   -> data is null, returning")
		return
	var drag_data = data as DragData
	if drag_data == null:
		print("[DragDebug]   -> data is not DragData, returning")
		return
	
	print("[DragDebug]   processing drop from source_type=%d, slot=%d" % [drag_data.source_type, drag_data.source_slot_index])
	
	# Handle hotbar slot drops
	if is_hotbar_slot:
		print("[DragDebug]   -> handling as hotbar drop")
		_handle_hotbar_drop(drag_data)
		return
	
	# Handle inventory slot drops
	print("[DragDebug]   -> handling as inventory drop")
	_handle_inventory_drop(drag_data)

func _handle_hotbar_drop(drag_data: DragData) -> void:
	if not inventory:
		return
	
	match drag_data.source_type:
		DragData.DragSource.INVENTORY:
			# Move from inventory bag to hotbar
			inventory.move_to_hotbar(drag_data.source_slot_index, slot_index)
		
		DragData.DragSource.HOTBAR:
			# Move between hotbar slots
			inventory.move_hotbar_to_hotbar(drag_data.source_slot_index, slot_index)
		
		DragData.DragSource.EQUIPMENT:
			# Equip from equipment to hotbar (equip to tool slot)
			if drag_data.equipment and drag_data.item:
				# Only tools can go to hotbar from equipment
				if drag_data.item.item_data and drag_data.item.item_data.item_type == ItemData.ItemType.TOOL:
					# Unequip and put in hotbar
					var unequipped = drag_data.equipment.unequip_item(drag_data.source_slot_index)
					if unequipped:
						# Check if hotbar slot has item - swap back to equipment
						var existing_hotbar_item = inventory.get_hotbar_slot(slot_index)
						if existing_hotbar_item and not existing_hotbar_item.is_empty():
							# Try to equip the hotbar item in the equipment slot
							if drag_data.equipment._can_equip_in_slot(existing_hotbar_item.item_data, drag_data.source_slot_index):
								drag_data.equipment.equip_item(existing_hotbar_item, drag_data.source_slot_index)
						
						# Put unequipped item in hotbar
						inventory.hotbar_slots[slot_index] = unequipped
						inventory.hotbar_changed.emit(slot_index)

func _handle_inventory_drop(drag_data: DragData) -> void:
	if not inventory:
		return
	
	match drag_data.source_type:
		DragData.DragSource.INVENTORY:
			# Move within inventory
			inventory.move_item(drag_data.source_slot_index, slot_index)
			item_dropped.emit(drag_data.source_slot_index, slot_index)
		
		DragData.DragSource.HOTBAR:
			# Move from hotbar to specific inventory slot
			var ok = inventory.move_to_bag(drag_data.source_slot_index, slot_index)
			if ok:
				print("[Inventory] Moved from hotbar %d to bag slot %d" % [drag_data.source_slot_index, slot_index])
		
		DragData.DragSource.EQUIPMENT:
			# Unequip to specific inventory slot
			if drag_data.equipment:
				var unequipped_item = drag_data.equipment.unequip_item(drag_data.source_slot_index)
				if unequipped_item:
					var current_item = inventory.get_slot(slot_index)
					
					if not current_item or current_item.is_empty():
						# Slot is empty, place item here
						inventory.slots[slot_index] = unequipped_item
						inventory.inventory_changed.emit(slot_index)
					elif current_item.can_stack_with(unequipped_item):
						# Can stack, combine them
						var overflow = current_item.add_amount(unequipped_item.quantity)
						if overflow > 0:
							unequipped_item.quantity = overflow
							# Find another slot for overflow
							for i in range(inventory.max_slots):
								var slot_item = inventory.get_slot(i)
								if not slot_item or slot_item.is_empty():
									inventory.slots[i] = unequipped_item
									inventory.inventory_changed.emit(i)
									break
						inventory.inventory_changed.emit(slot_index)
					else:
						# Swap items - put current item in equipment
						if drag_data.equipment._can_equip_in_slot(current_item.item_data, drag_data.source_slot_index):
							drag_data.equipment.equip_item(current_item, drag_data.source_slot_index)
							inventory.slots[slot_index] = unequipped_item
							inventory.inventory_changed.emit(slot_index)
						else:
							# Can't swap, find empty slot for unequipped item
							for i in range(inventory.max_slots):
								var slot_item = inventory.get_slot(i)
								if not slot_item or slot_item.is_empty():
									inventory.slots[i] = unequipped_item
									inventory.inventory_changed.emit(i)
									break

func _create_drag_preview() -> Control:
	return SlotUtils.create_drag_preview(item, slot_size)

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drag_start_pos = get_global_mouse_position()
			_is_dragging = true
			print("[DragDebug] Mouse pressed on slot %d" % slot_index)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = false
			print("[DragDebug] Mouse released on slot %d" % slot_index)
			# Note: click event is emitted regardless; drag operation handles itself via force_drag
			slot_clicked.emit(slot_index, event.button_index)

func _process(delta: float) -> void:
	if _is_dragging:
		var current_pos = get_global_mouse_position()
		var distance = _drag_start_pos.distance_to(current_pos)
		if distance > DRAG_THRESHOLD:
			_is_dragging = false
			print("[DragDebug] Drag threshold reached on slot %d" % slot_index)
			_start_drag()

func _start_drag() -> void:
	if not item or item.is_empty():
		print("[DragDebug] Cannot drag: no item in slot %d" % slot_index)
		return
	if not inventory:
		print("[DragDebug] Cannot drag: no inventory reference in slot %d" % slot_index)
		return
	
	var source = DragData.DragSource.HOTBAR if is_hotbar_slot else DragData.DragSource.INVENTORY
	var drag_data = DragData.new(source, slot_index, item, inventory)
	var preview = _create_drag_preview()
	if preview:
		set_drag_preview(preview)
		print("[DragDebug] Drag preview created for slot %d" % slot_index)
	print("[DragDebug] Starting force_drag from slot %d" % slot_index)
	force_drag(drag_data, preview)

func _on_mouse_entered() -> void:
	slot_hovered.emit(slot_index)
	var drag_data = get_viewport().gui_get_drag_data()
	if drag_data:
		# Show valid drop highlight
		if _can_drop(drag_data):
			modulate = Color(0.8, 1.0, 0.8)
			_apply_hover_style(true)
		else:
			modulate = Color(1.0, 0.8, 0.8)
			_apply_hover_style(false)
	else:
		modulate = Color(1.15, 1.15, 1.15)
		_apply_hover_style(true)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	_clear_hover_style()

func _can_drop(data: Variant) -> bool:
	if data == null:
		return false
	if not (data is DragData):
		return false
	return can_drop_data(Vector2.ZERO, data)

func _apply_hover_style(valid: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.3, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.85, 0.5, 1) if valid else Color(0.85, 0.5, 0.5, 1)
	add_theme_stylebox_override("panel", style)

func _clear_hover_style() -> void:
	if _default_panel_style:
		add_theme_stylebox_override("panel", _default_panel_style)
	else:
		remove_theme_stylebox_override("panel")
