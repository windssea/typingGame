class_name GameChrome
extends Control

var background: Texture2D
var top_shade: GradientTexture2D
var bottom_shade: GradientTexture2D
var world: TextureRect
var scenery: TextureRect
var full_world := true

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	scenery=TextureRect.new();scenery.texture=background
	scenery.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenery.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scenery.show_behind_parent=true
	add_child(scenery)
	for bottom in [false,true]:
		var gradient:=Gradient.new()
		gradient.colors=PackedColorArray([Color(.035,.12,.19,.88),Color(.035,.12,.19,.62),Color(.035,.12,.19,0)])
		gradient.offsets=PackedFloat32Array([0,.62,1])
		var texture:=GradientTexture2D.new();texture.gradient=gradient
		texture.fill_from=Vector2(0,1 if bottom else 0)
		texture.fill_to=Vector2(0,0 if bottom else 1)
		if bottom: bottom_shade=texture
		else: top_shade=texture

func _draw() -> void:
	if top_shade!=null: draw_texture_rect(top_shade,Rect2(0,0,size.x,142),false)
	if bottom_shade!=null: draw_texture_rect(bottom_shade,Rect2(0,size.y-137,size.x,137),false)
	# The HUD belongs to the world: a restrained metal edge, no opaque page-sized slabs.
	SoftStroke.line(self,Vector2(40,111),Vector2(size.x-40,111),Color(.95,.81,.49,.55),1.5)
	SoftStroke.line(self,Vector2(40,size.y-122),Vector2(size.x-40,size.y-122),Color(.95,.81,.49,.45),1.5)

func _process(_delta: float) -> void:
	if not is_instance_valid(world): return
	# The stage and the HUD share one aspect-preserving image frame. Sampling a
	# smaller stage outside its UVs used to stretch edge pixels into long stripes.
	scenery.material=world.material
	if full_world:
		world.set_meta("viewport_backdrop",true)
		world.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var to_parent: Transform2D=world.get_parent().get_global_transform().affine_inverse()*get_global_transform()
		world.position=to_parent*Vector2.ZERO
		world.size=size*to_parent.get_scale().abs()
	else:
		if world.has_meta("viewport_backdrop"): world.remove_meta("viewport_backdrop")
