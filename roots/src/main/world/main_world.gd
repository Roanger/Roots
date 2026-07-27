extends Node3D

@onready var music_player: AudioStreamPlayer = $MusicPlayer
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
const HerbariumUIScript = preload("res://src/ui/herbarium_ui.gd")
const BaseEnemy = preload("res://src/entities/base_enemy.gd")
const CraftingStationObject = preload("res://src/world/crafting_station_object.gd")
const BaseAnimalScript = preload("res://src/entities/animals/base_animal.gd")
const AnimalDataScript = preload("res://src/entities/animals/animal_data.gd")
const TownBuilderScript = preload("res://src/world/town_builder.gd")
const BaseNPCScript = preload("res://src/entities/npcs/base_npc.gd")
const NPCDataScript = preload("res://src/entities/npcs/npc_data.gd")
const DialogueUIScript = preload("res://src/ui/dialogue_ui.gd")
const ShopUIScript = preload("res://src/ui/shop_ui.gd")
const QuestJournalUIScript = preload("res://src/ui/quest_journal_ui.gd")
const NotificationPopupScript = preload("res://src/ui/notification_popup.gd")
const WeatherEffectsScript = preload("res://src/world/weather_effects.gd")
const InteriorManagerScript = preload("res://src/world/interior_manager.gd")
const CommunityCenterObject = preload("res://src/world/community_center_object.gd")
const HouseObjectScript = preload("res://src/world/house_object.gd")
var hud: Control = null
var town_builder: Node3D = null
var water_plane: MeshInstance3D = null
var skill_tree_ui: Control = null
var crafting_ui: CraftingUI = null
var herbarium_ui: Control = null
var dialogue_ui: Control = null
var shop_ui: Control = null
var quest_journal_ui: Control = null
var notification_popup: Control = null
var weather_effects: Node3D = null

# Underground ambient state
var _is_player_underground: bool = false
var _surface_ambient_energy: float = 0.5   # Cached surface ambient (set by _update_lighting)
var _surface_ambient_color: Color = Color(0.6, 0.6, 0.7)

# Water shader globals
const WATER_SUN_DIRECTION_PARAM: StringName = "sun_direction"
const WATER_SUN_COLOR_PARAM: StringName = "sun_color"

# Biome climate atmosphere
var _current_player_biome: int = -1
var _displayed_biome_fog: Color = Color(0.7, 0.8, 0.9)
var _target_biome_fog: Color = Color(0.7, 0.8, 0.9)
var _biome_check_timer: float = 0.0

# Reputation system
var _reputation: Dictionary = {}  # npc_id -> int (-100 to 100)

# Village placement (computed from terrain to avoid water)
var _village_center: Vector3 = Vector3(25, 0, 0)

# Dynamic wildlife (wild animals follow chunk lifecycle)
var _wildlife_by_chunk: Dictionary = {}  # Vector2i -> Array[BaseAnimal]
var _night_spawn_timer: float = 0.0
var _night_spawn_interval: float = 25.0  # seconds between night spawn waves
var _is_night: bool = false

# Wild animal spawn rules per species: which biomes and how many
const WILD_SPAWN_RULES: Dictionary = {
	"deer":		{ "biomes": [3, 8],		"count_range": [1, 2], "spawn_chance": 0.5 },
	"rabbit":	{ "biomes": [2, 3, 8],		"count_range": [1, 3], "spawn_chance": 0.7 },
	"boar":		{ "biomes": [2, 3, 8],		"count_range": [1, 1], "spawn_chance": 0.25 },
	"wolf":		{ "biomes": [3, 5, 9, 6],	"count_range": [0, 1], "spawn_chance": 0.12 },
	"duck":		{ "biomes": [1, 8],		"count_range": [1, 2], "spawn_chance": 0.35 },
	"goat":		{ "biomes": [6, 9],		"count_range": [1, 1], "spawn_chance": 0.25 },
}

# Explicit references to autoload singletons
@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var save_manager: Node = get_node_or_null("/root/SaveManager")

func _ready() -> void:
	# Set game state to playing
	if game_manager:
		game_manager.set_game_state(game_manager.GameState.PLAYING)
	
	# Register nodes in groups for Settings singleton to find
	if world_environment:
		world_environment.add_to_group("world_environment")
	if sun:
		sun.add_to_group("sun")
	if chunk_manager:
		chunk_manager.add_to_group("chunk_manager")
	
	# Start world music
	_start_world_music()
	
	# Set up global shader parameters for water shader before chunks generate
	_setup_water_shader_globals()
	
	# Find a dry spot for the village, then register the exclusion zone
	_village_center = _find_village_position()
	if chunk_manager and chunk_manager.has_method("add_exclusion_zone"):
		chunk_manager.add_exclusion_zone(_village_center, 22.0)
	
	# Connect chunk signals
	if chunk_manager:
		chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
		chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	
	# Initialize world — starts VoxelLodTerrain generation
	_initialize_world()
	
	# Setup player basics (no terrain-dependent positioning yet)
	if player:
		player.capture_mouse()
		player.set_chunk_manager(chunk_manager)
		player.set_physics_process(false)  # Disable gravity until terrain is ready
	
	# Connect time/day/season signals
	if game_manager:
		game_manager.time_changed.connect(_on_time_changed)
		game_manager.day_changed.connect(_on_day_changed)
		game_manager.season_changed.connect(_on_season_changed)
		_update_season_sky(game_manager.current_season)
	
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.player_underground_changed.connect(_on_player_underground_changed)
	
	if save_manager and save_manager.has_signal("save_started"):
		save_manager.save_started.connect(prepare_save_data)
	
	# Show loading screen while terrain generates
	_show_loading_screen()
	
	# Start terrain-ready wait — spawns everything once chunks are ready
	call_deferred("_on_terrain_ready")
	
	if game_manager:
		print("Main World loaded - Seed: ", game_manager.world_seed)

func _show_loading_screen() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "LoadingScreen"
	overlay.layer = 128
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var label := Label.new()
	label.text = "Building World"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	label.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(label)

	if game_manager:
		var seed_label := Label.new()
		seed_label.text = "Seed: %d" % game_manager.world_seed
		seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seed_label.add_theme_font_size_override("font_size", 16)
		seed_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
		seed_label.set_anchors_preset(Control.PRESET_CENTER)
		seed_label.position = Vector2(0, 40)
		overlay.add_child(seed_label)


func _hide_loading_screen() -> void:
	var overlay = get_node_or_null("LoadingScreen")
	if overlay:
		overlay.queue_free()


func _on_terrain_ready() -> void:
	## Waits for VoxelLodTerrain to generate terrain collision around the
	## player spawn point, then spawns everything and hides loading screen.
	await get_tree().process_frame

	# Find spawn point now (CPU noise, works before voxel blocks exist)
	var spawn_pos := _find_spawn_position()

	# Raycast from above the spawn point to detect when terrain collision
	# actually exists (VoxelLodTerrain streams blocks asynchronously)
	var origin := Vector3(spawn_pos.x, spawn_pos.y + 100, spawn_pos.z)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = Vector3(spawn_pos.x, spawn_pos.y - 20, spawn_pos.z)
	query.collision_mask = 1
	for _attempt in 120:
		var space := player.get_world_3d().direct_space_state if player else null
		if space:
			var result := space.intersect_ray(query)
			if result:
				break
		await get_tree().create_timer(0.1).timeout

	# Extra frames for secondary collision shapes
	await get_tree().process_frame
	await get_tree().process_frame

	# --- Spawn everything ---
	_spawn_player()
	_position_farm_plots()
	_setup_inventory_ui()
	_setup_character_ui()
	_setup_hotbar_ui()
	_setup_hud()
	_setup_skill_tree_ui()
	_setup_crafting_ui()
	_setup_herbarium_ui()
	_spawn_enemies()
	_spawn_animals()
	_setup_interior_manager()
	_build_village()
	_init_quest_system()
	_spawn_npcs()
	_setup_dialogue_ui()
	_setup_shop_ui()
	_setup_quest_journal_ui()
	_setup_notification_ui()
	_setup_reputation()
	_setup_weather()
	_load_player_data()
	_load_farm_plots()
	_load_placed_objects()

	_hide_loading_screen()
	print("Terrain ready — all entities spawned")

func _start_world_music() -> void:
	if not music_player:
		return
	var stream := preload("res://assets/Music/Shaggs Farm Game Song 1 Ver 2.mp3")
	if stream:
		music_player.stream = stream
		music_player.bus = &"Music"
		var settings_node = get_node_or_null("/root/Settings")
		var vol := 0.7
		if settings_node:
			vol = float(settings_node.get_setting("audio", "music_volume", 0.7))
		music_player.volume_db = linear_to_db(vol)
		music_player.play()

func _setup_water_shader_globals() -> void:
	# Avoid re-adding globals if MainWorld is reloaded in the same session
	var existing_dir = RenderingServer.global_shader_parameter_get(WATER_SUN_DIRECTION_PARAM)
	if existing_dir == null:
		RenderingServer.global_shader_parameter_add(WATER_SUN_DIRECTION_PARAM, RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.25, 0.8, 0.55))
	var existing_col = RenderingServer.global_shader_parameter_get(WATER_SUN_COLOR_PARAM)
	if existing_col == null:
		RenderingServer.global_shader_parameter_add(WATER_SUN_COLOR_PARAM, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1.0, 0.95, 0.85, 1.0))
	_update_water_shader_globals()

