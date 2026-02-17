extends Node
## Registers all quest definitions into the QuestManager.
## Called once at startup from main_world.gd.

var OT = QuestData.ObjectiveType

func register_all_quests(qm: Node) -> void:
	_register_main_quests(qm)
	_register_gathering_chain(qm)
	_register_farming_chain(qm)
	_register_combat_chain(qm)
	_register_crafting_chain(qm)
	_register_cooking_chain(qm)
	_register_alchemy_chain(qm)
	_register_animal_chain(qm)
	_register_side_quests(qm)

# =====================
# HELPER
# =====================

func _q(id: String, qname: String, desc: String, giver: String, turnin: String,
		objectives: Array, rewards_xp: Dictionary = {}, rewards_items: Array = [],
		rewards_gold: int = 0, prereqs: Array = [], unlock: Array = [],
		offer: String = "", progress: String = "", done: String = "", turnin_txt: String = "",
		chain: String = "", chain_order: int = 0, category: String = "main") -> QuestData:
	var quest = QuestData.new()
	quest.quest_id = id
	quest.quest_name = qname
	quest.description = desc
	quest.category = category
	quest.giver_npc_id = giver
	quest.turnin_npc_id = turnin
	quest.objectives = objectives
	quest.reward_xp = rewards_xp
	quest.reward_items = rewards_items
	quest.reward_gold = rewards_gold
	quest.required_quests = prereqs
	quest.reward_unlock_quests = unlock
	quest.offer_text = offer
	quest.in_progress_text = progress
	quest.complete_text = done
	quest.turnin_text = turnin_txt
	quest.chain_id = chain
	quest.chain_order = chain_order
	return quest

func _obj(type: int, text: String, target: int, filter: String = "") -> Dictionary:
	return { "type": type, "text": text, "target": target, "filter": filter }

# =====================
# MAIN STORY QUESTS
# =====================

func _register_main_quests(qm: Node) -> void:
	# Welcome quest — auto-available on game start
	qm.register_quest(_q(
		"welcome", "Welcome to the Village",
		"You've arrived at a small village. Speak with the Village Elder to get started.",
		"", "mayor",
		[_obj(OT.TALK_TO_NPC, "Talk to Village Elder Aldric", 1, "mayor")],
		{}, [], 0, [], ["gather_supplies", "first_harvest", "skeleton_threat"],
		"", "", "", "Welcome, traveler! I'm Aldric, the village elder. We could use your help around here.",
		"main", 0
	))
	
	# Elara's introduction — unlocked after welcome
	qm.register_quest(_q(
		"meet_elara", "Meet the Shopkeeper",
		"Aldric mentioned Elara runs the general store. Pay her a visit.",
		"mayor", "shopkeeper",
		[_obj(OT.TALK_TO_NPC, "Talk to Elara at the General Store", 1, "shopkeeper")],
		{}, [{"item_id": "torch", "amount": 2}], 5, ["welcome"], ["elara_errand"],
		"You should introduce yourself to Elara — she runs the general store. She'll have supplies you need.",
		"Have you met Elara yet?",
		"Good, you've met her!",
		"Welcome to my shop! Here, take these torches — you'll need them when it gets dark.",
		"main", 1
	))
	
	# Elara's errand — fetch wood for her
	qm.register_quest(_q(
		"elara_errand", "Elara's Errand",
		"Elara needs some wood planks for repairs. Craft some for her.",
		"shopkeeper", "shopkeeper",
		[_obj(OT.COLLECT_ITEM, "Bring 10 Wood Planks", 10, "wood_plank")],
		{"lumberjack": 15}, [], 15, ["meet_elara"], [],
		"I could really use some wood planks for repairs. Could you bring me 10?",
		"Still working on those planks?",
		"You got them all! Wonderful!",
		"These are perfect, thank you! Here's some coin for your trouble.",
		"main", 2
	))

# =====================
# GATHERING CHAIN
# =====================

