shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.18, 0.28, 0.65, 0.85);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.9);
uniform float time_scale : hint_range(0.0, 2.0) = 0.5;
uniform float wave_strength : hint_range(0.0, 2.0) = 0.15;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.5;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.3;

varying vec2 world_pos;
varying float wave_height;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    
    // Create wave movement using sine waves
    float time = TIME * wave_speed;
    float wave1 = sin(world_pos.x * 0.5 + time) * wave_strength;
    float wave2 = sin(world_pos.y * 0.3 + time * 0.8) * wave_strength * 0.5;
    float wave3 = sin((world_pos.x + world_pos.y) * 0.2 + time * 1.2) * wave_strength * 0.3;
    
    wave_height = wave1 + wave2 + wave3;
    VERTEX.y += wave_height;
}

void fragment() {
    // Create ripple pattern
    float time = TIME * wave_speed;
    float ripple1 = sin(world_pos.x * 2.0 + time * 2.0) * 0.5 + 0.5;
    float ripple2 = sin(world_pos.y * 1.5 + time * 1.5) * 0.5 + 0.5;
    float ripple = (ripple1 + ripple2) * 0.5;
    
    // Add foam at wave peaks
    float foam = smoothstep(1.0 - foam_amount, 1.0, ripple + wave_height * 2.0);
    
    // Mix water color with foam
    vec4 final_color = mix(water_color, foam_color, foam * 0.4);
    
    // Add slight transparency variation for depth effect
    float depth_fade = 0.85 + ripple * 0.15;
    final_color.a *= depth_fade;
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}
