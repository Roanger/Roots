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
const CraftingUIScript = preload("res://src/ui/crafting_ui.gd")
const BaseEnemy = preload("res://src/entities/base_enemy.gd")
const CraftingStationObject = preload("res://src/world/crafting_station_object.gd")
const BaseAnimalScript = preload("res://src/entities/animals/base_animal.gd")
const AnimalDataScript = preload("res://src/entities/animals/animal_data.gd")
var hud: Control = null
var water_plane: MeshInstance3D = null
var skill_tree_ui: Control = null
var crafting_ui: CraftingUI = null

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
	
	# Setup Skill Tree UI
	call_deferred("_setup_skill_tree_ui")
	
	# Setup Crafting UI
	call_deferred("_setup_crafting_ui")
	
	# Spawn enemies
	call_deferred("_spawn_enemies")
	
	# Spawn animals
	call_deferred("_spawn_animals")
	
	# Restore saved data (player inventory/equipment/stats, farm plots)
	call_deferred("_load_player_data")
	call_deferred("_load_farm_plots")
	
	# Connect signals
	if game_manager:
		game_manager.time_changed.connect(_on_time_changed)
		game_manager.day_changed.connect(_on_day_changed)
		game_manager.season_changed.connect(_on_season_changed)
		_update_season_sky(game_manager.current_season)
	
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
	return 25.0  # Default spawn height (adjusted for new terrain range)

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
	water_plane.position = Vector3(0, 16, 0)  # Water level
	
	terrain_container.add_child(water_plane)

func _process(_delta: float) -> void:
	# Handle pause input
	if Input.is_action_just_pressed("pause"):
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
			
			water_plane.position = Vector3(target_x, 16.0 + wave_height, target_z)

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

func _on_season_changed(season: int) -> void:
	_update_season_sky(season)

func _update_season_sky(season: int) -> void:
	if not world_environment or not world_environment.environment:
		return
	var env = world_environment.environment
	if not env.sky or not env.sky.sky_material:
		return
	var sky_mat = env.sky.sky_material
	
	# Season-specific cloud and atmosphere settings
	# GameManager.Season: SPRING=0, SUMMER=1, AUTUMN=2, WINTER=3
	var target_density: float
	var target_cloud_color: Color
	var target_fog_density: float
	
	match season:
		0: # SPRING
			target_density = 1.5
			target_cloud_color = Color(0.8, 0.8, 0.8, 1.0)
			target_fog_density = 0.001
		1: # SUMMER
			target_density = 0.6
			target_cloud_color = Color(0.9, 0.9, 0.95, 1.0)
			target_fog_density = 0.0005
		2: # AUTUMN
			target_density = 2.0
			target_cloud_color = Color(0.7, 0.68, 0.65, 1.0)
			target_fog_density = 0.0015
		3: # WINTER
			target_density = 3.5
			target_cloud_color = Color(0.6, 0.62, 0.65, 1.0)
			target_fog_density = 0.002
		_:
			target_density = 1.5
			target_cloud_color = Color(0.8, 0.8, 0.8, 1.0)
			target_fog_density = 0.001
	
	sky_mat.set_shader_parameter("cloud_density", target_density)
	sky_mat.set_shader_parameter("cloud_color", target_cloud_color)
	env.fog_density = target_fog_density
	
	var season_names = ["Spring", "Summer", "Autumn", "Winter"]
	var sname = season_names[season] if season < season_names.size() else "Unknown"
	print("Season sky updated: ", sname, " (clouds: ", target_density, ", fog: ", target_fog_density, ")")

