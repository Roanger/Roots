extends Node
class_name ToolAffinity
## Defines which tool types are effective against which target types.
## Used to calculate damage/effectiveness multipliers when using tools on world objects.

# Target types that world objects can declare
enum TargetType {
	FARM_PLOT,      # Tilling, watering, harvesting
	TREE,           # Chopping trees
	LOG,            # Chopping logs/stumps
	ROCK,           # Mining rocks
	ORE_NODE,       # Mining ore deposits
	TALL_GRASS,     # Cutting grass/weeds
	ENEMY,          # Combat targets
	BUILDING,       # Player-built structures
	CRAFTING_STATION # Workbenches, forges, etc.
}

# Effectiveness multipliers: tool_type -> { target_type -> multiplier }
# 1.0 = full effectiveness, 0.25 = reduced, 0.0 = no effect
const AFFINITY_TABLE: Dictionary = {
	"hoe": {
		TargetType.FARM_PLOT: 1.0,
		TargetType.TALL_GRASS: 0.5,
	},
	"watering_can": {
		TargetType.FARM_PLOT: 1.0,
	},
	"sickle": {
		TargetType.FARM_PLOT: 1.0,
		TargetType.TALL_GRASS: 1.0,
	},
	"axe": {
		TargetType.TREE: 1.0,
		TargetType.LOG: 1.0,
		TargetType.ENEMY: 0.5,
		TargetType.TALL_GRASS: 0.25,
	},
	"pickaxe": {
		TargetType.ROCK: 1.0,
		TargetType.ORE_NODE: 1.0,
		TargetType.ENEMY: 0.25,
	},
	"hammer": {
		TargetType.CRAFTING_STATION: 1.0,
		TargetType.BUILDING: 1.0,
		TargetType.ROCK: 0.25,
		TargetType.ENEMY: 0.25,
	},
	"saw": {
		TargetType.LOG: 1.0,
		TargetType.TREE: 0.25,
	},
	"chisel": {
		TargetType.CRAFTING_STATION: 1.0,
		TargetType.ROCK: 0.5,
	},
	"knife": {
		TargetType.TALL_GRASS: 1.0,
		TargetType.ENEMY: 0.5,
	},
	# Weapon types
	"sword": {
		TargetType.ENEMY: 1.0,
		TargetType.TREE: 0.1,
		TargetType.TALL_GRASS: 0.5,
	},
	"dagger": {
		TargetType.ENEMY: 1.0,
		TargetType.TALL_GRASS: 0.5,
	},
	"battle_axe": {
		TargetType.ENEMY: 1.0,
		TargetType.TREE: 0.25,
		TargetType.LOG: 0.25,
	},
}

## Tier multipliers: higher tier tools deal more damage/effectiveness
const TIER_MULTIPLIER: Dictionary = {
	ItemData.ToolTier.WOOD: 1.0,
	ItemData.ToolTier.BRONZE: 1.5,
	ItemData.ToolTier.IRON: 2.0,
	ItemData.ToolTier.STEEL: 3.0,
	ItemData.ToolTier.MYTHRIL: 5.0,
}

## Get the tier multiplier for a given tool tier.
static func get_tier_multiplier(tier: int) -> float:
	return TIER_MULTIPLIER.get(tier, 1.0)

## Get the effectiveness multiplier for a tool type against a target type.
## Returns 0.0 if the tool has no effect on the target.
static func get_effectiveness(tool_type: String, target_type: int) -> float:
	if tool_type in AFFINITY_TABLE:
		var affinities: Dictionary = AFFINITY_TABLE[tool_type]
		if target_type in affinities:
			return affinities[target_type]
	return 0.0

## Check if a tool can affect a target at all (effectiveness > 0).
static func can_affect(tool_type: String, target_type: int) -> bool:
	return get_effectiveness(tool_type, target_type) > 0.0

## Calculate actual damage/power applied to a target.
## base_power is the tool's tool_power stat, tier scales the result.
static func calculate_power(tool_type: String, target_type: int, base_power: int, tier: int = 0) -> float:
	var effectiveness = get_effectiveness(tool_type, target_type)
	var tier_mult = get_tier_multiplier(tier)
	return base_power * effectiveness * tier_mult

## Get a feedback message for when a tool can't affect a target.
static func get_ineffective_message(tool_type: String, target_type: int) -> String:
	if get_effectiveness(tool_type, target_type) > 0.0:
		return ""
	
	match target_type:
		TargetType.TREE, TargetType.LOG:
			return "Use an axe to chop this."
		TargetType.ROCK, TargetType.ORE_NODE:
			return "Use a pickaxe to mine this."
		TargetType.FARM_PLOT:
			return "Use a farming tool on this."
		TargetType.ENEMY:
			return "Use a weapon to fight."
		_:
			return "This tool doesn't work here."

## Get all target types a tool is effective against (multiplier > 0).
static func get_valid_targets(tool_type: String) -> Array:
	var targets: Array = []
	if tool_type in AFFINITY_TABLE:
		for target_type in AFFINITY_TABLE[tool_type]:
			targets.append(target_type)
	return targets
