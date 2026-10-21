extends SceneTree

func _initialize() -> void: exercise.call_deferred()
func type_word(run: AdventureRun, target: Dictionary) -> void:
	run.locked=target.id
	for letter in str(target.word).substr(target.typed): run.type_character(letter)
func exercise() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var profile: String="user://kitchen-film-%d.json"%Time.get_ticks_usec()
	app.store.path=profile;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	root.size=Vector2i(1440,900);app.lesson_index=5;app.start_game("restaurant")
	app.set_process(false)
	var arena: AdventureArena=app.layer.find_children("*","AdventureArena",true,false)[0]
	arena.set_process(false);arena.native_vfx.set_process(false)
	var scenario: String="serve" if "--serve" in OS.get_cmdline_user_args() else "cook" if "--cook" in OS.get_cmdline_user_args() else "idle"
	var target: Dictionary=app.run.targets[1]
	if scenario!="idle":
		type_word(app.run,target);type_word(app.run,target)
		if scenario=="serve": app.run.step(.5);app.run.step(.5);app.run.step(.5);app.run.step(.1);type_word(app.run,target)
	for frame in range(60):
		app.run.paused=false
		app.run.step(1.0/60);arena._process(1.0/60);arena.native_vfx._process(1.0/60)
		app.run.paused=true
		await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://build/v22-kitchen-"+scenario+"-%02d.png"%frame)
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix): DirAccess.remove_absolute(profile+suffix)
	quit()
