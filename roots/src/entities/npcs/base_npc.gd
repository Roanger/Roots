extends CharacterBody3D
class_name BaseNPC
## Base class for all village NPCs. Handles idle/wander AI,
## interaction (dialogue, shopping), and visual setup.
## Uses standard Godot CharacterBody3D physics for grounding.

const NPCDataScript = preload("res://src/entities/npcs/npc_data.gd")

enum AIState { IDLE, WANDER, TALKING, SLEEPING, GOING_TO_TARGET }

var npc_data = null  # NPCData

# Runtime state
var ai_state: AIState = AIState.IDLE
var _spawn_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _idle_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _model_node: Node3D = null
var _mesh: MeshInstance3D = null
var _name_label: Label3D = null
var _title_label: Label3D = null
var _talk_target: Node3D = null  # Player we're talking to
var _quest_glow: OmniLight3D = null
var _quest_particles: GPUParticles3D = null
var _has_quest: bool = false
var _glow_time: float = 0.0

# Schedule system
var home_position: Vector3 = Vector3.ZERO
var work_position: Vector3 = Vector3.ZERO
var _schedule: Array = []
var _schedule_idx: int = -1
var _current_activity: String = "idle"
var _schedule_check_timer: float = 0.0

signal dialogue_requested(npc: BaseNPC, player: Node3D)
signal shop_requested(npc: BaseNPC, player: Node3D)

func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 2  # World objects layer — so player raycast hits us
	collision_mask = 1   # Collide with terrain (layer 1) for gravity grounding
	_rng.randomize()
	_spawn_position = global_position
	_idle_timer = _rng.randf_range(2.0, 5.0)
	_build_visual()
	_init_schedule()

func setup(data) -> void:
	npc_data = data

# ── Visual ──────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	if npc_data and npc_data.model_path != "":
		_build_model_visual()
	else:
		_build_placeholder_visual()

	# Collision shape
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = npc_data.collision_radius if npc_data else 0.35
	shape.height = npc_data.collision_height if npc_data else 1.6
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)

	# Name label
	var label_y = (npc_data.collision_height if npc_data else 1.6) + 0.3
	_name_label = Label3D.new()
	_name_label.text = npc_data.display_name if npc_data else "NPC"
	_name_label.font_size = 24
	_name_label.position.y = label_y
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.modulate = Color(0.9, 0.85, 0.6)
	_name_label.outline_modulate = Color(0, 0, 0, 0.8)
	_name_label.outline_size = 4
	add_child(_name_label)

	# Title label (below name)
	if npc_data and npc_data.title != "":
		_title_label = Label3D.new()
		_title_label.text = npc_data.title
		_title_label.font_size = 16
		_title_label.position.y = label_y - 0.25
		_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_title_label.modulate = Color(0.7, 0.7, 0.7)
		_title_label.outline_modulate = Color(0, 0, 0, 0.6)
		_title_label.outline_size = 3
		add_child(_title_label)

func _build_model_visual() -> void:
	var scene_res = load(npc_data.model_path)
	if not scene_res:
		push_warning("BaseNPC: Failed to load model '%s', using placeholder" % npc_data.model_path)
		_build_placeholder_visual()
		return

	_model_node = scene_res.instantiate() as Node3D
	if not _model_node:
		_build_placeholder_visual()
		return

	_model_node.position = Vector3.ZERO
	_model_node.rotation = Vector3.ZERO
	_model_node.scale = Vector3.ONE * (npc_data.model_scale if npc_data else 1.0)
	add_child(_model_node)

func _build_placeholder_visual() -> void:
	_mesh = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = npc_data.collision_radius if npc_data else 0.35
	capsule.height = npc_data.collision_height if npc_data else 1.6
	_mesh.mesh = capsule
	var mat = StandardMaterial3D.new()
	mat.albedo_color = npc_data.body_color if npc_data else Color(0.7, 0.6, 0.5)
	_mesh.material_override = mat
	_mesh.position.y = capsule.height * 0.5
	add_child(_mesh)

