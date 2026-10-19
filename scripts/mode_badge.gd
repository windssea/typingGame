class_name ModeBadge
extends Control

var mode := "dojo"
var reduced_motion := false
var clock := 0.0
var art := GeneratedArt.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.setup(mode)

func _process(delta: float) -> void:
	if not reduced_motion:
		clock += delta
		queue_redraw()

func _draw() -> void:
	var sprite: String = {"balloons":"balloon_coral","aliens":"ufo","moles":"mole","racing":"car_mint","fighter":"boxer_blue","castle":"tower_fire"}.get(mode,"")
	if art.sprites.has(sprite):
		var bob := 0.0 if reduced_motion else sin(clock*2.5)*3
		draw_circle(size/2,30,Color(1,1,1,0.85))
		art.draw_sprite(self,sprite,size/2+Vector2(0,bob),Vector2(86,74))
		return
	draw_set_transform(size/2,0,Vector2.ONE*minf(1.0,size.x/120.0))
	var c := Vector2.ZERO
	var gold := PlayTheme.YELLOW
	var mint := PlayTheme.MINT
	draw_circle(c,39,Color(1,1,1,0.78))
	if mode == "dojo":
		for i in range(3):
			draw_style_box(PlayTheme.surface([PlayTheme.SKY,gold,mint][i],Color.WHITE,8),Rect2(c+Vector2(-54+i*37,-18),Vector2(31,34)))
			draw_line(c+Vector2(-46+i*37,9),c+Vector2(-31+i*37,9),PlayTheme.TEXT,2,true)
	elif mode == "bubbles":
		for i in range(5):
			var p := c+Vector2(cos(i*2.4)*43,sin(i*2.4)*25)
			draw_circle(p,13+i,Color(0.45,0.77,0.72,0.14))
			draw_arc(p,13+i,0,TAU,24,mint,1.5,true)
			draw_circle(p+Vector2(-4,-5),2,gold)
	elif mode == "rain":
		for i in range(3):
			var p := c+Vector2(-38+i*38,-20+i*14)
			draw_line(p-Vector2(15,25),p,PlayTheme.SKY,3,true)
			draw_circle(p,10,gold)
	elif mode == "sprint":
		draw_circle(c,28,Color("fff0cd"))
		draw_arc(c,29,0,TAU,48,PlayTheme.PRIMARY,4,true)
		draw_line(c,c+Vector2(0,-18),mint,3,true)
		draw_line(c,c+Vector2(13,8),mint,3,true)
		draw_line(c+Vector2(-8,-37),c+Vector2(8,-37),gold,5,true)
	elif mode == "balloons":
		for i in range(3):
			var p := c+Vector2(-25+i*25,-9+(i%2)*10)
			draw_line(p,p+Vector2(0,34),mint,1,true)
			draw_circle(p,15,[PlayTheme.CORAL,mint,gold][i])
			draw_circle(p+Vector2(-4,-5),3,Color(1,1,1,0.8))
	elif mode == "aliens":
		draw_circle(c-Vector2(0,10),20,mint)
		draw_style_box(PlayTheme.surface(PlayTheme.LILAC,Color.TRANSPARENT,8),Rect2(c-Vector2(38,0),Vector2(76,14)))
		for x in [-8,8]:
			draw_circle(c+Vector2(x,-12),3,Color("10232a"))
	elif mode == "moles":
		draw_circle(c,25,Color("ac866b"))
		for x in [-10,10]:
			draw_circle(c+Vector2(x,-6),3,Color("10232a"))
		draw_circle(c+Vector2(0,4),5,gold)
		draw_arc(c,30,0,PI,24,mint,4,true)
	elif mode == "racing":
		for x in [-21,21]:
			for y in [-18,18]:
				draw_rect(Rect2(c+Vector2(x-7,y-4),Vector2(14,8)),gold)
		draw_rect(Rect2(c-Vector2(36,17),Vector2(72,34)),mint)
		draw_rect(Rect2(c-Vector2(8,12),Vector2(23,24)),Color("10232a"))
	elif mode == "fighter":
		for side in [-1,1]:
			var p := c+Vector2(side*24,0)
			draw_circle(p,20,PlayTheme.SKY if side==-1 else PlayTheme.CORAL)
			draw_rect(Rect2(p+Vector2(-12,10),Vector2(24,18)),mint)
	else:
		draw_rect(Rect2(c+Vector2(-42,-9),Vector2(84,39)),Color("f3dca7"))
		for x in [-38,0,38]:
			draw_rect(Rect2(c+Vector2(x-10,-25),Vector2(20,54)),Color("ffe9b6"))
			draw_colored_polygon(PackedVector2Array([c+Vector2(x-16,-25),c+Vector2(x,-45),c+Vector2(x+16,-25)]),PlayTheme.LILAC)
		draw_rect(Rect2(c+Vector2(-8,9),Vector2(16,21)),Color("15292d"))
