extends SceneTree

var checks := 0
var failures := 0
var app: Control
var capture_enabled := false

func _initialize() -> void:
	capture_enabled = "--ui-capture" in OS.get_cmdline_user_args()
	exercise.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func capture(name_value: String) -> void:
	if is_instance_valid(app) and is_instance_valid(app.overlay) and name_value not in ["complete","help"]:
		app.close_modal()
		app.run.paused = true
	await process_frame
	await process_frame
	if capture_enabled:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v13-bridge-"+name_value+".png")

func exercise() -> void:
	var slow := BridgeRun.new()
	var fast := BridgeRun.new()
	slow.setup("dojo",GameContent.lessons()[0],.65,17)
	fast.setup("dojo",GameContent.lessons()[0],1.6,17)
	slow.type_character(slow.targets[0].word)
	fast.type_character(fast.targets[0].word)
	slow.step(.05)
	fast.step(.05)
	check(fast.travel>slow.travel and fast.kills==slow.kills,"speed selection changes traversal without requiring faster beginner typing")
	for index in range(10):
		var bridge := BridgeRun.new()
		bridge.setup("dojo",Vocabulary.lesson(GameContent.lessons()[index],"animals"),1,17)
		bridge.type_character("#")
		bridge.step(.2)
		check(bridge.kills==0 and bridge.travel==0 and bridge.hp==100,"wrong key cannot repair a bridge or punish a beginner: %d" % index)
		for tile in range(18):
			var target := bridge.recommended_target()
			var word: String = target.word
			for character in word:
				bridge.type_character(character)
			check(bridge.kills==tile+1,"whole word repairs exactly one tile: %d/%d" % [index,tile])
			check(bridge.travel<=bridge.kills,"robot never enters an unrepaired tile")
			bridge.step(.15)
			check(not bridge.done,"final bridge stays visible before arrival celebration finishes")
		var correct := bridge.correct
		bridge.type_character("f")
		check(bridge.correct==correct and bridge.targets.is_empty(),"no phantom target or extra input after final repair")
		bridge.paused = true
		var progress := bridge.travel
		bridge.step(9)
		check(bridge.travel==progress and not bridge.done,"pause freezes traversal and the ending")
		bridge.paused = false
		bridge.step(2)
		check(bridge.done and bridge.won and bridge.kills==18,"arrival completes the actual eighteen-tile mission")
	app = load("res://scenes/main.tscn").instantiate()
	var path := "user://bridge-tests-%d.json" % Time.get_ticks_usec()
	app.store.path = path
	root.add_child(app)
	app.lesson_index = 0
	app.start_game("dojo")
	app.run.paused = true
	await capture("start")
	check(app.run is BridgeRun,"training launches the actual bridge simulation")
	check(app.layer.find_children("*","BridgeArena",true,false).size()==1,"full scene bridge renderer is integrated")
	check(app.layer.find_children("*","ActionCue",true,false).is_empty(),"no duplicate footer word")
	check(app.layer.find_children("*","TrainingLedger",true,false).is_empty(),"no empty progress ledger")
	check(app.layer.find_children("*","TypingGuide",true,false).is_empty(),"full hand panel is opt-in instead of blocking the game")
	check(app.layer.find_children("*","LiveHud",true,false).is_empty(),"beginner stage has no irrelevant score or WPM dashboard")
	var stage: BridgeArena = app.layer.find_children("*","BridgeArena",true,false)[0]
	app.run.paused = false
	var wrong := InputEventKey.new()
	wrong.pressed = true
	wrong.unicode = "x".unicode_at(0)
	Input.parse_input_event(wrong)
	await process_frame
	check(stage.error_pulse>0 and app.run.kills==0,"real wrong key creates recoverable slip feedback")
	app.run.paused = true
	await capture("miss")
	for tile in range(18):
		if app.run.paused:
			app.toggle_pause()
		var target: Dictionary = app.run.recommended_target()
		for character in str(target.word):
			var event := InputEventKey.new()
			event.pressed = true
			event.unicode = character.unicode_at(0)
			Input.parse_input_event(event)
			await process_frame
		app.run.paused = false
		app.run.step(.13)
		check(app.run.kills==tile+1,"real keyboard repairs tile %d" % tile)
		if tile in [0,5,11,17]:
			app.run.paused = true
			await capture("tile-%02d" % (tile+1))
	check(stage.tile_age.size()==18 and stage.juice.serial>=21,"repairs and three lamps produce actual world feedback")
	app.run.paused = false
	app.run.step(2)
	await capture("complete")
	check(app.run.done and app.store.data.xp==90 and is_instance_valid(app.overlay),"arrival records reward once and opens results")
	app.show_home()
	app.lesson_index = 9
	app.start_game("dojo")
	app.run.recommended_target().word = "Would you like a glass of orange juice?"
	app.run.recommended_target().typed = 14
	app.run.paused = true
	await capture("sentence")
	check(TypingPrompt.measure(app.run.recommended_target().word,1080,88,52).font>=52,"complete phrases remain large and preserve spaces")
	app.show_game_guide()
	await capture("help")
	check(app.guide_open and app.run.paused,"F1 retains optional full keyboard and hands")
	app.close_game_guide()
	check(app.run.paused,"closing help restores the previous pause state")
	for resolution in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1920,800)]:
		root.size = resolution
		app.lesson_index = 0
		app.start_game("dojo")
		app.run.paused = true
		await capture("size-%dx%d" % [resolution.x,resolution.y])
		var world: BridgeArena = app.layer.find_child("BridgeWorld",true,false)
		check(world.size==Vector2(1440,900),"reference world remains intact at "+str(resolution))
		check(Rect2(Vector2.ZERO,app.size).encloses(app.pause_button.get_global_rect()),"pause action remains inside safe area at "+str(resolution))
		check(Rect2(Vector2.ZERO,world.size).encloses(Rect2(620,148,200,210)),"giant prompt remains clear of edges at "+str(resolution))
		check(144*root.get_final_transform().get_scale().y>=100,"actual single-key glyph exceeds 100 screen pixels at "+str(resolution))
	app.queue_free()
	await process_frame
	await create_timer(.1).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(path+suffix)
	print("BRIDGE ADVENTURE: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
