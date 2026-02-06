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
	var wooden_fence = _create_material("wooden_fence", "Wooden Fence", "A simple fence section.", 8, 20)
	wooden_fence.icon = _load_icon("res://Material/Wooden Plank.png")
	_register_item(wooden_fence)
	
	# Food
	var carrot_food = _create_food("carrot_raw", "Carrot", "A crunchy carrot.", 15, 10.0, 0.0, 5.0)
	carrot_food.icon = _load_icon("res://Veggies/icon-carrot.png")
	_register_item(carrot_food)
	var bread_food = _create_food("bread", "Bread", "Freshly baked bread.", 50, 40.0, 0.0, 0.0)
	bread_food.icon = _load_icon("res://Food/Bread.png")
	_register_item(bread_food)
	
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
