extends Control
class_name SkillTreeUI
## Skill tree UI panel showing all skills, levels, XP progress, and active perks

signal skill_tree_closed()

var skill_manager: Node = null
var player: Node = null
var skill_rows: Dictionary = {}  # skill_id -> row container

# UI references (built in code)
var panel: PanelContainer = null
var scroll_container: ScrollContainer = null
var skill_list: VBoxContainer = null
var header_label: Label = null
var close_button: Button = null
var points_label: Label = null
var total_level_label: Label = null
var perks_container: VBoxContainer = null

func _ready() -> void:
	add_to_group("skill_tree_ui")
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_build_ui()
	
	# Connect to EventBus for live updates
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("xp_gained"):
			event_bus.xp_gained.connect(_on_xp_gained)
		if event_bus.has_signal("level_up"):
			event_bus.level_up.connect(_on_level_up)

func _build_ui() -> void:
	# Full-screen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	# Center panel
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(650, 500)
	panel.position = Vector2(-325, -250)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.35, 0.25)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)
	
	# Header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header_row)
	
	header_label = Label.new()
	header_label.text = "Skills"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	
	total_level_label = Label.new()
	total_level_label.text = "Total Level: 12"
	total_level_label.add_theme_font_size_override("font_size", 14)
	total_level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header_row.add_child(total_level_label)
	
	points_label = Label.new()
	points_label.text = "Skill Points: 0"
	points_label.add_theme_font_size_override("font_size", 14)
	points_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	header_row.add_child(points_label)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.pressed.connect(_on_close_pressed)
	header_row.add_child(close_button)
	
	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)
	
	# Scrollable skill list
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)
	
	skill_list = VBoxContainer.new()
	skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_list.add_theme_constant_override("separation", 4)
	scroll_container.add_child(skill_list)
	
	# Perks section
	var perks_sep = HSeparator.new()
	main_vbox.add_child(perks_sep)
	
	var perks_header = Label.new()
	perks_header.text = "Active Synergies"
	perks_header.add_theme_font_size_override("font_size", 16)
	perks_header.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	main_vbox.add_child(perks_header)
	
	perks_container = VBoxContainer.new()
	perks_container.add_theme_constant_override("separation", 2)
	main_vbox.add_child(perks_container)

func initialize(p_player: Node = null) -> void:
	player = p_player
	skill_manager = get_node_or_null("/root/SkillManager")
	if not player:
		player = get_tree().get_first_node_in_group("player")

func _build_skill_rows() -> void:
	# Clear existing rows
	for child in skill_list.get_children():
		child.queue_free()
	skill_rows.clear()
	
	if not skill_manager:
		skill_manager = get_node_or_null("/root/SkillManager")
	if not skill_manager:
		return
	
	# Group skills by category
	var categories: Dictionary = {}
	for skill_id in skill_manager.get_all_skill_ids():
		var definition = skill_manager.get_skill_definition(skill_id)
		if not definition:
			continue
		var cat = definition.category
		if not categories.has(cat):
			categories[cat] = []
		categories[cat].append(skill_id)
	
	# Category display names
	var cat_names := {
		SkillData.SkillCategory.CULTIVATION: "Cultivation",
		SkillData.SkillCategory.GATHERING: "Gathering",
		SkillData.SkillCategory.CRAFTING: "Crafting",
		SkillData.SkillCategory.BLACKSMITHING: "Blacksmithing",
		SkillData.SkillCategory.COOKING: "Cooking",
		SkillData.SkillCategory.BAKING: "Baking",
		SkillData.SkillCategory.HUSBANDRY: "Husbandry",
		SkillData.SkillCategory.ALCHEMY: "Alchemy",
		SkillData.SkillCategory.MILITIA: "Militia",
		SkillData.SkillCategory.HERB_GATHERING: "Herb Gathering",
	}
	
	# Category colors
	var cat_colors := {
		SkillData.SkillCategory.CULTIVATION: Color(0.4, 0.7, 0.3),
		SkillData.SkillCategory.GATHERING: Color(0.6, 0.5, 0.3),
		SkillData.SkillCategory.CRAFTING: Color(0.5, 0.5, 0.7),
		SkillData.SkillCategory.BLACKSMITHING: Color(0.7, 0.4, 0.3),
		SkillData.SkillCategory.COOKING: Color(0.8, 0.6, 0.3),
		SkillData.SkillCategory.BAKING: Color(0.8, 0.7, 0.5),
		SkillData.SkillCategory.HUSBANDRY: Color(0.5, 0.7, 0.6),
		SkillData.SkillCategory.ALCHEMY: Color(0.6, 0.3, 0.7),
		SkillData.SkillCategory.MILITIA: Color(0.7, 0.3, 0.3),
		SkillData.SkillCategory.HERB_GATHERING: Color(0.3, 0.7, 0.4),
	}
	
	# Build rows sorted by category
	for cat in cat_names.keys():
		if not categories.has(cat):
			continue
		
		# Category header
		var cat_label = Label.new()
		cat_label.text = cat_names.get(cat, "Unknown")
		cat_label.add_theme_font_size_override("font_size", 15)
		cat_label.add_theme_color_override("font_color", cat_colors.get(cat, Color.WHITE))
		skill_list.add_child(cat_label)
		
		# Skill rows in this category
		for skill_id in categories[cat]:
			var row = _create_skill_row(skill_id, cat_colors.get(cat, Color.WHITE))
			skill_list.add_child(row)
			skill_rows[skill_id] = row

