class_name AdventureArena
extends GameArena

var motion := ArcadeMotion.new()
var enemy_motion := ArcadeMotion.new()
var reaction_age := 10.0
var reaction_point := Vector2.ZERO
var chef_x := 680.0

func _ready() -> void:
	super._ready()
	motion.setup({"royal":"knight","submarine":"sub","restaurant":"chef"}[run.mode])
	if run.mode=="royal": enemy_motion.setup("castle")
	run.action.connect(func(kind,point):
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
			chef_x=reaction_point.x if reduced_motion else lerpf(chef_x,reaction_point.x,1-exp(-delta*9))

func actor(id: String, point: Vector2, bounds: Vector2, seconds: float, flip := false, animated := true) -> void:
	var frame := enemy_motion.texture("idle",seconds,reduced_motion) if id=="goblin" else motion.texture("idle",seconds,reduced_motion) if animated else null
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
	else:
		var frame := motion.texture("idle",reaction_age if reaction_age<3.0 else 0.0,reduced_motion)
		if frame!=null:
			draw_texture_rect_region(frame,Rect2(chef_x-130,240,260,183),Rect2(0,0,256,180))
	for target in run.targets:
		var p: Vector2=target.position
		if run.mode=="royal":
			var stride := 0.0 if reduced_motion else sin(clock*10+target.id)*4
			actor("goblin",p-Vector2(0,18+absf(stride)),Vector2(126,126),clock,false,false)
		elif run.mode=="submarine":
			actor("sub",p,Vector2(172,172),clock+target.id*.3,true)
			if target.kind=="supply":
				write("+",p+Vector2(-8,8),32,PlayTheme.TEAL)
		else:
			# A dish changes with the actual order state; it is never part of the backdrop.
			var at := Vector2(p.x,408)
			var bob := 0.0 if reduced_motion else sin(clock*2+target.id)*2
			art.draw_sprite(self,"customer"+str(target.id%3),Vector2(p.x,120+bob),Vector2(100,110))
			draw_set_transform(at,0,Vector2(1,.33))
			draw_circle(Vector2.ZERO,55,Color("fff5dc"))
			draw_circle(Vector2.ZERO,44,Color("dbb984"))
			draw_set_transform(Vector2.ZERO)
			for i in range(5 if target.stage<2 else 0):
				var phase := clock*6+i
				var lift: float = sin(clampf(1-target.cook_left/.7,0,1)*PI)*65 if target.cook_left>0 and not reduced_motion else 0.0
				var food := at+Vector2(-27+i*13,-9-lift*(.7+i*.07))
				draw_circle(food,10,[Color("e79547"),Color("72b97b"),Color("e6b85b")][i%3])
				if target.stage>0 and not reduced_motion:
					var steam := at+Vector2(-25+i*12+sin(phase)*5,-25-fposmod(clock*28+i*13,65))
					draw_circle(steam,5,Color(1,1,1,.28))
			if target.stage==2: art.draw_sprite(self,"food"+str(target.id%3),at-Vector2(0,20),Vector2(135,100))
			panel(Rect2(p.x-58,453,116,36),Color(.08,.25,.28,.9),10)
			write(["备料","翻锅","出餐"][target.stage],Vector2(p.x,480),24,Color("fff1cb"),true)
			for i in range(3):
				panel(Rect2(p.x-52+i*38,496,30,5),PlayTheme.TEAL if i<=target.stage else Color(.8,.85,.8,.7),2)
		if not target.get("pending",false):
			var center := p-Vector2(0,100) if run.mode!="restaurant" else p-Vector2(0,55)
			prompts.append({"target":target,"center":center,"source":p})
		if run.mode=="restaurant":
			actors.append(Rect2(p.x-50,65,100,110))
		else: actors.append(Rect2(p-Vector2(50,60),Vector2(100,95)))
	var blocked: Array[Rect2]=[]
	if run.mode=="restaurant": blocked.append(Rect2(chef_x-100,280,200,150))
	layout_labels(prompts,actors,blocked)
	juice.draw(self)
	draw_impact()
	draw_target_labels()
