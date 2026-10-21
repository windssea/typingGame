class_name KitchenMotion
extends RefCounted

# Presentation follows actual order events. It never changes typing or guest time.
var clips := ArcadeMotion.new()
var state := "idle"
var age := 0.0
var hold := 0.0
var chef_x := 500.0
var destination := 500.0
var walking := false
var walk_clock := 0.0
var facing_left := false
var moments: Array[Dictionary] = []
var desserts: Array[Dictionary] = []

func setup() -> void:
	clips.setup("chef")

func react(kind: String, point: Vector2, run: AdventureRun) -> void:
	if kind=="skill":
		for target in run.targets:
			desserts.append({"age":0.0,"origin":Vector2(chef_x+35,452),"destination":Vector2(target.position.x+40,165)})
	if kind in ["chop","cook","plate","deliver"]:
		destination=point.x+180 if point.x<400 else point.x-180
		state={"chop":"stir","cook":"toss","plate":"idle","deliver":"serve"}[kind]
		age=0.0
		hold={"chop":.7,"cook":1.5,"plate":.3,"deliver":1.0}[kind]
	if kind in ["serve","miss"]:
		var target: Dictionary={}
		for candidate in run.targets:
			if is_equal_approx(float(candidate.position.x),point.x): target=candidate;break
		moments.append({"kind":kind,"age":0.0,"point":point,"guest":int(target.get("id",0))%3})
		if moments.size()>6: moments.pop_front()

func step(delta: float, reduced: bool) -> void:
	age+=delta
	walk_clock+=delta
	hold=maxf(0,hold-delta)
	if hold<=0 and state!="idle": state="idle";age=0.0
	walking=not reduced and absf(destination-chef_x)>6
	if walking: facing_left=destination<chef_x
	chef_x=destination if reduced else move_toward(chef_x,destination,delta*420)
	for moment in moments.duplicate():
		moment.age+=delta
		if moment.age>1.1: moments.erase(moment)
	for dessert in desserts.duplicate():
		dessert.age+=delta
		if dessert.age>1.5: desserts.erase(dessert)

func draw_desserts(canvas: GameArena) -> void:
	for dessert in desserts:
		var t:=1.0 if canvas.reduced_motion else clampf(float(dessert.age)/.65,0,1)
		var eased:=1-pow(1-t,2)
		var p: Vector2=dessert.origin.lerp(dessert.destination,eased)-Vector2(0,sin(t*PI)*65)
		var fade:=clampf((1.5-float(dessert.age))/.3,0,1)
		canvas.art.draw_sprite(canvas,"dessert",p,Vector2(86,86),Color(1,1,1,fade))

func texture(reduced: bool) -> Texture2D:
	return clips.texture("walk" if walking else state,walk_clock if walking else age,reduced)

static func delivery_point(target: Dictionary) -> Vector2:
	var t:=clampf(1-float(target.serve_left)/AdventureRun.SERVE_SECONDS,0,1)
	var eased:=1-pow(1-t,2)
	return Vector2(target.position.x,408).lerp(Vector2(target.position.x,174),eased)-Vector2(sin(t*PI)*26,sin(t*PI)*24)

func draw_station(canvas: GameArena, target: Dictionary) -> void:
	var x: float=target.position.x
	var cooking: bool=target.cook_left>0
	var delivering: bool=target.serve_left>0
	var dish:=delivery_point(target) if delivering else Vector2(x,396)
	var size_value:=Vector2(180,150)
	if delivering:
		var fraction:=clampf(1-float(target.serve_left)/AdventureRun.SERVE_SECONDS,0,1)
		size_value*=lerpf(1.0,.7,fraction)
	elif cooking and not canvas.reduced_motion:
		dish.y-=sin(clampf(1-float(target.cook_left)/1.5,0,1)*PI)*22
	canvas.art.draw_sprite(canvas,"prep%d_%d"%[target.stage,target.id%3],dish,size_value)
	# One compact physical stage strip replaces stacked flat badges and bars.
	var strip:=Rect2(x-92,453,184,48)
	TypingPrompt.material_frame(canvas,strip,false,true,false,0,"restaurant")
	for stage_index in range(3):
		var center:=Vector2(x-60+stage_index*60,477)
		canvas.art.draw_sprite(canvas,"prep%d_%d"%[stage_index,target.id%3],center,Vector2(50,42),Color.WHITE if stage_index<=target.stage else Color(.52,.61,.6,.65))
		if stage_index<target.stage:
			canvas.write("✓",center+Vector2(12,14),20,Color("167965"),true)
	if cooking:
		var progress:=clampf(1-float(target.cook_left)/1.5,0,1)
		canvas.draw_line(Vector2(x-79,496),Vector2(x-79+158*progress,496),Color("dc8b43"),3,true)

func draw_guests(canvas: GameArena, run: AdventureRun) -> void:
	for target in run.targets:
		var bob:=0.0 if canvas.reduced_motion else sin(canvas.clock*2+target.id)*1.2
		TypingPrompt.material_frame(canvas,Rect2(target.position.x-54,61,108,120),false,true,false,0,"restaurant")
		canvas.art.draw_sprite(canvas,"customer"+str(target.id%3),Vector2(target.position.x,120+bob),Vector2(100,110))
	for moment in moments:
		var fade:=clampf((1.1-float(moment.age))/.35,0,1)
		var p:=Vector2(moment.point.x,120)
		canvas.art.draw_sprite(canvas,"customer"+str(moment.guest),p,Vector2(100,110),Color(1,1,1,fade))
		if moment.kind=="serve":
			var offset:=0.0 if canvas.reduced_motion else sin(minf(1,moment.age*3)*PI)*8
			canvas.write("满意！",p+Vector2(0,-70-offset),25,Color("fff2bd",fade),true)
