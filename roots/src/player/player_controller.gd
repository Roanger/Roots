extends CharacterBody3D
## Player Controller - Handles all player movement and interaction

signal position_changed(new_position: Vector3)
signal state_changed(new_state: PlayerState)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)

enum PlayerState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	INTERACTING,
	USING_TOOL,
	CROUCHING,
	FIRST_PERSON
}

# Player stats
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 15.0  # Per second while sprinting
@export var stamina_regen_rate: float = 10.0  # Per second while not sprinting
@export var stamina_regen_delay: float = 1.0  # Seconds before regen starts

var current_health: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_timer: float = 0.0

@export var move_speed: float = 5.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 3.0
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var ground_acceleration: float = 10.0
@export var air_acceleration: float = 2.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var raycast: RayCast3D = $CameraPivot/Camera3D/RayCast3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback") if animation_tree else null
@onready var camera_controller = $CameraPivot

var current_state: PlayerState = PlayerState.IDLE
var is_on_ground: bool = false
var is_crouching: bool = false
var current_tool: String = ""
var interaction_target: Node3D = null

# Movement input
var move_input: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var is_interacting: bool = false

# Mouse state
var mouse_captured: bool = false

# Ground detection
@onready var ground_ray: RayCast3D = $GroundRay
var chunk_manager: Node = null
var terrain_height: float = 0.0

# Inventory
var inventory: Inventory = null
var equipment: Equipment = null
@onready var item_database: ItemDatabase = get_node_or_null("/root/ItemDatabase")
@onready var crop_database: CropDatabase = get_node_or_null("/root/CropDatabase")

# Farming component (child node)
var farming: PlayerFarming = null

# First-person tool display
var tool_holder: Node3D = null
var _tool_use_cooldown: float = 0.0
var _tool_use_cooldown_max: float = 0.5  # Seconds between swings

func _ready() -> void:
	add_to_group("player")
	
	# Camera position is handled by CameraController
	# Don't set it here to avoid conflicts
	
	# Setup raycast (mask: layer 2 = world objects, layer 4 = enemies)
	raycast.target_position = Vector3(0, 0, -3)
	raycast.collision_mask = 6
	raycast.enabled = true
	
	# Find chunk manager
	chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	if not chunk_manager:
		# Try to find it in the scene
		chunk_manager = get_node_or_null("/root/MainWorld/ChunkManager")
	
	# Initialize inventory
	inventory = Inventory.new(36)  # 36 slots
	if item_database:
		inventory.initialize(item_database)
		# Give starting items for testing
		_give_starting_items()
	
	# Initialize equipment
	equipment = Equipment.new()
	
	# Initialize farming component
	farming = PlayerFarming.new()
	farming.name = "PlayerFarming"
	add_child(farming)
	farming.initialize(self, inventory, item_database, crop_database)
	
	# Initialize first-person tool holder on camera
	if camera:
		tool_holder = ToolHolder.new()
		tool_holder.name = "ToolHolder"
		camera.add_child(tool_holder)

func _input(event: InputEvent) -> void:
	# Camera is handled by CameraController
	
	if event.is_action_pressed("jump"):
		if is_on_ground and not is_crouching:
			_jump()
	
	if event.is_action_pressed("interact"):
		_interact()
	
	if event.is_action_pressed("crouch"):
		_toggle_crouch()
	
	# Left-click to swing tool/weapon (only when mouse is captured = gameplay mode)
	if event.is_action_pressed("use_tool") and mouse_captured:
		_swing_tool()

func _physics_process(delta: float) -> void:
	_handle_movement_input()
	_apply_gravity(delta)
	_update_terrain_height()
	_update_stamina(delta)
	_move_character(delta)
	_update_animation()
	_check_interaction()
	_process_tool_use()

func _apply_gravity(delta: float) -> void:
	if not is_on_ground:
		velocity.y -= gravity * delta

func _handle_movement_input() -> void:
	move_input = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		move_input.y -= 1
	if Input.is_action_pressed("move_backward"):
		move_input.y += 1
	if Input.is_action_pressed("move_left"):
		move_input.x -= 1
	if Input.is_action_pressed("move_right"):
		move_input.x += 1
	
	move_input = move_input.normalized()
	
	is_sprinting = Input.is_action_pressed("run") and move_input.length() > 0

func get_camera_forward() -> Vector3:
	# Get camera's forward direction (horizontal only)
	if camera_controller:
		var forward = camera_controller.get_look_direction()
		forward.y = 0
		return forward.normalized()
	return -global_transform.basis.z

