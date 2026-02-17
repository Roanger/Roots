@tool
extends EditorScript
## Run this script from the editor (File > Run) to generate building .tscn files
## from the current TownBuilder code. Each building type gets its own scene file
## that you can then open and edit in the Godot editor.
##
## After editing, TownBuilder will automatically load your saved scenes instead
## of assembling from code.

const GLTF_BASE = "res://Medieval Village MegaKit[Standard]/glTF/"
const WALL_H: float = 3.12
const GRID: float = 2.0
const H: float = 1.0

const OUTPUT_DIR = "res://src/world/town_buildings/"

func _run() -> void:
	print("=== Exporting Town Building Scenes ===")
	
	_export_small_house()
	_export_large_house()
	_export_market_stall()
	_export_town_well()
	
	print("=== Export Complete! Scenes saved to ", OUTPUT_DIR, " ===")
	print("Open them in the editor to fine-tune positions, rotations, and pieces.")

# ─── Small House ───
func _export_small_house() -> void:
	var building = Node3D.new()
	building.name = "SmallHouse"
	
	# Floor (2x2 grid = 4x4m)
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(H, 0, H))
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(GRID + H, 0, H))
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(H, 0, GRID + H))
	_add_piece(building, "Floor_UnevenBrick.gltf", Vector3(GRID + H, 0, GRID + H))
	
	# Back wall (Z = 0)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(H, 0, 0))
	_add_piece(building, "Wall_Plaster_Window_Wide_Round.gltf", Vector3(GRID + H, 0, 0))
	
	# Front wall (Z = 4m)
	_add_piece(building, "Wall_Plaster_Door_Round.gltf", Vector3(H, 0, GRID * 2), PI)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(GRID + H, 0, GRID * 2), PI)
	
	# Left wall (X = 0)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(0, 0, H), PI / 2.0)
	_add_piece(building, "Wall_Plaster_Window_Thin_Round.gltf", Vector3(0, 0, GRID + H), PI / 2.0)
	
	# Right wall (X = 4m)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(GRID * 2, 0, GRID * 2 - H), -PI / 2.0)
	_add_piece(building, "Wall_Plaster_Straight.gltf", Vector3(GRID * 2, 0, GRID - H), -PI / 2.0)
	
	# Corners
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(0, 0, 0))
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(GRID * 2, 0, 0), -PI / 2.0)
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(GRID * 2, 0, GRID * 2), PI)
	_add_piece(building, "Corner_Exterior_Wood.gltf", Vector3(0, 0, GRID * 2), PI / 2.0)
	
	# Roof
	_add_piece(building, "Roof_RoundTiles_4x6.gltf", Vector3(GRID, WALL_H, GRID))
	
	# Door
	_add_piece(building, "Door_1_Round.gltf", Vector3(H, 0, GRID * 2), PI)
	
	# Chimney
	_add_piece(building, "Prop_Chimney.gltf", Vector3(GRID * 1.5, WALL_H - 2.84, -0.5))
	
	# Collision
	_add_building_collision(building, Vector3(GRID * 2, WALL_H, GRID * 2), Vector3(GRID, WALL_H * 0.5, GRID))
	
	_save_scene(building, "small_house.tscn")

# ─── Large House ───
func _export_large_house() -> void:
	var building = Node3D.new()
	building.name = "LargeHouse"
	
	# Floor (3x2 grid = 6x4m)
	for x in range(3):
		for z in range(2):
			_add_piece(building, "Floor_WoodDark.gltf", Vector3(x * GRID + H, 0, z * GRID + H))
	
	# Back wall (Z = 0)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(H, 0, 0))
	_add_piece(building, "Wall_UnevenBrick_Window_Wide_Round.gltf", Vector3(GRID + H, 0, 0))
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(GRID * 2 + H, 0, 0))
	
	# Front wall (Z = 4m)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(H, 0, GRID * 2), PI)
	_add_piece(building, "Wall_UnevenBrick_Door_Round.gltf", Vector3(GRID + H, 0, GRID * 2), PI)
	_add_piece(building, "Wall_UnevenBrick_Window_Wide_Flat.gltf", Vector3(GRID * 2 + H, 0, GRID * 2), PI)
	
	# Left wall (X = 0)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(0, 0, H), PI / 2.0)
	_add_piece(building, "Wall_UnevenBrick_Window_Thin_Round.gltf", Vector3(0, 0, GRID + H), PI / 2.0)
	
	# Right wall (X = 6m)
	_add_piece(building, "Wall_UnevenBrick_Straight.gltf", Vector3(GRID * 3, 0, GRID * 2 - H), -PI / 2.0)
	_add_piece(building, "Wall_UnevenBrick_Window_Thin_Round.gltf", Vector3(GRID * 3, 0, GRID - H), -PI / 2.0)
	
	# Corners
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(0, 0, 0))
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(GRID * 3, 0, 0), -PI / 2.0)
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(GRID * 3, 0, GRID * 2), PI)
	_add_piece(building, "Corner_Exterior_Brick.gltf", Vector3(0, 0, GRID * 2), PI / 2.0)
	
	# Roof
	_add_piece(building, "Roof_RoundTiles_6x6.gltf", Vector3(GRID * 1.5, WALL_H, GRID))
	
	# Door
	_add_piece(building, "Door_2_Round.gltf", Vector3(GRID + H, 0, GRID * 2), PI)
	
	# Chimney
	_add_piece(building, "Prop_Chimney2.gltf", Vector3(GRID * 2.5, WALL_H - 2.84, -0.5))
	
	# Overhang
	_add_piece(building, "Overhang_UnevenBrick_Long.gltf", Vector3(GRID * 1.5, WALL_H, GRID * 2))
	
	# Balcony
	_add_piece(building, "Balcony_Simple_Straight.gltf", Vector3(GRID * 1.5, WALL_H * 0.65, GRID * 2))
	
	# Vines
	_add_piece(building, "Prop_Vine1.gltf", Vector3(0, WALL_H * 0.3, GRID))
	
	# Collision
	_add_building_collision(building, Vector3(GRID * 3, WALL_H, GRID * 2), Vector3(GRID * 1.5, WALL_H * 0.5, GRID))
	
	_save_scene(building, "large_house.tscn")

