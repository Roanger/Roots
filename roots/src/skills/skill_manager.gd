extends Node
## SkillManager - Singleton that tracks all player skills, XP, levels, and perks
##
## Manages skill progression, level-up logic, perk unlocks, and synergy bonuses.
## Emits events through EventBus for UI updates and notifications.

# Skill state: { skill_id: { "xp": int, "level": int } }
var skills: Dictionary = {}

# Available skill points (earned on level-up)
var skill_points: int = 0

# Active perks: { perk_id: PerkData }
var active_perks: Dictionary = {}

# Skill definitions (populated in _ready)
var skill_definitions: Dictionary = {}

# Reference to event bus
var event_bus: Node = null

# XP table per skill (matching the game plan)
const BASE_XP_ACTIONS: Dictionary = {
	"pick_mushroom": {"skill": "herb_gathering", "xp": 2},
	"harvest_crop": {"skill": "cultivation", "xp": 5},
	"plant_seed": {"skill": "cultivation", "xp": 2},
	"water_crop": {"skill": "cultivation", "xp": 1},
	"till_soil": {"skill": "cultivation", "xp": 1},
	"mine_ore": {"skill": "mining", "xp": 8},
	"chop_tree": {"skill": "lumberjack", "xp": 5},
	"forage_item": {"skill": "foraging", "xp": 3},
	"cook_food": {"skill": "cooking", "xp": 10},
	"bake_item": {"skill": "baking", "xp": 12},
	"smelt_ore": {"skill": "blacksmithing", "xp": 15},
	"forge_item": {"skill": "blacksmithing", "xp": 20},
	"milk_animal": {"skill": "husbandry", "xp": 3},
	"feed_animal": {"skill": "husbandry", "xp": 2},
	"shear_animal": {"skill": "husbandry", "xp": 4},
	"brew_potion": {"skill": "alchemy", "xp": 20},
	"extract_herb": {"skill": "alchemy", "xp": 8},
	"defeat_enemy": {"skill": "militia", "xp": 25},
	"craft_item": {"skill": "crafting", "xp": 5},
}

# Mastery threshold for perk bonuses
const MASTERY_LEVEL: int = 50

# Synergy definitions: { perk_id: { "skills": [skill_ids], "bonus_type": str, "bonus_value": float } }
const SYNERGY_PERKS: Dictionary = {
	"farmer_alchemist": {
		"skills": ["cultivation", "alchemy"],
		"bonus_type": "herb_yield",
		"bonus_value": 0.10,
		"description": "Farmer + Alchemist: +10% herb yield"
	},
	"blacksmith_militia": {
		"skills": ["blacksmithing", "militia"],
		"bonus_type": "weapon_damage",
		"bonus_value": 0.10,
		"description": "Blacksmith + Militia: +10% weapon damage"
	},
	"cook_baker": {
		"skills": ["cooking", "baking"],
		"bonus_type": "food_restoration",
		"bonus_value": 0.15,
		"description": "Cook + Baker: +15% food hunger restoration"
	},
	"farmer_husbandry_cooking": {
		"skills": ["cultivation", "husbandry", "cooking"],
		"bonus_type": "cook_animal_products",
		"bonus_value": 0.25,
		"description": "Farmer + Husbandry + Cooking: +25% efficiency with animal products"
	},
}

func _ready() -> void:
	event_bus = get_node_or_null("/root/EventBus")
	_register_default_skills()

func _register_default_skills() -> void:
	# Core skills
	_register_skill("cultivation", "Cultivation", SkillData.SkillCategory.CULTIVATION)
	_register_skill("foraging", "Foraging", SkillData.SkillCategory.GATHERING)
	_register_skill("mining", "Mining", SkillData.SkillCategory.GATHERING)
	_register_skill("lumberjack", "Lumberjack", SkillData.SkillCategory.GATHERING)
	_register_skill("crafting", "Crafting", SkillData.SkillCategory.CRAFTING)
	# Professions
	_register_skill("blacksmithing", "Blacksmithing", SkillData.SkillCategory.BLACKSMITHING)
	_register_skill("cooking", "Cooking", SkillData.SkillCategory.COOKING)
	_register_skill("baking", "Baking", SkillData.SkillCategory.BAKING)
	_register_skill("husbandry", "Husbandry", SkillData.SkillCategory.HUSBANDRY)
	_register_skill("alchemy", "Alchemy", SkillData.SkillCategory.ALCHEMY)
	_register_skill("militia", "Militia", SkillData.SkillCategory.MILITIA)
	_register_skill("herb_gathering", "Herb Gathering", SkillData.SkillCategory.HERB_GATHERING)

func _register_skill(skill_id: String, display_name: String, category: SkillData.SkillCategory) -> void:
	var data = SkillData.new()
	data.skill_id = skill_id
	data.display_name = display_name
	data.category = category
	skill_definitions[skill_id] = data
	# Initialize skill state if not already present
	if not skills.has(skill_id):
		skills[skill_id] = {"xp": 0, "level": 1}

# =====================
# XP & LEVELING
# =====================

