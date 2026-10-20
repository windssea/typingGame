shader_type canvas_item;
uniform vec4 tint : source_color = vec4(.84,.93,.88,1.);
uniform float shelf_start = .40;
uniform float shelf_end = .70;

void fragment() {
	vec4 art = texture(TEXTURE,UV);
	// A painted title shelf belongs to the illustration; no white web-card backing.
	art.rgb = mix(art.rgb,tint.rgb,smoothstep(shelf_start,shelf_end,UV.y)*.97);
	vec2 q = abs(UV-.5)-vec2(.465,.455);
	float distance = length(max(q,vec2(0.))) + min(max(q.x,q.y),0.)-.035;
	art.a *= 1.-smoothstep(-.002,.002,distance);
	COLOR = art;
}
