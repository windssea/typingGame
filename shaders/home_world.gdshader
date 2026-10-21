shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float motion=1.0;
void fragment(){
 vec2 uv=UV;
 // Subpixel atmospheric shimmer stays in the distant landscape, never on UI.
 float far= smoothstep(.25,.48,uv.y)*(1.0-smoothstep(.64,.76,uv.y));
 uv.x+=sin(uv.y*32.0+clock*.7)*.0007*far*motion;
 vec4 tex=texture(TEXTURE,uv)*COLOR;
 float light=(sin(clock*.35+UV.x*3.0)*.009+.009)*motion;
 tex.rgb+=vec3(1.0,.86,.56)*light*tex.a;
 COLOR=tex;
}