func _register_gathering_chain(qm: Node) -> void:
	# Gather Supplies — starter, auto-available after welcome
	qm.register_quest(_q(
		"gather_supplies", "Gather Supplies",
		"Collect basic resources to get started in the village.",
		"mayor", "",
		[
			_obj(OT.COLLECT_ITEM, "Collect Wood", 5, "wood_log"),
			_obj(OT.COLLECT_ITEM, "Collect Stone", 5, "stone"),
		],
		{"foraging": 10}, [], 5, ["welcome"], ["resourceful"],
		"We need supplies. Gather some wood and stone to help the village.",
		"Keep gathering — we need those resources!",
		"", "",
		"gathering", 0
	))
	
	# Resourceful — gather more advanced materials
	qm.register_quest(_q(
		"resourceful", "Resourceful",
		"The village needs more materials. Gather copper and coal from the mines.",
		"mayor", "mayor",
		[
			_obj(OT.COLLECT_ITEM, "Collect Copper Nuggets", 5, "copper_nugget"),
			_obj(OT.COLLECT_ITEM, "Collect Coal", 5, "coal"),
		],
		{"mining": 20}, [{"item_id": "copper_ingot", "amount": 2}], 10, ["gather_supplies"], ["lumberjack_work"],
		"Now that you have the basics, we need copper and coal from the mines.",
		"The mines should have what we need.",
		"Excellent work, miner!",
		"These will be very useful. Tormund the blacksmith will be pleased.",
		"gathering", 1
	))
	
	# Lumberjack's Work — chop trees
	qm.register_quest(_q(
		"lumberjack_work", "Lumberjack's Work",
		"The village needs lumber. Chop down trees to supply wood.",
		"mayor", "mayor",
		[
			_obj(OT.CHOP_RESOURCE, "Chop Down Trees", 10, ""),
			_obj(OT.COLLECT_ITEM, "Collect Sticks", 20, "stick"),
		],
		{"lumberjack": 25}, [], 15, ["resourceful"], [],
		"We're running low on lumber. Can you chop some trees for us?",
		"Keep chopping! We need that wood.",
		"That's plenty of lumber!",
		"The village thanks you for your hard work.",
		"gathering", 2
	))

# =====================
# FARMING CHAIN
# =====================

func _register_farming_chain(qm: Node) -> void:
	# First Harvest — starter
	qm.register_quest(_q(
		"first_harvest", "First Harvest",
		"Try your hand at farming. Till some soil and plant your first crop.",
		"", "",
		[
			_obj(OT.TILL_SOIL, "Till a plot of soil", 1, ""),
			_obj(OT.PLANT_CROP, "Plant a crop", 1, ""),
		],
		{"cultivation": 10}, [{"item_id": "carrot_seed", "amount": 3}], 0, ["welcome"], ["green_thumb"],
		"", "", "", "",
		"farming", 0
	))
	
	# Green Thumb — expand the farm
	qm.register_quest(_q(
		"green_thumb", "Green Thumb",
		"Expand your farm. Plant and harvest multiple crops.",
		"farmer", "farmer",
		[
			_obj(OT.TILL_SOIL, "Till 5 plots", 5, ""),
			_obj(OT.PLANT_CROP, "Plant 5 crops", 5, ""),
			_obj(OT.HARVEST_CROP, "Harvest 3 crops", 3, ""),
		],
		{"cultivation": 25}, [{"item_id": "potato_seed", "amount": 5}], 10, ["first_harvest"], ["bountiful_harvest"],
		"So you've started farming! Good. Let me teach you a thing or two.",
		"Keep at it — farming takes patience.",
		"You're a natural!",
		"Here are some potato seeds. Try growing those next!",
		"farming", 1
	))
	
	# Bountiful Harvest — large-scale farming
	qm.register_quest(_q(
		"bountiful_harvest", "Bountiful Harvest",
		"Prove yourself as a true farmer. Harvest a large crop yield.",
		"farmer", "farmer",
		[
			_obj(OT.HARVEST_CROP, "Harvest 15 crops", 15, ""),
		],
		{"cultivation": 40}, [], 25, ["green_thumb"], [],
		"Think you can handle a real harvest? Show me what you've got.",
		"That's a lot of crops to tend to. Keep going!",
		"Impressive yield!",
		"Now that's what I call a harvest! You've earned your place here.",
		"farming", 2
	))

# =====================
# COMBAT CHAIN
# =====================

