shader_type canvas_item;
// This is a shader, NOT GDSCRIPT

// inputs
uniform vec2 ballPos = vec2(0.5f, 0.5f);
uniform float paddleHWidth = 0.1f;
uniform float paddlePosX = 0.5f;
uniform bool isCurrentlyShocking = false;
uniform bool isCurrentlyRewarding = false;
uniform vec4 rewardColor = vec4(1.0f, 0.0f, 0.0f, 0.0f);


vec4 RenderReward(vec4 colIn, vec2 uv)
{
    const float scale = 10.0; // Adjust for desired checker size

    // Calculate screen position based on the UV and resolution
    vec2 screenPos = vec2(uv.x * 400.0, uv.y * 400.0);

    int checkX = int(screenPos.x / scale) % 2;
    int checkY = int(screenPos.y / scale) % 2;

    float checkerValue = float(checkX ^ checkY);

    float pulseEffect = ceil(sin(300.0 * TIME));
    checkerValue *= pulseEffect;

    return colIn + (rewardColor * checkerValue);
}


vec4 RenderBox(vec2 pos, vec2 hSize, vec4 colBox, vec4 colIn, vec2 uvCoord){
	if(uvCoord.x < (pos.x - hSize.x)) {return colIn; }
	if(uvCoord.x > (pos.x + hSize.x)) {return colIn; }
	if(uvCoord.y < (pos.y - hSize.y)) {return colIn; }
	if(uvCoord.y > (pos.y + hSize.y)) {return colIn; }
	return colBox;
}

uniform float screen_width : hint_range(1, 400);
uniform float screen_height : hint_range(1, 400);


// Pseudo-random function definition
float rand(vec2 n) {
	return fract(sin(dot(n.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec4 Noise(vec2 uv) {
	const float CheckerSizeX = 25.0;
	const float CheckerSizeY = 25.0;
	
	// loop UV so we more of a checkerboard pattern
	uv = vec2( (float(floor(uv.x * CheckerSizeX)) * 0.01), (float(floor(uv.y * CheckerSizeY)) * 0.01));
	
	float ranR = rand(uv * TIME);
	float ranG = rand(uv * tan(TIME));
	float ranB = rand(uv * tan(TIME) + vec2(1,1));
    return vec4(ranR, ranG, ranB, 1.0);
}


vec4 RenderBackground() {
    return vec4(1.0f, 1.0f, 1.0f, 1.0f);
}



// This is the 'Main' function, also known as the frag / pixel
void fragment() {
	const float paddlePosY = 0.975f;
	const float paddleHHeight = 0.025f;
	const vec4 paddleColor = vec4 (1.0f, 1.0f, 1.0f, 1.0f);

	const vec2 ballHSize = vec2(0.025f, 0.025f);
	const vec4 ballColor = vec4(1.0f, 0.0f, 0.0f, 1.0f);

	// Render Background
	COLOR = RenderBackground();

	// Render Paddle
	COLOR = RenderBox( vec2(paddlePosX, paddlePosY), vec2(paddleHWidth, paddleHHeight), paddleColor, COLOR, UV);

	// Render Ball
	COLOR = RenderBox( ballPos, ballHSize, ballColor, COLOR, UV);
	
	// Reward / Punishments
	if(isCurrentlyRewarding) {COLOR = RenderReward(COLOR, UV); }
	if(isCurrentlyShocking) {COLOR = Noise(UV); }
}
