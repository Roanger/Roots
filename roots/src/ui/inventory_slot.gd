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
	_set_children_mouse_filter_ignore(self)
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

func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)

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
	# Return different colors based on item type for placeholder
	if not item or not item.item_data:
		return Color.WHITE
	
	match item.item_data.item_type:
		ItemData.ItemType.TOOL:
			return Color(0.8, 0.6, 0.4)  # Brown
		ItemData.ItemType.SEED:
			return Color(0.4, 0.8, 0.4)  # Green
		ItemData.ItemType.MATERIAL:
			return Color(0.6, 0.6, 0.6)  # Gray
		ItemData.ItemType.FOOD:
			return Color(0.8, 0.4, 0.4)  # Red
		_:
			return Color.WHITE

func set_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory

func get_drag_data(position: Vector2) -> Variant:
	if not item or item.is_empty():
		return null
	if not inventory:
		return null
	var source = DragData.DragSource.HOTBAR if is_hotbar_slot else DragData.DragSource.INVENTORY
	var drag_data = DragData.new(source, slot_index, item, inventory)
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	if not is_hotbar_slot:
		print("[Inventory] get_drag_data: slot %d \"%s\" - drag started (move mouse to target, then release)" % [slot_index, item.get_item_name()])
	return drag_data

func can_drop_data(position: Vector2, data: Variant) -> bool:
	if data == null:
		return false
	var drag_data = data as DragData
	if drag_data == null:
		return false
	if drag_data.source_type == DragData.DragSource.INVENTORY and drag_data.source_slot_index == slot_index and not is_hotbar_slot:
		return false
	if drag_data.source_type == DragData.DragSource.HOTBAR and drag_data.source_slot_index == slot_index and is_hotbar_slot:
		return false
	var accept = false
	if drag_data.source_type == DragData.DragSource.INVENTORY:
		accept = true
	elif drag_data.source_type == DragData.DragSource.HOTBAR:
		accept = true
	elif drag_data.source_type == DragData.DragSource.EQUIPMENT:
		accept = true
	if accept and is_hotbar_slot:
		print("[Hotbar] can_drop_data: slot %d accepts drop" % slot_index)
	return accept

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
		_clear_hover_style()

func drop_data(position: Vector2, data: Variant) -> void:
	if data == null:
		return
	var drag_data = data as DragData
	if drag_data == null:
		return
	if is_hotbar_slot:
		if drag_data.source_type == DragData.DragSource.INVENTORY:
			if inventory:
				var ok = inventory.move_to_hotbar(drag_data.source_slot_index, slot_index)
				print("[Hotbar] drop_data: move_to_hotbar bag %d -> hotbar %d = %s" % [drag_data.source_slot_index, slot_index, ok])
			else:
				print("[Hotbar] drop_data: no inventory ref on hotbar slot")
		elif drag_data.source_type == DragData.DragSource.HOTBAR:
			if inventory:
				inventory.move_hotbar_to_hotbar(drag_data.source_slot_index, slot_index)
		return
	if drag_data.source_type == DragData.DragSource.INVENTORY:
		if inventory:
			inventory.move_item(drag_data.source_slot_index, slot_index)
			item_dropped.emit(drag_data.source_slot_index, slot_index)
	elif drag_data.source_type == DragData.DragSource.HOTBAR:
		if inventory:
			inventory.move_to_bag(drag_data.source_slot_index, slot_index)
	elif drag_data.source_type == DragData.DragSource.EQUIPMENT:
		if inventory and drag_data.equipment:
			var unequipped_item = drag_data.equipment.unequip_item(drag_data.source_slot_index)
			if unequipped_item:
				var current_item = inventory.get_slot(slot_index)
				if not current_item or current_item.is_empty():
					inventory.slots[slot_index] = unequipped_item
					inventory.inventory_changed.emit(slot_index)
				else:
					for i in range(inventory.max_slots):
						var slot_item = inventory.get_slot(i)
						if not slot_item or slot_item.is_empty():
							inventory.slots[i] = unequipped_item
							inventory.inventory_changed.emit(i)
							break

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
		
		# Show quantity if > 1
		if item.quantity > 1:
			var qty_label = Label.new()
			qty_label.text = str(item.quantity)
			qty_label.add_theme_color_override("font_color", Color.WHITE)
			qty_label.add_theme_color_override("font_shadow_color", Color.BLACK)
			qty_label.add_theme_constant_override("shadow_offset_x", 1)
			qty_label.add_theme_constant_override("shadow_offset_y", 1)
			qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			qty_label.position = Vector2(slot_size - 24, slot_size - 20)
			qty_label.size = Vector2(20, 20)
			preview.add_child(qty_label)
	
	return preview

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			slot_clicked.emit(slot_index, event.button_index)

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