func _register_combat_chain(qm: Node) -> void:
	# Skeleton Threat — starter
	qm.register_quest(_q(
		"skeleton_threat", "The Skeleton Threat",
		"Skeletons have been spotted near the village. Defeat them!",
		"", "",
		[_obj(OT.DEFEAT_ENEMY, "Defeat Skeletons", 3, "Skeleton")],
		{"militia": 15}, [{"item_id": "basic_sword", "amount": 1}], 5, ["welcome"], ["undead_menace"],
		"", "", "", "",
		"combat", 0
	))
	
	# Undead Menace — more skeletons
	qm.register_quest(_q(
		"undead_menace", "Undead Menace",
		"The skeleton attacks are getting worse. Captain Rolf needs your help.",
		"guard", "guard",
		[_obj(OT.DEFEAT_ENEMY, "Defeat Skeletons", 10, "Skeleton")],
		{"militia": 30}, [], 20, ["skeleton_threat"], ["champion_of_village"],
		"The undead are growing bolder. We need warriors to push them back.",
		"Keep fighting! Don't let them near the village.",
		"You've driven them back!",
		"Well fought! The village is safer thanks to you.",
		"combat", 1
	))
	
	# Champion — defeat many enemies
	qm.register_quest(_q(
		"champion_of_village", "Champion of the Village",
		"Prove yourself as the village's greatest defender.",
		"guard", "guard",
		[_obj(OT.DEFEAT_ENEMY, "Defeat 25 enemies", 25, "")],
		{"militia": 50}, [{"item_id": "iron_ingot", "amount": 5}], 50, ["undead_menace"], [],
		"You've shown great courage. But the real test is endurance. Can you handle it?",
		"The fight continues. Stay strong.",
		"Incredible! You are truly a champion!",
		"The village owes you a great debt. Take these — you've earned them.",
		"combat", 2
	))

# =====================
# CRAFTING CHAIN
# =====================

func _register_crafting_chain(qm: Node) -> void:
	# Apprentice Crafter
	qm.register_quest(_q(
		"apprentice_crafter", "Apprentice Crafter",
		"Learn the basics of crafting. Make some simple items.",
		"blacksmith", "blacksmith",
		[
			_obj(OT.CRAFT_ITEM, "Craft Wooden Planks", 3, "planks_from_log"),
			_obj(OT.CRAFT_ITEM, "Craft Sticks", 2, "sticks_from_planks"),
			_obj(OT.CRAFT_ITEM, "Craft Rope", 1, "rope_from_string"),
		],
		{"crafting": 15}, [], 10, ["gather_supplies"], ["forge_ahead"],
		"Every adventurer needs to know how to craft. Let me show you the basics.",
		"Keep crafting! Practice makes perfect.",
		"You're getting the hang of it!",
		"Good work! You're ready for more advanced crafting.",
		"crafting", 0, "side"
	))
	
	# Forge Ahead — blacksmithing
	qm.register_quest(_q(
		"forge_ahead", "Forge Ahead",
		"Tormund needs help at the forge. Smelt some ingots.",
		"blacksmith", "blacksmith",
		[
			_obj(OT.CRAFT_ITEM, "Smelt Copper Ingots", 3, "copper_ingot"),
			_obj(OT.CRAFT_ITEM, "Craft a Bronze Tool", 1, ""),
		],
		{"blacksmithing": 25}, [{"item_id": "iron_nugget", "amount": 5}], 20, ["apprentice_crafter"], ["master_smith"],
		"The forge is hot and ready. Let's see what you can make!",
		"Smelting takes patience. Keep at it.",
		"Fine work at the forge!",
		"You have a talent for this. Here, some iron to work with next.",
		"crafting", 1, "side"
	))
	
	# Master Smith
	qm.register_quest(_q(
		"master_smith", "Master Smith",
		"Forge iron and steel items to prove your smithing mastery.",
		"blacksmith", "blacksmith",
		[
			_obj(OT.CRAFT_ITEM, "Smelt Iron Ingots", 5, "iron_ingot"),
			_obj(OT.CRAFT_ITEM, "Forge an Iron Weapon", 1, "craft_iron_sword"),
		],
		{"blacksmithing": 50}, [{"item_id": "steel_ingot", "amount": 2}], 40, ["forge_ahead"], [],
		"Ready for the real challenge? Iron and steel require true skill.",
		"The forge awaits your mastery.",
		"A masterwork!",
		"You've earned the title of Master Smith. Well done!",
		"crafting", 2, "side"
	))

