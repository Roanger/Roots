extends Area3D
class_name WorldItem
## A pickupable item in the world

@export var item_id: String = ""
@export var quantity: int = 1
@export var pickup_radius: float = 2.0
@export var auto_pickup: bool = false

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var item_database: ItemDatabase = get_node_or_null("/root/ItemDatabase")
@onready var event_bus: Node = get_node_or_null("/root/EventBus")

var item_data: ItemData = null
var bob_offset: float = 0.0
var bob_speed: float = 3.0
var bob_height: float = 0.2
var initial_y: float = 0.0

func _ready() -> void:
	# Get item data from database
	if item_database:
		item_data = item_database.get_item(item_id)
	
	if item_data:
		# Set up sprite
		if sprite and item_data.icon:
			sprite.texture = item_data.icon
			# Make it billboard (always face camera)
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# Scale based on icon size
			sprite.pixel_size = 0.005
	
	# Set up collision
	if collision_shape:
		var sphere = SphereShape3D.new()
		sphere.radius = pickup_radius
		collision_shape.shape = sphere
	
	# Connect body entered signal for auto-pickup or proximity detection
	body_entered.connect(_on_body_entered)
	
	initial_y = position.y
	bob_offset = randf() * 100.0  # Random starting phase

func _process(delta: float) -> void:
	# Bobbing animation
	var time = Time.get_time_dict_from_system()
	var seconds = time.hour * 3600 + time.minute * 60 + time.second
	var bob = sin((seconds + bob_offset) * bob_speed) * bob_height
	position.y = initial_y + bob
	
	# Rotate slowly
	rotate_y(delta * 1.0)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if auto_pickup:
			_pickup(body)
		else:
			# Show pickup prompt or highlight
			print("Press E to pick up ", item_data.item_name if item_data else item_id)

var _picked_up: bool = false

func _pickup(player: Node3D) -> void:
	if _picked_up:
		return
	_picked_up = true
	
	# Add to player inventory
	if player.has_method("add_item_to_inventory"):
		var remaining = player.add_item_to_inventory(item_id, quantity)
		# add_item_to_inventory returns remaining quantity (0 means all items added)
		if remaining < quantity:
			var picked_up_amount = quantity - remaining
			# Emit pickup event
			if event_bus and event_bus.has_method("notify_pickup"):
				event_bus.notify_pickup(item_id, picked_up_amount)
			print("Picked up: ", item_data.item_name if item_data else item_id, " x", picked_up_amount)
			# Destroy this world item if all items were picked up
			if remaining == 0:
				queue_free()
			else:
				# Partial pickup - update quantity and allow future pickups
				quantity = remaining
				_picked_up = false
		else:
			_picked_up = false

func interact(player: Node3D) -> void:
	"""Called when player manually interacts with this item (presses E)"""
	_pickup(player)

func set_item_data(data: ItemData, qty: int = 1) -> void:
	item_data = data
	item_id = data.item_id if data else ""
	quantity = qty
	
	if sprite and data and data.icon:
		sprite.texture = data.icon