func _update_lighting(hour: float) -> void:
	# Sun rotation: hour 6 = sunrise (0°), hour 12 = noon (90°), hour 18 = sunset (180°)
	# Negative X rotation arcs the sun overhead (LIGHT0_DIRECTION.y positive = day).
	# Clamp so the sun stays below horizon at night (LIGHT0_DIRECTION.y negative = night).
	var sun_angle = clampf(-((hour - 6.0) * 15.0), -270.0, 15.0)
	sun.rotation_degrees.x = sun_angle
	
	# --- Sun light ---
	var light_energy: float
	var light_color: Color
	
	if hour >= 5.0 and hour < 6.5:
		# Dawn: dark to warm sunrise
		var t = (hour - 5.0) / 1.5
		light_energy = lerp(0.0, 0.7, t)
		light_color = Color(1.0, 0.5, 0.3).lerp(Color(1.0, 0.7, 0.5), t)
	elif hour >= 6.5 and hour < 8.0:
		# Early morning: warm to full daylight
		var t = (hour - 6.5) / 1.5
		light_energy = lerp(0.7, 1.0, t)
		light_color = Color(1.0, 0.7, 0.5).lerp(Color(1.0, 0.95, 0.9), t)
	elif hour >= 8.0 and hour < 17.0:
		# Full day
		light_energy = 1.0
		light_color = Color(1.0, 0.95, 0.9)
	elif hour >= 17.0 and hour < 18.5:
		# Late afternoon: daylight to warm sunset
		var t = (hour - 17.0) / 1.5
		light_energy = lerp(1.0, 0.7, t)
		light_color = Color(1.0, 0.95, 0.9).lerp(Color(1.0, 0.5, 0.25), t)
	elif hour >= 18.5 and hour < 20.0:
		# Dusk: sunset to dark
		var t = (hour - 18.5) / 1.5
		light_energy = lerp(0.7, 0.0, t)
		light_color = Color(1.0, 0.4, 0.2).lerp(Color(0.3, 0.2, 0.4), t)
	else:
		# Night
		light_energy = 0.0
		light_color = Color(0.2, 0.2, 0.4)
	
	sun.light_energy = light_energy
	sun.light_color = light_color
	
	# Sky colors are handled automatically by BinbunSky shader via LIGHT0_DIRECTION
	# Cloud density is set per-season via _update_season_sky()
	
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		
		# --- Ambient light ---
		if hour >= 6.0 and hour < 18.0:
			env.ambient_light_color = Color(0.6, 0.6, 0.7)
			env.ambient_light_energy = 0.5
		elif hour >= 5.0 and hour < 6.0:
			var t = hour - 5.0
			env.ambient_light_color = Color(0.2, 0.2, 0.4).lerp(Color(0.6, 0.6, 0.7), t)
			env.ambient_light_energy = lerp(0.15, 0.5, t)
		elif hour >= 18.0 and hour < 20.0:
			var t = (hour - 18.0) / 2.0
			env.ambient_light_color = Color(0.6, 0.6, 0.7).lerp(Color(0.05, 0.05, 0.1), t)
			env.ambient_light_energy = lerp(0.5, 0.05, t)
		else:
			env.ambient_light_color = Color(0.05, 0.05, 0.1)
			env.ambient_light_energy = 0.05
		
		# --- Fog ---
		if hour >= 6.0 and hour < 18.0:
			env.fog_light_color = Color(0.7, 0.8, 0.9)
		elif hour >= 5.0 and hour < 6.0:
			var t = hour - 5.0
			env.fog_light_color = Color(0.05, 0.04, 0.08).lerp(Color(0.7, 0.8, 0.9), t)
		elif hour >= 18.0 and hour < 20.0:
			var t = (hour - 18.0) / 2.0
			env.fog_light_color = Color(0.7, 0.8, 0.9).lerp(Color(0.05, 0.04, 0.08), t)
		else:
			env.fog_light_color = Color(0.05, 0.04, 0.08)

func save_world() -> void:
	if game_manager:
		game_manager.world_data["terrain"] = _serialize_terrain()
		game_manager.world_data["farm_plots"] = _serialize_farm_plots()
		if player and player.has_method("serialize"):
			game_manager.player_data = player.serialize()
	if save_manager:
		save_manager.save_game()

func _serialize_terrain() -> Dictionary:
	if game_manager:
		return {
			"version": "1.0.0",
			"seed": game_manager.world_seed
		}
	return {"version": "1.0.0", "seed": 0}

func _serialize_farm_plots() -> Array:
	var plots_data: Array = []
	if farm_plots_container:
		for child in farm_plots_container.get_children():
			if child is FarmPlot:
				plots_data.append(child.get_save_data())
	return plots_data

