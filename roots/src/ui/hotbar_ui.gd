extends Control
class_name HotbarUI
## Hotbar UI - displays first 8 inventory slots at bottom of screen

signal hotbar_slot_selected(slot_index: int)
signal hotbar_item_used(slot_index: int)

@export var slot_size: int = 64
@export var slot_spacing: int = 4

@onready var slots_container: HBoxContainer = $HotbarPanel/MarginContainer/SlotsContainer

var inventory: Inventory = null
var slot_scene = preload("res://src/ui/inventory_slot.tscn")
var slots: Array[InventorySlot] = []
var selected_slot: int = 0  # 0-7 for hotbar slots

func _ready() -> void:
	# Set up hotbar container
	if slots_container:
		slots_container.add_theme_constant_override("separation", slot_spacing)
	
	# Initially hidden until inventory is initialized
	visible = false
	
	# Hotbar should always process input (even when game is paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

func initialize(p_inventory: Inventory) -> void:
	inventory = p_inventory
	
	if not inventory:
		push_error("HotbarUI: No inventory provided")
		return
	
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.hotbar_changed.connect(_on_hotbar_changed)
	
	_create_slots()
	_update_all_slots()
	
	# Show hotbar
	visible = true
	
	# Select first slot by default
	select_slot(0)

func _create_slots() -> void:
	if not inventory or not slots_container:
		return
	
	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()
	slots.clear()
	
	for i in range(inventory.hotbar_size):
		var slot = slot_scene.instantiate()
		slot.slot_index = i
		slot.slot_size = slot_size
		slot.is_hotbar_slot = true
		slot.set_inventory(inventory)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.item_dropped.connect(_on_item_dropped)
		
		slots_container.add_child(slot)
		slots.append(slot)
		
		# Add number label overlay
		var number_label = Label.new()
		number_label.name = "NumberLabel"
		number_label.text = str(i + 1)
		number_label.add_theme_font_size_override("font_size", 14)
		number_label.add_theme_color_override("font_color", Color.WHITE)
		number_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		number_label.add_theme_constant_override("shadow_offset_x", 1)
		number_label.add_theme_constant_override("shadow_offset_y", 1)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number_label.position = Vector2(4, 4)  # Position in top-left corner
		slot.add_child(number_label)

func _on_item_dropped(from_slot: int, to_slot: int) -> void:
	# Item was moved via drag-and-drop to hotbar
	# Slots will update automatically via hotbar_changed signal
	print("[Hotbar] Item dropped from slot %d to slot %d" % [from_slot, to_slot])

func _update_all_slots() -> void:
	if not inventory:
		return
	for i in range(min(slots.size(), inventory.hotbar_size)):
		var item = inventory.get_hotbar_slot(i)
		slots[i].update_slot(item)
	_update_selection_highlight()

func _on_inventory_changed(_slot_index: int) -> void:
	pass

func _on_hotbar_changed(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < slots.size():
		var item = inventory.get_hotbar_slot(slot_index)
		slots[slot_index].update_slot(item)

func _on_slot_clicked(slot_index: int, button_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	# Debug: log what's in this hotbar slot when clicked
	var hotbar_item = inventory.get_hotbar_slot(slot_index) if inventory else null
	if hotbar_item and not hotbar_item.is_empty():
		print("[Hotbar] Slot %d clicked: \"%s\" (qty %d)" % [slot_index + 1, hotbar_item.get_item_name(), hotbar_item.quantity])
	else:
		print("[Hotbar] Slot %d clicked: (empty)" % [slot_index + 1])
	match button_index:
		MOUSE_BUTTON_LEFT:
			select_slot(slot_index)
		MOUSE_BUTTON_RIGHT:
			_use_item_at_slot(slot_index)

func _on_slot_hovered(slot_index: int) -> void:
	# Show tooltip (future)
	pass

func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	
	selected_slot = slot_index
	_update_selection_highlight()
	hotbar_slot_selected.emit(slot_index)

func _update_selection_highlight() -> void:
	for i in range(slots.size()):
		if i == selected_slot:
			# Highlight selected slot with brighter border
			slots[i].modulate = Color(1.1, 1.1, 1.0)  # Slight yellowish tint
			# Create highlighted border style
			var highlight_style = StyleBoxFlat.new()
			highlight_style.bg_color = Color(0.2, 0.2, 0.25, 1)
			highlight_style.border_color = Color(1.0, 0.9, 0.2)  # Gold border
			highlight_style.border_width_left = 3
			highlight_style.border_width_top = 3
			highlight_style.border_width_right = 3
			highlight_style.border_width_bottom = 3
			slots[i].add_theme_stylebox_override("panel", highlight_style)
		else:
			# Reset to normal
			slots[i].modulate = Color.WHITE
			# Reset to default style (will use theme default)
			slots[i].remove_theme_stylebox_override("panel")

func use_selected_item() -> bool:
	return _use_item_at_slot(selected_slot)

func _use_item_at_slot(slot_index: int) -> bool:
	if not inventory:
		return false
	var item = inventory.get_hotbar_slot(slot_index)
	if not item or item.is_empty():
		return false
	if inventory.use_hotbar_item(slot_index, get_tree().get_first_node_in_group("player")):
		hotbar_item_used.emit(slot_index)
		return true
	return false

func get_selected_item() -> InventoryItem:
	if not inventory:
		return null
	return inventory.get_hotbar_slot(selected_slot)

func _is_menu_open() -> bool:
	# Check if any UI menu is open that should block hotbar input
	var ui = get_parent()
	if not ui:
		return false
	for name_check in ["CraftingUI", "InventoryUI", "CharacterUI", "SkillTreeUI"]:
		var node = ui.get_node_or_null(name_check)
		if node and node is Control and node.visible:
			return true
	return false

func _input(event: InputEvent) -> void:
	# Don't process hotbar input when a menu is open
	if _is_menu_open():
		return
	
	# Handle number keys 1-8 for hotbar selection
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		# Check for number keys 1-8
		if key >= KEY_1 and key <= KEY_8:
			var slot_index = key - KEY_1  # Convert KEY_1 (0) to slot 0, KEY_2 (1) to slot 1, etc.
			select_slot(slot_index)
			get_viewport().set_input_as_handled()
		# Also handle numpad keys
		elif key >= KEY_KP_1 and key <= KEY_KP_8:
			var slot_index = key - KEY_KP_1
			select_slot(slot_index)
			get_viewport().set_input_as_handled()
	
	# Handle mouse wheel for hotbar scrolling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# Scroll to previous slot
			var new_slot = (selected_slot - 1) % slots.size()
			if new_slot < 0:
				new_slot = slots.size() - 1
			select_slot(new_slot)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# Scroll to next slot
			var new_slot = (selected_slot + 1) % slots.size()
			select_slot(new_slot)
			get_viewport().set_input_as_handled()
