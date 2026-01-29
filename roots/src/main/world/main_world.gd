extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var terrain_container: Node3D = $TerrainContainer
@onready var chunk_manager: Node = $ChunkManager
@onready var farm_plots_container: Node3D = $FarmPlots
@onready var inventory_ui: Control = $UI/InventoryUI
@onready var character_ui: Control = $UI/CharacterUI
@onready var hotbar_ui: Control = $UI/HotbarUI

var hud_scene = preload("res://src/ui/hud/hud.tscn")
var hud: Control = null
var water_plane: MeshInstance3D = null

# Explicit references to autoload singletons
@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var save_manager: Node = get_node_or_null("/root/SaveManager")

func _ready() -> void:
	# Set game state to playing
	if game_manager:
		game_manager.set_game_state(game_manager.GameState.PLAYING)
	
	# Initialize world first (generates terrain)
	_initialize_world()
	
	# Setup player after terrain is ready
	if player:
		player.capture_mouse()
		player.set_chunk_manager(chunk_manager)
		# Find spawn point on terrain (after chunks are generated)
		call_deferred("_spawn_player")
	
	# Position farm plots on terrain after chunks are generated
	call_deferred("_position_farm_plots")
	
	# Setup inventory UI
	call_deferred("_setup_inventory_ui")
	
	# Setup character UI
	call_deferred("_setup_character_ui")
	
	# Setup hotbar UI
	call_deferred("_setup_hotbar_ui")
	
	# Setup HUD
	call_deferred("_setup_hud")
	
	# Connect signals
	if game_manager:
		game_manager.time_changed.connect(_on_time_changed)
		game_manager.day_changed.connect(_on_day_changed)
	
	if game_manager:
		print("Main World loaded - Seed: ", game_manager.world_seed)

func _spawn_player() -> void:
	# Wait a frame for chunks to generate, then spawn player
	await get_tree().process_frame
	
	if player:
		var spawn_height = _find_spawn_height()
		player.position = Vector3(0, spawn_height + 5, 0)  # Spawn higher above terrain
		print("Player spawned at height: ", spawn_height + 5)

func _initialize_world() -> void:
	# Create water plane - DISABLED FOR TESTING
	# _create_water_plane()
	
	# Setup chunk manager
	if chunk_manager:
		chunk_manager.terrain_container = terrain_container
		chunk_manager.player_node = player
		if chunk_manager.has_method("force_update"):
			chunk_manager.force_update()
	
	# Setup initial lighting
	if game_manager:
		_update_lighting(game_manager.current_hour)

func _find_spawn_height() -> float:
	# Get terrain height at spawn point from chunk manager
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		return chunk_manager.get_terrain_height(Vector3(0, 0, 0))
	return 15.0  # Default spawn height

func _position_farm_plots() -> void:
	# Wait a few frames for chunks to generate, then position farm plots
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not farm_plots_container or not chunk_manager:
		return
	
	if not chunk_manager.has_method("get_terrain_height"):
		print("Warning: ChunkManager doesn't have get_terrain_height method")
		return
	
	# Position each farm plot on the terrain
	for child in farm_plots_container.get_children():
		if child is FarmPlot:
			var plot: FarmPlot = child
			var current_pos = plot.global_position
			# Get terrain height at the plot's X/Z position
			var terrain_height = chunk_manager.get_terrain_height(Vector3(current_pos.x, 0, current_pos.z))
			
			# If terrain height is 0, chunks might not be loaded yet - wait a bit more
			if terrain_height == 0.0:
				# Wait a bit more and try again
				await get_tree().create_timer(0.1).timeout
				terrain_height = chunk_manager.get_terrain_height(Vector3(current_pos.x, 0, current_pos.z))
			
			# Position plot on top of terrain (plot height is 0.2, so center it at 0.1 above terrain)
			plot.global_position = Vector3(current_pos.x, terrain_height + 0.1, current_pos.z)
			print("Positioned farm plot at ", plot.global_position, " (terrain height: ", terrain_height, ")")

func _create_water_plane() -> void:
	water_plane = MeshInstance3D.new()
	water_plane.name = "WaterPlane"
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2000, 2000)
	water_plane.mesh = plane_mesh
	
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.2, 0.4, 0.7, 0.8)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.1
	water_material.metallic = 0.3
	water_material.emission_enabled = true
	water_material.emission = Color(0.1, 0.2, 0.4)
	water_material.emission_energy_multiplier = 0.2
	
	water_plane.material_override = water_material
	water_plane.position = Vector3(0, 10, 0)  # Water level
	
	terrain_container.add_child(water_plane)

func _process(_delta: float) -> void:
	# Handle pause input
	if Input.is_action_pressed("pause"):
		_toggle_pause()
	
	# Animate water
	if water_plane:
		var time = Time.get_ticks_msec() / 1000.0
		var mat = water_plane.material_override as StandardMaterial3D
		if mat:
			var wave_height = sin(time * 0.5) * 0.1
			# Make water follow player on X/Z but stay at water level + wave height on Y
			var target_x = 0.0
			var target_z = 0.0
			if player:
				target_x = player.global_position.x
				target_z = player.global_position.z
			
			water_plane.position = Vector3(target_x, 10.0 + wave_height, target_z)