# ── Physics ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	_update_quest_glow(delta)
	_check_schedule()

	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.WANDER:
			_process_wander(delta)
		AIState.TALKING:
			_process_talking(delta)
		AIState.SLEEPING:
			_process_sleeping(delta)
		AIState.GOING_TO_TARGET:
			_process_going_to_target(delta)

	move_and_slide()

# ── AI States ───────────────────────────────────────────────────────────────

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
		_idle_timer = _rng.randf_range(4.0, 10.0)
		return

	var spd = npc_data.move_speed if npc_data else 1.0
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face_direction(dir)

func _process_talking(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	# Face the player we're talking to
	if is_instance_valid(_talk_target):
		var dir = (_talk_target.global_position - global_position)
		dir.y = 0
		if dir.length() > 0.1:
			_face_direction(dir.normalized())

func _pick_wander_target() -> void:
	var radius = npc_data.wander_radius if npc_data else 3.0
	var angle = _rng.randf_range(0, TAU)
	var dist = _rng.randf_range(1.0, radius)
	_wander_target = _spawn_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	_wander_target.y = global_position.y

func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.12)

# ── Schedule System ─────────────────────────────────────────────────────────

func _init_schedule() -> void:
	if npc_data and npc_data.schedule.size() > 0:
		_schedule = npc_data.schedule.duplicate()
		_schedule.sort_custom(func(a, b): return a.get("hour", 0.0) < b.get("hour", 0.0))
	_update_schedule_for_hour()

func _check_schedule() -> void:
	if _schedule.is_empty() or ai_state == AIState.TALKING:
		return
	_schedule_check_timer += get_physics_process_delta_time()
	if _schedule_check_timer < 2.0:
		return
	_schedule_check_timer = 0.0
	_update_schedule_for_hour()

func _update_schedule_for_hour() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var hour: float = gm.current_hour

	var best_idx := -1
	for i in range(_schedule.size()):
		var entry_hour: float = _schedule[i].get("hour", 0.0)
		if hour >= entry_hour:
			best_idx = i
	if best_idx < 0:
		best_idx = _schedule.size() - 1
	# If same schedule index, no change needed
	if best_idx == _schedule_idx:
		return

	_schedule_idx = best_idx
	var entry = _schedule[_schedule_idx]
	_current_activity = entry.get("activity", "idle")
	var target: Vector3 = entry.get("target_pos", _spawn_position)
	target.y = global_position.y

	var dist := global_position.distance_to(target)
	if dist < 0.8:
		_arrived_at_target()
	else:
		_wander_target = target
		ai_state = AIState.GOING_TO_TARGET

func _arrived_at_target() -> void:
	match _current_activity:
		"sleep":
			ai_state = AIState.SLEEPING
		_:
			_spawn_position = global_position
			ai_state = AIState.IDLE
			_idle_timer = _rng.randf_range(2.0, 5.0)

