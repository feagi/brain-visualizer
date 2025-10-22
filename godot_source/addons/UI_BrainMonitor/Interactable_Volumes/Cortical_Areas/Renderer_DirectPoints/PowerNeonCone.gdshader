shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Material properties for bright red power cone
uniform vec4 albedo_color : source_color = vec4(1.0, 0.1, 0.1, 0.8);
uniform vec4 emission_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float emission_energy : hint_range(0.0, 3.0) = 1.5;
uniform float rim_power : hint_range(0.1, 10.0) = 1.5;
uniform float rim_intensity : hint_range(0.0, 3.0) = 2.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;

// Pulsing effect
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;

// Firing animation effect
uniform float firing_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 firing_color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float firing_intensity : hint_range(0.0, 5.0) = 3.0;
uniform float firing_width : hint_range(0.1, 0.5) = 0.2;

varying vec3 world_pos;
varying float height_ratio;

void vertex() {
    // No vertex displacement for power cone - keep it solid and stable
    world_pos = VERTEX;
    // Calculate height ratio (0.0 at bottom, 1.0 at top)
    height_ratio = (VERTEX.y + 3.0) / 6.0; // Assuming cone height is 6.0, centered at origin
}

void fragment() {
    // Base neon blue color
    vec3 base_color = albedo_color.rgb;
    float base_alpha = albedo_color.a;
    
    // Calculate rim lighting for neon glow
    float rim_dot = 1.0 - dot(NORMAL, VIEW);
    float rim_effect = pow(rim_dot, rim_power) * rim_intensity;
    
    // Add pulsing effect
    float pulse = sin(TIME * pulse_speed) * pulse_intensity + 1.0;
    
    // Calculate firing animation effect
    float firing_effect = 0.0;
    if (firing_progress > 0.0) {
        // Create a wave that travels from bottom (0.0) to top (1.0)
        float wave_center = firing_progress;
        float distance_from_wave = abs(height_ratio - wave_center);
        
        // Create a smooth wave with specified width
        if (distance_from_wave < firing_width) {
            firing_effect = (1.0 - distance_from_wave / firing_width) * firing_intensity;
            
            // Mix red firing color with base blue color
            float mix_factor = firing_effect * 0.7;
            base_color = mix(base_color, firing_color.rgb, mix_factor);
        }
    }
    
    ALBEDO = base_color;
    ALPHA = base_alpha;
    
    // Combine base emission with rim lighting, pulsing, and firing effect
    vec3 final_emission = emission_color.rgb * emission_energy * pulse;
    final_emission += emission_color.rgb * rim_effect * pulse;
    
    // Add firing emission
    if (firing_effect > 0.0) {
        final_emission += firing_color.rgb * firing_effect;
    }
    
    EMISSION = final_emission;
    
    // Material properties for slight metallic sheen
    METALLIC = metallic;
    ROUGHNESS = roughness;
}
