extends Control
class_name ShopUI
## Trading/Shop UI for NPC merchants.
## Shows items the NPC sells with buy/sell prices.
## Player can buy items if they have enough gold.

var _npc: Node = null  # BaseNPC
var _player: Node3D = null
var _shop_items: Array = []

# UI elements
var _panel: PanelContainer = null
var _title_label: Label = null
var _items_container: VBoxContainer = null
var _gold_label: Label = null
var _close_button: Button = null
var _scroll: ScrollContainer = null

signal shop_closed()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Center panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 450)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -250
	_panel.offset_right = 250
	_panel.offset_top = -225
	_panel.offset_bottom = 225

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(_gold_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.4, 0.35, 0.25))
	vbox.add_child(sep)

	# Column headers
	var col_header = HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 8)
	vbox.add_child(col_header)

	var item_header = Label.new()
	item_header.text = "Item"
	item_header.add_theme_font_size_override("font_size", 14)
	item_header.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	item_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_header.add_child(item_header)

	var price_header = Label.new()
	price_header.text = "Price"
	price_header.add_theme_font_size_override("font_size", 14)
	price_header.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	price_header.custom_minimum_size.x = 60
	col_header.add_child(price_header)

	var action_header = Label.new()
	action_header.text = ""
	action_header.custom_minimum_size.x = 70
	col_header.add_child(action_header)

	# Scrollable item list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 4)
	_scroll.add_child(_items_container)

	# Close button
	_close_button = Button.new()
	_close_button.text = "Close Shop"
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.pressed.connect(close)
	vbox.add_child(_close_button)

func open(npc: Node, player: Node3D) -> void:
	_npc = npc
	_player = player

	if npc.npc_data:
		_title_label.text = npc.npc_data.display_name + "'s Shop"
		_shop_items = npc.npc_data.shop_inventory
	else:
		_title_label.text = "Shop"
		_shop_items = []

	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_items()

func close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _npc and _npc.has_method("end_conversation"):
		_npc.end_conversation()
	_npc = null
	_player = null
	shop_closed.emit()

func _refresh_items() -> void:
	# Clear old items
	for child in _items_container.get_children():
		child.queue_free()

	# Update gold display
	var gold = _get_player_gold()
	_gold_label.text = "Gold: %d" % gold

	var item_db = get_node_or_null("/root/ItemDatabase")

	for shop_entry in _shop_items:
		var item_id: String = shop_entry.get("item_id", "")
		var buy_price: int = shop_entry.get("buy_price", 10)
		var stock: int = shop_entry.get("stock", -1)  # -1 = unlimited

		# Get item display name from database
		var item_name = item_id.replace("_", " ").capitalize()
		if item_db and item_db.has_method("get_item"):
			var item_data = item_db.get_item(item_id)
			if item_data:
				item_name = item_data.item_name

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Item name
		var name_label = Label.new()
		name_label.text = item_name
		if stock > 0:
			name_label.text += " (x%d)" % stock
		elif stock == 0:
			name_label.text += " (SOLD OUT)"
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Price
		var price_label = Label.new()
		price_label.text = "%d g" % buy_price
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		price_label.custom_minimum_size.x = 60
		row.add_child(price_label)

		# Buy button
		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.add_theme_font_size_override("font_size", 13)
		buy_btn.custom_minimum_size.x = 70
		buy_btn.disabled = (gold < buy_price) or (stock == 0)
		buy_btn.pressed.connect(_on_buy.bind(shop_entry))
		row.add_child(buy_btn)

		_items_container.add_child(row)

func _on_buy(shop_entry: Dictionary) -> void:
	var item_id: String = shop_entry.get("item_id", "")
	var buy_price: int = shop_entry.get("buy_price", 10)
	var stock: int = shop_entry.get("stock", -1)

	var gold = _get_player_gold()
	if gold < buy_price:
		return
	if stock == 0:
		return

	# Deduct gold
	if _player and _player.get("inventory"):
		_player.inventory.remove_item("gold_coin", buy_price)

	# Reduce stock if not unlimited
	if stock > 0:
		shop_entry["stock"] = stock - 1

	# Add item to player inventory
	var item_db = get_node_or_null("/root/ItemDatabase")
	if item_db and _player and _player.get("inventory"):
		var item_data = item_db.get_item(item_id)
		if item_data:
			_player.inventory.add_item(item_data, 1)

	_refresh_items()
	print("[Shop] Player bought %s for %d gold" % [item_id, buy_price])

func _get_player_gold() -> int:
	if _player and _player.get("inventory"):
		var inv = _player.inventory
		if inv.has_method("get_item_count"):
			return inv.get_item_count("gold_coin")
	return 0

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
