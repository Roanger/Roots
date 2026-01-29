extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var new_game_btn: Button = $VBoxContainer/MarginContainer/VBoxContainer/NewGameBtn
@onready var load_game_btn: Button = $VBoxContainer/MarginContainer/VBoxContainer/LoadGameBtn
@onready var multiplayer_btn: Button = $VBoxContainer/MarginContainer/VBoxContainer/MultiplayerBtn
@onready var settings_btn: Button = $VBoxContainer/MarginContainer/VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $VBoxContainer/MarginContainer/VBoxContainer/QuitBtn
@onready var version_label: Label = $VBoxContainer/VersionLabel
@onready var save_slots_container: VBoxContainer = $SaveSlotsContainer

var menu_state: String = "main"

# Explicit references to autoload singletons
@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var settings: Node = get_node_or_null("/root/Settings")
@onready var save_manager: Node = get_node_or_null("/root/SaveManager")
@onready var event_bus: Node = get_node_or_null("/root/EventBus")

func _ready() -> void:
	# Connect signals
	new_game_btn.pressed.connect(_on_new_game_pressed)
	load_game_btn.pressed.connect(_on_load_game_pressed)
	multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Set version
	version_label.text = "Roots v0.1.0"
	
	# Apply initial settings
	if settings:
		settings.apply_settings()
		
	# Also update references to use renamed methods if needed
	
	# Connect time signal for day/night background
	if game_manager:
		game_manager.time_changed.connect(_on_time_changed)
	
	_update_menu_state("main")

func _on_new_game_pressed() -> void:
	# Show confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Start New Game"
	confirm_dialog.dialog_text = "Start a new game? This will overwrite any unsaved progress."
	confirm_dialog.confirmed.connect(_start_new_game)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered(Vector2i(400, 200))

func _start_new_game() -> void:
	if game_manager:
		game_manager.reset_game()
	# Load main world
	get_tree().change_scene_to_file("res://src/main/world/main_world.tscn")

func _on_load_game_pressed() -> void:
	_update_menu_state("load")

func _on_multiplayer_pressed() -> void:
	_update_menu_state("multiplayer")

func _on_settings_pressed() -> void:
	_update_menu_state("settings")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _update_menu_state(new_state: String) -> void:
	menu_state = new_state
	
	if event_bus:
		event_bus.emit_signal("menu_opened", new_state)
	
	# Hide/show appropriate elements based on state
	match new_state:
		"main":
			$VBoxContainer/MarginContainer/VBoxContainer.show()
			$SaveSlotsContainer.hide()
			$MultiplayerMenu.hide()
			$SettingsMenu.hide()
		"load":
			$VBoxContainer/MarginContainer/VBoxContainer.hide()
			$SaveSlotsContainer.show()
			$MultiplayerMenu.hide()
			$SettingsMenu.hide()
			_refresh_save_slots()
		"multiplayer":
			$VBoxContainer/MarginContainer/VBoxContainer.hide()
			$SaveSlotsContainer.hide()
			$MultiplayerMenu.show()
			$SettingsMenu.hide()
		"settings":
			$VBoxContainer/MarginContainer/VBoxContainer.hide()
			$SaveSlotsContainer.hide()
			$MultiplayerMenu.hide()
			$SettingsMenu.show()

func _refresh_save_slots() -> void:
	# Clear existing slot buttons
	for child in save_slots_container.get_children():
		child.queue_free()
	
	if not save_manager:
		return
	
	# Get save files
	var saves = save_manager.get_save_files()
	
	# Create buttons for each save
	for i in range(5):  # MAX_SAVE_SLOTS
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		
		if i < saves.size():
			var save = saves[i]
			btn.text = save_manager.get_save_slot_name(save.slot)
			btn.disabled = false
			btn.pressed.connect(func(): _load_save(save.filepath))
		else:
			btn.text = "Empty Slot " + str(i + 1)
			btn.disabled = true
		
		save_slots_container.add_child(btn)
	
	# Add back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(func(): _update_menu_state("main"))
	save_slots_container.add_child(back_btn)

func _load_save(filepath: String) -> void:
	if save_manager and save_manager.load_game(filepath):
		get_tree().change_scene_to_file("res://src/main/world/main_world.tscn")

func _on_time_changed(hour: float) -> void:
	# Update background color based on time of day
	var sky_color: Color
	
	if hour >= 5 and hour < 7:
		# Dawn
		sky_color = Color(1.0, 0.6, 0.4, 1.0)
	elif hour >= 7 and hour < 18:
		# Day
		sky_color = Color(0.53, 0.81, 0.92, 1.0)
	elif hour >= 18 and hour < 20:
		# Dusk
		sky_color = Color(0.8, 0.4, 0.4, 1.0)
	else:
		# Night
		sky_color = Color(0.1, 0.1, 0.3, 1.0)
	
	# Apply to background
	$Background.color = sky_color

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and menu_state == "main":
		# Do nothing in main menu
		pass
	elif event.is_action_pressed("pause") and menu_state != "main":
		_update_menu_state("main")
