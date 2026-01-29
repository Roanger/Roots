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
	
	# Tools (icons from Weapon & Tool pack)
	var hoe_tool = _create_tool("basic_hoe", "Basic Hoe", "For tilling soil.", 100, "hoe", 1, 100)
	hoe_tool.icon = _load_icon("res://Weapon & Tool/Hammer.png")
	_register_item(hoe_tool)
	var shovel_tool = _create_tool("basic_shovel", "Basic Shovel", "For digging and moving soil.", 80, "shovel", 1, 80)
	shovel_tool.icon = _load_icon("res://Weapon & Tool/Shovel.png")
	_register_item(shovel_tool)
	_register_item(_create_tool("basic_watering_can", "Watering Can", "For watering crops.", 150, "watering_can", 1, 150))
	var sickle_tool = _create_tool("basic_sickle", "Basic Sickle", "For harvesting crops.", 120, "sickle", 1, 120)
	sickle_tool.icon = _load_icon("res://Weapon & Tool/Knife.png")
	_register_item(sickle_tool)
	var axe_tool = _create_tool("basic_axe", "Basic Axe", "For chopping trees.", 150, "axe", 1, 100)
	axe_tool.icon = _load_icon("res://Weapon & Tool/Axe.png")
	_register_item(axe_tool)
	var pickaxe_tool = _create_tool("basic_pickaxe", "Basic Pickaxe", "For mining rocks.", 150, "pickaxe", 1, 100)
	pickaxe_tool.icon = _load_icon("res://Weapon & Tool/Pickaxe.png")
	_register_item(pickaxe_tool)
	
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

func _create_tool(id: String, name: String, desc: String, value: int, tool_type: String, power: int, durability: int) -> ItemData:
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
	item.tool_power = power
	item.tool_range = 2.0
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
