extends Resource
class_name SkillData
## Defines a single skill with its properties and progression

# Skill categories matching the game plan
enum SkillCategory {
	CULTIVATION,
	GATHERING,
	CRAFTING,
	BLACKSMITHING,
	COOKING,
	BAKING,
	HUSBANDRY,
	ALCHEMY,
	MILITIA,
	HERB_GATHERING
}

# Sub-skill specializations
enum SkillSpecialization {
	NONE,
	# Cultivation
	CROP_FARMING,
	ORCHARDING,
	# Gathering
	FORAGING,
	MINING,
	LUMBERJACK,
	# Blacksmithing
	FORGE_WORK,
	WEAPONSMITH,
	# Cooking
	OPEN_FIRE,
	WOOD_STOVE,
	# Baking
	BREAD_MAKING,
	PASTRY,
	# Husbandry
	ANIMAL_CARE,
	APIARY,
	# Alchemy
	POTIONS,
	EXTRACTS,
	# Militia
	COMBAT,
	DEFENSE
}

@export var skill_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: SkillCategory = SkillCategory.CULTIVATION
@export var specialization: SkillSpecialization = SkillSpecialization.NONE
@export var icon: Texture2D = null
@export var max_level: int = 100
@export var base_xp_per_level: int = 100
@export var xp_scaling: float = 1.15  # Each level requires 15% more XP

func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(base_xp_per_level * pow(xp_scaling, level - 1))

func get_total_xp_for_level(level: int) -> int:
	var total := 0
	for i in range(1, level + 1):
		total += get_xp_for_level(i)
	return total
