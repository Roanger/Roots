extends RefCounted
class_name SlotUtils
## Shared utilities for inventory and equipment slot UI components

# Engine meta keys for coordinating drag-and-drop across all slot types
const DROP_COUNTER_KEY = "_global_drop_counter"
const LAST_DROP_SLOT_KEY = "_last_drop_slot_id"

static func get_drop_counter() -> int:
	if Engine.has_meta(DROP_COUNTER_KEY):
		return Engine.get_meta(DROP_COUNTER_KEY)
	return 0

static func set_drop_counter(value: int) -> void:
	Engine.set_meta(DROP_COUNTER_KEY, value)

static func get_last_drop_slot() -> int:
	if Engine.has_meta(LAST_DROP_SLOT_KEY):
		return Engine.get_meta(LAST_DROP_SLOT_KEY)
	return -1

static func set_last_drop_slot(slot_id: int) -> void:
	Engine.set_meta(LAST_DROP_SLOT_KEY, slot_id)

static func set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_children_mouse_filter_ignore(child)

static func get_placeholder_color(item: InventoryItem) -> Color:
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
		ItemData.ItemType.WEAPON:
			return Color(0.8, 0.2, 0.2)  # Dark red
		ItemData.ItemType.EQUIPMENT:
			return Color(0.4, 0.6, 0.8)  # Blue
		_:
			return Color.WHITE

static func create_drag_preview(item: InventoryItem, slot_size: int) -> Control:
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
			color_rect.color = get_placeholder_color(item)
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
