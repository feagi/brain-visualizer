shader_type spatial;
render_mode unshaded, cull_front, blend_mix;
// A simple way to handle outlines as a pass, TODO replace me with something nicer


uniform vec4 outline_color: source_color = vec4(0.4, 0.4, 0.8, 1.0);
uniform float thickness = 0.1;

void vertex() 
{
	VERTEX *= thickness + 1.0;
}

void fragment()
{
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