func _update_water_shader_globals() -> void:
	if not sun:
		return
	var sun_dir := -sun.global_transform.basis.z.normalized()
	RenderingServer.global_shader_parameter_set(WATER_SUN_DIRECTION_PARAM, sun_dir)
	var energy := sun.light_energy if sun.light_energy > 0.0 else 0.0
	var col := sun.light_color
	RenderingServer.global_shader_parameter_set(WATER_SUN_COLOR_PARAM, Vector4(col.r, col.g, col.b, energy))

func _spawn_player() -> void:
	# Wait a frame for chunks to generate, then spawn player
	await get_tree().process_frame
	
	if player:
		var spawn_pos = _find_spawn_position()
		player.position = Vector3(spawn_pos.x, spawn_pos.y + 5, spawn_pos.z)
		player.set_physics_process(true)  # Re-enable gravity now that terrain exists
		print("Player spawned at: ", player.position)

func _initialize_world() -> void:
	# Create water plane at sea level
	_create_water_plane()
	
	# Setup terrain service
	if chunk_manager:
		chunk_manager.player_node = player
	
	# Setup initial lighting
	if game_manager:
		_update_lighting(game_manager.current_hour)

func _find_spawn_position() -> Vector3:
	## Search for dry land near the origin.  Expands outward in rings until
	## a position above sea level with a non-water biome is found.
	if not chunk_manager or not chunk_manager.has_method("get_terrain_height") or not chunk_manager.has_method("get_biome_at"):
		return Vector3(0, 25, 0)
	var step := 8
	var max_radius := 80
	for r in range(0, max_radius + 1, step):
		var edge := r + step
		for x in range(-edge, edge + 1, step):
			for z in range(-edge, edge + 1, step):
				if absf(x) <= r and absf(z) <= r:
					continue
				var biome: int = chunk_manager.get_biome_at(Vector3(x, 0, z))
				if biome <= 1:
					continue
				var h: float = chunk_manager.get_terrain_height(Vector3(x, 0, z))
				if h > 0.5:
					return Vector3(x, h, z)
	return Vector3(0, 25, 0)

func _find_village_position() -> Vector3:
	## Search for dry land starting at (25, 0, 0).  Expands outward in rings
	## until a position whose entire 16m footprint is above sea level.
	const VILLAGE_RADIUS: float = 16.0
	if not chunk_manager or not chunk_manager.has_method("get_terrain_height") or not chunk_manager.has_method("get_biome_at"):
		return Vector3(25, 0, 0)

	# Try default first
	if _is_dry_footprint(25.0, 0.0, VILLAGE_RADIUS):
		var h: float = chunk_manager.get_terrain_height(Vector3(25, 0, 0))
		return Vector3(25, h, 0)

	var step := 8
	var max_radius := 120
	for r in range(0, max_radius + 1, step):
		var edge := r + step
		for x in range(-edge, edge + 1, step):
			for z in range(-edge, edge + 1, step):
				if absf(x) <= r and absf(z) <= r:
					continue
				if _is_dry_footprint(25.0 + x, z, VILLAGE_RADIUS):
					var h: float = chunk_manager.get_terrain_height(Vector3(25 + x, 0, z))
					return Vector3(25 + x, h, z)
	return Vector3(25, 0, 0)

func _is_dry_footprint(cx: float, cz: float, radius: float) -> bool:
	if chunk_manager.get_biome_at(Vector3(cx, 0, cz)) <= 1:
		return false
	for i in 8:
		var a := i * TAU / 8.0
		var px := cx + cos(a) * radius
		var pz := cz + sin(a) * radius
		if chunk_manager.get_biome_at(Vector3(px, 0, pz)) <= 1:
			return false
		if chunk_manager.get_terrain_height(Vector3(px, 0, pz)) < 1.0:
			return false
	return true

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
	
	var water_material = ShaderMaterial.new()
	water_material.shader = preload("res://src/shaders/water_shader.gdshader")
	water_material.set_shader_parameter("shallow_color", Color(0.12, 0.55, 0.72, 0.82))
	water_material.set_shader_parameter("deep_color", Color(0.02, 0.18, 0.38, 0.95))
	water_material.set_shader_parameter("foam_color", Color(0.98, 0.99, 1.0, 0.92))
	water_material.set_shader_parameter("time_scale", 0.55)
	water_material.set_shader_parameter("wave_strength", 0.35)
	water_material.set_shader_parameter("normal_strength", 0.75)
	
	water_plane.material_override = water_material
	water_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_plane.position = Vector3(0, 0, 0)  # Sea level at y=0
	
	add_child(water_plane)

const BIOME_FOG_COLORS: Dictionary = {
	0: Color(0.2, 0.3, 0.6),   # Water — misty blue
	1: Color(0.8, 0.75, 0.65), # Beach — warm hazy
	2: Color(0.7, 0.75, 0.6),  # Plains — warm clear
	3: Color(0.4, 0.55, 0.45), # Forest — cool green tint
	4: Color(0.2, 0.35, 0.25), # Jungle/Swamp — dark green fog
	5: Color(0.5, 0.6, 0.65),  # Taiga — cool blue mist
	6: Color(0.75, 0.7, 0.65), # Mountains — clear thin air
	7: Color(0.85, 0.85, 0.9), # Snow — bright white
	8: Color(0.7, 0.65, 0.5),  # Meadow — warm golden
	9: Color(0.65, 0.6, 0.55), # Highland — dry haze
}

func _process(delta: float) -> void:
	# Handle pause input
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
	
	# Follow player with water plane (center it on player XZ, keep Y at sea level)
	if water_plane and player:
		var pp = player.global_position
		water_plane.global_position = Vector3(pp.x, 0, pp.z)
	
	# Check biome climate
	if player and chunk_manager and chunk_manager.has_method("get_biome_at"):
		_biome_check_timer += delta
		if _biome_check_timer > 1.5:
			_biome_check_timer = 0.0
			_update_biome_climate()
		_apply_biome_atmosphere()
	
	# Night-time enemy spawning
	if _is_night and player and chunk_manager:
		_night_spawn_timer -= delta
		if _night_spawn_timer <= 0.0:
			_night_spawn_timer = _night_spawn_interval + randf_range(-5.0, 5.0)
			_spawn_night_enemies()
	
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
	var was_night = _is_night
	_is_night = hour < 5.0 or hour >= 20.0
	
	# Dawn: despawn all enemies
	if was_night and not _is_night:
		_despawn_all_enemies()
		_night_spawn_timer = 0.0

func _on_day_changed(day: int) -> void:
	if game_manager:
		print("Day ", day, " - Season: ", game_manager.get_season_name())

func _on_season_changed(season: int) -> void:
	_update_season_sky(season)

func _update_biome_climate() -> void:
	if not player or not chunk_manager:
		return
	var player_biome: int = chunk_manager.get_biome_at(player.global_position)
	if player_biome < 0:
		return
	if player_biome == _current_player_biome:
		return
	_current_player_biome = player_biome
	var fog_color: Color = BIOME_FOG_COLORS.get(player_biome, Color(0.7, 0.8, 0.9))
	_target_biome_fog = fog_color

func _apply_biome_atmosphere() -> void:
	if not world_environment or not world_environment.environment:
		return
	if _displayed_biome_fog.is_equal_approx(_target_biome_fog):
		return
	_displayed_biome_fog = _displayed_biome_fog.lerp(_target_biome_fog, 0.005)
	# Blend biome tint into current fog (subtle — 15% influence)
	var current_fog := world_environment.environment.fog_light_color
	world_environment.environment.fog_light_color = current_fog.lerp(_displayed_biome_fog, 0.15)

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
	
	if sky_mat is ShaderMaterial:
		pass  # Season handled via fog density below
	env.fog_density = target_fog_density
	var season_names = ["Spring", "Summer", "Autumn", "Winter"]
	var sname = season_names[season] if season < season_names.size() else "Unknown"
	print("Season sky updated: ", sname, " (fog: ", target_fog_density, ")")

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
	_update_water_shader_globals()
	
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		var sky_mat = env.sky.sky_material if env.sky else null
		
		# --- Sky colors (day/night transition) ---
		if sky_mat is ShaderMaterial:
			var sky_top: Color
			var sky_horizon: Color
			var sky_energy: float
			var star_vis: float
			if hour >= 6.0 and hour < 18.0:
				sky_top = Color(0.2, 0.4, 0.8)
				sky_horizon = Color(0.55, 0.7, 0.9)
				sky_energy = 1.0
				star_vis = 0.0
			elif hour >= 5.0 and hour < 6.0:
				var t = hour - 5.0
				sky_top = Color(0.02, 0.02, 0.08).lerp(Color(0.2, 0.4, 0.8), t)
				sky_horizon = Color(0.3, 0.2, 0.15).lerp(Color(0.55, 0.7, 0.9), t)
				sky_energy = lerp(0.1, 1.0, t)
				star_vis = lerp(1.0, 0.0, t)
			elif hour >= 18.0 and hour < 20.0:
				var t = (hour - 18.0) / 2.0
				sky_top = Color(0.2, 0.4, 0.8).lerp(Color(0.02, 0.02, 0.08), t)
				sky_horizon = Color(0.55, 0.7, 0.9).lerp(Color(0.1, 0.05, 0.02), t)
				sky_energy = lerp(1.0, 0.1, t)
				star_vis = lerp(0.0, 1.0, t)
			else:
				sky_top = Color(0.02, 0.02, 0.08)
				sky_horizon = Color(0.05, 0.04, 0.06)
				sky_energy = 0.1
				star_vis = 1.0
			sky_mat.set_shader_parameter("sky_top_color", sky_top)
			sky_mat.set_shader_parameter("sky_horizon_color", sky_horizon)
			sky_mat.set_shader_parameter("ground_horizon_color", sky_horizon)
			sky_mat.set_shader_parameter("sky_energy", sky_energy)
			sky_mat.set_shader_parameter("star_visibility", star_vis)
			# Moon traces its own arc: rises at sunset (18:00), peaks at midnight, sets at sunrise (6:00)
			# Rises from opposite side of horizon from the sun
			var moon_angle = deg_to_rad((hour - 18.0) * 15.0)
			var moon_dir = Vector3(0.0, sin(moon_angle), cos(moon_angle))
			sky_mat.set_shader_parameter("moon_direction", moon_dir)
		
		# --- Ambient light ---
		var target_ambient_color: Color
		var target_ambient_energy: float
		if hour >= 6.0 and hour < 18.0:
			target_ambient_color = Color(0.6, 0.6, 0.7)
			target_ambient_energy = 0.5
		elif hour >= 5.0 and hour < 6.0:
			var t = hour - 5.0
			target_ambient_color = Color(0.2, 0.2, 0.4).lerp(Color(0.6, 0.6, 0.7), t)
			target_ambient_energy = lerp(0.15, 0.5, t)
		elif hour >= 18.0 and hour < 20.0:
			var t = (hour - 18.0) / 2.0
			target_ambient_color = Color(0.6, 0.6, 0.7).lerp(Color(0.05, 0.05, 0.1), t)
			target_ambient_energy = lerp(0.5, 0.05, t)
		else:
			target_ambient_color = Color(0.05, 0.05, 0.1)
			target_ambient_energy = 0.05
		# Cache surface values for underground override
		_surface_ambient_color = target_ambient_color
		_surface_ambient_energy = target_ambient_energy
		# Apply (underground handler will override if needed)
		if not _is_player_underground:
			env.ambient_light_color = target_ambient_color
			env.ambient_light_energy = target_ambient_energy
		
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