# ─── Market Stall ───
func _export_market_stall() -> void:
	var stall = Node3D.new()
	stall.name = "MarketStall"
	
	# Crates
	_add_piece(stall, "Prop_Crate.gltf", Vector3(0, 0, 0))
	_add_piece(stall, "Prop_Crate.gltf", Vector3(0.8, 0, 0))
	
	# Support posts + roof
	_add_piece(stall, "Prop_Support.gltf", Vector3(-0.8, 0, 0))
	_add_piece(stall, "Prop_Support.gltf", Vector3(1.8, 0, 0))
	_add_piece(stall, "Roof_Wooden_2x1.gltf", Vector3(0.4, 2.2, 0))
	
	# Collision
	_add_building_collision(stall, Vector3(2.0, 1.0, 1.0), Vector3(0.5, 0.5, 0))
	
	_save_scene(stall, "market_stall.tscn")

# ─── Town Well ───
func _export_town_well() -> void:
	var well = Node3D.new()
	well.name = "TownWell"
	
	# Stone cylinder
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "WellBase"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.2
	mesh_inst.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.4)
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.6
	well.add_child(mesh_inst)
	mesh_inst.owner = well
	
	# Roof
	_add_piece(well, "Roof_Wooden_2x1.gltf", Vector3(0, 2.2, 0))
	
	# Support posts
	_add_piece(well, "Prop_Support.gltf", Vector3(-0.8, 0, 0))
	_add_piece(well, "Prop_Support.gltf", Vector3(0.8, 0, 0))
	
	# Collision
	var body = StaticBody3D.new()
	body.name = "WellCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	var col = CollisionShape3D.new()
	col.name = "CollisionShape"
	var shape = CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.2
	col.shape = shape
	col.position.y = 0.6
	body.add_child(col)
	col.owner = well
	well.add_child(body)
	body.owner = well
	
	_save_scene(well, "town_well.tscn")

# ─── Helpers ───

func _add_piece(parent: Node3D, gltf_name: String, local_pos: Vector3, rot_y: float = 0.0) -> void:
	var path = GLTF_BASE + gltf_name
	if not ResourceLoader.exists(path):
		push_warning("Export: glTF not found: " + path)
		return
	var scene = load(path) as PackedScene
	if not scene:
		return
	var inst = scene.instantiate() as Node3D
	if inst:
		inst.position = local_pos
		if rot_y != 0.0:
			inst.rotation.y = rot_y
		parent.add_child(inst)
		# Set owner recursively so all nodes are saved in the .tscn
		_set_owner_recursive(inst, parent)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)

func _add_building_collision(parent: Node3D, box_size: Vector3, center_offset: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = "BuildingCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	var col = CollisionShape3D.new()
	col.name = "CollisionShape"
	var shape = BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = center_offset
	body.add_child(col)
	col.owner = parent
	parent.add_child(body)
	body.owner = parent

func _save_scene(root: Node3D, filename: String) -> void:
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err != OK:
		push_error("Failed to pack scene: " + filename + " error: " + str(err))
		root.free()
		return
	
	var path = OUTPUT_DIR + filename
	err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("Failed to save scene: " + path + " error: " + str(err))
	else:
		print("  Saved: ", path)
	
	root.free()
