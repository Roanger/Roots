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

func _make_recipe(id: String, rname: String, desc: String, category: int, station: int, ingredients: Array[Dictionary], output_id: String, output_amount: int = 1, craft_time: float = 1.0, xp_skill: String = "", xp_amount: float = 5.0, req_skill: String = "", req_level: int = 0) -> CraftingRecipe:
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
	r.required_skill = req_skill
	r.required_skill_level = req_level
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
	
	# ===== MATERIALS (Loom) =====
	
	# Wool -> Fabric
	_register_recipe(_make_recipe(
		"fabric_from_wool", "Fabric", "Weave wool into fabric.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.LOOM,
		[{"item_id": "wool", "amount": 2}],
		"fabric", 1, 3.0, "crafting", 5.0, "crafting", 3
	))
	
	# Rabbit Fur -> Fabric (lower quality)
	_register_recipe(_make_recipe(
		"fabric_from_fur", "Fabric from Fur", "Weave soft fur into fabric.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.LOOM,
		[{"item_id": "rabbit_fur", "amount": 3}],
		"fabric", 1, 4.0, "husbandry", 6.0, "crafting", 5
	))
	
	# Fiber -> String
	_register_recipe(_make_recipe(
		"string_from_fiber", "String from Fiber", "Twist plant fiber into string.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.LOOM,
		[{"item_id": "fiber", "amount": 3}],
		"string", 2, 2.0, "crafting", 4.0, "crafting", 1
	))
	
	# ===== MATERIALS (Sawmill) =====
	
	# Log -> Planks (more efficient than hand-crafting)
	_register_recipe(_make_recipe(
		"mill_planks", "Sawn Planks", "Mill a log into planks efficiently.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.SAWMILL,
		[{"item_id": "wood_log", "amount": 1}],
		"wood_plank", 3, 2.0, "lumberjack", 5.0, "crafting", 3
	))
	
	# Log -> Sticks directly
	_register_recipe(_make_recipe(
		"mill_sticks", "Cut Sticks", "Cut a log into sticks.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.SAWMILL,
		[{"item_id": "wood_log", "amount": 1}],
		"stick", 6, 2.0, "lumberjack", 4.0, "crafting", 1
	))
	
	# ===== MATERIALS (Forge) =====
	
	# Copper Nuggets -> Copper Ingot
	_register_recipe(_make_recipe(
		"copper_ingot", "Copper Ingot", "Smelt copper nuggets into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "copper_nugget", "amount": 3}, {"item_id": "coal", "amount": 1}],
		"copper_ingot", 1, 4.0, "blacksmithing", 8.0, "blacksmithing", 3
	))
	
	# Iron Nuggets -> Iron Ingot
	_register_recipe(_make_recipe(
		"iron_ingot", "Iron Ingot", "Smelt iron nuggets into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "iron_nugget", "amount": 3}, {"item_id": "coal", "amount": 1}],
		"iron_ingot", 1, 5.0, "blacksmithing", 12.0, "blacksmithing", 8
	))
	
	# Gold Nuggets -> Gold Ingot
	_register_recipe(_make_recipe(
		"gold_ingot", "Gold Ingot", "Smelt gold nuggets into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "gold_nugget", "amount": 3}, {"item_id": "coal", "amount": 2}],
		"gold_ingot", 1, 6.0, "blacksmithing", 15.0, "blacksmithing", 12
	))
	
	# ===== SMELTING (Forge) - Advanced alloys =====
	
	# Steel Ingot (iron + extra coal)
	_register_recipe(_make_recipe(
		"steel_ingot", "Steel Ingot", "Forge iron with extra coal into steel.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "coal", "amount": 3}],
		"steel_ingot", 1, 8.0, "blacksmithing", 20.0, "blacksmithing", 15
	))
	
	# Mythril Ingot
	_register_recipe(_make_recipe(
		"mythril_ingot", "Mythril Ingot", "Smelt rare mythril ore into an ingot.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "mythril_ore", "amount": 3}, {"item_id": "coal", "amount": 3}],
		"mythril_ingot", 1, 10.0, "blacksmithing", 30.0, "blacksmithing", 25
	))
	
	# ===== CRAFTING STATIONS (placeable benches) =====

	# Workbench — hand-craftable, key bootstrap item
	_register_recipe(_make_recipe(
		"craft_workbench", "Workbench", "A sturdy workbench for crafting tools and items.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "wood_log", "amount": 5}, {"item_id": "stick", "amount": 8}, {"item_id": "small_stone", "amount": 4}],
		"workbench", 1, 5.0, "crafting", 10.0
	))

	# Cooking Fire — hand-craftable
	_register_recipe(_make_recipe(
		"craft_cooking_fire", "Cooking Fire", "An open fire for cooking meals.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "stick", "amount": 5}, {"item_id": "small_stone", "amount": 8}],
		"cooking_fire", 1, 4.0, "crafting", 8.0
	))

	# Forge — needs Workbench
	_register_recipe(_make_recipe(
		"craft_forge", "Forge", "A coal-fired forge for smelting ores.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stone", "amount": 12}, {"item_id": "stick", "amount": 6}, {"item_id": "dirt", "amount": 8}],
		"forge", 1, 6.0, "blacksmithing", 12.0
	))

	# Sawmill — needs Workbench
	_register_recipe(_make_recipe(
		"craft_sawmill", "Sawmill", "A sawmill for processing logs into planks.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 6}, {"item_id": "stone", "amount": 4}],
		"sawmill", 1, 5.0, "crafting", 10.0
	))

	# Loom — needs Workbench
	_register_recipe(_make_recipe(
		"craft_loom", "Loom", "A wooden loom for weaving cloth.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 6}, {"item_id": "string", "amount": 6}],
		"loom", 1, 5.0, "crafting", 10.0
	))

	# Anvil — needs Forge
	_register_recipe(_make_recipe(
		"craft_anvil", "Anvil", "A heavy anvil for shaping metal.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "iron_ingot", "amount": 5}, {"item_id": "stone", "amount": 10}],
		"anvil", 1, 8.0, "blacksmithing", 20.0, "blacksmithing", 5
	))

	# Blacksmith's Tongs — profession equipment (Tool slot), passive smelting/forging bonus
	_register_recipe(_make_recipe(
		"craft_blacksmiths_tongs", "Blacksmith's Tongs", "A well-worn pair of forge tongs, equippable in a Tool slot for a passive forge/anvil bonus.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.FORGE,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "stick", "amount": 1}],
		"blacksmiths_tongs", 1, 6.0, "blacksmithing", 15.0, "blacksmithing", 10
	))

	# Alchemy Table — needs Workbench
	_register_recipe(_make_recipe(
		"craft_alchemy_table", "Alchemy Table", "A sturdy table for brewing potions.",
		CraftingRecipe.RecipeCategory.MATERIALS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 6}, {"item_id": "stone_brick", "amount": 4}],
		"alchemy_table", 1, 5.0, "crafting", 10.0
	))

	# ===== TOOLS - Stone Tier (Hand-craftable from ground pickups) =====
	
	_register_recipe(_make_recipe(
		"craft_stone_hoe", "Stone Hoe", "A crude stone hoe for tilling soil.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "small_stone", "amount": 2}, {"item_id": "stick", "amount": 1}],
		"stone_hoe", 1, 3.0, "crafting", 4.0
	))
	_register_recipe(_make_recipe(
		"craft_stone_axe", "Stone Axe", "A sharpened stone axe for chopping trees.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "small_stone", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"stone_axe", 1, 3.0, "crafting", 4.0
	))
	_register_recipe(_make_recipe(
		"craft_stone_pickaxe", "Stone Pickaxe", "A crude stone pickaxe for mining rocks.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "small_stone", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"stone_pickaxe", 1, 3.0, "crafting", 4.0
	))
	_register_recipe(_make_recipe(
		"craft_stone_shovel", "Stone Shovel", "A stone-tipped shovel for digging.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "small_stone", "amount": 2}, {"item_id": "stick", "amount": 1}],
		"stone_shovel", 1, 3.0, "crafting", 4.0
	))
	_register_recipe(_make_recipe(
		"craft_stone_sickle", "Stone Sickle", "A stone sickle for harvesting crops and herbs.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "small_stone", "amount": 2}, {"item_id": "stick", "amount": 1}],
		"stone_sickle", 1, 3.0, "crafting", 4.0
	))
	_register_recipe(_make_recipe(
		"craft_stone_hammer", "Stone Hammer", "A stone hammer for basic building.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "small_stone", "amount": 2}, {"item_id": "stick", "amount": 1}],
		"stone_hammer", 1, 3.0, "crafting", 4.0
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
		"bronze_hoe", 1, 4.0, "blacksmithing", 8.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_axe", "Bronze Axe", "A copper-alloy axe for chopping.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"bronze_axe", 1, 4.0, "blacksmithing", 8.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_pickaxe", "Bronze Pickaxe", "A copper-alloy pickaxe for mining.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"bronze_pickaxe", 1, 4.0, "blacksmithing", 8.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_sickle", "Bronze Sickle", "A copper-alloy sickle for harvesting.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"bronze_sickle", 1, 4.0, "blacksmithing", 8.0, "blacksmithing", 5
	))
	
	# ===== TOOLS - Iron Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_iron_hoe", "Iron Hoe", "A sturdy iron hoe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"iron_hoe", 1, 5.0, "blacksmithing", 12.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_axe", "Iron Axe", "A sharp iron axe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"iron_axe", 1, 5.0, "blacksmithing", 12.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_pickaxe", "Iron Pickaxe", "A strong iron pickaxe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"iron_pickaxe", 1, 5.0, "blacksmithing", 12.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_sickle", "Iron Sickle", "A sharp iron sickle.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"iron_sickle", 1, 5.0, "blacksmithing", 12.0, "blacksmithing", 10
	))
	
	# ===== TOOLS - Steel Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_steel_hoe", "Steel Hoe", "A refined steel hoe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"steel_hoe", 1, 6.0, "blacksmithing", 18.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_axe", "Steel Axe", "A powerful steel axe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"steel_axe", 1, 6.0, "blacksmithing", 18.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_pickaxe", "Steel Pickaxe", "A powerful steel pickaxe.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}],
		"steel_pickaxe", 1, 6.0, "blacksmithing", 18.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_sickle", "Steel Sickle", "A keen steel sickle.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}],
		"steel_sickle", 1, 6.0, "blacksmithing", 18.0, "blacksmithing", 20
	))
	
	# ===== TOOLS - Mythril Tier (Anvil) =====
	
	_register_recipe(_make_recipe(
		"craft_mythril_hoe", "Mythril Hoe", "A legendary hoe of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_hoe", 1, 8.0, "blacksmithing", 30.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_axe", "Mythril Axe", "A legendary axe of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_axe", 1, 8.0, "blacksmithing", 30.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_pickaxe", "Mythril Pickaxe", "A legendary pickaxe of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_pickaxe", 1, 8.0, "blacksmithing", 30.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_sickle", "Mythril Sickle", "A legendary sickle of mythril.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 2}, {"item_id": "stick", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_sickle", 1, 8.0, "blacksmithing", 30.0, "blacksmithing", 35
	))
	
	# ===== WEAPONS (Anvil) =====
	
	# BRONZE weapons
	_register_recipe(_make_recipe(
		"craft_bronze_sword", "Bronze Sword", "Forge a bronze sword.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 3}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"bronze_sword", 1, 4.0, "blacksmithing", 10.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_battle_axe", "Bronze Battle Axe", "Forge a bronze battle axe.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 4}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"bronze_battle_axe", 1, 4.0, "blacksmithing", 10.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_dagger", "Bronze Dagger", "Forge a bronze dagger.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 1}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"bronze_dagger", 1, 3.0, "blacksmithing", 8.0, "blacksmithing", 5
	))
	
	# IRON weapons (existing)
	_register_recipe(_make_recipe(
		"craft_iron_sword", "Iron Sword", "Forge a sturdy iron sword.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"basic_sword", 1, 6.0, "blacksmithing", 15.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_battle_axe", "Iron Battle Axe", "Forge a heavy iron battle axe.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 4}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"basic_axe_weapon", 1, 6.0, "blacksmithing", 15.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_dagger", "Iron Dagger", "Forge a sharp iron dagger.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 1}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"basic_dagger", 1, 4.0, "blacksmithing", 10.0, "blacksmithing", 10
	))
	
	# STEEL weapons
	_register_recipe(_make_recipe(
		"craft_steel_sword", "Steel Sword", "Forge a masterful steel sword.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 3}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"steel_sword", 1, 7.0, "blacksmithing", 22.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_battle_axe", "Steel Battle Axe", "Forge a powerful steel battle axe.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 4}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"steel_battle_axe", 1, 7.0, "blacksmithing", 22.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_dagger", "Steel Dagger", "Forge a razor-sharp steel dagger.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "stick", "amount": 1}, {"item_id": "leather", "amount": 1}],
		"steel_dagger", 1, 5.0, "blacksmithing", 18.0, "blacksmithing", 20
	))
	
	# MYTHRIL weapons
	_register_recipe(_make_recipe(
		"craft_mythril_sword", "Mythril Sword", "Forge a legendary mythril sword.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "stick", "amount": 1}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_sword", 1, 9.0, "blacksmithing", 30.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_battle_axe", "Mythril Battle Axe", "Forge a mighty mythril battle axe.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 4}, {"item_id": "stick", "amount": 1}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_battle_axe", 1, 9.0, "blacksmithing", 32.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_dagger", "Mythril Dagger", "Forge a lightning-quick mythril dagger.",
		CraftingRecipe.RecipeCategory.WEAPONS, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 2}, {"item_id": "stick", "amount": 1}, {"item_id": "gold_ingot", "amount": 1}],
		"mythril_dagger", 1, 7.0, "blacksmithing", 25.0, "blacksmithing", 35
	))
	
	# ===== ARMOR (Anvil) =====
	
	# Bronze Armor
	_register_recipe(_make_recipe(
		"craft_bronze_helmet", "Bronze Helmet", "Forge a bronze helmet for protection.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 2}, {"item_id": "leather", "amount": 1}],
		"bronze_helmet", 1, 4.0, "blacksmithing", 10.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_chestplate", "Bronze Chestplate", "Forge a bronze chestplate.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 4}, {"item_id": "leather", "amount": 2}],
		"bronze_chestplate", 1, 5.0, "blacksmithing", 12.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_greaves", "Bronze Greaves", "Forge bronze leg guards.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 3}, {"item_id": "leather", "amount": 1}],
		"bronze_greaves", 1, 4.0, "blacksmithing", 10.0, "blacksmithing", 5
	))
	_register_recipe(_make_recipe(
		"craft_bronze_boots", "Bronze Boots", "Forge sturdy bronze boots.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "copper_ingot", "amount": 2}, {"item_id": "leather", "amount": 1}],
		"bronze_boots", 1, 3.0, "blacksmithing", 8.0, "blacksmithing", 5
	))
	
	# Iron Armor
	_register_recipe(_make_recipe(
		"craft_iron_helmet", "Iron Helmet", "Forge an iron helmet.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "leather", "amount": 1}],
		"iron_helmet", 1, 5.0, "blacksmithing", 15.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_chestplate", "Iron Chestplate", "Forge an iron chestplate.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 4}, {"item_id": "leather", "amount": 2}],
		"iron_chestplate", 1, 7.0, "blacksmithing", 20.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_greaves", "Iron Greaves", "Forge iron leg guards.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 3}, {"item_id": "leather", "amount": 1}],
		"iron_greaves", 1, 5.0, "blacksmithing", 15.0, "blacksmithing", 10
	))
	_register_recipe(_make_recipe(
		"craft_iron_boots", "Iron Boots", "Forge iron boots.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "iron_ingot", "amount": 2}, {"item_id": "leather", "amount": 1}],
		"iron_boots", 1, 4.0, "blacksmithing", 12.0, "blacksmithing", 10
	))
	
	# Steel Armor
	_register_recipe(_make_recipe(
		"craft_steel_helmet", "Steel Helmet", "Forge a high-quality steel helmet.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "leather", "amount": 1}],
		"steel_helmet", 1, 6.0, "blacksmithing", 22.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_chestplate", "Steel Chestplate", "Forge a masterful steel chestplate.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 4}, {"item_id": "fabric", "amount": 2}],
		"steel_chestplate", 1, 8.0, "blacksmithing", 28.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_greaves", "Steel Greaves", "Forge steel leg guards.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 3}, {"item_id": "fabric", "amount": 1}],
		"steel_greaves", 1, 6.0, "blacksmithing", 22.0, "blacksmithing", 20
	))
	_register_recipe(_make_recipe(
		"craft_steel_boots", "Steel Boots", "Forge heavy steel boots.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "steel_ingot", "amount": 2}, {"item_id": "fabric", "amount": 1}],
		"steel_boots", 1, 5.0, "blacksmithing", 18.0, "blacksmithing", 20
	))
	
	# Mythril Armor
	_register_recipe(_make_recipe(
		"craft_mythril_helmet", "Mythril Helmet", "Forge a legendary mythril helmet.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "leather", "amount": 2}],
		"mythril_helmet", 1, 8.0, "blacksmithing", 35.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_chestplate", "Mythril Chestplate", "Forge a mythril chestplate of incredible strength.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 6}, {"item_id": "fabric", "amount": 3}],
		"mythril_chestplate", 1, 10.0, "blacksmithing", 45.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_greaves", "Mythril Greaves", "Forge mythril leg guards.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 4}, {"item_id": "fabric", "amount": 2}],
		"mythril_greaves", 1, 8.0, "blacksmithing", 35.0, "blacksmithing", 35
	))
	_register_recipe(_make_recipe(
		"craft_mythril_boots", "Mythril Boots", "Forge light yet powerful mythril boots.",
		CraftingRecipe.RecipeCategory.ARMOR, CraftingRecipe.CraftingStation.ANVIL,
		[{"item_id": "mythril_ingot", "amount": 3}, {"item_id": "leather", "amount": 2}],
		"mythril_boots", 1, 7.0, "blacksmithing", 30.0, "blacksmithing", 35
	))
	
	# ===== SETTLEMENT =====
	_register_recipe(_make_recipe(
		"craft_claim_post", "Claim Post", "Mark your territory with a claim post.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 3}, {"item_id": "stone", "amount": 5}, {"item_id": "rope", "amount": 2}],
		"claim_post", 1, 4.0, "crafting", 10.0, "crafting", 5
	))

	# ===== DECORATIONS (Hand) =====
	_register_recipe(_make_recipe(
		"craft_flower_pot", "Flower Pot", "A charming pot with wildflowers.",
		CraftingRecipe.RecipeCategory.MISC, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "dirt", "amount": 2}, {"item_id": "fiber", "amount": 2}],
		"flower_pot", 1, 2.0, "crafting", 3.0
	))
	_register_recipe(_make_recipe(
		"craft_chair", "Wooden Chair", "A simple wooden chair for your home.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "wood_log", "amount": 2}],
		"chair_wood", 1, 2.0, "crafting", 4.0
	))
	_register_recipe(_make_recipe(
		"craft_table", "Small Table", "A small wooden table for your home.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.HAND,
		[{"item_id": "wood_plank", "amount": 3}],
		"table_small", 1, 2.5, "crafting", 5.0
	))

	# ===== FISHING =====
	_register_recipe(_make_recipe(
		"craft_fishing_rod", "Fishing Rod", "A simple fishing rod for catching fish.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stick", "amount": 3}, {"item_id": "string", "amount": 2}],
		"basic_fishing_rod", 1, 3.0, "crafting", 5.0
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
	
	# Alchemist's Mortar & Pestle — profession equipment (Tool slot), passive brewing bonus
	_register_recipe(_make_recipe(
		"craft_alchemists_mortar", "Alchemist's Mortar & Pestle", "A polished stone mortar and pestle, equippable in a Tool slot for a passive alchemy table bonus.",
		CraftingRecipe.RecipeCategory.TOOLS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "stone", "amount": 2}, {"item_id": "wood_plank", "amount": 1}],
		"alchemists_mortar", 1, 6.0, "alchemy", 15.0, "alchemy", 10
	))

	# ===== POTIONS (Alchemy Table) =====

	# Health Potion - chamomile + mushroom
	_register_recipe(_make_recipe(
		"brew_health_potion", "Health Potion", "Brew a potion that restores health.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "chamomile", "amount": 2}, {"item_id": "common_mushroom", "amount": 1}],
		"health_potion", 1, 5.0, "alchemy", 15.0, "alchemy", 5
	))
	
	# Greater Health Potion - chamomile + golden mushroom + nightshade
	_register_recipe(_make_recipe(
		"brew_greater_health_potion", "Greater Health Potion", "Brew a potent healing potion.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "chamomile", "amount": 3}, {"item_id": "golden_mushroom", "amount": 1}, {"item_id": "nightshade", "amount": 1}],
		"greater_health_potion", 1, 8.0, "alchemy", 25.0, "alchemy", 15
	))
	
	# Stamina Potion - mint + clover
	_register_recipe(_make_recipe(
		"brew_stamina_potion", "Stamina Potion", "Brew a potion that restores stamina.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "mint_leaf", "amount": 2}, {"item_id": "wild_clover", "amount": 2}],
		"stamina_potion", 1, 5.0, "alchemy", 15.0, "alchemy", 5
	))
	
	# Speed Potion - mint + fern + sage
	_register_recipe(_make_recipe(
		"brew_speed_potion", "Speed Potion", "Brew a potion that increases movement speed.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "mint_leaf", "amount": 2}, {"item_id": "fern_frond", "amount": 1}, {"item_id": "sage_leaf", "amount": 1}],
		"speed_potion", 1, 6.0, "alchemy", 20.0, "alchemy", 15
	))
	
	# Strength Potion - nightshade + golden mushroom + sage
	_register_recipe(_make_recipe(
		"brew_strength_potion", "Strength Potion", "Brew a potion that increases attack damage.",
		CraftingRecipe.RecipeCategory.POTIONS, CraftingRecipe.CraftingStation.ALCHEMY_TABLE,
		[{"item_id": "empty_bottle", "amount": 1}, {"item_id": "nightshade", "amount": 2}, {"item_id": "golden_mushroom", "amount": 1}, {"item_id": "sage_leaf", "amount": 1}],
		"strength_potion", 1, 8.0, "alchemy", 25.0, "alchemy", 15
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
		"flour", 2, 2.0, "cooking", 5.0, "cooking", 1
	))
	
	_register_recipe(_make_recipe(
		"churn_butter", "Butter", "Churn milk into butter.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "milk", "amount": 2}],
		"butter", 1, 3.0, "cooking", 5.0, "cooking", 1
	))
	
	_register_recipe(_make_recipe(
		"make_cheese", "Cheese", "Age milk into cheese.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "milk", "amount": 3}],
		"cheese", 1, 5.0, "cooking", 8.0, "cooking", 3
	))
	
	# Basic cooked meats
	_register_recipe(_make_recipe(
		"cook_meat", "Cooked Meat", "Cook raw meat over the fire.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "raw_meat", "amount": 1}],
		"cooked_meat", 1, 3.0, "cooking", 8.0, "cooking", 3
	))
	
	_register_recipe(_make_recipe(
		"cook_venison", "Cooked Venison", "Roast venison over the fire.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "venison", "amount": 1}],
		"cooked_venison", 1, 4.0, "cooking", 12.0, "cooking", 5
	))
	
	_register_recipe(_make_recipe(
		"cook_rabbit", "Cooked Rabbit", "Cook tender rabbit meat.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "rabbit_meat", "amount": 1}],
		"cooked_rabbit", 1, 3.0, "cooking", 10.0, "cooking", 3
	))
	
	_register_recipe(_make_recipe(
		"fry_egg", "Fried Egg", "Fry an egg on a hot stone.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "egg", "amount": 1}],
		"fried_egg", 1, 2.0, "cooking", 5.0, "cooking", 1
	))
	
	# Baked goods
	_register_recipe(_make_recipe(
		"bake_bread", "Bread", "Bake bread from flour.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "flour", "amount": 2}],
		"bread", 1, 4.0, "baking", 10.0, "baking", 3
	))
	
	_register_recipe(_make_recipe(
		"bake_meat_pie", "Meat Pie", "Bake a hearty meat pie.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "flour", "amount": 2}, {"item_id": "cooked_meat", "amount": 1}, {"item_id": "butter", "amount": 1}],
		"meat_pie", 1, 6.0, "baking", 18.0, "baking", 10
	))
	
	_register_recipe(_make_recipe(
		"bake_apple_pie", "Apple Pie", "Bake a sweet apple pie.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "flour", "amount": 2}, {"item_id": "apple", "amount": 2}, {"item_id": "butter", "amount": 1}],
		"apple_pie", 1, 6.0, "baking", 15.0, "baking", 8
	))
	
	# Soups & Stews
	_register_recipe(_make_recipe(
		"cook_vegetable_soup", "Vegetable Soup", "Simmer a pot of garden vegetables.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "carrot", "amount": 1}, {"item_id": "potato", "amount": 1}, {"item_id": "tomato", "amount": 1}],
		"vegetable_soup", 1, 5.0, "cooking", 12.0, "cooking", 8
	))
	
	_register_recipe(_make_recipe(
		"cook_mushroom_soup", "Mushroom Soup", "Brew a rich mushroom soup.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "common_mushroom", "amount": 3}, {"item_id": "milk", "amount": 1}],
		"mushroom_soup", 1, 5.0, "cooking", 12.0, "cooking", 5
	))
	
	_register_recipe(_make_recipe(
		"cook_hearty_stew", "Hearty Stew", "Slow-cook a thick stew of meat and vegetables.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "cooked_meat", "amount": 1}, {"item_id": "potato", "amount": 2}, {"item_id": "carrot", "amount": 1}, {"item_id": "tomato", "amount": 1}],
		"hearty_stew", 1, 8.0, "cooking", 20.0, "cooking", 12
	))
	
	# Drinks
	_register_recipe(_make_recipe(
		"brew_mushroom_tea", "Mushroom Tea", "Brew a warm tea from golden mushrooms.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "golden_mushroom", "amount": 1}, {"item_id": "chamomile", "amount": 1}, {"item_id": "empty_bottle", "amount": 1}],
		"mushroom_tea", 1, 5.0, "cooking", 15.0, "cooking", 5
	))
	
	# Fish cooking
	_register_recipe(_make_recipe(
		"cook_raw_fish", "Cooked Fish", "Grill a fresh fish over the fire.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "raw_fish", "amount": 1}],
		"cooked_fish", 1, 3.0, "cooking", 8.0, "cooking", 3
	))
	_register_recipe(_make_recipe(
		"cook_salmon", "Grilled Salmon", "Grill a plump salmon to perfection.",
		CraftingRecipe.RecipeCategory.FOOD, CraftingRecipe.CraftingStation.COOKING_FIRE,
		[{"item_id": "salmon", "amount": 1}],
		"grilled_salmon", 1, 4.0, "cooking", 12.0, "cooking", 5
	))

	# ===== BUILDING (Workbench) =====
	
	# Wooden Fence - 2 planks + 1 string
	_register_recipe(_make_recipe(
		"craft_fence_wood", "Wooden Fence", "Craft a wooden fence section.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 2}, {"item_id": "string", "amount": 1}],
		"fence_wood", 2, 2.0, "crafting", 5.0
	))
	
	# Fence Post - 1 log
	_register_recipe(_make_recipe(
		"craft_fence_post", "Fence Post", "Craft a fence post for corners and ends.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 1}],
		"fence_post", 2, 1.5, "crafting", 3.0
	))
	
	# Fence Gate - 3 planks + 2 string + 1 iron ingot (hinge)
	_register_recipe(_make_recipe(
		"craft_fence_gate", "Fence Gate", "Craft a gate that can be opened and closed.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 3}, {"item_id": "string", "amount": 2}, {"item_id": "iron_ingot", "amount": 1}],
		"fence_gate", 1, 3.0, "crafting", 10.0, "crafting", 5
	))

	# ===== Piece-by-Piece House Building =====
	_register_recipe(_make_recipe(
		"craft_wall_wood", "Wooden Wall", "Craft a half-timber wall panel.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 3}, {"item_id": "rope", "amount": 1}],
		"wall_wood", 1, 3.0, "crafting", 6.0, "crafting", 5
	))
	_register_recipe(_make_recipe(
		"craft_floor_wood", "Wooden Floor", "Craft a wooden floor tile.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 3}],
		"floor_wood", 1, 2.5, "crafting", 5.0, "crafting", 5
	))
	_register_recipe(_make_recipe(
		"craft_door_wood", "Wooden Door", "Craft a proper door that opens and closes.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 3}, {"item_id": "string", "amount": 2}, {"item_id": "iron_ingot", "amount": 1}],
		"door_wood", 1, 3.0, "crafting", 10.0, "crafting", 5
	))

	# Barn - large building, expensive
	_register_recipe(_make_recipe(
		"craft_barn", "Barn", "Build a barn to shelter your animals.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 10}, {"item_id": "wood_plank", "amount": 8}, {"item_id": "iron_ingot", "amount": 2}, {"item_id": "rope", "amount": 2}],
		"barn", 1, 10.0, "crafting", 25.0, "crafting", 10
	))
	
	# Hut - smaller building
	_register_recipe(_make_recipe(
		"craft_hut", "Hut", "Build a small hut for storage or shelter.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 6}, {"item_id": "wood_plank", "amount": 4}, {"item_id": "rope", "amount": 1}],
		"hut", 1, 8.0, "crafting", 18.0, "crafting", 5
	))

	# House - a proper player home, with a working interior
	_register_recipe(_make_recipe(
		"craft_house", "House", "Build a proper house of your own, with a door leading inside.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 14}, {"item_id": "wood_plank", "amount": 10}, {"item_id": "stone", "amount": 6}, {"item_id": "iron_ingot", "amount": 4}, {"item_id": "rope", "amount": 3}],
		"house", 1, 14.0, "crafting", 35.0, "crafting", 15
	))
	
	# Feeding Trough
	_register_recipe(_make_recipe(
		"craft_feeding_trough", "Feeding Trough", "Craft a trough for feeding farm animals.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 4}, {"item_id": "iron_ingot", "amount": 1}],
		"feeding_trough", 1, 4.0, "crafting", 10.0, "crafting", 3
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

	# ===== DEFENSIVE STRUCTURES =====
	
	# Wooden Wall — at workbench
	_register_recipe(_make_recipe(
		"craft_wood_wall", "Wooden Wall", "Build a sturdy wooden wall to block enemies.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 4}, {"item_id": "wood_plank", "amount": 4}],
		"wood_wall", 2, 5.0, "crafting", 8.0, "crafting", 3
	))
	
	# Stone Wall — at workbench
	_register_recipe(_make_recipe(
		"craft_stone_wall", "Stone Wall", "Build a strong stone wall that blocks enemies.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "stone", "amount": 8}, {"item_id": "stone_brick", "amount": 4}],
		"stone_wall", 2, 7.0, "crafting", 12.0, "crafting", 8
	))
	
	# Spiked Barricade — at workbench
	_register_recipe(_make_recipe(
		"craft_spiked_barricade", "Spiked Barricade", "Build a spiked barricade that damages enemies.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_plank", "amount": 4}, {"item_id": "iron_ingot", "amount": 2}, {"item_id": "rope", "amount": 1}],
		"spiked_barricade", 2, 6.0, "crafting", 10.0, "crafting", 8
	))
	
	# Community Center — requires lots of resources
	_register_recipe(_make_recipe(
		"craft_community_center", "Community Center", "Build a community center with shared storage.",
		CraftingRecipe.RecipeCategory.BUILDING, CraftingRecipe.CraftingStation.WORKBENCH,
		[{"item_id": "wood_log", "amount": 15}, {"item_id": "wood_plank", "amount": 12}, {"item_id": "iron_ingot", "amount": 4}, {"item_id": "rope", "amount": 3}, {"item_id": "stone", "amount": 10}],
		"community_center", 1, 15.0, "crafting", 40.0, "crafting", 15
	))
