class_name GameHudSkin
extends RefCounted
const FONT=preload("res://assets/ui-heading.ttf")
const TEXTURE=preload("res://assets/generated/v24/ui-hud-plates.png")
const REGIONS=[Rect2(34,88,1020,278),Rect2(1082,90,982,274),Rect2(34,408,1010,266),Rect2(1078,408,986,266)]
static func panel(canvas: CanvasItem, rect: Rect2, role:=1, tint:=Color.WHITE) -> void:
 var src:Rect2=REGIONS[clampi(role,0,3)]
 var sx=[src.position.x,src.position.x+96,src.end.x-96,src.end.x]
 var sy=[src.position.y,src.position.y+48,src.end.y-48,src.end.y]
 var edge:=minf(12,minf(rect.size.x,rect.size.y)*.2)
 var dx=[rect.position.x,rect.position.x+edge,rect.end.x-edge,rect.end.x]
 var dy=[rect.position.y,rect.position.y+edge,rect.end.y-edge,rect.end.y]
 for y in range(3):
  for x in range(3):canvas.draw_texture_rect_region(TEXTURE,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y]),tint)
static func text(canvas: CanvasItem, value: String, rect: Rect2, preferred:=24, tint:=Color("fff0d0"), centered:=false, dark:=true) -> void:
 var font_size:=preferred
 while font_size>16 and FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x:font_size-=1
 var ink:=TypingPrompt.ink_bounds(value,font_size)
 var at:=Vector2(rect.get_center().x-ink.get_center().x if centered else rect.position.x-ink.position.x,rect.get_center().y-ink.get_center().y)
 if dark:canvas.draw_string_outline(FONT,at+Vector2(0,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(.02,.12,.18,.65))
 canvas.draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
static func caption(canvas: CanvasItem, value: String, rect: Rect2, preferred:=24, role:=1) -> void:
 panel(canvas,rect,role)
 text(canvas,value,rect.grow(-minf(14,rect.size.x*.12)),preferred,Color("274657") if role==2 else Color("fff0d0"),true,role!=2)
