class_name CourseStamp
extends Control

const FONT = preload("res://assets/ui-font.ttf")
var number := 1
var mastered := false
var active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var tint := Color("dbefd4") if mastered else Color("ffe6a2") if active else Color("e8f3f7")
	draw_circle(Vector2(27,30),26,tint.darkened(.15))
	draw_circle(Vector2(27,26),26,tint)
	draw_arc(Vector2(27,26),21,PI*1.05,PI*1.8,24,Color(1,1,1,.8),2,true)
	if mastered:
		GameGlyph.draw(self,"star",Vector2(27,26),14,PlayTheme.TEAL)
	else:
		var value := "%02d" % number
		draw_string(FONT,Vector2(27-FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x/2,34),value,HORIZONTAL_ALIGNMENT_LEFT,-1,21,PlayTheme.TEXT)
