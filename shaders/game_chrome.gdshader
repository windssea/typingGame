shader_type canvas_item;
uniform vec2 canvas_size=vec2(1440.0,900.0);
uniform vec2 world_origin=vec2(40.0,120.0);
uniform vec2 world_size=vec2(1360.0,650.0);
uniform vec2 source_size=vec2(1536.0,1024.0);
void fragment(){
	float factor=max(world_size.x/source_size.x,world_size.y/source_size.y);
	vec2 image_size=source_size*factor;
	vec2 image_origin=world_origin+(world_size-image_size)*0.5;
	vec2 uv=(UV*canvas_size-image_origin)/image_size;
	uv=(uv-0.5)*0.988+0.5;
	COLOR=texture(TEXTURE,clamp(uv,vec2(0.001),vec2(0.999)));
}
