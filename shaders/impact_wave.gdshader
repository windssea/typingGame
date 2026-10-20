shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://shaders/vfx_mask.gdshaderinc"
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform int shape = 0;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	if (covers_prompt(world_position)) { discard; }
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float expansion = mix(0.08, 0.88, 1.0-pow(1.0-progress, 2.0));
	float wave = exp(-pow((radius-expansion)*30.0, 2.0));
	float core = exp(-radius*radius*22.0)*(1.0-progress)*0.7;
	float rays = pow(max(0.0,cos(angle*7.0+radius*6.0)),12.0)*exp(-radius*5.0)*(1.0-progress);
	if (shape == 1) {
		// A curved sword / punch streak, with a quick bright contact and tapered ends.
		wave *= smoothstep(-0.8,-0.3,angle)*(1.0-smoothstep(1.4,2.3,angle));
	} else if (shape == 2) {
		wave *= 0.65;
		core *= 0.3;
		rays = 0.0;
	} else if (shape == 3) {
		wave = 0.0;
		core = exp(-radius*radius*8.0)*1.6;
		rays = 0.0;
	} else {
		wave *= 0.45+0.55*pow(abs(sin(angle*3.0+0.5)),2.0);
	}
	float alpha = clamp((wave*0.6+core+rays)*(1.0-progress),0.0,0.75)*tint.a;
	COLOR = vec4(tint.rgb,alpha);
}
