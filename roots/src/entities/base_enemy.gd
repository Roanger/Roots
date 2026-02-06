extends CharacterBody3D
class_name BaseEnemy
## Base class for all enemies. Handles health, AI states, combat, loot drops.
## Enemies wander, chase the player when close, attack in melee range,
## and drop loot on death.

const WorldItemScene = preload("res://src/items/world_item.tscn")

enum AIState { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }

@export var enemy_name: String = "Slime"
@export var max_health: float = 20.0
@export var move_speed: float = 2.0
@export var chase_speed: float = 3.5
@export var attack_damage: float = 5.0
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2
@export var detection_range: float = 10.0
@export var lose_interest_range: float = 16.0
@export var wander_radius: float = 6.0
@export var xp_reward: float = 15.0
@export var xp_skill: String = "combat"

# Loot table: array of { "item_id": String, "min_amount": int, "max_amount": int, "chance": float }
@export var loot_table: Array = []

# Visuals
@export var body_color: Color = Color(0.3, 0.7, 0.2)
@export var model_path: String = ""  # Path to .glb/.fbx model; empty = placeholder capsule
@export var model_scale: float = 1.0

var current_health: float = 20.0
var ai_state: AIState = AIState.IDLE
var _target: Node3D = null
var _wander_target: Vector3 = Vector3.ZERO
var _attack_timer: float = 0.0
var _idle_timer: float = 0.0
var _hurt_timer: float = 0.0
var _death_timer: float = 0.0
var _spawn_position: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mesh: MeshInstance3D = null
var _model_node: Node3D = null
var _original_color: Color = Color.WHITE
var _gravity: float = 20.0
var _all_mesh_materials: Array = []  # Cached for hurt flash
var _chunk_manager: Node = null

@onready var event_bus: Node = get_node_or_null("/root/EventBus")

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	current_health = max_health
	_spawn_position = global_position
	_rng.randomize()
	_idle_timer = _rng.randf_range(1.0, 3.0)
	
	# Find chunk_manager for terrain height queries
	var scene = get_tree().current_scene
	if scene:
		_chunk_manager = scene.get_node_or_null("ChunkManager")
		if not _chunk_manager and scene.has_method("get_chunk_manager"):
			_chunk_manager = scene.get_chunk_manager()
		if not _chunk_manager:
			for child in scene.get_children():
				if child.has_method("get_terrain_height"):
					_chunk_manager = child
					break
	# Build visual
	_build_visual()

func _build_visual() -> void:
	if model_path != "":
		_build_model_visual()
	else:
		_build_placeholder_visual()
	
	# Collision shape
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35 * model_scale
	shape.height = 1.2 * model_scale
	col.shape = shape
	col.position.y = 0.6 * model_scale
	add_child(col)
	
	# Name label
	var label = Label3D.new()
	label.text = enemy_name
	label.font_size = 24
	label.position.y = 1.8 * model_scale
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.3, 0.3)
	add_child(label)

func _build_model_visual() -> void:
	var scene = load(model_path)
	if not scene:
		push_warning("BaseEnemy: Failed to load model '%s', using placeholder" % model_path)
		_build_placeholder_visual()
		return
	
	_model_node = scene.instantiate() as Node3D
	if not _model_node:
		_build_placeholder_visual()
		return
	
	_model_node.scale = Vector3.ONE * model_scale
	add_child(_model_node)
	
	# Cache all mesh materials for hurt flash
	_cache_mesh_materials(_model_node)
	_original_color = body_color

func _build_placeholder_visual() -> void:
	# Capsule body
	_mesh = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	_mesh.mesh = capsule
	var mat = StandardMaterial3D.new()
	mat.albedo_color = body_color
	_mesh.material_override = mat
	_mesh.position.y = 0.6
	_original_color = body_color
	add_child(_mesh)
	
	# Eyes (two small spheres)
	for i in 2:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.08
		eye_mesh.height = 0.16
		eye.mesh = eye_mesh
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color.WHITE
		eye.material_override = eye_mat
		eye.position = Vector3(-0.15 + i * 0.3, 0.9, -0.25)
		add_child(eye)

func _cache_mesh_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		# Create a unique override material so we can tint it on hit
		if mi.mesh:
			for surf_idx in mi.mesh.get_surface_count():
				var orig_mat = mi.get_active_material(surf_idx)
				if orig_mat and orig_mat is StandardMaterial3D:
					var mat_copy = orig_mat.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(surf_idx, mat_copy)
					_all_mesh_materials.append(mat_copy)
	for child in node.get_children():
		_cache_mesh_materials(child)