func _create_skill_row(skill_id: String, accent_color: Color) -> HBoxContainer:
	var definition = skill_manager.get_skill_definition(skill_id)
	var level = skill_manager.get_skill_level(skill_id)
	var xp = skill_manager.get_skill_xp(skill_id)
	var xp_needed = skill_manager.get_xp_to_next_level(skill_id)
	
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_meta("skill_id", skill_id)
	
	# Skill name
	var name_label = Label.new()
	name_label.text = definition.display_name if definition else skill_id
	name_label.custom_minimum_size = Vector2(140, 0)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	row.add_child(name_label)
	
	# Level label
	var level_label = Label.new()
	level_label.text = "Lv %d" % level
	level_label.custom_minimum_size = Vector2(50, 0)
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", accent_color)
	level_label.name = "LevelLabel"
	row.add_child(level_label)
	
	# XP progress bar
	var progress = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = max(xp_needed, 1)
	progress.value = xp
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.custom_minimum_size = Vector2(200, 20)
	progress.show_percentage = false
	progress.name = "XPBar"
	
	# Style the progress bar
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.18)
	bar_bg.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background", bar_bg)
	
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = accent_color * 0.8
	bar_fill.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("fill", bar_fill)
	
	row.add_child(progress)
	
	# XP text
	var xp_label = Label.new()
	if xp_needed > 0:
		xp_label.text = "%d / %d" % [xp, xp_needed]
	else:
		xp_label.text = "MAX"
	xp_label.custom_minimum_size = Vector2(90, 0)
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	xp_label.name = "XPLabel"
	row.add_child(xp_label)
	
	return row

func _update_skill_row(skill_id: String) -> void:
	if not skill_rows.has(skill_id) or not skill_manager:
		return
	
	var row = skill_rows[skill_id] as HBoxContainer
	if not row:
		return
	
	var level = skill_manager.get_skill_level(skill_id)
	var xp = skill_manager.get_skill_xp(skill_id)
	var xp_needed = skill_manager.get_xp_to_next_level(skill_id)
	
	var level_label = row.get_node_or_null("LevelLabel") as Label
	if level_label:
		level_label.text = "Lv %d" % level
	
	var xp_bar = row.get_node_or_null("XPBar") as ProgressBar
	if xp_bar:
		xp_bar.max_value = max(xp_needed, 1)
		xp_bar.value = xp
	
	var xp_label = row.get_node_or_null("XPLabel") as Label
	if xp_label:
		if xp_needed > 0:
			xp_label.text = "%d / %d" % [xp, xp_needed]
		else:
			xp_label.text = "MAX"

func _update_header() -> void:
	if not skill_manager:
		return
	if points_label:
		points_label.text = "Skill Points: %d" % skill_manager.skill_points
	if total_level_label:
		total_level_label.text = "Total Level: %d" % skill_manager.get_total_level()

func _update_perks() -> void:
	if not perks_container or not skill_manager:
		return
	
	for child in perks_container.get_children():
		child.queue_free()
	
	if skill_manager.active_perks.is_empty():
		var none_label = Label.new()
		none_label.text = "No synergies unlocked yet"
		none_label.add_theme_font_size_override("font_size", 12)
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		perks_container.add_child(none_label)
	else:
		for perk_id in skill_manager.active_perks:
			var perk = skill_manager.active_perks[perk_id]
			var perk_label = Label.new()
			perk_label.text = "★ " + perk.get("description", perk_id)
			perk_label.add_theme_font_size_override("font_size", 13)
			perk_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
			perks_container.add_child(perk_label)

func open() -> void:
	skill_manager = get_node_or_null("/root/SkillManager")
	visible = true
	_build_skill_rows()
	_update_header()
	_update_perks()
	
	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if not get_tree().paused:
		get_tree().paused = true

func close() -> void:
	visible = false
	
	# Check if other UIs are open before unpausing
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	var character_ui = get_tree().get_first_node_in_group("character_ui")
	var other_ui_open = (inventory_ui and inventory_ui.visible) or (character_ui and character_ui.visible)
	
	if not other_ui_open:
		if player and player.has_method("capture_mouse"):
			player.capture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
	
	skill_tree_closed.emit()

func _on_close_pressed() -> void:
	close()

func _on_xp_gained(_skill_name: String, _amount: int, _total_xp: int) -> void:
	if visible:
		_update_skill_row(_skill_name)
		_update_header()

func _on_level_up(_skill_name: String, _new_level: int) -> void:
	if visible:
		_update_skill_row(_skill_name)
		_update_header()
		_update_perks()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	# Consume mouse wheel so it scrolls the skill list instead of cycling the hotbar
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
