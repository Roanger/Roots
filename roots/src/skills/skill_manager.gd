extends Node
## SkillManager - Singleton that tracks all player skills, XP, levels, and perks
##
## Manages skill progression, level-up logic, perk unlocks, and synergy bonuses.
## Emits events through EventBus for UI updates and notifications.

# Skill state: { skill_id: { "xp": int, "level": int } }
var skills: Dictionary = {}

# Available skill points (earned on level-up)
var skill_points: int = 0

# Active perks: { perk_id: PerkData } (synergy perks)
var active_perks: Dictionary = {}

# Skill definitions (populated in _ready)
var skill_definitions: Dictionary = {}

# Perk tree definitions: { perk_id: PerkData }
var perk_definitions: Dictionary = {}

# Unlocked perks: { perk_id: true }
var unlocked_perks: Dictionary = {}

signal perk_unlocked(perk_id: String)

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
	"pet_animal": {"skill": "husbandry", "xp": 1},
	"shear_animal": {"skill": "husbandry", "xp": 4},
	"breed_animal": {"skill": "husbandry", "xp": 15},
	"brew_potion": {"skill": "alchemy", "xp": 20},
	"extract_herb": {"skill": "alchemy", "xp": 8},
	"defeat_enemy": {"skill": "militia", "xp": 25},
	"craft_item": {"skill": "crafting", "xp": 5},
	"build_structure": {"skill": "crafting", "xp": 8},
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
	_register_default_perks()

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

func _register_perk(p_id: String, p_name: String, p_desc: String, p_skill: String,
		p_level: int, p_cost: int, p_prereq: String, p_effect: PerkData.PerkEffect,
		p_value: float, p_tier: int) -> void:
	var perk = PerkData.new()
	perk.perk_id = p_id
	perk.display_name = p_name
	perk.description = p_desc
	perk.skill_id = p_skill
	perk.required_skill_level = p_level
	perk.point_cost = p_cost
	perk.prerequisite_perk = p_prereq
	perk.effect_type = p_effect
	perk.effect_value = p_value
	perk.tier = p_tier
	perk_definitions[p_id] = perk

