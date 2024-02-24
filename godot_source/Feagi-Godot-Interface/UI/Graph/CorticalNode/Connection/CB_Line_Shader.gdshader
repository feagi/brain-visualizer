shader_type canvas_item;



// Adds dashes to line
vec4 dashedLine(vec4 colorIn, float UVX, float numberDivisions){
	int segment = int(floor(UVX * numberDivisions));
	if(segment % 2 == 0){
		return colorIn;
	}
	else{
		return vec4(colorIn.xyz, 0.0);
	}
}

// Adds an offset to the color as a linear function in mx+b form (retain alpha channel)
vec4 addLinearFunctionAmount(vec4 inputColor, float UVX, float linearConstant, float linearSlope) {
	return vec4(inputColor.xyz + (linearConstant + UVX*linearSlope), inputColor.w);
}

// Technically instead of having 2 bounds and 2 checks, we could use a single comparitor if we check for negatives of a quadratic function, whose constants could be derived via crammers rule for a more optimized system. But I don't have time for such a micro-optimization :3
vec4 addHighLighting(vec4 inputColor, float UVY, float lowerBound, float UpperBound, vec4 highLightColor) {
	if (UVY < lowerBound) { return highLightColor; }
	if (UVY > UpperBound) { return highLightColor; }
	return inputColor;
}

uniform vec4 baseColor = vec4(1,1,1,1);
uniform vec4 colorHighLight = vec4(1,1,1,1);
uniform bool isOutlined = false;
uniform bool isDashed = true;
uniform float numDivisions = 100.0;
uniform float linConstant = 0.0;
uniform float linSlope = 0.0;
const float highlightLowerBound = 0.2;
const float highlightUpperBound = 0.8;

void vertex() {
	// Called for every vertex the material is visible on.
	//if(isHighlighted) {
		//VERTEX.y += 2.0 * sin(TIME * 10.0 + (1.0 * VERTEX.x));
	//}
}

void fragment() {
	COLOR = baseColor;
	COLOR = addLinearFunctionAmount(COLOR, UV.x, linConstant, linSlope); // Color Offset from brightning ends
	if (isDashed) {
		COLOR = dashedLine(COLOR, UV.x, numDivisions);
	}
	if (isOutlined){
		COLOR = addHighLighting(COLOR, UV.y, highlightLowerBound, highlightUpperBound, colorHighLight);
	}
}



//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
