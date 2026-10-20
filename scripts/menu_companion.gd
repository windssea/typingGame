class_name MenuCompanion
extends Control

var motion := ArcadeMotion.new()
var clock := 0.0
var reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion.setup("coach",true)

func _process(delta: float) -> void:
	if not reduced_motion:
		clock += delta
		queue_redraw()

func _draw() -> void:
	var frame := motion.texture("idle",clock,reduced_motion)
	if frame!=null:
		var side := minf(size.x,size.y)
		draw_texture_rect(frame,Rect2((size-Vector2.ONE*side)/2,Vector2.ONE*side),false)
