class_name HomeHeading
extends Control

var title := "指尖挑战"
var brand := false
var training := true
const FONT = preload("res://assets/ui-heading.ttf")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var font_size:=92 if brand else 36
	var bounds:=TypingPrompt.ink_bounds(title,font_size)
	var at:=size*.5-bounds.get_center()
	if brand:
		draw_string_outline(FONT,at+Vector2(0,6),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,10,Color("204e65"))
		draw_string_outline(FONT,at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color("547c82"))
		draw_string(FONT,at+Vector2(0,2),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d4a14d"))
		draw_string(FONT,at-Vector2(0,1),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff2c7"))
		for side in [-1,1]:
			GameGlyph.draw(self,"star",Vector2(size.x*.5+side*(bounds.size.x*.5+34),size.y*.5),13,Color("ffdb84"))
	else:
		var rect:=Rect2((size-Vector2(316,64))*.5,Vector2(316,64))
		TypingPrompt.material_frame(self,rect,false,true,false,0,"restaurant" if training else "castle")
		TypingPrompt.glyph(self,title,at,font_size,Color("285668") if training else Color("fff0c7"),0,training)
