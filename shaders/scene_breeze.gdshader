shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float strength = 1.0;
uniform int world_kind = 0;
uniform float restored = 0.0;

void fragment() {
	vec2 uv = UV;
	float edge = max(1.0-smoothstep(0.0,0.22,uv.x),smoothstep(0.78,1.0,uv.x));
	float sky = 1.0-smoothstep(0.16,0.5,uv.y);
	vec2 sample_uv = (uv-0.5)*0.988+0.5;
	if (world_kind==1 || world_kind==4) {
		sample_uv.x += strength*(sin(clock*1.15+uv.y*15.0)*0.0018*edge+sin(clock*0.14)*0.005*sky);
		sample_uv.y += strength*sin(clock*0.9+uv.x*12.0)*0.0012*edge;
	} else if (world_kind==3) {
		sample_uv += strength*vec2(sin(uv.y*12.0+clock*0.8),cos(uv.x*10.0+clock*0.6))*0.0018;
	} else if (world_kind==2 || world_kind==5) {
		sample_uv.x += strength*sin(clock*0.09)*0.004*sky;
	} else {
		// Hanging pennants and lamps move slightly; the floor stays anchored.
		sample_uv.x += strength*sin(clock*1.25+uv.x*9.0)*0.0015*sky;
		sample_uv.y += strength*sin(clock*1.1+uv.x*7.0)*0.001*sky;
	}
	vec4 source = texture(TEXTURE,clamp(sample_uv,vec2(0.001),vec2(0.999)));
	float light = sin(uv.x*4.0+uv.y*2.0-clock*0.18)*0.012*strength;
	if (world_kind==1 || world_kind==4) {
		light += sin(uv.x*11.0+uv.y*7.0-clock*0.3)*0.012*edge*strength;
	}
	source.rgb *= 1.0+light;
	if (world_kind==5) {
		source.rgb = mix(source.rgb,source.rgb*vec3(1.06,1.025,.97),restored);
	}
	COLOR = source;
}
