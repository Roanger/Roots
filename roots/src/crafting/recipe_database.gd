extends Node
## Central database of all crafting recipes.
## Registered as an autoload singleton.

const RecipeDataScript = preload("res://src/crafting/recipe_data.gd")

var recipes: Dictionary = {}  # recipe_id -> CraftingRecipe

func _ready() -> void:
	_init_recipes()
	print("RecipeDatabase initialized with %d recipes" % recipes.size())

func get_recipe(recipe_id: String) -> CraftingRecipe:
	return recipes.get(recipe_id, null)

func get_all_recipes() -> Array:
	return recipes.values()

func get_recipes_by_category(category: int) -> Array:
	var result: Array = []
	for recipe in recipes.values():
		if recipe.category == category:
			result.append(recipe)
	return result

func get_recipes_by_station(station: int) -> Array:
	var result: Array = []
	for recipe in recipes.values():
		if recipe.station == station:
			result.append(recipe)
	return result

func get_craftable_recipes(inventory, station: int = CraftingRecipe.CraftingStation.HAND) -> Array:
	var result: Array = []
	for recipe in recipes.values():
		if recipe.station == station and recipe.has_ingredients(inventory):
			result.append(recipe)
	return result

func _register_recipe(recipe: CraftingRecipe) -> void:
	recipes[recipe.recipe_id] = recipe

func _make_recipe(id: String, rname: String, desc: String, category: int, station: int, ingredients: Array[Dictionary], output_id: String, output_amount: int = 1, craft_time: float = 1.0, xp_skill: String = "", xp_amount: float = 5.0) -> CraftingRecipe:
	var r = CraftingRecipe.new()
	r.recipe_id = id
	r.recipe_name = rname
	r.description = desc
	r.category = category
	r.station = station
	r.ingredients = ingredients
	r.output_item_id = output_id
	r.output_amount = output_amount
	r.crafting_time = craft_time
	r.xp_skill = xp_skill
	r.xp_amount = xp_amount
	return r

