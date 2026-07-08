extends Control
class_name CraftingUI
## Crafting menu UI: shows available recipes, ingredients, and allows crafting.
## Toggle with C key. Built entirely in code.

const RecipeDataScript = preload("res://src/crafting/recipe_data.gd")

signal item_crafted(recipe_id: String)

var inventory: Inventory = null
var recipe_database: Node = null
var item_database: Node = null
var current_station: int = CraftingRecipe.CraftingStation.HAND
var selected_recipe: CraftingRecipe = null
var _crafting_timer: float = 0.0
var _is_crafting: bool = false

# UI references
var _panel: PanelContainer
var _title_label: Label
var _close_button: Button
var _category_container: HBoxContainer
var _recipe_list: VBoxContainer
var _recipe_scroll: ScrollContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_desc: Label
var _ingredients_container: VBoxContainer
var _output_container: HBoxContainer
var _craft_button: Button
var _craft_all_button: Button
var _progress_bar: ProgressBar
var _category_buttons: Dictionary = {}
var _craft_queue: int = 0  # Remaining crafts in a Craft All batch

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("crafting_ui")
	_build_ui()
	_center_panel()

func initialize(inv: Inventory) -> void:
	inventory = inv
	recipe_database = get_node_or_null("/root/RecipeDatabase")
	item_database = get_node_or_null("/root/ItemDatabase")
	_refresh_recipes()

func _build_ui() -> void:
	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 500)
	_panel.size = Vector2(700, 500)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)
	
	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	_title_label = Label.new()
	_title_label.text = "Crafting"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(30, 30)
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)
	
	# Category tabs
	_category_container = HBoxContainer.new()
	_category_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_category_container)
	
	var categories = ["All", "Materials", "Tools", "Weapons", "Armor", "Food", "Potions", "Building", "Misc"]
	for i in range(categories.size()):
		var btn = Button.new()
		btn.text = categories[i]
		btn.custom_minimum_size = Vector2(70, 28)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_category_pressed.bind(i))
		_category_container.add_child(btn)
		_category_buttons[i] = btn
	
	# Content split: recipe list (left) + details (right)
	var content_split = HSplitContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.split_offset = 280
	main_vbox.add_child(content_split)
	
	# Left: recipe list
	var left_panel = PanelContainer.new()
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	left_style.set_corner_radius_all(4)
	left_style.set_content_margin_all(4)
	left_panel.add_theme_stylebox_override("panel", left_style)
	content_split.add_child(left_panel)
	
	_recipe_scroll = ScrollContainer.new()
	_recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_recipe_scroll)
	
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 2)
	_recipe_scroll.add_child(_recipe_list)
	
	# Right: recipe details
	_detail_panel = PanelContainer.new()
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	detail_style.set_corner_radius_all(4)
	detail_style.set_content_margin_all(10)
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	content_split.add_child(_detail_panel)
	
	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(detail_vbox)
	
	_detail_name = Label.new()
	_detail_name.text = "Select a recipe"
	_detail_name.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(_detail_name)
	
	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_vbox.add_child(_detail_desc)
	
	# Separator
	var sep = HSeparator.new()
	detail_vbox.add_child(sep)
	
	# Skill requirement label (hidden if no requirement)
	var skill_req_label = Label.new()
	skill_req_label.name = "SkillRequirementLabel"
	skill_req_label.add_theme_font_size_override("font_size", 14)
	skill_req_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	detail_vbox.add_child(skill_req_label)
	
	# Ingredients label
	var ing_label = Label.new()
	ing_label.text = "Ingredients:"
	ing_label.add_theme_font_size_override("font_size", 15)
	detail_vbox.add_child(ing_label)
	
	_ingredients_container = VBoxContainer.new()
	_ingredients_container.add_theme_constant_override("separation", 4)
	detail_vbox.add_child(_ingredients_container)
	
	# Separator
	var sep2 = HSeparator.new()
	detail_vbox.add_child(sep2)
	
	# Output
	var out_label = Label.new()
	out_label.text = "Output:"
	out_label.add_theme_font_size_override("font_size", 15)
	detail_vbox.add_child(out_label)
	
	_output_container = HBoxContainer.new()
	_output_container.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(_output_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(spacer)
	
	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.value = 0
	_progress_bar.visible = false
	detail_vbox.add_child(_progress_bar)
	
	# Craft buttons row
	var craft_row = HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 6)
	detail_vbox.add_child(craft_row)
	
	_craft_button = Button.new()
	_craft_button.text = "Craft"
	_craft_button.custom_minimum_size = Vector2(0, 40)
	_craft_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_button.disabled = true
	_craft_button.pressed.connect(_on_craft_pressed)
	craft_row.add_child(_craft_button)
	
	_craft_all_button = Button.new()
	_craft_all_button.text = "Craft All"
	_craft_all_button.custom_minimum_size = Vector2(0, 40)
	_craft_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_all_button.disabled = true
	_craft_all_button.pressed.connect(_on_craft_all_pressed)
	craft_row.add_child(_craft_all_button)

