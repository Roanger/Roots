extends Node3D

const TEST_SEED: int = 12345

@onready var _terrain: VoxelLodTerrain = $VoxelLodTerrain
@onready var _camera: Camera3D = $Camera3D

var world_noise: WorldNoise


func _ready() -> void:
	world_noise = WorldNoise.new()
	world_noise.setup(TEST_SEED)
	_terrain.generator = world_noise.build_generator()
	_terrain.material = _make_material()
	var h := world_noise.get_height(0.0, 0.0)
	_camera.global_position = Vector3(0, h + 30.0, 0)


func _make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/terrain_v2/terrain_v2.gdshader")
	return mat
