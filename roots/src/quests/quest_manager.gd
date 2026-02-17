extends Node
## Singleton that manages all quest state: tracking, progression, completion, rewards.
## Listens to EventBus signals and auto-updates objective progress.

signal quest_available(quest_id: String)
signal quest_accepted(quest_id: String)
signal quest_objective_updated(quest_id: String, objective_index: int, current: int, target: int)
signal quest_completed(quest_id: String)
signal quest_turned_in(quest_id: String)
signal quest_reward_granted(quest_id: String, rewards: Dictionary)

# All registered quest definitions: quest_id -> QuestData
var quest_definitions: Dictionary = {}

# Runtime quest state: quest_id -> { "status": QuestData.QuestStatus, "progress": [int, ...] }
var quest_states: Dictionary = {}

var event_bus: Node = null
var _inventory: Inventory = null

func _ready() -> void:
	event_bus = get_node_or_null("/root/EventBus")
	_connect_event_bus()

func set_inventory(inv: Inventory) -> void:
	if _inventory and _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
	_inventory = inv
	if _inventory:
		_inventory.inventory_changed.connect(_on_inventory_changed)
		if _inventory.has_signal("hotbar_changed"):
			if not _inventory.hotbar_changed.is_connected(_on_inventory_changed):
				_inventory.hotbar_changed.connect(_on_inventory_changed)

# =====================
# QUEST REGISTRATION
# =====================

func register_quest(quest: QuestData) -> void:
	if quest.quest_id.is_empty():
		push_warning("QuestManager: Cannot register quest with empty ID")
		return
	quest_definitions[quest.quest_id] = quest
	if not quest_states.has(quest.quest_id):
		quest_states[quest.quest_id] = {
			"status": QuestData.QuestStatus.UNAVAILABLE,
			"progress": [],
		}
		# Initialize progress array
		for i in range(quest.objectives.size()):
			quest_states[quest.quest_id]["progress"].append(0)

func make_available(quest_id: String) -> void:
	if not quest_definitions.has(quest_id):
		return
	var state = quest_states[quest_id]
	if state["status"] == QuestData.QuestStatus.UNAVAILABLE:
		state["status"] = QuestData.QuestStatus.AVAILABLE
		quest_available.emit(quest_id)

func check_prerequisites(quest_id: String) -> bool:
	if not quest_definitions.has(quest_id):
		return false
	var quest = quest_definitions[quest_id] as QuestData
	
	# Check required quests
	for req_id in quest.required_quests:
		if not quest_states.has(req_id):
			return false
		if quest_states[req_id]["status"] != QuestData.QuestStatus.TURNED_IN:
			return false
	
	# Check required skill levels
	if not quest.required_level.is_empty():
		var sm = get_node_or_null("/root/SkillManager")
		if sm:
			for skill_id in quest.required_level:
				var req_level = quest.required_level[skill_id]
				var current_level = sm.get_skill_level(skill_id) if sm.has_method("get_skill_level") else 0
				if current_level < req_level:
					return false
	
	return true

# =====================
# QUEST FLOW
# =====================

func accept_quest(quest_id: String) -> bool:
	if not quest_definitions.has(quest_id):
		return false
	var state = quest_states[quest_id]
	if state["status"] != QuestData.QuestStatus.AVAILABLE:
		return false
	
	state["status"] = QuestData.QuestStatus.ACTIVE
	quest_accepted.emit(quest_id)
	# Immediately check inventory for any COLLECT_ITEM objectives
	refresh_collect_objectives()
	return true

func is_quest_active(quest_id: String) -> bool:
	if not quest_states.has(quest_id):
		return false
	return quest_states[quest_id]["status"] == QuestData.QuestStatus.ACTIVE

func is_quest_complete(quest_id: String) -> bool:
	if not quest_states.has(quest_id):
		return false
	return quest_states[quest_id]["status"] == QuestData.QuestStatus.COMPLETE

func is_quest_turned_in(quest_id: String) -> bool:
	if not quest_states.has(quest_id):
		return false
	return quest_states[quest_id]["status"] == QuestData.QuestStatus.TURNED_IN

func is_quest_available(quest_id: String) -> bool:
	if not quest_states.has(quest_id):
		return false
	return quest_states[quest_id]["status"] == QuestData.QuestStatus.AVAILABLE

func get_quest_status(quest_id: String) -> int:
	if not quest_states.has(quest_id):
		return QuestData.QuestStatus.UNAVAILABLE
	return quest_states[quest_id]["status"]

func get_active_quests() -> Array:
	var result: Array = []
	for quest_id in quest_states:
		if quest_states[quest_id]["status"] == QuestData.QuestStatus.ACTIVE:
			result.append(quest_id)
	return result