func _process(delta: float) -> void:
	if not visible:
		return
	if _is_crafting:
		_crafting_timer -= delta
		if _crafting_timer <= 0:
			_finish_crafting()
		else:
			_progress_bar.value = (1.0 - _crafting_timer / selected_recipe.crafting_time) * 100.0

func show_crafting(station: int = CraftingRecipe.CraftingStation.HAND) -> void:
	current_station = station
	var station_names = ["Hand Crafting", "Workbench", "Forge", "Anvil", "Cooking Fire", "Alchemy Table", "Loom", "Sawmill"]
	if station < station_names.size():
		_title_label.text = station_names[station]
	visible = true
	_center_panel()
	_refresh_recipes()
	
	# Release mouse so player can interact with UI
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if not get_tree().paused:
		get_tree().paused = true

func _refresh_recipes(category_filter: int = -1) -> void:
	# Clear old entries
	for child in _recipe_list.get_children():
		child.queue_free()
	
	if not recipe_database:
		return
	
	var all_recipes: Array = recipe_database.get_all_recipes()
	
	for recipe in all_recipes:
		# Filter by station: show HAND recipes always, plus current station
		if recipe.station != CraftingRecipe.CraftingStation.HAND and recipe.station != current_station:
			continue
		
		# Filter by category
		if category_filter > 0 and recipe.category != (category_filter - 1):
			continue
		
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Check skill requirement
		var meets_skill = _meets_skill_requirement(recipe)
		var can_craft = (meets_skill and recipe.has_ingredients(inventory)) if inventory else false
		
		var indicator = "● " if can_craft else "○ "
		var skill_text = ""
		if not meets_skill:
			skill_text = " [Req: %s Lv.%d]" % [_get_skill_display_name(recipe.required_skill), recipe.required_skill_level]
		btn.text = indicator + recipe.recipe_name + skill_text
		
		if can_craft:
			btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		elif not meets_skill:
			btn.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		
		btn.pressed.connect(_on_recipe_selected.bind(recipe))
		_recipe_list.add_child(btn)

