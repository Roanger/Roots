extends Node
## Noise utilities for procedural generation using simplex noise

# Singleton reference for random number generation
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Pre-generated noise seeds for different terrain features
var elevation_seed: int = 0
var moisture_seed: int = 0
var temperature_seed: int = 0
var detail_seed: int = 0

# Cached noise generators for better performance
var elevation_noise: FastNoiseLite = null
var detail_noise: FastNoiseLite = null

func _ready() -> void:
	_generate_seeds()

func _generate_seeds() -> void:
	elevation_seed = randi()
	moisture_seed = randi()
	temperature_seed = randi()
	detail_seed = randi()

func set_seed_from_world(world_seed: int) -> void:
	rng.seed = world_seed
	elevation_seed = rng.randi()
	moisture_seed = rng.randi()
	temperature_seed = rng.randi()
	detail_seed = rng.randi()
	
	# Initialize noise generators
	_init_noise_generators()

func _init_noise_generators() -> void:
	# Elevation noise - low frequency for large rolling hills
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = elevation_seed
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = 0.005  # Lower = smoother, larger features
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation_noise.fractal_octaves = 3  # Fewer octaves = smoother
	elevation_noise.fractal_lacunarity = 2.0
	elevation_noise.fractal_gain = 0.5
	
	# Detail noise - higher frequency for small terrain variation
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = detail_seed
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.05
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_lacunarity = 2.0
	detail_noise.fractal_gain = 0.5

func get_elevation(x: float, z: float) -> float:
	"""Get terrain elevation at world coordinates using simplex noise"""
	if elevation_noise == null:
		_init_noise_generators()
	
	# Get base elevation from smooth noise
	var base_elevation = elevation_noise.get_noise_2d(x, z)
	
	# Normalize from [-1, 1] to [0, 1]
	base_elevation = (base_elevation + 1.0) / 2.0
	
	# Apply a power function to create more flat valleys and steeper hills
	# Values < 1 create more flat areas, values > 1 create more peaks
	base_elevation = pow(base_elevation, 1.2)
	
	return base_elevation

func get_moisture(x: float, z: float) -> float:
	"""Get moisture level at world coordinates (0.0 = dry, 1.0 = wet)"""
	return _get_noise_2d(x, z, moisture_seed, 0.025, 1.0)

func get_temperature(x: float, z: float) -> float:
	"""Get temperature at world coordinates (0.0 = cold, 1.0 = hot)"""
	return _get_noise_2d(x, z, temperature_seed, 0.03, 1.0)

func get_detail(x: float, z: float) -> float:
	"""Get detail noise for terrain variation"""
	if detail_noise == null:
		_init_noise_generators()
	
	var value = detail_noise.get_noise_2d(x, z)
	return (value + 1.0) / 2.0 * 0.3  # Reduced amplitude for detail

func _get_noise_2d(x: float, z: float, noise_seed: int, scale: float, amplitude: float) -> float:
	"""Generate 2D noise value using simplex-like algorithm"""
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	
	var value = noise.get_noise_2d(x, z)
	# Normalize from [-1, 1] to [0, 1]
	return (value + 1.0) / 2.0 * amplitude

func get_biome_type(x: float, z: float) -> int:
	"""Determine biome type based on elevation, moisture, and temperature"""
	var elevation = get_elevation(x, z)
	var moisture = get_moisture(x, z)
	var temperature = get_temperature(x, z)
	
	# Biome determination logic
	if elevation < 0.25:
		return 0  # Water (lake/river)
	elif elevation < 0.30:
		return 1  # Beach/Coast
	elif elevation < 0.65:
		if moisture < 0.3:
			return 2  # Plains (dry)
		elif moisture < 0.6:
			return 3  # Forest (moderate)
		else:
			return 4  # Jungle (wet)
	elif elevation < 0.80:
		if temperature < 0.4:
			return 5  # Taiga (cold)
		else:
			return 6  # Hills/Mountains
	else:
		return 7  # Snow peaks

func get_terrain_height(x: float, z: float) -> float:
	"""Get final terrain height with smooth rolling hills"""
	var base_height = get_elevation(x, z)
	
	# Scale base height to reasonable range (5 to 35 units)
	# Lower minimum for flatter valleys, lower maximum for less extreme peaks
	var min_height = 8.0
	var max_height = 35.0
	var height = min_height + base_height * (max_height - min_height)
	
	# Add subtle detail variation (reduced for smoother terrain)
	var detail = get_detail(x, z)
	height += detail * 0.5  # Reduced detail contribution
	
	return height

func get_tree_density(x: float, z: float) -> float:
	"""Get tree density at position (0.0 = no trees, 1.0 = dense forest)"""
	var biome = get_biome_type(x, z)
	if biome in [3, 4]:  # Forest or Jungle
		var moisture = get_moisture(x, z)
		var elevation = get_elevation(x, z)
		return moisture * elevation * 0.7  # Reduced density
	return 0.0

func get_rock_density(x: float, z: float) -> float:
	"""Get rock/stone density at position"""
	var biome = get_biome_type(x, z)
	if biome in [5, 6, 7]:  # Taiga, Mountains, Snow
		var elevation = get_elevation(x, z)
		return elevation * 0.6
	return 0.0

func get_grass_color(x: float, z: float) -> Color:
	"""Get grass color based on moisture and temperature"""
	var moisture = get_moisture(x, z)
	var temperature = get_temperature(x, z)
	
	var base_green = Color(0.3, 0.6, 0.2)
	var dry_green = Color(0.6, 0.55, 0.3)
	var cold_green = Color(0.35, 0.45, 0.35)
	
	var color = base_green.lerp(dry_green, 1.0 - moisture)
	color = color.lerp(cold_green, 1.0 - temperature)
	return color

func get_water_level() -> float:
	"""Get the water level for this world"""
	return 10.0  # Water at height 10

func seed_changed() -> void:
	_generate_seeds()
	_init_noise_generators()
