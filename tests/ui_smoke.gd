extends SceneTree

var app: Control
var checks := 0
var failures := 0
var profile_path: String

func _initialize() -> void:
	exercise.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func capture(name_value: String) -> void:
	await process_frame
	if "--ui-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/"+name_value+"-preview.png")

func key(character: String, echo := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = echo
	event.unicode = character.unicode_at(0)
	event.keycode = character.to_upper().unicode_at(0)
	Input.parse_input_event(event)
	await process_frame

func press(text_value: String) -> bool:
	for control in app.layer.find_children("*","Button",true,false):
		if control.text == text_value and not control.disabled:
			control.pressed.emit()
			return true
	return false

func exercise() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	profile_path = "user://test-ui-%d.json" % Time.get_ticks_usec()
	app.store.path = profile_path
	root.add_child(app)
	await process_frame
	check(app.page == "home", "boots into home")
	app.show_lessons()
	await capture("lessons")
	check(app.page == "lessons", "lesson page reachable")
	app.show_training_games()
	await capture("training-games")
	check(app.page=="training_games","course leads to game selection")
	app.show_challenges()
	await capture("challenges")
	check(app.page=="challenges","separate challenge hub")
	app.select_lesson(0)
	app.start_game("dojo")
	await capture("dojo")
	app.run.paused = false
	var target: String = app.run.targets[0].word
	await key(target, true)
	check(app.run.correct == 0, "echo ignored by input handler")
	await key(target)
	check(app.run.correct == 1, "actual InputEventKey reaches typing model")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	Input.parse_input_event(escape)
	await process_frame
	check(app.run.paused and is_instance_valid(app.overlay), "escape opens pause UI")
	await capture("pause")
	app.toggle_pause()
	while app.run.kills<18:
		app.run.paused = false
		app.run.type_character(str(app.run.targets[0].word))
	app.run.step(4)
	await capture("result")
	check(is_instance_valid(app.overlay) and app.store.data.completed.has("home_index"), "result overlay and profile recorded")
	app.show_home()
	await capture("two-path-home")
	check(app.layer.find_child("StartTraining",true,false)!=null and app.layer.find_child("StartChallenge",true,false)!=null, "training and challenge are the two entry paths")
	app.show_profile()
	await capture("profile")
	check(app.page == "profile", "profile reachable")
	app.show_import()
	await capture("import")
	check(is_instance_valid(app.overlay), "import modal reachable")
	var blocked := true
	for control in app.modal_focus:
		blocked = blocked and control.focus_mode == Control.FOCUS_NONE
	check(blocked and not app.modal_focus.is_empty(), "modal excludes background buttons from keyboard focus")
	app.close_modal()
	check(app.modal_focus.is_empty(), "modal restores underlying focus modes")
	app.start_game("bubbles")
	await capture("bubbles")
	check(app.run.targets.size()==4,"bubble game is integrated")
	app.start_game("sprint","challenge")
	await capture("sprint")
	check(app.run.context=="challenge","challenge purpose reaches session")
	app.start_game("castle","challenge")
	app.castle_audio.enabled=false
	await capture("castle-build")
	if app.run.paused:
		app.toggle_pause()
	check(press("火焰塔  60 G") and app.run.towers.size()==1,"build button constructs tower")
	check(press("2") and app.run.selected_pad==1,"pad selector changes selected construction slot")
	var mouse := InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	mouse.position=root.get_final_transform()*(Vector2(40,130)+CastleRun.PADS[2])
	Input.parse_input_event(mouse)
	await process_frame
	mouse=mouse.duplicate()
	mouse.pressed=false
	Input.parse_input_event(mouse)
	await process_frame
	check(app.run.selected_pad==2,"real pointer click selects map construction pad")
	check(not press("寒冰塔  70 G"),"unaffordable tower button disabled")
	check(press("开始第 1 波  →") and app.run.phase=="assault","begin wave button starts combat")
	app.run.spawn_target()
	var word: String = app.run.targets[0].word
	await key(word)
	check(app.run.words_completed==1,"castle receives real keyboard input")
	app.run.paused=true
	await capture("castle-combat")
	app.show_home()
	check(app.run == null, "return home clears active run")
	var restored := ProfileStore.new()
	restored.path = profile_path
	restored.load_profile()
	check(restored.data.completed.has("home_index"), "UI session save survives reload")
	app.queue_free()
	await process_frame
	await create_timer(.1).timeout
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):
			DirAccess.remove_absolute(profile_path+suffix)
	print("UI TEST RESULTS: %d checks; %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
