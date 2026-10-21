extends SceneTree

var app: Control
var checks := 0
var failures := 0
var path := ""
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("FAIL: "+message)
func exercise() -> void:
	var feel:=GameFeel.new()
	feel.hit(Vector2(300,200),1)
	check(feel.trauma==0,"routine feedback never shakes")
	feel.hit(Vector2(300,200),2)
	var medium:=feel.trauma
	feel.hit(Vector2(300,200),3)
	check(feel.trauma>medium and feel.trauma<=.65,"heavy response accumulates with a safe cap")
	for i in range(100): feel.hit(Vector2.ZERO,3)
	check(feel.events.size()==12,"simultaneous impacts are bounded")
	for i in range(120):
		feel.step(1.0/120)
		check(feel.offset().length()<4,"camera feedback remains subtle")
	check(feel.events.is_empty() and feel.trauma==0,"feedback expires and returns to rest")
	for fps in [30,60,120]:
		var hold:=.04
		var advanced:=0.0
		for i in range(fps):
			advanced+=GameFeel.pose_step(1.0/fps,hold)
			hold=maxf(0,hold-1.0/fps)
		check(is_equal_approx(advanced,.96),"pose hold preserves remainder independent of frame rate")
	check(GameFeel.kick(0)==1 and GameFeel.kick(1)==0,"contact is immediate, recoil settles")
	feel.reduced_motion=true;feel.hit(Vector2.ZERO,3)
	check(feel.offset()==Vector2.ZERO,"reduced motion disables existing and new shake")
	var juice:=GameJuice.new()
	juice.reduced_motion=true;juice.burst(Vector2.ZERO,Color.WHITE,3)
	juice.step(.05)
	check(juice.particles.all(func(p): return p.p==Vector2.ZERO),"reduced motion uses stationary short fades")
	app=load("res://scenes/main.tscn").instantiate()
	path="user://feel-v15-%d.json" % Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false;app.store.save_profile()
	root.add_child(app);await process_frame
	app.lesson_index=6
	for definition in GameContent.modes():
		app.start_game(definition.id)
		if app.run is CastleRun:
			app.run.begin_wave();app.run.spawn_enemy("goblin").health=1
		elif definition.id=="rain": app.run.spawn_target()
		elif definition.id=="submarine":
			for i in range(200):
				if not app.run.recommended_target().is_empty(): break
				app.run.step(.1)
		var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
		var target: Dictionary=app.run.recommended_target()
		for character in str(target.word).substr(target.typed):
			app.run.paused=false
			var key:=InputEventKey.new();key.pressed=true;key.unicode=character.unicode_at(0)
			Input.parse_input_event(key);await process_frame
		if definition.id in ["rain","castle","royal","submarine","fighter"]:
			for i in range(180):
				if not arena.feel.events.is_empty(): break
				app.run.step(.025);arena._process(.025)
		var responded: bool=arena.nitro_age>=0 and arena.native_vfx.event_count>0 if definition.id=="racing" else not arena.feel.events.is_empty()
		check(app.run.correct>0 and responded,"actual completion triggers native propulsion or contact feedback: "+definition.id)
		var before: int=app.run.correct
		if app.run.recommended_target().is_empty():
			if app.run is CastleRun: app.run.spawn_enemy("goblin")
			elif definition.id=="submarine":
				for i in range(200):
					if not app.run.recommended_target().is_empty(): break
					app.run.step(.1)
			else: app.run.spawn_target()
		if arena is ArcadeArena: arena.impact_freeze=.065
		target=app.run.recommended_target()
		app.run.type_character("#")
		app.run.type_character(str(target.word).substr(target.typed,1))
		check(app.run.correct==before+1 and arena.error_pulse==0,"input remains live and clears error during feedback: "+definition.id)
		app.run.paused=true
		var clock: float=arena.feel.clock;arena._process(.2)
		check(arena.feel.clock==clock,"pause freezes presentation: "+definition.id)
		if "--ui-capture" in OS.get_cmdline_user_args():
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/v15-"+definition.id+"-impact.png")
			if definition.id=="fighter" and "--feel-film" in OS.get_cmdline_user_args():
				for frame in range(30):
					app.run.paused=false;arena._process(.02);app.run.paused=true
					await process_frame;await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://build/v15-fighter-frame-%02d.png" % frame)
		app.run.paused=false;arena._process(2)
		check(arena.feel.events.is_empty() and arena.feel.trauma==0,"mode recovers without permanent offsets: "+definition.id)
		check(Engine.time_scale==1,"visual hit-stop never changes simulation time: "+definition.id)
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("GAME FEEL: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
