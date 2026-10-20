class_name GameFeel
extends RefCounted

# Presentation only: no access to gameplay transforms, timers, RNG or Engine.time_scale.
const LIMIT := 12
var events: Array[Dictionary] = []
var trauma := 0.0
var clock := 0.0
var reduced_motion := false

static func kick(age: float, duration := .32) -> float:
	if age<0 or age>=duration: return 0.0
	var t := age/duration
	return cos(t*TAU*1.25)*pow(1-t,3)

static func pose_step(delta: float, remaining: float) -> float:
	return maxf(0,delta-maxf(0,remaining))

static func tier(combo: int, heavy: bool) -> int:
	return 3 if combo>0 and combo%5==0 else 2 if heavy else 1

func hit(point: Vector2, importance: int, tint := PlayTheme.YELLOW) -> void:
	importance=clampi(importance,1,3)
	if events.size()>=LIMIT: events.pop_front()
	events.append({"point":point,"age":0.0,"tier":importance,"color":tint})
	if not reduced_motion:
		trauma=minf(.65,trauma+([0.0,.25,.48][importance-1]))

func step(delta: float) -> void:
	clock+=delta
	trauma=0.0 if reduced_motion else maxf(0,trauma-delta*2.8)
	for event in events.duplicate():
		event.age+=delta
		if event.age>=.32: events.erase(event)

func offset() -> Vector2:
	if reduced_motion: return Vector2.ZERO
	return Vector2(sin(clock*31)+sin(clock*47)*.3,cos(clock*37))*Vector2(6,4)*trauma*trauma

func draw(canvas: CanvasItem, protected: Array[Rect2]) -> void:
	if reduced_motion: return
	for event in events:
		if event.tier<2: continue
		var t: float=event.age/.32
		var radius: float=12+pow(t,.4)*(22+event.tier*5)
		var bounds:=Rect2(event.point-Vector2.ONE*(radius+14),Vector2.ONE*(radius+14)*2)
		if protected.any(func(rect): return rect.intersects(bounds)): continue
		for i in range(6 if event.tier==2 else 9):
			var axis:=Vector2.from_angle(i*TAU/(6 if event.tier==2 else 9)+.2)
			canvas.draw_line(event.point+axis*radius*.7,event.point+axis*(radius+12*(1-t)),Color(event.color,(1-t)*.8),2.5,true)
