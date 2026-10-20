extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func arcade(mode: String, lesson := 6) -> ArcadeRun:
	var run := ArcadeRun.new()
	run.setup(mode,GameContent.lessons()[lesson],1,716)
	return run
func castle() -> CastleRun:
	var run := CastleRun.new()
	run.setup("castle",GameContent.lessons()[6],1,716)
	run.begin_wave();run.spawn_clock=1000
	return run
func word(run: GameRun, target: Dictionary) -> void:
	run.locked=target.id
	for character in str(target.word).substr(target.typed): run.type_character(character)
func advance(run: GameRun, seconds: float, fps := 60) -> void:
	for i in range(roundi(seconds*fps)): run.step(1.0/fps)
func exercise() -> void:
	for fps in [30,60,120]:
		var fighter:=arcade("fighter")
		var target: Dictionary=fighter.targets[0]
		target.remaining=EnemyTactics.warning_window(target.word,target.duration)+.15
		advance(fighter,.3,fps)
		check(target.intent=="windup","fighter enters a visible windup at all frame rates")
		var hp:=fighter.hp
		word(fighter,target)
		check(fighter.hp==hp and fighter.enemy_hp==50 and fighter.counters==1,"typing interrupts windup and deals double damage")
		check(fighter.correct==str(target.word).length(),"tactical bonus never fabricates typing credit")
		var alien:=arcade("aliens")
		for t in alien.targets: t.remaining=t.duration
		target=alien.targets[0]
		target.remaining=1
		advance(alien,.2,fps)
		check(target.intent=="dive","alien commits to a readable dive")
		var points:=alien.score
		word(alien,target)
		check(alien.counters==1 and alien.score-points==str(target.word).length()*10+5+20,"intercept earns the stated bonus")
	for lesson in range(10):
		var fighter:=arcade("fighter",lesson)
		var target: Dictionary=fighter.targets[0]
		check(EnemyTactics.warning_window(target.word,target.duration)>=target.duration*.4,"training telegraph preserves adequate lesson-scaled input time")
		fighter.skill_charge=3;fighter.activate_skill()
		target.remaining=.01;fighter.step(.02)
		check(fighter.hp==100 and fighter.targets[0].intent=="exposed" and not fighter.guard_ready,"earned guard creates an actionable opening")
		word(fighter,fighter.targets[0])
		check(fighter.enemy_hp==50,"counterattack after a block deals double damage")
	var run:=castle()
	var shaman:=run.spawn_enemy("shaman")
	var guard:=run.spawn_enemy("guard")
	shaman.position=Vector2(220,200);guard.position=Vector2(245,200)
	shaman.speed=0;guard.speed=0;guard.health=10;shaman.timer=0
	run.step(.1)
	check(shaman.intent=="casting" and guard.health==10,"healer selects a wounded ally and warns before healing")
	var origin: Vector2=shaman.position
	var remaining: float=shaman.intent_left
	run.paused=true;advance(run,1)
	check(shaman.position==origin and shaman.intent_left==remaining,"pause freezes decision and motion")
	run.paused=false
	word(run,shaman)
	check(run.interrupts==1 and shaman.intent=="recover" and guard.health==10,"typing cancels an actual pending heal")
	advance(run,3)
	check(guard.health==10,"interrupted spell cannot resolve later")
	shaman.timer=0;shaman.intent="march";run.step(.1)
	run.targets.erase(guard);run.step(.1)
	check(shaman.intent=="march","healer abandons a dead recipient instead of casting into empty space")
	var bomber:=run.spawn_enemy("bomber")
	bomber.position=CastleRun.KEEP+Vector2(155,0)
	run.step(.1)
	check(bomber.intent=="arming" and run.hp==100,"bomber stops to arm without invisible damage")
	origin=bomber.position;advance(run,1)
	check(bomber.position==origin,"armed bomber stays planted while the fuse is visible")
	word(run,bomber)
	check(run.interrupts==2 and bomber.intent=="recover" and run.hp==100,"typing defuses and knocks back surviving bomber")
	run.targets.clear()
	bomber=run.spawn_enemy("bomber");bomber.position=CastleRun.KEEP+Vector2(155,0)
	run.step(.1);advance(run,run.tactic_window(bomber)+.1)
	check(run.hp==70 and not run.targets.has(bomber),"unanswered fuse resolves exactly one explosion")
	var wolf:=run.spawn_enemy("wolf")
	wolf.position=wolf.waypoint
	run.step(.1)
	check(wolf.intent=="rush" and wolf.aim==CastleRun.KEEP,"flanker reaches its waypoint then commits to the keep")
	var normal:=arcade("fighter");var expected: float=normal.targets[0].duration
	normal.step(.3)
	check(is_equal_approx(normal.targets[0].remaining,expected-.3),"AI does not secretly accelerate the existing deadline")
	if "--ui-capture" in OS.get_cmdline_user_args(): await capture()
	print("ENEMY TACTICS RESULTS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
func capture() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var path: String="user://ai-v16-%d.json" % Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.lesson_index=6
	for mode in ["fighter","aliens","castle"]:
		app.start_game(mode)
		if mode=="castle":
			app.run.wave=5;app.run.begin_wave();app.run.spawn_clock=1000
			var healer: Dictionary=app.run.spawn_enemy("shaman");healer.position=Vector2(240,350);healer.timer=0
			var guard: Dictionary=app.run.spawn_enemy("guard");guard.position=Vector2(300,350);guard.health=30
			var bomber: Dictionary=app.run.spawn_enemy("bomber");bomber.position=CastleRun.KEEP+Vector2(150,0)
			app.run.step(.1)
		else:
			var target: Dictionary=app.run.targets[0]
			target.remaining=EnemyTactics.warning_window(target.word,target.duration)*(.4 if mode=="aliens" else .8)
			app.run.step(.1);app.run.step(.1)
		app.run.paused=true
		if is_instance_valid(app.overlay): app.close_modal()
		await process_frame;await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v16-"+mode+"-intent.png")
		if mode=="fighter":
			app.run.paused=false
			var target: Dictionary=app.run.targets[0]
			for character in str(target.word):
				var key:=InputEventKey.new();key.pressed=true;key.unicode=character.unicode_at(0)
				Input.parse_input_event(key);await process_frame
			app.run.paused=true
			if is_instance_valid(app.overlay): app.close_modal()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/v16-fighter-counter.png")
	app.queue_free();await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