func get_available_quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for quest_id in quest_definitions:
		var quest = quest_definitions[quest_id] as QuestData
		if quest.giver_npc_id == npc_id:
			var status = quest_states[quest_id]["status"]
			if status == QuestData.QuestStatus.AVAILABLE:
				result.append(quest_id)
	return result

func get_turnable_quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for quest_id in quest_definitions:
		var quest = quest_definitions[quest_id] as QuestData
		if quest.turnin_npc_id == npc_id:
			var status = quest_states[quest_id]["status"]
			if status == QuestData.QuestStatus.COMPLETE:
				result.append(quest_id)
	return result

func npc_has_quest_business(npc_id: String) -> bool:
	if get_available_quests_for_npc(npc_id).size() > 0:
		return true
	if get_turnable_quests_for_npc(npc_id).size() > 0:
		return true
	# Also glow if an active quest has an incomplete TALK_TO_NPC objective for this NPC
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.TALK_TO_NPC:
				if obj.get("filter", "") == npc_id:
					var progress = quest_states[quest_id]["progress"][i]
					if progress < obj.get("target", 1):
						return true
	return false

# =====================
# OBJECTIVE PROGRESS
# =====================

func update_objective(quest_id: String, obj_index: int, amount: int) -> void:
	if not quest_states.has(quest_id):
		return
	var state = quest_states[quest_id]
	if state["status"] != QuestData.QuestStatus.ACTIVE:
		return
	if obj_index < 0 or obj_index >= state["progress"].size():
		return
	
	var quest = quest_definitions[quest_id] as QuestData
	var target = quest.objectives[obj_index].get("target", 1)
	var new_val = mini(amount, target)
	var old_val = state["progress"][obj_index]
	if new_val == old_val:
		return
	state["progress"][obj_index] = new_val
	
	quest_objective_updated.emit(quest_id, obj_index, new_val, target)
	
	# Check if all objectives are met
	_check_completion(quest_id)

func increment_objective(quest_id: String, obj_index: int, amount: int = 1) -> void:
	if not quest_states.has(quest_id):
		return
	var state = quest_states[quest_id]
	if state["status"] != QuestData.QuestStatus.ACTIVE:
		return
	if obj_index < 0 or obj_index >= state["progress"].size():
		return
	
	var current = state["progress"][obj_index]
	update_objective(quest_id, obj_index, current + amount)

func get_objective_progress(quest_id: String, obj_index: int) -> int:
	if not quest_states.has(quest_id):
		return 0
	var state = quest_states[quest_id]
	if obj_index < 0 or obj_index >= state["progress"].size():
		return 0
	return state["progress"][obj_index]

func _check_completion(quest_id: String) -> void:
	if not quest_definitions.has(quest_id):
		return
	var quest = quest_definitions[quest_id] as QuestData
	var state = quest_states[quest_id]
	
	if state["status"] != QuestData.QuestStatus.ACTIVE:
		return
	
	var all_done := true
	for i in range(quest.objectives.size()):
		var target = quest.objectives[i].get("target", 1)
		if state["progress"][i] < target:
			all_done = false
			break
	
	if all_done:
		state["status"] = QuestData.QuestStatus.COMPLETE
		quest_completed.emit(quest_id)
		
		# Auto turn-in if no turnin NPC specified
		if quest.turnin_npc_id.is_empty():
			turn_in_quest(quest_id)

# =====================
# TURN-IN & REWARDS
# =====================

func turn_in_quest(quest_id: String) -> bool:
	if not quest_definitions.has(quest_id):
		return false
	var state = quest_states[quest_id]
	if state["status"] != QuestData.QuestStatus.COMPLETE:
		return false
	
	var quest = quest_definitions[quest_id] as QuestData
	state["status"] = QuestData.QuestStatus.TURNED_IN
	
	# Grant rewards
	_grant_rewards(quest)
	
	quest_turned_in.emit(quest_id)
	
	# Unlock follow-up quests
	for unlock_id in quest.reward_unlock_quests:
		if quest_definitions.has(unlock_id) and check_prerequisites(unlock_id):
			make_available(unlock_id)
	
	# Check if any other quests now have their prerequisites met
	_refresh_available_quests()
	
	return true

