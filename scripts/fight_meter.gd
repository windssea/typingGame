class_name FightMeter
extends RefCounted

static var blue: GradientTexture2D
static var coral: GradientTexture2D
static var gold: GradientTexture2D

static func ramp(top: Color, middle: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.4,1])
	gradient.colors = PackedColorArray([top,middle,bottom])
	var texture := GradientTexture2D.new()
	texture.width=8;texture.height=32;texture.gradient=gradient
	texture.fill_from=Vector2(.5,0);texture.fill_to=Vector2(.5,1)
	return texture

static func paint(canvas: CanvasItem, rect: Rect2, health: float, trail: float, side: int) -> void:
	if blue==null:
		blue=ramp(Color("b1f4ed"),Color("38bdbd"),Color("1d7394"))
		coral=ramp(Color("ffd5b5"),Color("f27979"),Color("ba3e66"))
		gold=ramp(Color("fff5c1"),Color("ffd17f"),Color("b88038"))
	TypingPrompt.material_frame(canvas,rect,false,true,false,0,"fighter")
	var inside := rect.grow(-7)
	canvas.draw_rect(inside,Color("122d43"))
	for layer in range(2):
		var fraction := clampf((trail if layer==0 else health)/100.0,0,1)
		if fraction<=0: continue
		var fill := Rect2(inside.position,Vector2(inside.size.x*fraction,inside.size.y))
		if side==1: fill.position.x=inside.end.x-fill.size.x
		canvas.draw_texture_rect(gold if layer==0 else blue if side==0 else coral,fill,false)
	for i in range(1,10):
		var x := inside.position.x+inside.size.x*i/10.0
		canvas.draw_line(Vector2(x,inside.position.y+2),Vector2(x,inside.end.y-1),Color(.04,.13,.19,.24),1,true)
	canvas.draw_line(inside.position+Vector2(1,1),Vector2(inside.end.x-1,inside.position.y+1),Color(1,1,1,.28),1,true)
