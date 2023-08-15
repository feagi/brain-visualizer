shader_type canvas_item;

uniform vec2 offset = vec2(0.4,0.0);
uniform float zoom = 3.0;
uniform float lineThickness = 0.05;
uniform vec4 colorBackground = vec4(0.15,0.1,0.15,1);
uniform vec4 colorLine = vec4(0.9,0.9,0.9,1);

// Get initial UV offset without zoom
vec2 GetOffsetUV(vec2 uv) {
	vec2 UVOffset = offset + uv;
	return UVOffset;
	//return mod(UVOffset, vec2(1.0,1.0));
}

bool IsOnLine(float distFromLine1D, float zoomReciprocal) {
	return distFromLine1D < (zoomReciprocal * lineThickness);
}

bool GetLineMapping(vec2 uv) {
	
	float zoomReciprocal = 1.0 / zoom;
	
	// Apply Zoom
	vec2 distFromLine = mod(GetOffsetUV(uv), vec2(zoomReciprocal, zoomReciprocal));
	
	// Use sin to find regions close to 0 or 1
	distFromLine = sin(PI * distFromLine);
	
	// This is unoptimized branching, fix
	bool isLineX = IsOnLine(distFromLine.x, zoomReciprocal);
	bool isLiney = IsOnLine(distFromLine.y, zoomReciprocal);
	
	return  isLineX || isLiney;
}



void fragment() {
	
	COLOR = colorBackground;
	if(GetLineMapping(UV)) {
		COLOR = colorLine;
	}
}
