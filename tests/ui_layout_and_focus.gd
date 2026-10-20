extends SceneTree

var app: Control
var checks := 0
var failures := 0
var profile_path := ""
var capture_enabled := false

func _initialize() -> void:
	capture_enabled = "--ui-capture" in OS.get_cmdline_user_args()
	exercise.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func settle() -> void:
	for i in range(4):
		await process_frame

func capture(name_value: String) -> void:
	if capture_enabled:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v12-"+name_value+".png")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	Input.parse_input_event(event)
	await settle()

func exercise() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	profile_path = "user://layout-v12-%d.json" % Time.get_ticks_usec()
	app.store.path = profile_path
	root.add_child(app)
	await settle()
	check(root.content_scale_size==Vector2i(1440,900),"explicit reference resolution remains 1440 by 900")
	check(app.layer.find_child("HomeLayout",true,false) is MarginContainer,"home respects anchored safe margins")
	check(app.layer.find_child("StartTraining",true,false).has_focus(),"home starts on training")
	await capture("home")
	app.show_lessons()
	await settle()
	check(app.layer.find_child("CourseLayout",true,false) is MarginContainer,"course grid uses containers")
	var first: Button = app.layer.find_child("Course0",true,false)
	first.grab_focus()
	await key(KEY_RIGHT)
	check(root.gui_get_focus_owner()==app.layer.find_child("Course1",true,false),"right arrow moves to the next course column")
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner()==app.layer.find_child("Course3",true,false),"down arrow moves within the same course column")
	app.select_lesson(5)
	await settle()
	check(app.layer.find_child("Course5",true,false).has_focus(),"selection rebuild preserves course focus")
	await capture("courses")
	for resolution in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1920,800)]:
		root.size = resolution
		await settle()
		app.start_game("fighter")
		app.run.paused = true
		await settle()
		var shell: GameShell = app.layer.find_child("GameShell",true,false)
		var dock: ActionCue = app.layer.find_child("InputDock",true,false)
		var arena: GameArena = shell.field.get_child(0)
		var header_rect := shell.header.get_global_rect()
		var dock_rect := dock.get_global_rect()
		check(shell is MarginContainer,"anchored game shell: "+str(resolution))
		check(header_rect.end.y<=arena.global_position.y-16,"header stays clear of playfield: "+str(resolution))
		check(arena.get_global_rect().end.y<=dock_rect.position.y-8,"arena leaves input-dock breathing room: "+str(resolution))
		check(app.typing_guide.get_global_rect().end.y<=dock_rect.position.y-8,"assistant cannot push the input dock off screen: "+str(resolution))
		check(Rect2(Vector2.ZERO,app.size).encloses(dock_rect),"input dock remains within viewport: "+str(resolution))
		check(not app.pause_button.get_global_rect().intersects(app.live_hud.get_global_rect()),"pause and metrics never overlap: "+str(resolution))
		await capture("fighter-%dx%d" % [resolution.x,resolution.y])
	root.size = Vector2i(1280,800)
	app.start_game("dojo")
	app.run.paused = true
	await settle()
	var refreshes: int = app.live_hud.refresh_count
	await settle()
	check(app.live_hud.refresh_count==refreshes,"idle HUD performs no per-frame refresh")
	app.run.hp = app.run.hp
	await settle()
	check(app.live_hud.refresh_count==refreshes,"unchanged model value emits no HUD update")
	app.run.hp -= 7
	app.run.score += 25
	await settle()
	check(app.live_hud.refresh_count==refreshes+1 and app.live_hud.values[0][1]=="25","stat events coalesce into one correct HUD refresh")
	app.run.paused = false
	app.toggle_pause()
	await settle()
	var pause: Control = app.overlay
	var focus: Control = root.gui_get_focus_owner()
	await key(KEY_F1)
	check(app.screen_stack.size()==2 and app.guide_open,"help pushes above pause")
	check(not pause.visible and app.run.paused,"covered pause is hidden and game remains frozen")
	await key(KEY_ESCAPE)
	check(app.overlay==pause and app.run.paused and not app.guide_open,"closing help restores paused screen without resuming combat")
	check(root.gui_get_focus_owner()==focus,"closing help restores exact pause action focus")
	await key(KEY_TAB)
	check(app.overlay.is_ancestor_of(root.gui_get_focus_owner()),"Tab cannot escape the top modal")
	await capture("pause")
	await key(KEY_ESCAPE)
	check(app.screen_stack.is_empty() and not app.run.paused,"escape pops pause and resumes gameplay")
	app.show_home()
	await settle()
	check(app.screen_stack.is_empty() and app.run==null,"navigating to home clears every overlay and run")
	app.queue_free()
	await process_frame
	await create_timer(.1).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):
			DirAccess.remove_absolute(profile_path+suffix)
	print("UI LAYOUT AND FOCUS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