func _register_default_perks() -> void:
	# === CULTIVATION ===
	_register_perk("cult_green_thumb", "Green Thumb", "+10% crop yield",
		"cultivation", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("cult_fast_growth", "Fast Growth", "+15% crop growth speed",
		"cultivation", 10, 1, "cult_green_thumb", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("cult_double_harvest", "Bountiful Harvest", "10% chance to double harvest",
		"cultivation", 20, 2, "cult_fast_growth", PerkData.PerkEffect.DOUBLE_HARVEST, 0.10, 2)
	_register_perk("cult_master_farmer", "Master Farmer", "+20% XP from farming",
		"cultivation", 35, 2, "cult_double_harvest", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("cult_legendary", "Legendary Cultivator", "+25% crop yield",
		"cultivation", 50, 3, "cult_master_farmer", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === MINING ===
	_register_perk("mine_prospector", "Prospector", "+10% ore yield",
		"mining", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("mine_efficient", "Efficient Strikes", "+15% mining speed",
		"mining", 10, 1, "mine_prospector", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("mine_gem_finder", "Gem Finder", "10% chance for bonus gems",
		"mining", 20, 2, "mine_efficient", PerkData.PerkEffect.DOUBLE_HARVEST, 0.10, 2)
	_register_perk("mine_deep_veins", "Deep Veins", "+20% mining XP",
		"mining", 35, 2, "mine_gem_finder", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("mine_legendary", "Legendary Miner", "+25% ore yield",
		"mining", 50, 3, "mine_deep_veins", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === LUMBERJACK ===
	_register_perk("lumb_sharp_axe", "Sharp Axe", "+10% wood yield",
		"lumberjack", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("lumb_quick_chop", "Quick Chop", "+15% chopping speed",
		"lumberjack", 10, 1, "lumb_sharp_axe", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("lumb_double_logs", "Timber!", "10% chance for double logs",
		"lumberjack", 20, 2, "lumb_quick_chop", PerkData.PerkEffect.DOUBLE_HARVEST, 0.10, 2)
	_register_perk("lumb_woodsman", "Woodsman", "+20% lumberjack XP",
		"lumberjack", 35, 2, "lumb_double_logs", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("lumb_legendary", "Legendary Lumberjack", "+25% wood yield",
		"lumberjack", 50, 3, "lumb_woodsman", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === FORAGING ===
	_register_perk("forg_keen_eye", "Keen Eye", "+10% forage yield",
		"foraging", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("forg_quick_hands", "Quick Hands", "+15% gathering speed",
		"foraging", 10, 1, "forg_keen_eye", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("forg_lucky_find", "Lucky Find", "10% chance for rare finds",
		"foraging", 20, 2, "forg_quick_hands", PerkData.PerkEffect.DOUBLE_HARVEST, 0.10, 2)
	_register_perk("forg_naturalist", "Naturalist", "+20% foraging XP",
		"foraging", 35, 2, "forg_lucky_find", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("forg_legendary", "Legendary Forager", "+25% forage yield",
		"foraging", 50, 3, "forg_naturalist", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === CRAFTING ===
	_register_perk("craft_apprentice", "Apprentice Crafter", "+10% crafting speed",
		"crafting", 5, 1, "", PerkData.PerkEffect.SPEED_BONUS, 0.10, 0)
	_register_perk("craft_resourceful", "Resourceful", "10% chance to save materials",
		"crafting", 10, 1, "craft_apprentice", PerkData.PerkEffect.RESOURCE_SAVING, 0.10, 1)
	_register_perk("craft_quality", "Quality Work", "+15% quality chance",
		"crafting", 20, 2, "craft_resourceful", PerkData.PerkEffect.QUALITY_BONUS, 0.15, 2)
	_register_perk("craft_expert", "Expert Crafter", "+20% crafting XP",
		"crafting", 35, 2, "craft_quality", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("craft_legendary", "Legendary Crafter", "20% chance to save materials",
		"crafting", 50, 3, "craft_expert", PerkData.PerkEffect.RESOURCE_SAVING, 0.20, 4)

	# === BLACKSMITHING ===
	_register_perk("smith_heat_control", "Heat Control", "+10% smelting speed",
		"blacksmithing", 5, 1, "", PerkData.PerkEffect.SPEED_BONUS, 0.10, 0)
	_register_perk("smith_strong_arm", "Strong Arm", "+15% smithing damage bonus",
		"blacksmithing", 10, 1, "smith_heat_control", PerkData.PerkEffect.DAMAGE_BONUS, 0.15, 1)
	_register_perk("smith_alloy_master", "Alloy Master", "10% chance to save ore",
		"blacksmithing", 20, 2, "smith_strong_arm", PerkData.PerkEffect.RESOURCE_SAVING, 0.10, 2)
	_register_perk("smith_master", "Master Smith", "+20% blacksmithing XP",
		"blacksmithing", 35, 2, "smith_alloy_master", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("smith_legendary", "Legendary Blacksmith", "+25% quality chance on forged items",
		"blacksmithing", 50, 3, "smith_master", PerkData.PerkEffect.QUALITY_BONUS, 0.25, 4)

	# === COOKING ===
	_register_perk("cook_seasoning", "Seasoning", "+10% food restoration",
		"cooking", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("cook_quick_prep", "Quick Prep", "+15% cooking speed",
		"cooking", 10, 1, "cook_seasoning", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("cook_gourmet", "Gourmet", "+15% meal buff duration",
		"cooking", 20, 2, "cook_quick_prep", PerkData.PerkEffect.BUFF_DURATION, 0.15, 2)
	_register_perk("cook_chef", "Head Chef", "+20% cooking XP",
		"cooking", 35, 2, "cook_gourmet", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("cook_legendary", "Legendary Cook", "+25% food restoration",
		"cooking", 50, 3, "cook_chef", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === BAKING ===
	_register_perk("bake_fresh", "Fresh Bread", "+10% baked goods restoration",
		"baking", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("bake_quick_rise", "Quick Rise", "+15% baking speed",
		"baking", 10, 1, "bake_fresh", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("bake_golden_crust", "Golden Crust", "+15% quality chance",
		"baking", 20, 2, "bake_quick_rise", PerkData.PerkEffect.QUALITY_BONUS, 0.15, 2)
	_register_perk("bake_pastry_chef", "Pastry Chef", "+20% baking XP",
		"baking", 35, 2, "bake_golden_crust", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("bake_legendary", "Legendary Baker", "20% chance to save ingredients",
		"baking", 50, 3, "bake_pastry_chef", PerkData.PerkEffect.RESOURCE_SAVING, 0.20, 4)

	# === HUSBANDRY ===
	_register_perk("husb_gentle_hand", "Gentle Hand", "+10% animal product yield",
		"husbandry", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("husb_quick_care", "Quick Care", "+15% animal care speed",
		"husbandry", 10, 1, "husb_gentle_hand", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("husb_breeder", "Expert Breeder", "+15% breeding success",
		"husbandry", 20, 2, "husb_quick_care", PerkData.PerkEffect.QUALITY_BONUS, 0.15, 2)
	_register_perk("husb_rancher", "Master Rancher", "+20% husbandry XP",
		"husbandry", 35, 2, "husb_breeder", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("husb_legendary", "Legendary Rancher", "+25% animal product yield",
		"husbandry", 50, 3, "husb_rancher", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === ALCHEMY ===
	_register_perk("alch_careful_mix", "Careful Mixing", "+10% potion effectiveness",
		"alchemy", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("alch_quick_brew", "Quick Brew", "+15% brewing speed",
		"alchemy", 10, 1, "alch_careful_mix", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("alch_potent", "Potent Brews", "+20% buff duration",
		"alchemy", 20, 2, "alch_quick_brew", PerkData.PerkEffect.BUFF_DURATION, 0.20, 2)
	_register_perk("alch_conserve", "Conserve Reagents", "15% chance to save ingredients",
		"alchemy", 35, 2, "alch_potent", PerkData.PerkEffect.RESOURCE_SAVING, 0.15, 3)
	_register_perk("alch_legendary", "Legendary Alchemist", "+30% potion effectiveness",
		"alchemy", 50, 3, "alch_conserve", PerkData.PerkEffect.YIELD_BONUS, 0.30, 4)

	# === HERB GATHERING ===
	_register_perk("herb_sharp_eye", "Sharp Eye", "+10% herb yield",
		"herb_gathering", 5, 1, "", PerkData.PerkEffect.YIELD_BONUS, 0.10, 0)
	_register_perk("herb_quick_pick", "Quick Pick", "+15% gathering speed",
		"herb_gathering", 10, 1, "herb_sharp_eye", PerkData.PerkEffect.SPEED_BONUS, 0.15, 1)
	_register_perk("herb_rare_find", "Rare Find", "10% chance for rare herbs",
		"herb_gathering", 20, 2, "herb_quick_pick", PerkData.PerkEffect.DOUBLE_HARVEST, 0.10, 2)
	_register_perk("herb_botanist", "Botanist", "+20% herb gathering XP",
		"herb_gathering", 35, 2, "herb_rare_find", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("herb_legendary", "Legendary Herbalist", "+25% herb yield",
		"herb_gathering", 50, 3, "herb_botanist", PerkData.PerkEffect.YIELD_BONUS, 0.25, 4)

	# === MILITIA ===
	_register_perk("mil_combat_training", "Combat Training", "+10% weapon damage",
		"militia", 5, 1, "", PerkData.PerkEffect.DAMAGE_BONUS, 0.10, 0)
	_register_perk("mil_thick_skin", "Thick Skin", "+10% damage reduction",
		"militia", 10, 1, "mil_combat_training", PerkData.PerkEffect.DEFENSE_BONUS, 0.10, 1)
	_register_perk("mil_critical_eye", "Critical Eye", "+10% critical hit chance",
		"militia", 20, 2, "mil_thick_skin", PerkData.PerkEffect.CRIT_CHANCE, 0.10, 2)
	_register_perk("mil_veteran", "Veteran", "+20% combat XP",
		"militia", 35, 2, "mil_critical_eye", PerkData.PerkEffect.XP_BONUS, 0.20, 3)
	_register_perk("mil_legendary", "Legendary Warrior", "+25% damage, +50 max health",
		"militia", 50, 3, "mil_veteran", PerkData.PerkEffect.DAMAGE_BONUS, 0.25, 4)

# =====================
# PERK UNLOCK & QUERY
# =====================

func can_unlock_perk(perk_id: String) -> bool:
	if unlocked_perks.has(perk_id):
		return false
	var perk = perk_definitions.get(perk_id) as PerkData
	if not perk:
		return false
	if skill_points < perk.point_cost:
		return false
	if get_skill_level(perk.skill_id) < perk.required_skill_level:
		return false
	if perk.prerequisite_perk != "" and not unlocked_perks.has(perk.prerequisite_perk):
		return false
	return true

func unlock_perk(perk_id: String) -> bool:
	if not can_unlock_perk(perk_id):
		return false
	var perk = perk_definitions[perk_id] as PerkData
	skill_points -= perk.point_cost
	unlocked_perks[perk_id] = true
	perk_unlocked.emit(perk_id)
	if event_bus:
		event_bus.emit_signal("notification_shown",
			"Perk Unlocked!",
			perk.display_name + ": " + perk.description,
			"success")
	return true

func has_unlocked_perk(perk_id: String) -> bool:
	return unlocked_perks.has(perk_id)

func get_perks_for_skill(skill_id: String) -> Array:
	var result := []
	for perk_id in perk_definitions:
		var perk = perk_definitions[perk_id] as PerkData
		if perk and perk.skill_id == skill_id:
			result.append(perk)
	# Sort by tier
	result.sort_custom(func(a, b): return a.tier < b.tier)
	return result

func get_perk_bonus(skill_id: String, effect_type: PerkData.PerkEffect) -> float:
	var total := 0.0
	for perk_id in unlocked_perks:
		var perk = perk_definitions.get(perk_id) as PerkData
		if perk and perk.skill_id == skill_id and perk.effect_type == effect_type:
			total += perk.effect_value
	return total

func get_total_perk_bonus(effect_type: PerkData.PerkEffect) -> float:
	var total := 0.0
	for perk_id in unlocked_perks:
		var perk = perk_definitions.get(perk_id) as PerkData
		if perk and perk.effect_type == effect_type:
			total += perk.effect_value
	return total

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
	# Perk tree XP bonus
	bonus += get_perk_bonus(skill_id, PerkData.PerkEffect.XP_BONUS)
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
		"unlocked_perks": unlocked_perks.keys(),
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
	
	# Restore active synergy perks
	active_perks.clear()
	var saved_perks = data.get("active_perks", [])
	for perk_id in saved_perks:
		if SYNERGY_PERKS.has(perk_id):
			active_perks[perk_id] = SYNERGY_PERKS[perk_id]
	
	# Restore unlocked perk tree perks
	unlocked_perks.clear()
	var saved_unlocked = data.get("unlocked_perks", [])
	for perk_id in saved_unlocked:
		if perk_definitions.has(perk_id):
			unlocked_perks[perk_id] = true

func reset_all() -> void:
	for skill_id in skills:
		skills[skill_id] = {"xp": 0, "level": 1}
	skill_points = 0
	active_perks.clear()
	unlocked_perks.clear()
