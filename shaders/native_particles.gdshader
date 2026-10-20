shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/vfx_mask.gdshaderinc"

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	if (covers_prompt(world_position)) { discard; }
	COLOR *= texture(TEXTURE, UV);
}
