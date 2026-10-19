class_name PlayfulArt
extends Control

var variant := "friends"
const FONT = preload("res://assets/ui-font.ttf")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func star(p: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append(p+Vector2.from_angle(-PI/2+i*PI/5)*radius*(1.0 if i%2==0 else 0.45))
	draw_colored_polygon(points,color)

func friend(p: Vector2, color: Color, letter: String, tilt: float) -> void:
	draw_set_transform(p,tilt)
	draw_line(Vector2(-30,16),Vector2(-53,1),PlayTheme.TEXT,5,true)
	draw_line(Vector2(31,15),Vector2(48,-12),PlayTheme.TEXT,5,true)
	draw_line(Vector2(-15,37),Vector2(-23,53),PlayTheme.TEXT,6,true)
	draw_line(Vector2(16,37),Vector2(28,49),PlayTheme.TEXT,6,true)
	draw_style_box(PlayTheme.surface(color.darkened(0.12),Color.TRANSPARENT,18),Rect2(-37,-32,74,79))
	draw_style_box(PlayTheme.surface(color,Color.WHITE,18),Rect2(-37,-38,74,73))
	draw_string(FONT,Vector2(-7,-10),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,21,PlayTheme.TEXT)
	for x in [-12,12]:
		draw_circle(Vector2(x,5),3.2,PlayTheme.TEXT)
		draw_circle(Vector2(x*1.7,13),5,Color(1,0.48,0.5,0.3))
	draw_arc(Vector2(0,12),8,0.2,PI-0.2,16,PlayTheme.TEXT,2.5,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if variant == "background":
		draw_circle(Vector2(1390,25),180,Color("edf3ff"))
		draw_circle(Vector2(280,900),140,Color("eef7f3"))
		return
	if variant == "friends":
		draw_circle(Vector2(140,70),64,Color("e4edfd"))
		star(Vector2(25,28),13,PlayTheme.YELLOW)
		star(Vector2(255,100),11,PlayTheme.CORAL)
		draw_arc(Vector2(244,36),11,0,TAU,24,PlayTheme.MINT,4,true)
		friend(Vector2(92,68),PlayTheme.YELLOW,"F",-0.13)
		friend(Vector2(186,65),PlayTheme.SKY,"J",0.14)
	else:
		star(Vector2(145,35),14,PlayTheme.YELLOW)
		friend(Vector2(90,75),PlayTheme.MINT,"K",-0.1)
