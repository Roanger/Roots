extends StaticBody3D
class_name FarmPlot
## A farm plot that can hold and grow crops

signal crop_planted(crop_id: String)
signal crop_harvested(crop_id: String, amount: int)
signal growth_stage_changed(stage: int)
signal watered_changed(is_watered: bool)

enum PlotState {
	EMPTY,
	TILLED,  # Soil prepared but no seed
	PLANTED,
	GROWING,
	READY_FOR_HARVEST
}

# Plot properties
@export var plot_position: Vector3 = Vector3.ZERO
@export var crop_id: String = ""
@export var current_stage: int = 0
@export var stage_progress: float = 0.0  # 0.0 to 1.0 within current stage

# State
var state: PlotState = PlotState.EMPTY
var is_watered: bool = false
var is_fertilized: bool = false

# Visual nodes
@onready var soil_mesh: MeshInstance3D = $SoilMesh
@onready var crop_mesh: MeshInstance3D = $CropMesh
@onready var water_particles: GPUParticles3D = $WaterParticles

# Crop data (loaded from database)
var crop_data: CropData = null

# References
var crop_database: Node = null  # Will be set by FarmManager
var item_database: ItemDatabase = null

func _ready() -> void:
	_update_visuals()

func _process(delta: float) -> void:
	if state == PlotState.GROWING and crop_data:
		_grow(delta)

func _grow(delta: float) -> void:
	var growth_rate = 1.0 / crop_data.growth_time_per_stage
	
	# Watered soil grows faster
	if is_watered:
		growth_rate *= 1.5
	
	stage_progress += delta * growth_rate
	
	if stage_progress >= 1.0:
		stage_progress = 0.0
		current_stage += 1
		
		if current_stage >= crop_data.stages - 1:
			# Crop is ready for harvest
			current_stage = crop_data.stages - 1
			state = PlotState.READY_FOR_HARVEST
			growth_stage_changed.emit(current_stage)
		else:
			growth_stage_changed.emit(current_stage)
		
		_update_visuals()

func till_soil() -> bool:
	if state == PlotState.EMPTY:
		state = PlotState.TILLED
		_update_visuals()
		return true
	return false

func plant_seed(seed_id: String, p_crop_data: CropData) -> bool:
	if state != PlotState.TILLED and state != PlotState.EMPTY:
		return false
	
	if not p_crop_data:
		return false
	
	crop_id = seed_id
	crop_data = p_crop_data
	state = PlotState.GROWING
	current_stage = 0
	stage_progress = 0.0
	
	_update_visuals()
	crop_planted.emit(crop_id)
	return true

func water() -> bool:
	if state == PlotState.EMPTY or state == PlotState.TILLED:
		return false
	
	if not is_watered:
		is_watered = true
		if water_particles:
			water_particles.emitting = true
		_update_visuals()
		watered_changed.emit(true)
		return true
	return false

func harvest() -> Dictionary:
	if state != PlotState.READY_FOR_HARVEST or not crop_data:
		return {}
	
	# Calculate harvest amount
	var amount = randi_range(crop_data.produce_amount_min, crop_data.produce_amount_max)
	
	# Quality bonus if watered
	if is_watered:
		amount = int(amount * 1.2)
	
	# Check for seed return
	var return_seed = randf() < crop_data.seed_return_chance
	
	var result = {
		"produce_id": crop_data.produce_item_id,
		"produce_amount": amount,
		"seed_returned": return_seed,
		"seed_id": crop_id if return_seed else ""
	}
	
	# Reset plot
	state = PlotState.TILLED
	crop_id = ""
	crop_data = null
	current_stage = 0
	stage_progress = 0.0
	is_watered = false
	is_fertilized = false
	
	_update_visuals()
	crop_harvested.emit(result.produce_id, result.produce_amount)
	
	return result

func can_interact() -> bool:
	return state != PlotState.EMPTY

func get_interact_text() -> String:
	match state:
		PlotState.EMPTY:
			return "Till Soil"
		PlotState.TILLED:
			return "Plant Seed"
		PlotState.GROWING, PlotState.PLANTED:
			if is_watered:
				return "Growing..."
			return "Water"
		PlotState.READY_FOR_HARVEST:
			return "Harvest"
	return ""

func on_interact(player: Node) -> void:
	match state:
		PlotState.EMPTY:
			# Try to till - requires hoe
			if player and player.has_method("use_tool"):
				player.use_tool("hoe", self)
		PlotState.TILLED:
			# Try to plant - requires seeds
			if player and player.has_method("select_seed"):
				player.select_seed(self)
		PlotState.GROWING, PlotState.PLANTED:
			# Water the crop
			if player and player.has_method("use_tool"):
				player.use_tool("watering_can", self)
		PlotState.READY_FOR_HARVEST:
			# Harvest
			var result = harvest()
			if player and player.has_method("add_harvest"):
				player.add_harvest(result)

func _update_visuals() -> void:
	# Update soil appearance based on state
	if soil_mesh:
		var mat = StandardMaterial3D.new()
		match state:
			PlotState.EMPTY:
				mat.albedo_color = Color(0.4, 0.3, 0.2)  # Untilled
			PlotState.TILLED:
				mat.albedo_color = Color(0.3, 0.2, 0.15)  # Tilled dark
			_:
				if is_watered:
					mat.albedo_color = Color(0.25, 0.18, 0.12)  # Wet dark
				else:
					mat.albedo_color = Color(0.35, 0.25, 0.18)  # Dry tilled
		soil_mesh.material_override = mat
	
	# Update crop visual
	if crop_mesh:
		if state == PlotState.GROWING or state == PlotState.READY_FOR_HARVEST:
			crop_mesh.visible = true
			# Scale based on growth stage
			var growth_scale = float(current_stage + 1) / float(crop_data.stages if crop_data else 4)
			crop_mesh.scale = Vector3.ONE * max(0.3, growth_scale)
		else:
			crop_mesh.visible = false

func get_save_data() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"crop_id": crop_id,
		"current_stage": current_stage,
		"stage_progress": stage_progress,
		"state": state,
		"is_watered": is_watered,
		"is_fertilized": is_fertilized
	}

func load_from_data(data: Dictionary, p_crop_database: Node) -> void:
	crop_id = data.get("crop_id", "")
	current_stage = data.get("current_stage", 0)
	stage_progress = data.get("stage_progress", 0.0)
	state = data.get("state", PlotState.EMPTY)
	is_watered = data.get("is_watered", false)
	is_fertilized = data.get("is_fertilized", false)
	
	if crop_database and crop_id:
		crop_data = crop_database.get_crop(crop_id)
	
	_update_visuals()
