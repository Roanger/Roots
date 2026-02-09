extends RefCounted
class_name AnimalModelCache
## Caches the animal FBX scene and extracts individual animal meshes by node name.
## Uses Engine meta to store a singleton instance.

const FBX_PATH = "res://EverythingLibrary_Animals_001.fbx"
const META_KEY = "_animal_model_cache"

# Map of species_id -> node name in the FBX
# These are the expected top-level child names in the FBX scene
const SPECIES_NODE_MAP: Dictionary = {
	"chicken": "Chicken",
	"cow": "HolsteinCow",
	"sheep": "Sheep",
	"goat": "Goat",
	"duck": "PekinDuck",
	"boar": "Boar",
	"deer": "Deer",
	"rabbit": "Rabbit",
}

var _fbx_scene: PackedScene = null
var _logged_nodes: bool = false

static func get_instance() -> RefCounted:
	if Engine.has_meta(META_KEY):
		return Engine.get_meta(META_KEY)
	var inst = AnimalModelCache.new()
	Engine.set_meta(META_KEY, inst)
	return inst

func _load_fbx() -> bool:
	if _fbx_scene:
		return true
	_fbx_scene = load(FBX_PATH) as PackedScene
	if not _fbx_scene:
		push_warning("AnimalModelCache: Failed to load FBX from %s" % FBX_PATH)
		return false
	return true

func extract_model(species_id: String) -> Node3D:
	## Returns a duplicate of the animal mesh subtree for the given species.
	## Returns null if the species or FBX can't be found.
	if not SPECIES_NODE_MAP.has(species_id):
		push_warning("AnimalModelCache: No node mapping for species '%s'" % species_id)
		return null
	
	if not _load_fbx():
		return null
	
	# Instantiate the full FBX each time we need to extract
	# (we duplicate just the subtree we need, then free the rest)
	var root = _fbx_scene.instantiate() as Node3D
	if not root:
		return null
	
	# Debug: print all node names on first call
	if not _logged_nodes:
		_logged_nodes = true
		print("[AnimalModelCache] FBX root: %s [%s] — %d children" % [root.name, root.get_class(), root.get_child_count()])
		_print_tree_debug(root, 0)
	
	var node_name = SPECIES_NODE_MAP[species_id]
	var animal_node: Node3D = _find_node_recursive(root, node_name)
	
	if not animal_node:
		push_warning("AnimalModelCache: Node '%s' not found in FBX for species '%s'" % [node_name, species_id])
		root.queue_free()
		return null
	
	# Duplicate the subtree before freeing the root
	var model = animal_node.duplicate() as Node3D
	
	# Reset position so it's centered at origin
	model.position = Vector3.ZERO
	
	root.queue_free()
	return model

func _print_tree_debug(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	var info = "%s%s [%s]" % [indent, node.name, node.get_class()]
	if node is MeshInstance3D:
		info += " (HAS MESH)"
	if node.get_child_count() > 0:
		info += " {%d children}" % node.get_child_count()
	print("[AnimalModelCache] %s" % info)
	if depth < 3:  # Limit depth to avoid flooding
		for child in node.get_children():
			_print_tree_debug(child, depth + 1)

func _find_node_recursive(node: Node, target_name: String) -> Node3D:
	if node.name == target_name and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found = _find_node_recursive(child, target_name)
		if found:
			return found
	return null

func list_available_nodes() -> Array[String]:
	## Debug helper: returns all top-level node names in the FBX
	var result: Array[String] = []
	if not _load_fbx():
		return result
	var root = _fbx_scene.instantiate() as Node3D
	if not root:
		return result
	for child in root.get_children():
		result.append(child.name)
	root.queue_free()
	return result
