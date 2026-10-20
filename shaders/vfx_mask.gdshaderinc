uniform vec4 protected_rects[32];
uniform int protected_count = 0;
varying vec2 world_position;

bool covers_prompt(vec2 point) {
	for (int i = 0; i < 32; i++) {
		if (i >= protected_count) { break; }
		vec4 r = protected_rects[i];
		if (point.x >= r.x && point.y >= r.y && point.x <= r.z && point.y <= r.w) { return true; }
	}
	return false;
}
