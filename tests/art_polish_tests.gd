extends SceneTree
var app: Control
var checks:=0
var failures:=0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1;push_error("FAIL: "+message)
func arena() -> GameArena:
	return app.layer.find_children("*","GameArena",true,false)[0]
func settle() -> void:
	for i in range(4): await process_frame
func press(code: Key) -> void:
	app.run.paused=false
	var key:=InputEventKey.new();key.pressed=true;key.keycode=code
	Input.parse_input_event(key);await process_frame
func letter(character: String) -> void:
	app.run.paused=false
	var key:=InputEventKey.new();key.pressed=true;key.unicode=character.unicode_at(0)
	Input.parse_input_event(key);await process_frame
func capture(name: String) -> void:
	if not "--ui-capture" in OS.get_cmdline_user_args(): return
	app.run.paused=true
	if is_instance_valid(app.overlay): app.close_modal()
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/v17-"+name+".png")
func exercise() -> void:
	for id in ["tower-fire","tower-ice","tower-storm","castle-keep","tower-pad"]:
		var image:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/v17/"+id+".png"))
		check(image!=null and image.has_mipmaps()==false,"source raster loads independently: "+id)
		check(image.get_pixel(0,0).a==0 and image.get_pixel(image.get_width()-1,image.get_height()-1).a==0,"cutout has real transparent corners: "+id)
		var edge_alpha:=0.0
		for x in range(image.get_width()): edge_alpha=maxf(edge_alpha,maxf(image.get_pixel(x,0).a,image.get_pixel(x,image.get_height()-1).a))
		check(edge_alpha==0,"source normalization leaves vertical padding: "+id)
		check(image.get_width()>=512,"runtime cutout has adequate native texel density: "+id)
		check("mipmaps/generate=true" in FileAccess.get_file_as_string("res://assets/generated/v17/"+id+".png.import"),"mipmapped minification is configured: "+id)
	app=load("res://scenes/main.tscn").instantiate()
	var path: String="user://art-v17-%d.json" % Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false
	root.add_child(app);await settle()
	app.lesson_index=6
	app.start_game("sprint")
	var stage:=arena()
	stage._process(.2)
	check(stage.sprint_steps==0 and not stage.sprint_running,"runner stays idle when nothing is typed")
	var target: Dictionary=app.run.recommended_target()
	await letter(str(target.word)[0]);stage._process(.2)
	check(stage.sprint_steps>0 and stage.sprint_running,"valid actual key input moves the runner")
	app.run.paused=false;stage._process(1)
	var steps: float=stage.sprint_steps
	await letter("#");stage._process(.2)
	check(stage.sprint_steps==steps,"wrong input never fabricates running distance")
	app.run.paused=true;stage._process(1)
	check(stage.sprint_steps==steps,"pause freezes runner motion")
	app.run.paused=false;stage.reduced_motion=true
	await letter(str(app.run.recommended_target().word).substr(app.run.recommended_target().typed,1));stage._process(.1)
	check(stage.sprint_steps==app.run.correct,"reduced motion immediately reflects accepted input without trailing movement")
	app.start_game("sprint");stage=arena()
	target=app.run.recommended_target()
	for c in str(target.word).left(2): await letter(c)
	stage._process(.08)
	await capture("sprint-board")
	GeneratedArt.warm_props("castle")
	app.start_game("castle");app.run.gold=1000
	check(GeneratedArt.pending.is_empty(),"async warmed props are consumed without leaving pending jobs")
	for code in [KEY_Q,KEY_2,KEY_W,KEY_3,KEY_E]: await press(code)
	check(app.run.towers.size()==3 and app.run.gold==785,"keyboard builds three actual tower kinds at their real costs")
	await settle()
	var battle_arena: CastleArena=arena()
	for id in GeneratedArt.POLISHED:
		check(battle_arena.art.sprites.has(id) and not battle_arena.art.sprites[id] is AtlasTexture,"polished prop uses an independent cutout, not a bleeding old atlas region: "+id)
	check(battle_arena.backdrop.texture.resource_path==GeneratedArt.background_path("castle"),"battlefield and castle are separate live layers")
	check(battle_arena.spell_origin(CastleRun.KEEP)==CastleRun.KEEP-Vector2(0,60),"player projectile starts at the castle building")
	check(battle_arena.spell_origin(CastleRun.PADS[0])==CastleRun.PADS[0]-Vector2(0,78),"tower projectile starts at the resized tower head")
	app.run.paused=false;battle_arena._process(1)
	await capture("castle-build")
	app.run.paused=false;app.run.wave=5;await press(KEY_N);app.run.spawn_clock=1000
	var positions: Array[Vector2]=[Vector2(175,205),Vector2(850,220),Vector2(180,490),Vector2(855,490),Vector2(520,140)]
	var kinds: Array[String]=["guard","wolf","shaman","bomber","goblin"]
	for i in range(kinds.size()):
		var enemy: Dictionary=app.run.spawn_enemy(kinds[i]);enemy.position=positions[i]
	app.run.locked=app.run.targets.back().id
	app.run.targets.back().word="forest"
	await settle()
	var top_label: Rect2=battle_arena.label_rects[app.run.targets.back().id]
	check(top_label.get_center().distance_to(app.run.targets.back().position)<230,"top-edge active word stays near its actual enemy")
	await capture("castle-combat")
	app.run.paused=false
	target=app.run.targets[0];app.run.locked=target.id
	var completed_word:=str(target.word)
	for c in completed_word: await letter(c)
	check(app.run.words_completed==1 and app.run.correct==completed_word.length(),"visual replacement preserves real rune input accounting")
	check(not battle_arena.effects.is_empty(),"input still launches actual spell feedback")
	app.run.paused=false;battle_arena._process(.07)
	await capture("castle-spell")
	app.queue_free();await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ART POLISH RESULTS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
