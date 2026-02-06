extends Node3D
class_name ToolHolder
## Displays the currently equipped tool/weapon as a 3D model in first-person view.
## Attach as a child of the Camera3D node.

signal tool_changed(tool_id: String)

# Position offset from camera for the tool (lower-right of screen)
@export var hold_position: Vector3 = Vector3(0.25, -0.2, -0.4)
@export var hold_rotation: Vector3 = Vector3(-10, -20, 0)  # degrees
@export var tool_scale: float = 0.3
@export var bob_amount: float = 0.02
@export var bob_speed: float = 3.0
@export var sway_amount: float = 0.003
@export var sway_speed: float = 5.0

var current_tool_id: String = ""
var current_model: Node3D = null
var _model_cache: Dictionary = {}  # model_path -> PackedScene
var _bob_time: float = 0.0
var _target_position: Vector3 = Vector3.ZERO
var _is_using: bool = false
var _use_timer: float = 0.0
var _use_duration: float = 0.4

# Swing animation parameters
var _swing_end_rot: Vector3 = Vector3(-45, 0, 0)

func _ready() -> void:
	position = hold_position
	rotation_degrees = hold_rotation
	_target_position = hold_position

func _process(delta: float) -> void:
	# Tool bob when moving
	var player = get_parent().get_parent().get_parent() if get_parent() else null
	var is_moving = false
	if player and player is CharacterBody3D:
		var hvel = Vector2(player.velocity.x, player.velocity.z)
		is_moving = hvel.length() > 0.5
	
	if is_moving and not _is_using:
		_bob_time += delta * bob_speed
		var bob_offset = Vector3(
			sin(_bob_time * 0.5) * bob_amount * 0.5,
			sin(_bob_time) * bob_amount,
			0
		)
		position = position.lerp(hold_position + bob_offset, delta * 10.0)
	elif not _is_using:
		_bob_time = 0.0
		position = position.lerp(hold_position, delta * 8.0)
	
	# Swing animation
	if _is_using:
		_use_timer += delta
		var t = clampf(_use_timer / _use_duration, 0.0, 1.0)
		if t < 0.5:
			# Swing forward
			var swing_t = t * 2.0
			rotation_degrees = hold_rotation + _swing_end_rot * swing_t
		else:
			# Return
			var return_t = (t - 0.5) * 2.0
			rotation_degrees = hold_rotation + _swing_end_rot * (1.0 - return_t)
		
		if t >= 1.0:
			_is_using = false
			_use_timer = 0.0
			rotation_degrees = hold_rotation

func equip_tool(item_data: ItemData) -> void:
	if not item_data:
		unequip_tool()
		return
	
	var model_path = item_data.world_model_path
	if model_path.is_empty():
		unequip_tool()
		return
	
	# Don't re-equip the same tool
	if current_tool_id == item_data.item_id and current_model:
		return
	
	# Remove old model
	_clear_model()
	
	# Load and instance the 3D model
	var model_node = _load_model(model_path)
	if not model_node:
		push_warning("ToolHolder: Failed to load model: " + model_path)
		return
	
	current_model = model_node
	current_tool_id = item_data.item_id
	add_child(current_model)
	
	# Scale the model
	current_model.scale = Vector3.ONE * tool_scale
	
	# Reset position
	position = hold_position
	rotation_degrees = hold_rotation
	
	tool_changed.emit(current_tool_id)

func unequip_tool() -> void:
	_clear_model()
	current_tool_id = ""
	tool_changed.emit("")

func play_use_animation() -> void:
	_is_using = true
	_use_timer = 0.0

func _clear_model() -> void:
	if current_model and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null

func _load_model(path: String) -> Node3D:
	# Check cache first
	if _model_cache.has(path):
		var scene = _model_cache[path] as PackedScene
		if scene:
			return scene.instantiate() as Node3D
	
	# Load the resource
	var resource = load(path)
	if not resource:
		return null
	
	if resource is PackedScene:
		_model_cache[path] = resource
		return (resource as PackedScene).instantiate() as Node3D
	
	return null
