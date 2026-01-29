extends Resource
class_name CropData
## Defines a type of crop that can be grown

@export var crop_id: String = ""
@export var crop_name: String = ""
@export var description: String = ""

# Growth stages
@export var stages: int = 4  # Number of growth stages
@export var stage_textures: Array[Texture2D] = []  # Visual for each stage
@export var growth_time_per_stage: float = 30.0  # Seconds per stage

# Harvest info
@export var produce_item_id: String = ""  # What item is harvested
@export var produce_amount_min: int = 1
@export var produce_amount_max: int = 3
@export var seed_return_chance: float = 0.5  # Chance to get seed back

# Requirements
@export var requires_water: bool = true
@export var can_grow_in_seasons: Array[String] = ["spring", "summer", "fall"]

# Quality modifiers
@export var quality_bonus_on_watered: float = 0.2

func get_growth_progress(current_stage: int, stage_progress: float) -> float:
	# Returns 0.0 to 1.0 overall growth progress
	var total_stages = float(stages)
	return (float(current_stage) + stage_progress) / total_stages

func get_stage_texture(stage: int) -> Texture2D:
	if stage >= 0 and stage < stage_textures.size():
		return stage_textures[stage]
	return null