func _update_terrain_height() -> void:
	# Get terrain height at player position from chunk manager
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		var target_height = chunk_manager.get_terrain_height(global_position)
		terrain_height = target_height
	else:
		# Fallback to basic height
		terrain_height = 10.0

func _move_character(delta: float) -> void:
	var speed = move_speed
	
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = run_speed
	
	# Get movement direction relative to camera orientation
	var direction = Vector3.ZERO
	
	if move_input.length() > 0:
		# Get camera-based movement directions
		var cam_forward = get_camera_forward()
		var cam_right = cam_forward.cross(Vector3.UP).normalized()
		
		# Calculate movement direction based on input
		direction = (cam_forward * -move_input.y) + (cam_right * move_input.x)
		direction = direction.normalized()
		
		# Rotation is handled by camera controller in both modes:
		# - Third person: mouse X rotates player (handled by CameraController)
		# - First person: camera rotates independently, player doesn't rotate with movement
	
	# Apply acceleration
	var acceleration = ground_acceleration if is_on_ground else air_acceleration
	
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	
	# Move character
	move_and_slide()
	
	# Check ground collision with terrain
	_check_terrain_collision()
	
	# Update position signal
	emit_signal("position_changed", global_position)

func _check_terrain_collision() -> void:
	# Get the terrain height at current position
	var current_height = terrain_height
	
	# Check if player is below terrain
	if global_position.y < current_height + 0.1:
		global_position.y = current_height
		velocity.y = 0
		is_on_ground = true
	elif global_position.y > current_height + 1.0:
		# Player is in the air
		is_on_ground = false
	else:
		# Check using ground ray
		if ground_ray.is_colliding():
			is_on_ground = true
			velocity.y = max(velocity.y, -1.0)
		else:
			is_on_ground = false

func _jump() -> void:
	velocity.y = jump_force
	is_on_ground = false
	_set_state(PlayerState.JUMPING)

func _toggle_crouch() -> void:
	is_crouching = not is_crouching
	
	# Camera height is handled by CameraController
	# Adjust first person height in camera controller instead of tweening here
	if camera_controller:
		if is_crouching:
			camera_controller.first_person_height = 1.0
		else:
			camera_controller.first_person_height = 1.7
	
	_set_state(PlayerState.CROUCHING if is_crouching else PlayerState.IDLE)

# First person camera is always active - no toggle needed

func _interact() -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Handle farm plot interactions
		if collider is FarmPlot:
			_handle_farm_plot_interaction(collider)
		elif collider.has_method("on_interact"):
			collider.on_interact(self)
			_set_state(PlayerState.INTERACTING)

func _handle_farm_plot_interaction(plot: FarmPlot) -> void:
	if farming:
		farming.handle_farm_plot_interaction(plot)
	# Update player state based on plot state
	match plot.state:
		FarmPlot.PlotState.EMPTY, FarmPlot.PlotState.GROWING, FarmPlot.PlotState.READY_FOR_HARVEST:
			_set_state(PlayerState.USING_TOOL)
			if tool_holder and tool_holder.has_method("play_use_animation"):
				tool_holder.play_use_animation()
		FarmPlot.PlotState.TILLED:
			_set_state(PlayerState.INTERACTING)
		_:
			_set_state(PlayerState.INTERACTING)

func _check_interaction() -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider != interaction_target:
			interaction_target = collider
			# Show interaction prompt if applicable
	else:
		interaction_target = null

func _process_tool_use() -> void:
	# Check if player is using a tool via interact key (E)
	if Input.is_action_pressed("interact"):
		if current_tool != "":
			_use_tool()
			_set_state(PlayerState.USING_TOOL)
	elif current_state == PlayerState.USING_TOOL:
		_set_state(PlayerState.IDLE)
	
	# Tick down swing cooldown
	if _tool_use_cooldown > 0:
		_tool_use_cooldown -= get_physics_process_delta_time()

func _use_tool() -> void:
	# Tool use logic - will be expanded with farming/crafting
	pass

