extends Control
## Settings Menu — Graphics + Controls options panel

@onready var settings: Node = get_node_or_null("/root/Settings")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 420)
	panel.position = -panel.custom_minimum_size / 2
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	vbox.add_child(_make_section_label("Graphics"))
	vbox.add_child(_make_option_row("Quality Preset", ["Low", "Medium", "High", "Ultra"], "graphics", "quality_preset", _on_quality_changed))
	vbox.add_child(_make_option_row("Anti-Aliasing", ["Off", "2x", "4x", "8x"], "graphics", "anti_aliasing", _on_aa_changed))
	vbox.add_child(_make_option_row("Shadows", ["Off", "Low", "Medium", "High", "Ultra"], "graphics", "shadow_quality", _on_shadow_changed))
	vbox.add_child(_make_check_row("Bloom", "graphics", "bloom", _on_bloom_changed))
	vbox.add_child(_make_check_row("Ambient Occlusion", "graphics", "ambient_occlusion", _on_ao_changed))
	vbox.add_child(_make_slider_row("Field of View", 60.0, 100.0, 1.0, "graphics", "field_of_view", _on_fov_changed))
	vbox.add_child(_make_slider_row("Chunk View Distance", 2.0, 8.0, 1.0, "graphics", "chunk_view_distance", _on_chunk_dist_changed))

	vbox.add_child(_make_section_label("Controls"))
	vbox.add_child(_make_slider_row("Mouse Sensitivity", 0.1, 2.0, 0.05, "controls", "mouse_sensitivity", _on_sensitivity_changed))
	vbox.add_child(_make_check_row("Invert Y", "controls", "invert_y", _on_invert_changed))

	vbox.add_child(_make_section_label("General"))
	vbox.add_child(_make_check_row("Fullscreen", "general", "fullscreen", _on_fullscreen_changed))
	vbox.add_child(_make_check_row("VSync", "general", "vsync", _on_vsync_changed))
	vbox.add_child(_make_check_row("Show FPS", "general", "show_fps", _on_fps_changed))

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	return label

func _make_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.5, 0.2, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _make_option_row(label_text: String, options: Array, category: String, key: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)
	var btn := OptionButton.new()
	for opt in options:
		btn.add_item(opt)
	var current_val := int(settings.get_setting(category, key, 0))
	btn.selected = clampi(current_val, 0, options.size() - 1)
	btn.item_selected.connect(callback.bind(btn))
	row.add_child(btn)
	return row

func _make_check_row(label_text: String, category: String, key: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)
	var btn := CheckBox.new()
	btn.set_pressed_no_signal(bool(settings.get_setting(category, key, false)))
	btn.toggled.connect(callback)
	row.add_child(btn)
	return row

func _make_slider_row(label_text: String, min_val: float, max_val: float, step: float, category: String, key: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = float(settings.get_setting(category, key, min_val))
	slider.custom_minimum_size = Vector2(180, 0)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	var val_label := Label.new()
	val_label.custom_minimum_size = Vector2(60, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.text = "%.0f" % slider.value
	slider.value_changed.connect(func(v: float): val_label.text = "%.0f" % v)
	row.add_child(val_label)
	return row

func _on_quality_changed(idx: int, _btn: OptionButton) -> void:
	settings.set_setting("graphics", "quality_preset", idx)

func _on_aa_changed(idx: int, _btn: OptionButton) -> void:
	settings.set_setting("graphics", "anti_aliasing", idx)

func _on_shadow_changed(idx: int, _btn: OptionButton) -> void:
	settings.set_setting("graphics", "shadow_quality", idx)

func _on_bloom_changed(enabled: bool) -> void:
	settings.set_setting("graphics", "bloom", enabled)

func _on_ao_changed(enabled: bool) -> void:
	settings.set_setting("graphics", "ambient_occlusion", enabled)

func _on_fov_changed(value: float) -> void:
	settings.set_setting("graphics", "field_of_view", value)

func _on_chunk_dist_changed(value: float) -> void:
	settings.set_setting("graphics", "chunk_view_distance", int(value))

func _on_sensitivity_changed(value: float) -> void:
	settings.set_setting("controls", "mouse_sensitivity", value)

func _on_invert_changed(enabled: bool) -> void:
	settings.set_setting("controls", "invert_y", enabled)

func _on_fullscreen_changed(enabled: bool) -> void:
	settings.set_setting("general", "fullscreen", enabled)

func _on_vsync_changed(enabled: bool) -> void:
	settings.set_setting("general", "vsync", enabled)

func _on_fps_changed(enabled: bool) -> void:
	settings.set_setting("general", "show_fps", enabled)

func _on_back_pressed() -> void:
	var main_menu := get_parent()
	if main_menu and main_menu.has_method("_update_menu_state"):
		main_menu._update_menu_state("main")
