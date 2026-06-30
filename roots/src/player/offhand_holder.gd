extends Node3D
class_name OffhandHolder
## Displays the offhand item (e.g. torch) in the left hand.
## Attach as a child of the Camera3D node, mirrored to the left side.

var current_item_id: String = ""
var current_model: Node3D = null
var _model_cache: Dictionary = {}

@export var hold_position: Vector3 = Vector3(-0.25, -0.2, -0.4)
@export var hold_rotation: Vector3 = Vector3(-10, 20, 0)
@export var tool_scale: float = 0.3

var _torch_light: OmniLight3D = null

func _ready() -> void:
	position = hold_position
	rotation_degrees = hold_rotation
	_setup_torch_light()

func _setup_torch_light() -> void:
	_torch_light = OmniLight3D.new()
	_torch_light.omni_range = 8.0
	_torch_light.light_color = Color(1.0, 0.6, 0.2)
	_torch_light.light_energy = 2.0
	_torch_light.omni_attenuation = 0.5
	_torch_light.shadow_enabled = false
	_torch_light.position = Vector3(0.3, -0.1, -0.6)
	_torch_light.visible = false
	add_child(_torch_light)

func equip_offhand(item_data: ItemData) -> void:
	if not item_data:
		unequip_offhand()
		return

	var model_path = item_data.world_model_path
	if model_path.is_empty():
		unequip_offhand()
		return

	if current_item_id == item_data.item_id and current_model:
		return

	_clear_model()

	var model_node = _load_model(model_path)
	if not model_node:
		push_warning("OffhandHolder: Failed to load model: " + model_path)
		return

	current_model = model_node
	current_item_id = item_data.item_id
	add_child(current_model)
	current_model.scale = Vector3.ONE * tool_scale
	position = hold_position
	rotation_degrees = hold_rotation

	_update_torch_light()

func unequip_offhand() -> void:
	_clear_model()
	current_item_id = ""
	_update_torch_light()

func _update_torch_light() -> void:
	if _torch_light:
		_torch_light.visible = (current_item_id == "torch")

func _clear_model() -> void:
	if current_model and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null

func _load_model(path: String) -> Node3D:
	if _model_cache.has(path):
		var scene = _model_cache[path] as PackedScene
		if scene:
			return scene.instantiate() as Node3D

	var resource = load(path)
	if not resource:
		return null

	if resource is PackedScene:
		_model_cache[path] = resource
		return (resource as PackedScene).instantiate() as Node3D

	return null
