class_name GameHudTitle
extends Control
var title:=""
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 custom_minimum_size=Vector2(252,68)
func _draw() -> void:
 GameHudSkin.caption(self,title,Rect2(Vector2.ZERO,size),27,0)
