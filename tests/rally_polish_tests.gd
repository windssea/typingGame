extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(message)
func _initialize() -> void: exercise.call_deferred()
func make_run() -> ArcadeRun:
 var run:=ArcadeRun.new();run.context="challenge";run.setup("racing",GameContent.lessons()[0],1,6)
 return run
func type_word(run: ArcadeRun) -> void:
 var target:=run.recommended_target()
 for letter in str(target.word): run.type_character(letter)
func exercise() -> void:
 for fps in [30,60,120]:
  var plain:=make_run();var nitro:=make_run();nitro.skill_charge=3;nitro.rival=.4
  check(nitro.activate_skill() and nitro.rival==.4 and nitro.distance==0,"nitro starts on player; neither car teleports")
  type_word(plain);type_word(nitro)
  check(is_equal_approx(nitro.distance,plain.distance*1.35),"skill grants 35% extra actual advance on a completed word")
  var before:=nitro.distance
  for i in range(fps): nitro.step(1.0/fps)
  check(nitro.distance==before and nitro.rival>.4,"incomplete typing never produces free race progress")
  var rival:=nitro.rival;var time:=nitro.skill_time;nitro.paused=true;nitro.step(.5)
  check(nitro.rival==rival and nitro.skill_time==time,"pause freezes skill and rival")
  nitro.paused=false
  for i in range(fps*4): nitro.step(1.0/fps)
  check(nitro.skill_time==0 and nitro.boost==0,"nitro returns to rest")
 for name in ["rally-mint-idle-v24","rally-mint-boost-v24","rally-coral-idle-v24"]:
  var frames: SpriteFrames=load("res://assets/animations/"+name+"/idle.tres")
  var state: StringName=frames.get_animation_names()[0]
  check(frames.get_animation_speed(state)==24,"native 24fps retained")
  for i in range(frames.get_frame_count(state)):
   var texture: AtlasTexture=frames.get_frame_texture(state,i)
   check(texture.region.size==Vector2(384,384),"HD common canvas")
 var app: Control=load("res://scenes/main.tscn").instantiate()
 var path: String="user://rally-v24-%d.json"%Time.get_ticks_usec()
 app.store.path=path;app.store.data.settings.sound=false;root.add_child(app);await process_frame
 app.set_process(false);app.lesson_index=5
 for mode in ["racing","submarine","fighter","royal","restaurant","rain","balloons","moles","aliens","sprint","bubbles","castle"]:
  app.start_game(mode,"challenge")
  if mode=="castle": app.run.begin_wave()
  app.run.paused=true
  for i in range(5):await process_frame
  var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
  var chrome: GameChrome=app.layer.find_children("*","GameChrome",true,false)[0]
  check(arena.backdrop.get_global_rect().is_equal_approx(chrome.get_global_rect()),"world and outer scenery share full viewport crop: "+mode)
  check(chrome.scenery.material==arena.backdrop.material,"continuous background shader and lighting: "+mode)
  if mode=="racing":
   check(arena.native_vfx.racing_exhaust.size()==3,"bounded native smoke/nitro pool")
   for lane in range(2):
    for fraction in [0.0,.5,1.0]:
     var at: Vector2=arena.track_point(fraction,lane)
     check(Rect2(Vector2.ZERO,arena.size).has_point(at),"car and finish stay inside actual race viewport")
   app.run.skill_charge=3;app.run.paused=false;app.run.activate_skill();arena.native_vfx._process(.016)
   check(arena.native_vfx.racing_exhaust[2].emitting and arena.native_vfx.nitro_light.enabled,"nitro owns an actual native emitter and light")
   app.run.paused=true;arena.native_vfx._process(.016)
   check(arena.native_vfx.racing_exhaust.all(func(p):return p.speed_scale==0),"pause freezes native exhaust")
   arena.reduced_motion=true;arena.native_vfx._process(.016)
   check(not arena.native_vfx.nitro_light.enabled and arena.native_vfx.racing_exhaust.all(func(p):return not p.emitting),"reduced motion disables native exhaust and light")
 app.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("RALLY V24: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
