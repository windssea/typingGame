extends SceneTree

var app: Control
var checks := 0
var failures := 0
var profile_path := ""

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	exercise.call_deferred()

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func capture(name: String) -> void:
	if "--ui-capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v10-"+name+".png")

func exercise() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	profile_path = "user://product-finish-%d.json" % Time.get_ticks_usec()
	app.store.path = profile_path
	app.store.data.settings.sound = false
	app.store.save_profile()
	root.add_child(app)
	await process_frame
	var stages: Array = app.layer.find_children("*","MenuStage",true,false)
	check(stages.size()==1 and stages[0].home and stages[0].lobby!=null,"home renders actual illustrated game stage")
	check(app.layer.find_child("StartTraining",true,false)!=null and app.layer.find_child("StartChallenge",true,false)!=null,"only two main adventure entry paths")
	for node in app.layer.find_children("*","Button",true,false):
		check(node.size.y>=44,"keyboard controls have visible full-size targets")
	await capture("home-final")
	for bus in ["Music","SFX","UI"]:
		var index := AudioServer.get_bus_index(bus)
		check(index>=0 and AudioServer.is_bus_mute(index),"saved mute applies to "+bus)
	check(app.soundscape.music.stream.loop and app.soundscape.rhythm.stream.loop,"phase-aligned music stems loop")
	check(app.soundscape.voices.size()==8,"one-shot polyphony has a hard bound")
	app.show_lessons()
	await capture("lessons-final")
	app.lesson_index = 6
	app.show_training_games()
	check(app.layer.find_child("GameCollection",true,false).get_child(0).columns==3,"tasks use illustrated game level tiles")
	await capture("missions-final")
	app.show_profile()
	var slider: HSlider = app.layer.find_child("MusicVolume",true,false)
	check(slider!=null,"music has a keyboard-adjustable volume control")
	slider.grab_focus()
	var before := slider.value
	await press(KEY_RIGHT)
	check(slider.value>before and is_equal_approx(app.store.data.settings.music_volume,slider.value/100),"real keyboard adjusts and saves music gain")
	await capture("settings-final")
	app.show_import()
	check(slider.focus_mode==Control.FOCUS_NONE,"modal traps focus away from volume sliders")
	await press(KEY_ESCAPE)
	check(slider.focus_mode==Control.FOCUS_ALL,"closing modal restores slider navigation")
	var invalid := ProfileStore.fresh()
	invalid.settings.music_volume = 1.5
	check(not app.store.valid(invalid),"out-of-range mixer gains rejected on import")
	for mode in GameContent.modes():
		app.start_game(mode.id)
		if mode.id in ["dojo","bubbles","rain","sprint"]:
			for child in app.layer.find_children("*","Control",true,false):
				if child is GameArena:
					check(child.art.sprites.has({"dojo":"key","bubbles":"bubble","rain":"meteor_head","sprint":"stopwatch"}[mode.id]),"foundation game has its production prop: "+mode.id)
		for node in app.layer.find_children("*","Button",true,false):
			check(node.size.y>=44,"all arena controls have readable targets: "+mode.id)
		if app.run is CastleRun:
			app.run.wave = 3
			app.run.begin_wave()
			app.run.spawn_enemy("wolf").position = Vector2(280,270)
			app.run.spawn_enemy("boss").position = Vector2(780,350)
		elif mode.id=="rain":
			app.run.spawn_target()
		elif mode.id=="submarine":
			for i in range(200):
				if not app.run.recommended_target().is_empty(): break
				app.run.step(.1)
		var sound: CastleAudio = app.castle_audio
		check(sound!=null and sound.players.size()==6,"every mode routes bounded SFX players: "+mode.id)
		for voice in sound.players:
			check(voice.bus=="SFX","effects respect shared volume and mute: "+mode.id)
		var target: Dictionary = app.run.recommended_target()
		var expected := str(target.word).substr(target.typed,1)
		app.run.type_character("#" if expected!="#" else "$")
		check(not app.run.last_input_ok and app.run.correct==0,"wrong input exposes explicit recoverable feedback: "+mode.id)
		app.run.type_character(expected)
		check(app.run.last_input_ok and app.run.correct==1,"next correct key clears error immediately: "+mode.id)
		if app.run is CastleRun:
			for child in app.layer.find_children("*","Control",true,false):
				if child is CastleArena:
					check(child.creature_clips.size()==3,"wave three pre-loads wolf, guard and boss native motion")
			app.run.paused = true
			await capture("castle-native-creatures")
			app.run.wave = 6
			for child in app.layer.find_children("*","Control",true,false):
				if child is CastleArena:
					child.prepare_creatures()
					check(child.creature_clips.size()==5,"final wave has all five creature motion sets")
			for i in range(3):
				app.run.spawn_enemy(["guard","shaman","bomber"][i]).position = Vector2(210+i*290,480)
			await capture("castle-all-creatures")
		app.run.paused = true
		await capture(mode.id+"-final")
	app.start_game("dojo")
	while app.run.kills<18:
		app.run.paused = false
		var target: Dictionary = app.run.recommended_target()
		for character in str(target.word).substr(target.typed):
			app.run.type_character(character)
	app.run.step(4)
	check(app.store.data.completed.has("long_words"),"redesigned UI preserves training mastery and save")
	check(app.overlay.find_children("*","ResultSeal",true,false).size()==1,"result has a game reward seal")
	await create_timer(.8).timeout
	await capture("result-final")
	var particles := GameJuice.new()
	for i in range(100): particles.burst(Vector2.ZERO,Color.WHITE,3)
	check(particles.particles.size()<=280,"simultaneous feedback respects particle budget")
	particles.step(3)
	check(particles.particles.is_empty(),"all transient particles expire")
	for key in ["castle_wolf","castle_boss","castle_guard","castle_shaman","castle_bomber"]:
		var motion := ArcadeMotion.new()
		motion.setup(key)
		check(motion.clips.size()==2 and motion.texture("idle",0)!=motion.texture("idle",.4),"new native motion actually changes pose: "+key)
		check(motion.texture("hit",.4,true)==motion.texture("idle",0),"new creature respects reduced motion: "+key)
	app.queue_free()
	await process_frame
	await create_timer(.1).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	print("PRODUCT FINISH: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
