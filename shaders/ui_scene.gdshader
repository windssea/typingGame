shader_type canvas_item;
uniform vec4 tint : source_color = vec4(.84,.93,.88,1.);
uniform float shelf_start = .40;
uniform float shelf_end = .70;

void fragment() {
	vec4 art = texture(TEXTURE,UV);
	// Keep the actual scene visible beneath a quiet, dark title veil.
	float shelf=smoothstep(shelf_start,shelf_end,UV.y);
	art.rgb=mix(art.rgb,art.rgb*vec3(.20,.32,.39)+vec3(.025,.06,.07),shelf*.94);
	vec2 q = abs(UV-.5)-vec2(.487,.487);
	float distance = length(max(q,vec2(0.))) + min(max(q.x,q.y),0.)-.012;
	art.a *= 1.-smoothstep(-.002,.002,distance);
	COLOR = art;
}
