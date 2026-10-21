extends SceneTree

var checks:=0
var failures:=0
var app: Control
var capture_enabled:=false
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(description)
func type_word(run: GameRun, target: Dictionary) -> void:
	for letter in str(target.word).substr(target.typed): run.type_character(letter)
func settle() -> void:
	for i in range(4):await process_frame
func capture(name_value: String) -> void:
	if not capture_enabled: return
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/v20-"+name_value+".png")

func exercise() -> void:
	capture_enabled="--ui-capture" in OS.get_cmdline_user_args()
	var lesson: Dictionary=GameContent.lessons()[5]
	for rank in ["normal","hard","master"]:
		var castle:=CastleRun.new();castle.context="challenge";castle.challenge_rank=rank
		castle.setup("castle",lesson,1,42);castle.begin_wave()
		var goblin:=castle.spawn_enemy("goblin");goblin.position=Vector2(130,300)
		var word: String=goblin.word
		type_word(castle,goblin)
		check(goblin.word==word and goblin.pending and goblin.typed==word.length(),"word stays completed until the projectile hits: "+rank)
		check(castle.recommended_target().is_empty(),"pending foe offers no duplicate prompt")
		castle.step_projectiles(2)
		check(not castle.targets.has(goblin) and castle.kills==1,"one word defeats an ordinary goblin: "+rank)
	var guard_run:=CastleRun.new();guard_run.setup("castle",lesson,1,42);guard_run.begin_wave()
	var guard:=guard_run.spawn_enemy("guard");guard.position=Vector2(120,300)
	type_word(guard_run,guard);var held_word: String=guard.word
	guard_run.step_projectiles(.01)
	check(guard.pending and guard.word==held_word and guard.health==85,"armor prompt cannot refresh mid-flight")
	guard_run.damage_enemy(guard,10,"ice",guard.position+Vector2(0,78))
	guard_run.step_projectiles(.01)
	check(guard.pending and guard.word==held_word and guard.health==75,"another tower's earlier impact cannot refresh the player's pending word")
	guard_run.step_projectiles(2)
	check(not guard.pending and guard.typed==0 and guard.health==39,"armor opens its next attack only after impact")
	var dive:=AdventureRun.new();dive.setup("submarine",lesson,1,42)
	check(dive.targets.all(func(target): return target.position.x>1360),"all submarines spawn beyond the right edge")
	check(dive.recommended_target().is_empty(),"offscreen submarine cannot receive a typing prompt")
	for i in range(120):dive.step(.1)
	check(not dive.recommended_target().is_empty(),"submarines sail smoothly into the playable area")
	var royal:=AdventureRun.new();royal.setup("royal",lesson,1,42)
	royal.targets.clear();royal.next_id=5;royal.spawn_target()
	var boss: Dictionary=royal.targets[0];boss.position=Vector2(650,235)
	for hit in range(3):
		type_word(royal,boss);royal.step_projectiles(3)
		check(royal.targets.has(boss)==(hit<2),"boss requires all three actual projectile impacts")
	check(royal.bosses_defeated==1,"royal boss defeat is recorded")
	app=load("res://scenes/main.tscn").instantiate()
	var path: String="user://product-v20-%d.json"%Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false
	root.add_child(app);await settle()
	root.size=Vector2i(1440,900)
	await capture("home")
	if capture_enabled:
		app.show_lessons();await capture("lessons")
		app.show_training_games();await capture("training-games")
		app.show_challenges();await capture("challenges")
		app.show_profile();await capture("settings")
	app.start_game("fighter");await settle()
	app.run.skill_charge=3
	var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_SPACE;event.unicode=32
	app._input(event)
	check(app.run.skill_uses==1 and app.run.attempts==0,"Space triggers the skill without a typing mistake")
	app.run.skill_time=0;app.run.skill_charge=3
	var phrase: Dictionary=app.run.targets[0]
	phrase.word="red fox";phrase.typed=3;app.run.locked=phrase.id
	var used: int=app.run.skill_uses
	app._input(event)
	check(phrase.typed==4 and app.run.skill_uses==used,"a required phrase space wins over the skill shortcut")
	app.lesson_index=5
	for mode in ["racing","fighter","restaurant","royal","submarine","rain","castle","balloons","aliens","moles","bubbles","sprint","dojo"]:
		app.start_game(mode,"challenge")
		if mode=="castle":
			app.run.begin_wave();app.run.spawn_enemy("goblin").position=Vector2(220,320)
		elif mode=="royal":
			app.run.next_id=5;app.run.spawn_target();app.run.targets.back().position=Vector2(930,445)
		elif mode=="submarine":
			for i in range(55):app.run.step(.1)
		elif mode=="rain":
			for i in range(5):app.run.spawn_target()
			for target in app.run.targets: target.position.y=150+target.id*65
		await settle()
		var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
		if mode=="racing":
			for lane in range(2):
				var at: Vector2=arena.track_point(.5,lane)
				var rendered: Vector2=arena.backdrop.get_global_transform().affine_inverse()*(arena.get_global_transform()*at)
				var tex: Vector2=arena.art.background.get_size()
				var factor:=maxf(arena.backdrop.size.x/tex.x,arena.backdrop.size.y/tex.y)
				var source_y: float=(rendered.y-(arena.backdrop.size.y-tex.y*factor)/2)/factor
				check(source_y>480 and source_y<635 if lane==0 else source_y>710 and source_y<870,"car center belongs to the actual painted road: lane "+str(lane))
		if mode=="restaurant":check(arena.art.sprites.has("prep0_0") and arena.art.sprites.has("prep2_2"),"all cooking states use generated food art")
		if mode=="rain":
			arena.native_vfx._process(.1)
			check(arena.native_vfx.meteor_trails.size()==12 and arena.native_vfx.snapshot().meteor_trails>0,"meteors have bounded native CPUParticles2D tails")
			if capture_enabled: await create_timer(.75).timeout
		app.run.paused=true;await capture(mode)
	app.show_home();app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("PRODUCT V20: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