func _on_player_underground_changed(underground: bool, depth: float) -> void:
	_is_player_underground = underground
	if not world_environment or not world_environment.environment:
		return
	var env = world_environment.environment
	if underground:
		# Darken ambient based on depth: at 5 units deep = cave dark, deeper = pitch black
		var darkness = clampf(depth / 20.0, 0.0, 1.0)
		var cave_color = Color(0.08, 0.06, 0.05)  # Warm dark cave tone
		env.ambient_light_color = _surface_ambient_color.lerp(cave_color, darkness)
		env.ambient_light_energy = lerpf(_surface_ambient_energy, 0.04, darkness)
		# Suppress sun contribution underground
		if sun:
			sun.light_energy = lerpf(sun.light_energy, 0.0, darkness * 0.8)
		# Add cave fog
		env.fog_enabled = true
		env.fog_density = lerpf(0.002, 0.025, darkness)
		env.fog_light_color = Color(0.05, 0.04, 0.03)
	else:
		# Restore surface ambient
		env.ambient_light_color = _surface_ambient_color
		env.ambient_light_energy = _surface_ambient_energy
		# Restore sun
		if game_manager:
			_update_lighting(game_manager.current_hour)

func prepare_save_data() -> void:
	## Populates game_manager.world_data and player_data with current state.
	## Called before saves (manual and autosave) so the JSON has real data.
	if game_manager:
		game_manager.world_data["terrain"] = _serialize_terrain()
		game_manager.world_data["farm_plots"] = _serialize_farm_plots()
		game_manager.world_data["placed_objects"] = _serialize_placed_objects()
		game_manager.world_data["claims"] = _serialize_claims()
		game_manager.world_data["reputation"] = _serialize_reputation()
		var wm = get_node_or_null("/root/WeatherManager")
		if wm:
			game_manager.world_data["weather"] = wm.get_save_data()
		if player and player.has_method("serialize"):
			game_manager.player_data = player.serialize()

func _serialize_placed_objects() -> Array:
	var all_objs: Array = []
	for child in get_children():
		if child is PlaceableObject:
			all_objs.append(child.serialize())
	# Also check other potential parent nodes
	for group in get_tree().get_nodes_in_group("placeables"):
		if group is PlaceableObject and group.get_parent() != self:
			all_objs.append(group.serialize())
	return all_objs

func _serialize_claims() -> Array:
	var claims: Array = []
	for child in get_children():
		if child is Node and child.has_meta("claim_owner"):
			claims.append({
				"position": {"x": child.global_position.x, "y": child.global_position.y, "z": child.global_position.z},
				"radius": child.get_meta("claim_radius", 8.0),
				"owner": child.get_meta("claim_owner", ""),
			})
	return claims

func _serialize_reputation() -> Dictionary:
	return _reputation.duplicate(true)

func save_world() -> void:
	prepare_save_data()
	if save_manager:
		save_manager.save_game()

func _serialize_terrain() -> Dictionary:
	if game_manager:
		return {
			"version": "1.0.0",
			"seed": game_manager.world_seed
		}
	return {"version": "1.0.0", "seed": 0}

func _serialize_farm_plots() -> Dictionary:
	var plots_data: Array = []
	if farm_plots_container:
		for child in farm_plots_container.get_children():
			if child is FarmPlot:
				plots_data.append(child.get_save_data())
	var dug: Array = []
	if chunk_manager and chunk_manager.has_method("serialize_dug_positions"):
		dug = chunk_manager.serialize_dug_positions()
	return {"plots": plots_data, "dug": dug}

func _load_player_data() -> void:
	if not game_manager or not player:
		return
	if game_manager.player_data.size() > 0 and player.has_method("deserialize"):
		player.deserialize(game_manager.player_data)
		print("Player data restored from save")

func _load_placed_objects() -> void:
	if not game_manager:
		return
	var objs_data: Array = game_manager.world_data.get("placed_objects", [])
	for data in objs_data:
		var item_id: String = data.get("item_id", "")
		var pos_data: Dictionary = data.get("position", {})
		var pos := Vector3(pos_data.get("x", 0.0), pos_data.get("y", 0.0), pos_data.get("z", 0.0))
		var rot_y: float = data.get("rotation_y", 0.0)
		var is_gate: bool = data.get("is_gate", false)
		var gate_open: bool = data.get("gate_open", false)

		var item_db = get_node_or_null("/root/ItemDatabase")
		if not item_db:
			continue
		var item = item_db.get_item(item_id)
		if not item:
			continue

		if item_id == "community_center":
			var cc = CommunityCenterObject.new()
			var interior_id: String = data.get("interior_id", "")
			cc.setup(item_id, item.item_name, "", item.placeable_scale, item.placeable_collision_size, false, interior_id)
			cc.name = "Placed_%s" % item_id
			cc.global_position = pos
			cc.rotation.y = rot_y
			add_child(cc)
		elif item_id == "house":
			var house = HouseObjectScript.new()
			var interior_id: String = data.get("interior_id", "")
			house.name = "Placed_%s" % item_id
			house.global_position = pos
			house.rotation.y = rot_y
			house.setup(item_id, item.item_name, item.placeable_model_path, item.placeable_scale, item.placeable_collision_size, false, interior_id)
			add_child(house)
		else:
			var obj := PlaceableObject.new()
			obj.name = "Placed_%s" % item_id
			obj.global_position = pos
			obj.rotation.y = rot_y
			obj.gate_open = gate_open
			obj.setup(item_id, item.item_name, item.placeable_model_path, item.placeable_scale, item.placeable_collision_size, is_gate)
			add_child(obj)
	# Restore claims
	var claims_data: Array = game_manager.world_data.get("claims", [])
	for claim in claims_data:
		var cpos_data: Dictionary = claim.get("position", {})
		var cpos := Vector3(cpos_data.get("x", 0.0), cpos_data.get("y", 0.0), cpos_data.get("z", 0.0))
		var radius: float = claim.get("radius", 8.0)
		var owner: String = claim.get("owner", "")
		_spawn_claim_boundary(cpos, radius, owner)
	if objs_data.size() > 0 or claims_data.size() > 0:
		print("Restored %d placed objects and %d claims" % [objs_data.size(), claims_data.size()])

func _load_farm_plots() -> void:
	if not game_manager or not farm_plots_container:
		return
	var farm_raw = game_manager.world_data.get("farm_plots", {})
	if farm_raw.is_empty():
		return
	# Handle both old format (array of plot data) and new format (dict with plots/dug)
	var plots_data: Array
	if farm_raw is Array:
		plots_data = farm_raw
	else:
		plots_data = farm_raw.get("plots", [])
		var dug_data: Array = farm_raw.get("dug", [])
		if not dug_data.is_empty() and chunk_manager and chunk_manager.has_method("restore_dug_positions"):
			chunk_manager.restore_dug_positions(dug_data)
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
	
	print("Crafting UI initialized")

func _setup_herbarium_ui() -> void:
	var ui_container = get_node_or_null("UI")
	if not ui_container:
		return
	herbarium_ui = HerbariumUIScript.new()
	herbarium_ui.name = "HerbariumUI"
	ui_container.add_child(herbarium_ui)
	herbarium_ui.initialize()
	print("Herbarium UI initialized")

func _on_open_crafting_station(station_type: int) -> void:
	if crafting_ui:
		crafting_ui.show_crafting(station_type)

# Crafting stations are now placed by the player from inventory items.
# See _place_object() in player_controller.gd.

