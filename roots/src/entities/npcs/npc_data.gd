extends Resource
class_name NPCData
## Defines an NPC's identity, role, dialogue, and shop inventory.

enum NPCRole { MERCHANT, BLACKSMITH, INNKEEPER, HERBALIST, FARMER, GUARD, QUEST_GIVER }

# Identity
@export var npc_id: String = ""
@export var display_name: String = ""
@export var role: NPCRole = NPCRole.MERCHANT
@export var title: String = ""  # e.g. "General Store Owner"

# Model
@export var model_path: String = ""
@export var model_scale: float = 1.0
@export var body_color: Color = Color(0.7, 0.6, 0.5)  # Placeholder color

# Stats
@export var move_speed: float = 1.0
@export var wander_radius: float = 3.0  # NPCs stay near their post

# Collision
@export var collision_radius: float = 0.35
@export var collision_height: float = 1.6

# Dialogue — array of dialogue entries, each is a Dictionary:
# { "text": String, "choices": [{ "text": String, "next": int, "action": String }] }
# If no choices, dialogue advances linearly. "action" can be "shop", "quest", "close".
@export var greeting_lines: Array = []  # Casual greetings when nearby
@export var dialogue: Array = []        # Full dialogue tree

# Shop inventory — array of item IDs this NPC sells
# { "item_id": String, "buy_price": int, "sell_price": int, "stock": int }
@export var shop_inventory: Array = []

# Quest references — quest IDs this NPC can give
@export var quest_ids: Array = []

# Daily schedule: each entry is { "hour": float, "activity": String, "target_pos": Vector3 }
# Activities: "sleep", "work", "socialize", "idle"
# At the given hour, NPC moves to target_pos and performs the activity.
@export var schedule: Array = []
