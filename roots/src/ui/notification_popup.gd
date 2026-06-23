extends Control
class_name NotificationPopup
## Toast-style notification popups for quest events and general notifications.
## Connects to EventBus.notification_shown and QuestManager signals.

const MAX_NOTIFICATIONS: int = 5
const NOTIFICATION_DURATION: float = 4.0
const SLIDE_DURATION: float = 0.3
const NOTIFICATION_HEIGHT: float = 56.0
const NOTIFICATION_WIDTH: float = 320.0
const SPACING: float = 8.0

var _notifications: Array[Control] = []
var _quest_manager: Node = null

func _ready() -> void:
	add_to_group("notification_popup")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_TOP_RIGHT
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.notification_shown.connect(_on_notification_shown)
	_quest_manager = get_node_or_null("/root/QuestManager")
	if _quest_manager:
		_quest_manager.quest_accepted.connect(_on_quest_accepted)
		_quest_manager.quest_completed.connect(_on_quest_completed)
		_quest_manager.quest_turned_in.connect(_on_quest_turned_in)

func _on_notification_shown(title: String, message: String, type: String) -> void:
	_show_notification(title, message, _type_color(type))

func _on_quest_accepted(quest_id: String) -> void:
	var quest = _get_quest(quest_id)
	if not quest:
		return
	_show_notification("Quest Accepted", quest.quest_name, Color(0.4, 0.8, 0.4, 1.0))

func _on_quest_completed(quest_id: String) -> void:
	var quest = _get_quest(quest_id)
	if not quest:
		return
	if quest.turnin_npc_id.is_empty():
		return
	_show_notification("Quest Complete!", quest.quest_name + " — Return to turn in", Color(0.9, 0.8, 0.2, 1.0))

func _on_quest_turned_in(quest_id: String) -> void:
	var quest = _get_quest(quest_id)
	if not quest:
		return
	var reward_text = quest.quest_name
	if quest.reward_gold > 0:
		reward_text += " (+%d gold)" % quest.reward_gold
	_show_notification("Quest Turned In", reward_text, Color(0.2, 0.6, 0.9, 1.0))

func _get_quest(quest_id: String) -> QuestData:
	if _quest_manager and _quest_manager.quest_definitions.has(quest_id):
		return _quest_manager.quest_definitions[quest_id] as QuestData
	return null

func _type_color(type: String) -> Color:
	match type:
		"success": return Color(0.4, 0.8, 0.4, 1.0)
		"error": return Color(0.9, 0.3, 0.3, 1.0)
		"info": return Color(0.3, 0.6, 0.9, 1.0)
		_: return Color(0.7, 0.7, 0.7, 1.0)

func _show_notification(title: String, message: String, color: Color) -> void:
	if _notifications.size() >= MAX_NOTIFICATIONS:
		var oldest = _notifications[0]
		_notifications.remove_at(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
	_relayout()

	var panel = _create_notification_panel(title, message, color)
	_notifications.append(panel)
	_relayout()

	var tween = create_tween()
	tween.set_parallel(true)
	var start_x = -NOTIFICATION_WIDTH - 20.0
	panel.position.x = start_x
	tween.tween_property(panel, "position:x", 0.0, SLIDE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, SLIDE_DURATION).from(0.0)

	await get_tree().create_timer(NOTIFICATION_DURATION).timeout

	if not is_instance_valid(panel):
		return
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 0.0, SLIDE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(panel, "position:x", start_x, SLIDE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await fade_tween.finished
	if is_instance_valid(panel):
		_notifications.erase(panel)
		panel.queue_free()
		_relayout()

func _create_notification_panel(title: String, message: String, color: Color) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(NOTIFICATION_WIDTH, 0)
	panel.modulate.a = 0.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.08, 0.92)
	style.border_width_left = 4
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	var msg_label = Label.new()
	msg_label.text = message
	msg_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	msg_label.add_theme_font_size_override("font_size", 12)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_label)

	add_child(panel)
	return panel

func _relayout() -> void:
	var y_offset = 60.0
	for i in range(_notifications.size() - 1, -1, -1):
		var panel = _notifications[i]
		if not is_instance_valid(panel):
			_notifications.remove_at(i)
			continue
		panel.position = Vector2(0.0, y_offset)
		y_offset += NOTIFICATION_HEIGHT + SPACING