func _build_village() -> void:
	await get_tree().process_frame
	town_builder = TownBuilderScript.new()
	town_builder.name = "TownBuilder"
	town_builder.setup(chunk_manager)
	add_child(town_builder)
	town_builder.build_village(_village_center)
	print("Starter village built at ", _village_center)

const SKELETON_MINION = "res://assets/characters/Zombie_Male.blend"
const SKELETON_WARRIOR = "res://assets/characters/Zombie_Female.blend"
const SKELETON_ROGUE = "res://assets/characters/Goblin_Male.blend"
const SKELETON_MAGE = "res://assets/characters/Goblin_Female.blend"

func _spawn_enemies() -> void:
	if not player:
		return
	await get_tree().process_frame
	var spawn_pos = player.global_position
	
	# Skeleton Minions - easy, near spawn but AWAY from village (village at X=25)
	for i in 3:
		var offset = Vector3(
			randf_range(-20, -10),
			0,
			randf_range(-15, 15)
		)
		_create_enemy(spawn_pos + offset, "Skeleton Minion", 15.0, 1.5, 2.5, 3.0, 1.5, 10.0,
			Color.WHITE, 10.0, [
				{"item_id": "string", "min_amount": 1, "max_amount": 2, "chance": 0.5},
				{"item_id": "stick", "min_amount": 1, "max_amount": 1, "chance": 0.3},
			], SKELETON_MINION, 0.5)
	
	# Skeleton Rogues - fast, medium difficulty (2)
	for i in 2:
		var offset = Vector3(
			randf_range(-30, -18),
			0,
			randf_range(-20, 20)
		)
		_create_enemy(spawn_pos + offset, "Skeleton Rogue", 20.0, 2.5, 4.5, 5.0, 1.5, 12.0,
			Color.WHITE, 18.0, [
				{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.5},
				{"item_id": "string", "min_amount": 1, "max_amount": 3, "chance": 0.6},
			], SKELETON_ROGUE, 0.5)
	
	# Skeleton Warrior - tough melee (1) — far from village
	_create_enemy(spawn_pos + Vector3(-25, 0, 22), "Skeleton Warrior", 40.0, 1.2, 2.5, 8.0, 1.8, 12.0,
		Color.WHITE, 30.0, [
			{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 3, "chance": 0.7},
			{"item_id": "copper_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.4},
			{"item_id": "gold_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.15},
		], SKELETON_WARRIOR, 0.5)
	
	# Skeleton Mage - ranged caster, dangerous (1) — far from village
	_create_enemy(spawn_pos + Vector3(-28, 0, -18), "Skeleton Mage", 25.0, 1.0, 2.0, 10.0, 2.5, 14.0,
		Color.WHITE, 35.0, [
			{"item_id": "coal", "min_amount": 2, "max_amount": 4, "chance": 0.8},
			{"item_id": "gold_nugget", "min_amount": 1, "max_amount": 1, "chance": 0.25},
			{"item_id": "iron_nugget", "min_amount": 1, "max_amount": 2, "chance": 0.5},
		], SKELETON_MAGE, 0.5)
	
	print("Enemies spawned")

# ── Animal Spawning ──────────────────────────────────────────────────────────

var _animal_species: Dictionary = {}  # species_id -> AnimalData

func _spawn_animals() -> void:
	if not player:
		return
	await get_tree().process_frame
	var spawn_pos = player.global_position
	
	_register_animal_species()
	
	# --- Farm animals near spawn (Plains/Meadow biomes only) ---
	var farm_biomes := [2, 8]  # Plains, Meadow
	_spawn_in_biomes("chicken", 3, spawn_pos, 8.0, farm_biomes)
	_spawn_in_biomes("cow", 2, spawn_pos, 12.0, farm_biomes)
	_spawn_in_biomes("sheep", 2, spawn_pos, 10.0, farm_biomes)
	_spawn_in_biomes("goat", 1, spawn_pos, 10.0, farm_biomes)
	_spawn_in_biomes("duck", 2, spawn_pos, 8.0, farm_biomes)
	_spawn_in_biomes("boar", 1, spawn_pos, 14.0, [2, 3, 8])  # Plains, Forest, Meadow
	
	# --- Wild/huntable animals in appropriate biomes ---
	_spawn_in_biomes("deer", 2, spawn_pos, 25.0, [3, 8])  # Forest, Meadow
	_spawn_in_biomes("rabbit", 3, spawn_pos, 20.0, [2, 3, 8])  # Plains, Forest, Meadow
	
	# --- Predators in wild biomes (further out, fewer numbers) ---
	_spawn_in_biomes("wolf", 1, spawn_pos, 40.0, [3, 5, 9])  # Forest, Taiga, Highland
	
	print("Animals spawned")

func _spawn_in_biomes(species_id: String, count: int, center: Vector3, radius: float, biomes: Array) -> void:
	## Spawns `count` animals of `species_id` within `radius` of `center`,
	## but only on terrain cells whose biome type is in the `biomes` whitelist.
	var placed := 0
	for attempt in range(100):
		if placed >= count:
			break
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(3.0, radius)
		var offset := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var pos := center + offset
		var valid := true
		if chunk_manager and chunk_manager.has_method("get_biome_at"):
			var biome: int = chunk_manager.get_biome_at(pos)
			if biome not in biomes:
				valid = false
		if valid and chunk_manager and chunk_manager.has_method("get_terrain_height"):
			if chunk_manager.get_terrain_height(pos) < 1.0:
				valid = false
		if valid:
			_create_animal(species_id, pos)
			placed += 1

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
	chicken.model_path = "res://assets/Animals/Blends/chicken.blend"
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
	cow.model_path = "res://assets/Animals/Blends/Cow.blend"
	cow.model_scale = 0.6
	cow.body_color = Color(0.9, 0.85, 0.8)
	cow.product_type = AnimalDataScript.ProductType.MILK
	cow.product_item_id = "milk"
	cow.product_interval = 120.0
	cow.product_amount = 1
	cow.feed_item_ids = ["animal_feed", "wheat", "carrot_raw"]
	cow.can_graze = true
	cow.graze_hunger_reduction = 0.3
	cow.graze_biomes = [2, 8, 3]
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
	sheep.model_path = "res://assets/Animals/Blends/sheep.blend"
	sheep.model_scale = 0.5
	sheep.body_color = Color(0.95, 0.95, 0.9)
	sheep.product_type = AnimalDataScript.ProductType.WOOL
	sheep.product_item_id = "wool"
	sheep.product_interval = 150.0
	sheep.product_amount = 1
	sheep.feed_item_ids = ["animal_feed", "wheat"]
	sheep.can_graze = true
	sheep.graze_hunger_reduction = 0.35
	sheep.graze_biomes = [2, 8, 3]
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
	goat.model_path = "res://assets/Animals/Blends/goat.blend"
	goat.model_scale = 0.5
	goat.body_color = Color(0.75, 0.7, 0.6)
	goat.product_type = AnimalDataScript.ProductType.MILK
	goat.product_item_id = "milk"
	goat.product_interval = 140.0
	goat.product_amount = 1
	goat.feed_item_ids = ["animal_feed", "wheat", "carrot_raw"]
	goat.can_graze = true
	goat.graze_hunger_reduction = 0.3
	goat.graze_biomes = [2, 8, 3, 9]
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
	duck.model_path = "res://assets/Animals/Blends/duck.blend"
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
	boar.model_path = "res://assets/Animals/Blends/boar.blend"
	boar.model_scale = 0.5
	boar.body_color = Color(0.5, 0.35, 0.25)
	boar.product_type = AnimalDataScript.ProductType.NONE
	boar.feed_item_ids = ["animal_feed", "carrot_raw", "potato"]
	boar.can_graze = true
	boar.graze_hunger_reduction = 0.25
	boar.graze_biomes = [2, 3, 8]
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
	deer.model_path = "res://assets/Animals/Blends/Deer.blend"
	deer.model_scale = 0.5
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
	rabbit.model_path = "res://assets/Animals/Blends/rabbit.blend"
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

	# Wolf (wild predator)
	var wolf = AnimalDataScript.new()
	wolf.species_id = "wolf"
	wolf.display_name = "Wolf"
	wolf.animal_type = AnimalDataScript.AnimalType.HUNTABLE
	wolf.max_health = 40.0
	wolf.move_speed = 2.5
	wolf.flee_speed = 5.0
	wolf.wander_radius = 15.0
	wolf.detection_range = 12.0
	wolf.collision_radius = 0.4
	wolf.collision_height = 1.0
	wolf.model_path = "res://assets/Animals/Blends/Wolf.blend"
	wolf.model_scale = 0.45
	wolf.body_color = Color(0.45, 0.4, 0.35)
	wolf.product_type = AnimalDataScript.ProductType.NONE
	wolf.is_predator = true
	wolf.prey_species = ["deer", "rabbit"]
	wolf.attack_damage = 8.0
	wolf.attack_cooldown = 3.0
	wolf.hunt_speed_mult = 1.8
	wolf.loot_table = [
		{"item_id": "raw_meat", "min_amount": 2, "max_amount": 3, "chance": 1.0},
		{"item_id": "leather", "min_amount": 1, "max_amount": 2, "chance": 0.8},
	]
	wolf.xp_reward = 20.0
	wolf.xp_skill = "combat"
	_animal_species["wolf"] = wolf

func _create_animal(species_id: String, pos: Vector3, tamed: bool = false, baby: bool = false) -> void:
	var data = _animal_species.get(species_id)
	if not data:
		push_warning("Unknown animal species: %s" % species_id)
		return
	
	# Snap to terrain height — skip if in water
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		var h: float = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
		if h < 1.0:
			return
		pos.y = h
	else:
		pos.y = 30.0
	
	var animal = BaseAnimalScript.new()
	animal.setup(data, tamed, baby)
	animal.position = pos
	add_child(animal)

# ── Dynamic Wildlife (chunk lifecycle) ──────────────────────────────────────

func _on_chunk_loaded(chunk_pos: Vector2i) -> void:
	## Spawn wild animals when a chunk finishes generating.
	_spawn_wildlife_for_chunk(chunk_pos)

func _on_chunk_unloaded(chunk_pos: Vector2i) -> void:
	## Despawn wild animals when a chunk is unloaded.
	_despawn_wildlife_for_chunk(chunk_pos)

func _spawn_wildlife_for_chunk(chunk_pos: Vector2i) -> void:
	## Spawn wild/huntable animals in a chunk based on its dominant biome.
	if not chunk_manager or not _animal_species:
		return

	var chunk_world_x = chunk_pos.x * 32 + 16
	var chunk_world_z = chunk_pos.y * 32 + 16
	var center_biome = chunk_manager.get_biome_at(Vector3(chunk_world_x, 0, chunk_world_z))

	var spawned: Array[BaseAnimal] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos) ^ hash(game_manager.world_seed if game_manager else 0)

	for species_id in WILD_SPAWN_RULES:
		var rule = WILD_SPAWN_RULES[species_id]
		if center_biome not in rule["biomes"]:
			continue
		if rng.randf() > rule["spawn_chance"]:
			continue
		var count = rng.randi_range(rule["count_range"][0], rule["count_range"][1])
		for i in range(count):
			var lx = rng.randf_range(1.0, 31.0)
			var lz = rng.randf_range(1.0, 31.0)
			var wx = chunk_world_x + (lx - 16.0)
			var wz = chunk_world_z + (lz - 16.0)
			var pos = Vector3(wx, 0, wz)
			var biome = chunk_manager.get_biome_at(pos)
			if biome not in rule["biomes"]:
				continue
			var terrain_y = chunk_manager.get_terrain_height(pos) if chunk_manager.has_method("get_terrain_height") else 30.0
			pos.y = terrain_y
			var animal = BaseAnimalScript.new()
			animal.setup(_animal_species[species_id], false, false)
			animal.position = pos
			add_child(animal)
			spawned.append(animal)

	if spawned.size() > 0:
		_wildlife_by_chunk[chunk_pos] = spawned

func _despawn_wildlife_for_chunk(chunk_pos: Vector2i) -> void:
	## Remove all wild animals belonging to an unloaded chunk.
	var animals = _wildlife_by_chunk.get(chunk_pos)
	if not animals or animals.is_empty():
		return
	for animal in animals:
		if is_instance_valid(animal):
			animal.queue_free()
	_wildlife_by_chunk.erase(chunk_pos)

# ── Night Enemy Spawning ────────────────────────────────────────────────────

func _spawn_night_enemies() -> void:
	## Spawn a wave of enemies at night, around the player but not too close.
	if not player or not chunk_manager:
		return

	var spawn_pos = player.global_position
	var wave_size = randi_range(2, 4)

	for i in range(wave_size):
		var angle = randf_range(0.0, TAU)
		var dist = randf_range(20.0, 40.0)
		var offset = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var pos = spawn_pos + offset

		# Skip water
		var biome = chunk_manager.get_biome_at(pos) if chunk_manager.has_method("get_biome_at") else -1
		if biome == 0:
			continue

		# Skip village area
		if pos.distance_to(Vector3(25, 0, 0)) < 22.0:
			continue

		# Pick enemy type based on difficulty
		var roll = randf()
		var ename: String
		var health: float
		var speed: float
		var chase_speed: float
		var damage: float
		var atk_range: float
		var detect: float
		var emodel: String
		var escale: float
		var loot: Array
		var xp: float = 10.0

		if roll < 0.5:
			ename = "Skeleton Minion"
			health = 15.0; speed = 1.5; chase_speed = 2.5; damage = 3.0; atk_range = 1.5; detect = 10.0
			emodel = "res://assets/characters/Zombie_Male.blend"; escale = 0.5
			loot = [{"item_id": "bone", "min_amount": 1, "max_amount": 2, "chance": 0.6}]
			xp = 10.0
		elif roll < 0.8:
			ename = "Skeleton Rogue"
			health = 20.0; speed = 2.5; chase_speed = 4.5; damage = 5.0; atk_range = 1.5; detect = 12.0
			emodel = "res://assets/characters/Goblin_Male.blend"; escale = 0.5
			loot = [{"item_id": "bone", "min_amount": 1, "max_amount": 2, "chance": 0.7}]
			xp = 18.0
		elif roll < 0.95:
			ename = "Skeleton Warrior"
			health = 40.0; speed = 1.2; chase_speed = 3.0; damage = 8.0; atk_range = 2.0; detect = 10.0
			emodel = "res://assets/characters/Zombie_Female.blend"; escale = 0.5
			loot = [{"item_id": "bone", "min_amount": 2, "max_amount": 4, "chance": 1.0}]
			xp = 30.0
		else:
			ename = "Skeleton Mage"
			health = 25.0; speed = 1.0; chase_speed = 2.0; damage = 6.0; atk_range = 8.0; detect = 14.0
			emodel = "res://assets/characters/Goblin_Female.blend"; escale = 0.5
			loot = [{"item_id": "bone", "min_amount": 2, "max_amount": 3, "chance": 1.0}]
			xp = 35.0

		_create_enemy(pos, ename, health, speed, chase_speed, damage, atk_range, detect,
			Color.WHITE, xp, loot, emodel, escale)

func _despawn_all_enemies() -> void:
	## Called at dawn — remove all enemies from the world.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _create_enemy(pos: Vector3, ename: String, health: float, spd: float,
		chase_spd: float, dmg: float, atk_range: float, detect: float,
		color: Color, xp: float, loot: Array,
		emodel: String = "", escale: float = 1.0) -> void:
	# Snap to terrain height — skip if in water
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		var terrain_y = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
		if terrain_y < 1.0:
			return
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