func _toggle_pause() -> void:
	if not game_manager:
		return
		
	if game_manager.current_state == game_manager.GameState.PLAYING:
		game_manager.set_game_state(game_manager.GameState.PAUSED)
	elif game_manager.current_state == game_manager.GameState.PAUSED:
		game_manager.set_game_state(game_manager.GameState.PLAYING)

func _on_time_changed(hour: float) -> void:
	_update_lighting(hour)

func _on_day_changed(day: int) -> void:
	if game_manager:
		print("Day ", day, " - Season: ", game_manager.get_season_name())

func _update_lighting(hour: float) -> void:
	var sun_angle = (hour - 6.0) * 15.0
	sun.rotation_degrees.x = sun_angle
	
	var light_energy: float
	var light_color: Color
	
	if hour >= 5 and hour < 7:
		light_energy = 0.5 + (hour - 5.0) * 0.5
		light_color = Color(1.0, 0.6, 0.4)
	elif hour >= 7 and hour < 18:
		light_energy = 1.0
		light_color = Color(1.0, 0.95, 0.9)
	elif hour >= 18 and hour < 20:
		light_energy = 1.0 - (hour - 18.0) * 0.5
		light_color = Color(1.0, 0.4, 0.3)
	else:
		light_energy = 0.0
		light_color = Color(0.2, 0.2, 0.4)
	
	sun.light_energy = light_energy
	sun.light_color = light_color
	
	# Update ambient light
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		if hour >= 6 and hour < 18:
			env.ambient_light_color = Color(0.6, 0.6, 0.7)
			env.ambient_light_energy = 0.5
		else:
			env.ambient_light_color = Color(0.2, 0.2, 0.4)
			env.ambient_light_energy = 0.2

func save_world() -> void:
	if game_manager:
		game_manager.world_data["terrain"] = _serialize_terrain()
	if save_manager:
		save_manager.save_game()

func _serialize_terrain() -> Dictionary:
	if game_manager:
		return {
			"version": "1.0.0",
			"seed": game_manager.world_seed
		}
	return {"version": "1.0.0", "seed": 0}

func get_chunk_manager() -> Node:
	return chunk_manager

func get_water_level() -> float:
	return 10.0

func _setup_inventory_ui() -> void:
	if not inventory_ui or not player:
		return
	
	# Wait for player to be ready
	await get_tree().process_frame
	
	# Get player's inventory
	if player.has_method("get_inventory"):
		var player_inventory = player.get_inventory()
		if player_inventory:
			inventory_ui.initialize(player_inventory, player)
			print("Inventory UI initialized")
		else:
			print("Warning: Player inventory not found")
	else:
		print("Warning: Player doesn't have get_inventory method")

func _setup_character_ui() -> void:
	if not character_ui or not player:
		return
	
	# Wait for player to be ready
	await get_tree().process_frame
	
	# Get player's equipment
	if player.has_method("get_equipment"):
		var player_equipment = player.get_equipment()
		if player_equipment:
			character_ui.initialize(player_equipment, player)
			print("Character UI initialized")
		else:
			print("Warning: Player equipment not found")
	else:
		print("Warning: Player doesn't have get_equipment method")

func _setup_hotbar_ui() -> void:
	if not hotbar_ui or not player:
		return
	
	# Wait for player to be ready
	await get_tree().process_frame
	
	# Get player's inventory
	if player.has_method("get_inventory"):
		var player_inventory = player.get_inventory()
		if player_inventory:
			hotbar_ui.initialize(player_inventory)
			print("Hotbar UI initialized")
		else:
			print("Warning: Player inventory not found for hotbar")
	else:
		print("Warning: Player doesn't have get_inventory method")

func _setup_hud() -> void:
	if not player:
		return
	
	# Wait for player to be ready
	await get_tree().process_frame
	
	# Instance HUD and add to UI layer
	hud = hud_scene.instantiate()
	$UI.add_child(hud)
	
	# Initialize with player reference
	if hud.has_method("initialize"):
		hud.initialize(player)

func _input(event: InputEvent) -> void:
	# Handle Tab key to toggle both inventory and character UI
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			var inventory_open = inventory_ui and inventory_ui.visible
			var character_open = character_ui and character_ui.visible
			
			# If both are closed, open both
			if not inventory_open and not character_open:
				if inventory_ui:
					inventory_ui.open()
				if character_ui:
					character_ui.open()
			# If either is open, close both
			else:
				if inventory_ui and inventory_ui.visible:
					inventory_ui.close()
				if character_ui and character_ui.visible:
					character_ui.close()
			
			get_viewport().set_input_as_handled()
