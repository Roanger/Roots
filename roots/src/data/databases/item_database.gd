extends Node
class_name ItemDatabase
## Central database for all item definitions

var items: Dictionary = {}  # item_id -> ItemData

func _ready() -> void:
	_initialize_items()

func _load_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var tex = load(path) as Texture2D
	return tex

func _initialize_items() -> void:
	# Materials (icons from Material / Ore & Gem pack)
	var wood_mat = _create_material("wood", "Wood", "A piece of wood from a tree.", 5, 99)
	wood_mat.icon = _load_icon("res://Material/Wood Log.png")
	_register_item(wood_mat)
	var stone_mat = _create_material("stone", "Stone", "A common stone.", 3, 99)
	stone_mat.icon = _load_icon("res://Ore & Gem/Coal.png")
	_register_item(stone_mat)
	var fiber_mat = _create_material("fiber", "Fiber", "Plant fiber for crafting.", 2, 99)
	fiber_mat.icon = _load_icon("res://Material/Fabric.png")
	_register_item(fiber_mat)
	_register_item(_create_material("sap", "Sap", "Sticky tree sap.", 8, 50))
	
	# Seeds (assign Veggies icons where we have a match)
	var carrot_seeds = _create_seed("carrot_seeds", "Carrot Seeds", "Plant these to grow carrots.", 15, "carrot", 90.0)
	carrot_seeds.icon = _load_icon("res://Veggies/icon-carrot.png")
	_register_item(carrot_seeds)
	var tomato_seeds = _create_seed("tomato_seeds", "Tomato Seeds", "Plant these to grow tomatoes.", 20, "tomato", 110.0)
	tomato_seeds.icon = _load_icon("res://Veggies/icon-tomato.png")
	_register_item(tomato_seeds)
	var wheat_seeds_item = _create_seed("wheat_seeds", "Wheat Seeds", "Plant these to grow wheat.", 10, "wheat", 120.0)
	wheat_seeds_item.icon = _load_icon("res://Veggies/icon-peas.png")
	_register_item(wheat_seeds_item)
	var potato_seeds_item = _create_seed("potato_seeds", "Potato Seeds", "Plant these to grow potatoes.", 12, "potato", 100.0)
	potato_seeds_item.icon = _load_icon("res://Veggies/icon-pumpkin.png")
	_register_item(potato_seeds_item)
	
	# Crops
	var carrot_crop = _create_crop("carrot", "Carrot", "A fresh orange carrot.", 30, 25.0)
	carrot_crop.icon = _load_icon("res://Veggies/icon-carrot.png")
	_register_item(carrot_crop)
	var tomato_crop = _create_crop("tomato", "Tomato", "A ripe red tomato.", 35, 15.0)
	tomato_crop.icon = _load_icon("res://Veggies/icon-tomato.png")
	_register_item(tomato_crop)
	var wheat_crop = _create_crop("wheat", "Wheat", "Golden wheat stalks.", 25, 20.0)
	wheat_crop.icon = _load_icon("res://Veggies/icon-peas.png")
	_register_item(wheat_crop)
	var potato_crop = _create_crop("potato", "Potato", "A starchy potato.", 20, 30.0)
	potato_crop.icon = _load_icon("res://Veggies/icon-pumpkin.png")
	_register_item(potato_crop)
	
	# Tools (icons from Weapon & Tool pack, 3D models from KayKit RPGToolsBits)
	var hoe_tool = _create_tool("basic_hoe", "Basic Hoe", "For tilling soil.", 100, "hoe", 1, 100)
	hoe_tool.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	hoe_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	_register_item(hoe_tool)
	var shovel_tool = _create_tool("basic_shovel", "Basic Shovel", "For digging and moving soil.", 80, "shovel", 1, 80)
	shovel_tool.icon = _load_icon("res://Weapon & Tool/Shovel.png")
	shovel_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/shovel.fbx"
	_register_item(shovel_tool)
	var watering_tool = _create_tool("basic_watering_can", "Watering Can", "For watering crops.", 150, "watering_can", 1, 150)
	watering_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/bucket_metal.fbx"
	_register_item(watering_tool)
	var sickle_tool = _create_tool("basic_sickle", "Basic Sickle", "For harvesting crops.", 120, "sickle", 1, 120)
	sickle_tool.icon = _load_icon("res://Weapon & Tool/Knife.png")
	sickle_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/knife.fbx"
	_register_item(sickle_tool)
	var axe_tool = _create_tool("basic_axe", "Basic Axe", "For chopping trees.", 150, "axe", 1, 100)
	axe_tool.icon = _load_icon("res://Weapon & Tool/Axe.png")
	axe_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/axe.fbx"
	_register_item(axe_tool)
	var pickaxe_tool = _create_tool("basic_pickaxe", "Basic Pickaxe", "For mining rocks.", 150, "pickaxe", 1, 100)
	pickaxe_tool.icon = _load_icon("res://Weapon & Tool/Pickaxe.png")
	pickaxe_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	_register_item(pickaxe_tool)
	# Extra tools
	var hammer_tool = _create_tool("basic_hammer", "Hammer", "For crafting and building.", 120, "hammer", 1, 100)
	hammer_tool.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	hammer_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/hammer.fbx"
	_register_item(hammer_tool)
	var saw_tool = _create_tool("basic_saw", "Saw", "For cutting wood.", 100, "saw", 1, 80)
	saw_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/saw.fbx"
	_register_item(saw_tool)
	var chisel_tool = _create_tool("basic_chisel", "Chisel", "For fine crafting work.", 90, "chisel", 1, 60)
	chisel_tool.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/chisel.fbx"
	_register_item(chisel_tool)
	
	# ===== Tiered Tools =====
	# Bronze tier (power 2, durability 150)
	var bronze_hoe = _create_tool("bronze_hoe", "Bronze Hoe", "A copper-alloy hoe, better than wood.", 180, "hoe", 2, 150, ItemData.ToolTier.BRONZE)
	bronze_hoe.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	bronze_hoe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	bronze_hoe.rarity = ItemData.ItemRarity.COMMON
	_register_item(bronze_hoe)
	var bronze_axe = _create_tool("bronze_axe", "Bronze Axe", "A copper-alloy axe for chopping.", 200, "axe", 2, 150, ItemData.ToolTier.BRONZE)
	bronze_axe.icon = _load_icon("res://Weapon & Tool/Axe.png")
	bronze_axe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/axe.fbx"
	bronze_axe.rarity = ItemData.ItemRarity.COMMON
	_register_item(bronze_axe)
	var bronze_pickaxe = _create_tool("bronze_pickaxe", "Bronze Pickaxe", "A copper-alloy pickaxe for mining.", 200, "pickaxe", 2, 150, ItemData.ToolTier.BRONZE)
	bronze_pickaxe.icon = _load_icon("res://Weapon & Tool/Pickaxe.png")
	bronze_pickaxe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	bronze_pickaxe.rarity = ItemData.ItemRarity.COMMON
	_register_item(bronze_pickaxe)
	var bronze_sickle = _create_tool("bronze_sickle", "Bronze Sickle", "A copper-alloy sickle for harvesting.", 180, "sickle", 2, 150, ItemData.ToolTier.BRONZE)
	bronze_sickle.icon = _load_icon("res://Weapon & Tool/Knife.png")
	bronze_sickle.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/knife.fbx"
	bronze_sickle.rarity = ItemData.ItemRarity.COMMON
	_register_item(bronze_sickle)
	
	# Iron tier (power 3, durability 200)
	var iron_hoe = _create_tool("iron_hoe", "Iron Hoe", "A sturdy iron hoe.", 300, "hoe", 3, 200, ItemData.ToolTier.IRON)
	iron_hoe.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	iron_hoe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	iron_hoe.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(iron_hoe)
	var iron_axe = _create_tool("iron_axe", "Iron Axe", "A sharp iron axe.", 350, "axe", 3, 200, ItemData.ToolTier.IRON)
	iron_axe.icon = _load_icon("res://Weapon & Tool/Axe.png")
	iron_axe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/axe.fbx"
	iron_axe.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(iron_axe)
	var iron_pickaxe = _create_tool("iron_pickaxe", "Iron Pickaxe", "A strong iron pickaxe.", 350, "pickaxe", 3, 200, ItemData.ToolTier.IRON)
	iron_pickaxe.icon = _load_icon("res://Weapon & Tool/Pickaxe.png")
	iron_pickaxe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	iron_pickaxe.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(iron_pickaxe)
	var iron_sickle = _create_tool("iron_sickle", "Iron Sickle", "A sharp iron sickle.", 300, "sickle", 3, 200, ItemData.ToolTier.IRON)
	iron_sickle.icon = _load_icon("res://Weapon & Tool/Knife.png")
	iron_sickle.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/knife.fbx"
	iron_sickle.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(iron_sickle)
	
	# Steel tier (power 5, durability 300)
	var steel_hoe = _create_tool("steel_hoe", "Steel Hoe", "A refined steel hoe.", 500, "hoe", 5, 300, ItemData.ToolTier.STEEL)
	steel_hoe.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	steel_hoe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	steel_hoe.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(steel_hoe)
	var steel_axe = _create_tool("steel_axe", "Steel Axe", "A powerful steel axe.", 600, "axe", 5, 300, ItemData.ToolTier.STEEL)
	steel_axe.icon = _load_icon("res://Weapon & Tool/Axe.png")
	steel_axe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/axe.fbx"
	steel_axe.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(steel_axe)
	var steel_pickaxe = _create_tool("steel_pickaxe", "Steel Pickaxe", "A powerful steel pickaxe.", 600, "pickaxe", 5, 300, ItemData.ToolTier.STEEL)
	steel_pickaxe.icon = _load_icon("res://Weapon & Tool/Pickaxe.png")
	steel_pickaxe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	steel_pickaxe.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(steel_pickaxe)
	var steel_sickle = _create_tool("steel_sickle", "Steel Sickle", "A keen steel sickle.", 500, "sickle", 5, 300, ItemData.ToolTier.STEEL)
	steel_sickle.icon = _load_icon("res://Weapon & Tool/Knife.png")
	steel_sickle.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/knife.fbx"
	steel_sickle.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(steel_sickle)
	
	# Mythril tier (power 8, durability 500)
	var mythril_hoe = _create_tool("mythril_hoe", "Mythril Hoe", "A legendary hoe of mythril.", 1000, "hoe", 8, 500, ItemData.ToolTier.MYTHRIL)
	mythril_hoe.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	mythril_hoe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	mythril_hoe.rarity = ItemData.ItemRarity.RARE
	_register_item(mythril_hoe)
	var mythril_axe = _create_tool("mythril_axe", "Mythril Axe", "A legendary axe of mythril.", 1200, "axe", 8, 500, ItemData.ToolTier.MYTHRIL)
	mythril_axe.icon = _load_icon("res://Weapon & Tool/Axe.png")
	mythril_axe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/axe.fbx"
	mythril_axe.rarity = ItemData.ItemRarity.RARE
	_register_item(mythril_axe)
	var mythril_pickaxe = _create_tool("mythril_pickaxe", "Mythril Pickaxe", "A legendary pickaxe of mythril.", 1200, "pickaxe", 8, 500, ItemData.ToolTier.MYTHRIL)
	mythril_pickaxe.icon = _load_icon("res://Weapon & Tool/Pickaxe.png")
	mythril_pickaxe.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/pickaxe.fbx"
	mythril_pickaxe.rarity = ItemData.ItemRarity.RARE
	_register_item(mythril_pickaxe)
	var mythril_sickle = _create_tool("mythril_sickle", "Mythril Sickle", "A legendary sickle of mythril.", 1000, "sickle", 8, 500, ItemData.ToolTier.MYTHRIL)
	mythril_sickle.icon = _load_icon("res://Weapon & Tool/Knife.png")
	mythril_sickle.world_model_path = "res://KayKit_RPGToolsBits_1.0_FREE/Assets/fbx/knife.fbx"
	mythril_sickle.rarity = ItemData.ItemRarity.RARE
	_register_item(mythril_sickle)
	
	# Weapons (3D models from KayKit Adventurers pack)
	var sword_weapon = _create_weapon("basic_sword", "Iron Sword", "A sturdy one-handed sword.", 200, 10, 80, "sword", "res://KayKit_Adventurers_2.0_FREE/Assets/gltf/sword_1handed.gltf")
	sword_weapon.icon = _load_icon("res://Weapon & Tool/Silver Sword.png")
	_register_item(sword_weapon)
	var axe_weapon = _create_weapon("basic_axe_weapon", "Battle Axe", "A one-handed battle axe.", 180, 12, 70, "battle_axe", "res://KayKit_Adventurers_2.0_FREE/Assets/gltf/axe_1handed.gltf")
	axe_weapon.icon = _load_icon("res://Weapon & Tool/Axe.png")
	_register_item(axe_weapon)
	var dagger_weapon = _create_weapon("basic_dagger", "Dagger", "A quick and light dagger.", 100, 6, 50, "dagger", "res://KayKit_Adventurers_2.0_FREE/Assets/gltf/dagger.gltf")
	dagger_weapon.icon = _load_icon("res://Weapon & Tool/Knife.png")
	_register_item(dagger_weapon)
	
	# ===== Crafting Materials =====
	
	# Wood
	var wood_log = _create_material("wood_log", "Wood Log", "A raw log from a tree.", 5, 50)
	wood_log.icon = _load_icon("res://Material/Wood Log.png")
	wood_log.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Wood_Log_A.fbx"
	_register_item(wood_log)
	var wood_plank = _create_material("wood_plank", "Wooden Plank", "A plank of processed wood.", 3, 50)
	wood_plank.icon = _load_icon("res://Material/Wooden Plank.png")
	wood_plank.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Wood_Plank_A.fbx"
	_register_item(wood_plank)
	var stick = _create_material("stick", "Stick", "A simple wooden stick.", 1, 99)
	stick.icon = _load_icon("res://Material/Wooden Plank.png")
	_register_item(stick)
	
	# Stone
	var stone = _create_material("stone", "Stone", "A chunk of raw stone.", 3, 50)
	stone.icon = _load_icon("res://Ore & Gem/Obsidian.png")
	stone.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Stone_Chunks_Small.fbx"
	_register_item(stone)
	var stone_brick = _create_material("stone_brick", "Stone Brick", "A shaped stone brick.", 8, 50)
	stone_brick.icon = _load_icon("res://Ore & Gem/Obsidian.png")
	stone_brick.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Stone_Brick.fbx"
	_register_item(stone_brick)
	
	# Ores & Ingots
	var coal = _create_material("coal", "Coal", "Fuel for smelting.", 4, 50)
	coal.icon = _load_icon("res://Ore & Gem/Coal.png")
	_register_item(coal)
	var copper_nugget = _create_material("copper_nugget", "Copper Nugget", "Raw copper ore.", 6, 50)
	copper_nugget.icon = _load_icon("res://Ore & Gem/Copper Nugget.png")
	copper_nugget.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Copper_Nugget_Small.fbx"
	_register_item(copper_nugget)
	var copper_ingot = _create_material("copper_ingot", "Copper Ingot", "A smelted copper ingot.", 20, 30)
	copper_ingot.icon = _load_icon("res://Ore & Gem/Copper Ingot.png")
	copper_ingot.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Copper_Bar.fbx"
	_register_item(copper_ingot)
	var iron_nugget = _create_material("iron_nugget", "Iron Nugget", "Raw iron ore.", 8, 50)
	iron_nugget.icon = _load_icon("res://Ore & Gem/Silver Nugget.png")
	iron_nugget.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Iron_Nugget_Small.fbx"
	_register_item(iron_nugget)
	var iron_ingot = _create_material("iron_ingot", "Iron Ingot", "A smelted iron ingot.", 30, 30)
	iron_ingot.icon = _load_icon("res://Ore & Gem/Silver Ingot.png")
	iron_ingot.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Iron_Bar.fbx"
	_register_item(iron_ingot)
	var gold_nugget = _create_material("gold_nugget", "Gold Nugget", "Raw gold ore.", 15, 50)
	gold_nugget.icon = _load_icon("res://Ore & Gem/Gold Nugget.png")
	gold_nugget.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Gold_Nugget_Small.fbx"
	_register_item(gold_nugget)
	var gold_ingot = _create_material("gold_ingot", "Gold Ingot", "A smelted gold ingot.", 50, 30)
	gold_ingot.icon = _load_icon("res://Ore & Gem/Golden Ingot.png")
	gold_ingot.world_model_path = "res://KayKit_ResourceBits_1.0_FREE/Assets/fbx/Gold_Bar.fbx"
	_register_item(gold_ingot)
	
	# Steel & Mythril (advanced tier materials)
	var steel_ingot = _create_material("steel_ingot", "Steel Ingot", "An alloy of iron and coal, stronger than iron.", 60, 30)
	steel_ingot.icon = _load_icon("res://Ore & Gem/Silver Ingot.png")
	steel_ingot.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(steel_ingot)
	var mythril_ore = _create_material("mythril_ore", "Mythril Ore", "A rare magical ore found deep underground.", 40, 30)
	mythril_ore.icon = _load_icon("res://Ore & Gem/Sapphire.png")
	mythril_ore.rarity = ItemData.ItemRarity.RARE
	_register_item(mythril_ore)
	var mythril_ingot = _create_material("mythril_ingot", "Mythril Ingot", "A smelted mythril ingot, light and incredibly strong.", 120, 20)
	mythril_ingot.icon = _load_icon("res://Ore & Gem/Cut Sapphire.png")
	mythril_ingot.rarity = ItemData.ItemRarity.RARE
	_register_item(mythril_ingot)
	
	# Fiber & Cloth
	var string_mat = _create_material("string", "String", "A length of string.", 2, 99)
	string_mat.icon = _load_icon("res://Material/String.png")
	_register_item(string_mat)
	var rope = _create_material("rope", "Rope", "A sturdy braided rope.", 8, 50)
	rope.icon = _load_icon("res://Material/Rope.png")
	_register_item(rope)
	var wool = _create_material("wool", "Wool", "Soft animal wool.", 5, 50)
	wool.icon = _load_icon("res://Material/Wool.png")
	_register_item(wool)
	var fabric = _create_material("fabric", "Fabric", "Woven cloth fabric.", 12, 50)
	fabric.icon = _load_icon("res://Material/Fabric.png")
	_register_item(fabric)
	var leather = _create_material("leather", "Leather", "Tanned animal leather.", 10, 50)
	leather.icon = _load_icon("res://Material/Leather.png")
	_register_item(leather)
	
	# Misc crafting
	var paper = _create_material("paper", "Paper", "A sheet of paper.", 3, 50)
	paper.icon = _load_icon("res://Material/Paper.png")
	_register_item(paper)
	var torch_item = _create_material("torch", "Torch", "A simple torch for light.", 5, 20)
	torch_item.icon = _load_icon("res://Weapon & Tool/Torch.png")
	_register_item(torch_item)
	# Food
	var carrot_food = _create_food("carrot_raw", "Carrot", "A crunchy carrot.", 15, 10.0, 0.0, 5.0)
	carrot_food.icon = _load_icon("res://Veggies/icon-carrot.png")
	_register_item(carrot_food)
	var bread_food = _create_food("bread", "Bread", "Freshly baked bread.", 50, 40.0, 0.0, 0.0)
	bread_food.icon = _load_icon("res://Food/Bread.png")
	_register_item(bread_food)
	
	# ===== Herbs & Alchemy =====
	
	# Gatherable herbs
	var common_mushroom = _create_material("common_mushroom", "Common Mushroom", "An edible forest mushroom.", 3, 99)
	common_mushroom.icon = _load_icon("res://Food/Mushroom.png")
	_register_item(common_mushroom)
	var golden_mushroom = _create_material("golden_mushroom", "Golden Mushroom", "A rare golden mushroom with potent properties.", 15, 50)
	golden_mushroom.icon = _load_icon("res://Food/Mushroom.png")
	golden_mushroom.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(golden_mushroom)
	var lavender = _create_material("lavender", "Lavender", "A fragrant purple flower used in alchemy.", 5, 99)
	lavender.icon = _load_icon("res://Potion/Blue Potion.png")
	_register_item(lavender)
	var chamomile = _create_material("chamomile", "Chamomile", "A calming herb with healing properties.", 5, 99)
	chamomile.icon = _load_icon("res://Potion/Green Potion.png")
	_register_item(chamomile)
	var mint_leaf = _create_material("mint_leaf", "Mint Leaf", "A refreshing herb that invigorates the body.", 4, 99)
	mint_leaf.icon = _load_icon("res://Potion/Green Potion 2.png")
	_register_item(mint_leaf)
	var sage_leaf = _create_material("sage_leaf", "Sage Leaf", "A wise herb used in potent brews.", 6, 99)
	sage_leaf.icon = _load_icon("res://Potion/Blue Potion 2.png")
	_register_item(sage_leaf)
	var nightshade = _create_material("nightshade", "Nightshade", "A dangerous but useful poisonous plant.", 12, 50)
	nightshade.icon = _load_icon("res://Potion/Red Potion.png")
	nightshade.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(nightshade)
	var wild_clover = _create_material("wild_clover", "Wild Clover", "A lucky little plant with mild restorative properties.", 2, 99)
	wild_clover.icon = _load_icon("res://Potion/Green Potion.png")
	_register_item(wild_clover)
	var fern_frond = _create_material("fern_frond", "Fern Frond", "A curled fern frond used in herbal remedies.", 3, 99)
	fern_frond.icon = _load_icon("res://Potion/Green Potion 3.png")
	_register_item(fern_frond)
	
	# Alchemy supplies
	var empty_bottle = _create_material("empty_bottle", "Empty Bottle", "A glass bottle for brewing potions.", 5, 50)
	empty_bottle.icon = _load_icon("res://Potion/Empty Bottle.png")
	_register_item(empty_bottle)
	
	# Potions
	var health_potion = _create_potion("health_potion", "Health Potion", "Restores health over time.", 25, 30.0, 0.0, 0.0, [{"type": "heal", "value": 30.0, "duration": 5.0}])
	health_potion.icon = _load_icon("res://Potion/Red Potion.png")
	_register_item(health_potion)
	var greater_health_potion = _create_potion("greater_health_potion", "Greater Health Potion", "Greatly restores health.", 60, 60.0, 0.0, 0.0, [{"type": "heal", "value": 60.0, "duration": 5.0}])
	greater_health_potion.icon = _load_icon("res://Potion/Red Potion 2.png")
	greater_health_potion.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(greater_health_potion)
	var stamina_potion = _create_potion("stamina_potion", "Stamina Potion", "Restores stamina.", 25, 0.0, 0.0, 40.0, [{"type": "stamina", "value": 40.0, "duration": 5.0}])
	stamina_potion.icon = _load_icon("res://Potion/Green Potion.png")
	_register_item(stamina_potion)
	var speed_potion = _create_potion("speed_potion", "Speed Potion", "Increases movement speed temporarily.", 35, 0.0, 0.0, 0.0, [{"type": "speed", "value": 1.5, "duration": 30.0}])
	speed_potion.icon = _load_icon("res://Potion/Blue Potion.png")
	speed_potion.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(speed_potion)
	var strength_potion = _create_potion("strength_potion", "Strength Potion", "Increases attack damage temporarily.", 40, 0.0, 0.0, 0.0, [{"type": "strength", "value": 1.5, "duration": 30.0}])
	strength_potion.icon = _load_icon("res://Potion/Red Potion 3.png")
	strength_potion.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(strength_potion)
	var antidote = _create_potion("antidote", "Antidote", "Cures poison and grants brief immunity.", 30, 0.0, 0.0, 0.0, [{"type": "antidote", "value": 1.0, "duration": 60.0}])
	antidote.icon = _load_icon("res://Potion/Blue Potion 3.png")
	_register_item(antidote)
	
	# ===== Animal Products =====
	
	var egg = _create_food("egg", "Egg", "A fresh egg from a chicken or duck.", 5, 10.0, 0.0, 5.0)
	egg.icon = _load_icon("res://Monster Part/Egg.png")
	_register_item(egg)
	
	var milk = _create_material("milk", "Milk", "Fresh milk from a cow or goat.", 8, 20)
	milk.icon = _load_icon("res://Potion/Water Bottle.png")
	_register_item(milk)
	
	
	var raw_meat = _create_food("raw_meat", "Raw Meat", "Uncooked meat. Best when cooked.", 6, 5.0, 0.0, 3.0)
	raw_meat.icon = _load_icon("res://Food/Meat.png")
	_register_item(raw_meat)
	
	var feathers = _create_material("feathers", "Feathers", "Soft feathers from poultry.", 3, 99)
	feathers.icon = _load_icon("res://Monster Part/Feather.png")
	_register_item(feathers)
	
	var animal_feed = _create_material("animal_feed", "Animal Feed", "A mix of grains and seeds for farm animals.", 4, 99)
	animal_feed.icon = _load_icon("res://Food/Bread.png")
	_register_item(animal_feed)
	
	var venison = _create_food("venison", "Venison", "Lean meat from a deer. Nutritious when cooked.", 10, 8.0, 0.0, 5.0)
	venison.icon = _load_icon("res://Food/Meat.png")
	venison.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(venison)
	
	var rabbit_meat = _create_food("rabbit_meat", "Rabbit Meat", "Tender rabbit meat.", 7, 6.0, 0.0, 4.0)
	rabbit_meat.icon = _load_icon("res://Food/Meat.png")
	_register_item(rabbit_meat)
	
	var rabbit_fur = _create_material("rabbit_fur", "Rabbit Fur", "Soft fur from a rabbit. Used in crafting.", 8, 50)
	rabbit_fur.icon = _load_icon("res://Material/Leather.png")
	_register_item(rabbit_fur)
	
	var deer_pelt = _create_material("deer_pelt", "Deer Pelt", "A sturdy pelt from a deer.", 15, 30)
	deer_pelt.icon = _load_icon("res://Material/Leather.png")
	deer_pelt.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(deer_pelt)
	
	# ===== Cooking Ingredients =====
	
	var flour = _create_material("flour", "Flour", "Ground wheat flour for baking.", 8, 50)
	flour.icon = _load_icon("res://Material/Paper.png")
	_register_item(flour)
	
	var cheese = _create_food("cheese", "Cheese", "Aged cheese made from milk.", 12, 20.0, 5.0, 5.0)
	cheese.icon = _load_icon("res://Food/Cheese.png")
	_register_item(cheese)
	
	var butter = _create_material("butter", "Butter", "Creamy butter churned from milk.", 10, 50)
	butter.icon = _load_icon("res://Food/Cheese.png")
	_register_item(butter)
	
	# ===== Cooked Foods =====
	
	# Basic cooked meats
	var cooked_meat = _create_cooked_food("cooked_meat", "Cooked Meat", "Seared meat. Restores health and stamina.", 15, 30.0, 15.0, 10.0,
		[{"type": "well_fed", "value": 1.1, "duration": 60.0}] as Array[Dictionary])
	cooked_meat.icon = _load_icon("res://Food/Ham.png")
	_register_item(cooked_meat)
	
	var cooked_venison = _create_cooked_food("cooked_venison", "Cooked Venison", "Tender roasted venison. Very nutritious.", 25, 40.0, 20.0, 15.0,
		[{"type": "well_fed", "value": 1.15, "duration": 90.0}] as Array[Dictionary])
	cooked_venison.icon = _load_icon("res://Food/Ham.png")
	cooked_venison.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(cooked_venison)
	
	var cooked_rabbit = _create_cooked_food("cooked_rabbit", "Cooked Rabbit", "Light and tender rabbit meat.", 18, 25.0, 10.0, 15.0,
		[{"type": "speed", "value": 1.15, "duration": 45.0}] as Array[Dictionary])
	cooked_rabbit.icon = _load_icon("res://Food/Ham.png")
	_register_item(cooked_rabbit)
	
	var fried_egg = _create_cooked_food("fried_egg", "Fried Egg", "A simple fried egg. Quick energy.", 10, 20.0, 5.0, 15.0)
	fried_egg.icon = _load_icon("res://Monster Part/Egg.png")
	_register_item(fried_egg)
	
	# Soups & Stews
	var vegetable_soup = _create_cooked_food("vegetable_soup", "Vegetable Soup", "A hearty soup of garden vegetables.", 20, 35.0, 10.0, 10.0,
		[{"type": "heal", "value": 20.0, "duration": 15.0}] as Array[Dictionary])
	vegetable_soup.icon = _load_icon("res://Potion/Green Potion.png")
	_register_item(vegetable_soup)
	
	var mushroom_soup = _create_cooked_food("mushroom_soup", "Mushroom Soup", "Earthy mushroom soup with restorative properties.", 22, 30.0, 15.0, 10.0,
		[{"type": "heal", "value": 25.0, "duration": 15.0}] as Array[Dictionary])
	mushroom_soup.icon = _load_icon("res://Potion/Green Potion 2.png")
	_register_item(mushroom_soup)
	
	var hearty_stew = _create_cooked_food("hearty_stew", "Hearty Stew", "A thick stew of meat and vegetables. Very filling.", 40, 50.0, 25.0, 20.0,
		[{"type": "well_fed", "value": 1.2, "duration": 120.0}, {"type": "strength", "value": 1.1, "duration": 60.0}] as Array[Dictionary])
	hearty_stew.icon = _load_icon("res://Potion/Red Potion.png")
	hearty_stew.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(hearty_stew)
	
	# Baked goods
	var meat_pie = _create_cooked_food("meat_pie", "Meat Pie", "A golden-crusted pie filled with seasoned meat.", 35, 45.0, 20.0, 15.0,
		[{"type": "well_fed", "value": 1.15, "duration": 90.0}] as Array[Dictionary])
	meat_pie.icon = _load_icon("res://Food/Bread.png")
	meat_pie.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(meat_pie)
	
	var apple_pie = _create_cooked_food("apple_pie", "Apple Pie", "Sweet baked apple pie. Boosts stamina recovery.", 30, 35.0, 10.0, 25.0,
		[{"type": "stamina", "value": 30.0, "duration": 30.0}] as Array[Dictionary])
	apple_pie.icon = _load_icon("res://Food/Bread.png")
	_register_item(apple_pie)
	
	# Fruit (raw consumable)
	var apple = _create_food("apple", "Apple", "A crisp apple. Light snack.", 5, 10.0, 5.0, 5.0)
	apple.icon = _load_icon("res://Food/Apple.png")
	_register_item(apple)
	
	# Drinks
	var mushroom_tea = _create_cooked_food("mushroom_tea", "Mushroom Tea", "A warm brew of golden mushrooms. Enhances focus.", 30, 15.0, 10.0, 20.0,
		[{"type": "well_fed", "value": 1.1, "duration": 60.0}, {"type": "speed", "value": 1.1, "duration": 45.0}] as Array[Dictionary])
	mushroom_tea.icon = _load_icon("res://Food/Wine.png")
	mushroom_tea.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(mushroom_tea)
	
	# ===== Placeable Items (Fences, Gates) =====
	
	var fence_wood = _create_placeable("fence_wood", "Wooden Fence", "A sturdy wooden fence section.", 8,
		"res://modular_terrain_collection/Hilly_Prop_Fence_Boards_1.obj", 2.0,
		Vector3(1.0, 0.8, 0.15))
	fence_wood.icon = _load_icon("res://Material/Wooden Plank.png")
	_register_item(fence_wood)
	
	var fence_post = _create_placeable("fence_post", "Fence Post", "A wooden fence post for corners and ends.", 5,
		"res://modular_terrain_collection/Hilly_Prop_Fence_Post_1.obj", 2.0,
		Vector3(0.2, 1.0, 0.2))
	fence_post.icon = _load_icon("res://Material/Wooden Plank.png")
	_register_item(fence_post)
	
	var fence_gate = _create_placeable("fence_gate", "Fence Gate", "A gate that can be opened and closed.", 15,
		"res://modular_terrain_collection/Hilly_Prop_Fence_Gate_1.obj", 2.0,
		Vector3(1.0, 0.8, 0.15))
	fence_gate.icon = _load_icon("res://Material/Wooden Plank.png")
	fence_gate.placeable_is_gate = true
	_register_item(fence_gate)
	
	# ===== Placeable Buildings =====
	
	var barn = _create_placeable("barn", "Barn", "A cozy barn to shelter your animals.", 80,
		"res://Animal QiwiiPack/Animal Models/Barn.fbx", 0.5,
		Vector3(4.0, 3.0, 4.0))
	barn.icon = _load_icon("res://Misc/Crate.png")
	barn.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(barn)
	
	var hut = _create_placeable("hut", "Hut", "A small wooden hut for storage or shelter.", 50,
		"res://Animal QiwiiPack/Animal Models/Hut.fbx", 0.5,
		Vector3(2.5, 2.5, 2.5))
	hut.icon = _load_icon("res://Misc/Crate.png")
	hut.rarity = ItemData.ItemRarity.UNCOMMON
	_register_item(hut)
	
	var feeding_trough = _create_placeable("feeding_trough", "Feeding Trough", "A wooden trough for feeding farm animals.", 20,
		"", 1.0,
		Vector3(1.5, 0.5, 0.6))
	feeding_trough.icon = _load_icon("res://Material/Wooden Plank.png")
	_register_item(feeding_trough)
	
	var campfire = _create_placeable("campfire", "Campfire", "A warm campfire for light and cooking.", 15,
		"res://modular_terrain_collection/Hilly_Prop_Camp_Campfire.obj", 2.0,
		Vector3(0.8, 0.4, 0.8))
	campfire.icon = _load_icon("res://Weapon & Tool/Torch.png")
	_register_item(campfire)
	
	var sitting_log = _create_placeable("sitting_log", "Sitting Log", "A log to sit on by the fire.", 8,
		"res://modular_terrain_collection/Hilly_Prop_Camp_Sitting_Log.obj", 2.0,
		Vector3(1.2, 0.5, 0.5))
	sitting_log.icon = _load_icon("res://Material/Wood Log.png")
	_register_item(sitting_log)
	
	# Optional: assign more from root-level item###.png or other packs
	_set_item_icons_from_pack()
	
	print("ItemDatabase initialized with ", items.size(), " items")