# ── NPC System ───────────────────────────────────────────────────────────────

const ADVENTURER_BARBARIAN = "res://assets/characters/Viking_Male.blend"
const ADVENTURER_KNIGHT = "res://assets/characters/Knight_Male.blend"
const ADVENTURER_MAGE = "res://assets/characters/Wizard.blend"
const ADVENTURER_RANGER = "res://assets/characters/Casual_Male.blend"
const ADVENTURER_ROGUE = "res://assets/characters/Ninja_Male.blend"
const ADVENTURER_ROGUE_HOODED = "res://assets/characters/Ninja_Female.blend"

var _npc_registry: Dictionary = {}  # npc_id -> NPCData

func _setup_dialogue_ui() -> void:
	dialogue_ui = DialogueUIScript.new()
	dialogue_ui.name = "DialogueUI"
	$UI.add_child(dialogue_ui)

func _setup_shop_ui() -> void:
	shop_ui = ShopUIScript.new()
	shop_ui.name = "ShopUI"
	$UI.add_child(shop_ui)

func _setup_quest_journal_ui() -> void:
	quest_journal_ui = QuestJournalUIScript.new()
	quest_journal_ui.name = "QuestJournalUI"
	$UI.add_child(quest_journal_ui)
	# Give journal a direct reference to the quest tracker
	if hud and hud.quest_tracker:
		quest_journal_ui.set("_tracker_ref", hud.quest_tracker)

func _setup_notification_ui() -> void:
	notification_popup = NotificationPopupScript.new()
	notification_popup.name = "NotificationPopup"
	$UI.add_child(notification_popup)

func _setup_interior_manager() -> void:
	await get_tree().process_frame

	var interior_manager = InteriorManagerScript.new()
	interior_manager.name = "InteriorManager"
	add_child(interior_manager)
	print("Interior manager initialized")

func _setup_weather() -> void:
	await get_tree().process_frame

	weather_effects = WeatherEffectsScript.new()
	weather_effects.name = "WeatherEffects"
	add_child(weather_effects)
	print("Weather effects initialized")

func _setup_reputation() -> void:
	## Initialize reputation from saved data, or set defaults.
	if game_manager:
		var saved: Dictionary = game_manager.world_data.get("reputation", {})
		if saved.size() > 0:
			_reputation = saved.duplicate(true)
		else:
			# Set default neutral reputation for all known NPCs
			for npc_id in _npc_registry:
				_reputation[npc_id] = 0
		print("Reputation initialized: %d NPCs" % _reputation.size())

func modify_reputation(npc_id: String, delta: int) -> void:
	## Change reputation for an NPC (clamped to -100..100).
	if not _reputation.has(npc_id):
		_reputation[npc_id] = 0
	_reputation[npc_id] = clampi(_reputation[npc_id] + delta, -100, 100)
	var npc_entry = _npc_registry.get(npc_id)
	var name_str = npc_entry.display_name if npc_entry else npc_id
	var direction := "increased" if delta >= 0 else "decreased"
	print("Reputation with %s %s by %d (now %d)" % [name_str, direction, abs(delta), _reputation[npc_id]])

func get_reputation(npc_id: String) -> int:
	return _reputation.get(npc_id, 0)

