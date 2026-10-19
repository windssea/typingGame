extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+message)

func arcade(speed: float, rank: String, context := "challenge") -> ArcadeRun:
	var run := ArcadeRun.new()
	run.context=context
	run.challenge_rank=rank
	run.setup("fighter",GameContent.lessons()[0],speed,42)
	return run

func _initialize() -> void:
	exercise.call_deferred()

func exercise() -> void:
	var normal := arcade(1,"normal")
	var hard := arcade(1.35,"hard")
	var expert := arcade(1.75,"expert")
	check(normal.targets[0].duration>hard.targets[0].duration and hard.targets[0].duration>expert.targets[0].duration,"higher ranks shorten real reaction windows")
	check(normal.goal==30 and hard.goal==36 and expert.goal==42,"higher ranks require longer real rounds")
	normal.miss_target(normal.targets[0])
	hard.miss_target(hard.targets[0])
	expert.miss_target(expert.targets[0])
	check(normal.hp==80 and hard.hp==75 and expert.hp==70,"challenge ranks have distinct failure tolerance")
	var slow := arcade(0.65,"normal","training")
	var fast := arcade(1.6,"normal","training")
	check(slow.targets[0].duration>fast.targets[0].duration*2,"training speed changes actual target lifetimes")
	for rank in range(3):
		var castle := CastleRun.new()
		castle.context="challenge"
		castle.challenge_rank=SessionOptions.RANK_IDS[rank]
		castle.setup("castle",GameContent.lessons()[0],SessionOptions.RANK_SPEEDS[rank],32)
		var enemy := castle.spawn_enemy("boss")
		check(enemy.health==ceili(330*(1+rank*0.2)),"boss rank health "+str(rank))
		var before := castle.hp
		castle.damage_castle(20)
		check(castle.hp==before-ceili(20*(1+rank*0.15)),"castle rank damage "+str(rank))
		var sprint := GameRun.new()
		sprint.context="challenge"
		sprint.challenge_rank=SessionOptions.RANK_IDS[rank]
		sprint.setup("sprint",GameContent.lessons()[0],1)
		sprint.correct=[18,36,60][rank]
		sprint.attempts=sprint.correct
		sprint.step(60)
		check(sprint.won,"sprint accepts each rank goal")
	var failed_sprint := GameRun.new()
	failed_sprint.context="challenge"
	failed_sprint.challenge_rank="expert"
	failed_sprint.setup("sprint",GameContent.lessons()[0],1)
	failed_sprint.correct=59
	failed_sprint.attempts=59
	failed_sprint.step(60)
	check(failed_sprint.done and not failed_sprint.won,"expert sprint fails below its target")
	var store := ProfileStore.new()
	store.path="user://motion-test-%d.json" % Time.get_ticks_usec()
	check(store.valid(ProfileStore.fresh()),"old saves remain compatible")
	var bad := ProfileStore.fresh()
	bad.settings.training_speed=100
	check(not store.valid(bad),"out-of-range speed cannot enter a save")
	var bad_rank := ProfileStore.fresh()
	bad_rank.settings.challenge_rank="invalid"
	check(not store.valid(bad_rank),"unknown challenge rank is rejected")
	for run in [normal,hard,expert,slow,fast]:
		store.record_run(run,0)
	check(store.data.records.size()==5,"speed and difficulty never overwrite one another's records")
	store.data.settings.training_speed=1.3
	store.data.settings.challenge_rank="expert"
	store.data.settings.sound=false
	store.save_profile()
	var reloaded := ProfileStore.new()
	reloaded.path=store.path
	reloaded.load_profile()
	check(reloaded.data.settings.training_speed==1.3 and reloaded.data.settings.challenge_rank=="expert","selected settings survive save and reload")
	var juice := GameJuice.new()
	for i in range(25):
		juice.burst(Vector2(150,150),Color.GOLD,3)
	check(juice.particles.size()<=GameJuice.LIMIT,"particle bursts obey the visual budget")
	var subject := arcade(1,"normal","training")
	subject.type_character(subject.targets[0].word)
	check(subject.correct==1,"typing stays immediate while particle feedback is active")
	juice.step(2)
	check(juice.particles.is_empty(),"all transient particles expire")
	juice.reduced_motion=true
	juice.burst(Vector2.ZERO,Color.GOLD,3)
	check(juice.particles.size()==4,"reduced motion reduces particles")
	for side in range(2):
		check(BoxingMotion.texture(side,0,-1,false)!=BoxingMotion.texture(side,0.3,-1,false),"idle advances native frames for side "+str(side))
		check(BoxingMotion.texture(side,0,-1,true)==BoxingMotion.texture(side,1,0.3,true),"reduced motion freezes animation for side "+str(side))
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.store.path=store.path
	root.add_child(app)
	await process_frame
	app.select_speed(4)
	check(app.pace==1.6 and app.get_viewport().gui_get_focus_owner().name=="TrainingSpeed4","speed selector preserves keyboard focus")
	app.start_game("balloons")
	check(app.run.difficulty==1.6,"selected training speed reaches the actual run")
	app.select_rank(2)
	check(app.get_viewport().gui_get_focus_owner().name=="ChallengeRank2","rank selector preserves keyboard focus")
	app.start_game("fighter","challenge")
	check(app.run.challenge_rank=="expert" and app.run.difficulty==1.75 and app.run.goal==42,"selected difficulty reaches the actual game")
	var arena: ArcadeArena
	for child in app.layer.get_children():
		if child is ArcadeArena:
			arena=child
	app.run.type_character(app.run.targets[0].word)
	check(arena.blue_attack_age==0 and not arena.juice.particles.is_empty(),"real hit starts native punch and particles")
	app.run.paused=true
	var frame_clock: float = arena.clock
	var count: int = arena.juice.particles.size()
	arena._process(1)
	check(arena.clock==frame_clock and arena.juice.particles.size()==count,"pause freezes animation and particle simulation")
	app.free()
	await create_timer(0.12).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):
			DirAccess.remove_absolute(store.path+suffix)
	print("MOTION AND DIFFICULTY: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
