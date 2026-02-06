extends Node
## Save Manager - Handles all save/load operations

const SAVE_DIR = "user://saves/"
const AUTOSAVE_INTERVAL = 300.0 # 5 minutes
const MAX_SAVE_SLOTS = 5

signal save_started()
signal save_completed(success: bool)
signal load_started()
signal load_completed(success: bool)

var autosave_timer: float = 0.0
var current_save_path: String = ""
var is_auto_save_enabled: bool = true

# Explicit references to autoload singletons
@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var event_bus: Node = get_node_or_null("/root/EventBus")

func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _process(delta: float) -> void:
	if is_auto_save_enabled and game_manager and game_manager.is_playing():
		autosave_timer += delta
		if autosave_timer >= AUTOSAVE_INTERVAL:
			autosave_timer = 0.0
			auto_save()

func get_save_files() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	
	for i in range(MAX_SAVE_SLOTS):
		var save_path = SAVE_DIR + "save_" + str(i + 1) + ".json"
		var save_info = get_save_info(save_path)
		if save_info.get("exists", false):
			saves.append(save_info)
	
	return saves

func get_save_info(filepath: String) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {"exists": false, "slot": -1}
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var save_data = json.data
		return {
			"exists": true,
			"slot": int(filepath.get_file().get_slice("_", 1).get_slice(".", 0)),
			"filepath": filepath,
			"timestamp": save_data.get("timestamp", 0),
			"day": save_data.get("game_state", {}).get("current_day", 0),
			"season": save_data.get("game_state", {}).get("current_season", 0),
			"world_seed": save_data.get("game_state", {}).get("world_seed", 0),
			"version": save_data.get("version", "unknown")
		}
	
	return {"exists": false, "slot": -1}

func save_game(slot: int = -1) -> bool:
	var filepath: String
	
	if slot == -1:
		# Find first empty slot or overwrite oldest
		var saves = get_save_files()
		if saves.size() < MAX_SAVE_SLOTS:
			slot = saves.size() + 1
		else:
			# Find oldest save
			var oldest_timestamp = Time.get_unix_time_from_system() + 1
			for save in saves:
				if save.get("timestamp", 0) < oldest_timestamp:
					oldest_timestamp = save.get("timestamp", 0)
					slot = save.get("slot", 1)
	
	filepath = SAVE_DIR + "save_" + str(slot) + ".json"
	current_save_path = filepath
	
	save_started.emit()
	var success = false
	if game_manager:
		success = game_manager.save_game(filepath)
	save_completed.emit(success)
	return success

func auto_save() -> void:
	if game_manager and game_manager.is_playing():
		save_game(-1)
		if event_bus:
			event_bus.emit_signal("notification_shown", "Auto Save", "Game saved automatically", "info")

func load_game(filepath: String = "") -> bool:
	if filepath == "":
		# Load from current save path or find most recent
		if current_save_path != "" and FileAccess.file_exists(current_save_path):
			filepath = current_save_path
		else:
			var saves = get_save_files()
			if saves.size() > 0:
				# Load most recent save
				var most_recent = saves[0]
				for save in saves:
					if save.get("timestamp", 0) > most_recent.get("timestamp", 0):
						most_recent = save
				filepath = most_recent.get("filepath", "")
			else:
				push_error("No save files found")
				return false
	
	load_started.emit()
	var success = false
	if game_manager:
		success = game_manager.load_game(filepath)
	load_completed.emit(success)
	return success

func load_game_slot(slot: int) -> bool:
	var filepath = SAVE_DIR + "save_" + str(slot) + ".json"
	if FileAccess.file_exists(filepath):
		return load_game(filepath)
	else:
		push_error("Save slot " + str(slot) + " does not exist")
		return false

func delete_save(slot: int) -> bool:
	var filepath = SAVE_DIR + "save_" + str(slot) + ".json"
	if FileAccess.file_exists(filepath):
		DirAccess.remove_absolute(filepath)
		return true
	return false

func copy_save(from_slot: int, to_slot: int) -> bool:
	var from_path = SAVE_DIR + "save_" + str(from_slot) + ".json"
	var to_path = SAVE_DIR + "save_" + str(to_slot) + ".json"
	
	if FileAccess.file_exists(from_path):
		var file = FileAccess.open(from_path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		file = FileAccess.open(to_path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		return true
	
	return false

func get_save_slot_name(slot: int) -> String:
	var saves = get_save_files()
	for save in saves:
		if save.get("slot", -1) == slot:
			var date_time = Time.get_datetime_dict_from_unix_time(save.get("timestamp", 0))
			var date_str = "%04d-%02d-%02d %02d:%02d" % [date_time.year, date_time.month, date_time.day, date_time.hour, date_time.minute]
			
			var season_name = "Unknown"
			if game_manager:
				var season_idx = save.get("season", 0)
				if season_idx >= 0 and season_idx < game_manager.Season.size():
					season_name = game_manager.Season.keys()[season_idx]
			
			return "%s - Day %d (%s)" % [date_str, save.get("day", 0), season_name]
	return "Empty Slot"

func format_timestamp(timestamp: int) -> String:
	var date_time = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [date_time.year, date_time.month, date_time.day, date_time.hour, date_time.minute, date_time.second]
