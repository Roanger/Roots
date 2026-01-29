extends Control
class_name CharacterUI
## Character/Equipment UI window

signal character_closed()

@export var slot_size: int = 64

@onready var character_panel: PanelContainer = $CharacterPanel
@onready var close_button: Button = $CharacterPanel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton

# Equipment slots
@onready var gear_head_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/GearContainer/GearHeadSlot
@onready var gear_chest_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/GearContainer/GearChestSlot
@onready var gear_legs_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/GearContainer/GearLegsSlot
@onready var gear_feet_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/GearContainer/GearFeetSlot
@onready var tool_1_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/ToolsContainer/Tool1Slot
@onready var tool_2_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/ToolsContainer/Tool2Slot
@onready var tool_3_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/ToolsContainer/Tool3Slot
@onready var weapon_slot: EquipmentSlotUI = $CharacterPanel/MarginContainer/VBoxContainer/ContentContainer/WeaponContainer/WeaponSlot

var equipment: Equipment = null
var player: Node = null
var slot_scene = preload("res://src/ui/equipment_slot.tscn")
var slots: Dictionary = {}

func _ready() -> void:
	# Add to group for easy finding
	add_to_group("character_ui")
	
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Initially hidden
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Setup slot references
	_setup_slots()

func _setup_slots() -> void:
	slots[Equipment.EquipmentSlot.GEAR_HEAD] = gear_head_slot
	slots[Equipment.EquipmentSlot.GEAR_CHEST] = gear_chest_slot
	slots[Equipment.EquipmentSlot.GEAR_LEGS] = gear_legs_slot
	slots[Equipment.EquipmentSlot.GEAR_FEET] = gear_feet_slot
	slots[Equipment.EquipmentSlot.TOOL_1] = tool_1_slot
	slots[Equipment.EquipmentSlot.TOOL_2] = tool_2_slot
	slots[Equipment.EquipmentSlot.TOOL_3] = tool_3_slot
	slots[Equipment.EquipmentSlot.WEAPON] = weapon_slot
	
	# Connect slot signals
	for slot_type in slots.keys():
		var slot = slots[slot_type]
		if slot:
			slot.slot_clicked.connect(_on_slot_clicked)
			slot.slot_hovered.connect(_on_slot_hovered)

func initialize(p_equipment: Equipment, p_player: Node = null) -> void:
	equipment = p_equipment
	player = p_player
	
	if not equipment:
		push_error("CharacterUI: No equipment provided")
		return
	
	# If player not provided, try to find it
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Get player inventory for drag-and-drop
	var player_inventory = null
	if player and player.has_method("get_inventory"):
		player_inventory = player.get_inventory()
	
	# Connect equipment signals
	equipment.equipment_changed.connect(_on_equipment_changed)
	
	# Setup slots with equipment and inventory references
	_setup_slot_references(player_inventory)
	
	# Update all slots
	_update_all_slots()

func _setup_slot_references(p_inventory: Inventory) -> void:
	# Set equipment and inventory references on all slots
	for slot_type in slots.keys():
		var slot_ui = slots.get(slot_type)
		if slot_ui:
			slot_ui.set_equipment(equipment)
			if p_inventory:
				slot_ui.set_inventory(p_inventory)

func _update_all_slots() -> void:
	if not equipment:
		return
	
	for slot_type in slots.keys():
		# slot_type is Equipment.EquipmentSlot enum value (which is an int)
		var item = equipment.get_equipped_item(slot_type)
		var slot_ui = slots[slot_type]
		if slot_ui:
			slot_ui.update_slot(item)

func _on_equipment_changed(slot_name: String) -> void:
	# Find slot type from name and update
	for slot_type in Equipment.EquipmentSlot.values():
		if equipment.get_slot_name(slot_type) == slot_name:
			var item = equipment.get_equipped_item(slot_type)
			var slot_ui = slots.get(slot_type)
			if slot_ui:
				slot_ui.update_slot(item)
			break

func _on_slot_clicked(slot_type: int, button_index: int) -> void:
	if not equipment:
		return
	
	# slot_type is already an int from the signal
	match button_index:
		MOUSE_BUTTON_LEFT:
			# Left click - unequip item
			var item = equipment.get_equipped_item(slot_type)
			if item:
				var unequipped = equipment.unequip_item(slot_type)
				# TODO: Add unequipped item back to inventory
				print("Unequipped: ", unequipped.get_item_name(), " from ", equipment.get_slot_name(slot_type))
		MOUSE_BUTTON_RIGHT:
			# Right click - context menu (future)
			pass

func _on_slot_hovered(slot_type: int) -> void:
	# Show tooltip or item info (future)
	pass

func open() -> void:
	visible = true
	_update_all_slots()
	
	# Release mouse so player can interact with UI
	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Pause game when character UI is open (only if not already paused)
	if not get_tree().paused:
		get_tree().paused = true

func close() -> void:
	visible = false
	
	# Only recapture mouse and unpause if no other UI is open
	# Check if inventory UI is still open
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	var other_ui_open = inventory_ui and inventory_ui.visible
	
	if not other_ui_open:
		# Recapture mouse for first-person camera
		if player and player.has_method("capture_mouse"):
			player.capture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Unpause game
		get_tree().paused = false
	
	character_closed.emit()

func _on_close_button_pressed() -> void:
	close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Close on Escape key
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
