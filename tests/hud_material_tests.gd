extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:exercise.call_deferred()
func exercise()->void:
 for entry in Vocabulary.data().entries:
  var paragraph:=TextParagraph.new()
  for font_size in range(24,17,-1):
   paragraph.clear();paragraph.add_string(entry.meaning,GameHudSkin.FONT,font_size);paragraph.width=356
   if paragraph.get_size().y<=66:break
  check(paragraph.get_size().y<=66,"complete vocabulary meaning fits the physical panel: "+entry.text)
 var app:Control=load("res://scenes/main.tscn").instantiate()
 var path:String="user://hud-v24-%d.json"%Time.get_ticks_usec();app.store.path=path;app.store.data.settings.sound=false;root.add_child(app);await process_frame
 app.set_process(false)
 for lesson in [0,5,9]:
  app.lesson_index=lesson
  for mode in GameContent.modes():
   app.start_game(mode.id,"challenge");app.run.paused=true
   for i in range(4):await process_frame
   var title:GameHudTitle=app.layer.find_children("*","GameHudTitle",true,false)[0]
   check(title.title==mode.name and title.size.y>=60,"title is an actual material widget: "+mode.id)
   if mode.id!="dojo":
    check(app.live_hud.values.size()==4,"live semantic data remains event-driven: "+mode.id)
    var cue:ActionCue=app.layer.find_child("InputDock",true,false)
    check(cue!=null and cue.size.x>=1350,"guide/definition/skill share one protected dock: "+mode.id)
   for control in app.layer.find_children("*","Button",true,false):
    if control.text in ["F1 指法","全屏","暂停 Esc"]:
     check(control.theme_type_variation=="HudButton","commands use physical HUD button skin: "+mode.id)
 app.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("HUD MATERIALS: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
