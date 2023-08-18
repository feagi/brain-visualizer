shader_type spatial;
render_mode unshaded;

varying mat4 INV_MODELVIEW_MATRIX;

void vertex() {
    INV_MODELVIEW_MATRIX = inverse(MODELVIEW_MATRIX);
}

void fragment() {
    ALBEDO = (INV_MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}