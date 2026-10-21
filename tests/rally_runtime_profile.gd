extends SceneTree
func _initialize() -> void:sample.call_deferred()
func percentile(values: Array[float], fraction: float) -> float:
 var sorted:=values.duplicate();sorted.sort();return sorted[clampi(ceili(sorted.size()*fraction)-1,0,sorted.size()-1)]
func sample() -> void:
 var app:Control=load("res://scenes/main.tscn").instantiate();var path: String="user://rally-profile-%d.json"%Time.get_ticks_usec()
 app.store.path=path;app.store.data.settings.sound=false;root.add_child(app);await process_frame
 app.lesson_index=0;app.start_game("racing","challenge");var run:ArcadeRun=app.run
 var arena:ArcadeArena=app.layer.find_children("*","ArcadeArena",true,false)[0]
 for i in range(240):
  if is_instance_valid(app.overlay):app.close_modal()
  run.paused=false;await process_frame
 var frames:Array[float]=[];var draws:Array[float]=[];var previous:=Time.get_ticks_usec();var start:=previous;var active_start:=run.elapsed
 for i in range(180):
  if is_instance_valid(app.overlay):app.close_modal()
  run.paused=false
  if i%40==0:
   var t:=run.recommended_target()
   for ch in str(t.word):run.type_character(ch)
  if i==80:run.skill_charge=3;run.activate_skill()
  await process_frame
  var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 var report:Dictionary={"scope":"local native release resources, two animated drivers with ongoing typing/sonar-free nitro; not browser/mobile or all-hardware guarantee","gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"samples":180,"fps":180.0/((Time.get_ticks_usec()-start)/1000000.0),"frame_p50_ms":percentile(frames,.5),"frame_p95_ms":percentile(frames,.95),"draw_calls_p95":percentile(draws,.95),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"active_seconds":run.elapsed-active_start,"native_vfx":arena.native_vfx.snapshot()}
 assert(not run.paused and not run.done and report.active_seconds>2,"must sample an active game")
 FileAccess.open("res://build/v24-native-performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 app.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 quit()
