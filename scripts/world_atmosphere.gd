class_name WorldAtmosphere
extends RefCounted

const CLOUD = preload("res://assets/generated/v18/cloud.png")

static func cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	var source := texture.get_size()
	var scale_value := maxf(rect.size.x/source.x,rect.size.y/source.y)
	var crop := rect.size/scale_value
	canvas.draw_texture_rect_region(texture,rect,Rect2((source-crop)*.5,crop))

# Independent scenery layers. Ground geometry and actor coordinates never distort.
static func paint(canvas: CanvasItem, mode: String, clock: float, extent: Vector2, reduced: bool) -> void:
	if reduced: return
	if mode in ["submarine","bubbles"]:
		for i in range(18):
			var p := Vector2(fposmod(i*193.7+sin(clock*.3+i)*18,extent.x),extent.y-fposmod(clock*(14+i%4*6)+i*41,extent.y))
			canvas.draw_circle(p,2+i%3,Color(.65,.94,1,.28))
		for i in range(5):
			var x := fposmod(clock*22+i*277,extent.x+120)-60
			var p := Vector2(x,extent.y*.18+i*22)
			canvas.draw_colored_polygon(PackedVector2Array([p-Vector2(10,0),p+Vector2(8,-3),p+Vector2(8,3)]),Color(.1,.42,.61,.25))
		return
	if mode in ["rain","aliens"]:
		for i in range(26):
			var p := Vector2(fposmod(i*103.7-clock*(3+i%3),extent.x),fposmod(i*71.3,extent.y))
			var alpha := .14+(.5+.5*sin(clock*1.5+i))* .25
			canvas.draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(1,1,1,alpha),1,true)
			canvas.draw_line(p-Vector2(0,3),p+Vector2(0,3),Color(1,1,1,alpha),1,true)
		return
	if mode=="restaurant":
		for i in range(6):
			var p := Vector2(40+i%2*(extent.x-80)+sin(clock+i)*5,extent.y*.55-fposmod(clock*22+i*33,150))
			canvas.draw_circle(p,4+sin(clock+i),Color(1,.9,.7,.18))
		return
	if mode=="royal":
		for i in range(12):
			var p := Vector2(extent.x*.5+sin(i*3.3)*14,fposmod(i*57+clock*30,extent.y))
			canvas.draw_line(p,p+Vector2(7+sin(clock+i)*3,0),Color(.75,.96,1,.30),1.5,true)
	# Drifting petals occupy the periphery; they cross the scene at different depths.
	for i in range(14):
		var p := Vector2(fposmod(i*113.5+clock*(9+i%4*3),extent.x+60)-30,fposmod(i*63+sin(clock*.4+i)*20+clock*3,extent.y))
		if p.x>extent.x*.2 and p.x<extent.x*.8 and p.y>extent.y*.2 and p.y<extent.y*.8: continue
		var axis := Vector2.from_angle(clock*.7+i)* (3+i%3)
		var cross_axis := axis.orthogonal()*.45
		canvas.draw_colored_polygon(PackedVector2Array([p-axis,p-cross_axis,p+axis,p+cross_axis]),Color(1,.9,.55,.45))
	if mode in ["balloons","sprint","racing"]:
		for i in range(3):
			var p := Vector2(fposmod(clock*(5+i*3)+i*extent.x*.4,extent.x+140)-70,45+i*43)
			canvas.draw_texture_rect(CLOUD,Rect2(p,Vector2(200+i*30,67+i*10)),false,Color(1,1,1,.40))
