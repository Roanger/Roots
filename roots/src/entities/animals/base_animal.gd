extends CharacterBody3D
class_name BaseAnimal
## Base class for all animals. Handles AI states, feeding, products, and loot.
## Farm animals idle/wander near their spawn, flee from threats, and can be fed/petted.
## Wild/huntable animals wander freely and flee when attacked.

const WorldItemScene = preload("res://src/items/world_item.tscn")
const AnimalDataScript = preload("res://src/entities/animals/animal_data.gd")


enum AIState { IDLE, WANDER, FLEE, FOLLOW, FEEDING, GRAZING, HUNTING, HURT, DEAD }

# Data reference (typed via preload const to avoid class_name timing issues)
var animal_data = null  # AnimalData

# Runtime state
var current_health: float = 20.0
var ai_state: AIState = AIState.IDLE
var hunger: float = 0.0          # 0 = full, 1 = starving
var happiness: float = 0.5       # 0 = miserable, 1 = happy
var is_tamed: bool = false
var is_baby: bool = false
var baby_timer: float = 0.0
var product_timer: float = 0.0
var breed_timer: float = 0.0

# Internal
var _spawn_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _flee_from: Node3D = null
var _follow_target: Node3D = null
var _idle_timer: float = 0.0
var _hurt_timer: float = 0.0
var _death_timer: float = 0.0
var _flee_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mesh: MeshInstance3D = null
var _model_node: Node3D = null
var _original_color: Color = Color.WHITE
var _all_mesh_materials: Array = []
var _chunk_manager: Node = null
var _name_label: Label3D = null

# Hunting / predator
var _prey_target: BaseAnimal = null
var _attack_timer: float = 0.0

# Grazing
var _graze_timer: float = 0.0
var _terrain_biome: int = -1

signal product_ready(animal: BaseAnimal)
signal animal_died(animal: BaseAnimal)

func _ready() -> void:
	add_to_group("animals")
	collision_layer = 4
	collision_mask = 3  # 1 (terrain) + 2 (world objects/fences)
	_rng.randomize()
	_spawn_position = global_position
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

	_apply_data()
	_build_visual()

func setup(data, tamed: bool = false, baby: bool = false) -> void:
	animal_data = data
	is_tamed = tamed
	is_baby = baby
	if baby and data:
		baby_timer = data.baby_grow_time

func _apply_data() -> void:
	if not animal_data:
		return
	current_health = animal_data.max_health
	if animal_data.animal_type == AnimalDataScript.AnimalType.FARM:
		is_tamed = true
	product_timer = animal_data.product_interval
	breed_timer = animal_data.breed_cooldown

func _build_visual() -> void:
	# Use individual model file if specified (e.g. .glb/.gltf), otherwise placeholder
	if animal_data and animal_data.model_path != "":
		_build_model_visual()
	else:
		_build_placeholder_visual()

	# Collision shape
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	var s = _get_scale_factor()
	shape.radius = (animal_data.collision_radius if animal_data else 0.4) * s
	shape.height = (animal_data.collision_height if animal_data else 1.0) * s
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)

	# Name label
	_name_label = Label3D.new()
	_name_label.text = animal_data.display_name if animal_data else "Animal"
	_name_label.font_size = 20
	_name_label.position.y = (animal_data.collision_height if animal_data else 1.0) * s + 0.4
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.modulate = Color(0.6, 1.0, 0.6) if is_tamed else Color(0.9, 0.9, 0.6)
	add_child(_name_label)

func _build_model_visual() -> void:
	var scene_res = load(animal_data.model_path)
	if not scene_res:
		push_warning("BaseAnimal: Failed to load model '%s', using placeholder" % animal_data.model_path)
		_build_placeholder_visual()
		return

	_model_node = scene_res.instantiate() as Node3D
	if not _model_node:
		_build_placeholder_visual()
		return

	# FBX models from QiwiiPack have baked-in position offsets (e.g. Z=-14)
	# and -90° X rotation from FBX Y-up conversion. Fix all child transforms.
	_model_node.position = Vector3.ZERO
	_model_node.rotation = Vector3.ZERO
	for child in _model_node.get_children():
		if child is Node3D:
			child.position = Vector3.ZERO
			# FBX uses Y-up, Godot uses Z-up → meshes come in rotated -90° on X
			# Reset to just the -90° X rotation which is the correct orientation fix
			child.rotation = Vector3(-PI / 2.0, 0, 0)

	_model_node.scale = Vector3.ONE * animal_data.model_scale * _get_scale_factor()
	add_child(_model_node)
	_cache_mesh_materials(_model_node)
	_original_color = animal_data.body_color

