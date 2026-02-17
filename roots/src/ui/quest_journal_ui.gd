extends Control
class_name QuestJournalUI
## Full-screen quest journal. Toggle with J key.
## Shows quests grouped by status with click-to-track functionality.
## Built entirely in code — no .tscn needed.

var _panel: PanelContainer = null
var _title_label: Label = null
var _close_button: Button = null
var _tab_container: HBoxContainer = null
var _quest_list_scroll: ScrollContainer = null
var _quest_list: VBoxContainer = null
var _detail_scroll: ScrollContainer = null
var _detail_vbox: VBoxContainer = null

var _detail_title: Label = null
var _detail_desc: RichTextLabel = null
var _detail_objectives: VBoxContainer = null
var _detail_rewards: VBoxContainer = null
var _detail_npc_info: Label = null
var _track_button: Button = null

var _current_tab: int = 0  # 0=Active, 1=Available, 2=Completed
var _selected_quest_id: String = ""
var _tracked_quest_ids: Array = []  # Quest IDs shown on HUD tracker
var _tracker_ref: Control = null  # Direct reference to QuestTrackerUI, set by main_world
const MAX_TRACKED = 4

# Colors
const BG_COLOR = Color(0.08, 0.07, 0.06, 0.95)
const PANEL_COLOR = Color(0.12, 0.11, 0.10, 1.0)
const ACCENT_COLOR = Color(0.85, 0.7, 0.3, 1.0)
const TEXT_COLOR = Color(0.9, 0.87, 0.8, 1.0)
const DIM_COLOR = Color(0.6, 0.58, 0.52, 0.8)
const DONE_COLOR = Color(0.4, 0.7, 0.4, 1.0)
const AVAILABLE_COLOR = Color(0.3, 0.6, 0.9, 1.0)
const SELECTED_COLOR = Color(0.25, 0.22, 0.18, 1.0)
const HOVER_COLOR = Color(0.18, 0.16, 0.14, 1.0)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	# Dark overlay background
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(800, 550)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_color = ACCENT_COLOR
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Quest Journal"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	main_vbox.add_child(sep)

	# Tab buttons
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_tab_container)

	var tab_names = ["Active", "Available", "Completed"]
	for i in range(tab_names.size()):
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(100, 30)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_tab_container.add_child(btn)

	# Content split: quest list (left) + detail (right)
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	main_vbox.add_child(split)

	# Left: quest list
	var left_panel = PanelContainer.new()
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.06, 0.055, 0.05, 1.0)
	left_style.set_border_width_all(1)
	left_style.border_color = Color(0.3, 0.28, 0.25, 0.5)
	left_style.set_corner_radius_all(4)
	left_style.set_content_margin_all(4)
	left_panel.add_theme_stylebox_override("panel", left_style)
	left_panel.custom_minimum_size = Vector2(260, 0)
	split.add_child(left_panel)

	_quest_list_scroll = ScrollContainer.new()
	_quest_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_quest_list_scroll)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 2)
	_quest_list_scroll.add_child(_quest_list)

	# Right: detail panel
	var right_panel = PanelContainer.new()
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.09, 0.08, 0.07, 1.0)
	right_style.set_border_width_all(1)
	right_style.border_color = Color(0.3, 0.28, 0.25, 0.5)
	right_style.set_corner_radius_all(4)
	right_style.set_content_margin_all(8)
	right_panel.add_theme_stylebox_override("panel", right_style)
	split.add_child(right_panel)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_detail_scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 8)
	_detail_scroll.add_child(_detail_vbox)

	# Detail: title
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 18)
	_detail_title.add_theme_color_override("font_color", ACCENT_COLOR)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_vbox.add_child(_detail_title)

	# Detail: description
	_detail_desc = RichTextLabel.new()
	_detail_desc.bbcode_enabled = true
	_detail_desc.fit_content = true
	_detail_desc.scroll_active = false
	_detail_desc.custom_minimum_size = Vector2(0, 40)
	_detail_desc.add_theme_color_override("default_color", TEXT_COLOR)
	_detail_desc.add_theme_font_size_override("normal_font_size", 13)
	_detail_vbox.add_child(_detail_desc)

	# Detail: NPC info
	_detail_npc_info = Label.new()
	_detail_npc_info.add_theme_font_size_override("font_size", 12)
	_detail_npc_info.add_theme_color_override("font_color", DIM_COLOR)
	_detail_npc_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_vbox.add_child(_detail_npc_info)

	# Detail: objectives header
	var obj_header = Label.new()
	obj_header.text = "Objectives"
	obj_header.add_theme_font_size_override("font_size", 14)
	obj_header.add_theme_color_override("font_color", ACCENT_COLOR)
	_detail_vbox.add_child(obj_header)

	_detail_objectives = VBoxContainer.new()
	_detail_objectives.add_theme_constant_override("separation", 4)
	_detail_vbox.add_child(_detail_objectives)

	# Detail: rewards header
	var rew_header = Label.new()
	rew_header.text = "Rewards"
	rew_header.add_theme_font_size_override("font_size", 14)
	rew_header.add_theme_color_override("font_color", ACCENT_COLOR)
	_detail_vbox.add_child(rew_header)

	_detail_rewards = VBoxContainer.new()
	_detail_rewards.add_theme_constant_override("separation", 2)
	_detail_vbox.add_child(_detail_rewards)

	# Track button
	_track_button = Button.new()
	_track_button.text = "Track Quest"
	_track_button.custom_minimum_size = Vector2(140, 34)
	_track_button.pressed.connect(_on_track_pressed)
	_detail_vbox.add_child(_track_button)

	# Start with empty detail
	_clear_detail()

