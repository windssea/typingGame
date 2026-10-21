extends SceneTree

var checks := 0
var failures := 0
var app: Control
var capture_enabled := false

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("FAIL: "+message)

func _initialize() -> void:
	capture_enabled="--ui-capture" in OS.get_cmdline_user_args()
	exercise.call_deferred()

func settle() -> void:
	for i in range(5): await process_frame

func click(control: Control) -> void:
	if not is_instance_valid(control):
		check(false,"requested mouse target exists")
		return
	if DisplayServer.get_name()!="headless": root.grab_focus()
	var control_name: String=control.name
	var point := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position=point
	move.global_position=point
	root.push_input(move,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		event.global_position=point
		root.push_input(event,true)
	await settle()
	if capture_enabled: print("MOUSE ",control_name," at ",point," -> ",app.page," window_mode=",DisplayServer.window_get_mode())

func screenshot(name: String) -> void:
	if not capture_enabled: return
	if app.run!=null:
		app.run.paused=true
		while is_instance_valid(app.overlay): app.close_modal()
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/v18-"+name+".png")

func type_target(game: GameRun) -> void:
	var target := game.recommended_target()
	if not target.is_empty():
		for c in str(target.word).substr(target.typed): game.type_character(c)

func exercise() -> void:
	var lesson: Dictionary=GameContent.lessons()[5]
	var meteor:=GameRun.new()
	meteor.setup("rain",lesson,1,18)
	meteor.spawn_target()
	var target: Dictionary=meteor.targets[0]
	var start: Vector2=target.position
	meteor.step(.2)
	check(target.position.x!=start.x and target.position.y>start.y,"meteor actually travels diagonally")
	type_target(meteor)
	check(meteor.targets.has(target) and meteor.kills==0 and meteor.projectiles.size()==1,"last key launches interceptor without exploding the target")
	var shot: Dictionary=meteor.projectiles[0]
	meteor.step(.05)
	check(meteor.kills==0 and shot.position!=shot.origin,"projectile has a real nonzero flight interval")
	meteor.paused=true
	var position: Vector2=shot.position
	meteor.step(.5)
	check(shot.position==position,"pause freezes projectile and contact")
	meteor.paused=false
	for i in range(60): meteor.step(.025)
	check(meteor.kills==1 and not meteor.targets.has(target),"interceptor resolves once at physical contact")
	var castle:=CastleRun.new()
	castle.setup("castle",lesson,1,12)
	castle.begin_wave()
	var guard:=castle.spawn_enemy("guard")
	guard.position=Vector2(800,330)
	castle.damage_enemy(guard,22,"ice",CastleRun.PADS[1])
	check(guard.health==85 and guard.slow==0 and castle.projectiles.size()==1,"ice tower waits for its own projectile")
	castle.step_projectiles(.01)
	check(guard.health==85,"tower cannot damage before contact")
	castle.step_projectiles(1)
	check(guard.health==63 and guard.slow>0,"ice damage and slow arrive together")
	for mode in AdventureRun.MODES:
		for context in ["training","challenge"]:
			var game:=AdventureRun.new()
			game.context=context
			game.challenge_rank="hard" if context=="challenge" else "normal"
			game.setup(mode,lesson,1.35 if context=="challenge" else 1,42)
			var before:=game.correct
			game.type_character("~")
			check(game.correct==before and game.attempts==1,"wrong key cannot advance "+mode+context)
			game.paused=true
			game.step(1)
			check(game.elapsed==0,"pause freezes new mode "+mode+context)
			game.paused=false
			for i in range(8000):
				if game.done: break
				type_target(game)
				game.step(.1)
				if game.skill_charge>=3: game.activate_skill()
			check(game.done and game.won,"actual typing reaches a win in "+mode+context)
			check(game.correct>0 and game.skill_uses>0,"typing and a charged skill are effective in "+mode+context)
			check(game.core==0 if mode=="royal" else game.kills==game.goal,"mode-specific victory condition "+mode+context)
			var lost:=AdventureRun.new()
			lost.context=context
			lost.setup(mode,lesson,1,33)
			for i in range(5000):
				if lost.done: break
				lost.step(.1)
			check(lost.done and not lost.won and lost.hp==0,"ignoring threats causes a real loss "+mode+context)
	app=load("res://scenes/main.tscn").instantiate()
	var profile: String="user://v18-test-%d.json" % Time.get_ticks_usec()
	app.store.path=profile
	app.store.data.settings.sound=false
	root.add_child(app)
	if DisplayServer.get_name()!="headless": root.grab_focus()
	await settle()
	for resolution in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1920,800)]:
		root.size=resolution
		app.show_challenges()
		await settle()
		await click(app.layer.find_child("TrainingNav",true,false))
		check(app.page=="lessons","real mouse reaches training navigation at "+str(resolution))
		await click(app.layer.find_child("ChallengeNav",true,false))
		check(app.page=="challenges","real mouse reaches challenge navigation at "+str(resolution))
		await click(app.layer.find_child("ProfileUtility",true,false))
		check(app.page=="profile","real mouse reaches bottom settings at "+str(resolution))
		var reduced: bool=app.store.data.settings.reduced_motion
		await click(app.layer.find_child("ReducedMotion",true,false))
		check(app.store.data.settings.reduced_motion!=reduced,"real mouse toggles a settings button at "+str(resolution))
		app.show_challenges()
		await settle()
		var scroll: ScrollContainer=app.layer.find_child("GameCollection",true,false)
		var last_button: Button=app.layer.find_child("Mission_restaurant",true,false)
		scroll.ensure_control_visible(last_button)
		await settle()
		await click(last_button)
		check(app.page=="game" and app.run.mode=="restaurant","real mouse starts a bottom-row game at "+str(resolution))
	if capture_enabled:
		app.show_challenges()
		await settle()
		await click(app.layer.find_child("FullscreenUtility",true,false))
		for i in range(30):
			if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN: break
			await process_frame
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"actual native fullscreen button enters fullscreen")
		await click(app.layer.find_child("FullscreenUtility",true,false))
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"same fullscreen button returns to windowed")
	root.size=Vector2i(1280,800)
	app.store.data.settings.reduced_motion=false
	app.lesson_index=5
	for mode in ["rain","sprint","castle","balloons","aliens","moles","racing","fighter","royal","submarine","restaurant"]:
		app.start_game(mode)
		if mode=="rain": app.run.spawn_target()
		if mode=="castle":
			app.run.gold=500
			for i in range(3): app.run.build_tower(i,["fire","ice","storm"][i])
			app.run.begin_wave()
			app.run.spawn_enemy("goblin").position=Vector2(200,300)
		for i in range(20): app.run.paused=false; app.run.step(.025)
		await settle()
		var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
		check(arena.backdrop.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"background preserves image proportions: "+mode)
		if mode in AdventureRun.MODES:
			var native_clip: Texture2D=arena.kitchen.texture(false) if mode=="restaurant" else arena.motion.texture("idle",0)
			check(native_clip!=null,"real Grok clip is connected: "+mode)
		if mode=="royal":
			var active: Dictionary=app.run.recommended_target()
			check(arena.label_rects[active.id].get_center().distance_to(active.position)<160,"royal word stays attached to its actual enemy")
		await screenshot(mode)
		app.run.paused=false
		type_target(app.run)
		for i in range(12): app.run.step(.025); arena._process(.025)
		await screenshot(mode+"-action")
	app.show_home()
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix): DirAccess.remove_absolute(profile+suffix)
	print("PLAYABLE V18: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
