extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func model(id_value:=0,challenge:=true) -> AdventureRun:
	var run:=AdventureRun.new();run.context="challenge" if challenge else "training"
	run.setup("submarine",GameContent.lessons()[5],1,623)
	run.targets.clear();run.next_id=id_value;run.spawn_target();run.spawn_clock=999
	var target: Dictionary=run.targets[0];target.position=Vector2(820,345);target.base_y=345;target.speed=0
	return run
func word(run: AdventureRun, target: Dictionary) -> void:
	run.locked=target.id
	for character in str(target.word).substr(target.typed): run.type_character(character)
func advance(run: AdventureRun, seconds: float, fps: int) -> void:
	for i in range(roundi(seconds*fps)): run.step(1.0/fps)
func exercise() -> void:
	for fps in [30,60,120]:
		var run:=model();var target: Dictionary=run.targets[0]
		run.step(.025)
		check(target.intent=="charging" and target.intent_left>=2.8,"opponent announces a real shot with adequate warning")
		var warning: float=target.intent_left
		word(run,target)
		check(target.pending and target.fired and run.enemy_shots.is_empty(),"correct word interrupts an unlaunched shot")
		advance(run,warning+.2,fps)
		check(run.enemy_shots.is_empty() and run.hp==100 and run.kills==1,"interrupted shot never causes later ghost damage")
		var danger:=model();target=danger.targets[0];target.intent="charging";target.intent_left=.01
		danger.step(.025)
		check(danger.enemy_shots.size()==1 and danger.hp==100,"enemy launch does not apply instant damage")
		var shot: Dictionary=danger.enemy_shots[0]
		var at: Vector2=shot.position
		danger.paused=true;advance(danger,1,fps)
		check(shot.position==at and danger.hp==100,"pause freezes hostile torpedo flight")
		danger.paused=false;danger.skill_charge=3;danger.activate_skill()
		advance(danger,.5,fps)
		check(shot.position.distance_to(at)<17 and danger.hp==100,"earned sonar slows an actual hostile torpedo")
		danger.skill_time=0
		word(danger,target);advance(danger,1.2,fps)
		check(danger.kills==1 and danger.enemy_shots.is_empty() and danger.hp==100,"physical interception neutralizes that submarine's launched threat")
		var damage:=model();target=damage.targets[0];target.intent="charging";target.intent_left=.01
		damage.step(.025);advance(damage,3,fps)
		check(damage.hp==80 and damage.enemy_shots.is_empty(),"unanswered enemy torpedo damages once at actual arrival")
		advance(damage,1,fps)
		check(damage.hp==80,"fired submarine cannot repeatedly create hidden attacks")
		var armor:=model(5,false);target=armor.targets[0]
		check(target.kind=="armored" and target.health==2,"armored hull has explicit multiple-hit durability")
		var first: String=target.word
		word(armor,target);armor.step_projectiles(.05)
		check(target.pending and target.word==first and target.health==2,"armor word stays completed until real contact")
		advance(armor,1,fps)
		check(target.health==1 and target.typed==0 and not target.pending and armor.kills==0,"surviving armor opens its next word only after contact")
		word(armor,target);advance(armor,1,fps)
		check(armor.kills==1 and armor.targets.is_empty(),"second real impact defeats armored submarine once")
		var rescue:=model(3,false);rescue.goal=1;rescue.hp=60;target=rescue.targets[0]
		word(rescue,target);rescue.step_projectiles(2)
		check(target.intent=="returning" and rescue.kills==0 and rescue.hp==60,"rescue probe starts towing rather than exploding supply pod")
		var start: Vector2=target.position
		advance(rescue,.5,fps)
		check(target.position.distance_to(DiveTactics.PLAYER)<start.distance_to(DiveTactics.PLAYER) and rescue.hp==60 and not rescue.done,"supply moves visibly toward the player before credit or healing")
		rescue.paused=true;var left: float=target.collect_left;advance(rescue,1,fps)
		check(target.collect_left==left,"pause freezes supply return")
		rescue.paused=false;advance(rescue,.4,fps)
		check(rescue.done and rescue.won and rescue.hp==72 and rescue.kills==1 and rescue.recovered_supplies==1,"arrival heals, charges and finishes the final recovery once")
		var late:=model(0,false);target=late.targets[0];target.position.x=112;target.speed=70
		word(late,target);late.step(.025)
		check(target.position.x<=112 and late.hp==100,"late correct input cannot teleport the hull or penalize it before contact")
		advance(late,.6,fps)
		check(late.kills==1 and late.hp==100,"accepted interception still resolves near the left boundary")
	var beginner:=model(0,false);advance(beginner,30,60)
	check(beginner.enemy_shots.is_empty() and beginner.hp==100,"beginner training does not introduce surprise enemy shooting")
	var entry:=AdventureRun.new();entry.setup("submarine",GameContent.lessons()[1],1,9)
	check(entry.targets.all(func(t):return t.position.x>=1440) and entry.recommended_target().is_empty(),"all first submarines enter from beyond the right edge")
	entry.type_character("f")
	check(entry.attempts==0 and entry.correct==0,"input before any visible target cannot become a phantom mistake")
	print("DIVE SERVICE: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
