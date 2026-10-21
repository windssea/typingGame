class_name AdventureArena
extends GameArena

var motion := ArcadeMotion.new()
var enemy_motion := ArcadeMotion.new()
var boss_motion:=ArcadeMotion.new()
var reaction_age := 10.0
var reaction_point := Vector2.ZERO
var kitchen := KitchenMotion.new()
var dive := DiveMotion.new()

func _ready() -> void:
	super._ready()
	if run.mode=="restaurant": kitchen.setup()
	else: motion.setup({"royal":"knight","submarine":"sub"}[run.mode])
	if run.mode=="submarine": dive.setup()
	if run.mode=="royal":
		enemy_motion.setup("castle")
		boss_motion.setup("castle_boss")
	run.action.connect(func(kind,point):
		if run.mode=="submarine":
			dive.react(kind,point,run)
			if kind in ["launch","enemy_launch","skill","interrupt"]: return
			var color:=PlayTheme.CORAL if kind in ["miss","depth_hit"] else PlayTheme.MINT if kind=="pickup" else PlayTheme.SKY
			var tier:=2 if kind in ["hit","armor_hit","depth_hit"] else 1
			juice.burst(point,color,tier,"droplet")
			record_impact(point,tier,color)
			return
		if run.mode=="restaurant":
			kitchen.react(kind,point,run)
			if kind in ["deliver","skill"]: return
			var at:=Vector2(point.x,175 if kind in ["serve","miss"] else 395)
			var color:=PlayTheme.CORAL if kind=="miss" else Color("ffd58d")
			juice.burst(at,color,1,"confetti" if kind=="serve" else "spark")
			record_impact(at,1,color)
			return
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
		if run.mode=="restaurant": kitchen.step(delta,reduced_motion)
		if run.mode=="submarine": dive.step(delta)

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
		dive.draw_fish(self)
		var recoil:=0.0 if reduced_motion else sin(clampf(dive.recoil_age/.24,0,1)*PI)*5
		actor("sub",DiveTactics.PLAYER-Vector2(recoil,0),Vector2(240,240),clock)
	if run.mode=="restaurant": kitchen.draw_guests(self,run)
	for target in run.targets:
		var p: Vector2=target.position
		if run.mode=="royal":
			var stride := 0.0 if reduced_motion else sin(clock*10+target.id)*4
			var boss: bool=target.kind=="boss"
			actor("boss" if boss else "goblin",p-Vector2(0,30 if boss else 18+absf(stride)),Vector2(218,218) if boss else Vector2(126,126),clock,true)
			if boss:
				panel(Rect2(p+Vector2(-67,78),Vector2(134,12)),Color("193847"),4)
				panel(Rect2(p+Vector2(-64,81),Vector2(128*float(target.health)/target.max_health,6)),Color("ffbb64"),3)
				GameHudSkin.caption(self,"统领 %d / %d"%[target.health,target.max_health],Rect2(p+Vector2(-90,93),Vector2(180,34)),21,1)
		elif run.mode=="submarine":
			if p.x>1460: continue
			dive.draw_target(self,target)
		else:
			kitchen.draw_station(self,target)
		if run.target_available(target):
			var center := p-Vector2(0,182 if target.kind=="boss" else 145 if target.kind=="armored" else 115 if run.mode=="submarine" else 100) if run.mode!="restaurant" else p-Vector2(0,55)
			prompts.append({"target":target,"center":center,"source":p})
		if run.mode=="restaurant":
			actors.append(Rect2(p.x-50,65,100,110))
		else: actors.append(Rect2(p-Vector2(100,96),Vector2(200,192)) if target.kind=="armored" else Rect2(p-Vector2(95,135),Vector2(190,255)) if target.kind=="boss" else Rect2(p-Vector2(76,64),Vector2(152,128)) if run.mode=="submarine" else Rect2(p-Vector2(50,60),Vector2(100,95)))
	var blocked: Array[Rect2]=[]
	if run.mode=="restaurant":
		blocked.append(Rect2(kitchen.chef_x-110,310,220,320))
		var frame:=kitchen.texture(reduced_motion)
		if frame!=null:
			draw_ellipse_shadow(Vector2(kitchen.chef_x,622),Vector2(55,10))
			draw_set_transform(Vector2(kitchen.chef_x,468),0,Vector2(-1 if kitchen.walking and kitchen.facing_left else 1,1))
			draw_texture_rect(frame,Rect2(-180,-180,360,360),false)
			draw_set_transform(Vector2.ZERO)
	layout_labels(prompts,actors,blocked)
	if run.mode=="submarine":
		dive.draw_ghosts(self)
		dive.draw_torpedoes(self,run.projectiles)
		dive.draw_torpedoes(self,run.enemy_shots,true)
	if run.mode=="restaurant": kitchen.draw_desserts(self)
	juice.draw(self)
	draw_impact()
	draw_target_labels()
