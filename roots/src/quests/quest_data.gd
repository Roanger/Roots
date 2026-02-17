extends Resource
class_name QuestData
## Data resource defining a single quest: objectives, rewards, prerequisites, NPC links.

enum QuestStatus { UNAVAILABLE, AVAILABLE, ACTIVE, COMPLETE, TURNED_IN }

enum ObjectiveType {
	COLLECT_ITEM,      # Collect N of item_id
	DEFEAT_ENEMY,      # Defeat N enemies (enemy_filter)
	TALK_TO_NPC,       # Talk to npc_id
	CRAFT_ITEM,        # Craft N of recipe_id
	HARVEST_CROP,      # Harvest N crops (crop_filter)
	TILL_SOIL,         # Till N plots
	PLANT_CROP,        # Plant N crops
	REACH_SKILL_LEVEL, # Reach level N in skill_id
	TAME_ANIMAL,       # Tame N animals (animal_filter)
	COOK_RECIPE,       # Cook N of recipe_id
	BREW_POTION,       # Brew N of recipe_id
	MINE_RESOURCE,     # Mine/destroy N rocks
	CHOP_RESOURCE,     # Chop/destroy N trees
	CUSTOM,            # Custom objective tracked manually
}

# Identity
@export var quest_id: String = ""
@export var quest_name: String = ""
@export var description: String = ""
@export var category: String = "main"  # main, side, daily

# NPC links
@export var giver_npc_id: String = ""    # NPC who gives this quest
@export var turnin_npc_id: String = ""   # NPC to turn in to (empty = auto-complete)

# Prerequisites
@export var required_quests: Array = []  # Quest IDs that must be TURNED_IN first
@export var required_level: Dictionary = {}  # { "skill_id": min_level } — all must be met

# Objectives
@export var objectives: Array = []
# Each objective: {
#   "type": ObjectiveType,
#   "text": String (display text),
#   "target": int (amount needed),
#   "filter": String (item_id, enemy name filter, npc_id, recipe_id, crop_id, skill_id, etc.)
# }

# Rewards
@export var reward_xp: Dictionary = {}       # { "skill_id": amount }
@export var reward_items: Array = []         # [{ "item_id": String, "amount": int }]
@export var reward_gold: int = 0
@export var reward_unlock_quests: Array = [] # Quest IDs to make available on turn-in

# Dialogue
@export var offer_text: String = ""          # NPC dialogue when offering quest
@export var in_progress_text: String = ""    # NPC dialogue while quest is active
@export var complete_text: String = ""       # NPC dialogue when objectives are done
@export var turnin_text: String = ""         # NPC dialogue on turn-in

# Chain
@export var chain_id: String = ""            # Group quests into a chain
@export var chain_order: int = 0             # Order within chain
