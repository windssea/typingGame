extends SceneTree
class GlyphProbe extends Control:
 var value:="a"
 var card:=Rect2(8,8,78,74)
 var preferred:=48
 func _draw() -> void:
  var layout:=TypingPrompt.key_layout(card,value,preferred)
  TypingPrompt.glyph(self,value,layout.baseline,layout.font,Color("18384f"),0,true)
class KeySheet extends Control:
 func _draw() -> void:
  draw_rect(Rect2(0,0,960,420),Color("254252"))
  var chars:=["a","c","e","j","g","p","A","F","1",";","?","空格"]
  for i in range(chars.size()):
   var at:=Vector2(28+(i%6)*156,24+(i/6)*188)
   TypingPrompt.key(self,Rect2(at,Vector2(110,104)),chars[i],58 if chars[i]!="空格" else 36)
   draw_string(TypingPrompt.FONT,at+Vector2(0,134),chars[i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:exercise.call_deferred()
func exercise() -> void:
 var chars:="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789;,.?/!@#$%&*()-_=+[]{}:'\""
 var worst:=0.0
 for font_size in [32,48,64]:
  for value in chars:
   var rect:=Rect2(8,8,78,74);var layout:=TypingPrompt.key_layout(rect,value,font_size)
   var rendered: Rect2=Rect2(layout.baseline+layout.ink.position,layout.ink.size)
   check(rendered.get_center().distance_to(layout.face.get_center())<.01,"ink centers on raised face: "+value)
   check(rect.grow(-5).encloses(rendered),"ascender and descender fit inside face: "+value)
 if DisplayServer.get_name()!="headless":
  var viewport:=SubViewport.new();viewport.size=Vector2i(96,96);viewport.transparent_bg=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
  var probe:=GlyphProbe.new();viewport.add_child(probe)
  for value in ["a","c","e","j","g","p","A","F","1",";","?","空格"]:
   probe.value=value;probe.preferred=28 if value=="空格" else 48;probe.queue_redraw()
   await process_frame;RenderingServer.force_draw()
   var im:=viewport.get_texture().get_image();var minimum:=Vector2(96,96);var maximum:=Vector2(-1,-1)
   for y in range(96):
    for x in range(96):
     var c:=im.get_pixel(x,y)
     if c.a>.75 and absf(c.r-.094)<.035 and absf(c.g-.22)<.035 and absf(c.b-.31)<.035:
      minimum=minimum.min(Vector2(x,y));maximum=maximum.max(Vector2(x,y))
   var layout:=TypingPrompt.key_layout(probe.card,value,probe.preferred)
   var error: float=((minimum+maximum+Vector2.ONE)*.5-layout.face.get_center()).length()
   worst=maxf(worst,error)
   check(maximum.x>=minimum.x and error<=2.2,"actual raster ink is visually centered: "+value+" "+str(error))
  viewport.queue_free();await process_frame
  root.content_scale_size=Vector2i(960,420);root.size=Vector2i(960,420);var sheet:=KeySheet.new();root.add_child(sheet)
  await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png("res://build/v24-keycap-alignment.png")
 print("KEYCAP ALIGNMENT: %d checks; %d failures; raster error %.2fpx"%[checks,failures,worst]);quit(1 if failures else 0)