# =====================
# COOKING CHAIN
# =====================

func _register_cooking_chain(qm: Node) -> void:
	# Kitchen Helper
	qm.register_quest(_q(
		"kitchen_helper", "Kitchen Helper",
		"Marta needs help in the kitchen. Cook some basic meals.",
		"baker", "baker",
		[
			_obj(OT.COOK_RECIPE, "Cook Meat", 2, "cook_meat"),
			_obj(OT.COOK_RECIPE, "Fry an Egg", 1, "fry_egg"),
		],
		{"cooking": 15}, [{"item_id": "flour", "amount": 5}], 10, ["gather_supplies"], ["bakers_apprentice"],
		"The kitchen could use an extra pair of hands. Can you cook?",
		"Don't burn anything!",
		"Smells delicious!",
		"Not bad at all! Here's some flour — try baking next.",
		"cooking", 0, "side"
	))
	
	# Baker's Apprentice
	qm.register_quest(_q(
		"bakers_apprentice", "Baker's Apprentice",
		"Learn to bake bread and pies from Marta.",
		"baker", "baker",
		[
			_obj(OT.COOK_RECIPE, "Bake Bread", 3, "bake_bread"),
			_obj(OT.COOK_RECIPE, "Bake a Pie", 1, ""),
		],
		{"baking": 25}, [], 20, ["kitchen_helper"], ["master_chef"],
		"Ready to learn the art of baking? It's all about timing.",
		"The oven is waiting!",
		"Perfect golden crust!",
		"You're a natural baker! The village will eat well tonight.",
		"cooking", 1, "side"
	))
	
	# Master Chef
	qm.register_quest(_q(
		"master_chef", "Master Chef",
		"Create the finest dishes in the village.",
		"baker", "baker",
		[
			_obj(OT.COOK_RECIPE, "Cook Hearty Stew", 2, "cook_hearty_stew"),
			_obj(OT.COOK_RECIPE, "Cook Vegetable Soup", 2, "cook_vegetable_soup"),
			_obj(OT.COOK_RECIPE, "Bake Meat Pie", 2, "bake_meat_pie"),
		],
		{"cooking": 40, "baking": 30}, [], 50, ["bakers_apprentice"], [],
		"Think you can handle the finest recipes? Show me what you've got!",
		"The kitchen demands perfection.",
		"A feast fit for a king!",
		"Magnificent! You are truly a master of the kitchen.",
		"cooking", 2, "side"
	))

# =====================
# ALCHEMY CHAIN
# =====================

func _register_alchemy_chain(qm: Node) -> void:
	# Herb Collector
	qm.register_quest(_q(
		"herb_collector", "Herb Collector",
		"Sage Willow needs herbs for her potions. Gather some from the wild.",
		"herbalist", "herbalist",
		[
			_obj(OT.COLLECT_ITEM, "Collect Chamomile", 5, "chamomile"),
			_obj(OT.COLLECT_ITEM, "Collect Mushrooms", 3, "common_mushroom"),
		],
		{"herb_gathering": 15}, [{"item_id": "empty_bottle", "amount": 3}], 10, ["gather_supplies"], ["potion_brewer"],
		"The forest is full of useful herbs. Would you gather some for me?",
		"Look near streams for chamomile, and in shady spots for mushrooms.",
		"These are perfect specimens!",
		"Wonderful! Here are some bottles — try brewing potions yourself.",
		"alchemy", 0, "side"
	))
	
	# Potion Brewer
	qm.register_quest(_q(
		"potion_brewer", "Potion Brewer",
		"Brew your first potions at the Alchemy Table.",
		"herbalist", "herbalist",
		[
			_obj(OT.BREW_POTION, "Brew Health Potions", 2, "brew_health_potion"),
			_obj(OT.BREW_POTION, "Brew Stamina Potions", 2, "brew_stamina_potion"),
		],
		{"alchemy": 25}, [], 20, ["herb_collector"], ["master_alchemist"],
		"Now that you have ingredients, let's see if you can brew potions.",
		"Careful with the measurements!",
		"Well brewed!",
		"You have a steady hand. These potions are excellent quality.",
		"alchemy", 1, "side"
	))
	
	# Master Alchemist
	qm.register_quest(_q(
		"master_alchemist", "Master Alchemist",
		"Master the art of alchemy by brewing advanced potions.",
		"herbalist", "herbalist",
		[
			_obj(OT.BREW_POTION, "Brew Speed Potion", 1, "brew_speed_potion"),
			_obj(OT.BREW_POTION, "Brew Strength Potion", 1, "brew_strength_potion"),
			_obj(OT.BREW_POTION, "Brew Antidote", 1, "brew_antidote"),
		],
		{"alchemy": 50}, [{"item_id": "golden_mushroom", "amount": 3}], 40, ["potion_brewer"], [],
		"Only the most skilled alchemists can brew these advanced potions.",
		"These recipes require rare ingredients. Search carefully.",
		"Remarkable! You've mastered alchemy!",
		"I'm impressed. You've surpassed even my expectations. Take these rare mushrooms.",
		"alchemy", 2, "side"
	))