func _on_recipe_selected(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	_update_detail_panel()

func _update_detail_panel() -> void:
	if not selected_recipe:
		return
	
	_detail_name.text = selected_recipe.recipe_name
	_detail_desc.text = selected_recipe.description
	
	# Update skill requirement label
	var skill_req_label = _detail_panel.find_child("SkillRequirementLabel", true, false)
	if skill_req_label:
		var meets_skill = _meets_skill_requirement(selected_recipe)
		if selected_recipe.required_skill != "" and selected_recipe.required_skill_level > 0:
			var skill_name = _get_skill_display_name(selected_recipe.required_skill)
			var player_level = 0
			var sm = get_node_or_null("/root/SkillManager")
			if sm and sm.has_method("get_skill_level"):
				player_level = sm.get_skill_level(selected_recipe.required_skill)
			skill_req_label.text = "Requires: %s Lv.%d  (You: %d)" % [skill_name, selected_recipe.required_skill_level, player_level]
			skill_req_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if meets_skill else Color(1.0, 0.3, 0.3))
			skill_req_label.visible = true
		else:
			skill_req_label.visible = false
	
	# Clear ingredients
	for child in _ingredients_container.get_children():
		child.queue_free()
	
	# Show ingredients
	for ingredient in selected_recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var amount: int = ingredient.get("amount", 1)
		var item_data: ItemData = item_database.get_item(item_id) if item_database else null
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		_ingredients_container.add_child(hbox)
		
		# Icon
		if item_data and item_data.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = item_data.icon
			icon_rect.custom_minimum_size = Vector2(24, 24)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			hbox.add_child(icon_rect)
		
		# Name + count
		var label = Label.new()
		var display_name = item_data.item_name if item_data else item_id
		var have_count = inventory.get_item_count(item_id) if inventory else 0
		var has_enough = have_count >= amount
		
		label.text = "%s  %d/%d" % [display_name, have_count, amount]
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if has_enough else Color(1.0, 0.3, 0.3))
		hbox.add_child(label)
	
	# Clear output
	for child in _output_container.get_children():
		child.queue_free()
	
	# Show output
	var output_data: ItemData = item_database.get_item(selected_recipe.output_item_id) if item_database else null
	if output_data:
		if output_data.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = output_data.icon
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			_output_container.add_child(icon_rect)
		
		var out_label = Label.new()
		out_label.text = "%s x%d" % [output_data.item_name, selected_recipe.output_amount]
		out_label.add_theme_font_size_override("font_size", 16)
		_output_container.add_child(out_label)
	
	# Update craft buttons
	var meets_skill = _meets_skill_requirement(selected_recipe)
	var has_mats = selected_recipe.has_ingredients(inventory) if inventory else false
	var can_craft = meets_skill and has_mats
	_craft_button.disabled = not can_craft or _is_crafting
	
	if not meets_skill:
		_craft_button.text = "Requires Higher Level"
	elif not has_mats:
		_craft_button.text = "Missing Ingredients"
	elif _is_crafting:
		_craft_button.text = "Crafting..."
	else:
		_craft_button.text = "Craft"
	
	var max_count = _get_max_craftable(selected_recipe)
	_craft_all_button.disabled = max_count < 2 or _is_crafting
	_craft_all_button.text = "Craft All (%d)" % max_count if max_count >= 2 else "Craft All"
	if _is_crafting and _craft_queue > 0:
		_craft_all_button.text = "Crafting... (%d left)" % _craft_queue

func _on_craft_pressed() -> void:
	if not selected_recipe or _is_crafting:
		return
	if not _meets_skill_requirement(selected_recipe):
		return
	if not selected_recipe.has_ingredients(inventory):
		return
	
	_craft_queue = 0
	_start_crafting()

func _on_craft_all_pressed() -> void:
	if not selected_recipe or _is_crafting:
		return
	if not _meets_skill_requirement(selected_recipe):
		return
	var max_count = _get_max_craftable(selected_recipe)
	if max_count < 1:
		return
	
	_craft_queue = max_count - 1  # First craft starts immediately
	_start_crafting()

func _start_crafting() -> void:
	_is_crafting = true
	_crafting_timer = selected_recipe.crafting_time
	_progress_bar.visible = true
	_progress_bar.value = 0
	_craft_button.disabled = true
	_craft_button.text = "Crafting..."
	_craft_all_button.disabled = true
	if _craft_queue > 0:
		_craft_all_button.text = "Crafting... (%d left)" % _craft_queue

func _get_max_craftable(recipe: CraftingRecipe) -> int:
	if not recipe or not inventory:
		return 0
	var max_possible := 999
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var amount: int = ingredient.get("amount", 1)
		if amount <= 0:
			continue
		var have = inventory.get_item_count(item_id)
		@warning_ignore("integer_division")
		var can_make = have / amount
		max_possible = mini(max_possible, can_make)
	return max_possible

