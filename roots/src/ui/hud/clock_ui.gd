extends Control
class_name ClockUI
## In-game clock display - shows time, day, and season below the minimap.
## Styled like Vintage Story's clock with a cozy semi-transparent background.

@export var clock_width: float = 180.0
@export var clock_height: float = 52.0
@export var bg_color: Color = Color(0.0, 0.0, 0.0, 0.4)
@export var border_color: Color = Color(0.5, 0.7, 0.8, 0.3)
@export var time_color: Color = Color(0.95, 0.92, 0.8, 1.0)
@export var day_color: Color = Color(0.7, 0.8, 0.9, 0.9)
@export var season_color: Color = Color(0.6, 0.85, 0.6, 0.85)

var _game_manager: Node = null
var _current_hour: float = 6.0
var _current_day: int = 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(clock_width, clock_height)
	_game_manager = get_node_or_null("/root/GameManager")
	if _game_manager:
		if _game_manager.has_signal("time_changed"):
			_game_manager.time_changed.connect(_on_time_changed)
		if _game_manager.has_signal("day_changed"):
			_game_manager.day_changed.connect(_on_day_changed)
		_current_hour = _game_manager.current_hour
		_current_day = _game_manager.current_day

func _on_time_changed(hour: float) -> void:
	_current_hour = hour
	queue_redraw()

func _on_day_changed(day: int) -> void:
	_current_day = day
	queue_redraw()

func _draw() -> void:
	var font = ThemeDB.fallback_font
	
	# Background
	var bg_rect = Rect2(0, 0, clock_width, clock_height)
	draw_rect(bg_rect, bg_color)
	draw_rect(bg_rect, border_color, false, 1.0)
	
	# Time string (large, centered)
	var time_str = _get_time_string()
	var time_size = 18
	var time_text_size = font.get_string_size(time_str, HORIZONTAL_ALIGNMENT_CENTER, -1, time_size)
	draw_string(
		font,
		Vector2((clock_width - time_text_size.x) / 2.0, 20),
		time_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		time_size,
		time_color
	)
	
	# Day + Season (smaller, centered below time)
	var info_str = _get_day_string()
	var info_size = 12
	var info_text_size = font.get_string_size(info_str, HORIZONTAL_ALIGNMENT_CENTER, -1, info_size)
	draw_string(
		font,
		Vector2((clock_width - info_text_size.x) / 2.0, 40),
		info_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		info_size,
		day_color
	)
	
	# Sun/moon icon indicator
	_draw_time_icon()

func _draw_time_icon() -> void:
	var icon_x = 14.0
	var icon_y = 18.0
	var radius = 6.0
	
	if _current_hour >= 6.0 and _current_hour < 20.0:
		# Sun icon - yellow circle with rays
		var sun_color = Color(1.0, 0.85, 0.3, 0.9)
		draw_circle(Vector2(icon_x, icon_y), radius, sun_color)
		# Small rays
		for i in range(8):
			var angle = i * PI / 4.0
			var inner = Vector2(icon_x + cos(angle) * (radius + 1), icon_y + sin(angle) * (radius + 1))
			var outer = Vector2(icon_x + cos(angle) * (radius + 3), icon_y + sin(angle) * (radius + 3))
			draw_line(inner, outer, Color(sun_color, 0.6), 1.0)
	else:
		# Moon icon - crescent via two overlapping circles
		var moon_color = Color(0.8, 0.85, 0.95, 0.9)
		draw_circle(Vector2(icon_x, icon_y), radius, moon_color)
		draw_circle(Vector2(icon_x + 3, icon_y - 2), radius - 1, bg_color)

func _get_time_string() -> String:
	if _game_manager and _game_manager.has_method("get_time_of_day_string"):
		return _game_manager.get_time_of_day_string()
	# Fallback
	var hour = int(_current_hour)
	var minute = int((_current_hour - hour) * 60)
	var am_pm = "AM" if hour < 12 else "PM"
	var display_hour = hour if hour <= 12 else hour - 12
	if display_hour == 0:
		display_hour = 12
	return "%02d:%02d %s" % [display_hour, minute, am_pm]

func _get_day_string() -> String:
	var season_str = ""
	var day_str = "Day %d" % _current_day
	if _game_manager:
		if _game_manager.has_method("get_season_name"):
			season_str = _game_manager.get_season_name()
		if _game_manager.has_method("get_day_of_week"):
			day_str = _game_manager.get_day_of_week()
	if season_str != "":
		return "%s - %s, Day %d" % [day_str, season_str, _current_day]
	return day_str
