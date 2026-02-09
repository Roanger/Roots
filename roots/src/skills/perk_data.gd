extends Resource
class_name PerkData
## Defines a single perk node in a profession's skill tree

# Perk effect types
enum PerkEffect {
	YIELD_BONUS,        # +% item yield (e.g., extra ore, herbs, wood)
	SPEED_BONUS,        # +% action speed (e.g., faster smelting, cooking)
	QUALITY_BONUS,      # +% chance of higher quality results
	DAMAGE_BONUS,       # +% damage with profession-related tools/weapons
	DEFENSE_BONUS,      # +% damage reduction
	XP_BONUS,           # +% XP gain for this profession
	RESOURCE_SAVING,    # +% chance to not consume materials
	DOUBLE_HARVEST,     # +% chance to double harvest
	UNLOCK_RECIPE,      # Unlocks a specific recipe tier or recipe
	BUFF_DURATION,      # +% buff duration (potions, food)
	HEALTH_BONUS,       # +flat max health
	STAMINA_BONUS,      # +flat max stamina
	CRIT_CHANCE,        # +% critical hit chance
}

@export var perk_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var skill_id: String = ""           # Which profession this belongs to
@export var required_skill_level: int = 1   # Minimum skill level to unlock
@export var point_cost: int = 1             # Skill points to unlock
@export var prerequisite_perk: String = ""  # Must unlock this perk first (empty = root)
@export var effect_type: PerkEffect = PerkEffect.YIELD_BONUS
@export var effect_value: float = 0.0       # The bonus value (e.g., 0.10 = +10%)
@export var tier: int = 0                   # Visual tier in the tree (0=root, 1, 2, 3, 4)
@export var icon: Texture2D = null