func _physics_process(delta: float) -> void:
	# Snap to terrain height (terrain has no physics collision body)
	_snap_to_terrain()
	
	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.WANDER:
			_process_wander(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK:
			_process_attack(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.DEAD:
			_process_dead(delta)
			return
	
	# Always check for player detection (except when dead/hurt)
	if ai_state != AIState.DEAD and ai_state != AIState.HURT:
		_check_player_detection()
	
	move_and_slide()

func _snap_to_terrain() -> void:
	if _chunk_manager and _chunk_manager.has_method("get_terrain_height"):
		var terrain_y = _chunk_manager.get_terrain_height(global_position)
		if global_position.y < terrain_y + 0.1:
			global_position.y = terrain_y
			velocity.y = 0
		elif global_position.y > terrain_y + 2.0:
			# Falling — apply gravity toward terrain
			velocity.y -= _gravity * get_physics_process_delta_time()
		else:
			global_position.y = terrain_y
			velocity.y = 0

func _process_idle(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_idle_timer -= delta
	if _idle_timer <= 0:
		_pick_wander_target()
		ai_state = AIState.WANDER

func _process_wander(_delta: float) -> void:
	var dir = (_wander_target - global_position)
	dir.y = 0
	var dist = dir.length()
	
	if dist < 0.5:
		ai_state = AIState.IDLE
		_idle_timer = _rng.randf_range(2.0, 5.0)
		return
	
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_direction(dir)

func _process_chase(_delta: float) -> void:
	if not is_instance_valid(_target):
		ai_state = AIState.IDLE
		_idle_timer = 1.0
		return
	
	var dir = (_target.global_position - global_position)
	dir.y = 0
	var dist = dir.length()
	
	# Lost interest
	if dist > lose_interest_range:
		_target = null
		ai_state = AIState.IDLE
		_idle_timer = 1.0
		return
	
	# In attack range
	if dist <= attack_range:
		ai_state = AIState.ATTACK
		_attack_timer = 0.3  # Wind-up before first hit
		velocity.x = 0
		velocity.z = 0
		return
	
	dir = dir.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_face_direction(dir)

func _process_attack(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	if not is_instance_valid(_target):
		ai_state = AIState.IDLE
		_idle_timer = 1.0
		return
	
	var dist = global_position.distance_to(_target.global_position)
	
	# Target moved out of range
	if dist > attack_range * 1.5:
		ai_state = AIState.CHASE
		return
	
	# Face target
	var dir = (_target.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		_face_direction(dir.normalized())
	
	_attack_timer -= delta
	if _attack_timer <= 0:
		_do_attack()
		_attack_timer = attack_cooldown

func _process_hurt(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hurt_timer -= delta
	if _hurt_timer <= 0:
		if current_health <= 0:
			_die()
		else:
			ai_state = AIState.CHASE if _target else AIState.IDLE

func _process_dead(delta: float) -> void:
	velocity = Vector3.ZERO
	_death_timer -= delta
	if _death_timer <= 0:
		queue_free()

func _check_player_detection() -> void:
	if _target:
		return  # Already tracking a target
	
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		var dist = global_position.distance_to(p.global_position)
		if dist <= detection_range:
			_target = p
			ai_state = AIState.CHASE
			break

func _pick_wander_target() -> void:
	var angle = _rng.randf_range(0, TAU)
	var dist = _rng.randf_range(2.0, wander_radius)
	_wander_target = _spawn_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	_wander_target.y = global_position.y

func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.15)

func _do_attack() -> void:
	if not is_instance_valid(_target):
		return
	
	# Visual lunge
	var lunge_dir = (_target.global_position - global_position).normalized()
	var tween = create_tween()
	tween.tween_property(self, "position",
		global_position + lunge_dir * 0.3, 0.1)
	tween.tween_property(self, "position",
		global_position, 0.1)
	
	# Deal damage to player
	if _target.has_method("take_damage"):
		_target.take_damage(attack_damage, self)

# Called by the player's tool affinity system
func get_target_type() -> int:
	return ToolAffinity.TargetType.ENEMY

func on_hit(player: Node3D, _tool_type: String, power: float = 1.0) -> void:
	if ai_state == AIState.DEAD:
		return
	
	current_health -= power
	_target = player
	ai_state = AIState.HURT
	_hurt_timer = 0.3
	
	# Flash red
	_flash_hurt()
	
	print("%s took %.1f damage (%.1f/%.1f HP)" % [enemy_name, power, current_health, max_health])

func _flash_hurt() -> void:
	# Flash loaded model materials
	if _all_mesh_materials.size() > 0:
		var model_tween = create_tween()
		for mat in _all_mesh_materials:
			if mat is StandardMaterial3D:
				mat.albedo_color = Color(1, 0.2, 0.2)
				model_tween.parallel().tween_property(mat, "albedo_color",
					Color.WHITE, 0.25)
		return
	
	# Flash placeholder mesh
	if not _mesh or not _mesh.material_override:
		return
	_mesh.material_override.albedo_color = Color(1, 0.2, 0.2)
	var placeholder_tween = create_tween()
	placeholder_tween.tween_property(_mesh.material_override, "albedo_color",
		_original_color, 0.25)

func _die() -> void:
	ai_state = AIState.DEAD
	_death_timer = 1.0
	
	# Grant XP
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager and skill_manager.has_method("grant_action_xp"):
		skill_manager.grant_action_xp(xp_skill)
	
	# Spawn loot
	_spawn_loot()
	
	# Shrink animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.8)
	
	print("%s defeated!" % enemy_name)

func _spawn_loot() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for loot in loot_table:
		var chance: float = loot.get("chance", 1.0)
		if rng.randf() > chance:
			continue
		
		var item_id: String = loot.get("item_id", "")
		var min_amt: int = loot.get("min_amount", 1)
		var max_amt: int = loot.get("max_amount", 1)
		var amount: int = rng.randi_range(min_amt, max_amt)
		
		if item_id == "" or amount <= 0:
			continue
		
		var drop_pos = global_position + Vector3(
			rng.randf_range(-0.5, 0.5),
			0.5,
			rng.randf_range(-0.5, 0.5)
		)
		
		var world_item = WorldItemScene.instantiate() as WorldItem
		world_item.item_id = item_id
		world_item.quantity = amount
		world_item.auto_pickup = true
		world_item.position = drop_pos
		
		var tree_root = get_tree().current_scene
		if tree_root:
			tree_root.add_child(world_item)
