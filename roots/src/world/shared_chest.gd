extends StaticBody3D
class_name SharedChest
## A shared storage chest that all players can access.
## Stores items in world_data so they persist across sessions.

var inventory: Inventory = null
var chest_id: String = ""
var _open: bool = false

func setup(p_chest_id: String, slot_count: int = 16) -> void:
	chest_id = p_chest_id
	inventory = Inventory.new(slot_count)
	_load_inventory()

	# Visual
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.6, 0.6)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.35, 0.15)
	mat.metallic = 0.2
	mat.roughness = 0.8
	mesh.material_override = mat
	mesh.position.y = 0.3
	add_child(mesh)

	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 0.6, 0.6)
	col.shape = shape
	col.position.y = 0.3
	add_child(col)

	collision_layer = 2
	collision_mask = 0

	# Lid visual
	var lid = MeshInstance3D.new()
	var lid_box = BoxMesh.new()
	lid_box.size = Vector3(0.8, 0.08, 0.5)
	lid.mesh = lid_box
	var lid_mat = StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.55, 0.4, 0.18)
	lid_mat.metallic = 0.15
	lid_mat.roughness = 0.7
	lid.material_override = lid_mat
	lid.position = Vector3(0, 0.65, -0.05)
	lid.name = "Lid"
	add_child(lid)

func on_interact(_player: Node3D) -> void:
	_open = not _open
	if _open:
		_open_chest()
	else:
		_close_chest()

func _open_chest() -> void:
	var lid = get_node_or_null("Lid")
	if lid:
		var tween = create_tween()
		tween.tween_property(lid, "rotation:x", deg_to_rad(-70.0), 0.3)
	# TODO: Open chest UI showing shared inventory

func _close_chest() -> void:
	var lid = get_node_or_null("Lid")
	if lid:
		var tween = create_tween()
		tween.tween_property(lid, "rotation:x", 0.0, 0.3)
	# TODO: Close chest UI

func get_interaction_text() -> String:
	return "Open Chest" if not _open else "Close Chest"

func get_target_type() -> int:
	return ToolAffinity.TargetType.CRAFTING_STATION  # Reuse for general interactable

func add_item(item_data, amount: int = 1) -> int:
	if not inventory:
		return amount
	var overflow = inventory.add_item(item_data, amount)
	_save_inventory()
	return overflow

func remove_item(item_id: String, amount: int = 1) -> int:
	if not inventory:
		return 0
	var removed = inventory.remove_item(item_id, amount)
	_save_inventory()
	return removed

func get_item_count(item_id: String) -> int:
	if not inventory:
		return 0
	return inventory.get_item_count(item_id)

func serialize() -> Dictionary:
	if not inventory:
		return {"chest_id": chest_id, "slots": []}
	var slots_data = []
	for i in range(inventory.slots.size()):
		var slot = inventory.slots[i]
		if slot and not slot.is_empty() and slot.item_data:
			slots_data.append({
				"index": i,
				"item_id": slot.item_data.id,
				"amount": slot.amount,
			})
	return {
		"chest_id": chest_id,
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"slots": slots_data,
	}

func _save_inventory() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	if not gm.has_method("set_world_data"):
		return
	var chests = gm.world_data.get("shared_chests", {})
	chests[chest_id] = serialize()
	gm.world_data["shared_chests"] = chests

func _load_inventory() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var chests = gm.world_data.get("shared_chests", {})
	if chests.has(chest_id):
		var data = chests[chest_id]
		if data.has("slots"):
			var item_db = get_node_or_null("/root/ItemDatabase")
			if item_db:
				for slot_data in data["slots"]:
					var item = item_db.get_item(slot_data["item_id"])
					if item:
						inventory.add_item(item, slot_data["amount"])
