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
	PLACEABLE,   # Fences, gates, decorations — placed in world
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

enum ToolTier {
	STONE,      # Ground-tier — hand-crafted from gathered stones and sticks
	WOOD,       # Starter tier at workbench
	BRONZE,     # Copper-based
	IRON,       # Mid-tier
	STEEL,      # Advanced
	MYTHRIL     # End-game
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
@export var world_model_path: String = ""  # Path to 3D model (FBX/GLTF) for first-person display

# Stack info
@export var max_stack_size: int = 99
@export var is_stackable: bool = true

# Value
@export var base_value: int = 0
@export var sellable: bool = true

# Durability (for tools/weapons/equipment)
@export var has_durability: bool = false
@export var max_durability: int = 100

# Offhand
@export var is_offhand: bool = false  # Can be equipped in the offhand slot

# Food properties
@export var is_consumable: bool = false
@export var hunger_restore: float = 0.0
@export var health_restore: float = 0.0
@export var stamina_restore: float = 0.0
@export var buff_effects: Array[Dictionary] = []

# Equipment properties
@export var defense_value: int = 0  # Damage reduction for armor

# Tool properties
@export var tool_type: String = ""  # "hoe", "axe", "pickaxe", "sickle", "watering_can"
@export var tool_tier: ToolTier = ToolTier.WOOD
@export var tool_power: int = 1
@export var tool_range: float = 2.0

# Profession equipment bonus — for TOOL items worn in the passive Tool 1/2/3
# equipment slots (see Equipment.EquipmentSlot). Each entry: {"skill": String,
# "effect": int (PerkData.PerkEffect), "value": float}. Summed into
# SkillManager.get_perk_bonus()/get_total_perk_bonus() alongside unlocked perks.
@export var equip_bonuses: Array[Dictionary] = []

# Seed properties
@export var crop_id: String = ""  # What crop this seed grows
@export var growth_time: float = 60.0  # Seconds to grow

# Station (crafting bench) type — 0 = not a station, 1-7 = CraftingStation enum
@export var station_type: int = 0

# Placeable properties
@export var placeable_model_path: String = ""  # OBJ/FBX path for world placement
@export var placeable_scale: float = 1.0
@export var placeable_snap_to_grid: bool = true  # Snap to 1-unit grid
@export var placeable_can_rotate: bool = true  # R key to rotate 90°
@export var placeable_collision_size: Vector3 = Vector3(1.0, 1.0, 0.2)  # Collision box size
@export var placeable_is_gate: bool = false  # Gates pivot from hinge edge
@export var placeable_indoor_ok: bool = false  # Can be placed inside a building interior (decorations only)

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

static func get_quality_multiplier(quality: ItemQuality) -> float:
	match quality:
		ItemQuality.POOR: return 0.8
		ItemQuality.GOOD: return 1.15
		ItemQuality.EXCELLENT: return 1.3
		ItemQuality.PERFECT: return 1.5
		_: return 1.0

static func get_quality_name(quality: ItemQuality) -> String:
	match quality:
		ItemQuality.POOR: return "Poor"
		ItemQuality.GOOD: return "Good"
		ItemQuality.EXCELLENT: return "Excellent"
		ItemQuality.PERFECT: return "Perfect"
		_: return ""

static func get_quality_color(quality: ItemQuality) -> Color:
	match quality:
		ItemQuality.POOR: return Color(0.6, 0.55, 0.5)
		ItemQuality.GOOD: return Color(0.4, 0.8, 1.0)
		ItemQuality.EXCELLENT: return Color(0.7, 0.4, 1.0)
		ItemQuality.PERFECT: return Color(1.0, 0.75, 0.2)
		_: return Color(0.85, 0.85, 0.85)

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