func _set_item_icons_from_pack() -> void:
	# Items without a direct match: use a close fit from available packs
	var watering_can = items.get("basic_watering_can")
	if watering_can:
		watering_can.icon = _load_icon("res://Potion/Water Bottle.png")

func _register_item(item: ItemData) -> void:
	if item and not item.item_id.is_empty():
		items[item.item_id] = item

func get_item(item_id: String) -> ItemData:
	return items.get(item_id, null)

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.assign(items.values())
	return result

func get_items_by_type(item_type: ItemData.ItemType) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items.values():
		if item.item_type == item_type:
			result.append(item)
	return result

# Helper functions to create items
func _create_material(id: String, name: String, desc: String, value: int, max_stack: int) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.MATERIAL
	item.base_value = value
	item.max_stack_size = max_stack
	item.is_stackable = true
	return item

func _create_seed(id: String, name: String, desc: String, value: int, crop: String, growth_time: float) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.SEED
	item.base_value = value
	item.max_stack_size = 99
	item.is_stackable = true
	item.crop_id = crop
	item.growth_time = growth_time
	return item

func _create_crop(id: String, name: String, desc: String, value: int, hunger: float) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.CROP
	item.base_value = value
	item.max_stack_size = 99
	item.is_stackable = true
	item.is_consumable = true
	item.hunger_restore = hunger
	return item

