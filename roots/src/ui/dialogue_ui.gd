extends Control
class_name DialogueUI
## Dialogue box UI for NPC conversations.
## Shows NPC name, dialogue text, and clickable choice buttons.
## Built entirely in code — no .tscn needed.

var _npc: Node = null  # BaseNPC
var _player: Node3D = null
var _dialogue_tree: Array = []
var _current_index: int = 0

# UI elements
var _panel: PanelContainer = null
var _name_label: Label = null
var _text_label: RichTextLabel = null
var _choices_container: VBoxContainer = null
var _continue_button: Button = null

signal dialogue_closed()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# Full-screen overlay to capture clicks
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dark semi-transparent background at bottom
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -220
	_panel.offset_left = 100
	_panel.offset_right = -100
	_panel.offset_bottom = -20

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# NPC name
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	vbox.add_child(_name_label)

	# Dialogue text
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(0, 60)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	vbox.add_child(_text_label)

	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_choices_container)

	# Continue button (for dialogue without choices)
	_continue_button = Button.new()
	_continue_button.text = "Continue..."
	_continue_button.add_theme_font_size_override("font_size", 14)
	_continue_button.pressed.connect(_on_continue)
	_continue_button.visible = false
	vbox.add_child(_continue_button)

func open(npc: Node, player: Node3D) -> void:
	_npc = npc
	_player = player
	_current_index = 0

	if npc.npc_data and npc.npc_data.dialogue.size() > 0:
		_dialogue_tree = npc.npc_data.dialogue
	else:
		# Default dialogue for NPCs without custom dialogue
		_dialogue_tree = [
			{"text": "Hello there, traveler! What can I do for you?", "choices": [
				{"text": "Just looking around.", "action": "close"},
			]}
		]
		# Add shop option if NPC has inventory
		if npc.npc_data and npc.npc_data.shop_inventory.size() > 0:
			_dialogue_tree[0]["choices"].insert(0, {"text": "Show me your wares.", "action": "shop"})

	_name_label.text = npc.npc_data.display_name if npc.npc_data else "NPC"
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_entry(_current_index)

func close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _npc and _npc.has_method("end_conversation"):
		_npc.end_conversation()
	_npc = null
	_player = null
	_dialogue_tree = []
	dialogue_closed.emit()

func _show_entry(index: int) -> void:
	if index < 0 or index >= _dialogue_tree.size():
		close()
		return

	_current_index = index
	var entry = _dialogue_tree[index]
	_text_label.text = entry.get("text", "...")

	# Clear old choices
	for child in _choices_container.get_children():
		child.queue_free()

	var choices = entry.get("choices", [])
	if choices.size() > 0:
		_continue_button.visible = false
		for i in range(choices.size()):
			var choice = choices[i]
			var btn = Button.new()
			btn.text = "> " + choice.get("text", "...")
			btn.add_theme_font_size_override("font_size", 14)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.15, 0.12, 0.08, 0.6)
			btn_style.set_corner_radius_all(4)
			btn_style.set_content_margin_all(6)
			btn.add_theme_stylebox_override("normal", btn_style)

			var hover_style = btn_style.duplicate()
			hover_style.bg_color = Color(0.25, 0.2, 0.12, 0.8)
			btn.add_theme_stylebox_override("hover", hover_style)

			btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))

			var choice_data = choice
			btn.pressed.connect(_on_choice_selected.bind(choice_data))
			_choices_container.add_child(btn)
	else:
		# No choices — show continue button to advance to next entry
		_continue_button.visible = true

func _on_choice_selected(choice: Dictionary) -> void:
	var action = choice.get("action", "")
	# Save refs before close() nulls them
	var npc_ref = _npc
	var _player_ref = _player

	match action:
		"close":
			close()
		"shop":
			# Close dialogue but keep mouse visible for shop transition
			visible = false
			_npc = null
			_player = null
			_dialogue_tree = []
			dialogue_closed.emit()
			if npc_ref and npc_ref.has_method("open_shop"):
				npc_ref.open_shop()
		"quest":
			# TODO: Open quest UI
			close()
		_:
			# Navigate to next dialogue entry
			var next_idx = choice.get("next", _current_index + 1)
			_show_entry(next_idx)

func _on_continue() -> void:
	_show_entry(_current_index + 1)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Close on Escape
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	# Continue on E / interact
	if event.is_action_pressed("interact") and _continue_button.visible:
		_on_continue()
		get_viewport().set_input_as_handled()
