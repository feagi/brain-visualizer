shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Jello effect parameters
uniform float jello_strength : hint_range(0.0, 0.8) = 0.25;
uniform float jello_frequency : hint_range(0.1, 10.0) = 3.0;
uniform float jello_speed : hint_range(0.1, 8.0) = 2.0;

// Material properties
uniform vec4 albedo_color : source_color = vec4(0.8, 0.2, 0.1, 0.8);
uniform vec4 emission_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float emission_energy : hint_range(0.0, 2.0) = 0.8;
uniform float rim_power : hint_range(0.1, 10.0) = 2.0;
uniform float rim_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = VERTEX;
    
    // Create jello effect with multiple sine waves
    float time = TIME * jello_speed;
    vec3 pos = VERTEX;
    
    // Apply multiple sine waves for complex jello motion
    float wave1 = sin(pos.x * jello_frequency + time) * jello_strength;
    float wave2 = sin(pos.y * jello_frequency * 1.3 + time * 0.7) * jello_strength;
    float wave3 = sin(pos.z * jello_frequency * 0.8 + time * 1.2) * jello_strength;
    
    // Combine waves and apply to normal direction for outward displacement
    vec3 displacement = NORMAL * (wave1 + wave2 + wave3) * 0.33;
    
    // Apply the displacement
    VERTEX += displacement;
    world_position = VERTEX;
}

void fragment() {
    // Base color with transparency
    ALBEDO = albedo_color.rgb;
    ALPHA = albedo_color.a;
    
    // Calculate rim lighting for extra glow
    float rim_dot = 1.0 - dot(NORMAL, VIEW);
    float rim_effect = pow(rim_dot, rim_power) * rim_intensity;
    
    // Combine base emission with rim lighting
    vec3 final_emission = emission_color.rgb * emission_energy;
    final_emission += emission_color.rgb * rim_effect;
    
    EMISSION = final_emission;
    
    // Material properties
    METALLIC = metallic;
    ROUGHNESS = roughness;
}