func _build_placeholder_visual() -> void:
	_mesh = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	var s = _get_scale_factor()
	capsule.radius = (animal_data.collision_radius if animal_data else 0.35) * s
	capsule.height = (animal_data.collision_height if animal_data else 1.0) * s
	_mesh.mesh = capsule
	var mat = StandardMaterial3D.new()
	mat.albedo_color = animal_data.body_color if animal_data else Color(0.8, 0.7, 0.5)
	_mesh.material_override = mat
	_mesh.position.y = capsule.height * 0.5
	_original_color = mat.albedo_color
	add_child(_mesh)

func _get_scale_factor() -> float:
	if is_baby and animal_data:
		return animal_data.baby_scale
	return 1.0

func _cache_mesh_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for surf_idx in mi.mesh.get_surface_count():
				var orig_mat = mi.get_active_material(surf_idx)
				if orig_mat and orig_mat is StandardMaterial3D:
					var mat_copy = orig_mat.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(surf_idx, mat_copy)
					_all_mesh_materials.append(mat_copy)
	for child in node.get_children():
		_cache_mesh_materials(child)

# ── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Apply standard Godot gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	# Sample terrain biome for grazing decisions
	if _chunk_manager and _chunk_manager.has_method("get_biome_at"):
		_terrain_biome = _chunk_manager.get_biome_at(global_position)

	# Threat detection — auto-flee from threats
	if ai_state not in [AIState.FLEE, AIState.HURT, AIState.DEAD, AIState.HUNTING]:
		_scan_for_threats()

	# Predator hunting — scan for prey
	if animal_data and animal_data.is_predator and ai_state not in [AIState.FLEE, AIState.HURT, AIState.DEAD]:
		if ai_state != AIState.HUNTING:
			_scan_for_prey()
		else:
			# Chase prey during hunt
			if not is_instance_valid(_prey_target) or _prey_target.ai_state == AIState.DEAD:
				_prey_target = null
				ai_state = AIState.IDLE
				_idle_timer = _rng.randf_range(2.0, 5.0)

	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.WANDER:
			_process_wander(delta)
		AIState.FLEE:
			_process_flee(delta)
		AIState.FOLLOW:
			_process_follow(delta)
		AIState.FEEDING:
			_process_feeding(delta)
		AIState.GRAZING:
			_process_grazing(delta)
		AIState.HUNTING:
			_process_hunting(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.DEAD:
			_process_dead(delta)
			return

	# Timers
	_update_hunger(delta)
	_update_products(delta)
	_update_baby(delta)
	if breed_timer > 0:
		breed_timer -= delta
	if _attack_timer > 0:
		_attack_timer -= delta

	move_and_slide()

# ── AI States ────────────────────────────────────────────────────────────────

func _process_idle(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_idle_timer -= delta
	if _idle_timer <= 0:
		# Tamed animals on grassy terrain may graze instead of wandering
		if animal_data and animal_data.can_graze and _is_on_grazable_terrain():
			if _rng.randf() < 0.5:
				ai_state = AIState.GRAZING
				_graze_timer = _rng.randf_range(3.0, 6.0)
				return
		_pick_wander_target()
		ai_state = AIState.WANDER

func _process_wander(_delta: float) -> void:
	var dir = (_wander_target - global_position)
	dir.y = 0
	var dist = dir.length()

	if dist < 0.5:
		ai_state = AIState.IDLE
		_idle_timer = _rng.randf_range(3.0, 8.0)
		return

	var spd = animal_data.move_speed if animal_data else 1.5
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face_direction(dir)

func _process_flee(delta: float) -> void:
	_flee_timer -= delta
	if _flee_timer <= 0 or not is_instance_valid(_flee_from):
		_flee_from = null
		ai_state = AIState.IDLE
		_idle_timer = _rng.randf_range(2.0, 4.0)
		return

	var dir = (global_position - _flee_from.global_position)
	dir.y = 0
	if dir.length() < 0.1:
		dir = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	dir = dir.normalized()
	var spd = animal_data.flee_speed if animal_data else 4.0
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face_direction(dir)

func _process_follow(_delta: float) -> void:
	if not is_instance_valid(_follow_target):
		_follow_target = null
		ai_state = AIState.IDLE
		_idle_timer = 1.0
		return

	var dir = (_follow_target.global_position - global_position)
	dir.y = 0
	var dist = dir.length()

	# Stop following if too far
	if dist > 20.0:
		_follow_target = null
		ai_state = AIState.IDLE
		_idle_timer = 1.0
		return

	# Stay near but not on top of target
	if dist < 2.0:
		velocity.x = 0
		velocity.z = 0
		return

	var spd = animal_data.move_speed * 1.5 if animal_data else 2.0
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face_direction(dir)

func _process_feeding(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_idle_timer -= delta
	if _idle_timer <= 0:
		ai_state = AIState.IDLE
		_idle_timer = _rng.randf_range(3.0, 6.0)

func _process_grazing(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	# Reduce hunger while grazing
	if animal_data and animal_data.can_graze and is_tamed:
		hunger = clampf(hunger - animal_data.graze_hunger_reduction * delta, 0.0, 1.0)
		# Slight happiness boost from grazing
		happiness = clampf(happiness + 0.005 * delta, 0.0, 1.0)
	_graze_timer -= delta
	if _graze_timer <= 0 or not _is_on_grazable_terrain():
		ai_state = AIState.IDLE
		_idle_timer = _rng.randf_range(3.0, 6.0)

func _process_hunting(_delta: float) -> void:
	if not is_instance_valid(_prey_target) or _prey_target.ai_state == AIState.DEAD:
		_prey_target = null
		ai_state = AIState.IDLE
		_idle_timer = _rng.randf_range(2.0, 5.0)
		return

	var dir = (_prey_target.global_position - global_position)
	dir.y = 0
	var dist = dir.length()

	# Attack if close enough
	if dist < 1.5 and _attack_timer <= 0:
		_prey_target.on_hit_by_predator(self)
		_attack_timer = animal_data.attack_cooldown if animal_data else 3.0
		# Brief pause after attacking
		velocity.x = 0
		velocity.z = 0
		return

	# Chase the prey
	if dist > 0.5:
		var spd = animal_data.move_speed * (animal_data.hunt_speed_mult if animal_data else 1.5)
		dir = dir.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		_face_direction(dir)
	else:
		velocity.x = 0
		velocity.z = 0

func _scan_for_threats() -> void:
	if not animal_data or animal_data.is_predator:
		return
	var range_sq = animal_data.detection_range * animal_data.detection_range
	var nearest_threat: Node3D = null
	var nearest_dist_sq: float = range_sq + 1.0

	# HUNTABLE animals flee from any player and from predators
	if animal_data.animal_type == AnimalDataScript.AnimalType.HUNTABLE:
		for player in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(player):
				continue
			var d_sq = global_position.distance_squared_to(player.global_position)
			if d_sq < range_sq and d_sq < nearest_dist_sq:
				nearest_dist_sq = d_sq
				nearest_threat = player
		# Also flee from predators
		for animal in get_tree().get_nodes_in_group("animals"):
			if animal == self or not animal is BaseAnimal:
				continue
			var other := animal as BaseAnimal
			if other.animal_data and other.animal_data.is_predator:
				var d_sq = global_position.distance_squared_to(other.global_position)
				if d_sq < range_sq and d_sq < nearest_dist_sq:
					nearest_dist_sq = d_sq
					nearest_threat = other

	# FARM animals flee from enemies (skeletons etc)
	if animal_data.animal_type == AnimalDataScript.AnimalType.FARM:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var d_sq = global_position.distance_squared_to(enemy.global_position)
			if d_sq < range_sq and d_sq < nearest_dist_sq:
				nearest_dist_sq = d_sq
				nearest_threat = enemy

	if nearest_threat:
		_flee_from = nearest_threat
		_flee_timer = 4.0
		ai_state = AIState.FLEE

func _scan_for_prey() -> void:
	if not animal_data or not animal_data.is_predator or not animal_data.prey_species:
		return
	var range_sq = animal_data.detection_range * animal_data.detection_range
	var nearest_prey: BaseAnimal = null
	var nearest_dist_sq: float = range_sq + 1.0

	for animal in get_tree().get_nodes_in_group("animals"):
		if animal == self or not animal is BaseAnimal:
			continue
		var other := animal as BaseAnimal
		if not other.animal_data:
			continue
		if not other.animal_data.species_id in animal_data.prey_species:
			continue
		if other.ai_state == AIState.DEAD:
			continue
		var d_sq = global_position.distance_squared_to(other.global_position)
		if d_sq < range_sq and d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			nearest_prey = other

	if nearest_prey:
		_prey_target = nearest_prey
		ai_state = AIState.HUNTING

func _is_on_grazable_terrain() -> bool:
	if not animal_data or not animal_data.can_graze:
		return false
	if animal_data.graze_biomes.is_empty():
		return false
	return _terrain_biome in animal_data.graze_biomes

func _process_hurt(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hurt_timer -= delta
	if _hurt_timer <= 0:
		if current_health <= 0:
			_die()
		else:
			# Flee from attacker
			if _flee_from:
				ai_state = AIState.FLEE
				_flee_timer = 4.0
			else:
				ai_state = AIState.IDLE

func _process_dead(delta: float) -> void:
	velocity = Vector3.ZERO
	_death_timer -= delta
	if _death_timer <= 0:
		queue_free()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _pick_wander_target() -> void:
	var radius = animal_data.wander_radius if animal_data else 6.0
	var angle = _rng.randf_range(0, TAU)
	var dist = _rng.randf_range(2.0, radius)
	_wander_target = _spawn_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	_wander_target.y = global_position.y

func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.12)

func _update_hunger(delta: float) -> void:
	if not animal_data or not is_tamed:
		return
	hunger = clampf(hunger + animal_data.hunger_rate * delta, 0.0, 1.0)
	# Happiness decays when hungry
	if hunger > 0.7:
		happiness = clampf(happiness - 0.01 * delta, 0.0, 1.0)

func _update_products(delta: float) -> void:
	if not animal_data or not is_tamed or is_baby:
		return
	if animal_data.product_type == AnimalDataScript.ProductType.NONE:
		return
	if animal_data.product_item_id == "":
		return

	# Only produce when fed (hunger < 0.8) and happy enough
	if hunger > 0.8 or happiness < 0.2:
		return

	product_timer -= delta
	if product_timer <= 0:
		product_timer = animal_data.product_interval
		_drop_product()

func _update_baby(delta: float) -> void:
	if not is_baby or not animal_data:
		return
	baby_timer -= delta
	if baby_timer <= 0:
		is_baby = false
		# Grow to adult size
		if _model_node:
			var tween = create_tween()
			tween.tween_property(_model_node, "scale",
				Vector3.ONE * animal_data.model_scale, 1.0)
		elif _mesh:
			var tween = create_tween()
			tween.tween_property(_mesh, "scale", Vector3.ONE, 1.0)

func _drop_product() -> void:
	if not animal_data or animal_data.product_item_id == "":
		return

	var drop_pos = global_position + Vector3(
		_rng.randf_range(-0.3, 0.3),
		0.3,
		_rng.randf_range(-0.3, 0.3)
	)

	var world_item = WorldItemScene.instantiate() as WorldItem
	world_item.item_id = animal_data.product_item_id
	world_item.quantity = animal_data.product_amount
	world_item.auto_pickup = true
	world_item.position = drop_pos

	var tree_root = get_tree().current_scene
	if tree_root:
		tree_root.add_child(world_item)

	product_ready.emit(self)
	print("[Animal] %s produced %s x%d" % [animal_data.display_name, animal_data.product_item_id, animal_data.product_amount])

# ── Interaction ──────────────────────────────────────────────────────────────

func on_interact(player: Node3D) -> void:
	## Called when the player presses E while looking at this animal.
	## If holding a food item the animal eats → feed it.
	## If holding nothing or non-food → pet it (tamed only).
	if ai_state == AIState.DEAD:
		return

	# Check what the player is holding
	var held_item: ItemData = null
	if player.has_method("_get_held_item_data"):
		held_item = player._get_held_item_data()

	# Try feeding first
	if held_item and animal_data and held_item.item_id in animal_data.feed_item_ids:
		if feed(player, held_item.item_id):
			# Consume one item from the player's hotbar
			var inv = player.get("inventory") if player else null
			if inv:
				var hotbar_ui_node = player.get_tree().get_first_node_in_group("hotbar_ui")
				if not hotbar_ui_node:
					# Fallback: search all HotbarUI nodes
					for ui_node in player.get_tree().get_nodes_in_group("hotbar_ui"):
						hotbar_ui_node = ui_node
						break
				var slot_idx: int = hotbar_ui_node.selected_slot if hotbar_ui_node else 0
				var slot_item = inv.get_hotbar_slot(slot_idx)
				if slot_item:
					slot_item.remove_amount(1)
					if slot_item.is_empty():
						inv.hotbar_slots[slot_idx] = null
					inv.hotbar_changed.emit(slot_idx)
			_show_floating_text("Fed!", Color(0.4, 1.0, 0.4))
			# Try breeding after feeding (if conditions met)
			_try_breed()
			return

	# If tamed and not fed, pet instead
	if is_tamed:
		pet(player)
		_show_floating_text("Petted!", Color(0.6, 0.8, 1.0))
		return

	# Wild animals — show a hint
	if animal_data and animal_data.animal_type == AnimalDataScript.AnimalType.HUNTABLE:
		_show_floating_text("Wild", Color(0.9, 0.9, 0.6))

func _show_floating_text(text: String, color: Color = Color.WHITE) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = global_position + Vector3(0, (animal_data.collision_height if animal_data else 1.0) + 0.8, 0)
	label.no_depth_test = true
	get_tree().current_scene.add_child(label)
	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func get_target_type() -> int:
	# Wild/huntable animals can be hit
	if animal_data and animal_data.animal_type == AnimalDataScript.AnimalType.HUNTABLE:
		return ToolAffinity.TargetType.ENEMY
	# Farm animals shouldn't be attacked easily (still return ENEMY so weapons work)
	return ToolAffinity.TargetType.ENEMY

func on_hit(player: Node3D, _tool_type: String, power: float = 1.0) -> void:
	if ai_state == AIState.DEAD:
		return

	current_health -= power
	_flee_from = player
	ai_state = AIState.HURT
	_hurt_timer = 0.3

	_flash_hurt()
	print("[Animal] %s took %.1f damage (%.1f/%.1f HP)" % [
		animal_data.display_name if animal_data else "Animal",
		power, current_health, animal_data.max_health if animal_data else 0])

func on_hit_by_predator(predator: Node3D) -> void:
	## Called when a predator attacks this animal.
	if ai_state == AIState.DEAD:
		return

	var dmg = animal_data.attack_damage if animal_data else 5.0
	current_health -= dmg
	_flee_from = predator
	ai_state = AIState.HURT
	_hurt_timer = 0.3

	_flash_hurt()
	print("[Animal] %s was attacked by predator! (%.1f/%.1f HP)" % [
		animal_data.display_name if animal_data else "Animal",
		current_health, animal_data.max_health if animal_data else 0])

func feed(player: Node3D, item_id: String) -> bool:
	## Try to feed this animal. Returns true if the animal accepted the food.
	if not animal_data or not is_tamed:
		return false
	if ai_state == AIState.DEAD:
		return false
	if not item_id in animal_data.feed_item_ids:
		return false

	hunger = clampf(hunger - 0.4, 0.0, 1.0)
	happiness = clampf(happiness + animal_data.happiness_from_feed, 0.0, 1.0)

	# Enter feeding state briefly
	ai_state = AIState.FEEDING
	_idle_timer = 2.0

	# Face the player
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		_face_direction(dir.normalized())

	# Grant husbandry XP
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager and skill_manager.has_method("grant_action_xp"):
		skill_manager.grant_action_xp("feed_animal")

	print("[Animal] %s was fed (hunger=%.2f, happiness=%.2f)" % [
		animal_data.display_name, hunger, happiness])
	return true

func pet(player: Node3D) -> void:
	## Pet the animal to increase happiness
	if not is_tamed or ai_state == AIState.DEAD:
		return

	happiness = clampf(happiness + 0.1, 0.0, 1.0)

	# Face the player
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		_face_direction(dir.normalized())

	# Brief pause
	ai_state = AIState.IDLE
	_idle_timer = 2.0

	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager and skill_manager.has_method("grant_action_xp"):
		skill_manager.grant_action_xp("pet_animal")

	print("[Animal] %s was petted (happiness=%.2f)" % [animal_data.display_name, happiness])

func can_breed() -> bool:
	if not animal_data or is_baby or not is_tamed:
		return false
	return breed_timer <= 0 and hunger < 0.5 and happiness > 0.6

func start_breed_cooldown() -> void:
	if animal_data:
		breed_timer = animal_data.breed_cooldown

func _try_breed() -> void:
	if not can_breed():
		return
	# Find a nearby same-species partner that can also breed
	var partner: BaseAnimal = null
	for node in get_tree().get_nodes_in_group("animals"):
		if node == self or not node is BaseAnimal:
			continue
		var other := node as BaseAnimal
		if not other.animal_data or other.animal_data.species_id != animal_data.species_id:
			continue
		if not other.can_breed():
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < 8.0:
			partner = other
			break

	if not partner:
		return

	# Both parents go on cooldown
	start_breed_cooldown()
	partner.start_breed_cooldown()

	# Spawn baby between the two parents
	var baby_pos = (global_position + partner.global_position) * 0.5
	baby_pos += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))

	var baby = BaseAnimal.new()
	baby.setup(animal_data, true, true)
	baby.position = baby_pos

	# Snap baby to terrain
	if _chunk_manager and _chunk_manager.has_method("get_terrain_height"):
		baby.position.y = _chunk_manager.get_terrain_height(baby_pos)

	get_tree().current_scene.add_child(baby)

	_show_floating_text("Baby!", Color(1.0, 0.8, 1.0))
	partner._show_floating_text("Baby!", Color(1.0, 0.8, 1.0))

	# Grant husbandry XP
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager and skill_manager.has_method("grant_action_xp"):
		skill_manager.grant_action_xp("breed_animal")

	print("[Animal] %s bred! Baby spawned at %s" % [animal_data.display_name, str(baby_pos)])

# ── Damage / Death ───────────────────────────────────────────────────────────

func _flash_hurt() -> void:
	if _all_mesh_materials.size() > 0:
		var model_tween = create_tween()
		for mat in _all_mesh_materials:
			if mat is StandardMaterial3D:
				mat.albedo_color = Color(1, 0.2, 0.2)
				model_tween.parallel().tween_property(mat, "albedo_color",
					Color.WHITE, 0.25)
		return

	if not _mesh or not _mesh.material_override:
		return
	_mesh.material_override.albedo_color = Color(1, 0.2, 0.2)
	var placeholder_tween = create_tween()
	placeholder_tween.tween_property(_mesh.material_override, "albedo_color",
		_original_color, 0.25)

func _die() -> void:
	ai_state = AIState.DEAD
	_death_timer = 1.5

	# Grant XP
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager and skill_manager.has_method("grant_action_xp"):
		var skill = animal_data.xp_skill if animal_data else "combat"
		skill_manager.grant_action_xp(skill)

	# Spawn loot
	_spawn_loot()

	# Shrink animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 1.0)

	animal_died.emit(self)
	print("[Animal] %s died!" % (animal_data.display_name if animal_data else "Animal"))

func _spawn_loot() -> void:
	if not animal_data:
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for loot in animal_data.loot_table:
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

# ── Serialization ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"species_id": animal_data.species_id if animal_data else "",
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"health": current_health,
		"hunger": hunger,
		"happiness": happiness,
		"is_tamed": is_tamed,
		"is_baby": is_baby,
		"baby_timer": baby_timer,
		"product_timer": product_timer,
		"breed_timer": breed_timer,
	}
