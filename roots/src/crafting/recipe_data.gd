extends Resource
class_name CraftingRecipe
## Defines a single crafting recipe: inputs, output, requirements.

enum CraftingStation {
	HAND,           # Can craft anywhere (no station needed)
	WORKBENCH,      # Basic workbench
	FORGE,          # Smelting and metalwork
	ANVIL,          # Smithing tools/weapons/armor
	COOKING_FIRE,   # Basic cooking
	ALCHEMY_TABLE,  # Potions and extracts
	LOOM,           # Fabric and cloth
	SAWMILL         # Wood processing
}

enum RecipeCategory {
	MATERIALS,      # Planks, ingots, rope, etc.
	TOOLS,          # Hoes, axes, pickaxes, etc.
	WEAPONS,        # Swords, daggers, etc.
	ARMOR,          # Helmets, chestplates, etc.
	FOOD,           # Cooked meals
	POTIONS,        # Alchemy potions
	BUILDING,       # Fences, walls, furniture
	MISC            # Everything else
}

@export var recipe_id: String = ""
@export var recipe_name: String = ""
@export var description: String = ""
@export var category: RecipeCategory = RecipeCategory.MATERIALS
@export var station: CraftingStation = CraftingStation.HAND

# Ingredients: Array of { "item_id": String, "amount": int }
@export var ingredients: Array[Dictionary] = []

# Output
@export var output_item_id: String = ""
@export var output_amount: int = 1

# Requirements
@export var required_skill: String = ""       # Skill category needed (e.g. "blacksmithing")
@export var required_skill_level: int = 0     # Minimum skill level
@export var crafting_time: float = 1.0        # Seconds to craft

# XP reward
@export var xp_skill: String = ""             # Which skill gets XP
@export var xp_amount: float = 5.0            # How much XP

# Unlocking
@export var unlocked_by_default: bool = true
@export var unlock_recipe_id: String = ""     # Recipe that must be crafted first to unlock this

func has_ingredients(inventory) -> bool:
	for ingredient in ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var amount: int = ingredient.get("amount", 1)
		if not inventory.has_item(item_id, amount):
			return false
	return true

func consume_ingredients(inventory) -> bool:
	if not has_ingredients(inventory):
		return false
	for ingredient in ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var amount: int = ingredient.get("amount", 1)
		inventory.remove_item(item_id, amount)
	return true
