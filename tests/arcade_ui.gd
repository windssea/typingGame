extends SceneTree

var app: Control
var checks := 0
var failures := 0
var profile_path: String

func _initialize() -> void:
	exercise.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+message)

func capture(filename: String) -> void:
	await process_frame
	if "--ui-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/"+filename+"-preview.png")

func key(character: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = character.unicode_at(0)
	event.keycode = character.to_upper().unicode_at(0)
	event.shift_pressed = TypingGuide.mapping(character).shift
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func exercise() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	profile_path = "user://arcade-ui-%d.json" % Time.get_ticks_usec()
	app.store.path = profile_path
	root.add_child(app)
	await capture("home-v03")
	app.show_training_games()
	await process_frame
	var scroll: ScrollContainer = app.layer.find_child("GameCollection",true,false)
	check(scroll.get_child(0).get_child_count()==10,"all ten games available from lesson selector")
	scroll.scroll_vertical = 1000
	await capture("collection-bottom")
	check(scroll.scroll_vertical>0,"collection can scroll to all new games")
	app.show_fingering()
	await key("?")
	await capture("finger-guide")
	check(app.typing_guide.current=="?","finger lesson responds to actual keyboard events")
	for mode in ArcadeRun.MODES:
		app.lesson_index = 6
		app.start_game(mode,"training")
		app.castle_audio.enabled = false
		await process_frame
		if app.run.paused:
			app.toggle_pause()
		check(app.run is ArcadeRun and is_instance_valid(app.typing_guide),"mode and live coach integrated: "+mode)
		var word: String = app.run.targets[0].word
		await key(word[0])
		check(app.run.correct==1 and app.typing_guide.current==word[1],"typing advances target and live next-finger cue: "+mode)
		for character in word.substr(1):
			await key(character)
		check(app.run.kills==1,"actual key events complete one target: "+mode)
		for i in range(2):
			for character in str(app.run.targets[0].word):
				app.run.type_character(character)
		app.show_game_guide()
		var elapsed: float = app.run.elapsed
		await process_frame
		await key("x")
		check(app.guide_open and app.run.paused and app.run.elapsed==elapsed,"guide pauses timer and blocks game input")
		app.close_game_guide()
		check(not app.run.paused and app.overlay==null,"guide resumes cleanly")
		for arena in app.layer.get_children():
			if arena is ArcadeArena:
				arena._process(0.16)
		app.run.paused = true
		await capture(mode)
		app.run.paused = false
		for arena in app.layer.get_children():
			if arena is ArcadeArena:
				arena._process(0.8)
				check(arena.bursts.is_empty() and arena.trauma==0 and arena.strike==0,"impact feedback returns to rest without blocking input")
		while not app.run.done:
			for character in str(app.run.targets[0].word):
				app.run.type_character(character)
		check(app.store.data.records.has("training:"+mode+":long_words"),"new mode results persist in training namespace")
	app.start_game("castle","challenge")
	app.show_game_guide()
	await capture("castle-fingers")
	check(app.guide_open and app.run.paused,"castle opens shared finger coach without removing build panel")
	app.close_game_guide()
	app.show_challenges()
	await capture("challenges-v03")
	var challenge_scroll: ScrollContainer = app.layer.find_child("GameCollection",true,false)
	check(challenge_scroll.get_child(0).get_child_count()==8,"eight distinct games in challenge hub")
	app.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):
			DirAccess.remove_absolute(profile_path+suffix)
	print("ARCADE UI RESULTS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
