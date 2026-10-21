extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error(text)
func make_run() -> ArcadeRun:
	var run := ArcadeRun.new()
	run.setup("fighter",GameContent.lessons()[5],1,21)
	return run
func word(run: ArcadeRun) -> void:
	var target := run.recommended_target()
	for letter in str(target.word).substr(target.typed): run.type_character(letter)
func exercise() -> void:
	for fps in [30,60,120]:
		var run := make_run()
		var events: Array[String] = []
		run.punch_started.connect(func(_attack):events.append("start"))
		run.impact.connect(func(_kind,_point,_power):events.append("contact"))
		word(run)
		check(events==["start"] and run.enemy_hp==100,"typing starts an attack without premature damage, sound or impact")
		var credit := run.correct
		var next := run.recommended_target()
		run.type_character(str(next.word)[0])
		check(run.correct==credit+1,"the next word remains typeable during the jab")
		for i in range(floori(.13*fps)): run.step(1.0/fps)
		check(run.enemy_hp==100,"opponent is not hurt before the contact frame")
		run.paused=true;run.step(.4)
		check(run.enemy_hp==100 and events==["start"],"pause freezes pending contact")
		run.paused=false;run.step(.1)
		check(run.enemy_hp==75 and events==["start","contact"],"one actual contact resolves damage and feedback together")
		run.step(.1)
		check(run.enemy_hp==75 and events.size()==2,"contact cannot resolve twice")
	var guard := make_run()
	guard.skill_charge=3;guard.activate_skill();guard.miss_target(guard.targets[0])
	check(guard.punches.size()==1 and guard.punches[0].kind=="block" and guard.hp==100,"guard creates a real pending enemy punch")
	guard.step(.25)
	check(guard.hp==100 and guard.punches.is_empty(),"guard absorbs damage on the contact frame")
	var loss := make_run()
	loss.hp=10;loss.miss_target(loss.targets[0])
	check(not loss.done and loss.hp==10,"failure waits for the visible enemy punch")
	loss.step(.25)
	check(loss.done and not loss.won and loss.hp==0,"the enemy punch ends the round at contact")
	var intercept := make_run()
	intercept.miss_target(intercept.targets[0])
	word(intercept)
	check(intercept.counters==1 and intercept.punches.all(func(punch):return punch.side==0),"a last-moment typed counter interrupts an enemy punch before contact")
	intercept.step(.25)
	check(intercept.hp==100 and intercept.enemy_hp==50,"interrupted enemy punch cannot deal ghost damage later")
	var knockout := make_run()
	knockout.enemy_hp=25;word(knockout)
	var hud := LiveHud.new();hud.refresh(knockout)
	var snapshot := hud.snapshot
	knockout.step(.2);hud.refresh(knockout)
	check(hud.round_number==2 and hud.snapshot!=snapshot,"a contact-driven knockout redraws the round even without another key")
	hud.free()
	var burst := make_run()
	for i in range(burst.goal): word(burst)
	check(burst.kills==burst.goal and not burst.done,"fast input preserves every completed word and waits for final contact")
	burst.step(.25)
	check(burst.done and burst.won and burst.punches.is_empty(),"queued punches resolve exactly once before victory")
	print("FIGHTER CONTACT: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
