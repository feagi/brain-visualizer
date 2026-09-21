shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 band_a : source_color = vec4(0.12, 0.86, 0.80, 0.78);
uniform vec4 band_b : source_color = vec4(0.64, 0.30, 0.92, 0.78);
uniform float class_count = 1.0;
uniform float chamfer = 0.16;
uniform float emission_energy : hint_range(0.0, 4.0) = 0.55;
uniform float roughness : hint_range(0.0, 1.0) = 0.18;
uniform float metallic : hint_range(0.0, 1.0) = 0.22;
uniform float rim_power : hint_range(0.1, 8.0) = 2.4;
uniform float rim_intensity : hint_range(0.0, 3.0) = 0.85;
uniform float activity : hint_range(0.0, 2.0) = 0.0;
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float wobble_strength : hint_range(0.0, 0.4) = 0.09;
uniform float wobble_frequency : hint_range(0.1, 12.0) = 3.2;
uniform float wobble_speed : hint_range(0.1, 8.0) = 1.7;
uniform float wobble_size_scale : hint_range(0.0, 4.0) = 1.0;

varying float class_t;

void vertex() {
	class_t = VERTEX.z + 0.5;
	if (VERTEX.z < 0.0) {
		VERTEX.xy *= (1.0 - chamfer);
	}
	float time = TIME * wobble_speed;
	vec3 pos = VERTEX;
	float wave1 = sin(pos.x * wobble_frequency + time);
	float wave2 = sin(pos.y * wobble_frequency * 1.3 + time * 0.7);
	float wave3 = sin(pos.z * wobble_frequency * 0.8 + time * 1.2);
	float amplitude = wobble_strength * wobble_size_scale * (1.0 + hover * 0.45 + activity * 0.25);
	VERTEX += NORMAL * ((wave1 + wave2 + wave3) * 0.33 * amplitude);
}

void fragment() {
	float bands = max(class_count, 1.0);
	float band = floor(clamp(class_t, 0.0, 0.99999) * bands);
	float u = band / max(bands - 1.0, 1.0);
	vec4 base = mix(band_a, band_b, u);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_intensity;
	ALBEDO = base.rgb;
	ALPHA = clamp(base.a + hover * 0.12, 0.0, 1.0);
	EMISSION = base.rgb * (emission_energy + activity + rim + hover * 0.35);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
