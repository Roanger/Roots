extends Control
## Multiplayer Menu — lobby host/join via GD-Sync local multiplayer

@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var event_bus: Node = get_node_or_null("/root/EventBus")

var _lobby_name_edit: LineEdit = null
var _lobby_password_edit: LineEdit = null
var _lobby_list_container: VBoxContainer = null
var _status_label: Label = null
var _refresh_btn: Button = null
var _lobby_refresh_timer: float = 0.0
var _is_connected: bool = false
var _is_host: bool = false

func _ready() -> void:
	_build_ui()
	_connect_gdsync_signals()

func _process(delta: float) -> void:
	if _is_connected and _lobby_list_container and _lobby_list_container.visible:
		_lobby_refresh_timer += delta
		if _lobby_refresh_timer >= 5.0:
			_lobby_refresh_timer = 0.0
			_refresh_lobbies()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 480)
	panel.position = -panel.custom_minimum_size / 2
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Not connected"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_status_label)

	vbox.add_child(_make_section_label("Host a Game"))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = "Lobby Name:"
	name_label.custom_minimum_size = Vector2(120, 0)
	name_row.add_child(name_label)
	_lobby_name_edit = LineEdit.new()
	_lobby_name_edit.placeholder_text = "My Cozy Farm"
	_lobby_name_edit.max_length = 32
	name_row.add_child(_lobby_name_edit)
	vbox.add_child(name_row)

	var pass_row := HBoxContainer.new()
	pass_row.add_theme_constant_override("separation", 8)
	var pass_label := Label.new()
	pass_label.text = "Password:"
	pass_label.custom_minimum_size = Vector2(120, 0)
	pass_row.add_child(pass_label)
	_lobby_password_edit = LineEdit.new()
	_lobby_password_edit.placeholder_text = "(optional)"
	_lobby_password_edit.max_length = 16
	_lobby_password_edit.secret = true
	pass_row.add_child(_lobby_password_edit)
	vbox.add_child(pass_row)

	var host_btn := Button.new()
	host_btn.text = "Host Game"
	host_btn.custom_minimum_size = Vector2(0, 36)
	host_btn.pressed.connect(_on_host_pressed)
	vbox.add_child(host_btn)

	vbox.add_child(_make_section_label("Join a Game"))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(scroll)

	_lobby_list_container = VBoxContainer.new()
	_lobby_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_lobby_list_container)

	_refresh_btn = Button.new()
	_refresh_btn.text = "Refresh List"
	_refresh_btn.pressed.connect(_refresh_lobbies)
	vbox.add_child(_refresh_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	return label

func _make_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.5, 0.2, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _connect_gdsync_signals() -> void:
	var gdsync := get_node_or_null("/root/GDSync")
	if not gdsync:
		_status_label.text = "GD-Sync not loaded"
		return
	if gdsync.has_signal("connected"):
		gdsync.connected.connect(_on_gdsync_connected)
	if gdsync.has_signal("connection_failed"):
		gdsync.connection_failed.connect(_on_gdsync_connection_failed)
	if gdsync.has_signal("lobby_created"):
		gdsync.lobby_created.connect(_on_lobby_created)
	if gdsync.has_signal("lobby_creation_failed"):
		gdsync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	if gdsync.has_signal("lobby_joined"):
		gdsync.lobby_joined.connect(_on_lobby_joined)
	if gdsync.has_signal("lobby_join_failed"):
		gdsync.lobby_join_failed.connect(_on_lobby_join_failed)
	if gdsync.has_signal("lobbies_received"):
		gdsync.lobbies_received.connect(_on_lobbies_received)
	if gdsync.has_signal("client_joined"):
		gdsync.client_joined.connect(_on_client_joined)
	if gdsync.has_signal("client_left"):
		gdsync.client_left.connect(_on_client_left)

func _on_host_pressed() -> void:
	var gdsync := get_node_or_null("/root/GDSync")
	if not gdsync:
		_status_label.text = "GD-Sync not loaded"
		return
	var lobby_name := _lobby_name_edit.text.strip_edges()
	if lobby_name.is_empty():
		lobby_name = "Roots Co-op"
	_status_label.text = "Starting local multiplayer..."
	gdsync.start_local_multiplayer()
	_is_host = true
	# Create lobby after connection signal
	await get_tree().create_timer(0.5).timeout
	if _is_connected:
		gdsync.lobby_create(lobby_name, _lobby_password_edit.text)

func _on_lobby_created(lobby_name: String) -> void:
	_status_label.text = "Lobby '%s' created! Waiting for players..." % lobby_name
	if game_manager:
		game_manager.is_multiplayer = true
		# Set the world seed in lobby data so joiners use the same seed
		if game_manager.world_seed != 0:
			var gdsync := get_node_or_null("/root/GDSync")
			if gdsync:
				gdsync.lobby_set_data("seed", game_manager.world_seed)

func _on_lobby_creation_failed(lobby_name: String, error: int) -> void:
	_status_label.text = "Failed to create lobby (error %d)" % error
	_is_host = false

func _refresh_lobbies() -> void:
	var gdsync := get_node_or_null("/root/GDSync")
	if gdsync and _is_connected:
		gdsync.get_public_lobbies()

func _on_lobbies_received(lobbies: Array) -> void:
	if not _lobby_list_container:
		return
	for child in _lobby_list_container.get_children():
		child.queue_free()
	for lobby in lobbies:
		var btn := Button.new()
		var name_str: String = lobby.get("Name", "Unknown")
		var count: int = lobby.get("PlayerCount", 0)
		var limit: int = lobby.get("PlayerLimit", 0)
		var has_pass: bool = lobby.get("HasPassword", false)
		var label_text = "%s (%d/%d)" % [name_str, count, limit]
		if has_pass:
			label_text += " [locked]"
		if lobby.get("Open", true) == false:
			label_text += " [closed]"
		btn.text = label_text
		btn.custom_minimum_size = Vector2(0, 32)
		btn.disabled = not lobby.get("Open", true) or (limit > 0 and count >= limit)
		btn.pressed.connect(_on_join_lobby.bind(name_str, has_pass))
		_lobby_list_container.add_child(btn)
	if lobbies.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No lobbies found. Host one!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_lobby_list_container.add_child(empty_label)

func _on_join_lobby(lobby_name: String, has_password: bool) -> void:
	var gdsync := get_node_or_null("/root/GDSync")
	if not gdsync:
		return
	var password := ""
	if has_password:
		password = _lobby_password_edit.text
	_status_label.text = "Joining '%s'..." % lobby_name
	gdsync.lobby_join(lobby_name, password)

func _on_lobby_joined(lobby_name: String) -> void:
	_status_label.text = "Joined lobby: %s" % lobby_name
	if game_manager:
		game_manager.is_multiplayer = true
		var gdsync := get_node_or_null("/root/GDSync")
		if gdsync:
			game_manager.local_player_id = gdsync.get_client_id()
			# Read the world seed from lobby data if joiner
			if not _is_host:
				var seed_val = gdsync.lobby_get_data("seed", 0)
				if seed_val != 0:
					game_manager.world_seed = int(seed_val)
	if event_bus:
		var gdsync := get_node_or_null("/root/GDSync")
		if gdsync:
			event_bus.player_connected.emit(gdsync.get_client_id(), "")

func _on_lobby_join_failed(lobby_name: String, error: int) -> void:
	_status_label.text = "Failed to join '%s' (error %d)" % [lobby_name, error]

func _on_gdsync_connected() -> void:
	_is_connected = true
	var gdsync := get_node_or_null("/root/GDSync")
	if gdsync and game_manager:
		game_manager.local_player_id = gdsync.get_client_id()
	if _is_host:
		_status_label.text = "Connected! Creating lobby..."
	else:
		_status_label.text = "Connected! Refreshing lobbies..."
		_refresh_lobbies()

func _on_gdsync_connection_failed(error: int) -> void:
	_is_connected = false
	_status_label.text = "Connection failed (error %d)" % error

func _on_client_joined(client_id: int) -> void:
	var gdsync := get_node_or_null("/root/GDSync")
	var username := ""
	if gdsync:
		username = gdsync.player_get_username(client_id, "Player %d" % client_id)
	_status_label.text = "%s joined (id: %d)" % [username, client_id]
	if event_bus:
		event_bus.player_connected.emit(client_id, username)

func _on_client_left(client_id: int) -> void:
	_status_label.text = "Player %d left" % client_id
	if event_bus:
		event_bus.player_disconnected.emit(client_id)

func _on_back_pressed() -> void:
	var main_menu := get_parent()
	if main_menu and main_menu.has_method("_update_menu_state"):
		main_menu._update_menu_state("main")