func open() -> void:
	visible = true
	_center_panel()
	_refresh_quest_list()

	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("release_mouse"):
		p.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not get_tree().paused:
		get_tree().paused = true

func close() -> void:
	visible = false
	if get_tree().paused:
		var p = get_tree().get_first_node_in_group("player")
		if p and p.has_method("capture_mouse"):
			p.capture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
			close()
			get_viewport().set_input_as_handled()

func _center_panel() -> void:
	if not _panel:
		return
	var vp = get_viewport_rect().size
	_panel.position = (vp - _panel.size) / 2.0

func _on_tab_pressed(tab_index: int) -> void:
	_current_tab = tab_index
	# Update button states
	for i in range(_tab_container.get_child_count()):
		var btn = _tab_container.get_child(i) as Button
		if btn:
			btn.button_pressed = (i == tab_index)
	_selected_quest_id = ""
	_clear_detail()
	_refresh_quest_list()

# =====================
# QUEST LIST
# =====================

func _refresh_quest_list() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return

	var quest_ids: Array = []
	match _current_tab:
		0:  # Active
			quest_ids = _get_quests_by_status(qm, QuestData.QuestStatus.ACTIVE) + _get_quests_by_status(qm, QuestData.QuestStatus.COMPLETE)
		1:  # Available
			quest_ids = _get_quests_by_status(qm, QuestData.QuestStatus.AVAILABLE)
		2:  # Completed
			quest_ids = _get_quests_by_status(qm, QuestData.QuestStatus.TURNED_IN)

	if quest_ids.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No quests"
		empty_label.add_theme_color_override("font_color", DIM_COLOR)
		empty_label.add_theme_font_size_override("font_size", 13)
		_quest_list.add_child(empty_label)
		return

	for qid in quest_ids:
		var quest = qm.quest_definitions.get(qid) as QuestData
		if not quest:
			continue
		_add_quest_list_entry(qm, qid, quest)

	# Auto-select first if nothing selected
	if _selected_quest_id.is_empty() and not quest_ids.is_empty():
		_select_quest(quest_ids[0])

