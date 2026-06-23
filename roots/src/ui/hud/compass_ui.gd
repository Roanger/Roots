extends Control
class_name CompassUI
## Compass UI - Horizontal compass bar at top-center of screen
## Shows cardinal directions (N, S, E, W), intercardinals (NE, SE, SW, NW),
## and degree tick marks that scroll based on camera yaw.

# Visual settings
@export var compass_width: float = 400.0
@export var compass_height: float = 32.0
@export var tick_color: Color = Color(0.7, 0.85, 0.9, 0.7)
@export var cardinal_color: Color = Color(0.8, 0.95, 1.0, 1.0)
@export var intercardinal_color: Color = Color(0.6, 0.75, 0.85, 0.85)
@export var degree_color: Color = Color(0.5, 0.65, 0.75, 0.6)
@export var north_color: Color = Color(1.0, 0.4, 0.3, 1.0)
@export var bg_color: Color = Color(0.0, 0.0, 0.0, 0.35)
@export var center_tick_color: Color = Color(1.0, 1.0, 1.0, 0.9)

var camera: Camera3D = null
var current_yaw: float = 0.0
var _waypoints: Array = []
var _player: Node3D = null

# Direction markers: degree -> label
var direction_labels: Dictionary = {
	0: "N",
	45: "NE",
	90: "E",
	135: "SE",
	180: "S",
	225: "SW",
	270: "W",
	315: "NW",
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(compass_width, compass_height + 4)

func set_camera(cam: Camera3D) -> void:
	camera = cam

func set_player(p: Node3D) -> void:
	_player = p

func set_waypoints(waypoints: Array) -> void:
	_waypoints = waypoints

func clear_waypoints() -> void:
	_waypoints.clear()

func _process(_delta: float) -> void:
	if camera and is_instance_valid(camera):
		# Get camera yaw (rotation around Y axis) in degrees
		var forward = -camera.global_transform.basis.z
		var yaw_rad = atan2(forward.x, -forward.z)
		current_yaw = fmod(rad_to_deg(yaw_rad) + 360.0, 360.0)
	queue_redraw()

func _draw() -> void:
	var center_x = size.x / 2.0
	var top_y = 0.0
	var bar_left = center_x - compass_width / 2.0
	var bar_right = center_x + compass_width / 2.0
	
	# Background bar
	var bg_rect = Rect2(bar_left, top_y, compass_width, compass_height)
	draw_rect(bg_rect, bg_color)
	
	# Subtle top/bottom border lines
	var border_color = Color(0.5, 0.7, 0.8, 0.3)
	draw_line(Vector2(bar_left, top_y), Vector2(bar_right, top_y), border_color, 1.0)
	draw_line(Vector2(bar_left, top_y + compass_height), Vector2(bar_right, top_y + compass_height), border_color, 1.0)
	
	# Pixels per degree — how many pixels one degree of rotation spans
	var ppd = compass_width / 120.0  # Show ~120 degrees of view
	
	# Draw ticks and labels for visible degree range
	var half_range = 60.0  # degrees visible on each side of center
	var start_deg = current_yaw - half_range
	var end_deg = current_yaw + half_range
	
	# Cardinal/intercardinal font
	var font = ThemeDB.fallback_font
	var cardinal_size = 16
	var intercardinal_size = 13
	var degree_size = 10
	
	# Iterate through every degree in the visible range
	var deg = ceil(start_deg)
	while deg <= end_deg:
		var norm_deg = fmod(deg + 360.0, 360.0)
		var offset_from_center = (deg - current_yaw) * ppd
		var x_pos = center_x + offset_from_center
		
		# Clip to compass bounds
		if x_pos >= bar_left and x_pos <= bar_right:
			var int_deg = int(round(norm_deg)) % 360
			
			if direction_labels.has(int_deg):
				# Cardinal or intercardinal direction
				var label_text = direction_labels[int_deg]
				var is_cardinal = label_text.length() == 1
				var font_size = cardinal_size if is_cardinal else intercardinal_size
				var color = cardinal_color if is_cardinal else intercardinal_color
				
				# North gets special color
				if int_deg == 0:
					color = north_color
				
				# Tall tick
				var tick_h = compass_height * 0.45
				draw_line(
					Vector2(x_pos, top_y + 2),
					Vector2(x_pos, top_y + 2 + tick_h),
					color, 1.5
				)
				
				# Label below tick
				var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
				draw_string(
					font,
					Vector2(x_pos - text_size.x / 2.0, top_y + compass_height - 4),
					label_text,
					HORIZONTAL_ALIGNMENT_CENTER,
					-1,
					font_size,
					color
				)
			elif int_deg % 15 == 0:
				# Major tick every 15 degrees — show degree number
				var tick_h = compass_height * 0.3
				draw_line(
					Vector2(x_pos, top_y + 4),
					Vector2(x_pos, top_y + 4 + tick_h),
					tick_color, 1.0
				)
				
				# Degree number
				var deg_text = str(int_deg)
				var text_size = font.get_string_size(deg_text, HORIZONTAL_ALIGNMENT_CENTER, -1, degree_size)
				draw_string(
					font,
					Vector2(x_pos - text_size.x / 2.0, top_y + compass_height - 6),
					deg_text,
					HORIZONTAL_ALIGNMENT_CENTER,
					-1,
					degree_size,
					degree_color
				)
			elif int_deg % 5 == 0:
				# Minor tick every 5 degrees
				var tick_h = compass_height * 0.2
				draw_line(
					Vector2(x_pos, top_y + 6),
					Vector2(x_pos, top_y + 6 + tick_h),
					Color(tick_color, 0.4), 1.0
				)
		
		deg += 1.0
	
	# Center indicator (small triangle/tick at the very center)
	var tri_size = 5.0
	var tri_top = top_y - 1
	draw_line(
		Vector2(center_x, tri_top + tri_size + 2),
		Vector2(center_x, tri_top + tri_size + compass_height * 0.3),
		center_tick_color, 2.0
	)
	# Small downward triangle
	var tri_points = PackedVector2Array([
		Vector2(center_x, tri_top + tri_size + 2),
		Vector2(center_x - tri_size, tri_top),
		Vector2(center_x + tri_size, tri_top),
	])
	draw_colored_polygon(tri_points, center_tick_color)

	# Quest waypoint markers
	if _waypoints.is_empty() or not _player or not is_instance_valid(_player):
		return
	var ppd_wp = compass_width / 120.0
	var player_pos = _player.global_position
	var font_wp = ThemeDB.fallback_font
	var wp_font_size = 10
	for wp in _waypoints:
		var target_pos: Vector3 = wp.get("position", Vector3.ZERO)
		if target_pos == Vector3.ZERO:
			continue
		var dx = target_pos.x - player_pos.x
		var dz = target_pos.z - player_pos.z
		if dx == 0.0 and dz == 0.0:
			continue
		var bearing = fmod(rad_to_deg(atan2(dx, -dz)) + 360.0, 360.0)
		var rel_angle = bearing - current_yaw
		while rel_angle > 180.0: rel_angle -= 360.0
		while rel_angle < -180.0: rel_angle += 360.0
		var wp_color: Color = wp.get("color", Color(1.0, 0.8, 0.2, 1.0))
		var wp_label: String = wp.get("label", "")
		if abs(rel_angle) <= 60.0:
			var x = center_x + rel_angle * ppd_wp
			var marker_y = top_y + compass_height + 3.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, marker_y),
				Vector2(x - 5, marker_y + 7),
				Vector2(x + 5, marker_y + 7),
			]), wp_color)
			if not wp_label.is_empty():
				var short_label = wp_label.substr(0, min(wp_label.length(), 12))
				var text_size = font_wp.get_string_size(short_label, HORIZONTAL_ALIGNMENT_CENTER, -1, wp_font_size)
				draw_string(font_wp, Vector2(x - text_size.x / 2.0, marker_y + 20), short_label, HORIZONTAL_ALIGNMENT_CENTER, -1, wp_font_size, wp_color)
		else:
			var edge_x = bar_right if rel_angle > 0 else bar_left
			var arrow_dir = 1.0 if rel_angle > 0 else -1.0
			var arrow_y = top_y + compass_height / 2.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(edge_x, arrow_y),
				Vector2(edge_x - arrow_dir * 8, arrow_y - 5),
				Vector2(edge_x - arrow_dir * 8, arrow_y + 5),
			]), wp_color)
