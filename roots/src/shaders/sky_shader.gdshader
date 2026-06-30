shader_type sky;

uniform vec4 sky_top_color : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.55, 0.7, 0.9, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.55, 0.7, 0.9, 1.0);
uniform float sky_energy : hint_range(0.0, 2.0) = 1.0;
uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform float moon_size : hint_range(0.01, 0.5) = 0.05;
uniform float star_density : hint_range(0.0, 1.0) = 0.99;
uniform float sun_size : hint_range(0.005, 0.2) = 0.02;
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float stars(vec2 uv, float density) {
	vec2 grid = uv * 200.0;
	vec2 cell = floor(grid);
	vec2 cell_uv = fract(grid);
	float star = 0.0;
	float h = hash(cell);
	if (h > density) {
		float d = length(cell_uv - 0.5);
		float brightness = (1.0 - smoothstep(0.0, 0.08, d));
		brightness *= hash(cell + 17.0);
		star = brightness;
	}
	return star;
}

void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y;
	
	// Sky gradient
	vec3 sky_col;
	if (y > 0.0) {
		float t = pow(clamp(y, 0.0, 1.0), 0.5);
		sky_col = mix(sky_horizon_color.rgb, sky_top_color.rgb, t);
	} else {
		float t = pow(clamp(-y, 0.0, 1.0), 0.5);
		sky_col = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, t);
	}
	
	// Stars (only in upper hemisphere)
	if (y > 0.01 && star_visibility > 0.01) {
		vec2 star_uv = vec2(atan(dir.x, dir.z) / 6.2832, y) * vec2(1.0, 2.0);
		float s = stars(star_uv, star_density);
		s += stars(star_uv * 2.3 + 50.0, star_density) * 0.5;
		s += stars(star_uv * 4.7 + 100.0, star_density) * 0.25;
		s = clamp(s, 0.0, 1.0);
		sky_col += vec3(s) * star_visibility;
	}
	
	// Sun disc (uses Godot's built-in LIGHT0_DIRECTION)
	if (y > 0.0 && LIGHT0_ENABLED) {
		float sun_dot = max(dot(normalize(dir), normalize(LIGHT0_DIRECTION)), 0.0);
		float sun_disc = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.5, sun_dot);
		float sun_glow = smoothstep(1.0 - sun_size * 6.0, 1.0 - sun_size, sun_dot) * 0.3;
		sky_col += sun_color.rgb * (sun_disc * 1.5 + sun_glow);
	}
	
	// Moon (opposite to sun direction)
	if (y > 0.0) {
		float moon_dot = max(dot(normalize(dir), normalize(moon_direction)), 0.0);
		float moon_disc = smoothstep(1.0 - moon_size, 1.0 - moon_size * 0.6, moon_dot);
		float moon_glow = smoothstep(1.0 - moon_size * 4.0, 1.0 - moon_size, moon_dot) * 0.15;
		// Moon visible when it's above horizon and sky is dark enough
		float moon_vis = smoothstep(0.0, 0.3, moon_direction.y) * (1.0 - sky_energy * 0.8);
		sky_col += vec3(0.95, 0.95, 0.85) * (moon_disc * 0.7 + moon_glow) * moon_vis;
	}
	
	COLOR = sky_col * sky_energy;
}
