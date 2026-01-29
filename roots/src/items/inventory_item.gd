extends Resource
class_name InventoryItem
## Represents an item instance in an inventory slot

@export var item_data: ItemData = null
@export var quantity: int = 1
@export var durability: int = -1  # -1 means not used
@export var quality: ItemData.ItemQuality = ItemData.ItemQuality.NORMAL

func _init(p_item_data: ItemData = null, p_quantity: int = 1) -> void:
	item_data = p_item_data
	quantity = p_quantity
	if item_data and item_data.has_durability:
		durability = item_data.max_durability

func get_item_name() -> String:
	if item_data:
		return item_data.get_display_name()
	return "Empty"

func get_icon() -> Texture2D:
	if item_data:
		return item_data.icon
	return null

func can_stack_with(other: InventoryItem) -> bool:
	if not item_data or not other.item_data:
		return false
	if not item_data.can_stack_with(other.item_data):
		return false
	# Don't stack items with durability or different quality
	if item_data.has_durability or durability != other.durability:
		return false
	if quality != other.quality:
		return false
	return true

func get_max_stack() -> int:
	if item_data:
		return item_data.max_stack_size
	return 1

func is_full_stack() -> bool:
	return quantity >= get_max_stack()

func add_amount(amount: int) -> int:
	# Returns overflow amount
	var max_size = get_max_stack()
	var new_quantity = quantity + amount
	if new_quantity > max_size:
		quantity = max_size
		return new_quantity - max_size
	quantity = new_quantity
	return 0

func remove_amount(amount: int) -> int:
	# Returns amount actually removed
	var removed = min(amount, quantity)
	quantity -= removed
	return removed

func is_empty() -> bool:
	return item_data == null or quantity <= 0

func get_durability_percent() -> float:
	if not item_data or not item_data.has_durability:
		return 100.0
	return float(durability) / float(item_data.max_durability) * 100.0

func damage(amount: int) -> void:
	if item_data and item_data.has_durability:
		durability = max(0, durability - amount)
		if durability <= 0:
			quantity = 0  # Item breaks

func repair(amount: int) -> void:
	if item_data and item_data.has_durability:
		durability = min(item_data.max_durability, durability + amount)

func serialize() -> Dictionary:
	return {
		"item_id": item_data.item_id if item_data else "",
		"quantity": quantity,
		"durability": durability,
		"quality": quality
	}

static func deserialize(data: Dictionary, database: ItemDatabase) -> InventoryItem:
	var item_id = data.get("item_id", "")
	if item_id.is_empty():
		return null
	
	var item_data = database.get_item(item_id)
	if not item_data:
		return null
	
	var item = InventoryItem.new(item_data, data.get("quantity", 1))
	item.durability = data.get("durability", item_data.max_durability)
	item.quality = data.get("quality", ItemData.ItemQuality.NORMAL)
	return item
