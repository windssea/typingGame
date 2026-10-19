extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func make_run(mode: String, lesson_index := 0, purpose := "training") -> ArcadeRun:
	var battle := ArcadeRun.new()
	battle.context = purpose
	battle.setup(mode,GameContent.lessons()[lesson_index],1,128)
	return battle

func complete_word(battle: ArcadeRun) -> void:
	var target: Dictionary = battle.targets[0]
	for character in str(target.word).substr(target.typed):
		battle.type_character(character)

func _initialize() -> void:
	for mode in ArcadeRun.MODES:
		for lesson_index in range(10):
			for purpose in ["training","challenge"]:
				var battle := make_run(mode,lesson_index,purpose)
				var guard := 0
				while not battle.done and guard<40:
					complete_word(battle)
					guard += 1
				check(battle.done and battle.won and (battle.distance==1 if mode=="racing" else battle.kills==battle.goal), "%s %d %s completes with this lesson vocabulary" % [mode,lesson_index,purpose])
				check(battle.accuracy()==1 and battle.correct>=18,"accurate completion statistics")
		var paused := make_run(mode)
		paused.paused = true
		paused.step(1)
		complete_word(paused)
		check(paused.elapsed==0 and paused.correct==0,"pause freezes simulation and typing: "+mode)
		var training := make_run(mode,9)
		var challenge := make_run(mode,9,"challenge")
		check(training.time_budget("Hello, world!")>challenge.time_budget("Hello, world!"),"training gives more finger lookup time")
		check(training.targets.size()==1,"phrases never overlap multi-lane labels")
	var aliens := make_run("aliens")
	aliens.miss_target(aliens.targets[0])
	check(aliens.shield==30 and aliens.hp==100,"alien shield absorbs damage before hull")
	for i in range(3):
		complete_word(aliens)
	check(aliens.shield==42,"three consecutive hits recharge alien shield")
	var balloons := make_run("balloons",6,"challenge")
	balloons.type_character(str(balloons.targets[0].word)[0])
	var target := balloons.target_by_id(balloons.locked)
	target.remaining = 0.01
	balloons.step(0.05)
	check(balloons.locked==-1 and balloons.hp==80 and balloons.misses==1,"expired locked balloon clears lock and costs one chance")
	for i in range(4):
		balloons.miss_target(balloons.targets[0])
	check(balloons.done and not balloons.won,"balloon challenge loses after five misses")
	var moles := make_run("moles")
	for i in range(20):
		moles.miss_target(moles.targets[0])
	check(moles.hp==100 and not moles.done,"mole training permits unlimited retreat without failure")
	var race := make_run("racing",0,"challenge")
	race.rival = 0.99999
	race.step(0.5)
	check(race.done and not race.won,"racing challenge loses when opponent reaches finish")
	var practice := make_run("racing")
	practice.rival = 1
	practice.step(0.5)
	check(not practice.done,"racing training continues after pacing car finishes")
	for i in range(2):
		complete_word(practice)
	var previous := practice.distance
	complete_word(practice)
	check(practice.distance-previous>1.0/practice.goal,"three-hit nitro increases actual race progress")
	var fighter := make_run("fighter")
	complete_word(fighter)
	check(fighter.enemy_hp==75 and fighter.targets[0].remaining==fighter.targets[0].duration,"punch damages opponent and interrupts attack timer")
	for i in range(3):
		complete_word(fighter)
	check(fighter.round_number==2 and fighter.enemy_hp==100,"four punches knock out opponent and start new round")
	check(TypingGuide.mapping("f").finger==3 and TypingGuide.mapping("j").finger==4,"F and J are opposite index fingers")
	check(TypingGuide.mapping("F").shift_hand=="右手小指" and TypingGuide.mapping("F").shift,"uppercase left key uses right Shift")
	check(TypingGuide.mapping("?").key=="/" and TypingGuide.mapping("?").shift_hand=="左手小指","question mark uses slash and opposite Shift")
	check(TypingGuide.mapping(" ").finger==8,"space uses thumbs")
	var shifted := "~!@#$%^&*()_+{}|:\"<>?"
	var plain := "`1234567890-=[]\\;',./"
	for i in range(shifted.length()):
		check(TypingGuide.mapping(shifted[i]).key==plain[i],"US shifted symbol maps to its physical key: "+shifted[i])
	for lesson in GameContent.lessons():
		for word in lesson.words:
			for character in word:
				var mapping := TypingGuide.mapping(character)
				check(character==" " or mapping.finger<8,"all lesson characters have finger assignments")
	print("ARCADE TEST RESULTS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
