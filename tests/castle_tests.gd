extends SceneTree

var checks := 0
var failures := 0

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+message)

func game(index := 6) -> CastleRun:
	var run := CastleRun.new()
	run.setup("castle",GameContent.lessons()[index],1.0,42)
	return run

func type_word(run: CastleRun,target: Dictionary) -> void:
	var word: String = str(target.word).substr(target.typed)
	for character in word:
		run.type_character(character)

func _initialize() -> void:
	var run := game()
	run.step(5)
	check(run.phase=="build" and run.elapsed==0 and run.targets.is_empty(),"construction freezes battle timer and enemies")
	check(not run.type_character("f") and run.attempts==0,"build input does not enter statistics")
	check(run.build_tower(0,"fire") and run.gold==50,"build pays exact cost")
	check(not run.build_tower(0,"ice") and run.gold==50,"occupied pad cannot be overwritten")
	check(not run.build_tower(1,"storm") and run.gold==50,"insufficient funds cannot build")
	check(not run.build_tower(-1,"fire") and not run.build_tower(4,"fire") and not run.build_tower(1,"unknown"),"invalid tower operations rejected")
	run.gold = 1000
	check(run.upgrade_tower(0) and run.tower_at(0).level==2 and run.gold==935,"level two tower upgrade")
	check(run.upgrade_tower(0) and run.tower_at(0).level==3 and run.gold==850,"level three tower upgrade")
	check(not run.upgrade_tower(0),"tower max level enforced")
	check(run.purchase_upgrade("walls") and run.max_hp==125 and run.hp==125,"wall reinforcement")
	check(run.purchase_upgrade("power") and run.upgrades.power==1,"spell reinforcement")
	run.hp = 50
	var funds := run.gold
	check(run.repair() and run.hp==85 and run.gold==funds-35,"repair cost and health")
	run.hp=run.max_hp
	check(not run.repair(),"cannot waste money repairing full health")
	run.begin_wave()
	check(not run.build_tower(1,"ice") and not run.purchase_upgrade("chain") and not run.repair(),"all construction locked during combat")
	check(not run.begin_wave(),"wave start is idempotent")
	run.paused = true
	run.step(3)
	check(run.elapsed==0 and run.spawned==0,"pause freezes combat")
	run.paused = false
	run.step(0.5)
	run.step(0.2)
	check(run.spawned==1,"wave begins spawning")

	run=game()
	run.begin_wave()
	var a := run.spawn_enemy("guard")
	a.word="fire"
	a.position=CastleRun.KEEP+Vector2(150,0)
	var b := run.spawn_enemy("goblin")
	b.word="forest"
	b.position=CastleRun.KEEP+Vector2(80,0)
	run.type_character("f")
	check(run.locked==b.id,"shared initials resolve urgency")
	run.type_character("x")
	check(b.typed==1 and run.correct==1,"wrong input preserves prefix")
	run.cancel_target()
	check(run.correct==0 and run.locked==-1,"cancellation removes abandoned effective chars")
	run.targets.erase(b)
	type_word(run,a)
	check(a.health==49 and run.kills==0 and a.typed==0 and run.energy==2,"armored enemy survives and receives next prompt")
	check(run.locked==a.id,"armored target remains locked")
	type_word(run,a)
	type_word(run,a)
	check(run.kills==1 and run.gold==134 and run.energy==6,"multi-prompt enemy kill and bounty")

	run=game(0)
	run.begin_wave()
	for kind in ["goblin","wolf","guard","shaman","bomber"]:
		run.spawn_enemy(kind)
	run.combo=4
	type_word(run,run.targets[0])
	check(run.combo==5 and run.correct==1 and run.energy==2,"chain spell grants no extra typing credit or energy")
	check(run.kills>=2,"chain spell damages additional targets")

	run=game()
	run.begin_wave()
	var boss := run.spawn_enemy("boss")
	boss.windup=3.0
	type_word(run,boss)
	check(boss.windup==0 and boss.timer==10,"typing boss prompt interrupts attack")
	boss.health=160
	run.step(0.01)
	check(boss.rage,"boss enters enraged phase below half health")
	boss.windup=0.01
	var health := run.hp
	run.step(0.02)
	check(run.hp==health-18,"uninterrupted boss quake damages castle")
	boss.position=CastleRun.KEEP
	run.step(0.01)
	check(run.targets.has(boss),"boss at keep remains a siege threat until killed")
	run.damage_enemy(boss,999,"fire",CastleRun.KEEP)
	check(run.bosses_defeated==1 and not run.targets.has(boss),"boss defeat recorded")

	run=game()
	run.begin_wave()
	var shaman := run.spawn_enemy("shaman")
	var guard := run.spawn_enemy("guard")
	shaman.position=Vector2(200,200)
	guard.position=Vector2(230,200)
	guard.health=30
	shaman.timer=0
	run.step(0.01)
	check(guard.health==42,"shaman heals nearby allies")
	var bomber := run.spawn_enemy("bomber")
	bomber.position=CastleRun.KEEP
	run.hp=30
	run.step(0.01)
	check(run.done and not run.won and run.hp==0,"bomber breach can cause defeat")

	for kind in ["fire","ice","storm"]:
		run=game()
		run.build_tower(0,kind)
		run.begin_wave()
		var target := run.spawn_enemy("guard")
		target.position=CastleRun.PADS[0]+Vector2(70,0)
		var second := run.spawn_enemy("guard")
		second.position=target.position-Vector2(35,0)
		run.update_towers(0.1)
		check(target.health==85,"tower requires typing charge: "+kind)
		run.energy=1
		run.update_towers(0.1)
		check(target.health<85 and run.energy==0,"tower attack consumes one charge: "+kind)
		if kind=="ice":
			check(target.slow>0,"ice applies slow")
		else:
			check(second.health<85,"fire splash / storm chain affects second enemy: "+kind)

	run=game(9)
	run.begin_wave()
	for i in range(100):
		run.step(0.1)
	check(run.targets.size()<=2,"sentence concurrency bounded")

	# Full campaign through public typing and wave transitions, including both bosses.
	run=game(6)
	run.build_tower(0,"fire")
	var cap := 0
	while not run.done and cap<15000:
		cap+=1
		if run.phase=="build":
			run.purchase_upgrade("power")
			run.begin_wave()
		run.step(0.1)
		if not run.targets.is_empty():
			var selected := run.target_by_id(run.locked)
			type_word(run,run.targets[0] if selected.is_empty() else selected)
	check(run.done and run.won and run.wave==6,"full six wave campaign wins")
	check(run.bosses_defeated==2 and run.kills==52,"campaign contains and defeats two bosses and all 52 enemies")
	var saved_score := run.score
	run.step(10)
	run.type_character("f")
	check(run.score==saved_score and not run.build_tower(3,"ice"),"finished campaign is immutable")
	print("CASTLE TEST RESULTS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