func _load_player_data() -> void:
	if not game_manager or not player:
		return
	if game_manager.player_data.size() > 0 and player.has_method("deserialize"):
		player.deserialize(game_manager.player_data)
		print("Player data restored from save")

func _load_farm_plots() -> void:
	if not game_manager or not farm_plots_container:
		return
	var plots_data = game_manager.world_data.get("farm_plots", [])
	if plots_data.is_empty():
		return
	var crop_db = get_node_or_null("/root/CropDatabase")
	var plots = farm_plots_container.get_children()
	for i in range(min(plots_data.size(), plots.size())):
		if plots[i] is FarmPlot:
			plots[i].load_from_data(plots_data[i], crop_db)
	print("Farm plot data restored from save")

func get_chunk_manager() -> Node:
	return chunk_manager

func get_water_level() -> float:
	return 16.0

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
			hotbar_ui.hotbar_slot_selected.connect(_on_hotbar_slot_selected)
			player_inventory.hotbar_changed.connect(_on_hotbar_contents_changed)
			print("Hotbar UI initialized")
		else:
			print("Warning: Player inventory not found for hotbar")
	else:
		print("Warning: Player doesn't have get_inventory method")

func _on_hotbar_slot_selected(_slot_index: int) -> void:
	if not player or not hotbar_ui:
		return
	var item = hotbar_ui.get_selected_item()
	if player.has_method("update_held_tool"):
		player.update_held_tool(item)

func _on_hotbar_contents_changed(slot_index: int) -> void:
	# When the currently selected hotbar slot's contents change, refresh the player's held item
	if not player or not hotbar_ui:
		return
	if slot_index == hotbar_ui.selected_slot:
		var item = hotbar_ui.get_selected_item()
		if player.has_method("update_held_tool"):
			player.update_held_tool(item)

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

func _setup_skill_tree_ui() -> void:
	if not player:
		return
	await get_tree().process_frame
	
	var ui_container = get_node_or_null("UI")
	if not ui_container:
		return
	
	skill_tree_ui = SkillTreeUI.new()
	skill_tree_ui.name = "SkillTreeUI"
	ui_container.add_child(skill_tree_ui)
	skill_tree_ui.initialize(player)
	print("Skill Tree UI initialized")

func _setup_crafting_ui() -> void:
	if not player:
		return
	await get_tree().process_frame
	
	var ui_container = get_node_or_null("UI")
	if not ui_container:
		return
	
	crafting_ui = CraftingUI.new()
	crafting_ui.name = "CraftingUI"
	ui_container.add_child(crafting_ui)
	crafting_ui.initialize(player.get_inventory())
	
	# Connect EventBus signal so crafting stations can open the UI
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.open_crafting_station.connect(_on_open_crafting_station)
	
	# Spawn starter crafting stations near the player
	call_deferred("_spawn_crafting_stations")
	print("Crafting UI initialized")

func _on_open_crafting_station(station_type: int) -> void:
	if crafting_ui:
		crafting_ui.show_crafting(station_type)

func _spawn_crafting_stations() -> void:
	if not player:
		return
	var spawn_pos = player.global_position
	
	# Workbench - 3m in front of player spawn
	_create_station(spawn_pos + Vector3(3, 0, 0), 1, "Workbench", Color(0.55, 0.35, 0.15))
	# Forge - 5m to the right
	_create_station(spawn_pos + Vector3(5, 0, 2), 2, "Forge", Color(0.3, 0.3, 0.3))
	# Anvil - next to forge
	_create_station(spawn_pos + Vector3(5, 0, 4), 3, "Anvil", Color(0.25, 0.25, 0.3))
	# Alchemy Table - near the other stations
	_create_station(spawn_pos + Vector3(3, 0, 4), 5, "Alchemy Table", Color(0.4, 0.2, 0.5))

