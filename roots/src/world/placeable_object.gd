extends StaticBody3D
class_name PlaceableObject
## A player-placed object in the world (fence, gate, decoration).
## Has collision to block animals/NPCs and can be picked up by the player.

@export var item_id: String = ""  # The item this was placed from
@export var object_name: String = "Fence"
@export var is_gate: bool = false  # Gates can be opened/closed
@export var gate_open: bool = false

var _model_node: Node3D = null
var _collision_shape: CollisionShape3D = null
var _gate_interact_shape: CollisionShape3D = null  # Small shape on hinge post for raycast when gate is open
var _gate_pivot: Node3D = null  # Pivot node for gate hinge rotation

func setup(p_item_id: String, p_name: String, model_path: String, model_scale: float, collision_size: Vector3, p_is_gate: bool = false) -> void:
	item_id = p_item_id
	object_name = p_name
	is_gate = p_is_gate
	
	# Load and add the 3D model (OBJ files import as ArrayMesh, not PackedScene)
	if model_path != "":
		var res = load(model_path)
		if res:
			if res is PackedScene:
				_model_node = res.instantiate() as Node3D
				if _model_node:
					# FBX models may have baked-in position offsets and rotation — reset them
					_model_node.position = Vector3.ZERO
					_model_node.rotation = Vector3.ZERO
					for child_node in _model_node.get_children():
						if child_node is Node3D:
							child_node.position = Vector3.ZERO
							child_node.rotation = Vector3(-PI / 2.0, 0, 0)
					_model_node.scale = Vector3.ONE * model_scale
			elif res is Mesh:
				_model_node = MeshInstance3D.new()
				(_model_node as MeshInstance3D).mesh = res
				_model_node.scale = Vector3.ONE * model_scale
			
			if _model_node:
				if p_is_gate:
					# For gates: pivot at the hinge post (left edge of mesh)
					# The model is added directly to the scene, and a separate
					# pivot node is positioned at the hinge edge. The model is
					# re-parented under the pivot with compensating offset.
					_gate_pivot = Node3D.new()
					_gate_pivot.name = "GatePivot"
					add_child(_gate_pivot)
					# The big hinge post is at the right edge (max X) of the mesh
					# We position the model so the right edge is at the pivot's origin
					if _model_node is MeshInstance3D:
						var aabb = (_model_node as MeshInstance3D).mesh.get_aabb()
						# max_x = left edge + width; shift mesh left so right edge = 0
						var max_x = aabb.position.x + aabb.size.x
						_model_node.position.x = -max_x * model_scale
						# Also center the Z axis on the mesh
						var center_z = (aabb.position.z + aabb.size.z * 0.5)
						_model_node.position.z = -center_z * model_scale
					_gate_pivot.add_child(_model_node)
				else:
					add_child(_model_node)
	
	# Fallback placeholder if model didn't load
	if not _model_node:
		_build_placeholder(collision_size)
	
	# Collision shape for blocking movement
	_collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = collision_size * model_scale
	_collision_shape.shape = shape
	_collision_shape.position.y = collision_size.y * model_scale * 0.5
	add_child(_collision_shape)
	
	# Set collision layers: layer 2 (world objects), mask 0
	collision_layer = 2
	collision_mask = 0
	
	# For gates: add a small always-active collision shape on the hinge post
	# so the player can raycast-hit it to close the gate
	if p_is_gate:
		_gate_interact_shape = CollisionShape3D.new()
		var post_shape = BoxShape3D.new()
		post_shape.size = Vector3(0.3, 1.0, 0.3) * model_scale
		_gate_interact_shape.shape = post_shape
		_gate_interact_shape.position.y = collision_size.y * model_scale * 0.5
		add_child(_gate_interact_shape)
	
	# Add to group for save/load and pasture detection
	add_to_group("placeables")
	if is_gate:
		add_to_group("gates")
	else:
		add_to_group("fences")

func _build_placeholder(collision_size: Vector3) -> void:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = collision_size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.15) if not is_gate else Color(0.45, 0.3, 0.12)
	mesh_inst.material_override = mat
	mesh_inst.position.y = collision_size.y * 0.5
	add_child(mesh_inst)

func get_target_type() -> int:
	return ToolAffinity.TargetType.BUILDING

func on_hit(_player: Node3D, _tool_type: String, _power: float = 0.0) -> void:
	# Pick up the fence/gate — return item to player inventory
	var inv = _player.get_inventory() if _player.has_method("get_inventory") else null
	if inv and inv.has_method("add_item"):
		inv.add_item(item_id, 1)
		print("[Placeable] Picked up %s" % object_name)
	queue_free()

func on_interact(_player: Node3D) -> void:
	if is_gate:
		_toggle_gate(_player)

func get_interaction_text() -> String:
	if is_gate:
		return "Open" if not gate_open else "Close"
	return "Pick up %s" % object_name

func _toggle_gate(player: Node3D = null) -> void:
	gate_open = not gate_open
	# Disable the main blocking shape when open (animals can pass through)
	# The small hinge post shape stays active for raycast interaction
	if _collision_shape:
		_collision_shape.disabled = gate_open
	# Rotate gate open/closed visually via the pivot node (hinges from edge)
	var pivot = _gate_pivot if _gate_pivot else _model_node
	if pivot:
		var target_rot = 0.0
		if gate_open and player:
			# Determine which side the player is on relative to the gate's forward (Z) axis
			# Use the gate's local Z direction to check if player is in front or behind
			var to_player = player.global_position - global_position
			var gate_forward = global_basis.z
			var dot = to_player.dot(gate_forward)
			# If dot > 0, player is on the +Z side, swing to -Z (negative rotation)
			# If dot < 0, player is on the -Z side, swing to +Z (positive rotation)
			target_rot = -PI / 2.0 if dot > 0 else PI / 2.0
		var tween = create_tween()
		tween.tween_property(pivot, "rotation:y", target_rot, 0.3)

func serialize() -> Dictionary:
	return {
		"item_id": item_id,
		"object_name": object_name,
		"is_gate": is_gate,
		"gate_open": gate_open,
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"rotation_y": rotation.y,
	}

static func deserialize(data: Dictionary) -> Dictionary:
	return data
