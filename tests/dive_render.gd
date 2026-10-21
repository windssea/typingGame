extends SceneTree

func _initialize() -> void: exercise.call_deferred()
func type_word(run: AdventureRun, target: Dictionary) -> void:
	run.locked=target.id
	for ch in str(target.word).substr(target.typed): run.type_character(ch)
func exercise() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var profile: String="user://dive-film-%d.json"%Time.get_ticks_usec()
	app.store.path=profile;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	root.size=Vector2i(1440,900);app.lesson_index=5;app.start_game("submarine","challenge")
	app.set_process(false)
	var arena: AdventureArena=app.layer.find_children("*","AdventureArena",true,false)[0]
	arena.set_process(false);arena.native_vfx.set_process(false)
	var run: AdventureRun=app.run
	run.spawn_clock=999
	for i in range(3):
		var t: Dictionary=run.targets[i]
		t.id=[0,5,3][i];t.position=Vector2([700,1020,1130][i],[180,345,510][i]);t.speed=20
		DiveTactics.configure(t,0)
	run.next_id=6
	var scenario: String="sonar" if "--sonar" in OS.get_cmdline_user_args() else "supply" if "--supply" in OS.get_cmdline_user_args() else "impact" if "--impact" in OS.get_cmdline_user_args() else "battle"
	if scenario=="sonar":
		run.launch_enemy_torpedo(run.targets[0]);run.skill_charge=3;run.activate_skill()
	if scenario=="supply":
		run.hp=60;run.targets[2].position=Vector2(800,510);run.targets[2].speed=0
		type_word(run,run.targets[2]);run.step(.5);run.step(.4)
	if scenario=="impact":
		run.targets[1].position=Vector2(810,345);run.targets[1].speed=0
		type_word(run,run.targets[1]);run.step(.45)
	for frame in range(60):
		run.paused=false
		run.step(1.0/60);arena._process(1.0/60);arena.native_vfx._process(1.0/60)
		run.paused=true
		await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://build/v23-dive-"+scenario+"-%02d.png"%frame)
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix): DirAccess.remove_absolute(profile+suffix)
	quit()
