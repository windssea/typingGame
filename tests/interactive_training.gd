extends SceneTree

var checks := 0
var failures := 0
var app: Control
var profile_path: String

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	exercise.call_deferred()

func capture(name: String) -> void:
	if "--ui-capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v08-"+name+".png")

func arena() -> ArcadeArena:
	for child in app.layer.find_children("*","Control",true,false):
		if child is ArcadeArena:
			return child
	return null

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func complete_word() -> void:
	var target: Dictionary = app.run.recommended_target()
	for character in str(target.word).substr(target.typed):
		app.run.type_character(character)

func exercise() -> void:
	for mode in ["moles","aliens","racing","castle"]:
		var motion := ArcadeMotion.new()
		motion.setup(mode)
		check(motion.clips.size()==2,"only current arena clips load: "+mode)
		check(motion.texture("idle",0)!=motion.texture("idle",0.3),"native frames advance: "+mode)
		check(motion.texture("idle",0)==motion.texture("idle",motion.duration("idle")),"idle uses bounded native loop: "+mode)
		var reaction := "boost" if mode=="racing" else "hit"
		check(motion.texture(reaction,5)==motion.texture(reaction,motion.duration(reaction)-0.001),"one-shot never wraps: "+mode)
		check(motion.texture(reaction,.3,true)==motion.texture("idle",0),"reduced motion always shows idle: "+mode)
	app=load("res://scenes/main.tscn").instantiate()
	profile_path="user://interactive-v08-%d.json" % Time.get_ticks_usec()
	app.store.path=profile_path
	app.store.data.settings.sound=false
	app.store.save_profile()
	root.add_child(app)
	await process_frame
	var texts: Array = []
	for button in app.layer.find_children("*","Button",true,false):
		texts.append(button.text)
	check(not texts.has("游戏集合") and not texts.has("玩法图鉴") and app.layer.find_child("WorldPortal0",true,false)==null,"home has only training/challenge paths plus save utility")
	await capture("home")
	app.show_lessons()
	await capture("lessons")
	app.show_training_games()
	await capture("missions")
	app.show_challenges()
	await capture("challenges")
	app.begin_recommended_training()
	check(app.run is BridgeRun and app.run.mode=="dojo","first recommended mission is playable F/J bridge repair")
	check(app.typing_guide==null,"beginner stage avoids the duplicated hand panel")
	app.start_game("moles","training")
	var visual := arena()
	await create_timer(.36).timeout
	await capture("moles-ready")
	complete_word()
	check(not visual.reaction_echoes.is_empty() and visual.impact_freeze>0,"real successful typing starts a reaction and pose beat")
	var attempts: int = app.run.attempts
	complete_word(); complete_word()
	check(app.run.skill_charge==3,"three actual word completions charge an ability")
	await key(KEY_SPACE)
	check(app.run.skill_uses==1 and app.run.skill_time>0 and app.run.skill_charge==0,"Space triggers a real earned ability")
	check(app.run.attempts==attempts+2,"skill hotkey never counts as a typing mistake")
	var remaining: float = app.run.targets[0].remaining
	app.run.advance(.5)
	check(remaining-app.run.targets[0].remaining<.11,"focus ability slows real expiry instead of a decorative effect")
	app.run.paused=true
	var pose: float = visual.pose_clock
	var age: float = visual.reaction_echoes[0].age
	visual._process(.4)
	check(visual.pose_clock==pose and visual.reaction_echoes[0].age==age,"pause freezes poses and reaction clips")
	app.run.paused=false
	await capture("moles-skill")
	for mode in ["aliens","racing","fighter","balloons"]:
		app.start_game(mode,"challenge")
		app.castle_audio.enabled=false
		await create_timer(.3).timeout
		for i in range(3):complete_word()
		var before: float = app.run.rival if mode=="racing" else app.run.shield if mode=="aliens" else app.run.hp
		await key(KEY_SPACE)
		check(app.run.skill_uses==1,"skill reachable by actual keyboard: "+mode)
		if mode=="racing":
			check(app.run.rival<before,"rally ability actually moves rival back")
		elif mode=="aliens":
			check(app.run.shield>before,"alien ability actually restores shield")
		elif mode=="fighter":
			app.run.miss_target(app.run.targets[0])
			check(app.run.hp==before and not app.run.guard_ready,"prepared guard actually absorbs the next counter")
		app.run.paused=true
		await capture(mode)
	app.lesson_index=0
	app.start_game("moles","training")
	while not app.run.done:complete_word()
	check(app.store.data.completed.has("home_index"),"short accurate training still earns real lesson mastery")
	app.continue_training()
	check(app.lesson_index==1 and app.run.context=="training","next lesson advances into a real recommended mission")
	app.free()
	await create_timer(.15).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):DirAccess.remove_absolute(profile_path+suffix)
	print("INTERACTIVE TRAINING: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
