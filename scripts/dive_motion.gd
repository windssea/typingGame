class_name DiveMotion
extends RefCounted

var scout := ArcadeMotion.new()
var armored := ArcadeMotion.new()
var ghosts: Array[Dictionary] = []
var hit_ages: Dictionary = {}
var recoil_age := 1.0

func setup() -> void:
	scout.setup("dive_scout");armored.setup("dive_armored")

func react(kind: String, point: Vector2, run: AdventureRun) -> void:
	if kind=="launch": recoil_age=0
	if kind not in ["hit","armor_hit"]: return
	for target in run.targets:
		if target.position.distance_squared_to(point)>1: continue
		if kind=="armor_hit": hit_ages[target.id]=0.0
		else:
			ghosts.append({"position":point,"kind":target.kind,"age":0.0})
			if ghosts.size()>6: ghosts.pop_front()
		break

func step(delta: float) -> void:
	recoil_age+=delta
	for id in hit_ages.keys():
		hit_ages[id]+=delta
		if hit_ages[id]>.45: hit_ages.erase(id)
	for ghost in ghosts.duplicate():
		ghost.age+=delta
		if ghost.age>.65: ghosts.erase(ghost)

func enemy_texture(target: Dictionary, clock: float, reduced: bool) -> Texture2D:
	var library:=armored if target.kind=="armored" else scout
	var state:="hit" if hit_ages.has(target.id) else "alert" if target.intent=="charging" else "idle"
	var pose_time: float=hit_ages[target.id]*library.duration("hit")/.45 if hit_ages.has(target.id) else target.swim_clock
	return library.texture(state,pose_time,reduced)

func draw_target(canvas: GameArena, target: Dictionary) -> void:
	var p: Vector2=target.position
	if target.kind=="supply":
		canvas.art.draw_sprite(canvas,"supply_pod",p,Vector2(144,144))
		return
	var frame:=enemy_texture(target,canvas.clock,canvas.reduced_motion)
	var bounds:=Vector2.ONE*(248 if target.kind=="armored" else 208)
	var bank:=0.0 if canvas.reduced_motion else cos(target.swim_clock*.9)*.025
	canvas.draw_set_transform(p,bank)
	if frame!=null: canvas.draw_texture_rect(frame,Rect2(-bounds*.5,bounds),false,Color(.78,.95,1) if canvas.run.skill_time>0 else Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
	if target.kind=="armored":
		for i in range(target.max_health):
			var rect:=Rect2(p+Vector2(-target.max_health*12+i*24,84),Vector2(20,6))
			canvas.panel(rect,Color("ffd48d") if i<target.health else Color("38526b"),3)
	if target.intent=="charging":
		# A lamp warns about a real pending shot, away from the readable word.
		var alpha:=.45 if canvas.reduced_motion else .45+.35*sin(canvas.clock*6)
		canvas.art.draw_sprite(canvas,"enemy_torpedo",p+Vector2(-66,38),Vector2(55,28),Color(1,1,1,alpha))

func draw_ghosts(canvas: GameArena) -> void:
	for ghost in ghosts:
		var library:=armored if ghost.kind=="armored" else scout
		var frame:=library.texture("hit",ghost.age*library.duration("hit")/.65,canvas.reduced_motion)
		if frame==null: continue
		var bounds:=Vector2.ONE*(248 if ghost.kind=="armored" else 208)
		var fade:=clampf((.65-float(ghost.age))/.28,0,1)
		var rise: float=0.0 if canvas.reduced_motion else ghost.age*45
		canvas.draw_texture_rect(frame,Rect2(ghost.position-Vector2(0,rise)-bounds*.5,bounds),false,Color(1,1,1,fade))

func draw_torpedoes(canvas: GameArena, shots: Array, enemy := false) -> void:
	for shot in shots:
		var direction: Vector2=shot.position-shot.previous
		var angle:=direction.angle()-(PI if enemy else 0.0)
		canvas.draw_set_transform(shot.position,angle)
		canvas.art.draw_sprite(canvas,"enemy_torpedo" if enemy else "friendly_torpedo",Vector2.ZERO,Vector2(68,38))
		canvas.draw_set_transform(Vector2.ZERO)

func draw_fish(canvas: GameArena) -> void:
	if canvas.reduced_motion: return
	for i in range(3):
		var x:=fposmod(canvas.clock*(14+i*4)+i*470,1600)-120
		var y:=100+i*145+sin(canvas.clock*.35+i)*8
		canvas.art.draw_sprite(canvas,"fish_school",Vector2(x,y),Vector2(120+i*22,95+i*12),Color(.55,.84,.94,.22))
