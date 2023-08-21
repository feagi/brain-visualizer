shader_type spatial;
render_mode unshaded;

varying mat4 INV_MODELVIEW_MATRIX;
uniform float green_intensity = 1;
uniform float red_intensity = 0;
uniform float blue_intensity=0;

void vertex() {
    INV_MODELVIEW_MATRIX = inverse(MODELVIEW_MATRIX);
}

void fragment() {
    ALBEDO = vec3(red_intensity, green_intensity, blue_intensity); // Set the color to solid green (R=0, G=1, B=0)
}