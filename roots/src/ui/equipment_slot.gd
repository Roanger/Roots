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

func update_slot(p_item: InventoryItem) -> void:
	item = p_item
	
	if item and not item.is_empty():
		# Show item
		item_icon.visible = true
		placeholder_rect.visible = false
		label.modulate = Color.WHITE
		
		# Set icon (use placeholder for now)
		if item.get_icon():
			item_icon.texture = item.get_icon()
			placeholder_rect.visible = false
		else:
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

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			slot_clicked.emit(slot_type, event.button_index)

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
	if data == null:
		return false
	var drag_data = data as DragData
	if drag_data == null:
		return false
	
	# Can't drop on itself
	if drag_data.source_type == DragData.DragSource.EQUIPMENT and drag_data.source_slot_index == slot_type:
		return false
	
	# Can only drop items from inventory
	if drag_data.source_type != DragData.DragSource.INVENTORY:
		return false
	
	# Check if item type matches slot type
	if not drag_data.item or not drag_data.item.item_data:
		return false
	
	var item_data = drag_data.item.item_data
	
	# Validate item type matches slot
	match slot_type:
		Equipment.EquipmentSlot.GEAR_HEAD, Equipment.EquipmentSlot.GEAR_CHEST, Equipment.EquipmentSlot.GEAR_LEGS, Equipment.EquipmentSlot.GEAR_FEET:
			return item_data.item_type == ItemData.ItemType.EQUIPMENT
		Equipment.EquipmentSlot.TOOL_1, Equipment.EquipmentSlot.TOOL_2, Equipment.EquipmentSlot.TOOL_3:
			return item_data.item_type == ItemData.ItemType.TOOL
		Equipment.EquipmentSlot.WEAPON:
			return item_data.item_type == ItemData.ItemType.WEAPON
		_:
			return false

func drop_data(position: Vector2, data: Variant) -> void:
	if data == null:
		return
	var drag_data = data as DragData
	if drag_data == null:
		return
	
	if drag_data.source_type == DragData.DragSource.INVENTORY:
		# Equipping item from inventory
		if equipment and drag_data.inventory:
			# Remove item from inventory
			var item_to_equip = drag_data.inventory.get_slot(drag_data.source_slot_index)
			if item_to_equip and not item_to_equip.is_empty():
				# Try to equip
				if equipment.equip_item(item_to_equip, slot_type):
					# Remove from inventory
					drag_data.inventory.remove_from_slot(drag_data.source_slot_index, 1)

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Reset visual state after drag ends
		modulate = Color.WHITE
