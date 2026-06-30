shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx;

global uniform vec3 sun_direction;
global uniform vec4 sun_color;

uniform vec4 shallow_color : source_color = vec4(0.12, 0.55, 0.72, 0.82);
uniform vec4 deep_color : source_color = vec4(0.02, 0.18, 0.38, 0.95);
uniform vec4 foam_color : source_color = vec4(0.98, 0.99, 1.0, 0.92);
uniform vec4 fresnel_color : source_color = vec4(0.55, 0.8, 0.95, 1.0);
uniform vec4 sky_color : source_color = vec4(0.55, 0.75, 0.95, 1.0);

uniform float time_scale : hint_range(0.0, 2.0) = 0.55;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.1;
uniform float wave_strength : hint_range(0.0, 2.0) = 0.35;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.75;

uniform float depth_fade_distance : hint_range(0.1, 20.0) = 3.5;
uniform float foam_threshold : hint_range(0.0, 5.0) = 0.8;
uniform float foam_amount : hint_range(0.0, 2.0) = 1.0;
uniform float foam_noise_scale : hint_range(0.1, 10.0) = 3.0;

uniform float refraction_strength : hint_range(0.0, 0.2) = 0.045;
uniform float fresnel_power : hint_range(0.0, 10.0) = 2.2;
uniform float fresnel_strength : hint_range(0.0, 2.0) = 0.75;

uniform float specular_power : hint_range(1.0, 256.0) = 80.0;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.85;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

varying vec2 v_world_pos;

float wave(vec2 p, vec2 dir, float freq, float speed, float amp, float time, inout vec2 deriv) {
    float phase = dot(p, dir) * freq + time * speed;
    float s = sin(phase);
    float c = cos(phase);
    deriv += dir * freq * amp * c;
    return amp * s;
}

float foam_noise(vec2 p, float time) {
    float n1 = sin(p.x * foam_noise_scale + time * 1.1);
    float n2 = sin(p.y * foam_noise_scale * 0.8 - time * 0.9);
    float n3 = sin((p.x + p.y) * foam_noise_scale * 0.5 + time * 0.7);
    return (n1 + n2 + n3) * 0.33 + 0.5;
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;

    float time = TIME * wave_speed * time_scale;
    vec2 deriv = vec2(0.0);
    float h = 0.0;

    h += wave(v_world_pos, vec2(1.0, 0.5), 0.35, 1.0, wave_strength, time, deriv);
    h += wave(v_world_pos, vec2(-0.6, 0.9), 0.55, 1.2, wave_strength * 0.65, time + 1.3, deriv);
    h += wave(v_world_pos, vec2(0.2, -1.0), 0.85, 1.8, wave_strength * 0.35, time * 1.1 + 2.1, deriv);
    h += wave(v_world_pos, vec2(-0.9, -0.4), 1.3, 2.4, wave_strength * 0.2, time * 0.8 + 3.7, deriv);

    VERTEX.y += h;
}

void fragment() {
    float time = TIME * wave_speed * time_scale;
    vec2 deriv = vec2(0.0);
    float h = 0.0;

    h += wave(v_world_pos, vec2(1.0, 0.5), 0.35, 1.0, wave_strength, time, deriv);
    h += wave(v_world_pos, vec2(-0.6, 0.9), 0.55, 1.2, wave_strength * 0.65, time + 1.3, deriv);
    h += wave(v_world_pos, vec2(0.2, -1.0), 0.85, 1.8, wave_strength * 0.35, time * 1.1 + 2.1, deriv);
    h += wave(v_world_pos, vec2(-0.9, -0.4), 1.3, 2.4, wave_strength * 0.2, time * 0.8 + 3.7, deriv);

    vec3 world_normal = normalize(vec3(-deriv.x * normal_strength, 1.0, -deriv.y * normal_strength));
    NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

    // Refraction / depth
    vec2 refract_offset = world_normal.xz * refraction_strength;
    vec2 screen_uv = SCREEN_UV + refract_offset;

    float depth_raw = textureLod(DEPTH_TEXTURE, screen_uv, 0.0).r;
    vec4 view_pos = INV_PROJECTION_MATRIX * vec4(screen_uv * 2.0 - 1.0, depth_raw, 1.0);
    view_pos.xyz /= view_pos.w;
    float water_depth = max(VERTEX.z - view_pos.z, 0.0);

    vec3 refract_color = textureLod(SCREEN_TEXTURE, screen_uv, 0.0).rgb;

    // Depth-based water color
    float depth_factor = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
    vec4 water_col = mix(shallow_color, deep_color, depth_factor);

    // Shoreline foam
    float foam_edge = 1.0 - smoothstep(0.0, foam_threshold, water_depth);
    float foam_noise_val = foam_noise(v_world_pos, time);
    float foam = foam_edge * foam_noise_val * foam_amount;

    // Fresnel
    vec3 view_dir = normalize(-VERTEX);
    float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), fresnel_power);

    // Specular sun sparkle
    vec3 sun_dir_view = normalize((VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz);
    vec3 half_vec = normalize(view_dir + sun_dir_view);
    float spec = pow(max(dot(NORMAL, half_vec), 0.0), specular_power) * specular_strength;
    spec *= sun_color.a;

    // Fake sky reflection mixed with fresnel
    vec3 reflection = mix(sky_color.rgb, fresnel_color.rgb, fresnel * 0.6);

    // Combine
    vec3 final_rgb = mix(water_col.rgb, refract_color, (1.0 - depth_factor) * 0.5);
    final_rgb = mix(final_rgb, foam_color.rgb, clamp(foam, 0.0, 1.0));
    final_rgb += reflection * fresnel * fresnel_strength;
    final_rgb += sun_color.rgb * spec;

    ALBEDO = final_rgb;
    ALPHA = mix(water_col.a, foam_color.a, clamp(foam, 0.0, 1.0));
    ROUGHNESS = 0.04 + (1.0 - fresnel) * 0.3;
    SPECULAR = 0.9;
}