func _get_quests_by_status(qm: Node, status: int) -> Array:
	var result: Array = []
	for qid in qm.quest_states:
		if qm.quest_states[qid]["status"] == status:
			result.append(qid)
	return result

func _add_quest_list_entry(qm: Node, quest_id: String, quest: QuestData) -> void:
	var btn = Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)

	var status = qm.quest_states[quest_id]["status"]
	var tracked = quest_id in _tracked_quest_ids

	# Build display text
	var prefix = ""
	if tracked:
		prefix = "[T] "
	if status == QuestData.QuestStatus.COMPLETE:
		prefix += "* "

	btn.text = prefix + quest.quest_name

	# Style based on selection
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = SELECTED_COLOR if quest_id == _selected_quest_id else Color(0, 0, 0, 0)
	style_normal.set_corner_radius_all(3)
	style_normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = HOVER_COLOR
	style_hover.set_corner_radius_all(3)
	style_hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", style_hover)

	if status == QuestData.QuestStatus.TURNED_IN:
		btn.add_theme_color_override("font_color", DONE_COLOR)
	elif status == QuestData.QuestStatus.COMPLETE:
		btn.add_theme_color_override("font_color", ACCENT_COLOR)
	elif tracked:
		btn.add_theme_color_override("font_color", AVAILABLE_COLOR)
	else:
		btn.add_theme_color_override("font_color", TEXT_COLOR)

	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_select_quest.bind(quest_id))
	_quest_list.add_child(btn)

func _select_quest(quest_id: String) -> void:
	_selected_quest_id = quest_id
	_update_detail()
	_refresh_quest_list()

# =====================
# DETAIL PANEL
# =====================

func _clear_detail() -> void:
	_detail_title.text = "Select a quest"
	_detail_desc.text = ""
	_detail_npc_info.text = ""
	for child in _detail_objectives.get_children():
		child.queue_free()
	for child in _detail_rewards.get_children():
		child.queue_free()
	_track_button.visible = false

func _update_detail() -> void:
	_clear_detail()

	var qm = get_node_or_null("/root/QuestManager")
	if not qm or _selected_quest_id.is_empty():
		return

	var quest = qm.quest_definitions.get(_selected_quest_id) as QuestData
	if not quest:
		return

	var state = qm.quest_states.get(_selected_quest_id, {})
	var status = state.get("status", QuestData.QuestStatus.UNAVAILABLE)
	var progress = state.get("progress", [])

	# Title
	_detail_title.text = quest.quest_name

	# Description
	_detail_desc.text = quest.description

	# NPC info
	var npc_lines: Array = []
	if not quest.giver_npc_id.is_empty():
		npc_lines.append("Given by: %s" % _get_npc_display_name(quest.giver_npc_id))
	if not quest.turnin_npc_id.is_empty():
		npc_lines.append("Turn in to: %s" % _get_npc_display_name(quest.turnin_npc_id))
	_detail_npc_info.text = "\n".join(npc_lines)

	# Objectives
	for i in range(quest.objectives.size()):
		var obj = quest.objectives[i]
		var obj_text = obj.get("text", "Objective")
		var target = obj.get("target", 1)
		var current = progress[i] if i < progress.size() else 0
		var done = current >= target

		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

		var prefix_str = "[x] " if done else "[ ] "
		var progress_str = " (%d/%d)" % [current, target] if target > 1 else ""
		lbl.text = prefix_str + obj_text + progress_str

		if done:
			lbl.add_theme_color_override("font_color", DONE_COLOR)
		else:
			lbl.add_theme_color_override("font_color", TEXT_COLOR)

		_detail_objectives.add_child(lbl)

	# Rewards
	if not quest.reward_xp.is_empty():
		for skill_id in quest.reward_xp:
			var lbl = Label.new()
			lbl.text = "+ %d %s XP" % [quest.reward_xp[skill_id], skill_id.capitalize()]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", AVAILABLE_COLOR)
			_detail_rewards.add_child(lbl)

	if not quest.reward_items.is_empty():
		for item_reward in quest.reward_items:
			var item_id = item_reward.get("item_id", "")
			var amount = item_reward.get("amount", 1)
			var idb = get_node_or_null("/root/ItemDatabase")
			var display_name = item_id.capitalize()
			if idb and idb.has_method("get_item"):
				var item_data = idb.get_item(item_id)
				if item_data:
					display_name = item_data.item_name
			var lbl = Label.new()
			lbl.text = "+ %d %s" % [amount, display_name]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", ACCENT_COLOR)
			_detail_rewards.add_child(lbl)

	if quest.reward_gold > 0:
		var lbl = Label.new()
		lbl.text = "+ %d Gold" % quest.reward_gold
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", ACCENT_COLOR)
		_detail_rewards.add_child(lbl)

	# Track button (only for active/complete quests)
	if status == QuestData.QuestStatus.ACTIVE or status == QuestData.QuestStatus.COMPLETE:
		_track_button.visible = true
		if _selected_quest_id in _tracked_quest_ids:
			_track_button.text = "Untrack Quest"
		else:
			_track_button.text = "Track Quest"
	else:
		_track_button.visible = false

