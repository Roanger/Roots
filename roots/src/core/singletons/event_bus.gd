extends Node
## Event Bus - Centralized event system for decoupled communication

# Signals for different game events
signal player_moved(position: Vector3)
signal player_interacted(target: Node)
signal item_picked_up(item_id: String, amount: int)
signal item_dropped(item_id: String, amount: int)
signal inventory_changed(slot_index: int, item_id: String, amount: int)
signal skill_gained(skill_name: String, amount: int, new_level: int)
signal xp_gained(skill_name: String, amount: int, total_xp: int)
signal level_up(skill_name: String, new_level: int)

# World events
signal time_updated(hour: float)
signal day_passed(day: int)
signal season_changed(season: int)
signal weather_changed(weather_type: String, intensity: float)

# Farming events
signal crop_planted(position: Vector3, crop_type: String)
signal crop_harvested(position: Vector3, crop_type: String, amount: int)
signal crop_watered(position: Vector3)
signal animal_interacted(animal_id: String, action: String)

# Crafting events
signal open_crafting_station(station_type: int)
signal crafting_started(station_type: String, recipe_id: String)
signal crafting_completed(recipe_id: String, output: Dictionary)
signal crafting_cancelled(recipe_id: String)

# Multiplayer events
signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal world_state_synced()

# UI events
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal notification_shown(title: String, message: String, type: String)
signal HUD_updated(component: String)

# Achievement events
signal achievement_unlocked(achievement_id: String)
signal milestone_reached(milestone_id: String)

# Save/Load events
signal save_started()
signal save_completed(success: bool)
signal load_started()
signal load_completed(success: bool)

# Emit a custom event with optional data
func emit_custom_event(event_name: String, data: Variant = null) -> void:
	# Check if the event exists as a signal
	if has_signal(event_name):
		if data == null:
			emit_signal(event_name)
		else:
			emit_signal(event_name, data)
	else:
		push_warning("EventBus: Unknown event '" + event_name + "'")

# Convenience methods for common events
func notify_pickup(item_id: String, amount: int) -> void:
	emit_signal("item_picked_up", item_id, amount)
	emit_signal("notification_shown", "Item Collected", "x" + str(amount) + " " + item_id, "info")

func notify_skill_gain(skill_name: String, xp_amount: int) -> void:
	emit_signal("xp_gained", skill_name, xp_amount, 0)

func notify_level_up(skill_name: String, new_level: int) -> void:
	emit_signal("level_up", skill_name, new_level)
	emit_signal("notification_shown", "Level Up!", skill_name + " reached level " + str(new_level), "success")

func notify_error(message: String) -> void:
	emit_signal("notification_shown", "Error", message, "error")
