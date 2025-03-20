shader_type spatial;
render_mode unshaded, blend_add, wireframe;
// A simple way to handle outlines as a pass, TODO replace me with something nicer


uniform vec4 outline_color: source_color = vec4(0.4, 0.4, 0.8, 1.0);
uniform vec3 thickness_scaling = vec3(1.0, 1.0, 1.0);

void vertex() 
{
	vec3 dir = sign(VERTEX);
	VERTEX += (dir * 0.05) * thickness_scaling;
}

void fragment()
{
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
