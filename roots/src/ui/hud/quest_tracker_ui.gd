extends Control
class_name QuestTrackerUI
## Displays active quests below the clock/minimap in the HUD.
## Shows quest name, description, and objective progress.
## Built entirely in code — no .tscn needed.

const MAX_VISIBLE_QUESTS = 4

var _quest_entries: Array = []  # Array of { "id", "title", "objectives": [{ "text", "current", "target", "done" }] }
var _bg_color: Color = Color(0.0, 0.0, 0.0, 0.4)
var _border_color: Color = Color(0.5, 0.7, 0.8, 0.3)
var _title_color: Color = Color(0.95, 0.85, 0.5, 1.0)
var _objective_color: Color = Color(0.85, 0.82, 0.75, 0.9)
var _done_color: Color = Color(0.5, 0.75, 0.5, 0.7)
var _header_color: Color = Color(0.7, 0.65, 0.5, 0.9)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 30)

func add_quest(quest_id: String, title: String, objectives: Array) -> void:
	## objectives: [{ "text": String, "current": int, "target": int }]
	# Don't add duplicates
	for entry in _quest_entries:
		if entry["id"] == quest_id:
			return
	
	var formatted_objectives: Array = []
	for obj in objectives:
		formatted_objectives.append({
			"text": obj.get("text", ""),
			"current": obj.get("current", 0),
			"target": obj.get("target", 1),
			"done": false,
		})
	
	_quest_entries.append({
		"id": quest_id,
		"title": title,
		"objectives": formatted_objectives,
	})
	queue_redraw()

func update_objective(quest_id: String, objective_index: int, current: int) -> void:
	for entry in _quest_entries:
		if entry["id"] == quest_id:
			if objective_index >= 0 and objective_index < entry["objectives"].size():
				var obj = entry["objectives"][objective_index]
				obj["current"] = current
				if current >= obj["target"]:
					obj["done"] = true
			queue_redraw()
			return

func complete_quest(quest_id: String) -> void:
	for i in range(_quest_entries.size()):
		if _quest_entries[i]["id"] == quest_id:
			_quest_entries.remove_at(i)
			queue_redraw()
			return

func remove_quest(quest_id: String) -> void:
	complete_quest(quest_id)

func has_quest(quest_id: String) -> bool:
	for entry in _quest_entries:
		if entry["id"] == quest_id:
			return true
	return false

func get_quest_count() -> int:
	return _quest_entries.size()

func _draw() -> void:
	var font = ThemeDB.fallback_font
	if _quest_entries.is_empty():
		return
	
	# Calculate total height needed
	var header_size = 13
	var title_size = 13
	var obj_size = 11
	var padding = 6.0
	var line_height = 16.0
	var obj_line_height = 14.0
	var quest_gap = 6.0
	
	var total_height = padding  # Top padding
	total_height += line_height  # "Quests" header
	
	var visible_quests = mini(_quest_entries.size(), MAX_VISIBLE_QUESTS)
	for i in range(visible_quests):
		var entry = _quest_entries[i]
		total_height += line_height  # Quest title
		total_height += entry["objectives"].size() * obj_line_height  # Objectives
		if i < visible_quests - 1:
			total_height += quest_gap
	
	total_height += padding  # Bottom padding
	
	var panel_width = 190.0
	
	# Background
	var bg_rect = Rect2(0, 0, panel_width, total_height)
	draw_rect(bg_rect, _bg_color)
	draw_rect(bg_rect, _border_color, false, 1.0)
	
	var y_pos = padding
	
	# Header
	draw_string(font, Vector2(padding, y_pos + header_size), "Quests", HORIZONTAL_ALIGNMENT_LEFT, -1, header_size, _header_color)
	y_pos += line_height
	
	# Draw separator line
	draw_line(Vector2(padding, y_pos), Vector2(panel_width - padding, y_pos), _border_color, 1.0)
	y_pos += 2.0
	
	# Quest entries
	for i in range(visible_quests):
		var entry = _quest_entries[i]
		
		# Quest title
		draw_string(font, Vector2(padding, y_pos + title_size), entry["title"], HORIZONTAL_ALIGNMENT_LEFT, int(panel_width - padding * 2), title_size, _title_color)
		y_pos += line_height
		
		# Objectives
		for obj in entry["objectives"]:
			var obj_text: String = obj["text"]
			var current: int = obj["current"]
			var target: int = obj["target"]
			var done: bool = obj["done"]
			
			var prefix = "[x] " if done else "[ ] "
			var progress = ""
			if target > 1:
				progress = " (%d/%d)" % [current, target]
			
			var display_text = prefix + obj_text + progress
			var color = _done_color if done else _objective_color
			
			draw_string(font, Vector2(padding + 4, y_pos + obj_size), display_text, HORIZONTAL_ALIGNMENT_LEFT, int(panel_width - padding * 2 - 4), obj_size, color)
			y_pos += obj_line_height
		
		if i < visible_quests - 1:
			y_pos += quest_gap
	
	# Update control size to match content
	custom_minimum_size.y = total_height