func grant_xp(skill_id: String, amount: int) -> void:
	if not skills.has(skill_id):
		push_warning("SkillManager: Unknown skill '%s'" % skill_id)
		return
	
	var skill = skills[skill_id]
	var definition = skill_definitions.get(skill_id) as SkillData
	if not definition:
		return
	
	# Don't grant XP if at max level
	if skill["level"] >= definition.max_level:
		return
	
	# Apply mastery bonus if applicable
	var bonus_mult = get_xp_bonus_multiplier(skill_id)
	var final_amount = int(amount * (1.0 + bonus_mult))
	
	skill["xp"] += final_amount
	
	# Emit XP gained event
	if event_bus:
		event_bus.notify_skill_gain(skill_id, final_amount)
	
	# Check for level up
	_check_level_up(skill_id)

func grant_action_xp(action_id: String) -> void:
	if not BASE_XP_ACTIONS.has(action_id):
		return
	var action = BASE_XP_ACTIONS[action_id]
	grant_xp(action["skill"], action["xp"])

func _check_level_up(skill_id: String) -> void:
	var skill = skills[skill_id]
	var definition = skill_definitions.get(skill_id) as SkillData
	if not definition:
		return
	
	var _leveled_up := false
	while skill["level"] < definition.max_level:
		var xp_needed = definition.get_xp_for_level(skill["level"] + 1)
		if skill["xp"] >= xp_needed:
			skill["xp"] -= xp_needed
			skill["level"] += 1
			skill_points += 1
			_leveled_up = true
			
			if event_bus:
				event_bus.notify_level_up(skill_id, skill["level"])
			
			# Check for new synergy perks
			_check_synergy_perks()
		else:
			break

func get_skill_level(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id]["level"]
	return 0

func get_skill_xp(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id]["xp"]
	return 0

func get_xp_to_next_level(skill_id: String) -> int:
	var definition = skill_definitions.get(skill_id) as SkillData
	if not definition:
		return 0
	var level = get_skill_level(skill_id)
	if level >= definition.max_level:
		return 0
	return definition.get_xp_for_level(level + 1)

func get_xp_progress(skill_id: String) -> float:
	var xp_needed = get_xp_to_next_level(skill_id)
	if xp_needed <= 0:
		return 1.0
	return float(get_skill_xp(skill_id)) / float(xp_needed)

func get_total_level() -> int:
	var total := 0
	for skill_id in skills:
		total += skills[skill_id]["level"]
	return total

# =====================
# PERKS & SYNERGIES
# =====================

func get_xp_bonus_multiplier(skill_id: String) -> float:
	var bonus := 0.0
	# Mastery bonus: +20% if skill is level 50+
	if get_skill_level(skill_id) >= MASTERY_LEVEL:
		bonus += 0.20
	return bonus

func get_skill_modifier(bonus_type: String) -> float:
	var total := 0.0
	for perk_id in active_perks:
		var perk = active_perks[perk_id]
		if perk.get("bonus_type", "") == bonus_type:
			total += perk.get("bonus_value", 0.0)
	# Add mastery bonuses for relevant skills
	return total

func _check_synergy_perks() -> void:
	for perk_id in SYNERGY_PERKS:
		if active_perks.has(perk_id):
			continue
		var perk = SYNERGY_PERKS[perk_id]
		var all_met := true
		for required_skill in perk["skills"]:
			if get_skill_level(required_skill) < MASTERY_LEVEL:
				all_met = false
				break
		if all_met:
			active_perks[perk_id] = perk
			if event_bus:
				event_bus.emit_signal("notification_shown",
					"Synergy Unlocked!",
					perk.get("description", perk_id),
					"success")

func has_perk(perk_id: String) -> bool:
	return active_perks.has(perk_id)

func get_all_skill_ids() -> Array:
	return skill_definitions.keys()

func get_skill_definition(skill_id: String) -> SkillData:
	return skill_definitions.get(skill_id)

func get_skills_by_category(category: SkillData.SkillCategory) -> Array:
	var result := []
	for skill_id in skill_definitions:
		var def = skill_definitions[skill_id] as SkillData
		if def and def.category == category:
			result.append(skill_id)
	return result

# =====================
# SAVE / LOAD
# =====================

func serialize() -> Dictionary:
	var data: Dictionary = {
		"skills": {},
		"skill_points": skill_points,
		"active_perks": active_perks.keys(),
	}
	for skill_id in skills:
		data["skills"][skill_id] = {
			"xp": skills[skill_id]["xp"],
			"level": skills[skill_id]["level"],
		}
	return data

func deserialize(data: Dictionary) -> void:
	skill_points = data.get("skill_points", 0)
	
	var saved_skills = data.get("skills", {})
	for skill_id in saved_skills:
		if skills.has(skill_id):
			skills[skill_id]["xp"] = saved_skills[skill_id].get("xp", 0)
			skills[skill_id]["level"] = saved_skills[skill_id].get("level", 1)
	
	# Restore active perks
	active_perks.clear()
	var saved_perks = data.get("active_perks", [])
	for perk_id in saved_perks:
		if SYNERGY_PERKS.has(perk_id):
			active_perks[perk_id] = SYNERGY_PERKS[perk_id]

func reset_all() -> void:
	for skill_id in skills:
		skills[skill_id] = {"xp": 0, "level": 1}
	skill_points = 0
	active_perks.clear()
