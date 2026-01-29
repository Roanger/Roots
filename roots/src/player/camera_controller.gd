extends Node3D
## Camera Controller - First-person camera only
## Full mouse look with pitch (up/down) and yaw (left/right)

@export var camera: Camera3D = null

# Camera settings
@export var first_person_height: float = 1.7
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

# State
var pitch: float = 0.0  # Vertical rotation (up/down)
var yaw: float = 0.0    # Horizontal rotation (left/right)

func _ready() -> void:
	if not camera:
		camera = get_node_or_null("Camera3D")
	
	# Ensure CameraPivot is at origin relative to player
	position = Vector3.ZERO
	
	# Initialize camera position
	_update_camera()

func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseMotion:
		# Handle mouse look
		# Y movement controls pitch (up/down)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		
		# X movement controls yaw (left/right)
		yaw -= event.relative.x * mouse_sensitivity
		
		# Apply rotations immediately
		_update_camera()

func _update_camera() -> void:
	if not camera:
		return
	
	# Ensure CameraPivot is at origin relative to player (no position offset)
	# This ensures camera height is relative to player, not terrain
	position = Vector3.ZERO
	
	# Set camera position at head height
	camera.position = Vector3(0, first_person_height, 0)
	
	# Apply yaw rotation to CameraPivot (this node)
	# This rotates the entire camera pivot left/right
	rotation.y = yaw
	
	# Apply pitch rotation directly to camera
	# This rotates the camera up/down
	camera.rotation.x = pitch
	camera.rotation.y = 0.0
	camera.rotation.z = 0.0

func get_look_direction() -> Vector3:
	if not camera:
		return -global_transform.basis.z
	
	# Get the camera's forward direction in world space
	var cam_basis = camera.global_transform.basis
	return -cam_basis.z

func get_pitch() -> float:
	return rad_to_deg(pitch)

func set_mouse_sensitivity(sensitivity: float) -> void:
	mouse_sensitivity = sensitivity
