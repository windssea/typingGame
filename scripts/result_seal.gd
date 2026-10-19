class_name ResultSeal
extends Control

var stars := 0
var reduced_motion := false
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if clock<2:
		clock += delta
		queue_redraw()

func _draw() -> void:
	var p := Vector2(45,45)
	draw_circle(p+Vector2(0,4),37,Color("d3ac5a"))
	draw_circle(p,37,Color("ffe6a0"))
	draw_arc(p,30,0,TAU,48,Color("fff6cf"),3,true)
	GameGlyph.draw(self,"star" if stars else "key",p,22,Color("ae7628") if stars else PlayTheme.PRIMARY)
	for i in range(3):
		var phase := clampf((clock-i*.13)/.35,0,1)
		var scale_value := 1.0 if reduced_motion else sin(phase*PI/2)*(1+.12*sin(phase*PI))
		GameGlyph.draw(self,"star",Vector2(12+i*33,101),12*scale_value,Color("dc9c30") if i<stars else Color("d4ddd7"))
