extends Node
## WeatherManager — Manages weather state transitions per season.
## Emits EventBus.weather_changed(type, intensity) when weather changes.
## Weather types: "clear", "rain", "storm", "snow"

enum WeatherType { CLEAR, RAIN, STORM, SNOW }

const WEATHER_NAMES := {
	WeatherType.CLEAR: "clear",
	WeatherType.RAIN: "rain",
	WeatherType.STORM: "storm",
	WeatherType.SNOW: "snow",
}

const WEATHER_DURATION_MIN: float = 120.0
const WEATHER_DURATION_MAX: float = 300.0
const TRANSITION_DURATION: float = 10.0

var current_weather: int = WeatherType.CLEAR
var target_weather: int = WeatherType.CLEAR
var intensity: float = 0.0
var target_intensity: float = 0.0
var _weather_timer: float = 0.0
var _next_weather_change: float = 60.0
var _is_transitioning: bool = false
var _transition_timer: float = 0.0

var _season_probabilities: Dictionary = {
	0: {WeatherType.CLEAR: 0.55, WeatherType.RAIN: 0.30, WeatherType.STORM: 0.10, WeatherType.SNOW: 0.05},
	1: {WeatherType.CLEAR: 0.75, WeatherType.RAIN: 0.15, WeatherType.STORM: 0.07, WeatherType.SNOW: 0.03},
	2: {WeatherType.CLEAR: 0.40, WeatherType.RAIN: 0.35, WeatherType.STORM: 0.15, WeatherType.SNOW: 0.10},
	3: {WeatherType.CLEAR: 0.30, WeatherType.RAIN: 0.10, WeatherType.STORM: 0.10, WeatherType.SNOW: 0.50},
}

@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var event_bus: Node = get_node_or_null("/root/EventBus")

func _ready() -> void:
	if game_manager and game_manager.has_signal("day_changed"):
		game_manager.day_changed.connect(_on_day_changed)
	_next_weather_change = randf_range(30.0, 60.0)

func _process(delta: float) -> void:
	if not game_manager or game_manager.current_state != game_manager.GameState.PLAYING:
		return

	if _is_transitioning:
		_transition_timer += delta
		var t = clampf(_transition_timer / TRANSITION_DURATION, 0.0, 1.0)
		intensity = lerp(intensity, target_intensity, t * 0.1)
		if t >= 1.0:
			intensity = target_intensity
			current_weather = target_weather
			_is_transitioning = false
			_weather_timer = 0.0
			_next_weather_change = randf_range(WEATHER_DURATION_MIN, WEATHER_DURATION_MAX)
	else:
		_weather_timer += delta
		if _weather_timer >= _next_weather_change:
			_start_weather_transition()

func _start_weather_transition() -> void:
	var season = game_manager.current_season if game_manager else 0
	var probs = _season_probabilities.get(season, _season_probabilities[0])
	var roll = randf()
	var cumulative = 0.0
	var new_weather = WeatherType.CLEAR
	for w in [WeatherType.CLEAR, WeatherType.RAIN, WeatherType.STORM, WeatherType.SNOW]:
		cumulative += probs.get(w, 0.0)
		if roll <= cumulative:
			new_weather = w
			break
	if new_weather == current_weather and not _is_transitioning:
		new_weather = WeatherType.CLEAR if current_weather != WeatherType.CLEAR else WeatherType.RAIN
	target_weather = new_weather
	target_intensity = 1.0 if new_weather != WeatherType.CLEAR else 0.0
	_is_transitioning = true
	_transition_timer = 0.0
	if event_bus:
		var weather_name = WEATHER_NAMES.get(new_weather, "clear")
		event_bus.weather_changed.emit(weather_name, target_intensity)
		if new_weather != WeatherType.CLEAR:
			event_bus.notification_shown.emit("Weather", _weather_description(new_weather), "info")

func _weather_description(w: int) -> String:
	match w:
		WeatherType.RAIN: return "It started raining."
		WeatherType.STORM: return "A storm is rolling in!"
		WeatherType.SNOW: return "Snowflakes begin to fall."
		_: return "The weather is clearing up."

func _on_day_changed(_day: int) -> void:
	_weather_timer = 0.0
	_next_weather_change = randf_range(20.0, 60.0)

func force_weather(weather: int) -> void:
	target_weather = weather
	target_intensity = 1.0 if weather != WeatherType.CLEAR else 0.0
	_is_transitioning = true
	_transition_timer = 0.0
	if event_bus:
		event_bus.weather_changed.emit(WEATHER_NAMES.get(weather, "clear"), target_intensity)

func get_weather_name() -> String:
	return WEATHER_NAMES.get(current_weather, "clear")

func get_save_data() -> Dictionary:
	return {
		"current_weather": current_weather,
		"intensity": intensity,
		"weather_timer": _weather_timer,
		"next_weather_change": _next_weather_change,
	}

func load_save_data(data: Dictionary) -> void:
	current_weather = int(data.get("current_weather", WeatherType.CLEAR))
	intensity = float(data.get("intensity", 0.0))
	_weather_timer = float(data.get("weather_timer", 0.0))
	_next_weather_change = float(data.get("next_weather_change", 60.0))
	target_weather = current_weather
	target_intensity = intensity
	_is_transitioning = false
