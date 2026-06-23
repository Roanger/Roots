extends Node3D
class_name WeatherEffects

const WEATHER_CLEAR := "clear"
const WEATHER_RAIN := "rain"
const WEATHER_STORM := "storm"
const WEATHER_SNOW := "snow"

@onready var event_bus := get_node_or_null("/root/EventBus") as Node
@onready var game_manager := get_node_or_null("/root/GameManager") as Node
@onready var weather_manager := get_node_or_null("/root/WeatherManager") as Node

var rain_particles: GPUParticles3D
var snow_particles: GPUParticles3D

var _current_type: String = WEATHER_CLEAR
var _current_intensity: float = 0.0

var _base_fog: float = 0.001
var _base_cloud_density: float = 1.5
var _base_cloud_color: Color = Color(0.8, 0.8, 0.8, 1.0)

var _target_fog: float = 0.001
var _target_cloud_density: float = 1.5
var _displayed_fog: float = 0.001
var _displayed_cloud_density: float = 1.5

func _ready() -> void:
	_create_rain_particles()
	_create_snow_particles()
	_connect_signals()
	if game_manager:
		_update_season_base(game_manager.current_season)

func _connect_signals() -> void:
	if event_bus:
		event_bus.weather_changed.connect(_on_weather_changed)
	if game_manager and game_manager.has_signal("season_changed"):
		game_manager.season_changed.connect(_on_season_changed)

func _on_weather_changed(weather_type: String, _intensity: float) -> void:
	_current_type = weather_type
	_current_intensity = 0.0
	_update_targets()

func _on_season_changed(season: int) -> void:
	_update_season_base(season)
	_update_targets()

func _update_season_base(season: int) -> void:
	match season:
		0:
			_base_cloud_density = 1.5
			_base_cloud_color = Color(0.8, 0.8, 0.8, 1.0)
			_base_fog = 0.001
		1:
			_base_cloud_density = 0.6
			_base_cloud_color = Color(0.9, 0.9, 0.95, 1.0)
			_base_fog = 0.0005
		2:
			_base_cloud_density = 2.0
			_base_cloud_color = Color(0.7, 0.68, 0.65, 1.0)
			_base_fog = 0.0015
		3:
			_base_cloud_density = 3.5
			_base_cloud_color = Color(0.6, 0.62, 0.65, 1.0)
			_base_fog = 0.002
		_:
			_base_cloud_density = 1.5
			_base_cloud_color = Color(0.8, 0.8, 0.8, 1.0)
			_base_fog = 0.001

func _update_targets() -> void:
	match _current_type:
		WEATHER_RAIN:
			_target_cloud_density = maxf(_base_cloud_density, 3.0)
			_target_fog = _base_fog * 3.0
		WEATHER_STORM:
			_target_cloud_density = 5.0
			_target_fog = _base_fog * 5.0
		WEATHER_SNOW:
			_target_cloud_density = maxf(_base_cloud_density, 3.5)
			_target_fog = _base_fog * 3.0
		_:
			_target_cloud_density = _base_cloud_density
			_target_fog = _base_fog

func _process(_delta: float) -> void:
	_follow_player()
	_tick_weather()

func _follow_player() -> void:
	var player := get_node_or_null("/root/MainWorld/Player")
	if player:
		global_position = player.global_position

func _tick_weather() -> void:
	if not weather_manager:
		return
	_current_intensity = weather_manager.intensity
	var should_rain := _current_type in [WEATHER_RAIN, WEATHER_STORM]
	var should_snow := _current_type == WEATHER_SNOW

	if should_rain:
		rain_particles.emitting = true
		rain_particles.amount_ratio = _current_intensity
	else:
		rain_particles.emitting = false

	if should_snow:
		snow_particles.emitting = true
		snow_particles.amount_ratio = _current_intensity
	else:
		snow_particles.emitting = false

	_displayed_fog = lerpf(_displayed_fog, _target_fog, 0.02)
	_displayed_cloud_density = lerpf(_displayed_cloud_density, _target_cloud_density, 0.02)
	_apply_environment()

func _apply_environment() -> void:
	var env_node := get_node_or_null("/root/MainWorld/WorldEnvironment") as WorldEnvironment
	if not env_node or not env_node.environment:
		return
	var env := env_node.environment

	env.fog_density = _displayed_fog

	if not env.sky or not env.sky.sky_material:
		return
	env.sky.sky_material.set_shader_parameter("cloud_density", _displayed_cloud_density)

	var storm_color := Color(0.55, 0.55, 0.6, 1.0)
	var cloud_color := _base_cloud_color.lerp(storm_color, _current_intensity * 0.4)
	env.sky.sky_material.set_shader_parameter("cloud_color", cloud_color)

func _create_rain_particles() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.emitting = false
	rain_particles.one_shot = false
	rain_particles.amount = 800
	rain_particles.lifetime = 0.8
	rain_particles.preprocess = 0.5
	rain_particles.explosiveness = 0.0
	rain_particles.randomness = 0.2
	rain_particles.fixed_fps = 0
	rain_particles.interpolate = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.DOWN
	material.spread = 15.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 28.0
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color = Color(0.8, 0.85, 1.0, 0.5)

	var alpha_grad := Gradient.new()
	alpha_grad.add_point(0.0, Color(1, 1, 1, 0.0))
	alpha_grad.add_point(0.1, Color(1, 1, 1, 0.6))
	alpha_grad.add_point(0.9, Color(1, 1, 1, 0.4))
	alpha_grad.add_point(1.0, Color(1, 1, 1, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = alpha_grad
	material.alpha_curve = grad_tex

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(8, 4, 8)

	rain_particles.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.015, 0.3)
	quad.flip_faces = false
	rain_particles.draw_pass_1 = quad

	add_child(rain_particles)

func _create_snow_particles() -> void:
	snow_particles = GPUParticles3D.new()
	snow_particles.name = "SnowParticles"
	snow_particles.emitting = false
	snow_particles.one_shot = false
	snow_particles.amount = 400
	snow_particles.lifetime = 3.5
	snow_particles.preprocess = 1.0
	snow_particles.explosiveness = 0.0
	snow_particles.randomness = 0.3
	snow_particles.fixed_fps = 0
	snow_particles.interpolate = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.DOWN
	material.spread = 30.0
	material.gravity = Vector3(0, -1.5, 0)
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 2.0
	material.scale_min = 0.8
	material.scale_max = 1.5
	material.color = Color(1, 1, 1, 0.85)

	var alpha_grad := Gradient.new()
	alpha_grad.add_point(0.0, Color(1, 1, 1, 0.0))
	alpha_grad.add_point(0.1, Color(1, 1, 1, 0.9))
	alpha_grad.add_point(0.8, Color(1, 1, 1, 0.8))
	alpha_grad.add_point(1.0, Color(1, 1, 1, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = alpha_grad
	material.alpha_curve = grad_tex

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(10, 6, 10)
	material.tangential_accel_min = -0.3
	material.tangential_accel_max = 0.3

	snow_particles.process_material = material

	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	snow_particles.draw_pass_1 = sphere

	add_child(snow_particles)
