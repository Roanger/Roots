extends Resource
class_name ItemData
## Base class for all item data

enum ItemType {
	MATERIAL,    # Crafting materials, resources
	TOOL,        # Hoes, axes, pickaxes, etc.
	WEAPON,      # Combat weapons
	FOOD,        # Consumable food items
	SEED,        # Crop seeds
	CROP,        # Harvested crops
	POTION,      # Alchemy potions
	EQUIPMENT,   # Armor, accessories
	QUEST,       # Quest items
	MISC         # Miscellaneous items
}

enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum ItemQuality {
	POOR,
	NORMAL,
	GOOD,
	EXCELLENT,
	PERFECT
}

# Basic info
@export var item_id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var rarity: ItemRarity = ItemRarity.COMMON

# Visual
@export var icon: Texture2D = null
@export var world_model: PackedScene = null

# Stack info
@export var max_stack_size: int = 99
@export var is_stackable: bool = true

# Value
@export var base_value: int = 0
@export var sellable: bool = true

# Durability (for tools/weapons/equipment)
@export var has_durability: bool = false
@export var max_durability: int = 100

# Food properties
@export var is_consumable: bool = false
@export var hunger_restore: float = 0.0
@export var health_restore: float = 0.0
@export var stamina_restore: float = 0.0
@export var buff_effects: Array[Dictionary] = []

# Tool properties
@export var tool_type: String = ""  # "hoe", "axe", "pickaxe", "sickle", "watering_can"
@export var tool_power: int = 1
@export var tool_range: float = 2.0

# Seed properties
@export var crop_id: String = ""  # What crop this seed grows
@export var growth_time: float = 60.0  # Seconds to grow

# Crafting
@export var crafting_recipes: Array[String] = []  # IDs of recipes this item is used in

func get_display_name() -> String:
	return item_name

func get_sell_price() -> int:
	var multiplier = 1.0
	match rarity:
		ItemRarity.UNCOMMON: multiplier = 1.5
		ItemRarity.RARE: multiplier = 2.5
		ItemRarity.EPIC: multiplier = 5.0
		ItemRarity.LEGENDARY: multiplier = 10.0
	return int(base_value * multiplier * 0.5)  # Sell for 50% of value

func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.COMMON: return Color(0.7, 0.7, 0.7)
		ItemRarity.UNCOMMON: return Color(0.2, 0.8, 0.2)
		ItemRarity.RARE: return Color(0.2, 0.4, 0.9)
		ItemRarity.EPIC: return Color(0.6, 0.2, 0.8)
		ItemRarity.LEGENDARY: return Color(1.0, 0.6, 0.1)
	return Color.WHITE

func can_stack_with(other: ItemData) -> bool:
	if not is_stackable or not other.is_stackable:
		return false
	return item_id == other.item_id
