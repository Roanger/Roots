extends Node
class_name PlayerFarming
## Handles all farming-related player interactions (tilling, planting, watering, harvesting)

var player: Node = null
var inventory: Inventory = null
var item_database: ItemDatabase = null
var crop_database: CropDatabase = null
var skill_manager: Node = null

func initialize(p_player: Node, p_inventory: Inventory, p_item_database: ItemDatabase, p_crop_database: CropDatabase) -> void:
	player = p_player
	inventory = p_inventory
	item_database = p_item_database
	crop_database = p_crop_database
	skill_manager = Engine.get_singleton("SkillManager") if Engine.has_singleton("SkillManager") else null
	if not skill_manager:
		skill_manager = p_player.get_node_or_null("/root/SkillManager")

func handle_farm_plot_interaction(plot: FarmPlot) -> void:
	match plot.state:
		FarmPlot.PlotState.EMPTY:
			# Use hoe to till
			use_tool("hoe", plot)
		FarmPlot.PlotState.TILLED:
			# Plant seed (use first available)
			var seeds = get_available_seeds()
			if seeds.size() > 0:
				plant_seed(plot, seeds[0])
		FarmPlot.PlotState.GROWING, FarmPlot.PlotState.PLANTED:
			# Water if not watered
			if not plot.is_watered:
				use_tool("watering_can", plot)
		FarmPlot.PlotState.READY_FOR_HARVEST:
			# Harvest with sickle
			use_tool("sickle", plot)

func use_tool(tool_type: String, target: Node) -> bool:
	match tool_type:
		"hoe":
			if target is FarmPlot:
				var success = target.till_soil()
				if success and skill_manager:
					skill_manager.grant_action_xp("till_soil")
				return success
		"watering_can":
			if target is FarmPlot:
				var success = target.water()
				if success and skill_manager:
					skill_manager.grant_action_xp("water_crop")
				return success
		"sickle":
			if target is FarmPlot and target.state == FarmPlot.PlotState.READY_FOR_HARVEST:
				var result = target.harvest()
				add_harvest(result)
				if skill_manager:
					skill_manager.grant_action_xp("harvest_crop")
				return true
	return false

func plant_seed(plot: FarmPlot, seed_id: String) -> bool:
	if not crop_database or not inventory:
		return false
	
	# Check if player has seeds
	if not inventory.has_item(seed_id, 1):
		return false
	
	# Get crop data from seed
	var crop_data = crop_database.get_crop_from_seed(seed_id)
	if not crop_data:
		return false
	
	# Try to plant
	if plot.plant_seed(seed_id, crop_data):
		# Remove one seed from inventory
		inventory.remove_item(seed_id, 1)
		if skill_manager:
			skill_manager.grant_action_xp("plant_seed")
		return true
	
	return false

func add_harvest(result: Dictionary) -> void:
	if result.is_empty():
		return
	
	var produce_id = result.get("produce_id", "")
	var produce_amount = result.get("produce_amount", 0)
	var seed_returned = result.get("seed_returned", false)
	var seed_id = result.get("seed_id", "")
	
	# Add produce
	if produce_id and produce_amount > 0:
		var overflow = add_item_to_inventory(produce_id, produce_amount)
		if overflow > 0:
			print("Inventory full! Dropped ", overflow, " ", produce_id)
	
	# Return seed
	if seed_returned and seed_id:
		add_item_to_inventory(seed_id, 1)

func add_item_to_inventory(item_id: String, quantity: int = 1) -> int:
	if not item_database or not inventory:
		return quantity
	
	var item_data = item_database.get_item(item_id)
	if not item_data:
		return quantity
	
	return inventory.add_item(item_data, quantity)

func can_plant_seed(plot: FarmPlot) -> bool:
	return plot.state == FarmPlot.PlotState.TILLED or plot.state == FarmPlot.PlotState.EMPTY

func get_available_seeds() -> Array[String]:
	var seeds: Array[String] = []
	if not inventory:
		return seeds
	
	for i in range(inventory.max_slots):
		var item = inventory.get_slot(i)
		if item and item.item_data and item.item_data.item_type == ItemData.ItemType.SEED:
			seeds.append(item.item_data.item_id)
	
	return seeds
