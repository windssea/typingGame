extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func word(run: AdventureRun, target: Dictionary) -> void:
	run.locked=target.id
	for letter in str(target.word).substr(target.typed): run.type_character(letter)
func advance(run: AdventureRun, seconds: float, fps: int) -> void:
	for i in range(roundi(seconds*fps)): run.step(1.0/fps)
func exercise() -> void:
	for fps in [30,60,120]:
		var run:=AdventureRun.new();run.setup("restaurant",GameContent.lessons()[5],1,422)
		var events: Array[String]=[]
		run.action.connect(func(kind,_point): events.append(kind))
		var t: Dictionary=run.targets[0]
		word(run,t)
		check(t.stage==1 and not t.pending and events==["chop"],"preparation changes only its own station")
		word(run,t)
		check(t.cook_left==1.5 and t.pending and run.kills==0,"cooking holds its completed word while pan is active")
		advance(run,1.6,fps)
		check(t.stage==2 and not t.pending and events==["chop","cook","plate"],"plating follows actual cook completion")
		var credit:=run.correct
		word(run,t)
		check(run.kills==0 and t.pending and t.serve_left>0,"final typing launches a physical dish before service credit")
		check(run.correct==credit+str(t.word).length(),"dish flight never delays genuine typing credit")
		var start:=KitchenMotion.delivery_point(t)
		t.remaining=.001
		advance(run,.2,fps)
		check(KitchenMotion.delivery_point(t).y<start.y and run.hp==100,"dish travels toward guest who stays for accepted service")
		var other: Dictionary=run.targets[1]
		word(run,other)
		check(other.stage==1,"other stations accept input during delivery")
		run.paused=true
		var left: float=t.serve_left;advance(run,2,fps)
		check(is_equal_approx(left,t.serve_left) and run.kills==0,"pause freezes dish and service contact")
		run.paused=false;advance(run,.6,fps)
		check(run.kills==1 and run.served==1 and run.skill_charge==1 and not run.targets.has(t),"arrival resolves exactly one real order")
		check(events.count("serve")==1,"arrival emits one customer celebration")
		advance(run,1,fps)
		check(run.kills==1,"settled dish cannot score twice")
		var ending:=AdventureRun.new();ending.setup("restaurant",GameContent.lessons()[0],1,8)
		ending.goal=1;ending.targets.resize(1)
		var last: Dictionary=ending.targets[0];last.stage=2
		word(ending,last)
		check(not ending.done,"last accepted word still shows its delivery")
		advance(ending,.8,fps)
		check(ending.done and ending.won and ending.kills==1,"victory waits for last plate arrival")
	var motion:=KitchenMotion.new()
	var model:=AdventureRun.new();model.setup("restaurant",GameContent.lessons()[0],1,8)
	motion.react("cook",Vector2(1120,285),model);motion.step(.1,false)
	check(motion.state=="toss" and motion.chef_x<940 and motion.chef_x>500,"chef travels to requested station without teleporting")
	motion.step(2,false)
	check(motion.state=="idle" and motion.moments.is_empty(),"action returns to quiet idle")
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var profile: String="user://kitchen-service-%d.json"%Time.get_ticks_usec()
	app.store.path=profile;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.set_process(false);app.lesson_index=5;app.start_game("restaurant")
	var arena: AdventureArena=app.layer.find_children("*","AdventureArena",true,false)[0]
	arena.set_process(false);arena.native_vfx.set_process(false)
	var vfx: EngineVfx=arena.native_vfx
	vfx._process(.01)
	check(vfx.stoves.size()==3 and vfx.snapshot().cooking_stoves==0,"three bounded native stoves remain quiet without cooking")
	var cooking: Dictionary=app.run.targets[1]
	word(app.run,cooking);word(app.run,cooking);vfx._process(.01)
	check(vfx.snapshot().cooking_stoves==1 and vfx.stoves[1].light.enabled,"only actual cooking station emits fire, steam and local light")
	check(arena.kitchen.state=="toss","actual order event selects articulated pan action")
	app.run.paused=true;vfx._process(.1)
	check(vfx.stoves[1].steam.speed_scale==0 and vfx.stoves[1].fire.speed_scale==0,"pause freezes native stove particles")
	arena.reduced_motion=true;vfx._process(.1)
	check(vfx.snapshot().cooking_stoves==0 and not vfx.stoves[1].light.enabled,"reduced motion disables stove particles and flickering light")
	app.run.paused=false;arena.reduced_motion=false;advance(app.run,1.6,60);vfx._process(.1)
	check(vfx.snapshot().cooking_stoves==0,"stove stops when pan finishes, not on an arbitrary effect timer")
	for state in ["idle","stir","toss","serve","walk"]:
		var frames: SpriteFrames=arena.kitchen.clips.clips[state]
		check(frames.get_animation_speed(state)==24,"chef keeps native frame rate: "+state)
		for index in range(frames.get_frame_count(state)):
			var texture: Texture2D=frames.get_frame_texture(state,index)
			check(texture.get_size()==Vector2(384,384),"chef pose retains HD canvas: "+state)
			var image: Image=texture.get_image()
			var safe:=true
			for pixel in range(384):
				for edge in range(3):
					if image.get_pixel(pixel,edge).a>.1 or image.get_pixel(pixel,383-edge).a>.1 or image.get_pixel(edge,pixel).a>.1 or image.get_pixel(383-edge,pixel).a>.1: safe=false
			check(safe,"complete chef pose has transparent border: "+state+str(index))
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix): DirAccess.remove_absolute(profile+suffix)
	print("KITCHEN SERVICE: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
