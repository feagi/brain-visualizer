shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, diffuse_burley, specular_disabled;

// Tesla coil electrical spike parameters
uniform float spike_intensity : hint_range(0.0, 3.0) = 2.0;
uniform float spike_speed : hint_range(0.1, 10.0) = 5.0;
uniform float spike_thickness : hint_range(0.01, 0.1) = 0.03;
uniform vec4 electrical_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float flicker_speed : hint_range(1.0, 20.0) = 8.0;

varying vec3 world_pos;
varying float spike_progress;

void vertex() {
    world_pos = VERTEX;
    // Calculate progress along the spike (0.0 at base, 1.0 at tip)
    spike_progress = (VERTEX.y + 1.0) / 2.0; // Assuming spike goes from -1 to 1
}

void fragment() {
    // Create electrical flickering effect
    float time_offset = TIME * flicker_speed;
    float flicker = sin(time_offset + world_pos.x * 10.0) * 0.3 + 0.7;
    flicker *= sin(time_offset * 1.3 + world_pos.z * 8.0) * 0.2 + 0.8;
    
    // Create jagged electrical pattern
    float electrical_noise = sin(world_pos.y * 20.0 + TIME * spike_speed) * 0.1;
    electrical_noise += sin(world_pos.x * 15.0 + TIME * spike_speed * 0.7) * 0.05;
    
    // Distance from center of spike
    float distance_from_center = length(vec2(world_pos.x, world_pos.z));
    
    // Create spike shape - thicker at base, thinner at tip
    float spike_width = spike_thickness * (1.0 - spike_progress * 0.8);
    
    // Electrical glow effect
    float glow = 1.0 - smoothstep(0.0, spike_width, distance_from_center);
    glow *= flicker * spike_intensity;
    
    // Add electrical crackling
    glow += electrical_noise * flicker * 0.5;
    
    // Fade out towards the tip
    glow *= (1.0 - spike_progress * 0.3);
    
    ALBEDO = electrical_color.rgb;
    ALPHA = glow * electrical_color.a;
    EMISSION = electrical_color.rgb * glow * 2.0;
}