func _swing_tool() -> void:
	# Left-click swing: plays animation and applies tool effect
	if _tool_use_cooldown > 0:
		return
	if current_tool == "" and (not tool_holder or tool_holder.current_tool_id == ""):
		return
	
	_tool_use_cooldown = _tool_use_cooldown_max
	_set_state(PlayerState.USING_TOOL)
	
	# Play swing animation
	if tool_holder and tool_holder.has_method("play_use_animation"):
		tool_holder.play_use_animation()
	
	# Get the held item's data for affinity checks
	var held_item_data: ItemData = _get_held_item_data()
	var tool_type: String = current_tool if current_tool != "" else ""
	var base_power: int = held_item_data.tool_power if held_item_data else 1
	var tool_tier: int = held_item_data.tool_tier if held_item_data else 0
	
	# Check what we're hitting with the raycast
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Farm plot interaction (check affinity)
		if collider is FarmPlot:
			if ToolAffinity.can_affect(tool_type, ToolAffinity.TargetType.FARM_PLOT):
				_handle_farm_plot_interaction(collider)
			else:
				_show_tool_feedback(ToolAffinity.get_ineffective_message(tool_type, ToolAffinity.TargetType.FARM_PLOT))
			return
		
		# Objects that declare their target type via get_target_type()
		if collider.has_method("get_target_type") and collider.has_method("on_hit"):
			var target_type: int = collider.get_target_type()
			var effectiveness: float = ToolAffinity.get_effectiveness(tool_type, target_type)
			if effectiveness > 0.0:
				var power = ToolAffinity.calculate_power(tool_type, target_type, base_power, tool_tier)
				collider.on_hit(self, tool_type, power)
			else:
				_show_tool_feedback(ToolAffinity.get_ineffective_message(tool_type, target_type))
			return
		
		# Legacy on_hit without target type (pass raw values)
		if collider.has_method("on_hit"):
			collider.on_hit(self, tool_type)
			return
		
		# Generic interactable
		if collider.has_method("on_interact"):
			collider.on_interact(self)

func _get_held_item_data() -> ItemData:
	# Get the ItemData for whatever is currently in the selected hotbar slot
	if tool_holder and tool_holder.current_tool_id != "":
		if item_database:
			return item_database.get_item(tool_holder.current_tool_id)
	return null

func _show_tool_feedback(message: String) -> void:
	if message == "":
		return
	# TODO: Show on-screen feedback text (floating text or HUD message)
	print("[ToolFeedback] ", message)

func _update_animation() -> void:
	# Update animation state based on movement
	if current_state in [PlayerState.JUMPING, PlayerState.INTERACTING, PlayerState.USING_TOOL]:
		return
	
	var speed_percent = 0.0
	
	if move_input.length() > 0:
		speed_percent = velocity.length() / run_speed
		_set_state(PlayerState.RUNNING if is_sprinting else PlayerState.WALKING)
	else:
		_set_state(PlayerState.CROUCHING if is_crouching else PlayerState.IDLE)
	
	# Update animation tree parameters
	if animation_tree:
		animation_tree.set("parameters/speed_percent/scale", speed_percent)

func _set_state(new_state: PlayerState) -> void:
	if current_state != new_state:
		current_state = new_state
		emit_signal("state_changed", new_state)

func set_fov(fov: float) -> void:
	camera.fov = fov

func set_mouse_sensitivity(sensitivity: float) -> void:
	mouse_sensitivity = sensitivity
	if camera_controller:
		camera_controller.set_mouse_sensitivity(sensitivity)

func capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera_controller:
		camera_controller.set_mouse_sensitivity(mouse_sensitivity)

func release_mouse() -> void:
	mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func equip_tool(tool_name: String) -> void:
	current_tool = tool_name

func unequip_tool() -> void:
	current_tool = ""

func update_held_tool(item: InventoryItem) -> void:
	if not tool_holder:
		return
	if item and not item.is_empty() and item.item_data:
		var idata = item.item_data
		if idata.item_type == ItemData.ItemType.TOOL or idata.item_type == ItemData.ItemType.WEAPON:
			tool_holder.equip_tool(idata)
			current_tool = idata.tool_type
			return
	tool_holder.unequip_tool()
	current_tool = ""

func get_look_direction() -> Vector3:
	if camera_controller:
		return camera_controller.get_look_direction()
	return -global_transform.basis.z

func get_look_position() -> Vector3:
	return raycast.get_collision_point() if raycast.is_colliding() else camera.global_position + get_look_direction() * 10.0

func get_terrain_height() -> float:
	return terrain_height

func set_chunk_manager(manager: Node) -> void:
	chunk_manager = manager

