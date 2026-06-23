extends Control
class_name HUD
## HUD - Displays player health, stamina, and mini-map

const CompassUIScript = preload("res://src/ui/hud/compass_ui.gd")
const ClockUIScript = preload("res://src/ui/hud/clock_ui.gd")
const BuffDisplayUIScript = preload("res://src/ui/hud/buff_display_ui.gd")
const QuestTrackerUIScript = preload("res://src/ui/hud/quest_tracker_ui.gd")

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var mini_map: SubViewportContainer = $MiniMapContainer
@onready var mini_map_camera: Camera3D = $MiniMapContainer/SubViewport/MiniMapCamera

@export var mini_map_height: float = 40.0  # Height above player

var player: Node = null
var compass: Control = null
var clock: Control = null
var buff_display: Control = null
var quest_tracker: Control = null

func _ready() -> void:
	add_to_group("hud")
	visible = false
	var settings = get_node_or_null("/root/Settings")
	if settings:
		var show_fps := bool(settings.get_setting("general", "show_fps", true))
		_create_fps_label(show_fps)
	else:
		_create_fps_label(true)

func initialize(p_player: Node) -> void:
	player = p_player
	
	if not player:
		push_error("HUD: No player provided")
		return
	
	# Connect to player signals
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	
	# Initialize bars with current values
	_update_health_bar(player.current_health, player.max_health)
	_update_stamina_bar(player.current_stamina, player.max_stamina)
	
	# Create compass UI at top-center
	compass = CompassUIScript.new()
	compass.name = "CompassUI"
	compass.anchor_left = 0.0
	compass.anchor_right = 1.0
	compass.anchor_top = 0.0
	compass.anchor_bottom = 0.0
	compass.offset_top = 8.0
	compass.offset_bottom = 44.0
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(compass)
	
	# Pass camera reference to compass
	var cam = player.get_node_or_null("CameraPivot/Camera3D")
	if cam:
		compass.set_camera(cam)
		compass.set_player(player)
	
	# Create clock UI below minimap
	clock = ClockUIScript.new()
	clock.name = "ClockUI"
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.anchor_top = 0.0
	clock.anchor_bottom = 0.0
	# Position below minimap: minimap bottom is at 284, add 4px gap
	clock.offset_left = -210.0
	clock.offset_top = 288.0
	clock.offset_right = -20.0
	clock.offset_bottom = 340.0
	clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock)
	
	# Create buff display below health/stamina bars
	buff_display = BuffDisplayUIScript.new()
	buff_display.name = "BuffDisplayUI"
	buff_display.set_player(player)
	# Position below the MarginContainer (health/stamina bars end around y=120)
	buff_display.anchor_left = 0.0
	buff_display.anchor_top = 0.0
	buff_display.offset_left = 258.0
	buff_display.offset_top = 20.0
	buff_display.offset_right = 600.0
	buff_display.offset_bottom = 60.0
	buff_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buff_display)
	
	# Create quest tracker below clock
	quest_tracker = QuestTrackerUIScript.new()
	quest_tracker.name = "QuestTrackerUI"
	quest_tracker.anchor_left = 1.0
	quest_tracker.anchor_right = 1.0
	quest_tracker.anchor_top = 0.0
	quest_tracker.anchor_bottom = 0.0
	# Clock ends at y=340, add 4px gap
	quest_tracker.offset_left = -210.0
	quest_tracker.offset_top = 344.0
	quest_tracker.offset_right = -20.0
	quest_tracker.offset_bottom = 500.0
	quest_tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quest_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quest_tracker)
	
	visible = true
	print("HUD initialized")

var _fps_label: Label = null
var _fps_update_timer: float = 0.0

func _process(delta: float) -> void:
	# Update mini-map camera to follow player
	if player and mini_map_camera:
		var player_pos = player.global_position
		mini_map_camera.global_position = Vector3(player_pos.x, player_pos.y + mini_map_height, player_pos.z)
	if _fps_label and _fps_label.visible:
		_fps_update_timer += delta
		if _fps_update_timer >= 0.25:
			_fps_update_timer = 0.0
			_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if compass and player:
		var main_world = player.get_parent()
		if main_world and main_world.has_method("get_tracked_quest_waypoints"):
			compass.set_waypoints(main_world.get_tracked_quest_waypoints())

func _on_health_changed(current: float, maximum: float) -> void:
	_update_health_bar(current, maximum)

func _on_stamina_changed(current: float, maximum: float) -> void:
	_update_stamina_bar(current, maximum)

func _update_health_bar(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current

func _update_stamina_bar(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current

func _create_fps_label(show: bool) -> void:
	if _fps_label:
		set_fps_visible(show)
		return
	_fps_label = Label.new()
	_fps_label.name = "FPSLabel"
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_left = -120.0
	_fps_label.offset_top = -30.0
	_fps_label.offset_right = -20.0
	_fps_label.offset_bottom = -4.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 0.4, 0.8))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.visible = show
	add_child(_fps_label)

func set_fps_visible(show: bool) -> void:
	if _fps_label:
		_fps_label.visible = show
