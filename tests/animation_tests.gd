extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	exercise.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+description)

func press(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame

func exercise() -> void:
	var frames: SpriteFrames = load("res://assets/animations/royal-guard-idle-v002/idle.tres")
	check(frames.get_frame_count("idle")==96,"real native frames packed")
	check(is_equal_approx(frames.get_animation_speed("idle"),24),"native 24fps playback")
	for i in [0,47,95]:
		var texture := frames.get_frame_texture("idle",i)
		check(texture is AtlasTexture and texture.get_size()==Vector2(128,128),"valid atlas frame %d" % i)
	var preview: Control = load("res://scenes/animation_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	check(preview.players.size()==3,"native-scale preview instances")
	check(root.gui_get_focus_owner()==preview.play_button,"preview initial keyboard focus")
	await create_timer(0.18).timeout
	check(preview.players[0].frame>0,"animation actually advances")
	await press(KEY_SPACE)
	var frozen: int = preview.players[0].frame
	await create_timer(0.15).timeout
	check(preview.paused and preview.players[0].frame==frozen,"Space freezes native animation")
	await press(KEY_R)
	check(preview.reduced and preview.players[0].frame==0,"reduced motion uses first frame")
	await press(KEY_SPACE)
	check(not preview.players[0].is_playing(),"reduced motion overrides resume")
	await press(KEY_R)
	await create_timer(0.15).timeout
	check(preview.players[0].is_playing() and preview.players[0].frame>0,"normal playback resumes")
	preview.free()
	print("ANIMATION TEST RESULTS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
