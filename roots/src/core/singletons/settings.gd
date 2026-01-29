extends Node
## Settings Manager - Handles all game settings with persistence

const SETTINGS_FILE = "user://settings.json"

# Settings categories
enum Category {
	GENERAL,
	GRAPHICS,
	AUDIO,
	CONTROLS,
	GAMEPLAY
}

# Default settings
var defaults: Dictionary = {
	"general": {
		"language": "en",
		"fullscreen": false,
		"vsync": true,
		"show_fps": true,
		"ui_scale": 1.0
	},
	"graphics": {
		"quality_preset": 2,  # 0=low, 1=medium, 2=high, 3=ultra
		"anti_aliasing": 2,
		"shadow_quality": 2,
		"bloom": true,
		"ambient_occlusion": true,
		"field_of_view": 75.0,
		"draw_distance": 1000.0,
		"chunk_view_distance": 4
	},
	"audio": {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.8,
		"voice_volume": 0.8,
		"ambient_volume": 0.6,
		"enable_voice_chat": false
	},
	"controls": {
		"mouse_sensitivity": 0.5,
		"invert_y": false,
		"use_gamepad": true,
		"gamepad_deadzone": 0.2,
		"quick_slot_1": 0,
		"quick_slot_2": 1,
		"quick_slot_3": 2,
		"quick_slot_4": 3,
		"quick_slot_5": 4
	},
	"gameplay": {
		"auto_save": true,
		"auto_save_interval": 5,
		"show_tooltips": true,
		"show_item_names": true,
		"damage_numbers": true,
		"auto_pickup": false,
		"hotbar_on_bottom": true,
		"compact_inventory": false
	}
}

# Current settings
var settings: Dictionary = {}

# Settings change signals
signal setting_changed(category: String, key: String, value: Variant)

# Explicit reference to autoload
@onready var game_manager: Node = get_node_or_null("/root/GameManager")

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			settings = merge_settings(json.data, defaults)
		else:
			settings = defaults.duplicate(true)
			push_error("Failed to parse settings file, using defaults")
	else:
		settings = defaults.duplicate(true)
	
	apply_settings()

func save_settings() -> void:
	var json_string = JSON.stringify(settings, "\t")
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

func merge_settings(user_settings: Dictionary, default_settings: Dictionary) -> Dictionary:
	var result = default_settings.duplicate(true)
	
	for category in user_settings:
		if category in result:
			if typeof(user_settings[category]) == TYPE_DICTIONARY:
				for key in user_settings[category]:
					result[category][key] = user_settings[category][key]
			else:
				result[category] = user_settings[category]
		else:
			result[category] = user_settings[category]
	
	return result

# Renamed from 'get' to avoid conflict with Object.get()
func get_setting(category: String, key: String, default: Variant = null) -> Variant:
	if category in settings and key in settings[category]:
		return settings[category][key]
	return default

# Renamed from 'set' to avoid conflict with Object.set()
func set_setting(category: String, key: String, value: Variant) -> void:
	if not category in settings:
		settings[category] = {}
	
	var old_value = get_setting(category, key)
	settings[category][key] = value
	
	emit_signal("setting_changed", category, key, value)
	
	# Auto-save on setting change
	save_settings()
	
	# Apply setting immediately if applicable
	apply_setting(category, key, value)

func apply_settings() -> void:
	# Apply all settings at once (called on game start)
	for category in settings:
		for key in settings[category]:
			apply_setting(category, key, settings[category][key])

func apply_setting(category: String, key: String, value: Variant) -> void:
	match category:
		"general":
			apply_general_setting(key, value)
		"graphics":
			apply_graphics_setting(key, value)
		"audio":
			apply_audio_setting(key, value)
		"controls":
			apply_controls_setting(key, value)

func apply_general_setting(key: String, value: Variant) -> void:
	match key:
		"fullscreen":
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		"show_fps":
			# Will be handled by FPS display component
			pass
		"ui_scale":
			# Will be handled by UI scaling system
			pass

func apply_graphics_setting(key: String, value: Variant) -> void:
	match key:
		"quality_preset":
			apply_quality_preset(value)
		"anti_aliasing":
			get_viewport().set_msaa_3d(value)
		"shadow_quality":
			# Will be handled by shadow system
			pass
		"bloom":
			# Will be handled by WorldEnvironment
			pass
		"field_of_view":
			if game_manager and game_manager.is_playing() and game_manager.current_state == game_manager.GameState.PLAYING:
				var player = get_tree().get_first_node_in_group("player")
				if player and player.has_method("set_fov"):
					player.set_fov(value)

func apply_quality_preset(preset: int) -> void:
	var quality_settings = {
		0: {"aa": 0, "shadows": 0, "bloom": false, "ao": false, "chunks": 2},
		1: {"aa": 1, "shadows": 1, "bloom": true, "ao": false, "chunks": 3},
		2: {"aa": 2, "shadows": 2, "bloom": true, "ao": true, "chunks": 4},
		3: {"aa": 2, "shadows": 3, "bloom": true, "ao": true, "chunks": 5}
	}
	
	var q = quality_settings.get(preset, quality_settings[2])
	set_setting("graphics", "anti_aliasing", q.aa)
	set_setting("graphics", "shadow_quality", q.shadows)
	set_setting("graphics", "bloom", q.bloom)
	set_setting("graphics", "ambient_occlusion", q.ao)
	set_setting("graphics", "chunk_view_distance", q.chunks)

func apply_audio_setting(key: String, value: Variant) -> void:
	match key:
		"master_volume":
			var master_idx = AudioServer.get_bus_index("Master")
			if master_idx >= 0:
				AudioServer.set_bus_mute(master_idx, value <= 0.0)
				AudioServer.set_bus_volume_db(master_idx, linear_to_db(value) if value > 0 else -80)
		"music_volume":
			var music_idx = AudioServer.get_bus_index("Music")
			if music_idx >= 0:
				AudioServer.set_bus_volume_db(music_idx, linear_to_db(value) if value > 0 else -80)
		"sfx_volume":
			var sfx_idx = AudioServer.get_bus_index("SFX")
			if sfx_idx >= 0:
				AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(value) if value > 0 else -80)
		"voice_volume":
			var voice_idx = AudioServer.get_bus_index("Voice")
			if voice_idx >= 0:
				AudioServer.set_bus_volume_db(voice_idx, linear_to_db(value) if value > 0 else -80)
		"ambient_volume":
			var ambient_idx = AudioServer.get_bus_index("Ambient")
			if ambient_idx >= 0:
				AudioServer.set_bus_volume_db(ambient_idx, linear_to_db(value) if value > 0 else -80)

func apply_controls_setting(key: String, value: Variant) -> void:
	# Controls are applied directly from settings when needed
	pass

func reset_to_defaults() -> void:
	settings = defaults.duplicate(true)
	apply_settings()
	save_settings()

func get_category_keys(category: String) -> Array:
	if category in settings:
		return settings[category].keys()
	return []

func get_all_settings() -> Dictionary:
	return settings.duplicate(true)
