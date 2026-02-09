extends PanelContainer
class_name ItemTooltip
## Floating tooltip panel that displays item name, description, and stats

const TOOLTIP_MAX_WIDTH := 280
const PADDING := 8

var _vbox: VBoxContainer
var _name_label: Label
var _type_label: Label
var _separator: HSeparator
var _desc_label: Label
var _stats_label: Label
var _built: bool = false

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	visible = false
	
	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(PADDING)
	add_theme_stylebox_override("panel", style)
	
	# Layout
	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	
	# Item name
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(_name_label)
	
	# Item type / tier line
	_type_label = Label.new()
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_label.add_theme_font_size_override("font_size", 11)
	_type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_vbox.add_child(_type_label)
	
	# Separator
	_separator = HSeparator.new()
	_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_separator.add_theme_constant_override("separation", 2)
	_vbox.add_child(_separator)
	
	# Description
	_desc_label = Label.new()
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size.x = TOOLTIP_MAX_WIDTH - PADDING * 2
	_vbox.add_child(_desc_label)
	
	# Stats
	_stats_label = Label.new()
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.55, 0.8, 0.55))
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_stats_label.custom_minimum_size.x = TOOLTIP_MAX_WIDTH - PADDING * 2
	_vbox.add_child(_stats_label)

func _ready() -> void:
	_ensure_built()

func show_item(inv_item: InventoryItem) -> void:
	_ensure_built()
	if not inv_item or inv_item.is_empty() or not inv_item.item_data:
		hide_tooltip()
		return
	
	var data: ItemData = inv_item.item_data
	
	# Name with rarity color
	_name_label.text = data.item_name
	_name_label.add_theme_color_override("font_color", data.get_rarity_color())
	
	# Type + tier line
	_type_label.text = _get_type_string(data)
	_type_label.visible = _type_label.text != ""
	
	# Description
	if data.description != "":
		_desc_label.text = data.description
		_desc_label.visible = true
		_separator.visible = true
	else:
		_desc_label.visible = false
		_separator.visible = false
	
	# Stats
	var stats_text = _build_stats_text(data, inv_item)
	if stats_text != "":
		_stats_label.text = stats_text
		_stats_label.visible = true
	else:
		_stats_label.visible = false
	
	visible = true
	# Force layout update so size is correct for positioning
	reset_size()

func hide_tooltip() -> void:
	visible = false

func update_position(mouse_pos: Vector2) -> void:
	if not visible:
		return
	var viewport_size = get_viewport_rect().size
	var tip_size = size
	# Position to the right and below cursor, with screen clamping
	var pos = mouse_pos + Vector2(16, 16)
	if pos.x + tip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tip_size.x - 8
	if pos.y + tip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tip_size.y - 8
	pos.x = maxf(pos.x, 0)
	pos.y = maxf(pos.y, 0)
	global_position = pos

func _get_type_string(data: ItemData) -> String:
	var parts: Array[String] = []
	
	match data.item_type:
		ItemData.ItemType.TOOL:
			var tier_name = _get_tier_name(data.tool_tier)
			if tier_name != "":
				parts.append(tier_name)
			if data.tool_type != "":
				parts.append(data.tool_type.capitalize())
			else:
				parts.append("Tool")
		ItemData.ItemType.WEAPON:
			if data.tool_type != "":
				parts.append(data.tool_type.replace("_", " ").capitalize())
			else:
				parts.append("Weapon")
		ItemData.ItemType.EQUIPMENT:
			parts.append("Equipment")
		ItemData.ItemType.FOOD:
			parts.append("Food")
		ItemData.ItemType.POTION:
			parts.append("Potion")
		ItemData.ItemType.SEED:
			parts.append("Seed")
		ItemData.ItemType.CROP:
			parts.append("Crop")
		ItemData.ItemType.MATERIAL:
			parts.append("Material")
		ItemData.ItemType.QUEST:
			parts.append("Quest Item")
		_:
			parts.append("Misc")
	
	# Rarity
	var rarity_name = ""
	match data.rarity:
		ItemData.ItemRarity.UNCOMMON: rarity_name = "Uncommon"
		ItemData.ItemRarity.RARE: rarity_name = "Rare"
		ItemData.ItemRarity.EPIC: rarity_name = "Epic"
		ItemData.ItemRarity.LEGENDARY: rarity_name = "Legendary"
	if rarity_name != "":
		parts.insert(0, rarity_name)
	
	return " ".join(parts)

func _get_tier_name(tier: ItemData.ToolTier) -> String:
	match tier:
		ItemData.ToolTier.WOOD: return "Wood"
		ItemData.ToolTier.BRONZE: return "Bronze"
		ItemData.ToolTier.IRON: return "Iron"
		ItemData.ToolTier.STEEL: return "Steel"
		ItemData.ToolTier.MYTHRIL: return "Mythril"
	return ""

func _build_stats_text(data: ItemData, inv_item: InventoryItem) -> String:
	var lines: Array[String] = []
	
	# Tool stats
	if data.item_type == ItemData.ItemType.TOOL or data.item_type == ItemData.ItemType.WEAPON:
		if data.tool_power > 0:
			lines.append("Power: %d" % data.tool_power)
		if data.tool_range > 0 and data.tool_range != 2.0:
			lines.append("Range: %.1f" % data.tool_range)
	
	# Durability
	if data.has_durability:
		lines.append("Durability: %d / %d" % [inv_item.durability, data.max_durability])
	
	# Consumable stats
	if data.is_consumable:
		if data.health_restore > 0:
			lines.append("Restores %.0f Health" % data.health_restore)
		if data.stamina_restore > 0:
			lines.append("Restores %.0f Stamina" % data.stamina_restore)
		if data.hunger_restore > 0:
			lines.append("Restores %.0f Hunger" % data.hunger_restore)
		for buff in data.buff_effects:
			var buff_type = buff.get("type", "")
			var buff_val = buff.get("value", 0)
			var buff_dur = buff.get("duration", 0)
			if buff_type == "heal":
				lines.append("+%.0f HP/s for %.0fs" % [buff_val, buff_dur])
			elif buff_type == "stamina":
				lines.append("+%.0f Stamina/s for %.0fs" % [buff_val, buff_dur])
			elif buff_type == "speed":
				lines.append("+%.0f%% Speed for %.0fs" % [(buff_val - 1.0) * 100, buff_dur])
			elif buff_type == "strength":
				lines.append("+%.0f%% Damage for %.0fs" % [(buff_val - 1.0) * 100, buff_dur])
			elif buff_type == "antidote":
				lines.append("Cures poison (%0.fs)" % buff_dur)
	
	# Value
	if data.sellable and data.base_value > 0:
		lines.append("Value: %d" % data.base_value)
	
	return "\n".join(lines)
