extends Resource
class_name AnimalData
## Defines a species of animal and its properties

enum AnimalType { FARM, WILD, HUNTABLE }
enum ProductType { NONE, EGG, MILK, WOOL }

# Identity
@export var species_id: String = ""
@export var display_name: String = ""
@export var animal_type: AnimalType = AnimalType.FARM

# Model
@export var model_path: String = ""
@export var model_scale: float = 1.0
@export var body_color: Color = Color.WHITE

# Stats
@export var max_health: float = 20.0
@export var move_speed: float = 1.5
@export var flee_speed: float = 4.0
@export var wander_radius: float = 8.0
@export var detection_range: float = 6.0  # Range at which animal detects threats

# Predator
@export var is_predator: bool = false
@export var prey_species: Array = []  # species_ids this predator hunts
@export var attack_damage: float = 5.0
@export var attack_cooldown: float = 3.0      # Seconds between attacks
@export var hunt_speed_mult: float = 1.5      # Speed multiplier when hunting

# Grazing
@export var can_graze: bool = false           # Can graze on grassy terrain
@export var graze_hunger_reduction: float = 0.3  # Hunger reduction per graze cycle
@export var graze_biomes: Array = []     # Biome IDs where this animal grazes (e.g., [2, 3, 8])

# Collision
@export var collision_radius: float = 0.4
@export var collision_height: float = 1.0

# Products (farm animals)
@export var product_type: ProductType = ProductType.NONE
@export var product_item_id: String = ""       # Item ID of the product
@export var product_interval: float = 120.0    # Seconds between product yields
@export var product_amount: int = 1

# Feeding
@export var feed_item_ids: Array = []  # Item IDs this animal eats
@export var hunger_rate: float = 0.005         # Hunger per second (0-1 scale)
@export var happiness_from_feed: float = 0.3   # Happiness gained per feeding

# Loot (when killed/hunted)
@export var loot_table: Array = []  # [{ "item_id": String, "min_amount": int, "max_amount": int, "chance": float }]
@export var xp_reward: float = 10.0
@export var xp_skill: String = "husbandry"

# Breeding
@export var breed_cooldown: float = 300.0      # Seconds between breeding
@export var baby_grow_time: float = 180.0      # Seconds for baby to become adult
@export var baby_scale: float = 0.5
