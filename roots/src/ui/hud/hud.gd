extends Control
class_name HUD
## HUD - Displays player health, stamina, and mini-map

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var mini_map: SubViewportContainer = $MiniMapContainer
@onready var mini_map_camera: Camera3D = $MiniMapContainer/SubViewport/MiniMapCamera

@export var mini_map_height: float = 40.0  # Height above player

var player: Node = null

func _ready() -> void:
	# Initially hidden until initialized
	visible = false

func initialize(p_player: Node) -> void:
	player = p_player
	
	if not player:
		push_error("HUD: No player provided")
		return
	
	# Connect to player signals
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	
	# Initialize bars with current values
	_update_health_bar(player.current_health, player.max_health)
	_update_stamina_bar(player.current_stamina, player.max_stamina)
	
	visible = true
	print("HUD initialized")

func _process(_delta: float) -> void:
	# Update mini-map camera to follow player
	if player and mini_map_camera:
		var player_pos = player.global_position
		mini_map_camera.global_position = Vector3(player_pos.x, player_pos.y + mini_map_height, player_pos.z)

func _on_health_changed(current: float, maximum: float) -> void:
	_update_health_bar(current, maximum)

func _on_stamina_changed(current: float, maximum: float) -> void:
	_update_stamina_bar(current, maximum)

func _update_health_bar(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current

func _update_stamina_bar(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