# =====================
# ANIMAL HUSBANDRY CHAIN
# =====================

func _register_animal_chain(qm: Node) -> void:
	# Animal Friend
	qm.register_quest(_q(
		"animal_friend", "Animal Friend",
		"Old Hank needs help with the farm animals.",
		"farmer", "farmer",
		[
			_obj(OT.COLLECT_ITEM, "Collect Animal Feed", 5, "animal_feed"),
			_obj(OT.COLLECT_ITEM, "Collect Eggs", 3, "egg"),
		],
		{"husbandry": 15}, [], 10, ["first_harvest"], ["shepherd"],
		"The animals need tending. Can you help gather feed and collect eggs?",
		"Check the coops for eggs, and the fields for feed ingredients.",
		"The animals are well fed!",
		"Good work! The animals seem to like you.",
		"animals", 0, "side"
	))
	
	# Shepherd
	qm.register_quest(_q(
		"shepherd", "Shepherd's Duty",
		"Take care of the village's livestock.",
		"farmer", "farmer",
		[
			_obj(OT.COLLECT_ITEM, "Collect Wool", 5, "wool"),
			_obj(OT.COLLECT_ITEM, "Collect Milk", 3, "milk"),
		],
		{"husbandry": 25}, [{"item_id": "animal_feed", "amount": 10}], 20, ["animal_friend"], [],
		"The sheep need shearing and the cows need milking. Can you handle it?",
		"The animals are waiting for you.",
		"Well done, shepherd!",
		"You've got a real knack for this. Here's some extra feed for your own animals.",
		"animals", 1, "side"
	))

# =====================
# SIDE QUESTS (standalone)
# =====================

func _register_side_quests(qm: Node) -> void:
	# Innkeeper's Request
	qm.register_quest(_q(
		"innkeeper_request", "A Warm Welcome",
		"Bram the innkeeper wants to serve a special meal. Help him gather ingredients.",
		"innkeeper", "innkeeper",
		[
			_obj(OT.COLLECT_ITEM, "Bring Cooked Meat", 2, "cooked_meat"),
			_obj(OT.COLLECT_ITEM, "Bring Bread", 2, "bread"),
		],
		{"cooking": 10}, [{"item_id": "health_potion", "amount": 2}], 15, ["gather_supplies"], [],
		"I want to prepare a special feast! But I need some ingredients first.",
		"Still need that meat and bread!",
		"Perfect! The feast will be grand!",
		"Here, take these potions — on the house!",
		"", 0, "side"
	))
	
	# Mining Expedition
	qm.register_quest(_q(
		"mining_expedition", "Mining Expedition",
		"Explore the mines and collect valuable ores.",
		"blacksmith", "blacksmith",
		[
			_obj(OT.MINE_RESOURCE, "Mine 15 rocks", 15, ""),
			_obj(OT.COLLECT_ITEM, "Collect Iron Nuggets", 8, "iron_nugget"),
		],
		{"mining": 30}, [{"item_id": "coal", "amount": 10}], 25, ["resourceful"], [],
		"The deeper mines have iron ore. Bring me what you find.",
		"Keep digging! Iron is down there somewhere.",
		"A fine haul of ore!",
		"Excellent! Here's some coal to smelt those with.",
		"", 0, "side"
	))
