extends SceneTree
func _initialize() -> void: exercise.call_deferred()
func exercise() -> void:
 var app: Control=load("res://scenes/main.tscn").instantiate()
 var profile: String="user://rally-film-%d.json"%Time.get_ticks_usec()
 app.store.path=profile;app.store.data.settings.sound=false;root.add_child(app);await process_frame
 root.size=Vector2i(1440,900);app.lesson_index=5
 var mode: String="racing"
 for option in ["submarine","restaurant","castle","royal","fighter","dojo"]:
  if "--"+option in OS.get_cmdline_user_args(): mode=option
 app.start_game(mode,"challenge");app.set_process(false)
 var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
 arena.set_process(false);arena.native_vfx.set_process(false)
 if mode=="racing":
  app.run.distance=.42;app.run.rival=.48;arena.visual_distance=.42;arena.visual_rival=.48
  app.run.skill_charge=3;app.run.activate_skill();arena.nitro_age=0.0
 elif mode=="submarine":
  app.run.spawn_clock=999
  for i in range(3):
   app.run.targets[i].position=Vector2(700+i*230,180+i*165);app.run.targets[i].speed=20
 if mode=="castle":
  app.run.gold=600
  for i in range(3):app.run.build_tower(i,["fire","ice","storm"][i])
  app.run.begin_wave();app.run.spawn_enemy("goblin").position=Vector2(260,340)
 app.run.paused=true
 for i in range(5):await process_frame
 for frame in range(60):
  app.run.paused=false;app.run.step(1.0/60);arena._process(1.0/60);arena.native_vfx._process(1.0/60);app.run.paused=true
  await process_frame;RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://build/v24-"+mode+"-%02d.png"%frame)
 app.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(profile+suffix):DirAccess.remove_absolute(profile+suffix)
 quit()
