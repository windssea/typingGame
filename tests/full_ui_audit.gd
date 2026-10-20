extends SceneTree

var app: Control
var checks := 0
var failures := 0
var report: Array = []
var capture_enabled := false
var profile_path := ""

func _initialize() -> void:
	capture_enabled = "--ui-capture" in OS.get_cmdline_user_args()
	exercise.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func settle() -> void:
	for i in range(5): await process_frame

func visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var parent := control.get_parent()
	while parent is Control:
		if parent.clip_contents:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect.intersection(Rect2(Vector2.ZERO,app.size))

func review(title: String, take_picture := true) -> void:
	var game_frame: bool = app.page=="game" and not ["pause","help","win","retry"].any(func(prefix): return title.begins_with(prefix))
	if game_frame:
		# Native focus loss can open pause while the test window is in the background.
		# Inspect the intended world, never silently audit the pause overlay instead.
		app.run.paused=true
		while is_instance_valid(app.overlay): app.close_modal()
	await settle()
	if game_frame: check(not is_instance_valid(app.overlay),"game review shows the world rather than a pause overlay: "+title)
	var scope: Control = app.overlay if is_instance_valid(app.overlay) else app.layer
	var controls: Array[Control] = []
	for node in scope.find_children("*","Control",true,false):
		if not node.is_visible_in_tree() or visible_rect(node).get_area()<=0: continue
		if node is Button or node is OptionButton or node is HSlider or node is TextEdit:
			controls.append(node)
	for control in controls:
		var clipped := visible_rect(control)
		check(control.size.y>=44,"44-unit target: "+title+"/"+control.name)
		if not control.find_parent("GameCollection"):
			check(Rect2(Vector2.ZERO,app.size).grow(1).encloses(control.get_global_rect()),"control in viewport: "+title+"/"+control.name)
		var ancestor := control.get_parent()
		while ancestor is Control:
			if ancestor is CastlePanel or ancestor is PanelContainer:
				check(ancestor.get_global_rect().grow(1).encloses(control.get_global_rect()),"action stays inside its surface: "+title+"/"+control.name+"/"+ancestor.name)
			ancestor = ancestor.get_parent()
		if control is Button and not control is OptionButton:
			var font: Font = control.get_theme_font("font")
			var width := font.get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
			check(width<=control.size.x-24,"button text fits: "+title+"/"+control.text)
		for other in controls:
			if control.get_instance_id()>=other.get_instance_id() or control.is_ancestor_of(other) or other.is_ancestor_of(control): continue
			check(not clipped.grow(-2).intersects(visible_rect(other).grow(-2)),"no overlapping actions: "+title+"/"+control.name+"/"+other.name)
	var focus := root.gui_get_focus_owner()
	if app.page!="game" or is_instance_valid(app.overlay):
		check(is_instance_valid(focus) and scope.is_ancestor_of(focus),"initial focus belongs to active page: "+title)
	report.append({"state":title,"window":str(root.size),"controls":controls.size(),"focus":str(focus.name) if is_instance_valid(focus) else "", "screenshot":"v14-audit-"+title+".png" if take_picture and capture_enabled else ""})
	if capture_enabled and take_picture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v14-audit-"+title+".png")

func exercise() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	profile_path="user://audit-v14-%d.json" % Time.get_ticks_usec()
	app.store.path=profile_path
	app.store.data.settings.sound=false
	app.store.save_profile()
	root.add_child(app)
	for resolution in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1920,800)]:
		root.size=resolution
		var suffix := "-%dx%d" % [resolution.x,resolution.y]
		var picture: bool = resolution==Vector2i(1280,800)
		app.show_home(); await review("home"+suffix,picture)
		app.layer.find_child("ChooseCourse",true,false).pressed.emit()
		await settle()
		check(app.page=="lessons" and root.gui_get_focus_owner()==app.layer.find_child("Course%d" % app.lesson_index,true,false),"home offers a direct course path with current-course focus")
		app.show_lessons(); await review("courses"+suffix,picture)
		app.show_fingering(); await review("fingering"+suffix,picture)
		app.lesson_index=6
		app.show_training_games(); await review("training"+suffix,picture)
		var scroll: ScrollContainer=app.layer.find_child("GameCollection",true,false)
		scroll.scroll_vertical=10000; await review("training-bottom"+suffix,picture)
		app.show_challenges(); await review("challenge"+suffix,picture)
		var text_selector: OptionButton=app.layer.find_child("ChallengeText",true,false)
		text_selector.item_selected.emit(6)
		await settle()
		check(root.gui_get_focus_owner()==app.layer.find_child("ChallengeText",true,false),"changing challenge text retains selector focus")
		app.show_vocabulary(); await review("vocabulary"+suffix,picture)
		app.overlay.find_child("VocabularyTopic",true,false).item_selected.emit(1)
		await settle()
		check(root.gui_get_focus_owner()==app.layer.find_child("VocabularySettings",true,false),"changing topic restores the topic action")
		app.show_profile(); await review("settings"+suffix,picture)
		app.layer.find_child("ReducedMotion",true,false).pressed.emit()
		await settle()
		check(root.gui_get_focus_owner()==app.layer.find_child("ReducedMotion",true,false),"toggling reduced motion retains setting focus")
		app.layer.find_child("ReducedMotion",true,false).pressed.emit()
		app.store.data.key_stats["f"]={"hit":4,"miss":2}
		app.show_profile(); await review("practice-keys"+suffix,picture)
		app.show_import(); await review("import"+suffix,picture)
		var original_xp: int=app.store.data.xp
		for node in app.overlay.find_children("*","TextEdit",true,false): node.text="{invalid}"
		for node in app.overlay.find_children("*","Button",true,false):
			if node.text=="验证并恢复": node.pressed.emit()
		await review("import-error"+suffix,picture)
		check(app.store.data.xp==original_xp,"invalid import keeps current progress")
		app.close_modal()
		for definition in GameContent.modes():
			app.start_game(definition.id)
			if app.run is CastleRun:
				await review("castle-build"+suffix,picture)
				app.run.paused=false
				app.run.begin_wave()
				app.run.spawn_enemy("boss").position=Vector2(780,340)
			elif definition.id=="rain": app.run.spawn_target()
			app.run.step(.4)
			for node in app.layer.find_children("*","Control",true,false):
				if node is GameArena: node._process(.4)
			app.run.paused=true
			await review(definition.id+suffix,picture)
		app.run.paused=false
		app.toggle_pause(); await review("pause"+suffix,picture)
		app.show_game_guide(); await review("help"+suffix,picture)
		app.close_game_guide(); app.toggle_pause()
		app.run.elapsed=60
		for completion in range(100):
			if app.run.done: break
			app.run.paused=false
			var target: Dictionary=app.run.recommended_target()
			for character in str(target.word).substr(target.typed): app.run.type_character(character)
		check(app.run.done and app.run.won,"bounded completion reaches the actual training result")
		await review("win"+suffix,picture)
		app.start_game("fighter","challenge")
		app.run.hp=0; app.run.finish(false)
		await review("retry"+suffix,picture)
	var file := FileAccess.open("res://build/v14-ui-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"states":report},"\t"))
	app.queue_free(); await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	print("FULL UI AUDIT: %d checks; %d failures; %d page/resolution states" % [checks,failures,report.size()])
	quit(1 if failures else 0)
