extends Node
class_name CropDatabase
## Database for all crop definitions

var crops: Dictionary = {}  # crop_id -> CropData

func _ready() -> void:
	_initialize_crops()

func _initialize_crops() -> void:
	# Wheat
	var wheat = CropData.new()
	wheat.crop_id = "wheat"
	wheat.crop_name = "Wheat"
	wheat.description = "A common grain crop."
	wheat.stages = 4
	wheat.growth_time_per_stage = 30.0
	wheat.produce_item_id = "wheat"
	wheat.produce_amount_min = 2
	wheat.produce_amount_max = 4
	wheat.seed_return_chance = 0.7
	_register_crop(wheat)
	
	# Carrot
	var carrot = CropData.new()
	carrot.crop_id = "carrot"
	carrot.crop_name = "Carrot"
	carrot.description = "An orange root vegetable."
	carrot.stages = 3
	carrot.growth_time_per_stage = 25.0
	carrot.produce_item_id = "carrot"
	carrot.produce_amount_min = 1
	carrot.produce_amount_max = 3
	carrot.seed_return_chance = 0.8
	_register_crop(carrot)
	
	# Potato
	var potato = CropData.new()
	potato.crop_id = "potato"
	potato.crop_name = "Potato"
	potato.description = "A starchy tuber."
	potato.stages = 4
	potato.growth_time_per_stage = 35.0
	potato.produce_item_id = "potato"
	potato.produce_amount_min = 2
	potato.produce_amount_max = 5
	potato.seed_return_chance = 0.75
	_register_crop(potato)
	
	# Tomato
	var tomato = CropData.new()
	tomato.crop_id = "tomato"
	tomato.crop_name = "Tomato"
	tomato.description = "A juicy red fruit."
	tomato.stages = 4
	tomato.growth_time_per_stage = 28.0
	tomato.produce_item_id = "tomato"
	tomato.produce_amount_min = 2
	tomato.produce_amount_max = 4
	tomato.seed_return_chance = 0.6
	_register_crop(tomato)
	
	print("CropDatabase initialized with ", crops.size(), " crops")

func _register_crop(crop: CropData) -> void:
	if crop and not crop.crop_id.is_empty():
		crops[crop.crop_id] = crop

func get_crop(crop_id: String) -> CropData:
	return crops.get(crop_id, null)

func has_crop(crop_id: String) -> bool:
	return crops.has(crop_id)

func get_all_crops() -> Array[CropData]:
	var result: Array[CropData] = []
	result.assign(crops.values())
	return result

func get_crop_from_seed(seed_id: String) -> CropData:
	# Extract crop ID from seed ID (e.g., "wheat_seeds" -> "wheat")
	var crop_id = seed_id.replace("_seeds", "")
	return get_crop(crop_id)
