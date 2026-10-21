extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(description)
func exercise() -> void:
	for font_size in [32,48,88]:
		var previous:=Vector2.ZERO
		for word in ["jf","fj","ill","ii","jj","lo","a","WW"]:
			var layout:=TypingPrompt.measure(word,1080,font_size,font_size)
			check(layout.size.x>=TypingPrompt.MIN_CARD_WIDTH and layout.size.y>=TypingPrompt.MIN_CARD_HEIGHT,"short target retains minimum plaque: "+word)
			check(layout.size.x>=font_size*3.2,"large training font expands short plaque horizontally")
			for row in layout.rows:
				check((layout.size.x-row.width)*.5>=TypingPrompt.CARD_PADDING,"text has clear space from material bevel")
			if word in ["jf","fj","ill","ii","jj","lo"]:
				check(previous==Vector2.ZERO or layout.size==previous,"narrow key combinations share the same stable card size")
				previous=layout.size
	for maximum in [220.0,340.0,834.0]:
		var layout:=TypingPrompt.measure("Would you like a glass of orange juice?",maximum,48,32)
		check(layout.size.x<=maximum,"minimum never overrides viewport width")
		var rebuilt:=""
		for row in layout.rows: rebuilt+=row.text
		check(rebuilt=="Would you like a glass of orange juice?","long phrases retain every character")
	if "--capture" in OS.get_cmdline_user_args():
		var app: Control=load("res://scenes/main.tscn").instantiate()
		var profile: String="user://prompt-minimum-%d.json"%Time.get_ticks_usec()
		app.store.path=profile;app.store.data.settings.sound=false
		root.add_child(app);await process_frame
		app.lesson_index=1;app.start_game("dojo");app.set_process(false)
		app.run.targets[0].word="jf";app.run.targets[0].typed=1;app.run.paused=true
		for resolution in [Vector2i(1440,900),Vector2i(1280,720)]:
			root.size=resolution
			for i in range(3): await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://build/v22-minimum-%dx%d.png"%[resolution.x,resolution.y])
		app.queue_free();await process_frame
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(profile+suffix): DirAccess.remove_absolute(profile+suffix)
	print("PROMPT MINIMUM: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