func get_reputation_price_modifier(npc_id: String) -> float:
	## Returns a price multiplier based on reputation level.
	var rep := get_reputation(npc_id)
	if rep >= 51: return 0.7     # Honored: 30% off
	if rep >= 21: return 0.85    # Friendly: 15% off
	if rep >= 0:  return 1.0     # Neutral: normal
	if rep >= -50: return 1.25   # Unfriendly: 25% markup
	return 1.5                    # Hostile: 50% markup

	# Restore saved weather state
	var wm = get_node_or_null("/root/WeatherManager")
	if wm and game_manager:
		var saved = game_manager.world_data.get("weather", {})
		if saved.size() > 0:
			wm.load_save_data(saved)
			print("Weather data restored from save")

func _spawn_npcs() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # Wait for village to be built
	
	_register_npc_data()
	
	# NPCs placed near their respective buildings (matching build_village layout)
	# Building positions from town_builder: offset from _village_center
	var vc := _village_center
	_create_npc("shopkeeper",   Vector3(vc.x + 2, 0, vc.z - 12))   # General Store (north)
	_create_npc("innkeeper",    Vector3(vc.x + 12, 0, vc.z - 8))   # Tavern (northeast)
	_create_npc("blacksmith",   Vector3(vc.x + 12, 0, vc.z + 2))   # Blacksmith (east)
	_create_npc("baker",        Vector3(vc.x + 8, 0, vc.z + 12))   # Bakery (southeast)
	_create_npc("mayor",        Vector3(vc.x - 2, 0, vc.z + 12))   # Town Hall (south)
	_create_npc("herbalist",    Vector3(vc.x - 8, 0, vc.z + 8))    # Herbalist (southwest)
	_create_npc("farmer",       Vector3(vc.x - 12, 0, vc.z - 2))   # Farmer House (west)
	_create_npc("guard",        Vector3(vc.x - 8, 0, vc.z - 8))    # Guard Post (northwest)
	
	# Start quests via QuestManager
	_add_starter_quests()
	_refresh_npc_quest_glows()
	
	print("Village NPCs spawned")

func _get_quest_tracker():
	if hud and hud.quest_tracker:
		return hud.quest_tracker
	return null

func _init_quest_system() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	var qdb = get_node_or_null("/root/QuestDatabase")
	if not qm or not qdb:
		push_warning("main_world: QuestManager or QuestDatabase not found")
		return
	
	# Give QuestManager access to the player inventory
	if player and player.has_method("get_inventory"):
		qm.set_inventory(player.get_inventory())
	elif player and player.get("inventory"):
		qm.set_inventory(player.inventory)
	
	# Register all quest definitions
	qdb.register_all_quests(qm)
	
	# Connect QuestManager signals to QuestTrackerUI
	qm.quest_accepted.connect(_on_qm_quest_accepted)
	qm.quest_objective_updated.connect(_on_qm_objective_updated)
	qm.quest_completed.connect(_on_qm_quest_completed)
	qm.quest_turned_in.connect(_on_qm_quest_turned_in)
	qm.quest_available.connect(_on_qm_quest_available)
	qm.quest_reward_granted.connect(_on_qm_reward_granted)
	
	print("Quest system initialized with %d quests" % qm.quest_definitions.size())

func _add_starter_quests() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	
	# Welcome quest is available immediately
	qm.make_available("welcome")
	qm.accept_quest("welcome")

