class_name AdventureRun
extends GameRun

signal action(kind: String, point: Vector2)
const MODES := ["royal","submarine","restaurant"]
var goal := 18
var core := 100
var core_max := 100
var served := 0
var skill_charge := 0
var skill_time := 0.0
var skill_uses := 0
var units: Array[Dictionary] = []
var bosses_defeated:=0

func setup(mode_id: String, lesson_data: Dictionary, pace := 1.0, seed_value := 0) -> void:
	super.setup(mode_id,lesson_data,pace,seed_value)
	goal = (12 if mode=="restaurant" else 18)+(SessionOptions.rank_index(challenge_rank)*4 if context=="challenge" else 0)
	core_max = 100+(SessionOptions.rank_index(challenge_rank)*20 if context=="challenge" else 0)
	core = core_max
	for i in range(2 if mode=="royal" else 3): spawn_target()

func spawn_target() -> void:
	if mode=="restaurant" and kills+targets.size()>=goal: return
	var lane := next_id% (2 if mode=="royal" else 3)
	if mode=="restaurant":
		for i in range(3):
			if not targets.any(func(t): return t.lane==i):
				lane=i
				break
	var word := next_word()
	var duration := ((42.0+word.length()*3) if context=="training" else (22.0+word.length()*1.8))/difficulty
	var pos := Vector2(1260,235+lane*210) if mode=="royal" else Vector2(1440+lane*120,180+lane*165) if mode=="submarine" else Vector2(240+lane*440,285)
	targets.append({"id":next_id,"word":word,"typed":0,"position":pos,"lane":lane,"stage":0,"remaining":duration,"duration":duration,"speed":(930.0/(16+word.length()*1.6))*difficulty,"kind":"supply" if mode=="submarine" and next_id%4==3 else "enemy","pending":false,"cook_left":0.0})
	if mode=="royal":
		var boss:=next_id%6==5
		targets[-1].kind="boss" if boss else "enemy"
		targets[-1].health=3+SessionOptions.rank_index(challenge_rank) if boss else 1
		targets[-1].max_health=targets[-1].health
		if boss: targets[-1].speed*=.55
	next_id+=1
	spawned+=1

func priority(target: Dictionary) -> float:
	return float(target.remaining) if mode=="restaurant" else (target.position.x-100)/maxf(1,target.speed)

func target_available(target: Dictionary) -> bool:
	return super.target_available(target) and (mode!="submarine" or target.position.x<1320)

func step(delta: float) -> void:
	if done or paused: return
	var remaining := minf(delta,.5)
	while remaining>0 and not done:
		var dt := minf(remaining,.025)
		advance(dt)
		remaining-=dt

func advance(dt: float) -> void:
	elapsed+=dt
	skill_time=maxf(0,skill_time-dt)
	for target in targets.duplicate():
		if mode=="restaurant":
			target.remaining-=dt
			if target.cook_left>0:
				target.cook_left-=dt
				if target.cook_left<=0:
					target.stage=2
					target.pending=false
					target.word=next_word()
					target.typed=0
					action.emit("plate",target.position)
		else:
			var factor := .12 if mode=="submarine" and skill_time>0 else 1.0
			target.position.x-=target.speed*dt*factor
		if (mode=="restaurant" and target.remaining<=0) or (mode!="restaurant" and target.position.x<110):
			hp=maxi(0,hp-(12 if context=="training" else 20))
			combo=0
			action.emit("miss",target.position)
			targets.erase(target)
			if locked==target.id: locked=-1
			if hp==0:
				finish(false)
				return
	step_projectiles(dt)
	for unit in units.duplicate():
		unit.position.x+=dt*(420 if skill_time>0 else 255)
		if unit.position.x>=1240:
			units.erase(unit)
			core=maxi(0,core-10)
			action.emit("core",unit.position)
			hud_changed.emit()
			if core==0:
				finish(true)
				return
	spawn_clock-=dt
	var cap := 2 if mode=="royal" or str(lesson.id)=="phrases" else 3
	if spawn_clock<=0 and targets.size()<cap:
		spawn_target()
		spawn_clock=(2.0 if mode=="restaurant" else 3.0)/difficulty

func on_word_completed(target: Dictionary) -> void:
	locked=-1
	if mode=="restaurant":
		if target.stage==0:
			target.stage=1
			target.word=next_word()
			target.typed=0
			action.emit("chop",target.position)
		elif target.stage==1:
			target.pending=true
			target.cook_left=1.5
			action.emit("cook",target.position)
		else:
			complete_order(target)
		return
	target.pending=true
	launch_projectile(target,Vector2(160,target.position.y) if mode=="royal" else Vector2(185,485),"knight" if mode=="royal" else "torpedo",1,340 if mode=="royal" else 650)
	action.emit("deploy" if mode=="royal" else "launch",target.position)

func resolve_projectile(_shot: Dictionary, target: Dictionary) -> void:
	if mode=="royal":
		target.health-=1
		if target.health>0:
			target.pending=false;target.typed=0;target.word=next_word()
			target.position.x+=26
			action.emit("hit",target.position)
			return
		if target.kind=="boss": bosses_defeated+=1
		units.append({"position":target.position,"lane":target.lane})
	elif target.kind=="supply": hp=mini(100,hp+12)
	complete_order(target)

func complete_order(target: Dictionary) -> void:
	action.emit("serve" if mode=="restaurant" else "hit",target.position)
	last_completion_point=target.position
	score+=str(target.word).length()*10+mini(combo,20)*5+(maxi(0,int(target.remaining)) if mode=="restaurant" else 0)
	kills+=1
	served=kills
	skill_charge=mini(3,skill_charge+1)
	targets.erase(target)
	hud_changed.emit()
	if mode!="royal" and kills>=goal: finish(true)

func activate_skill() -> bool:
	if done or paused or skill_charge<3 or skill_time>0: return false
	skill_charge=0
	skill_uses+=1
	skill_time=4.0
	if mode=="restaurant":
		for target in targets: target.remaining= minf(target.duration,target.remaining+8)
	elif mode=="royal":
		for shot in projectiles: shot.speed=600.0
	action.emit("skill",Vector2(680,330))
	hud_changed.emit()
	return true

func skill_name() -> String:
	return {"royal":"集结冲锋","submarine":"声呐冻结","restaurant":"甜点安抚"}.get(mode,"")
