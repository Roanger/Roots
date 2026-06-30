extends Node3D
## Camera Controller - First-person camera with smoothing, zoom, and collision clipping

@export var camera: Camera3D = null

@export var first_person_height: float = 1.7
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0
@export var rotation_smoothing: float = 30.0
@export var height_smoothing: float = 12.0
@export var fov_smoothing: float = 8.0
@export var min_zoom_fov: float = 30.0
@export var zoom_step: float = 5.0
@export var collision_margin: float = 0.1
@export var camera_forward_offset: float = 0.4

var _target_pitch: float = 0.0
var _target_yaw: float = 0.0
var _target_fov: float = 75.0
var _base_fov: float = 75.0
var _current_pitch: float = 0.0
var _current_yaw: float = 0.0
var _current_height: float = 1.7
var _current_fov: float = 75.0
var _invert_y: bool = false
var _sensitivity: float = 0.002
var _collision_ray: RayCast3D = null
var height_target: Node3D = null

func _ready() -> void:
	if not camera:
		camera = get_node_or_null("Camera3D")
	position = Vector3.ZERO
	_collision_ray = get_node_or_null("CameraCollisionRay")
	if _collision_ray:
		var player_body = get_parent()
		if player_body is PhysicsBody3D:
			_collision_ray.add_exception(player_body)
	_current_yaw = _target_yaw
	_current_pitch = _target_pitch
	_current_height = first_person_height
	_current_fov = _target_fov
	_apply_camera()

func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var y_delta = event.relative.y * _sensitivity
		if _invert_y:
			y_delta = -y_delta
		_target_pitch -= y_delta
		_target_pitch = clamp(_target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		_target_yaw -= event.relative.x * _sensitivity
	elif event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_fov = maxf(_target_fov - zoom_step, min_zoom_fov)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_fov = minf(_target_fov + zoom_step, _base_fov)

func _process(delta: float) -> void:
	var rot_t := 1.0 - exp(-rotation_smoothing * delta)
	_current_yaw = lerp_angle(_current_yaw, _target_yaw, rot_t)
	_current_pitch = lerp(_current_pitch, _target_pitch, rot_t)

	var target_height := first_person_height
	if height_target and is_instance_valid(height_target):
		target_height = to_local(height_target.global_position).y
	var safe_height := target_height
	if _collision_ray and _collision_ray.is_colliding():
		var hit_pos = _collision_ray.get_collision_point()
		var hit_dist = to_local(hit_pos).y
		safe_height = minf(target_height, hit_dist - collision_margin)
	var h_t := 1.0 - exp(-height_smoothing * delta)
	_current_height = lerp(_current_height, safe_height, h_t)

	var f_t := 1.0 - exp(-fov_smoothing * delta)
	_current_fov = lerp(_current_fov, _target_fov, f_t)

	_apply_camera()

func _apply_camera() -> void:
	if not camera:
		return
	position = Vector3.ZERO
	camera.position = Vector3(0, _current_height, -camera_forward_offset)
	rotation.y = _current_yaw
	camera.rotation.x = _current_pitch
	camera.rotation.y = 0.0
	camera.rotation.z = 0.0
	camera.fov = _current_fov

func set_base_fov(fov: float) -> void:
	_base_fov = fov
	_target_fov = clampf(_target_fov, min_zoom_fov, _base_fov)

func set_mouse_sensitivity(sensitivity: float) -> void:
	_sensitivity = sensitivity

func set_invert_y(invert: bool) -> void:
	_invert_y = invert

func get_look_direction() -> Vector3:
	if not camera:
		return -global_transform.basis.z
	return -camera.global_transform.basis.z

func get_pitch() -> float:
	return rad_to_deg(_current_pitch)

func set_height_target(target: Node3D) -> void:
	height_target = target
