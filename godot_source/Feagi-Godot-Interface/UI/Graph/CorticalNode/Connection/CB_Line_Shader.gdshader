shader_type canvas_item;

// Calculates the color of a dashed line. Can appear like a full line if colorDashA == colorDashB
vec4 dashedLine(float UVX, float numberDivisions, vec4 colorDashA, vec4 colorDashB) {
	int segment = int(floor(UVX * numberDivisions));
	if(segment % 2 == 0){
		return colorDashA;
	}
	else{
		return colorDashB;
	}
}

// Adds an offset to the color as a linear function in mx+b form (retain alpha channel)
vec4 addLinearFunctionAmount(vec4 inputColor, float UVX, float linearConstant, float linearSlope) {
	return vec4(inputColor.xyz + (linearConstant + UVX*linearSlope), inputColor.w);
}

void vertex() {
	// Called for every vertex the material is visible on.
	//VERTEX = VERTEX + (vec2(100.0 * cos(TIME), 100.0 * sin(TIME))); // funni
}



uniform vec4 colorA = vec4(1,1,1,1);
uniform vec4 colorB = vec4(1,1,1,1);
uniform float numDivisions = 100.0;
uniform float linConstant = 0.0;
uniform float linSlope = 0.0;

void fragment() {
	COLOR = dashedLine(UV.x, numDivisions, colorA, colorB); // Dashed Line
	COLOR = addLinearFunctionAmount(COLOR, UV.x, linConstant, linSlope); // Color Offset from highlighting
}



//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
