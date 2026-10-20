extends SceneTree

var checks := 0
var failures := 0
var app: Control
var profile_path := ""

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	exercise.call_deferred()

func capture(filename: String) -> void:
	if "--ui-capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v10-"+filename+".png")

func complete_word() -> void:
	var target: Dictionary = app.run.recommended_target()
	for character in str(target.word).substr(target.typed):
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		event.keycode = character.to_upper().unicode_at(0)
		event.shift_pressed = TypingGuide.mapping(character).shift
		Input.parse_input_event(event)
		await process_frame

func exercise() -> void:
	var words := {}
	var phrases := 0
	for entry in Vocabulary.data().entries:
		check(not entry.meaning.is_empty(),"every entry has original Chinese meaning")
		if entry.kind=="word":
			check(not words.has(entry.text),"no duplicate core words: "+entry.text)
			words[entry.text] = true
		else:
			phrases += 1
	check(words.size()==709 and phrases==48,"709 core words plus 48 original phrases")
	check(Vocabulary.topics().size()==25,"24 themes and mixed mode")
	var lessons := GameContent.lessons()
	for topic in Vocabulary.topics():
		for i in range(lessons.size()):
			var lesson := Vocabulary.lesson(lessons[i],topic.id)
			check(not lesson.words.is_empty(),"each theme/course has playable content")
			for word in lesson.words:
				for character in word:
					check(character in lesson.keys,"only taught keys: "+lesson.id+"/"+word)
			if i<5 or i==7:
				check(lesson.words==lessons[i].words,"beginner and numbers progression unchanged")
	var pool := Vocabulary.lesson(lessons[6])
	var bag := GameRun.new()
	bag.lesson = pool
	bag.rng.seed = 123
	var seen := {}
	for i in range(pool.words.size()):
		var word := bag.next_word()
		check(not seen.has(word),"a shuffled cycle does not repeat words")
		seen[word] = true
	var store := ProfileStore.new()
	check(store.valid(ProfileStore.fresh()),"legacy save without vocabulary setting remains valid")
	var invalid := ProfileStore.fresh()
	invalid.settings.vocabulary_topic = "missing-topic"
	check(not store.valid(invalid),"invalid topics rejected during save import")
	app = load("res://scenes/main.tscn").instantiate()
	profile_path = "user://polish-v09-%d.json" % Time.get_ticks_usec()
	app.store.path = profile_path
	app.store.data.settings.sound = false
	app.store.save_profile()
	root.add_child(app)
	await process_frame
	await capture("home")
	app.lesson_index = 6
	app.show_training_games()
	await capture("missions")
	app.show_vocabulary()
	check(app.layer.find_child("VocabularyTopic",true,false)!=null,"theme picker uses keyboard-focusable control")
	await capture("vocabulary")
	app.close_modal()
	# Theme selection rebuilds the task page and persists without touching lesson progress.
	app.show_vocabulary()
	app.layer.find_child("VocabularyTopic",true,false).item_selected.emit(1)
	check(app.vocabulary_topic=="animals" and app.store.data.settings.vocabulary_topic=="animals","theme selection persists")
	check(app.page=="training_games" and app.lesson_index==6,"theme change preserves selected course")
	app.vocabulary_topic = "mixed"
	app.store.data.settings.vocabulary_topic = "mixed"
	for mode in GameContent.modes():
		app.start_game(mode.id)
		if app.run is CastleRun:
			app.run.build_tower(0,"fire")
			app.run.begin_wave()
			app.run.spawn_target()
		elif mode.id=="rain":
			app.run.spawn_target()
		await process_frame
		var before: int = app.run.correct
		await complete_word()
		check(app.run.correct>before and app.run.attempts==app.run.correct,"real input advances "+mode.id)
		for child in app.layer.find_children("*","Control",true,false):
			if child is GameArena:
				child._process(.12)
				check(child.key_pulse>0,"per-letter feedback reaches arena: "+mode.id)
				if child is ArcadeArena and mode.id=="racing":
					check(child.visual_distance>0 and child.visual_distance<app.run.distance,"car advances smoothly without changing input/rules")
		app.run.paused = true
		await capture(mode.id)
		if mode.id in ["moles","rain","castle"]:
			app.run.paused = false
			if mode.id=="rain":
				app.run.spawn_target()
			elif mode.id=="castle" and app.run.targets.is_empty():
				app.run.spawn_target()
			for i in range(20):
				app.run.step(1.0/60)
				for child in app.layer.find_children("*","Control",true,false):
					if child is GameArena:
						child._process(1.0/60)
			app.run.paused = true
			await capture(mode.id+"-ready")
		var clock_before := 0.0
		for child in app.layer.find_children("*","Control",true,false):
			if child is GameArena:
				clock_before = child.clock
				child._process(.5)
				check(child.clock==clock_before,"pause freezes all animation clocks: "+mode.id)
	app.start_game("moles")
	var last := int(app.run.targets[0].lane)
	for i in range(6):
		await complete_word()
		check(app.run.targets[0].lane!=last,"successive moles use different holes")
		last = int(app.run.targets[0].lane)
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):
			DirAccess.remove_absolute(profile_path+suffix)
	print("VOCABULARY AND POLISH: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
