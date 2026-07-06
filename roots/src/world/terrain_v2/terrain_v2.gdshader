shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 water_color: source_color = vec3(0.15, 0.35, 0.55);
uniform vec3 beach_color: source_color = vec3(0.82, 0.74, 0.52);
uniform vec3 plains_color: source_color = vec3(0.45, 0.65, 0.28);
uniform vec3 forest_color: source_color = vec3(0.22, 0.48, 0.18);
uniform vec3 jungle_color: source_color = vec3(0.15, 0.40, 0.10);
uniform vec3 taiga_color: source_color = vec3(0.18, 0.32, 0.20);
uniform vec3 mountains_color: source_color = vec3(0.52, 0.48, 0.42);
uniform vec3 snow_color: source_color = vec3(0.92, 0.93, 0.95);
uniform vec3 meadow_color: source_color = vec3(0.55, 0.70, 0.30);
uniform vec3 highland_color: source_color = vec3(0.50, 0.52, 0.30);

varying vec3 world_pos;

float hash_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash_noise(i), hash_noise(i + vec2(1.0, 0.0)), u.x),
		mix(hash_noise(i + vec2(0.0, 1.0)), hash_noise(i + vec2(1.0, 1.0)), u.x),
		u.y);
}

float get_moisture(vec2 p) {
	return value_noise(p * 0.0035 + 100.0);
}

float get_temperature(vec2 p) {
	return value_noise(p * 0.003 + 200.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));

	float h = world_pos.y;
	float moisture = get_moisture(world_pos.xz);
	float temperature = get_temperature(world_pos.xz);

	vec3 col;
	if (h < 0.3) {
		col = water_color;
	} else if (h < 2.0) {
		col = beach_color;
	} else if (h < 18.0) {
		if (moisture < 0.25) col = plains_color;
		else if (moisture < 0.45) col = meadow_color;
		else if (moisture < 0.65) col = forest_color;
		else col = jungle_color;
	} else if (h < 32.0) {
		if (temperature < 0.35) col = taiga_color;
		else if (moisture > 0.5) col = forest_color;
		else col = highland_color;
	} else if (h < 48.0) {
		if (temperature < 0.35) col = taiga_color;
		else col = mountains_color;
	} else {
		col = snow_color;
	}

	float detail = value_noise(world_pos.xz * 0.05) * 0.06 - 0.03;
	col += detail;

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
