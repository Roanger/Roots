extends StaticBody3D
class_name FishingSpot
## A fishing spot placed at water surfaces. Requires a fishing rod to catch fish.

@export var catch_time: float = 3.5
@export var cooldown_time: float = 15.0
@export var loot_table: Array[Dictionary] = []

enum State { IDLE, FISHING, COOLDOWN }
var state: int = State.IDLE
var _timer: float = 0.0
var _fishing_player: Node3D = null
var _label: Label3D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_add_collision_shape()
	_add_label()

func _add_collision_shape() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	add_child(col)

func _add_label() -> void:
	_label = Label3D.new()
	_label.name = "FishingLabel"
	_label.text = ""
	_label.font_size = 32
	_label.position.y = 1.0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1, 1, 0.8)
	add_child(_label)

func _process(delta: float) -> void:
	match state:
		State.FISHING:
			_timer -= delta
			# Pulse the label
			if _label:
				var dots := ". " if int(_timer * 2) % 2 == 0 else " .."
				_label.text = "Fishing" + dots
				_label.modulate.a = 0.6 + sin(_timer * 4.0) * 0.3
			if _timer <= 0.0:
				_catch_fish()
		State.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.IDLE

func on_hit(player: Node3D, _tool_type: String, power: float = 1.0) -> void:
	if _tool_type != "fishing_rod":
		return
	if state != State.IDLE:
		return

	_fishing_player = player
	state = State.FISHING
	_timer = catch_time
	if _label:
		_label.text = "Fishing ..."

func _catch_fish() -> void:
	state = State.COOLDOWN
	_timer = cooldown_time

	if not _fishing_player or not _fishing_player.has_method("get_inventory"):
		_fishing_player = null
		return

	var inv = _fishing_player.get_inventory()
	if not inv:
		_fishing_player = null
		return

	var total_weight := 0.0
	for entry in loot_table:
		total_weight += entry.get("chance", 0.0)

	var roll := randf_range(0.0, total_weight)
	var cumulative := 0.0
	var caught_id := ""
	var caught_amount := 1
	for entry in loot_table:
		cumulative += entry.get("chance", 0.0)
		if roll <= cumulative:
			caught_id = entry.get("item_id", "")
			caught_amount = randi_range(entry.get("min_amount", 1), entry.get("max_amount", 1))
			break

	if caught_id.is_empty():
		_catch_fail()
		return

	inv.add_item(caught_id, caught_amount)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.item_picked_up.emit(caught_id, caught_amount)
		event_bus.notification_shown.emit("Fishing", "Caught %d %s" % [caught_amount, caught_id], "info")

	if _label:
		_label.text = "! :)"
		var tween := create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(func(): _label.text = "" if state != State.FISHING else _label.text)

	_fishing_player = null

func _catch_fail() -> void:
	if _label:
		_label.text = "..."
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(func(): _label.text = "")
	_fishing_player = null

func set_default_loot() -> void:
	if loot_table.is_empty():
		loot_table = [
			{"item_id": "raw_fish", "min_amount": 1, "max_amount": 2, "chance": 0.6},
			{"item_id": "salmon", "min_amount": 1, "max_amount": 1, "chance": 0.25},
			{"item_id": "pufferfish", "min_amount": 1, "max_amount": 1, "chance": 0.15},
		]