func _create_station(pos: Vector3, station_type: int, station_name: String, color: Color) -> void:
	# Snap to terrain height
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		pos.y = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
	
	var container = Node3D.new()
	container.name = station_name
	container.position = pos
	
	# Visual mesh
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.2, 0.8, 0.8)
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.4
	container.add_child(mesh_inst)
	
	# Label
	var label = Label3D.new()
	label.text = station_name
	label.font_size = 32
	label.position.y = 1.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	container.add_child(label)
	
	# Interactable collision (CraftingStationObject)
	var station = CraftingStationObject.new()
	station.name = "StationBody"
	station.station_type = station_type
	station.station_name = station_name
	station.collision_layer = 2
	station.collision_mask = 0
	var col_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 0.8, 0.8)
	col_shape.shape = shape
	col_shape.position.y = 0.4
	station.add_child(col_shape)
	container.add_child(station)
	
	add_child(container)

const SKELETON_MINION = "res://KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Minion.glb"
const SKELETON_WARRIOR = "res://KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Warrior.glb"
const SKELETON_ROGUE = "res://KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Rogue.glb"
const SKELETON_MAGE = "res://KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Mage.glb"

func _spawn_enemies() -> void:
	if not player:
		return
	await get_tree().process_frame
	var spawn_pos = player.global_position
	
	# Skeleton Minions - easy, near spawn (3)
	for i in 3:
		var offset = Vector3(
			randf_range(-15, -8) if i % 2 == 0 else randf_range(8, 15),
			0,
			randf_range(-12, 12)
		)
		_create_enemy(spawn_pos + offset, "Skeleton Minion", 15.0, 1.5, 2.5, 3.0, 1.5, 10.0,
			Color.WHITE, 10.0, [
				{"item_id": "string", "min_amount": 1, "max_amount": 2, "chance": 0.5},
				{"item_id": "stick", "min_amount": 1, "max_amount": 1, "chance": 0.3},
			], SKELETON_MINION, 1.0)
	
	# Skeleton Rogues - fast, medium difficulty (2)
	for i in 2:
		var offset = Vector3(
			randf_range(-22, -14) if i % 2 == 0 else randf_range(14, 22),
			0,
			randf_range(-15, 15)
		)
		_create_enemy(spawn_pos + offset, "Skeleton Rogue", 20.0, 2.5, 4.5, 5.0, 1.5, 12.0,
			Color.WHITE, 18.0, [
				{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.5},
				{"item_id": "string", "min_amount": 1, "max_amount": 3, "chance": 0.6},
			], SKELETON_ROGUE, 1.0)
	
	# Skeleton Warrior - tough melee (1)
	_create_enemy(spawn_pos + Vector3(18, 0, 18), "Skeleton Warrior", 40.0, 1.2, 2.5, 8.0, 1.8, 12.0,
		Color.WHITE, 30.0, [
			{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 3, "chance": 0.7},
			{"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.4},
			{"item_id": "gold_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.15},
		], SKELETON_WARRIOR, 1.0)
	
	# Skeleton Mage - ranged caster, dangerous (1)
	_create_enemy(spawn_pos + Vector3(-20, 0, 16), "Skeleton Mage", 25.0, 1.0, 2.0, 10.0, 2.5, 14.0,
		Color.WHITE, 35.0, [
			{"item_id": "coal", "min_amount": 2, "max_amount": 4, "chance": 0.8},
			{"item_id": "gold_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.25},
			{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.5},
		], SKELETON_MAGE, 1.0)
	
	print("Enemies spawned")

# ── Animal Spawning ──────────────────────────────────────────────────────────

var _animal_species: Dictionary = {}  # species_id -> AnimalData

func _spawn_animals() -> void:
	if not player:
		return
	await get_tree().process_frame
	var spawn_pos = player.global_position
	
	_register_animal_species()
	
	# Farm animals near spawn
	_create_animal("chicken", spawn_pos + Vector3(6, 0, 4))
	_create_animal("chicken", spawn_pos + Vector3(7, 0, 5))
	_create_animal("chicken", spawn_pos + Vector3(5, 0, 6))
	_create_animal("cow", spawn_pos + Vector3(10, 0, -5))
	_create_animal("cow", spawn_pos + Vector3(12, 0, -3))
	_create_animal("sheep", spawn_pos + Vector3(-8, 0, 6))
	_create_animal("sheep", spawn_pos + Vector3(-6, 0, 8))
	_create_animal("goat", spawn_pos + Vector3(-10, 0, -4))
	_create_animal("duck", spawn_pos + Vector3(4, 0, 8))
	_create_animal("duck", spawn_pos + Vector3(3, 0, 10))
	_create_animal("boar", spawn_pos + Vector3(14, 0, 10))
	
	# Wild/huntable animals further out
	_create_animal("deer", spawn_pos + Vector3(25, 0, 20))
	_create_animal("deer", spawn_pos + Vector3(-22, 0, 25))
	_create_animal("rabbit", spawn_pos + Vector3(18, 0, -15))
	_create_animal("rabbit", spawn_pos + Vector3(-16, 0, -18))
	_create_animal("rabbit", spawn_pos + Vector3(20, 0, 12))
	
	print("Animals spawned")

func _register_animal_species() -> void:
	# Chicken
	var chicken = AnimalDataScript.new()
	chicken.species_id = "chicken"
	chicken.display_name = "Chicken"
	chicken.animal_type = AnimalDataScript.AnimalType.FARM
	chicken.max_health = 8.0
	chicken.move_speed = 1.2
	chicken.flee_speed = 3.0
	chicken.wander_radius = 5.0
	chicken.detection_range = 4.0
	chicken.collision_radius = 0.25
	chicken.collision_height = 0.5
	chicken.model_path = "res://Animal QiwiiPack/Animal Models/Chicken.fbx"
	chicken.model_scale = 0.4
	chicken.body_color = Color(0.95, 0.9, 0.8)
	chicken.product_type = AnimalDataScript.ProductType.EGG
	chicken.product_item_id = "egg"
	chicken.product_interval = 90.0
	chicken.product_amount = 1
	chicken.feed_item_ids = ["animal_feed", "wheat"]
	chicken.loot_table = [
		{"item_id": "raw_meat", "min_amount": 1, "max_amount": 1, "chance": 0.8},
		{"item_id": "feathers", "min_amount": 1, "max_amount": 3, "chance": 1.0},
	]
	chicken.xp_reward = 5.0
	_animal_species["chicken"] = chicken
	
	# Cow (Holstein)
	var cow = AnimalDataScript.new()
	cow.species_id = "cow"
	cow.display_name = "Cow"
	cow.animal_type = AnimalDataScript.AnimalType.FARM
	cow.max_health = 40.0
	cow.move_speed = 1.0
	cow.flee_speed = 2.5
	cow.wander_radius = 8.0
	cow.detection_range = 5.0
	cow.collision_radius = 0.5
	cow.collision_height = 1.4
	cow.model_path = "res://Animal QiwiiPack/Animal Models/Cow.fbx"
	cow.model_scale = 0.6
	cow.body_color = Color(0.9, 0.85, 0.8)
	cow.product_type = AnimalDataScript.ProductType.MILK
	cow.product_item_id = "milk"
	cow.product_interval = 120.0
	cow.product_amount = 1
	cow.feed_item_ids = ["animal_feed", "wheat", "carrot_raw"]
	cow.loot_table = [
		{"item_id": "raw_meat", "min_amount": 2, "max_amount": 4, "chance": 1.0},
		{"item_id": "leather", "min_amount": 1, "max_amount": 2, "chance": 0.8},
	]
	cow.xp_reward = 8.0
	_animal_species["cow"] = cow
	
	# Sheep
	var sheep = AnimalDataScript.new()
	sheep.species_id = "sheep"
	sheep.display_name = "Sheep"
	sheep.animal_type = AnimalDataScript.AnimalType.FARM
	sheep.max_health = 20.0
	sheep.move_speed = 1.2
	sheep.flee_speed = 3.0
	sheep.wander_radius = 7.0
	sheep.detection_range = 5.0
	sheep.collision_radius = 0.4
	sheep.collision_height = 1.0
	sheep.model_path = "res://Animal QiwiiPack/Animal Models/Sheep White.fbx"
	sheep.model_scale = 0.5
	sheep.body_color = Color(0.95, 0.95, 0.9)
	sheep.product_type = AnimalDataScript.ProductType.WOOL
	sheep.product_item_id = "wool"
	sheep.product_interval = 150.0
	sheep.product_amount = 1
	sheep.feed_item_ids = ["animal_feed", "wheat"]
	sheep.loot_table = [
		{"item_id": "raw_meat", "min_amount": 1, "max_amount": 2, "chance": 1.0},
		{"item_id": "wool", "min_amount": 1, "max_amount": 3, "chance": 0.9},
	]
	sheep.xp_reward = 6.0
	_animal_species["sheep"] = sheep
	
	# Goat
	var goat = AnimalDataScript.new()
	goat.species_id = "goat"
	goat.display_name = "Goat"
	goat.animal_type = AnimalDataScript.AnimalType.FARM
	goat.max_health = 25.0
	goat.move_speed = 1.5
	goat.flee_speed = 3.5
	goat.wander_radius = 8.0
	goat.detection_range = 6.0
	goat.collision_radius = 0.35
	goat.collision_height = 0.9
	goat.model_scale = 1.0
	goat.body_color = Color(0.75, 0.7, 0.6)
	goat.product_type = AnimalDataScript.ProductType.MILK
	goat.product_item_id = "milk"
	goat.product_interval = 140.0
	goat.product_amount = 1
	goat.feed_item_ids = ["animal_feed", "wheat", "carrot_raw"]
	goat.loot_table = [
		{"item_id": "raw_meat", "min_amount": 1, "max_amount": 2, "chance": 1.0},
		{"item_id": "leather", "min_amount": 1, "max_amount": 1, "chance": 0.6},
	]
	goat.xp_reward = 6.0
	_animal_species["goat"] = goat
	
	# Duck (Pekin)
	var duck = AnimalDataScript.new()
	duck.species_id = "duck"
	duck.display_name = "Duck"
	duck.animal_type = AnimalDataScript.AnimalType.FARM
	duck.max_health = 8.0
	duck.move_speed = 1.3
	duck.flee_speed = 3.0
	duck.wander_radius = 6.0
	duck.detection_range = 4.0
	duck.collision_radius = 0.25
	duck.collision_height = 0.5
	duck.model_path = "res://Animal QiwiiPack/Animal Models/Chick.fbx"
	duck.model_scale = 0.5
	duck.body_color = Color(0.95, 0.92, 0.75)
	duck.product_type = AnimalDataScript.ProductType.EGG
	duck.product_item_id = "egg"
	duck.product_interval = 100.0
	duck.product_amount = 1
	duck.feed_item_ids = ["animal_feed", "wheat"]
	duck.loot_table = [
		{"item_id": "raw_meat", "min_amount": 1, "max_amount": 1, "chance": 0.8},
		{"item_id": "feathers", "min_amount": 1, "max_amount": 2, "chance": 1.0},
	]
	duck.xp_reward = 5.0
	_animal_species["duck"] = duck
	
	# Boar (wild pig, tameable)
	var boar = AnimalDataScript.new()
	boar.species_id = "boar"
	boar.display_name = "Boar"
	boar.animal_type = AnimalDataScript.AnimalType.FARM
	boar.max_health = 30.0
	boar.move_speed = 1.4
	boar.flee_speed = 4.0
	boar.wander_radius = 10.0
	boar.detection_range = 6.0
	boar.collision_radius = 0.45
	boar.collision_height = 0.9
	boar.model_path = "res://Animal QiwiiPack/Animal Models/Pig.fbx"
	boar.model_scale = 0.5
	boar.body_color = Color(0.5, 0.35, 0.25)
	boar.product_type = AnimalDataScript.ProductType.NONE
	boar.feed_item_ids = ["animal_feed", "carrot_raw", "potato"]
	boar.loot_table = [
		{"item_id": "raw_meat", "min_amount": 2, "max_amount": 4, "chance": 1.0},
		{"item_id": "leather", "min_amount": 1, "max_amount": 2, "chance": 0.7},
	]
	boar.xp_reward = 10.0
	_animal_species["boar"] = boar
	
	# Deer (wild, huntable)
	var deer = AnimalDataScript.new()
	deer.species_id = "deer"
	deer.display_name = "Deer"
	deer.animal_type = AnimalDataScript.AnimalType.HUNTABLE
	deer.max_health = 25.0
	deer.move_speed = 2.0
	deer.flee_speed = 5.5
	deer.wander_radius = 12.0
	deer.detection_range = 10.0
	deer.collision_radius = 0.4
	deer.collision_height = 1.3
	deer.model_scale = 1.0
	deer.body_color = Color(0.6, 0.45, 0.3)
	deer.product_type = AnimalDataScript.ProductType.NONE
	deer.loot_table = [
		{"item_id": "venison", "min_amount": 2, "max_amount": 3, "chance": 1.0},
		{"item_id": "deer_pelt", "min_amount": 1, "max_amount": 1, "chance": 0.8},
		{"item_id": "leather", "min_amount": 1, "max_amount": 2, "chance": 0.5},
	]
	deer.xp_reward = 15.0
	deer.xp_skill = "combat"
	_animal_species["deer"] = deer
	
	# Rabbit (wild, huntable)
	var rabbit = AnimalDataScript.new()
	rabbit.species_id = "rabbit"
	rabbit.display_name = "Rabbit"
	rabbit.animal_type = AnimalDataScript.AnimalType.HUNTABLE
	rabbit.max_health = 6.0
	rabbit.move_speed = 2.5
	rabbit.flee_speed = 6.0
	rabbit.wander_radius = 8.0
	rabbit.detection_range = 8.0
	rabbit.collision_radius = 0.2
	rabbit.collision_height = 0.4
	rabbit.model_scale = 1.0
	rabbit.body_color = Color(0.7, 0.6, 0.5)
	rabbit.product_type = AnimalDataScript.ProductType.NONE
	rabbit.loot_table = [
		{"item_id": "rabbit_meat", "min_amount": 1, "max_amount": 1, "chance": 1.0},
		{"item_id": "rabbit_fur", "min_amount": 1, "max_amount": 1, "chance": 0.7},
	]
	rabbit.xp_reward = 8.0
	rabbit.xp_skill = "combat"
	_animal_species["rabbit"] = rabbit

func _create_animal(species_id: String, pos: Vector3, tamed: bool = false, baby: bool = false) -> void:
	var data = _animal_species.get(species_id)
	if not data:
		push_warning("Unknown animal species: %s" % species_id)
		return
	
	# Snap to terrain height
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		var terrain_y = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
		pos.y = terrain_y
	else:
		pos.y = 30.0
	
	var animal = BaseAnimalScript.new()
	animal.setup(data, tamed, baby)
	animal.position = pos
	add_child(animal)

func _create_enemy(pos: Vector3, ename: String, health: float, spd: float,
		chase_spd: float, dmg: float, atk_range: float, detect: float,
		color: Color, xp: float, loot: Array,
		emodel: String = "", escale: float = 1.0) -> void:
	# Snap to terrain height
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		var terrain_y = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
		pos.y = terrain_y
	else:
		pos.y = 30.0
	
	var enemy = BaseEnemy.new()
	enemy.enemy_name = ename
	enemy.max_health = health
	enemy.move_speed = spd
	enemy.chase_speed = chase_spd
	enemy.attack_damage = dmg
	enemy.attack_range = atk_range
	enemy.detection_range = detect
	enemy.body_color = color
	enemy.xp_reward = xp
	enemy.loot_table = loot
	enemy.model_path = emodel
	enemy.model_scale = escale
	enemy.position = pos
	add_child(enemy)

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
		
		# K key to toggle skill tree
		elif event.keycode == KEY_K:
			if skill_tree_ui:
				if skill_tree_ui.visible:
					skill_tree_ui.close()
				else:
					skill_tree_ui.open()
				get_viewport().set_input_as_handled()
		
		# R key to toggle crafting
		elif event.keycode == KEY_R:
			if crafting_ui:
				if crafting_ui.visible:
					crafting_ui.close()
				else:
					crafting_ui.show_crafting()
				get_viewport().set_input_as_handled()
