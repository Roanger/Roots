extends Control
class_name InventoryUI
## Main inventory UI window

signal inventory_closed()

@export var slots_per_row: int = 6
@export var slot_size: int = 64
@export var slot_spacing: int = 4

@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var slots_container: GridContainer = $InventoryPanel/MarginContainer/VBoxContainer/SlotsContainer
@onready var title_label: Label = $InventoryPanel/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var close_button: Button = $InventoryPanel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton

var inventory: Inventory = null
var slot_scene = preload("res://src/ui/inventory_slot.tscn")
var slots: Array[InventorySlot] = []
var player: Node = null

func _ready() -> void:
	# Add to group for easy finding
	add_to_group("inventory_ui")
	
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Set up grid container
	if slots_container:
		slots_container.columns = slots_per_row
		slots_container.add_theme_constant_override("h_separation", slot_spacing)
		slots_container.add_theme_constant_override("v_separation", slot_spacing)
	
	# Initially hidden
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func initialize(p_inventory: Inventory, p_player: Node = null) -> void:
	inventory = p_inventory
	player = p_player
	
	if not inventory:
		push_error("InventoryUI: No inventory provided")
		return
	
	# If player not provided, try to find it
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Connect inventory signals
	inventory.inventory_changed.connect(_on_inventory_changed)
	
	# Create slots
	_create_slots()
	
	# Update all slots
	_update_all_slots()

func _create_slots() -> void:
	if not inventory or not slots_container:
		return
	
	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()
	slots.clear()
	
	# Create slots for inventory
	for i in range(inventory.max_slots):
		var slot = slot_scene.instantiate()
		slot.slot_index = i
		slot.slot_size = slot_size
		slot.set_inventory(inventory)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.item_dropped.connect(_on_item_dropped)
		
		slots_container.add_child(slot)
		slots.append(slot)

func _update_all_slots() -> void:
	if not inventory:
		return
	
	for i in range(min(slots.size(), inventory.max_slots)):
		var item = inventory.get_slot(i)
		slots[i].update_slot(item)

func _on_inventory_changed(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < slots.size():
		var item = inventory.get_slot(slot_index)
		slots[slot_index].update_slot(item)

func _on_slot_clicked(slot_index: int, button_index: int) -> void:
	if not inventory:
		return
	
	match button_index:
		MOUSE_BUTTON_LEFT:
			# Left click - use item or select
			var item = inventory.get_slot(slot_index)
			if item and not item.is_empty():
				# For now, just print - will implement use logic later
				print("Clicked slot ", slot_index, " with item: ", item.get_item_name())
		MOUSE_BUTTON_RIGHT:
			# Right click - context menu (future)
			pass

func _on_slot_hovered(slot_index: int) -> void:
	# Show tooltip or item info (future)
	pass

func _on_item_dropped(from_slot: int, to_slot: int) -> void:
	# Item was moved via drag-and-drop
	# Slots will update automatically via inventory_changed signal
	pass

func open() -> void:
	visible = true
	_update_all_slots()
	
	# Release mouse so player can interact with UI
	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Pause game when inventory is open (only if not already paused)
	if not get_tree().paused:
		get_tree().paused = true

func close() -> void:
	visible = false
	
	# Only recapture mouse and unpause if no other UI is open
	# Check if character UI is still open
	var character_ui = get_tree().get_first_node_in_group("character_ui")
	var other_ui_open = character_ui and character_ui.visible
	
	if not other_ui_open:
		# Recapture mouse for first-person camera
		if player and player.has_method("capture_mouse"):
			player.capture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Unpause game
		get_tree().paused = false
	
	inventory_closed.emit()

func _on_close_button_pressed() -> void:
	close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Close on Escape key
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
