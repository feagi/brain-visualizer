shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform vec4 colorA = vec4(1,1,1,1);
uniform vec4 colorB = vec4(1,1,1,1);
uniform float numDivisions = 100.0;

void fragment() {
	int segment = int(floor(UV.x * numDivisions));
	if(segment % 2 == 0){
		COLOR = colorA;
	}
	else{
		COLOR = colorB;
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
