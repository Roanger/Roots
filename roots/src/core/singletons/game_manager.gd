extends Node
## Main game manager - handles game state and lifecycle

signal game_state_changed(state: GameState)
signal day_changed(day: int)
signal time_changed(hour: float)
signal season_changed(season: Season)

enum GameState {
	MENU,
	LOADING,
	PLAYING,
	PAUSED,
	SAVING
}

enum Season {
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER
}

var current_state: GameState = GameState.MENU
var current_day: int = 1
var current_hour: float = 6.0 # Game starts at 6 AM
var current_season: Season = Season.SPRING

# Game constants
const DAY_DURATION_HOURS: float = 24.0
const SEASON_DAYS: int = 30
const TIME_SCALE: float = 1.0 # Can be adjusted for faster/slower time

# World settings
var world_seed: int = 0
var is_multiplayer: bool = false
var local_player_id: int = 1

# Game data
var player_data: Dictionary = {}
var world_data: Dictionary = {}

func _ready() -> void:
	# Generate world seed if not set
	if world_seed == 0:
		world_seed = randi()
	
	print("Game Manager initialized with seed: ", world_seed)

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		_process_time(delta * TIME_SCALE)

func _process_time(delta: float) -> void:
	# Add time (1 game hour = 60 real seconds at scale 1.0)
	current_hour += delta * (24.0 / 60.0) * TIME_SCALE
	
	if current_hour >= DAY_DURATION_HOURS:
		current_hour = 0.0
		advance_day()
	
	emit_signal("time_changed", current_hour)

func advance_day() -> void:
	current_day += 1
	
	# Check for season change
	if current_day % SEASON_DAYS == 0:
		change_season()
	
	emit_signal("day_changed", current_day)
	print("Day ", current_day, " - Season: ", Season.keys()[current_season])

func change_season() -> void:
	var seasons_array = Season.values()
	var current_index = seasons_array.find(current_season)
	var next_index = (current_index + 1) % seasons_array.size()
	current_season = seasons_array[next_index]
	emit_signal("season_changed", current_season)
	print("Season changed to: ", Season.keys()[current_season])

func set_game_state(new_state: GameState) -> void:
	var old_state = current_state
	current_state = new_state
	emit_signal("game_state_changed", new_state)
	
	match new_state:
		GameState.PLAYING:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameState.PAUSED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.MENU:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func get_time_of_day_string() -> String:
	var hour = int(current_hour)
	var minute = int((current_hour - hour) * 60)
	var am_pm = "AM" if hour < 12 else "PM"
	var display_hour = hour if hour <= 12 else hour - 12
	if display_hour == 0:
		display_hour = 12
	return "%02d:%02d %s" % [display_hour, minute, am_pm]

func get_day_of_week() -> String:
	var day_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var day_index = (current_day - 1) % 7
	return day_names[day_index]

func get_season_name() -> String:
	return Season.keys()[current_season]

func save_game(filepath: String) -> bool:
	set_game_state(GameState.SAVING)
	
	var save_data = {
		"version": "1.0.0",
		"timestamp": Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system()),
		"game_state": {
			"current_day": current_day,
			"current_hour": current_hour,
			"current_season": current_season,
			"world_seed": world_seed
		},
		"player_data": player_data,
		"world_data": world_data
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		set_game_state(GameState.PLAYING)
		print("Game saved to: ", filepath)
		return true
	else:
		set_game_state(GameState.PLAYING)
		push_error("Failed to save game to: " + filepath)
		return false

func load_game(filepath: String) -> bool:
	set_game_state(GameState.LOADING)
	
	if not FileAccess.file_exists(filepath):
		set_game_state(GameState.MENU)
		push_error("Save file not found: " + filepath)
		return false
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var save_data = json.data
		current_day = save_data.get("game_state", {}).get("current_day", 1)
		current_hour = save_data.get("game_state", {}).get("current_hour", 6.0)
		current_season = save_data.get("game_state", {}).get("current_season", Season.SPRING)
		world_seed = save_data.get("game_state", {}).get("world_seed", randi())
		player_data = save_data.get("player_data", {})
		world_data = save_data.get("world_data", {})
		
		set_game_state(GameState.PLAYING)
		print("Game loaded from: ", filepath)
		return true
	else:
		set_game_state(GameState.MENU)
		push_error("Failed to parse save file: " + filepath)
		return false

func reset_game() -> void:
	current_day = 1
	current_hour = 6.0
	current_season = Season.SPRING
	world_seed = randi()
	player_data.clear()
	world_data.clear()
	set_game_state(GameState.MENU)