func _process_sleeping(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

func _process_going_to_target(_delta: float) -> void:
	var dir = (_wander_target - global_position)
	dir.y = 0
	var dist = dir.length()
	if dist < 0.6:
		_arrived_at_target()
		return
	var spd = npc_data.move_speed if npc_data else 1.0
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face_direction(dir)

# ── Interaction ─────────────────────────────────────────────────────────────

func on_interact(player: Node3D) -> void:
	## Called when the player presses E while looking at this NPC.
	if ai_state == AIState.TALKING:
		return  # Already in conversation

	# Sleeping NPCs are unresponsive
	if ai_state == AIState.SLEEPING:
		var sleep_messages := ["Zzz...", "Fast asleep.", "Shh, sleeping..."]
		_show_floating_text(sleep_messages[_rng.randi() % sleep_messages.size()], Color(0.5, 0.5, 0.8))
		return

	_talk_target = player
	ai_state = AIState.TALKING

	# Face the player
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		_face_direction(dir.normalized())

	# Show greeting
	if npc_data and npc_data.greeting_lines.size() > 0:
		var greeting = npc_data.greeting_lines[_rng.randi() % npc_data.greeting_lines.size()]
		_show_floating_text(greeting, Color(0.9, 0.85, 0.6))

	# Emit dialogue signal — the UI system picks this up
	dialogue_requested.emit(self, player)

func end_conversation() -> void:
	## Called when dialogue UI closes.
	ai_state = AIState.IDLE
	_idle_timer = _rng.randf_range(3.0, 6.0)
	_talk_target = null

func open_shop() -> void:
	## Called from dialogue when player chooses "Shop" option.
	if _talk_target:
		shop_requested.emit(self, _talk_target)

func _show_floating_text(text: String, color: Color = Color.WHITE) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.no_depth_test = true
	label.position = global_position + Vector3(0, (npc_data.collision_height if npc_data else 1.6) + 0.8, 0)
	get_tree().current_scene.add_child(label)
	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

# ── Quest Glow ─────────────────────────────────────────────────────────────

func set_quest_available(available: bool) -> void:
	_has_quest = available
	if available:
		_create_quest_glow()
	else:
		_remove_quest_glow()

func _create_quest_glow() -> void:
	if _quest_glow:
		return  # Already exists

	var glow_y = (npc_data.collision_height if npc_data else 1.6) * 0.6

	# Soft omni light — warm golden glow
	_quest_glow = OmniLight3D.new()
	_quest_glow.light_color = Color(1.0, 0.85, 0.4)
	_quest_glow.light_energy = 0.6
	_quest_glow.omni_range = 2.0
	_quest_glow.omni_attenuation = 1.5
	_quest_glow.shadow_enabled = false
	_quest_glow.position = Vector3(0, glow_y, 0)
	add_child(_quest_glow)

	# Small sparkle particles
	_quest_particles = GPUParticles3D.new()
	_quest_particles.amount = 6
	_quest_particles.lifetime = 1.5
	_quest_particles.position = Vector3(0, glow_y, 0)
	_quest_particles.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.5
	mat.gravity = Vector3(0, -0.3, 0)
	mat.scale_min = 0.03
	mat.scale_max = 0.06
	mat.color = Color(1.0, 0.9, 0.5, 0.8)
	var color_ramp = GradientTexture1D.new()
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.5, 0.9))
	gradient.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	_quest_particles.process_material = mat

	# Tiny quad mesh for each particle
	var quad = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var quad_mat = StandardMaterial3D.new()
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.emission_enabled = true
	quad_mat.emission = Color(1.0, 0.9, 0.5)
	quad_mat.emission_energy_multiplier = 2.0
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.vertex_color_use_as_albedo = true
	quad.material = quad_mat
	_quest_particles.draw_pass_1 = quad

	add_child(_quest_particles)

func _remove_quest_glow() -> void:
	if _quest_glow:
		_quest_glow.queue_free()
		_quest_glow = null
	if _quest_particles:
		_quest_particles.queue_free()
		_quest_particles = null

func _update_quest_glow(delta: float) -> void:
	if not _has_quest or not _quest_glow:
		return
	_glow_time += delta
	# Gentle pulse: energy oscillates between 0.3 and 0.8
	_quest_glow.light_energy = 0.55 + 0.25 * sin(_glow_time * 2.0)

func get_target_type() -> int:
	# NPCs shouldn't be attacked — return BUILDING so weapons are ineffective
	return ToolAffinity.TargetType.BUILDING

func on_hit(_player: Node3D, _tool_type: String, _power: float = 1.0) -> void:
	# NPCs can't be damaged — show reaction and penalize reputation
	_show_floating_text("Hey! Watch it!", Color(1.0, 0.4, 0.4))
	var main_world = get_node_or_null("/root/MainWorld")
	if main_world and main_world.has_method("modify_reputation") and npc_data:
		main_world.modify_reputation(npc_data.npc_id, -5)
