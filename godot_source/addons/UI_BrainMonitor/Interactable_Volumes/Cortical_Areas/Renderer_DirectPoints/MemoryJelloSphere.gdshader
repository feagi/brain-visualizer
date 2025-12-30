shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Jello effect parameters
uniform float jello_strength : hint_range(0.0, 0.8) = 0.25;
uniform float jello_frequency : hint_range(0.1, 10.0) = 3.0;
uniform float jello_speed : hint_range(0.1, 8.0) = 2.0;
// Size-aware wobble scaling
// - As the sphere grows, a fixed displacement becomes visually subtle.
// - We scale wobble amplitude based on local radius (|VERTEX|) so larger spheres wobble more.
uniform float jello_size_scale : hint_range(0.0, 4.0) = 1.0;
uniform float jello_size_power : hint_range(0.0, 2.0) = 0.5;
uniform float jello_reference_radius : hint_range(0.01, 10.0) = 0.5;

// Internal "fluid activity" parameters (continuous turbulent glow)
uniform float activity_level : hint_range(0.0, 1.0) = 0.0;
uniform vec4 internal_color : source_color = vec4(1.0, 0.45, 0.25, 1.0);
uniform float internal_strength : hint_range(0.0, 5.0) = 1.2;
uniform float internal_scale : hint_range(0.1, 10.0) = 2.0;
uniform float internal_speed : hint_range(0.0, 10.0) = 1.5;
uniform float internal_contrast : hint_range(0.1, 4.0) = 1.6;

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

// --- Lightweight 3D value noise (no textures) ---
float _hash31(vec3 p) {
	// Cheap, deterministic hash
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float _noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);

	// Smooth interpolation
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = _hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = _hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = _hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = _hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = _hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = _hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = _hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = _hash31(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

float _fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int o = 0; o < 4; o++) {
		v += a * _noise3(p);
		p = p * 2.02 + vec3(17.0, 19.0, 23.0);
		a *= 0.5;
	}
	return v;
}

void vertex() {
    world_position = VERTEX;
    
    // Create jello effect with multiple sine waves
    float time = TIME * jello_speed;
    vec3 pos = VERTEX;
    
    // Apply multiple sine waves for complex jello motion
    float wave1 = sin(pos.x * jello_frequency + time) * jello_strength;
    float wave2 = sin(pos.y * jello_frequency * 1.3 + time * 0.7) * jello_strength;
    float wave3 = sin(pos.z * jello_frequency * 0.8 + time * 1.2) * jello_strength;
    
    // Combine waves and apply to normal direction for outward displacement.
    // Size-aware amplitude scaling: larger radius -> more visible wobble.
    float radius = length(pos);
    float denom = max(jello_reference_radius, 0.0001);
    float size_factor = pow(radius / denom, jello_size_power) * jello_size_scale;
    vec3 displacement = NORMAL * (wave1 + wave2 + wave3) * 0.33 * size_factor;
    
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

	// Internal continuous "fluid" activity:
	// Approximate "depth through the sphere" using dot(NORMAL, VIEW): strongest at center, weakest at rim.
	float center_thickness = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float internal_mask = pow(center_thickness, 0.85);
	
	float t = TIME * internal_speed;
	vec3 p = world_position * internal_scale;
	
	// Add animated drift + mild warp for more "fluid" motion
	vec3 drift = vec3(t, t * 0.73, -t * 0.41);
	vec3 warp = vec3(
		sin(t + p.y * 0.9),
		cos(t * 1.2 + p.z * 0.8),
		sin(t * 0.8 + p.x * 1.1)
	);
	
	float n = _fbm(p + drift + warp);
	n = clamp(n, 0.0, 1.0);
	n = pow(n, internal_contrast);
	
	// Activity scales how much inner turbulence is visible
	float internal_intensity = n * internal_mask * activity_level;
	final_emission += internal_color.rgb * internal_strength * internal_intensity;
    
    EMISSION = final_emission;
    
    // Material properties
    METALLIC = metallic;
    ROUGHNESS = roughness;
}