func _init_recipes() -> void:
	# ===== MATERIALS (Hand-craftable) =====
	
	# Wood Log -> Wooden Planks (2)
	_register_recipe(_make_recipe(
		"planks_from_log", "Wooden Planks", "Split a log into planks.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "wood_log", "amount": 1}],
		"wood_plank", 2, 1.5, "lumberjack", 3.0
	))
	
	# Wooden Planks -> Sticks (4)
	_register_recipe(_make_recipe(
		"sticks_from_planks", "Sticks", "Whittle planks into sticks.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "wood_plank", "amount": 1}],
		"stick", 4, 1.0, "lumberjack", 2.0
	))
	
	# String -> Rope
	_register_recipe(_make_recipe(
		"rope_from_string", "Rope", "Braid string into rope.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "string", "amount": 3}],
		"rope", 1, 2.0, "crafting", 4.0
	))
	
	# Stone Chunks -> Stone Brick
	_register_recipe(_make_recipe(
		"stone_brick", "Stone Brick", "Shape stone chunks into a brick.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stone", "amount": 3}],
		"stone_brick", 1, 2.0, "mining", 4.0
	))
	
	# ===== MATERIALS (Workbench) =====
	
	# Wool -> Fabric (at loom, but workbench for now)
	_register_recipe(_make_recipe(
		"fabric_from_wool", "Fabric", "Weave wool into fabric.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wool", "amount": 2}],
		"fabric", 1, 3.0, "crafting", 5.0
	))
	
	# ===== MATERIALS (Forge) =====
	
	# Copper Nuggets -> Copper Ingot
	_register_recipe(_make_recipe(
		"copper_ingot", "Copper Ingot", "Smelt copper nuggets into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "copper_nugget", "amount": 3}, {"item_id": "coal", "amount": 1}],
		"copper_ingot", 1, 4.0, "blacksmithing", 8.0
	))
	
	# Iron Nuggets -> Iron Ingot
	_register_recipe(_make_recipe(
		"iron_ingot", "Iron Ingot", "Smelt iron nuggets into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "iron_nugget", "amount": 3}, {"item_id": "coal", "amount": 1}],
		"iron_ingot", 1, 5.0, "blacksmithing", 12.0
	))
	
	# Gold Nuggets -> Gold Ingot
	_register_recipe(_make_recipe(
		"gold_ingot", "Gold Ingot", "Smelt gold nuggets into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "gold_nugget", "amount": 3}, {"item_id": "coal", "amount": 2}],
		"gold_ingot", 1, 6.0, "blacksmithing", 15.0
	))
	
	# ===== SMELTING (Forge) - Advanced alloys =====
	
	# Steel Ingot (iron + extra coal)
	_register_recipe(_make_recipe(
		"steel_ingot", "Steel Ingot", "Forge iron with extra coal into steel.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "coal", "amount": 3}],
		"steel_ingot", 1, 8.0, "blacksmithing", 20.0
	))
	
	# Mythril Ingot
	_register_recipe(_make_recipe(
		"mythril_ingot", "Mythril Ingot", "Smelt rare mythril ore into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "mythril_ore", "amount": 3}, {"item_id": "coal", "amount": 3}],
		"mythril_ingot", 1, 10.0, "blacksmithing", 30.0
	))
	
	# ===== TOOLS - Wood Tier (Workbench) =====
	
	_register_recipe(_make_recipe(
		"craft_wooden_hoe", "Wooden Hoe", "A simple hoe made from sticks and planks.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stick", "amount": 2}, {"item_id": "wood_plank", "amount": 2}],
		"basic_hoe", 1, 3.0, "crafting", 5.0
	))
	_register_recipe(_make_recipe(
		"craft_wooden_axe", "Wooden Axe", "A crude axe for chopping.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stick", "amount": 2}, {"item_id": "wood_plank", "amount": 3}],
		"basic_axe", 1, 3.0, "crafting", 5.0
	))
	_register_recipe(_make_recipe(
		"craft_wooden_pickaxe", "Wooden Pickaxe", "A basic pickaxe for mining.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stick", "amount": 2}, {"item_id": "wood_plank", "amount": 3}],
		"basic_pickaxe", 1, 3.0, "crafting", 5.0
	))
	_register_recipe(_make_recipe(
		"craft_wooden_sickle", "Wooden Sickle", "A crude sickle for harvesting.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stick", "amount": 2}, {"item_id": "wood_plank", "amount": 1}],
		"basic_sickle", 1, 3.0, "crafting", 5.0
	))
	
	# ===== TOOLS - Bronze Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_bronze_hoe", "Bronze Hoe", "A copper-alloy hoe, better than wood.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"bronze_hoe", 1, 4.0, "blacksmithing", 8.0
	))
	_register_recipe(_make_recipe(
		"craft_bronze_axe", "Bronze Axe", "A copper-alloy axe for chopping.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"bronze_axe", 1, 4.0, "blacksmithing", 8.0
	))
	_register_recipe(_make_recipe(
		"craft_bronze_pickaxe", "Bronze Pickaxe", "A copper-alloy pickaxe for mining.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"bronze_pickaxe", 1, 4.0, "blacksmithing", 8.0
	))
	_register_recipe(_make_recipe(
		"craft_bronze_sickle", "Bronze Sickle", "A copper-alloy sickle for harvesting.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"bronze_sickle", 1, 4.0, "blacksmithing", 8.0
	))
	
	# ===== TOOLS - Iron Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_iron_hoe", "Iron Hoe", "A sturdy iron hoe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"iron_hoe", 1, 5.0, "blacksmithing", 12.0
	))
	_register_recipe(_make_recipe(
		"craft_iron_axe", "Iron Axe", "A sharp iron axe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"iron_axe", 1, 5.0, "blacksmithing", 12.0
	))
	_register_recipe(_make_recipe(
		"craft_iron_pickaxe", "Iron Pickaxe", "A strong iron pickaxe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"iron_pickaxe", 1, 5.0, "blacksmithing", 12.0
	))
	_register_recipe(_make_recipe(
		"craft_iron_sickle", "Iron Sickle", "A sharp iron sickle.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"iron_sickle", 1, 5.0, "blacksmithing", 12.0
	))
	
	# ===== TOOLS - Steel Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_steel_hoe", "Steel Hoe", "A refined steel hoe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"steel_hoe", 1, 6.0, "blacksmithing", 18.0
	))
	_register_recipe(_make_recipe(
		"craft_steel_axe", "Steel Axe", "A powerful steel axe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"steel_axe", 1, 6.0, "blacksmithing", 18.0
	))
	_register_recipe(_make_recipe(
		"craft_steel_pickaxe", "Steel Pickaxe", "A powerful steel pickaxe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"steel_pickaxe", 1, 6.0, "blacksmithing", 18.0
	))
	_register_recipe(_make_recipe(
		"craft_steel_sickle", "Steel Sickle", "A keen steel sickle.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"steel_sickle", 1, 6.0, "blacksmithing", 18.0
	))
	
	# ===== TOOLS - Mythril Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_mythril_hoe", "Mythril Hoe", "A legendary hoe of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_hoe", 1, 8.0, "blacksmithing", 30.0
	))
	_register_recipe(_make_recipe(
		"craft_mythril_axe", "Mythril Axe", "A legendary axe of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_axe", 1, 8.0, "blacksmithing", 30.0
	))
	_register_recipe(_make_recipe(
		"craft_mythril_pickaxe", "Mythril Pickaxe", "A legendary pickaxe of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_pickaxe", 1, 8.0, "blacksmithing", 30.0
	))
	_register_recipe(_make_recipe(
		"craft_mythril_sickle", "Mythril Sickle", "A legendary sickle of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_sickle", 1, 8.0, "blacksmithing", 30.0
	))
	
	# ===== WEAPONS (Anvil) =====
	
	# Iron Sword
	_register_recipe(_make_recipe(
		"craft_iron_sword", "Iron Sword", "Forge a sturdy iron sword.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"basic_sword", 1, 6.0, "blacksmithing", 15.0
	))
	
	# Dagger
	_register_recipe(_make_recipe(
		"craft_dagger", "Dagger", "A quick and light dagger.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 1}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"basic_dagger", 1, 4.0, "blacksmithing", 10.0
	))
	
	# ===== BUILDING (Hand) =====
	
	# Wooden Fence
	_register_recipe(_make_recipe(
		"craft_fence", "Wooden Fence", "A simple wooden fence section.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stick", "amount": 4}, {"item_id": "rope", "amount": 1}],
		"fence_wood", 2, 2.0, "crafting", 3.0
	))
	
	# Torch
	_register_recipe(_make_recipe(
		"craft_torch", "Torch", "A simple torch for light.",
		CraftingRecipe.RecipeCategory.MISC, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stick", "amount": 1}, {"item_id": "coal", "amount": 1}],
		"torch", 2, 1.0, "crafting", 2.0
	))
	
	# Empty Bottle (hand-craftable from stone)
	_register_recipe(_make_recipe(
		"craft_empty_bottle", "Empty Bottle", "A glass bottle for brewing potions.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stone", "amount": 2}],
		"empty_bottle", 2, 2.0, "crafting", 3.0
	))
	
	# ===== POTIONS (Alchemy Table) =====
	
	# Health Potion - chamomile + mushroom
	_register_recipe(_make_recipe(
		"brew_health_potion", "Health Potion", "Brew a potion that restores health.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "chamomile", "amount": 2}, {"item_id": "common_mushroom", "amount": 1}],
		"health_potion", 1, 5.0, "alchemy", 15.0
	))
	
	# Greater Health Potion - chamomile + golden mushroom + nightshade
	_register_recipe(_make_recipe(
		"brew_greater_health_potion", "Greater Health Potion", "Brew a potent healing potion.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "chamomile", "amount": 3}, {"item_id": "golden_mushroom", "amount": 1}, {"item_id": "nightshade", "amount": 1}],
		"greater_health_potion", 1, 8.0, "alchemy", 25.0
	))
	
	# Stamina Potion - mint + clover
	_register_recipe(_make_recipe(
		"brew_stamina_potion", "Stamina Potion", "Brew a potion that restores stamina.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "mint_leaf", "amount": 2}, {"item_id": "wild_clover", "amount": 2}],
		"stamina_potion", 1, 5.0, "alchemy", 15.0
	))
	
	# Speed Potion - mint + fern + sage
	_register_recipe(_make_recipe(
		"brew_speed_potion", "Speed Potion", "Brew a potion that increases movement speed.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "mint_leaf", "amount": 2}, {"item_id": "fern_frond", "amount": 1}, {"item_id": "sage_leaf", "amount": 1}],
		"speed_potion", 1, 6.0, "alchemy", 20.0
	))
	
	# Strength Potion - nightshade + golden mushroom + sage
	_register_recipe(_make_recipe(
		"brew_strength_potion", "Strength Potion", "Brew a potion that increases attack damage.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "nightshade", "amount": 2}, {"item_id": "golden_mushroom", "amount": 1}, {"item_id": "sage_leaf", "amount": 1}],
		"strength_potion", 1, 8.0, "alchemy", 25.0
	))
	
	# Antidote - wild clover + chamomile + fern
	_register_recipe(_make_recipe(
		"brew_antidote", "Antidote", "Brew a potion that cures poison.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "wild_clover", "amount": 2}, {"item_id": "chamomile", "amount": 1}, {"item_id": "fern_frond", "amount": 1}],
		"antidote", 1, 5.0, "alchemy", 15.0
	))
	
	# ===== COOKING (Cooking Fire) =====
	
	# Ingredient prep
	_register_recipe(_make_recipe(
		"grind_flour", "Flour", "Grind wheat into flour.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "wheat", "amount": 2}],
		"flour", 2, 2.0, "cooking", 5.0
	))
	
	_register_recipe(_make_recipe(
		"churn_butter", "Butter", "Churn milk into butter.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "milk", "amount": 2}],
		"butter", 1, 3.0, "cooking", 5.0
	))
	
	_register_recipe(_make_recipe(
		"make_cheese", "Cheese", "Age milk into cheese.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "milk", "amount": 3}],
		"cheese", 1, 5.0, "cooking", 8.0
	))
	
	# Basic cooked meats
	_register_recipe(_make_recipe(
		"cook_meat", "Cooked Meat", "Cook raw meat over the fire.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "raw_meat", "amount": 1}],
		"cooked_meat", 1, 3.0, "cooking", 8.0
	))
	
	_register_recipe(_make_recipe(
		"cook_venison", "Cooked Venison", "Roast venison over the fire.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "venison", "amount": 1}],
		"cooked_venison", 1, 4.0, "cooking", 12.0
	))
	
	_register_recipe(_make_recipe(
		"cook_rabbit", "Cooked Rabbit", "Cook tender rabbit meat.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "rabbit_meat", "amount": 1}],
		"cooked_rabbit", 1, 3.0, "cooking", 10.0
	))
	
	_register_recipe(_make_recipe(
		"fry_egg", "Fried Egg", "Fry an egg on a hot stone.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "egg", "amount": 1}],
		"fried_egg", 1, 2.0, "cooking", 5.0
	))
	
	# Baked goods
	_register_recipe(_make_recipe(
		"bake_bread", "Bread", "Bake bread from flour.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "flour", "amount": 2}],
		"bread", 1, 4.0, "baking", 10.0
	))
	
	_register_recipe(_make_recipe(
		"bake_meat_pie", "Meat Pie", "Bake a hearty meat pie.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "flour", "amount": 2}, {"item_id": "cooked_meat", "amount": 1}, {"item_id": "butter", "amount": 1}],
		"meat_pie", 1, 6.0, "baking", 18.0
	))
	
	_register_recipe(_make_recipe(
		"bake_apple_pie", "Apple Pie", "Bake a sweet apple pie.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "flour", "amount": 2}, {"item_id": "apple", "amount": 2}, {"item_id": "butter", "amount": 1}],
		"apple_pie", 1, 6.0, "baking", 15.0
	))
	
	# Soups & Stews
	_register_recipe(_make_recipe(
		"cook_vegetable_soup", "Vegetable Soup", "Simmer a pot of garden vegetables.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "carrot", "amount": 1}, {"item_id": "potato", "amount": 1}, {"item_id": "tomato", "amount": 1}],
		"vegetable_soup", 1, 5.0, "cooking", 12.0
	))
	
	_register_recipe(_make_recipe(
		"cook_mushroom_soup", "Mushroom Soup", "Brew a rich mushroom soup.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "common_mushroom", "amount": 3}, {"item_id": "milk", "amount": 1}],
		"mushroom_soup", 1, 5.0, "cooking", 12.0
	))
	
	_register_recipe(_make_recipe(
		"cook_hearty_stew", "Hearty Stew", "Slow-cook a thick stew of meat and vegetables.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "cooked_meat", "amount": 1}, {"item_id": "potato", "amount": 2}, {"item_id": "carrot", "amount": 1}, {"item_id": "tomato", "amount": 1}],
		"hearty_stew", 1, 8.0, "cooking", 20.0
	))
	
	# Drinks
	_register_recipe(_make_recipe(
		"brew_mushroom_tea", "Mushroom Tea", "Brew a warm tea from golden mushrooms.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "golden_mushroom", "amount": 1}, {"item_id": "chamomile", "amount": 1}, {"item_id": "empty_bottle", "amount": 1}],
		"mushroom_tea", 1, 5.0, "cooking", 15.0
	))
	
	# ===== BUILDING (Workbench) =====
	
	# Wooden Fence - 2 planks + 1 string
	_register_recipe(_make_recipe(
		"craft_fence_wood", "Wooden Fence", "Craft a wooden fence section.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 2}, {"item_id": "string", "amount": 1}],
		"fence_wood", 2, 2.0, "construction", 5.0
	))
	
	# Fence Post - 1 log
	_register_recipe(_make_recipe(
		"craft_fence_post", "Fence Post", "Craft a fence post for corners and ends.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 1}],
		"fence_post", 2, 1.5, "construction", 3.0
	))
	
	# Fence Gate - 3 planks + 2 string + 1 iron ingot (hinge)
	_register_recipe(_make_recipe(
		"craft_fence_gate", "Fence Gate", "Craft a gate that can be opened and closed.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 3}, {"item_id": "string", "amount": 2}, {"item_id": "iron_ingot", "amount": 1}],
		"fence_gate", 1, 3.0, "construction", 10.0
	))
	
	# Barn - large building, expensive
	_register_recipe(_make_recipe(
		"craft_barn", "Barn", "Build a barn to shelter your animals.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 10}, {"item_id": "wood_plank", "amount": 8}, {"item_id": "iron_ingot", "amount": 2}, {"item_id": "rope", "amount": 2}],
		"barn", 1, 10.0, "construction", 25.0
	))
	
	# Hut - smaller building
	_register_recipe(_make_recipe(
		"craft_hut", "Hut", "Build a small hut for storage or shelter.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 6}, {"item_id": "wood_plank", "amount": 4}, {"item_id": "rope", "amount": 1}],
		"hut", 1, 8.0, "construction", 18.0
	))
	
	# Feeding Trough
	_register_recipe(_make_recipe(
		"craft_feeding_trough", "Feeding Trough", "Craft a trough for feeding farm animals.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 4}, {"item_id": "iron_ingot", "amount": 1}],
		"feeding_trough", 1, 4.0, "construction", 10.0
	))
	
	# Campfire
	_register_recipe(_make_recipe(
		"craft_campfire", "Campfire", "Build a campfire for warmth and cooking.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stone", "amount": 5}, {"item_id": "stick", "amount": 3}, {"item_id": "coal", "amount": 1}],
		"campfire", 1, 3.0, "crafting", 8.0
	))
	
	# Sitting Log
	_register_recipe(_make_recipe(
		"craft_sitting_log", "Sitting Log", "Carve a log into a seat.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "wood_log", "amount": 2}],
		"sitting_log", 1, 2.0, "lumberjack", 4.0
	))
