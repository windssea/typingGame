extends SceneTree

var checks:=0
var failures:=0
var app: Control
func _initialize() -> void: exercise.call_deferred()
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error("FAIL: "+message)

func exercise() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	var path: String="user://engine-vfx-%d.json"%Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.lesson_index=6
	for definition in GameContent.modes():
		app.start_game(definition.id)
		if app.run is CastleRun:
			app.run.gold=1000
			for i in range(3): app.run.build_tower(i,["fire","ice","storm"][i])
			app.run.begin_wave();app.run.spawn_enemy("goblin").health=1
		elif definition.id=="rain": app.run.spawn_target()
		elif definition.id=="submarine":
			for i in range(200):
				if not app.run.recommended_target().is_empty(): break
				app.run.step(.1)
		var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
		var vfx: EngineVfx=arena.native_vfx
		check(is_instance_valid(vfx) and vfx.ambient is CPUParticles2D,"native emitters exist: "+definition.id)
		check(vfx.bursts.size()==10 and vfx.trails.size()==6 and vfx.waves.size()==6 and vfx.lights.size()==5,"fixed node budgets: "+definition.id)
		check(vfx.lights.all(func(s): return s.node is PointLight2D and s.node.range_item_cull_mask==2),"real lights exclude game text: "+definition.id)
		var before:=vfx.event_count
		var target: Dictionary=app.run.recommended_target()
		for c in str(target.get("word","")).substr(target.get("typed",0)): app.run.type_character(c)
		for i in range(160):
			if vfx.event_count>before: break
			app.run.step(.025);arena._process(.025);vfx._process(.025)
		check(vfx.event_count>before,"actual game events drive native effects: "+definition.id)
		if definition.id in ["rain","castle","royal","submarine"]:
			check(vfx.launch_count>0,"physical launches drive native trails: "+definition.id)
		if app.run is CastleRun and app.run.targets.is_empty(): app.run.spawn_enemy("guard")
		if definition.id=="submarine":
			for i in range(200):
				if not app.run.recommended_target().is_empty(): break
				app.run.step(.1)
		arena.queue_redraw();await process_frame
		vfx.apply_mask()
		check(not vfx.protected_regions.is_empty(),"typing regions mask native effects: "+definition.id)
		if definition.id=="castle":
			vfx._process(.01)
			check(vfx.auras.filter(func(e): return e.emitting).size()==3,"each built tower has its own native aura")
		var count:=vfx.get_child_count()
		for i in range(80): vfx.emit_at(Vector2(520,410),3,"magic",PlayTheme.YELLOW)
		check(count==vfx.get_child_count(),"dense impacts reuse nodes: "+definition.id)
		vfx._process(.08)
		check(vfx.shake.length()<=3.4 and Engine.time_scale==1,"bounded visual shake leaves simulation time intact: "+definition.id)
		app.run.paused=true
		var time:=vfx.clock;var offset:=vfx.shake
		vfx._process(.5)
		check(vfx.clock==time and vfx.shake==offset and vfx.bursts.all(func(p): return p.speed_scale==0),"pause freezes particles, waves, lights and shake: "+definition.id)
		app.run.paused=false;vfx._process(2)
		check(vfx.shake==Vector2.ZERO and vfx.lights.all(func(s): return not s.node.enabled) and vfx.waves.all(func(s): return not s.node.visible),"tweens settle completely: "+definition.id)
		arena.reduced_motion=true
		vfx.emit_at(Vector2(520,410),3,"magic",PlayTheme.YELLOW);vfx._process(.01)
		check(vfx.shake==Vector2.ZERO and not vfx.ambient.visible and vfx.bursts.all(func(p): return not p.visible) and vfx.lights.all(func(s): return not s.node.enabled),"reduced motion suppresses moving FX and light flashes: "+definition.id)
		check(vfx.trails.all(func(s): return not s.emitter.visible),"reduced motion hides flight particles: "+definition.id)
		arena.reduced_motion=false
		if "--ui-capture" in OS.get_cmdline_user_args():
			app.run.paused=false
			if is_instance_valid(app.overlay): app.close_modal()
			vfx.emit_at(Vector2(600,410),3,"slash" if definition.id=="fighter" else "water" if definition.id=="submarine" else "magic",PlayTheme.SKY)
			for frame in range(12):
				app.run.paused=false
				if is_instance_valid(app.overlay): app.close_modal()
				await process_frame
			app.run.paused=true;vfx._process(0)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/v19-"+definition.id+"-native-fx.png")
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("ENGINE VFX: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
