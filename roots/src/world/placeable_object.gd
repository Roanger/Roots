extends StaticBody3D
class_name PlaceableObject
## A player-placed object in the world (fence, gate, decoration).
## Has collision to block animals/NPCs and can be picked up by the player.

@export var item_id: String = ""  # The item this was placed from
@export var object_name: String = "Fence"
@export var is_gate: bool = false  # Gates can be opened/closed
@export var gate_open: bool = false
@export var damage_on_contact: float = 0.0  # Damage per second to enemies touching this (for spikes/traps)

var _model_node: Node3D = null
var _collision_shape: CollisionShape3D = null
var _gate_interact_shape: CollisionShape3D = null  # Small shape on hinge post for raycast when gate is open
var _gate_pivot: Node3D = null  # Pivot node for gate hinge rotation
var _campfire_light: OmniLight3D = null
var _damage_area: Area3D = null

func setup(p_item_id: String, p_name: String, model_path: String, model_scale: float, collision_size: Vector3, p_is_gate: bool = false) -> void:
	item_id = p_item_id
	object_name = p_name
	is_gate = p_is_gate
	
	var is_gltf := model_path.to_lower().ends_with(".gltf") or model_path.to_lower().ends_with(".glb")
	
	# Load and add the 3D model (OBJ files import as ArrayMesh, not PackedScene)
	if model_path != "":
		var res = load(model_path)
		if res:
			if res is PackedScene:
				_model_node = res.instantiate() as Node3D
				if _model_node:
					_model_node.position = Vector3.ZERO
					_model_node.rotation = Vector3.ZERO
					# glTF files are already Y-up; only apply the legacy FBX/.blend rotation fix for other formats
					if not is_gltf:
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
					# For gates: pivot at the hinge post (right edge of mesh)
					_gate_pivot = Node3D.new()
					_gate_pivot.name = "GatePivot"
					add_child(_gate_pivot)
					var mesh_inst := _find_first_mesh_instance(_model_node)
					if mesh_inst and mesh_inst.mesh:
						var aabb = mesh_inst.mesh.get_aabb()
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
	
	# Campfire light
	if item_id == "campfire":
		_campfire_light = OmniLight3D.new()
		_campfire_light.omni_range = 8.0
		_campfire_light.light_color = Color(1.0, 0.55, 0.15)
		_campfire_light.light_energy = 2.5
		_campfire_light.omni_attenuation = 0.6
		_campfire_light.shadow_enabled = false
		_campfire_light.position.y = collision_size.y * model_scale * 0.5 + 0.2
		add_child(_campfire_light)
	
	# Damage area for traps (spikes, barricades)
	if damage_on_contact > 0.0:
		_damage_area = Area3D.new()
		var area_shape = CollisionShape3D.new()
		var area_box = BoxShape3D.new()
		area_box.size = collision_size * model_scale
		area_shape.shape = area_box
		area_shape.position.y = collision_size.y * model_scale * 0.5
		_damage_area.add_child(area_shape)
		_damage_area.collision_layer = 0
		_damage_area.collision_mask = 4  # Enemy layer
		_damage_area.body_entered.connect(_on_damage_area_body_entered)
		_damage_area.body_exited.connect(_on_damage_area_body_exited)
		add_child(_damage_area)
	
	# Add to group for save/load and pasture detection
	add_to_group("placeables")
	if is_gate:
		add_to_group("gates")
	else:
		add_to_group("fences")

func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found:
			return found
	return null

var _enemies_in_range: Array[Node3D] = []

func _process(delta: float) -> void:
	if damage_on_contact <= 0.0 or _enemies_in_range.is_empty():
		return
	for enemy in _enemies_in_range:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage_on_contact * delta)

func _on_damage_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and body not in _enemies_in_range:
		_enemies_in_range.append(body)

func _on_damage_area_body_exited(body: Node3D) -> void:
	_enemies_in_range.erase(body)

func _build_placeholder(collision_size: Vector3) -> void:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = collision_size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	if item_id == "campfire":
		mat.albedo_color = Color(0.9, 0.3, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.05)
		mat.emission_energy_multiplier = 1.5
	else:
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
