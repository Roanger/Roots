extends Node3D
class_name InteriorManager
## Manages building interior scenes.
## Interiors are loaded at a hidden y-height and the player is teleported between
## the exterior door and the interior spawn point.

const INTERIOR_Y: float = 500.0

var _interiors: Dictionary = {}      # interior_id -> Node3D (interior root)
var _players_inside: Dictionary = {}  # interior_id -> Array of player NodePaths
var _return_positions: Dictionary = {}  # player_path + interior_id -> {pos: Vector3, rot: float}

func enter_interior(player: Node3D, interior_id: String, scene_path: String, spawn_offset: Vector3, return_pos: Vector3, return_rot: float) -> void:
	var interior = _get_or_load_interior(interior_id, scene_path)
	if not interior:
		return

	# Store return position
	var key = _player_key(player, interior_id)
	_return_positions[key] = {"pos": return_pos, "rot": return_rot}

	# Teleport player to interior spawn
	var spawn_pos = interior.global_position + spawn_offset
	player.global_position = spawn_pos
	player.rotation.y = 0.0

	# Track player inside
	if not _players_inside.has(interior_id):
		_players_inside[interior_id] = []
	var path_str = player.get_path()
	if path_str not in _players_inside[interior_id]:
		_players_inside[interior_id].append(path_str)

func exit_interior(player: Node3D, interior_id: String) -> void:
	var key = _player_key(player, interior_id)
	if _return_positions.has(key):
		var rp = _return_positions[key]
		player.global_position = rp.pos
		player.rotation.y = rp.rot
		_return_positions.erase(key)

	if _players_inside.has(interior_id):
		var path_str = player.get_path()
		_players_inside[interior_id].erase(path_str)
		if _players_inside[interior_id].is_empty():
			_unload_interior(interior_id)

func _get_or_load_interior(interior_id: String, scene_path: String) -> Node3D:
	if _interiors.has(interior_id):
		return _interiors[interior_id]

	var scene = load(scene_path) as PackedScene
	if not scene:
		push_error("InteriorManager: Cannot load interior scene: ", scene_path)
		return null

	var interior = scene.instantiate() as Node3D
	if not interior:
		return null

	interior.name = "Interior_" + interior_id
	var hash_val = abs(interior_id.hash()) % 1000
	interior.position = Vector3(hash_val * 50, INTERIOR_Y, 0)
	add_child(interior)
	_interiors[interior_id] = interior

	# Build the room, furnished per building role (interior_id), exit door, and lighting
	if interior.has_method("setup"):
		interior.setup(interior_id)

	# Fix exit doors inside this interior: set their interior_id to match
	_fix_exit_doors(interior, interior_id)

	_restore_decorations(interior)

	return interior

func _restore_decorations(interior: Node3D) -> void:
	## Player-placed decorations (flower pots, chairs, etc.) inside this specific
	## interior instance were saved as PlaceableObjects via the normal outdoor
	## placed_objects pipeline (main_world.gd's group-based scan already picks up
	## indirect children), just at this interior's y=500 pocket-dimension offset.
	## Restore only the ones that belong to THIS interior (matched by proximity to
	## its deterministic hash position — see _get_or_load_interior).
	var game_manager = get_node_or_null("/root/GameManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if not game_manager or not item_db:
		return
	var PlaceableObjectScript = load("res://src/world/placeable_object.gd")
	var objs_data: Array = game_manager.world_data.get("placed_objects", [])
	for data in objs_data:
		var pos_data: Dictionary = data.get("position", {})
		var pos := Vector3(pos_data.get("x", 0.0), pos_data.get("y", 0.0), pos_data.get("z", 0.0))
		if pos.y < 100.0:
			continue  # not an interior decoration
		if interior.global_position.distance_to(pos) > 5.0:
			continue  # belongs to a different interior instance
		var item_id: String = data.get("item_id", "")
		var item = item_db.get_item(item_id)
		if not item:
			continue
		var obj = PlaceableObjectScript.new()
		obj.name = "Placed_%s" % item_id
		interior.add_child(obj)
		obj.global_position = pos
		obj.rotation.y = data.get("rotation_y", 0.0)
		obj.setup(item_id, item.item_name, item.placeable_model_path, item.placeable_scale, item.placeable_collision_size, data.get("is_gate", false))

func _fix_exit_doors(node: Node, interior_id: String) -> void:
	for child in node.get_children():
		if child is BuildingDoor and child.is_exit:
			child.interior_id = interior_id
		_fix_exit_doors(child, interior_id)

func _unload_interior(interior_id: String) -> void:
	if not _interiors.has(interior_id):
		return
	var interior = _interiors[interior_id]
	if interior and is_instance_valid(interior):
		interior.queue_free()
	_interiors.erase(interior_id)

func get_interior_node(interior_id: String) -> Node3D:
	return _interiors.get(interior_id, null)

func is_player_inside(player: Node3D) -> bool:
	var path_str = player.get_path()
	for interior_id in _players_inside:
		if path_str in _players_inside[interior_id]:
			return true
	return false

func get_current_interior_id(player: Node3D) -> String:
	var path_str = player.get_path()
	for interior_id in _players_inside:
		if path_str in _players_inside[interior_id]:
			return interior_id
	return ""

func _player_key(player: Node3D, interior_id: String) -> String:
	return str(player.get_path()) + "::" + interior_id

func building_name_from_id(interior_id: String) -> String:
	match interior_id:
		"general_store": return "General Store"
		"tavern": return "Tavern"
		"blacksmith": return "Blacksmith"
		"bakery": return "Bakery"
		"town_hall": return "Town Hall"
		"herbalist": return "Herbalist"
		"farmer_house": return "Farmer House"
		"guard_post": return "Guard Post"
		"small_house": return "House"
		"large_house": return "Large House"
		_: return interior_id.capitalize()