func _register_npc_data() -> void:
	# Shopkeeper — General Store
	var shopkeeper = NPCDataScript.new()
	shopkeeper.npc_id = "shopkeeper"
	shopkeeper.display_name = "Elara"
	shopkeeper.role = NPCDataScript.NPCRole.MERCHANT
	shopkeeper.title = "General Store"
	shopkeeper.model_path = ADVENTURER_RANGER
	shopkeeper.model_scale = 0.5
	shopkeeper.body_color = Color(0.6, 0.8, 0.5)
	shopkeeper.wander_radius = 2.0
	shopkeeper.greeting_lines = ["Welcome!", "Need supplies?", "Browse my wares!"]
	shopkeeper.dialogue = [
		{"text": "Welcome to my shop! I've got all the essentials a traveler needs.", "choices": [
			{"text": "Show me your wares.", "action": "shop"},
			{"text": "Just passing through.", "action": "close"},
		]}
	]
	shopkeeper.shop_inventory = [
		{"item_id": "wood_log", "buy_price": 5, "stock": -1},
		{"item_id": "stone", "buy_price": 5, "stock": -1},
		{"item_id": "stick", "buy_price": 2, "stock": -1},
		{"item_id": "string", "buy_price": 3, "stock": -1},
		{"item_id": "rope", "buy_price": 8, "stock": -1},
		{"item_id": "torch", "buy_price": 10, "stock": 10},
		{"item_id": "animal_feed", "buy_price": 4, "stock": -1},
	]
	shopkeeper.schedule = [
		{"hour": 6.0, "activity": "idle", "target_pos": Vector3(27, 0, -12)},
		{"hour": 8.0, "activity": "work", "target_pos": Vector3(27, 0, -12)},
		{"hour": 12.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(27, 0, -12)},
		{"hour": 18.0, "activity": "socialize", "target_pos": Vector3(35, 0, -10)},
		{"hour": 21.0, "activity": "idle", "target_pos": Vector3(27, 0, -12)},
		{"hour": 22.0, "activity": "sleep", "target_pos": Vector3(27, 0, -12)},
	]
	_npc_registry["shopkeeper"] = shopkeeper
	
	# Innkeeper — Tavern
	var innkeeper = NPCDataScript.new()
	innkeeper.npc_id = "innkeeper"
	innkeeper.display_name = "Bram"
	innkeeper.role = NPCDataScript.NPCRole.INNKEEPER
	innkeeper.title = "Innkeeper"
	innkeeper.model_path = ADVENTURER_BARBARIAN
	innkeeper.model_scale = 0.5
	innkeeper.body_color = Color(0.7, 0.5, 0.4)
	innkeeper.wander_radius = 2.5
	innkeeper.greeting_lines = ["Come in, come in!", "Hungry?", "Rest your feet!"]
	innkeeper.dialogue = [
		{"text": "Welcome to the Rusty Tankard! Best food and drink in town.", "choices": [
			{"text": "What's on the menu?", "action": "shop"},
			{"text": "Any rumors?", "next": 1},
			{"text": "I'll be going.", "action": "close"},
		]},
		{"text": "I've heard strange noises from the forest at night. Skeletons, they say. Be careful out there.", "choices": [
			{"text": "Thanks for the warning.", "action": "close"},
		]}
	]
	innkeeper.shop_inventory = [
		{"item_id": "health_potion", "buy_price": 25, "stock": 5},
		{"item_id": "stamina_potion", "buy_price": 20, "stock": 5},
		{"item_id": "empty_bottle", "buy_price": 3, "stock": -1},
	]
	innkeeper.schedule = [
		{"hour": 7.0, "activity": "work", "target_pos": Vector3(35, 0, -10)},
		{"hour": 12.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(35, 0, -10)},
		{"hour": 22.0, "activity": "sleep", "target_pos": Vector3(35, 0, -10)},
	]
	_npc_registry["innkeeper"] = innkeeper
	
	# Blacksmith
	var blacksmith = NPCDataScript.new()
	blacksmith.npc_id = "blacksmith"
	blacksmith.display_name = "Tormund"
	blacksmith.role = NPCDataScript.NPCRole.BLACKSMITH
	blacksmith.title = "Blacksmith"
	blacksmith.model_path = ADVENTURER_KNIGHT
	blacksmith.model_scale = 0.5
	blacksmith.body_color = Color(0.5, 0.4, 0.35)
	blacksmith.wander_radius = 2.0
	blacksmith.greeting_lines = ["Need something forged?", "Steel and fire!", "What'll it be?"]
	blacksmith.dialogue = [
		{"text": "I forge the finest tools and weapons in the region. Interested?", "choices": [
			{"text": "Show me what you've got.", "action": "shop"},
			{"text": "Not right now.", "action": "close"},
		]}
	]
	blacksmith.shop_inventory = [
		{"item_id": "iron_ingot", "buy_price": 15, "stock": 10},
		{"item_id": "copper_ingot", "buy_price": 10, "stock": 10},
		{"item_id": "steel_ingot", "buy_price": 30, "stock": 5},
		{"item_id": "coal", "buy_price": 5, "stock": -1},
	]
	blacksmith.schedule = [
		{"hour": 6.0, "activity": "idle", "target_pos": Vector3(39, 0, 0)},
		{"hour": 7.0, "activity": "work", "target_pos": Vector3(39, 0, 0)},
		{"hour": 12.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(39, 0, 0)},
		{"hour": 17.0, "activity": "socialize", "target_pos": Vector3(35, 0, -10)},
		{"hour": 19.0, "activity": "idle", "target_pos": Vector3(39, 0, 0)},
		{"hour": 21.0, "activity": "sleep", "target_pos": Vector3(39, 0, 0)},
	]
	_npc_registry["blacksmith"] = blacksmith
	
	# Baker
	var baker = NPCDataScript.new()
	baker.npc_id = "baker"
	baker.display_name = "Marta"
	baker.role = NPCDataScript.NPCRole.MERCHANT
	baker.title = "Baker"
	baker.model_path = ADVENTURER_ROGUE
	baker.model_scale = 0.5
	baker.body_color = Color(0.85, 0.75, 0.6)
	baker.wander_radius = 2.0
	baker.greeting_lines = ["Fresh bread!", "Smells good, right?", "Try my pastries!"]
	baker.dialogue = [
		{"text": "Everything's baked fresh this morning! Can I tempt you?", "choices": [
			{"text": "What do you have?", "action": "shop"},
			{"text": "Maybe later.", "action": "close"},
		]}
	]
	baker.shop_inventory = [
		{"item_id": "wheat", "buy_price": 3, "stock": -1},
		{"item_id": "carrot_raw", "buy_price": 4, "stock": 10},
		{"item_id": "potato", "buy_price": 4, "stock": 10},
	]
	baker.schedule = [
		{"hour": 5.0, "activity": "work", "target_pos": Vector3(35, 0, 10)},
		{"hour": 8.0, "activity": "work", "target_pos": Vector3(35, 0, 10)},
		{"hour": 12.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(35, 0, 10)},
		{"hour": 18.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 20.0, "activity": "idle", "target_pos": Vector3(35, 0, 10)},
		{"hour": 21.0, "activity": "sleep", "target_pos": Vector3(35, 0, 10)},
	]
	_npc_registry["baker"] = baker
	# Mayor — Town Hall
	var mayor = NPCDataScript.new()
	mayor.npc_id = "mayor"
	mayor.display_name = "Aldric"
	mayor.role = NPCDataScript.NPCRole.QUEST_GIVER
	mayor.title = "Village Elder"
	mayor.model_path = ADVENTURER_MAGE
	mayor.model_scale = 0.5
	mayor.body_color = Color(0.6, 0.5, 0.7)
	mayor.wander_radius = 3.0
	mayor.greeting_lines = ["Ah, the newcomer!", "Good day, friend.", "Our village grows!"]
	mayor.dialogue = [
		{"text": "Welcome to our humble village! We could use someone with your talents around here.", "choices": [
			{"text": "What needs doing?", "next": 1},
			{"text": "Just exploring.", "action": "close"},
		]},
		{"text": "The skeleton menace in the forest grows bolder. Clear some out and I'll make it worth your while. Also, we always need more supplies — wood, stone, food.", "choices": [
			{"text": "I'll see what I can do.", "action": "close"},
		]}
	]
	mayor.schedule = [
		{"hour": 7.0, "activity": "idle", "target_pos": Vector3(25, 0, 14)},
		{"hour": 8.0, "activity": "work", "target_pos": Vector3(25, 0, 14)},
		{"hour": 12.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(25, 0, 14)},
		{"hour": 17.0, "activity": "socialize", "target_pos": Vector3(35, 0, -10)},
		{"hour": 19.0, "activity": "idle", "target_pos": Vector3(25, 0, 14)},
		{"hour": 21.0, "activity": "sleep", "target_pos": Vector3(25, 0, 14)},
	]
	_npc_registry["mayor"] = mayor
	
	# Herbalist
	var herbalist = NPCDataScript.new()
	herbalist.npc_id = "herbalist"
	herbalist.display_name = "Sage Willow"
	herbalist.role = NPCDataScript.NPCRole.HERBALIST
	herbalist.title = "Herbalist"
	herbalist.model_path = ADVENTURER_ROGUE_HOODED
	herbalist.model_scale = 0.5
	herbalist.body_color = Color(0.4, 0.7, 0.5)
	herbalist.wander_radius = 2.5
	herbalist.greeting_lines = ["Herbs and remedies...", "Nature provides.", "Need a cure?"]
	herbalist.dialogue = [
		{"text": "I deal in herbs, potions, and natural remedies. The forest holds many secrets.", "choices": [
			{"text": "Show me your potions.", "action": "shop"},
			{"text": "Tell me about the herbs.", "next": 1},
			{"text": "Farewell.", "action": "close"},
		]},
		{"text": "Mushrooms grow near trees, flowers in meadows, and ferns in the shade. Use a sickle or knife to harvest them carefully.", "choices": [
			{"text": "Thanks for the tip!", "action": "close"},
		]}
	]
	herbalist.shop_inventory = [
		{"item_id": "health_potion", "buy_price": 20, "stock": 5},
		{"item_id": "greater_health_potion", "buy_price": 50, "stock": 3},
		{"item_id": "antidote", "buy_price": 15, "stock": 5},
		{"item_id": "speed_potion", "buy_price": 30, "stock": 3},
		{"item_id": "strength_potion", "buy_price": 35, "stock": 3},
		{"item_id": "empty_bottle", "buy_price": 2, "stock": -1},
	]
	herbalist.schedule = [
		{"hour": 6.0, "activity": "idle", "target_pos": Vector3(17, 0, 10)},
		{"hour": 8.0, "activity": "work", "target_pos": Vector3(17, 0, 10)},
		{"hour": 12.0, "activity": "idle", "target_pos": Vector3(17, 0, 10)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(17, 0, 10)},
		{"hour": 17.0, "activity": "socialize", "target_pos": Vector3(25, 0, 0)},
		{"hour": 19.0, "activity": "idle", "target_pos": Vector3(17, 0, 10)},
		{"hour": 21.0, "activity": "sleep", "target_pos": Vector3(17, 0, 10)},
	]
	_npc_registry["herbalist"] = herbalist
	
	# Farmer
	var farmer_npc = NPCDataScript.new()
	farmer_npc.npc_id = "farmer"
	farmer_npc.display_name = "Old Hank"
	farmer_npc.role = NPCDataScript.NPCRole.FARMER
	farmer_npc.title = "Farmer"
	farmer_npc.model_path = ADVENTURER_BARBARIAN
	farmer_npc.model_scale = 0.5
	farmer_npc.body_color = Color(0.65, 0.55, 0.4)
	farmer_npc.wander_radius = 3.0
	farmer_npc.greeting_lines = ["Fine day for farming!", "Howdy!", "Crops are coming in!"]
	farmer_npc.dialogue = [
		{"text": "Nothing beats a good day's work in the fields. I sell seeds and animal feed if you need 'em.", "choices": [
			{"text": "I'll take a look.", "action": "shop"},
			{"text": "Any farming tips?", "next": 1},
			{"text": "See you around.", "action": "close"},
		]},
		{"text": "Till the soil with a hoe, plant your seeds, water 'em, and wait. Different crops grow at different speeds. And don't forget to feed your animals!", "choices": [
			{"text": "Good advice, thanks!", "action": "close"},
		]}
	]
	farmer_npc.shop_inventory = [
		{"item_id": "animal_feed", "buy_price": 3, "stock": -1},
		{"item_id": "wheat", "buy_price": 2, "stock": -1},
	]
	farmer_npc.schedule = [
		{"hour": 5.0, "activity": "work", "target_pos": Vector3(11, 0, -2)},
		{"hour": 7.0, "activity": "work", "target_pos": Vector3(25, 0, -8)},
		{"hour": 12.0, "activity": "idle", "target_pos": Vector3(11, 0, -2)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(25, 0, -8)},
		{"hour": 17.0, "activity": "idle", "target_pos": Vector3(11, 0, -2)},
		{"hour": 19.0, "activity": "socialize", "target_pos": Vector3(35, 0, -10)},
		{"hour": 21.0, "activity": "sleep", "target_pos": Vector3(11, 0, -2)},
	]
	_npc_registry["farmer"] = farmer_npc
	# Guard
	var guard = NPCDataScript.new()
	guard.npc_id = "guard"
	guard.display_name = "Captain Rolf"
	guard.role = NPCDataScript.NPCRole.GUARD
	guard.title = "Guard Captain"
	guard.model_path = ADVENTURER_KNIGHT
	guard.model_scale = 0.5
	guard.body_color = Color(0.5, 0.5, 0.6)
	guard.wander_radius = 4.0
	guard.greeting_lines = ["Stay safe.", "Keep your wits about you.", "All clear... for now."]
	guard.dialogue = [
		{"text": "I keep watch over this village. The skeletons in the forest have been getting bolder lately.", "choices": [
			{"text": "I can help with that.", "next": 1},
			{"text": "I'll be careful.", "action": "close"},
		]},
		{"text": "If you're heading into the forest, bring a good weapon. Those bone-heads hit harder than they look.", "choices": [
			{"text": "Noted. Thanks.", "action": "close"},
		]}
	]
	guard.schedule = [
		{"hour": 6.0, "activity": "work", "target_pos": Vector3(17, 0, -10)},
		{"hour": 8.0, "activity": "work", "target_pos": Vector3(17, 0, -10)},
		{"hour": 12.0, "activity": "idle", "target_pos": Vector3(25, 0, 0)},
		{"hour": 13.0, "activity": "work", "target_pos": Vector3(25, 0, -5)},
		{"hour": 14.0, "activity": "work", "target_pos": Vector3(17, 0, -10)},
		{"hour": 18.0, "activity": "work", "target_pos": Vector3(25, 0, -5)},
		{"hour": 20.0, "activity": "sleep", "target_pos": Vector3(17, 0, -10)},
	]
	_npc_registry["guard"] = guard

func _spawn_claim_boundary(center: Vector3, radius: float, _owner: String) -> void:
	## Spawns visual boundary posts in a circle around the claim center.
	var num_posts := 8
	for i in range(num_posts):
		var angle := float(i) / float(num_posts) * TAU
		var offset := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var pos := center + offset
		if chunk_manager and chunk_manager.has_method("get_terrain_height"):
			pos.y = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
		var post := PlaceableObject.new()
		post.name = "BoundaryPost_%d" % i
		post.set_meta("claim_owner", _owner)
		post.set_meta("is_boundary", true)
		post.setup("claim_post", "Boundary Post", "", 1.5, Vector3(0.15, 0.6, 0.15))
		post.global_position = pos
		add_child(post)
	# Tag the claim center node
	var marker := Node3D.new()
	marker.name = "ClaimCenter"
	marker.global_position = center
	marker.set_meta("claim_owner", _owner)
	marker.set_meta("claim_radius", radius)
	add_child(marker)