func _create_tool(id: String, name: String, desc: String, value: int, tool_type: String, power: int, durability: int, tier: int = ItemData.ToolTier.WOOD) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.TOOL
	item.base_value = value
	item.max_stack_size = 1
	item.is_stackable = false
	item.has_durability = true
	item.max_durability = durability
	item.tool_type = tool_type
	item.tool_tier = tier
	item.tool_power = power
	item.tool_range = 2.0
	return item

func _create_weapon(id: String, name: String, desc: String, value: int, power: int, durability: int, weapon_type: String = "sword", model_path: String = "") -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.WEAPON
	item.base_value = value
	item.max_stack_size = 1
	item.is_stackable = false
	item.has_durability = true
	item.max_durability = durability
	item.tool_type = weapon_type
	item.tool_power = power
	item.world_model_path = model_path
	return item

func _create_potion(id: String, name: String, desc: String, value: int, health: float, hunger: float, stamina: float, buffs: Array = []) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.POTION
	item.base_value = value
	item.max_stack_size = 10
	item.is_stackable = true
	item.is_consumable = true
	item.health_restore = health
	item.hunger_restore = hunger
	item.stamina_restore = stamina
	item.buff_effects.assign(buffs)
	return item

func _create_food(id: String, name: String, desc: String, value: int, hunger: float, health: float, stamina: float) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.FOOD
	item.base_value = value
	item.max_stack_size = 20
	item.is_stackable = true
	item.is_consumable = true
	item.hunger_restore = hunger
	item.health_restore = health
	item.stamina_restore = stamina
	return item

func _create_cooked_food(id: String, name: String, desc: String, value: int, hunger: float, health: float, stamina: float, buffs: Array[Dictionary] = []) -> ItemData:
	var item = _create_food(id, name, desc, value, hunger, health, stamina)
	item.buff_effects = buffs
	return item

func _create_placeable(id: String, name: String, desc: String, value: int, model_path: String, model_scale: float, collision_size: Vector3) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.item_type = ItemData.ItemType.PLACEABLE
	item.base_value = value
	item.max_stack_size = 50
	item.is_stackable = true
	item.placeable_model_path = model_path
	item.placeable_scale = model_scale
	item.placeable_collision_size = collision_size
	return item
