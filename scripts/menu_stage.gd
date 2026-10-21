class_name MenuStage
extends Control

var home := false
var settings_room := false
var reduced_motion := false
var clock := 0.0
var lobby: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ContentPackLoader.enabled() or home:
		lobby=load("res://assets/menu-v20/settings.png" if settings_room else "res://assets/menu-v20/lobby.png")
		if home:
			var atmosphere:=ShaderMaterial.new();atmosphere.shader=preload("res://shaders/home_world.gdshader")
			atmosphere.set_shader_parameter("motion",0.0 if reduced_motion else 1.0);material=atmosphere
		return
	if ResourceLoader.exists("res://assets/generated/academy-lobby-v10.png"):
		lobby = load("res://assets/generated/dojo-background.png" if settings_room else "res://assets/generated/academy-lobby-v10.png")

func _process(delta: float) -> void:
	if not reduced_motion:
		clock += delta
		if material!=null:material.set_shader_parameter("clock",clock)
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
		draw_style_box(PlayTheme.surface(Color(.8,.93,.89,.48),Color.TRANSPARENT,18),Rect2(270,18,1148,864))
		draw_rect(Rect2(0,0,260,900),Color(.75,.89,.82,.18))
	if settings_room:
		draw_rect(Rect2(0,0,260,900),Color(.75,.89,.82,.9))
	if not reduced_motion:
		for i in range(10):
			var p := Vector2(45+fposmod(i*157.0+sin(clock*.5+i)*12,1340),700+sin(clock*.7+i*2)*90)
			draw_circle(p,2+i%2,Color(1,.94,.65,.22+sin(clock+i)*.12))
		if home:
			for i in range(3):
				var p:=Vector2(fposmod(clock*(7+i*4)+i*670,1900)-340,240+i*85)
				draw_texture_rect(WorldAtmosphere.CLOUD,Rect2(p,Vector2(340+i*60,110+i*20)),false,Color(1,1,1,.26))
	# Grounding and a quiet frame, not a webpage sidebar.
	if not home:draw_line(Vector2(26,880),Vector2(1414,880),Color(1,1,1,.6),2,true)