func _on_track_pressed() -> void:
	if _selected_quest_id.is_empty():
		return

	if _selected_quest_id in _tracked_quest_ids:
		# Untrack
		_tracked_quest_ids.erase(_selected_quest_id)
		_sync_tracker_ui()
	else:
		# Track (limit to MAX_TRACKED)
		if _tracked_quest_ids.size() >= MAX_TRACKED:
			_tracked_quest_ids.pop_front()
		_tracked_quest_ids.append(_selected_quest_id)
		_sync_tracker_ui()

	_update_detail()
	_refresh_quest_list()

func _sync_tracker_ui() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	var tracker = _get_quest_tracker()
	if not qm or not tracker:
		return

	# Clear tracker and re-add only tracked quests
	# Remove quests not in tracked list
	for entry in tracker._quest_entries.duplicate():
		if entry["id"] not in _tracked_quest_ids:
			tracker.complete_quest(entry["id"])

	# Add tracked quests not yet in tracker
	for qid in _tracked_quest_ids:
		if tracker.has_quest(qid):
			continue
		var quest = qm.quest_definitions.get(qid) as QuestData
		if not quest:
			continue
		var state = qm.quest_states.get(qid, {})
		var progress = state.get("progress", [])
		var objectives: Array = []
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			objectives.append({
				"text": obj.get("text", ""),
				"current": progress[i] if i < progress.size() else 0,
				"target": obj.get("target", 1),
			})
		tracker.add_quest(qid, quest.quest_name, objectives)

func auto_track_quest(quest_id: String) -> void:
	if quest_id in _tracked_quest_ids:
		return
	if _tracked_quest_ids.size() >= MAX_TRACKED:
		_tracked_quest_ids.pop_front()
	_tracked_quest_ids.append(quest_id)

func auto_untrack_quest(quest_id: String) -> void:
	_tracked_quest_ids.erase(quest_id)

func _get_quest_tracker() -> Control:
	if _tracker_ref and is_instance_valid(_tracker_ref):
		return _tracker_ref
	# Fallback: search scene tree
	var scene = get_tree().current_scene
	if scene:
		var tracker = scene.find_child("QuestTrackerUI", true, false)
		if tracker:
			_tracker_ref = tracker
			return tracker
	return null

func _get_npc_display_name(npc_id: String) -> String:
	var names = {
		"mayor": "Elder Aldric",
		"shopkeeper": "Elara",
		"blacksmith": "Tormund",
		"baker": "Marta",
		"herbalist": "Sage Willow",
		"farmer": "Old Hank",
		"guard": "Captain Rolf",
		"innkeeper": "Bram",
	}
	return names.get(npc_id, npc_id.capitalize())
