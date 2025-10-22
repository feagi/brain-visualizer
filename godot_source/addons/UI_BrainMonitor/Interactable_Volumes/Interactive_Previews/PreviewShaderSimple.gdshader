shader_type spatial;
render_mode unshaded, blend_add;

uniform vec4 color: source_color = vec4(0.5, 0.5, 0.3, 0.5);

void vertex() {
	// lol
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
