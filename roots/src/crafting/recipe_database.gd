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
		"wooden_fence", 2, 2.0, "crafting", 3.0
	))
	
	# Torch
	_register_recipe(_make_recipe(
		"craft_torch", "Torch", "A simple torch for light.",
		CraftingRecipe.RecipeCategory.MISC, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stick", "amount": 1}, {"item_id": "coal", "amount": 1}],
		"torch", 2, 1.0, "crafting", 2.0
	))
