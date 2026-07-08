extends Control
class_name HerbariumUI
## Herbarium journal: shows discovered plants and their properties.
## Toggle with H key.

var skill_manager: Node = null
var item_database: Node = null

var _panel: PanelContainer
var _title_label: Label
var _close_button: Button
var _herb_list: VBoxContainer
var _scroll: ScrollContainer
var _detail_name: Label
var _detail_desc: Label
var _detail_info: Label

const HERB_IDS := ["common_mushroom", "golden_mushroom", "lavender", "chamomile", "mint_leaf", "sage_leaf", "nightshade", "wild_clover", "fern_frond"]

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("herbarium_ui")
	_build_ui()
	_center_panel()

func initialize() -> void:
	skill_manager = get_node_or_null("/root/SkillManager")
	item_database = get_node_or_null("/root/ItemDatabase")
	_refresh_list()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 400)
	_panel.size = Vector2(500, 400)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Herbarium"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(30, 30)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	# Progress label
	var progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.add_theme_font_size_override("font_size", 13)
	progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	main_vbox.add_child(progress_label)

	# Split: list (left) + detail (right)
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 200
	main_vbox.add_child(split)

	# Left: herb list
	var left_panel = PanelContainer.new()
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	left_style.set_corner_radius_all(4)
	left_style.set_content_margin_all(4)
	left_panel.add_theme_stylebox_override("panel", left_style)
	split.add_child(left_panel)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_scroll)

	_herb_list = VBoxContainer.new()
	_herb_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_herb_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_herb_list)

	# Right: herb detail
	var detail_panel = PanelContainer.new()
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	detail_style.set_corner_radius_all(4)
	detail_style.set_content_margin_all(10)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	split.add_child(detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_vbox)

	_detail_name = Label.new()
	_detail_name.text = "Select a plant"
	_detail_name.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_vbox.add_child(_detail_desc)

	detail_vbox.add_child(HSeparator.new())

	_detail_info = Label.new()
	_detail_info.text = ""
	_detail_info.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_info)

func _refresh_list() -> void:
	for child in _herb_list.get_children():
		child.queue_free()

	if not skill_manager:
		return

	var progress_label = _panel.find_child("ProgressLabel", true, false)
	var discovered_count := 0
	var total := HERB_IDS.size()

	for herb_id in HERB_IDS:
		var discovered = skill_manager.is_herb_discovered(herb_id)
		if discovered:
			discovered_count += 1

		var item_data = item_database.get_item(herb_id) if item_database else null

		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if discovered and item_data:
			btn.text = item_data.item_name
			btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
			btn.pressed.connect(_on_herb_selected.bind(herb_id))
		else:
			btn.text = "???  (Undiscovered)"
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			btn.disabled = true

		_herb_list.add_child(btn)

	if progress_label:
		progress_label.text = "Discovered: %d / %d" % [discovered_count, total]

	var undisc: Array = skill_manager.get_undiscovered_wild_herbs() if skill_manager.has_method("get_undiscovered_wild_herbs") else []
	if discovered_count == total:
		_detail_name.text = "Herbarium Complete!"
		_detail_desc.text = "You have discovered every plant species."
		_detail_info.text = ""

func _on_herb_selected(herb_id: String) -> void:
	if not item_database:
		return
	var item_data = item_database.get_item(herb_id)
	if not item_data:
		return
	_detail_name.text = item_data.item_name
	_detail_desc.text = item_data.description
	var rarity_name = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	var rarity_str = rarity_name[item_data.rarity] if item_data.rarity < rarity_name.size() else "Common"
	_detail_info.text = "Rarity: %s\nValue: %d gold" % [rarity_str, item_data.base_value]

func show_herbarium() -> void:
	if not skill_manager:
		initialize()
	_refresh_list()
	visible = true
	_center_panel()

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not get_tree().paused:
		get_tree().paused = true

func close() -> void:
	visible = false
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	var crafting_ui = get_tree().get_first_node_in_group("crafting_ui")
	var character_ui = get_tree().get_first_node_in_group("character_ui")
	var skill_tree_ui = get_tree().get_first_node_in_group("skill_tree_ui")
	var other_open = (inventory_ui and inventory_ui.visible) or (crafting_ui and crafting_ui.visible) or (character_ui and character_ui.visible) or (skill_tree_ui and skill_tree_ui.visible)

	if not other_open:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("capture_mouse"):
			player.capture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _center_panel() -> void:
	if not _panel:
		return
	var viewport_size = get_viewport_rect().size
	_panel.position = (viewport_size - _panel.size) / 2.0
