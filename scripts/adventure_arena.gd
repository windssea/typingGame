class_name AdventureArena
extends GameArena

var motion := ArcadeMotion.new()
var enemy_motion := ArcadeMotion.new()
var boss_motion:=ArcadeMotion.new()
var reaction_age := 10.0
var reaction_point := Vector2.ZERO
var chef_x := 500.0

func _ready() -> void:
	super._ready()
	motion.setup({"royal":"knight","submarine":"sub","restaurant":"chef"}[run.mode])
	if run.mode=="royal":
		enemy_motion.setup("castle")
		boss_motion.setup("castle_boss")
	run.action.connect(func(kind,point):
		if kind in ["deploy","launch"]: return
		reaction_age=0.0
		reaction_point=point
		var tint := PlayTheme.CORAL if kind=="miss" else PlayTheme.YELLOW
		juice.burst(point,tint,2 if kind in ["hit","core","serve"] else 1,"confetti" if kind=="serve" else "droplet" if run.mode=="submarine" else "spark")
		record_impact(point,2 if kind in ["hit","core","serve","miss"] else 1,tint))

func _process(delta: float) -> void:
	super._process(delta)
	if run!=null and not run.paused:
		reaction_age+=delta
		if run.mode=="restaurant" and reaction_age<3.0:
			var aisle: float=reaction_point.x-180 if reaction_point.x>400 else reaction_point.x+180
			chef_x=aisle if reduced_motion else lerpf(chef_x,aisle,1-exp(-delta*9))

func actor(id: String, point: Vector2, bounds: Vector2, seconds: float, flip := false, animated := true) -> void:
	var frame := boss_motion.texture("idle",seconds,reduced_motion) if id=="boss" else enemy_motion.texture("idle",seconds,reduced_motion) if id=="goblin" else motion.texture("idle",seconds,reduced_motion) if animated else null
	draw_set_transform(point,0,Vector2(-1 if flip else 1,1))
	if frame!=null:
		draw_texture_rect(frame,Rect2(-bounds*.5,bounds),false)
	else:
		art.draw_sprite(self,id,Vector2.ZERO,bounds)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if run==null: return
	draw_scene_background()
	var prompts: Array[Dictionary]=[]
	var actors: Array[Rect2]=[]
	if run.mode=="royal":
		for shot in run.projectiles:
			actor("knight",shot.position-Vector2(0,24),Vector2(138,138),clock+shot.target*.2)
		for unit in run.units:
			actor("knight",unit.position-Vector2(0,24),Vector2(138,138),clock)
		for side in range(2):
			var x := 55.0 if side==0 else 1170.0
			panel(Rect2(x,46,135,12),Color(.12,.23,.32,.5),6)
			panel(Rect2(x,46,135*(float(run.hp)/100 if side==0 else float(run.core)/run.core_max),12),PlayTheme.TEAL if side==0 else PlayTheme.CORAL,6)
	elif run.mode=="submarine":
		actor("sub",Vector2(175,490),Vector2(240,240),clock)
		draw_flights()
	for target in run.targets:
		var p: Vector2=target.position
		if run.mode=="royal":
			var stride := 0.0 if reduced_motion else sin(clock*10+target.id)*4
			var boss: bool=target.kind=="boss"
			actor("boss" if boss else "goblin",p-Vector2(0,30 if boss else 18+absf(stride)),Vector2(218,218) if boss else Vector2(126,126),clock,true)
			if boss:
				panel(Rect2(p+Vector2(-67,78),Vector2(134,12)),Color("193847"),4)
				panel(Rect2(p+Vector2(-64,81),Vector2(128*float(target.health)/target.max_health,6)),Color("ffbb64"),3)
				write("统领  %d / %d"%[target.health,target.max_health],p+Vector2(0,112),21,Color("254454"),true)
		elif run.mode=="submarine":
			if p.x>1460: continue
			actor("sub",p,Vector2(172,172),clock+target.id*.3,true)
			if target.kind=="supply":
				write("+",p+Vector2(-8,8),32,PlayTheme.TEAL)
		else:
			# A dish changes with the actual order state; it is never part of the backdrop.
			var at := Vector2(p.x,408)
			var bob := 0.0 if reduced_motion else sin(clock*2+target.id)*2
			art.draw_sprite(self,"customer"+str(target.id%3),Vector2(p.x,120+bob),Vector2(100,110))
			var toss:=sin(clampf(1-target.cook_left/1.5,0,1)*PI)*22 if target.cook_left>0 and not reduced_motion else 0.0
			art.draw_sprite(self,"prep%d_%d"%[target.stage,target.id%3],at-Vector2(0,12+toss),Vector2(180,150))
			panel(Rect2(p.x-58,453,116,36),Color(.08,.25,.28,.9),10)
			write(["备料","翻锅","出餐"][target.stage],Vector2(p.x,480),24,Color("fff1cb"),true)
			for i in range(3):
				panel(Rect2(p.x-52+i*38,496,30,5),PlayTheme.TEAL if i<=target.stage else Color(.8,.85,.8,.7),2)
		if run.target_available(target):
			var center := p-Vector2(0,182 if target.kind=="boss" else 100) if run.mode!="restaurant" else p-Vector2(0,55)
			prompts.append({"target":target,"center":center,"source":p})
		if run.mode=="restaurant":
			actors.append(Rect2(p.x-50,65,100,110))
		else: actors.append(Rect2(p-Vector2(95,135),Vector2(190,255)) if target.kind=="boss" else Rect2(p-Vector2(50,60),Vector2(100,95)))
	var blocked: Array[Rect2]=[]
	if run.mode=="restaurant":
		blocked.append(Rect2(chef_x-100,350,200,280))
		var frame := motion.texture("idle",reaction_age if reaction_age<3.0 else clock*.45,reduced_motion)
		if frame!=null:
			draw_ellipse_shadow(Vector2(chef_x,625),Vector2(55,12))
			draw_texture_rect(frame,Rect2(chef_x-140,350,280,280),false)
	layout_labels(prompts,actors,blocked)
	juice.draw(self)
	draw_impact()
	draw_target_labels()
