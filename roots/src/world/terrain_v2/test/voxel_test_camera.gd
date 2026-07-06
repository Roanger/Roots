extends Camera3D

const MOVE_SPEED: float = 20.0
const MOUSE_SENSITIVITY: float = 0.003
const DIG_RADIUS: float = 2.5

@onready var _terrain: VoxelLodTerrain = get_node("../VoxelLodTerrain")


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		rotation.x = clampf(rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dig(VoxelTool.MODE_REMOVE)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dig(VoxelTool.MODE_ADD)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		dir -= Vector3.UP
	var speed := MOVE_SPEED * (3.0 if Input.is_key_pressed(KEY_CTRL) else 1.0)
	global_position += dir.normalized() * speed * delta if dir != Vector3.ZERO else Vector3.ZERO


func _dig(mode: int) -> void:
	var tool := _terrain.get_voxel_tool()
	var hit := tool.raycast(global_position, -transform.basis.z, 200.0)
	if hit == null:
		return
	tool.mode = mode
	tool.do_sphere(Vector3(hit.position), DIG_RADIUS)
