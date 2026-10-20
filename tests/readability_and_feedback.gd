extends SceneTree

var app: Control
var checks := 0
var failures := 0
var capture_enabled := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	capture_enabled = "--ui-capture" in OS.get_cmdline_user_args()
	exercise.call_deferred()

func render() -> void:
	await process_frame
	if capture_enabled:
		await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if capture_enabled:
		await render()
		root.get_texture().get_image().save_png("res://build/v11-"+name+".png")

func arena() -> GameArena:
	for child in app.layer.find_children("*","Control",true,false):
		if child is GameArena:
			return child
	return null

func type_word() -> void:
	var target: Dictionary = app.run.recommended_target()
	for character in str(target.word).substr(target.typed):
		if app.run.paused:
			app.toggle_pause()
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		Input.parse_input_event(event)
		await process_frame

func exercise() -> void:
	var samples := ["f","flamingo","information","I like playing football after school.","Would you like a glass of orange juice?"]
	for word in samples:
		for maximum in [340.0,834.0]:
			var layout := TypingPrompt.measure(word,maximum,46,32)
			var rebuilt := ""
			for row in layout.rows:
				rebuilt += row.text
				check(row.width<=maximum-31,"complete text fits the measured line: "+word)
			check(rebuilt==word,"wrapping preserves every space and punctuation")
			check(layout.font>=32,"input characters do not shrink below the legibility floor")
	var occupied: Array[Rect2] = [Rect2(200,80,280,80)]
	var actors: Array[Rect2] = [Rect2(240,210,180,150)]
	var slot := TypingPrompt.place(Vector2(320,120),Vector2(220,65),Rect2(12,12,800,600),occupied,actors)
	check(not slot.intersects(occupied[0]) and not slot.intersects(actors[0]),"label solver moves out of a blocked label and actor")
	app = load("res://scenes/main.tscn").instantiate()
	var profile_path := "user://readability-%d.json" % Time.get_ticks_usec()
	app.store.path = profile_path
	app.store.data.settings.sound = false
	app.store.save_profile()
	root.add_child(app)
	await process_frame
	app.lesson_index = 6
	for definition in GameContent.modes():
		var mode: String = definition.id
		app.start_game(mode)
		var run: GameRun = app.run
		if run is CastleRun:
			run.wave = 6
			run.begin_wave()
			run.spawn_enemy("goblin").position = Vector2(245,275)
		elif mode=="rain":
			run.spawn_target()
		# Let a mole emerge before the static readability capture.
		run.step(.4)
		arena()._process(.4)
		run.paused = true
		await render()
		var dock: ActionCue = app.layer.find_child("InputDock",true,false)
		if run is BridgeRun:
			check(dock==null,"bridge has one in-world prompt and no duplicated input dock")
			check(arena().size==Vector2(1440,900),"bridge uses the entire playable stage")
		else:
			check(dock.size==Vector2(1360,108),"expanded fixed input dock: "+mode)
			check(arena().get_global_rect().end.y<=dock.global_position.y-8,"playfield does not overlap input dock: "+mode)
		check(TypingPrompt.measure(run.recommended_target().word,834,46,32).font>=32,"large complete word in "+mode)
		check(arena().backdrop!=null and arena().backdrop.material.shader==GameArena.BREEZE,"background motion is isolated from text and actor rendering: "+mode)
		if mode in ["dojo","sprint"]:
			check(arena().coach_motion.clips.size()==3,"foundation mode has real idle, cheer and run clips: "+mode)
		elif run is ArcadeRun and mode in ["moles","aliens","racing"]:
			check(arena().motion.texture("idle",0).get_width()>=256,"active character uses a newly decoded HD atlas: "+mode)
		if mode not in ["dojo","sprint"]:
			var rects: Array = arena().label_rects.values()
			check(rects.size()==run.targets.size(),"each target has a protected label: "+mode)
			for i in range(rects.size()):
				check(Rect2(Vector2.ZERO,arena().size).encloses(rects[i]),"word plate stays inside arena: "+mode)
				for j in range(i):
					check(not rects[i].intersects(rects[j]),"word plates avoid one another: "+mode)
			if capture_enabled:
				var first: Rect2 = rects[0]
				var scaled := Rect2i(root.get_final_transform()*Rect2(arena().global_position+first.position*arena().scale,first.size*arena().scale))
				scaled = scaled.grow(-9)
				var before := root.get_texture().get_image().get_region(scaled).get_data()
				arena().juice.burst(first.get_center(),Color("ff3355"),3,"confetti")
				arena().queue_redraw()
				await render()
				var after := root.get_texture().get_image().get_region(scaled).get_data()
				check(before==after,"actual rendered word remains unchanged under a particle burst: "+mode)
		await capture(mode+"-readable")
		run.paused = false
		if run is CastleRun:
			run.recommended_target().health = 1
		await type_word()
		check(run.correct>0 and arena().impact_age<.2,"real keyboard completion triggers visual impact: "+mode)
		check(not arena().juice.particles.is_empty(),"material particles emitted: "+mode)
		if run is CastleRun:
			check(arena().defeat_ghosts.size()==1,"defeated castle enemy finishes its hit motion before fading")
		elif mode=="balloons":
			check(not arena().pop_reactions.is_empty(),"balloon deforms and collapses on a real hit")
		if run is ArcadeRun and mode in ["moles","fighter"]:
			var before := run.correct
			arena().impact_freeze = .045
			var next: Dictionary = run.recommended_target()
			run.type_character(str(next.word).substr(next.typed,1))
			check(run.correct==before+1,"hit-stop never blocks the next accepted key: "+mode)
		run.paused = true
		await capture(mode+"-impact")
		var age: float = arena().impact_age
		arena()._process(.25)
		check(is_equal_approx(age,arena().impact_age),"pause freezes feedback: "+mode)
		run.paused = false
		var previous_particles: Array = arena().juice.particles.duplicate()
		arena()._process(2.0)
		check(previous_particles.all(func(p): return not arena().juice.particles.has(p)),"transient bursts expire while ambient trails may continue: "+mode)
		arena().juice.reduced_motion = true
		var count := arena().juice.particles.size()
		arena().juice.jet(Vector2.ZERO,Vector2.UP,Color.WHITE,3)
		check(arena().juice.particles.size()==count,"reduced motion suppresses directional streaks: "+mode)
	# A clustered final-wave fixture checks long words and label density together.
	app.start_game("castle")
	app.run.wave = 6
	app.run.begin_wave()
	app.run.targets.clear()
	var kinds := ["wolf","guard","shaman","bomber","goblin","boss"]
	for i in range(kinds.size()):
		var enemy: Dictionary = app.run.spawn_enemy(kinds[i])
		enemy.position = Vector2(260+i*100,290+(i%2)*40)
		enemy.word = ["information","beautiful","adventure","understand","playground","competition"][i]
	app.run.paused = true
	await render()
	var dense: Array = arena().label_rects.values()
	for i in range(dense.size()):
		for j in range(i):
			check(not dense[i].intersects(dense[j]),"crowded castle words never overlap")
	await capture("castle-crowded")
	app.lesson_index = 9
	app.start_game("aliens")
	app.run.recommended_target().word = "Would you like a glass of orange juice?"
	app.run.recommended_target().typed = 14
	app.run.paused = true
	await capture("long-sentence")
	app.queue_free()
	await process_frame
	await create_timer(.1).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):
			DirAccess.remove_absolute(profile_path+suffix)
	print("READABILITY AND FEEDBACK: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
