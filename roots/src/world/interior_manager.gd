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

	# Fix exit doors inside this interior: set their interior_id to match
	_fix_exit_doors(interior, interior_id)

	return interior

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
