extends Control
class_name BuffDisplayUI
## Displays active buff icons with remaining time near the health/stamina bars.
## Each buff is a small rounded rectangle with an icon symbol, name, and countdown timer.

@export var icon_size: float = 32.0
@export var icon_spacing: float = 6.0
@export var bg_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var border_color: Color = Color(0.5, 0.7, 0.8, 0.3)

# Buff type -> display config: { symbol, color }
const BUFF_DISPLAY: Dictionary = {
	"well_fed": {"symbol": "♥", "color": Color(0.4, 1.0, 0.4), "label": "Well Fed"},
	"speed": {"symbol": "»", "color": Color(0.4, 0.8, 1.0), "label": "Speed"},
	"strength": {"symbol": "⚔", "color": Color(1.0, 0.5, 0.3), "label": "Strength"},
	"heal": {"symbol": "+", "color": Color(1.0, 0.3, 0.3), "label": "Regen"},
	"stamina": {"symbol": "★", "color": Color(1.0, 0.85, 0.1), "label": "Stamina"},
	"antidote": {"symbol": "✦", "color": Color(0.6, 1.0, 0.6), "label": "Antidote"},
}

var _player: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_player(p_player: Node) -> void:
	_player = p_player

func _process(_delta: float) -> void:
	if _player and _player.get("active_buffs"):
		queue_redraw()

func _draw() -> void:
	if not _player:
		return
	var active_buffs: Dictionary = _player.get("active_buffs")
	if not active_buffs or active_buffs.is_empty():
		return

	var font = ThemeDB.fallback_font
	var x_offset: float = 0.0
	var buff_height: float = icon_size + 4.0
	var buff_keys = active_buffs.keys()

	for buff_type in buff_keys:
		var buff_info: Dictionary = active_buffs[buff_type]
		var remaining: float = buff_info.get("remaining", 0.0)
		if remaining <= 0:
			continue

		var display = BUFF_DISPLAY.get(buff_type, {"symbol": "?", "color": Color.WHITE, "label": buff_type})
		var buff_color: Color = display["color"]
		var symbol: String = display["symbol"]
		var label: String = display["label"]

		# Calculate width based on label + timer text
		var timer_str = _format_time(remaining)
		var label_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var timer_size = font.get_string_size(timer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var text_width = max(label_size.x, timer_size.x)
		var buff_width: float = icon_size + 4.0 + text_width + 8.0

		# Background
		var bg_rect = Rect2(x_offset, 0, buff_width, buff_height)
		draw_rect(bg_rect, bg_color)
		draw_rect(bg_rect, border_color, false, 1.0)

		# Colored icon square
		var icon_rect = Rect2(x_offset + 2, 2, icon_size, icon_size)
		draw_rect(icon_rect, Color(buff_color.r, buff_color.g, buff_color.b, 0.25))
		draw_rect(icon_rect, buff_color, false, 1.5)

		# Symbol centered in icon
		var sym_size = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		var sym_x = x_offset + 2 + (icon_size - sym_size.x) * 0.5
		var sym_y = 2 + (icon_size + sym_size.y) * 0.5 - 4.0
		draw_string(font, Vector2(sym_x, sym_y), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, buff_color)

		# Label text (top-right of icon)
		var text_x = x_offset + icon_size + 6.0
		draw_string(font, Vector2(text_x, 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, buff_color)

		# Timer text (bottom-right of icon)
		var timer_color = buff_color
		if remaining < 10.0:
			# Flash when about to expire
			timer_color = Color(1.0, 0.4, 0.4) if fmod(remaining, 1.0) < 0.5 else buff_color
		draw_string(font, Vector2(text_x, 30.0), timer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, timer_color)

		x_offset += buff_width + icon_spacing

func _format_time(seconds: float) -> String:
	if seconds >= 60.0:
		var total_secs: int = int(seconds)
		@warning_ignore("integer_division")
		var mins: int = total_secs / 60
		var secs: int = total_secs % 60
		return "%dm %02ds" % [mins, secs]
	return "%.0fs" % seconds