func _finish_crafting() -> void:
	_is_crafting = false
	_progress_bar.visible = false
	_progress_bar.value = 0
	
	if not selected_recipe:
		return
	
	# Check resource saving perk (chance to not consume materials)
	var saved_resources := false
	var sm = get_node_or_null("/root/SkillManager")
	if sm and sm.has_method("get_total_perk_bonus"):
		var save_chance = sm.get_total_perk_bonus(PerkData.PerkEffect.RESOURCE_SAVING)
		if save_chance > 0.0 and randf() < save_chance:
			saved_resources = true
			print("[Crafting] Resource saving perk triggered! Materials preserved.")
	
	# Consume ingredients (unless saved by perk)
	if not saved_resources:
		if not selected_recipe.consume_ingredients(inventory):
			print("[Crafting] Failed to consume ingredients!")
			_update_detail_panel()
			return
	
	# Give output item
	if item_database:
		var output_item = item_database.get_item(selected_recipe.output_item_id)
		if output_item:
			inventory.add_item(output_item, selected_recipe.output_amount)
			print("[Crafting] Crafted %s x%d" % [output_item.item_name, selected_recipe.output_amount])
	
	# Grant XP
	if selected_recipe.xp_skill != "" and selected_recipe.xp_amount > 0:
		var skill_manager = get_node_or_null("/root/SkillManager")
		if skill_manager and skill_manager.has_method("grant_xp"):
			skill_manager.grant_xp(selected_recipe.xp_skill, int(selected_recipe.xp_amount))
	
	emit_signal("item_crafted", selected_recipe.recipe_id)
	
	# Notify EventBus for quest tracking
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.crafting_completed.emit(selected_recipe.recipe_id, {"item_id": selected_recipe.output_item_id, "amount": selected_recipe.output_amount})
	
	# Continue queue if Craft All is active
	if _craft_queue > 0 and selected_recipe and selected_recipe.has_ingredients(inventory):
		_craft_queue -= 1
		_start_crafting()
		_refresh_recipes()
		_update_detail_panel()
		return
	
	_craft_queue = 0
	
	# Refresh UI
	_refresh_recipes()
	_update_detail_panel()

func _on_category_pressed(category_index: int) -> void:
	# Unpress all other buttons
	for idx in _category_buttons:
		_category_buttons[idx].button_pressed = (idx == category_index)
	
	# -1 means "All", otherwise map to RecipeCategory enum
	var filter = -1 if category_index == 0 else category_index
	_refresh_recipes(filter)

func close() -> void:
	visible = false
	_is_crafting = false
	_craft_queue = 0
	_progress_bar.visible = false
	
	# Check if other UIs are open before recapturing mouse
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	var character_ui = get_tree().get_first_node_in_group("character_ui")
	var skill_tree_ui = get_tree().get_first_node_in_group("skill_tree_ui")
	var other_ui_open = (inventory_ui and inventory_ui.visible) or (character_ui and character_ui.visible) or (skill_tree_ui and skill_tree_ui.visible)
	
	if not other_ui_open:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("capture_mouse"):
			player.capture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false

func _on_close_pressed() -> void:
	close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _center_panel() -> void:
	if not _panel:
		return
	var viewport_size = get_viewport_rect().size
	_panel.position = (viewport_size - _panel.size) / 2.0

func _meets_skill_requirement(recipe: CraftingRecipe) -> bool:
	if recipe.required_skill == "" or recipe.required_skill_level <= 0:
		return true
	var sm = get_node_or_null("/root/SkillManager")
	if not sm:
		return true
	if not sm.has_method("get_skill_level"):
		return true
	return sm.get_skill_level(recipe.required_skill) >= recipe.required_skill_level

func _get_skill_display_name(skill_id: String) -> String:
	if skill_id == "":
		return ""
	var sm = get_node_or_null("/root/SkillManager")
	if not sm or not sm.has_method("get_skill_definition"):
		return skill_id.capitalize()
	var def = sm.get_skill_definition(skill_id)
	if def and def.has_method("get_display_name"):
		return def.display_name
	return skill_id.capitalize()
