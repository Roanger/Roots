extends StaticBody3D
class_name HarvestableResource
## Base class for harvestable world objects (trees, rocks, ore nodes, etc.)
## Attach this script to the StaticBody3D collision node inside a world object.
## Implements get_target_type() and on_hit() for the ToolAffinity system.

const WorldItemScene = preload("res://src/items/world_item.tscn")

@export var max_health: float = 10.0
@export var resource_type: int = ToolAffinity.TargetType.TREE

# Loot table: array of { "item_id": String, "min_amount": int, "max_amount": int, "chance": float }
@export var loot_table: Array = []

# XP action to grant on each hit (e.g. "pick_mushroom", "forage_item")
@export var xp_action_id: String = ""

var current_health: float = 10.0
var _is_destroyed: bool = false
var _shake_tween: Tween = null
var _parent_object: Node3D = null  # The visual parent (tree/rock Node3D)

func _ready() -> void:
	current_health = max_health
	_parent_object = get_parent()

func get_target_type() -> int:
	return resource_type

func on_hit(player: Node3D, _tool_type: String, power: float = 1.0) -> void:
	if _is_destroyed:
		return
	
	current_health -= power
	
	# Visual feedback: shake
	_play_hit_effect()
	
	if current_health <= 0:
		_destroy(player)

func _play_hit_effect() -> void:
	if not _parent_object:
		return
	
	# Kill any existing shake tween
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	
	# Shake the parent visual object
	var original_pos = _parent_object.position
	_shake_tween = create_tween()
	_shake_tween.tween_property(_parent_object, "position",
		original_pos + Vector3(0.08, 0, 0), 0.05)
	_shake_tween.tween_property(_parent_object, "position",
		original_pos + Vector3(-0.08, 0, 0), 0.05)
	_shake_tween.tween_property(_parent_object, "position",
		original_pos + Vector3(0.04, 0, 0), 0.05)
	_shake_tween.tween_property(_parent_object, "position",
		original_pos, 0.05)

func _grant_xp(_player: Node3D, _power: float) -> void:
	if xp_action_id.is_empty():
		return
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager and skill_manager.has_method("grant_action_xp"):
		skill_manager.grant_action_xp(xp_action_id)

func _destroy(player: Node3D) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	
	# Grant XP once on destroy
	_grant_xp(player, 1.0)
	
	# Notify QuestManager for resource destroy objectives
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("on_resource_destroyed"):
		if resource_type == ToolAffinity.TargetType.TREE:
			qm.on_resource_destroyed("tree")
		elif resource_type == ToolAffinity.TargetType.ROCK:
			qm.on_resource_destroyed("rock")
	
	# Spawn loot drops
	_spawn_drops(player)
	
	# Play destruction animation then remove
	_play_destroy_animation()

func _spawn_drops(_player: Node3D) -> void:
	if not _parent_object:
		return
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var world_pos = _parent_object.global_position
	
	# Look up perk bonuses for yield and double harvest
	var yield_bonus := 0.0
	var double_chance := 0.0
	var sm = get_node_or_null("/root/SkillManager")
	if sm and sm.has_method("get_perk_bonus"):
		var skill_id = _get_skill_for_resource()
		if skill_id != "":
			yield_bonus = sm.get_perk_bonus(skill_id, 0)   # PerkData.PerkEffect.YIELD_BONUS
			double_chance = sm.get_perk_bonus(skill_id, 7)  # PerkData.PerkEffect.DOUBLE_HARVEST
	
	for loot in loot_table:
		var chance: float = loot.get("chance", 1.0)
		if rng.randf() > chance:
			continue
		
		var item_id: String = loot.get("item_id", "")
		var min_amt: int = loot.get("min_amount", 1)
		var max_amt: int = loot.get("max_amount", 1)
		var amount: int = rng.randi_range(min_amt, max_amt)
		
		# Apply yield bonus (round up any fractional bonus)
		if yield_bonus > 0.0:
			amount = int(ceil(amount * (1.0 + yield_bonus)))
		
		# Double harvest chance
		if double_chance > 0.0 and rng.randf() < double_chance:
			amount *= 2
		
		if item_id == "" or amount <= 0:
			continue
		
		# Spawn a WorldItem at a slightly randomized position
		var drop_pos = world_pos + Vector3(
			rng.randf_range(-0.8, 0.8),
			0.5,
			rng.randf_range(-0.8, 0.8)
		)
		_spawn_world_item(item_id, amount, drop_pos)

func _get_skill_for_resource() -> String:
	match resource_type:
		ToolAffinity.TargetType.TREE:
			return "lumberjack"
		ToolAffinity.TargetType.ROCK, ToolAffinity.TargetType.ORE_NODE:
			return "mining"
		ToolAffinity.TargetType.HERB:
			return "herb_gathering"
		ToolAffinity.TargetType.TALL_GRASS:
			return "foraging"
	return ""

func _spawn_world_item(item_id: String, amount: int, world_pos: Vector3) -> void:
	var world_item = WorldItemScene.instantiate() as WorldItem
	world_item.item_id = item_id
	world_item.quantity = amount
	world_item.auto_pickup = true
	world_item.position = world_pos
	
	# Add to the scene tree at a high level so it persists after parent is freed
	var tree_root = get_tree().current_scene
	if tree_root:
		tree_root.add_child(world_item)

func _play_destroy_animation() -> void:
	if not _parent_object:
		queue_free()
		return
	
	# Scale down and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_parent_object, "scale",
		Vector3(0.01, 0.01, 0.01), 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(_parent_object, "position:y",
		_parent_object.position.y - 0.5, 0.4).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_parent_object.queue_free)