func _grant_rewards(quest: QuestData) -> void:
	var rewards := {}
	
	# XP rewards
	if not quest.reward_xp.is_empty():
		var sm = get_node_or_null("/root/SkillManager")
		if sm and sm.has_method("grant_xp"):
			for skill_id in quest.reward_xp:
				sm.grant_xp(skill_id, int(quest.reward_xp[skill_id]))
			rewards["xp"] = quest.reward_xp
	
	# Item rewards
	if quest.reward_items.size() > 0 and _inventory:
		var item_db = get_node_or_null("/root/ItemDatabase")
		if item_db:
			for reward in quest.reward_items:
				var item = item_db.get_item(reward.get("item_id", ""))
				if item:
					_inventory.add_item(item, reward.get("amount", 1))
			rewards["items"] = quest.reward_items
	
	# Gold reward
	if quest.reward_gold > 0 and _inventory:
		var item_db = get_node_or_null("/root/ItemDatabase")
		if item_db:
			var gold = item_db.get_item("gold_coin")
			if gold:
				_inventory.add_item(gold, quest.reward_gold)
			rewards["gold"] = quest.reward_gold
	
	if not rewards.is_empty():
		quest_reward_granted.emit(quest.quest_id, rewards)
		# Show notification
		if event_bus:
			var msg = "Quest Complete: %s" % quest.quest_name
			event_bus.notification_shown.emit("Quest Reward", msg, "success")

func _refresh_available_quests() -> void:
	for quest_id in quest_definitions:
		var state = quest_states[quest_id]
		if state["status"] == QuestData.QuestStatus.UNAVAILABLE:
			if check_prerequisites(quest_id):
				make_available(quest_id)

# =====================
# EVENT BUS LISTENERS
# =====================

func _connect_event_bus() -> void:
	if not event_bus:
		return
	event_bus.enemy_defeated.connect(_on_enemy_defeated)
	event_bus.soil_tilled.connect(_on_soil_tilled)
	event_bus.crop_planted.connect(_on_crop_planted)
	event_bus.crop_harvested.connect(_on_crop_harvested)
	event_bus.npc_dialogue_started.connect(_on_npc_talked)
	event_bus.crafting_completed.connect(_on_crafting_completed)

func _on_inventory_changed(_slot_index: int) -> void:
	refresh_collect_objectives()

func refresh_collect_objectives() -> void:
	if not _inventory:
		return
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.COLLECT_ITEM:
				var item_id = obj.get("filter", "")
				if item_id.is_empty():
					continue
				var count = _inventory.get_item_count(item_id)
				update_objective(quest_id, i, count)

func _on_enemy_defeated(enemy_name: String) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.DEFEAT_ENEMY:
				var filter = obj.get("filter", "")
				if filter.is_empty() or filter in enemy_name:
					increment_objective(quest_id, i, 1)

func _on_soil_tilled(_pos: Vector3) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.TILL_SOIL:
				increment_objective(quest_id, i, 1)

func _on_crop_planted(_pos: Vector3, crop_type: String) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.PLANT_CROP:
				var filter = obj.get("filter", "")
				if filter.is_empty() or filter == crop_type:
					increment_objective(quest_id, i, 1)

func _on_crop_harvested(_pos: Vector3, crop_type: String, amount: int) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.HARVEST_CROP:
				var filter = obj.get("filter", "")
				if filter.is_empty() or filter == crop_type:
					increment_objective(quest_id, i, amount)

func _on_npc_talked(npc_id: String) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.TALK_TO_NPC:
				if obj.get("filter", "") == npc_id:
					increment_objective(quest_id, i, 1)

func _on_crafting_completed(recipe_id: String, _output: Dictionary) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			var obj_type = obj.get("type", -1)
			if obj_type == QuestData.ObjectiveType.CRAFT_ITEM or \
			   obj_type == QuestData.ObjectiveType.COOK_RECIPE or \
			   obj_type == QuestData.ObjectiveType.BREW_POTION:
				var filter = obj.get("filter", "")
				if filter.is_empty() or filter == recipe_id:
					increment_objective(quest_id, i, 1)

# =====================
# RESOURCE DESTROY TRACKING (called from HarvestableResource)
# =====================

func on_resource_destroyed(resource_type: String) -> void:
	for quest_id in get_active_quests():
		var quest = quest_definitions[quest_id] as QuestData
		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			if obj.get("type", -1) == QuestData.ObjectiveType.MINE_RESOURCE and resource_type == "rock":
				increment_objective(quest_id, i, 1)
			elif obj.get("type", -1) == QuestData.ObjectiveType.CHOP_RESOURCE and resource_type == "tree":
				increment_objective(quest_id, i, 1)

# =====================
# SAVE / LOAD
# =====================

func get_save_data() -> Dictionary:
	return quest_states.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	for quest_id in data:
		if quest_states.has(quest_id):
			quest_states[quest_id] = data[quest_id]