func _on_claim_post_placed(pos: Vector3) -> void:
	## Called when a claim post is placed in the world.
	var claim_radius := 8.0
	var owner_id := "player"
	_spawn_claim_boundary(pos, claim_radius, owner_id)
	_show_placed_notification("Claim Established", "Territory claimed!")

func _show_placed_notification(title: String, msg: String) -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.notification_shown.emit(title, msg, "info")

func _create_npc(npc_id: String, pos: Vector3) -> void:
	var data = _npc_registry.get(npc_id)
	if not data:
		push_warning("Unknown NPC: %s" % npc_id)
		return
	
	# Snap to terrain height — skip if in water
	if chunk_manager and chunk_manager.has_method("get_terrain_height"):
		var h: float = chunk_manager.get_terrain_height(Vector3(pos.x, 0, pos.z))
		if h < 1.0:
			push_warning("NPC %s skipped — spawn position in water" % npc_id)
			return
		pos.y = h
	else:
		pos.y = 30.0
	
	var npc = BaseNPCScript.new()
	npc.setup(data)
	npc.position = pos
	add_child(npc)
	_npc_nodes[npc_id] = npc
	
	# Connect NPC signals to UI
	npc.dialogue_requested.connect(_on_npc_dialogue_requested)
	npc.shop_requested.connect(_on_npc_shop_requested)

func _on_npc_dialogue_requested(npc: Node, npc_player: Node3D) -> void:
	var npc_id = npc.npc_data.npc_id if npc.npc_data else ""
	var qm = get_node_or_null("/root/QuestManager")
	
	# Check if NPC has quests to offer or turn in
	if qm and not npc_id.is_empty():
		# Turn in completed quests first
		var turnable = qm.get_turnable_quests_for_npc(npc_id)
		for quest_id in turnable:
			qm.turn_in_quest(quest_id)
		
		# Offer available quests
		var available = qm.get_available_quests_for_npc(npc_id)
		for quest_id in available:
			qm.accept_quest(quest_id)
		
		_refresh_npc_quest_glows()
	
	# Emit EventBus signal so QuestManager tracks TALK_TO_NPC objectives
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and not npc_id.is_empty():
		event_bus.npc_dialogue_started.emit(npc_id)
	
	if dialogue_ui and dialogue_ui.has_method("open"):
		dialogue_ui.open(npc, npc_player)

func _on_npc_shop_requested(npc: Node, npc_player: Node3D) -> void:
	if shop_ui and shop_ui.has_method("open"):
		shop_ui.open(npc, npc_player)

# ── Quest System Integration ──────────────────────────────────────────────────

var _npc_nodes: Dictionary = {}  # npc_id -> BaseNPC node

func _on_qm_quest_accepted(quest_id: String) -> void:
	# Auto-track in journal
	if quest_journal_ui and quest_journal_ui.has_method("auto_track_quest"):
		quest_journal_ui.auto_track_quest(quest_id)
		quest_journal_ui._sync_tracker_ui()
	else:
		# Fallback: add directly to tracker
		var tracker = _get_quest_tracker()
		var qm = get_node_or_null("/root/QuestManager")
		if tracker and qm:
			var quest = qm.quest_definitions.get(quest_id) as QuestData
			if quest:
				var objectives: Array = []
				for obj in quest.objectives:
					objectives.append({
						"text": obj.get("text", ""),
						"current": qm.get_objective_progress(quest_id, objectives.size()),
						"target": obj.get("target", 1),
					})
				tracker.add_quest(quest_id, quest.quest_name, objectives)
	_refresh_npc_quest_glows()

func _on_qm_objective_updated(quest_id: String, objective_index: int, current: int, _target: int) -> void:
	var tracker = _get_quest_tracker()
	if tracker:
		tracker.update_objective(quest_id, objective_index, current)

func _on_qm_quest_completed(_quest_id: String) -> void:
	# Quest objectives are done — if auto-turnin, it will fire turned_in next
	# If NPC turnin required, the glow will update
	_refresh_npc_quest_glows()

func _on_qm_quest_turned_in(quest_id: String) -> void:
	# Untrack from journal and HUD tracker
	if quest_journal_ui and quest_journal_ui.has_method("auto_untrack_quest"):
		quest_journal_ui.auto_untrack_quest(quest_id)
		quest_journal_ui._sync_tracker_ui()
	else:
		var tracker = _get_quest_tracker()
		if tracker:
			tracker.complete_quest(quest_id)
	_refresh_npc_quest_glows()

func _on_qm_reward_granted(quest_id: String, _rewards: Dictionary) -> void:
	## Grant reputation when a quest is turned in.
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var quest = qm.quest_definitions.get(quest_id) as QuestData
	if not quest:
		return
	# Reputation goes to the turnin NPC (or giver if no turnin)
	var npc_id: String = quest.turnin_npc_id if not quest.turnin_npc_id.is_empty() else quest.giver_npc_id
	if not npc_id.is_empty():
		modify_reputation(npc_id, 20)

func _on_qm_quest_available(quest_id: String) -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var quest = qm.quest_definitions.get(quest_id) as QuestData
	if not quest:
		return
	
	# Auto-accept quests with no giver NPC (they're given by the world/system)
	if quest.giver_npc_id.is_empty():
		qm.accept_quest(quest_id)
	else:
		_refresh_npc_quest_glows()

func get_quest_waypoint(quest_id: String) -> Vector3:
	## Returns a world-space position for the quest waypoint, or Vector3.ZERO if none.
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return Vector3.ZERO
	var quest = qm.quest_definitions.get(quest_id) as QuestData
	if not quest:
		return Vector3.ZERO
	var status = qm.get_quest_status(quest_id)
	# If complete, point to turnin NPC
	if status == QuestData.QuestStatus.COMPLETE:
		if not quest.turnin_npc_id.is_empty() and _npc_nodes.has(quest.turnin_npc_id):
			var npc = _npc_nodes[quest.turnin_npc_id]
			if is_instance_valid(npc):
				return npc.global_position
		return Vector3.ZERO
	# For active quests, find the first incomplete objective with a spatial target
	if status != QuestData.QuestStatus.ACTIVE:
		return Vector3.ZERO
	for i in range(quest.objectives.size()):
		var progress = qm.get_objective_progress(quest_id, i)
		var target = int(quest.objectives[i].get("target", 1))
		if progress >= target:
			continue
		var obj_type = int(quest.objectives[i].get("type", -1))
		var filter = quest.objectives[i].get("filter", "")
		match obj_type:
			QuestData.ObjectiveType.TALK_TO_NPC:
				if _npc_nodes.has(filter):
					var npc = _npc_nodes[filter]
					if is_instance_valid(npc):
						return npc.global_position
			QuestData.ObjectiveType.DEFEAT_ENEMY:
				var enemies = get_tree().get_nodes_in_group("enemies")
				for enemy in enemies:
					if is_instance_valid(enemy) and filter in enemy.name:
						return enemy.global_position
	# Fallback: point to giver NPC
	if not quest.giver_npc_id.is_empty() and _npc_nodes.has(quest.giver_npc_id):
		var npc = _npc_nodes[quest.giver_npc_id]
		if is_instance_valid(npc):
			return npc.global_position
	# Fallback: point to turnin NPC
	if not quest.turnin_npc_id.is_empty() and _npc_nodes.has(quest.turnin_npc_id):
		var npc = _npc_nodes[quest.turnin_npc_id]
		if is_instance_valid(npc):
			return npc.global_position
	return Vector3.ZERO

func get_tracked_quest_waypoints() -> Array:
	## Returns [{ "position": Vector3, "label": String, "color": Color }] for all tracked quests.
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return []
	var tracked_ids: Array = []
	if quest_journal_ui and quest_journal_ui.get("_tracked_quest_ids"):
		tracked_ids = quest_journal_ui.get("_tracked_quest_ids")
	var waypoints: Array = []
	for quest_id in tracked_ids:
		var pos = get_quest_waypoint(quest_id)
		if pos != Vector3.ZERO:
			var quest = qm.quest_definitions.get(quest_id) as QuestData
			var label = quest.quest_name if quest else quest_id
			var status = qm.get_quest_status(quest_id)
			var color = Color(1.0, 0.8, 0.2, 1.0)
			if status == QuestData.QuestStatus.COMPLETE:
				color = Color(0.3, 0.9, 0.3, 1.0)
			waypoints.append({"position": pos, "label": label, "color": color})
	return waypoints

func _refresh_npc_quest_glows() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	
	# Update glow on all registered NPCs
	for npc_id in _npc_nodes:
		if not is_instance_valid(_npc_nodes[npc_id]):
			continue
		var has_business = qm.npc_has_quest_business(npc_id)
		_npc_nodes[npc_id].set_quest_available(has_business)

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
		
		# H key to toggle herbarium
		elif event.keycode == KEY_H:
			if herbarium_ui:
				if herbarium_ui.visible:
					herbarium_ui.close()
				else:
					herbarium_ui.show_herbarium()
				get_viewport().set_input_as_handled()

		# J key to toggle quest journal
		elif event.keycode == KEY_J:
			if quest_journal_ui:
				if quest_journal_ui.visible:
					quest_journal_ui.close()
				else:
					quest_journal_ui.open()
				get_viewport().set_input_as_handled()
