extends SceneTree

# Real rendered film: simulation and renderer advance on the same controlled clock.
func _initialize() -> void: exercise.call_deferred()
func exercise() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var profile: String="user://fighter-film-%d.json"%Time.get_ticks_usec()
	app.store.path=profile;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	root.size=Vector2i(1440,900)
	app.lesson_index=5
	app.start_game("fighter")
	app.set_process(false)
	var arena: ArcadeArena=app.layer.find_children("*","ArcadeArena",true,false)[0]
	arena.set_process(false);arena.native_vfx.set_process(false)
	var scenario := "enemy" if "--enemy" in OS.get_cmdline_user_args() else "block" if "--block" in OS.get_cmdline_user_args() else "ko" if "--ko" in OS.get_cmdline_user_args() else "blue"
	if scenario=="ko": app.run.enemy_hp=25
	if scenario=="block": app.run.skill_charge=3;app.run.activate_skill()
	if scenario in ["enemy","block"]: app.run.miss_target(app.run.recommended_target())
	else:
		var target: Dictionary=app.run.recommended_target()
		for character in str(target.word): app.run.type_character(character)
	for frame in range(40):
		app.run.paused=false
		app.run.step(1.0/60);arena._process(1.0/60);arena.native_vfx._process(1.0/60)
		app.run.paused=true
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://build/v21-fighter-"+scenario+"-%02d.png"%frame)
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix): DirAccess.remove_absolute(profile+suffix)
	quit()
