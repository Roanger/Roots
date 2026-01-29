extends CharacterBody3D
## Player Controller - Handles all player movement and interaction

signal position_changed(new_position: Vector3)
signal state_changed(new_state: PlayerState)

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

func _ready() -> void:
	add_to_group("player")
	
	# Camera position is handled by CameraController
	# Don't set it here to avoid conflicts
	
	# Setup raycast
	raycast.target_position = Vector3(0, 0, -3)
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

func _input(event: InputEvent) -> void:
	# Camera is handled by CameraController
	
	if event.is_action_pressed("jump"):
		if is_on_ground and not is_crouching:
			_jump()
	
	if event.is_action_pressed("interact"):
		_interact()
	
	if event.is_action_pressed("crouch"):
		_toggle_crouch()

func _physics_process(delta: float) -> void:
	_handle_movement_input()
	_apply_gravity(delta)
	_update_terrain_height()
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
	match plot.state:
		FarmPlot.PlotState.EMPTY:
			# Use hoe to till
			use_tool("hoe", plot)
			_set_state(PlayerState.USING_TOOL)
		FarmPlot.PlotState.TILLED:
			# Plant seed (use first available)
			var seeds = get_available_seeds()
			if seeds.size() > 0:
				plant_seed(plot, seeds[0])
			_set_state(PlayerState.INTERACTING)
		FarmPlot.PlotState.GROWING, FarmPlot.PlotState.PLANTED:
			# Water if not watered
			if not plot.is_watered:
				use_tool("watering_can", plot)
				_set_state(PlayerState.USING_TOOL)
		FarmPlot.PlotState.READY_FOR_HARVEST:
			# Harvest with sickle
			use_tool("sickle", plot)
			_set_state(PlayerState.USING_TOOL)

func _check_interaction() -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider != interaction_target:
			interaction_target = collider
			# Show interaction prompt if applicable
	else:
		interaction_target = null

func _process_tool_use() -> void:
	# Check if player is using a tool
	if Input.is_action_pressed("interact"):
		if current_tool != "":
			_use_tool()
			_set_state(PlayerState.USING_TOOL)
	elif current_state == PlayerState.USING_TOOL:
		_set_state(PlayerState.IDLE)

func _use_tool() -> void:
	# Tool use logic - will be expanded with farming/crafting
	pass

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
	var seeds = item_database.get_item("wheat_seeds")
	
	if hoe:
		inventory.add_item(hoe, 1)
	if shovel:
		inventory.add_item(shovel, 1)
	if watering_can:
		inventory.add_item(watering_can, 1)
	if seeds:
		inventory.add_item(seeds, 10)

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

# Farming methods
func use_tool(tool_type: String, target: Node) -> bool:
	match tool_type:
		"hoe":
			if target is FarmPlot:
				return target.till_soil()
		"watering_can":
			if target is FarmPlot:
				return target.water()
		"sickle":
			if target is FarmPlot and target.state == FarmPlot.PlotState.READY_FOR_HARVEST:
				var result = target.harvest()
				add_harvest(result)
				return true
	return false

func plant_seed(plot: FarmPlot, seed_id: String) -> bool:
	if not crop_database or not inventory:
		return false
	
	# Check if player has seeds
	if not inventory.has_item(seed_id, 1):
		return false
	
	# Get crop data from seed
	var crop_data = crop_database.get_crop_from_seed(seed_id)
	if not crop_data:
		return false
	
	# Try to plant
	if plot.plant_seed(seed_id, crop_data):
		# Remove one seed from inventory
		inventory.remove_item(seed_id, 1)
		return true
	
	return false

func add_harvest(result: Dictionary) -> void:
	if result.is_empty():
		return
	
	var produce_id = result.get("produce_id", "")
	var produce_amount = result.get("produce_amount", 0)
	var seed_returned = result.get("seed_returned", false)
	var seed_id = result.get("seed_id", "")
	
	# Add produce
	if produce_id and produce_amount > 0:
		var overflow = add_item_to_inventory(produce_id, produce_amount)
		if overflow > 0:
			print("Inventory full! Dropped ", overflow, " ", produce_id)
	
	# Return seed
	if seed_returned and seed_id:
		add_item_to_inventory(seed_id, 1)

func can_plant_seed(plot: FarmPlot) -> bool:
	return plot.state == FarmPlot.PlotState.TILLED or plot.state == FarmPlot.PlotState.EMPTY

func get_available_seeds() -> Array[String]:
	var seeds: Array[String] = []
	if not inventory:
		return seeds
	
	for i in range(inventory.max_slots):
		var item = inventory.get_slot(i)
		if item and item.item_data and item.item_data.item_type == ItemData.ItemType.SEED:
			seeds.append(item.item_data.item_id)
	
	return seeds
