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
	SlotUtils.set_children_mouse_filter_ignore(self)
	
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

func update_slot(p_item: InventoryItem) -> void:
	item = p_item
	
	if item and not item.is_empty():
		# Show item
		item_icon.visible = true
		placeholder_rect.visible = false
		label.modulate = Color.WHITE
		
		# Set icon (use placeholder for now)
		var icon = item.get_icon()
		if icon:
			item_icon.texture = icon
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
	return SlotUtils.get_placeholder_color(item)

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0
var _is_hovered: bool = false

var _last_drag_data: DragData = null
var _last_can_drop: bool = false


var _my_drop_counter: int = 0
var _slot_id: int = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		var global_counter = SlotUtils.get_drop_counter()
		
		# Only process if this slot was the LAST one to have can_drop_data called
		if _last_drag_data != null and _last_can_drop and _my_drop_counter == global_counter and SlotUtils.get_last_drop_slot() == _slot_id:
			# Increment counter to prevent other slots from processing
			SlotUtils.set_drop_counter(global_counter + 1)
			SlotUtils.set_last_drop_slot(-1)
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
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = false
			slot_clicked.emit(slot_type, event.button_index)

func _process(delta: float) -> void:
	if _is_dragging:
		var current_pos = get_global_mouse_position()
		var distance = _drag_start_pos.distance_to(current_pos)
		if distance > DRAG_THRESHOLD:
			_is_dragging = false
			SlotUtils.hide_tooltip()
			_start_drag()
	if _is_hovered and not _is_dragging:
		SlotUtils.move_tooltip(self)

func _start_drag() -> void:
	if not item or item.is_empty():
		return
	if not equipment:
		return
	
	var drag_data = DragData.new(DragData.DragSource.EQUIPMENT, slot_type, item, inventory, equipment)
	var preview = _create_drag_preview()
	if preview:
		set_drag_preview(preview)
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
	# Clear previous state
	_last_drag_data = null
	_last_can_drop = false
	
	if data == null:
		return false
	var drag_data = data as DragData
	if drag_data == null:
		return false
	
	# Can't drop on itself
	if drag_data.source_type == DragData.DragSource.EQUIPMENT and drag_data.source_slot_index == slot_type:
		return false
	
	# Can only drop items from inventory (or hotbar for tools)
	if drag_data.source_type != DragData.DragSource.INVENTORY and drag_data.source_type != DragData.DragSource.HOTBAR:
		return false
	
	# Check if item type matches slot type
	if not drag_data.item or not drag_data.item.item_data:
		return false
	
	var item_data = drag_data.item.item_data
	
	# Validate item type matches slot
	var valid = false
	match slot_type:
		Equipment.EquipmentSlot.GEAR_HEAD, Equipment.EquipmentSlot.GEAR_CHEST, Equipment.EquipmentSlot.GEAR_LEGS, Equipment.EquipmentSlot.GEAR_FEET:
			valid = item_data.item_type == ItemData.ItemType.EQUIPMENT
		Equipment.EquipmentSlot.TOOL_1, Equipment.EquipmentSlot.TOOL_2, Equipment.EquipmentSlot.TOOL_3:
			valid = item_data.item_type == ItemData.ItemType.TOOL
		Equipment.EquipmentSlot.WEAPON:
			valid = item_data.item_type == ItemData.ItemType.WEAPON
	
	# Store for potential manual drop handling
	if valid:
		_last_drag_data = drag_data
		_last_can_drop = true
		# Tag this slot with current global counter and unique slot ID
		var global_counter = SlotUtils.get_drop_counter()
		_my_drop_counter = global_counter
		_slot_id = 2000 + slot_type  # Equipment slots start at 2000 to avoid collision with inventory
		SlotUtils.set_last_drop_slot(_slot_id)
	
	return valid

func drop_data(position: Vector2, data: Variant) -> void:
	if data == null:
		return
	var drag_data = data as DragData
	if drag_data == null:
		return
	
	if drag_data.source_type == DragData.DragSource.INVENTORY or drag_data.source_type == DragData.DragSource.HOTBAR:
		# Equipping item from inventory
		if equipment and drag_data.inventory:
			var item_to_equip = drag_data.inventory.get_slot(drag_data.source_slot_index)
			if item_to_equip and not item_to_equip.is_empty():
				# Check if there's already an item equipped
				var currently_equipped = equipment.get_equipped_item(slot_type)
				
				# Try to equip the new item
				if equipment.equip_item(item_to_equip, slot_type):
					# Remove from inventory
					drag_data.inventory.remove_from_slot(drag_data.source_slot_index, 1)
					
					# If there was an equipped item, return it to inventory
					if currently_equipped and not currently_equipped.is_empty():
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
	return SlotUtils.create_drag_preview(item, slot_size)

func _on_mouse_entered() -> void:
	slot_hovered.emit(slot_type)
	_is_hovered = true
	var drag_data = get_viewport().gui_get_drag_data()
	if drag_data:
		# Show valid drop highlight
		if can_drop_data(Vector2.ZERO, drag_data):
			modulate = Color(0.8, 1.0, 0.8)  # Greenish tint for valid drop
		else:
			modulate = Color(1.0, 0.8, 0.8)  # Reddish tint for invalid drop
		SlotUtils.hide_tooltip()
	else:
		modulate = Color(1.2, 1.2, 1.2)  # Highlight on hover
		# Show tooltip
		if item and not item.is_empty():
			SlotUtils.show_tooltip(self, item)

func _on_mouse_exited() -> void:
	_is_hovered = false
	SlotUtils.hide_tooltip()
	var drag_data = get_viewport().gui_get_drag_data()
	if not drag_data:
		modulate = Color.WHITE  # Reset color
