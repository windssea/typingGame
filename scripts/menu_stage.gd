class_name MenuStage
extends Control

var home := false
var settings_room := false
var reduced_motion := false
var clock := 0.0
var lobby: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/generated/academy-lobby-v10.png"):
		lobby = load("res://assets/generated/dojo-background.png" if settings_room else "res://assets/generated/academy-lobby-v10.png")

func _process(delta: float) -> void:
	if not reduced_motion:
		clock += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),Color("edf8f8"))
	if lobby!=null:
		WorldAtmosphere.cover(self,lobby,Rect2(0,0,1440,900))
	else:
		draw_circle(Vector2(160,750),430,Color("dcf0d4"))
		draw_circle(Vector2(1330,730),420,Color("dceef9"))
	if not home and not settings_room:
		# A quiet wash lets the actual illustration remain visible; individual controls own their framing.
		draw_style_box(PlayTheme.surface(Color(.8,.93,.89,.88),Color.TRANSPARENT,32),Rect2(270,18,1148,864))
		draw_rect(Rect2(0,0,260,900),Color(.75,.89,.82,.45))
	if settings_room:
		draw_rect(Rect2(0,0,260,900),Color(.75,.89,.82,.9))
	if not reduced_motion:
		for i in range(10):
			var p := Vector2(45+fposmod(i*157.0+sin(clock*.5+i)*12,1340),700+sin(clock*.7+i*2)*90)
			draw_circle(p,2+i%2,Color(1,.94,.65,.22+sin(clock+i)*.12))
	# Grounding and a quiet frame, not a webpage sidebar.
	draw_line(Vector2(26,880),Vector2(1414,880),Color(1,1,1,.6),2,true)
