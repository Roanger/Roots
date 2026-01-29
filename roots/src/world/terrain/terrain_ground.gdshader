shader_type spatial;

render_mode cull_disabled, depth_draw_opaque;

// Draw both faces but discard underside using FRONT_FACING (works at any distance).

// Preserves vertex (biome) color and adds subtle procedural ground variation
// so terrain reads as solid ground while staying color-coded by type.

varying vec3 world_pos;

// Simple 2D hash for procedural variation
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Only draw TOP of terrain using FRONT_FACING (works at any distance).
	// Our winding makes front face = underside, so discard when FRONT_FACING.
	if (FRONT_FACING) {
		discard;
	}

	// Two scales of noise for a more natural ground feel (dirt/grass variation)
	vec2 uv = world_pos.xz * 0.5;
	float n1 = hash(floor(uv));
	float n2 = hash(floor(uv * 2.3 + 1.0));
	float variation = (n1 * 0.6 + n2 * 0.4) * 0.2 + 0.85; // 0.85 to 1.05

	// Vertex color = biome color; modulate by variation so it's not flat
	ALBEDO = COLOR.rgb * variation;
	ALPHA = 1.0; // Fully opaque so ground is solid (no see-through)
	ROUGHNESS = 0.92;
	SPECULAR = 0.1;
}