func _give_starting_items() -> void:
	if not item_database:
		return
	
	# Give basic tools
	var hoe = item_database.get_item("basic_hoe")
	var shovel = item_database.get_item("basic_shovel")
	var watering_can = item_database.get_item("basic_watering_can")
	var sickle = item_database.get_item("basic_sickle")
	var axe = item_database.get_item("basic_axe")
	var pickaxe = item_database.get_item("basic_pickaxe")
	var seeds = item_database.get_item("wheat_seeds")
	var sword = item_database.get_item("basic_sword")
	
	if hoe:
		inventory.add_item(hoe, 1)
	if shovel:
		inventory.add_item(shovel, 1)
	if watering_can:
		inventory.add_item(watering_can, 1)
	if sickle:
		inventory.add_item(sickle, 1)
	if axe:
		inventory.add_item(axe, 1)
	if pickaxe:
		inventory.add_item(pickaxe, 1)
	if sword:
		inventory.add_item(sword, 1)
	if seeds:
		inventory.add_item(seeds, 10)
	
	# Give starting crafting materials for testing
	var wood_log = item_database.get_item("wood_log")
	var stone_item = item_database.get_item("stone")
	var string_item = item_database.get_item("string")
	var coal_item = item_database.get_item("coal")
	var iron_nugget = item_database.get_item("iron_nugget")
	
	if wood_log:
		inventory.add_item(wood_log, 10)
	if stone_item:
		inventory.add_item(stone_item, 10)
	if string_item:
		inventory.add_item(string_item, 10)
	if coal_item:
		inventory.add_item(coal_item, 5)
	if iron_nugget:
		inventory.add_item(iron_nugget, 9)

func get_inventory() -> Inventory:
	return inventory

func get_equipment() -> Equipment:
	return equipment

func add_item_to_inventory(item_id: String, quantity: int = 1) -> int:
	if not item_database or not inventory:
		return quantity
	
	var item_data = item_database.get_item(item_id)
	if not item_data:
		return quantity
	
	return inventory.add_item(item_data, quantity)

# Farming methods - delegated to PlayerFarming component
func use_tool(tool_type: String, target: Node) -> bool:
	if farming:
		return farming.use_tool(tool_type, target)
	return false

func plant_seed(plot: FarmPlot, seed_id: String) -> bool:
	if farming:
		return farming.plant_seed(plot, seed_id)
	return false

func add_harvest(result: Dictionary) -> void:
	if farming:
		farming.add_harvest(result)

func can_plant_seed(plot: FarmPlot) -> bool:
	if farming:
		return farming.can_plant_seed(plot)
	return false

func get_available_seeds() -> Array[String]:
	if farming:
		return farming.get_available_seeds()
	return []

# =====================
# STAMINA & HEALTH SYSTEM
# =====================

func _update_stamina(delta: float) -> void:
	var old_stamina = current_stamina
	
	if is_sprinting and move_input.length() > 0:
		# Drain stamina while sprinting
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		stamina_regen_timer = stamina_regen_delay
		
		# Stop sprinting if out of stamina
		if current_stamina <= 0:
			is_sprinting = false
	else:
		# Regenerate stamina after delay
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		else:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	
	# Emit signal if changed
	if abs(old_stamina - current_stamina) > 0.01:
		stamina_changed.emit(current_stamina, max_stamina)

func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_regen_timer = stamina_regen_delay
		stamina_changed.emit(current_stamina, max_stamina)
		return true
	return false

func take_damage(amount: float, _attacker: Node3D = null) -> void:
	var old_health = current_health
	current_health = max(0.0, current_health - amount)
	
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
		print("Player took %.1f damage (%.1f/%.1f HP)" % [amount, current_health, max_health])
	
	if current_health <= 0:
		_on_death()

func heal(amount: float) -> void:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if current_health != old_health:
		health_changed.emit(current_health, max_health)

func _on_death() -> void:
	# For now, just respawn at origin
	print("Player died! Respawning...")
	current_health = max_health
	health_changed.emit(current_health, max_health)
	global_position = Vector3(0, 20, 0)

func get_health_percent() -> float:
	return current_health / max_health

func get_stamina_percent() -> float:
	return current_stamina / max_stamina

# =====================
# SAVE / LOAD
# =====================

func serialize() -> Dictionary:
	var data: Dictionary = {
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"health": current_health,
		"stamina": current_stamina,
	}
	if inventory:
		data["inventory"] = inventory.serialize()
	if equipment:
		data["equipment"] = equipment.serialize()
	var sm = get_node_or_null("/root/SkillManager")
	if sm and sm.has_method("serialize"):
		data["skills"] = sm.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	# Position
	if data.has("position"):
		var pos = data["position"]
		global_position = Vector3(pos.get("x", 0), pos.get("y", 20), pos.get("z", 0))
	# Stats
	current_health = data.get("health", max_health)
	current_stamina = data.get("stamina", max_stamina)
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	# Inventory
	if data.has("inventory") and inventory and item_database:
		inventory.deserialize(data["inventory"])
	# Equipment
	if data.has("equipment") and equipment and item_database:
		equipment.deserialize(data["equipment"], item_database)
	# Skills
	if data.has("skills"):
		var sm = get_node_or_null("/root/SkillManager")
		if sm and sm.has_method("deserialize"):
			sm.deserialize(data["skills"])
