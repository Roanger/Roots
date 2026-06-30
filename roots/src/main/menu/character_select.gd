extends Control
## Character selection screen. Shows a rotating 3D preview of character models
## with left/right arrows to cycle and a Confirm button to start the game.

const CHARACTER_SCALE: float = 0.5

var _characters: Array[Dictionary] = []
var _current_index: int = 0
var _preview_scene: Node3D = null
var _preview_camera: Camera3D = null
var _preview_light: DirectionalLight3D = null
var _model_holder: Node3D = null
var _current_model: Node3D = null
var _name_label: Label = null
var _subtitle_label: Label = null
var _rotate_speed: float = 0.5

@onready var game_manager: Node = get_node_or_null("/root/GameManager")

func _ready() -> void:
	_load_character_list()
	_build_ui()
	_show_character(0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _load_character_list() -> void:
	var dir = DirAccess.open("res://assets/characters")
	if not dir:
		push_warning("CharacterSelect: Cannot open characters directory")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".blend") and not file_name.begins_with("Cow") and not file_name.begins_with("Pug") and not file_name.begins_with("VikingHelmet") and not file_name.ends_with("_Hair.blend") and not file_name.begins_with("Chef_Hat") and not file_name.begins_with("Ninja_Sand"):
			var display_name = file_name.get_basename().replace("_", " ")
			_characters.append({
				"path": "res://assets/characters/" + file_name,
				"name": display_name,
			})
		file_name = dir.get_next()
	dir.list_dir_end()
	_characters.sort_custom(func(a, b): return a.name < b.name)
	if _characters.is_empty():
		_characters.append({"path": "", "name": "Default"})

func _build_ui() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "Choose Your Character"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(get_viewport().get_window().size.x, 50)
	add_child(title)

	# 3D preview viewport
	var vp_size = Vector2(400, 500)
	var vp_pos = Vector2(get_viewport().get_window().size.x * 0.5 - vp_size.x * 0.5, 100)
	var container = SubViewportContainer.new()
	container.position = vp_pos
	container.size = vp_size
	container.stretch = true
	add_child(container)
	var sub_vp = SubViewport.new()
	sub_vp.size = vp_size
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub_vp)

	_preview_scene = Node3D.new()
	sub_vp.add_child(_preview_scene)

	_preview_camera = Camera3D.new()
	_preview_camera.position = Vector3(0, 1.0, 3.5)
	_preview_camera.look_at(Vector3(0, 0.8, 0))
	_preview_scene.add_child(_preview_camera)

	_preview_light = DirectionalLight3D.new()
	_preview_light.position = Vector3(2, 3, 2)
	_preview_light.look_at(Vector3.ZERO)
	_preview_light.light_energy = 1.2
	_preview_scene.add_child(_preview_light)

	var ambient = WorldEnvironment.new()
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.ambient_light_energy = 0.6
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.15, 0.2, 0.35)
	sky_mat.sky_horizon_color = Color(0.3, 0.35, 0.45)
	sky.sky_material = sky_mat
	env.sky = sky
	ambient.environment = env
	_preview_scene.add_child(ambient)

	_model_holder = Node3D.new()
	_preview_scene.add_child(_model_holder)

	# Left arrow
	var left_btn = Button.new()
	left_btn.text = "<"
	left_btn.add_theme_font_size_override("font_size", 32)
	left_btn.position = Vector2(vp_pos.x - 60, vp_pos.y + vp_size.y * 0.5 - 30)
	left_btn.size = Vector2(50, 60)
	left_btn.pressed.connect(_prev_character)
	add_child(left_btn)

	# Right arrow
	var right_btn = Button.new()
	right_btn.text = ">"
	right_btn.add_theme_font_size_override("font_size", 32)
	right_btn.position = Vector2(vp_pos.x + vp_size.x + 10, vp_pos.y + vp_size.y * 0.5 - 30)
	right_btn.size = Vector2(50, 60)
	right_btn.pressed.connect(_next_character)
	add_child(right_btn)

	# Character name label
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, vp_pos.y + vp_size.y + 10)
	_name_label.size = Vector2(get_viewport().get_window().size.x, 40)
	add_child(_name_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "Use arrows to browse"
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.modulate = Color(0.6, 0.6, 0.6)
	_subtitle_label.position = Vector2(0, vp_pos.y + vp_size.y + 45)
	_subtitle_label.size = Vector2(get_viewport().get_window().size.x, 30)
	add_child(_subtitle_label)

	# Confirm button
	var confirm_btn = Button.new()
	confirm_btn.text = "Start Game"
	confirm_btn.add_theme_font_size_override("font_size", 24)
	confirm_btn.position = Vector2(get_viewport().get_window().size.x * 0.5 - 100, vp_pos.y + vp_size.y + 90)
	confirm_btn.size = Vector2(200, 50)
	confirm_btn.pressed.connect(_confirm)
	add_child(confirm_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(20, 20)
	back_btn.size = Vector2(80, 40)
	back_btn.pressed.connect(_back)
	add_child(back_btn)

func _show_character(index: int) -> void:
	if _characters.is_empty():
		return
	_current_index = index % _characters.size()
	if _current_index < 0:
		_current_index = _characters.size() - 1
	var char_data = _characters[_current_index]
	_name_label.text = char_data.name

	# Clear old model
	if _current_model and is_instance_valid(_current_model):
		_current_model.queue_free()
		_current_model = null

	if char_data.path.is_empty():
		return

	var scene = load(char_data.path) as PackedScene
	if not scene:
		_name_label.text = char_data.name + " (failed to load)"
		return
	_current_model = scene.instantiate() as Node3D
	if _current_model:
		_current_model.scale = Vector3.ONE * CHARACTER_SCALE
		_model_holder.add_child(_current_model)

func _prev_character() -> void:
	_show_character(_current_index - 1)

func _next_character() -> void:
	_show_character(_current_index + 1)

func _confirm() -> void:
	if game_manager:
		game_manager.selected_character_path = _characters[_current_index].path
	get_tree().change_scene_to_file("res://src/main/world/main_world.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://src/main/menu/main_menu.tscn")

func _process(delta: float) -> void:
	if _model_holder:
		_model_holder.rotation.y += _rotate_speed * delta

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()
