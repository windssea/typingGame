class_name DiveTactics
extends RefCounted

const PLAYER := Vector2(175,490)
const MUZZLE := Vector2(260,500)
const COLLECT_SECONDS := .8

static func configure(target: Dictionary, rank: int) -> void:
	target.kind="armored" if target.id%6==5 else "supply" if target.id%4==3 else "enemy"
	target.base_y=target.position.y
	target.swim_clock=target.id*.7
	target.intent="cruise"
	target.intent_left=0.0
	target.fired=false
	target.collect_left=0.0
	if target.kind=="armored":
		target.health=2+(1 if rank==2 else 0)
		target.max_health=target.health
		target.speed*=.72

# A small FSM owns intent; motion remains independent and frame-rate invariant.
static func advance(target: Dictionary, dt: float, frozen: bool, challenge: bool, difficulty: float) -> bool:
	var factor:=.12 if frozen else .25 if target.pending else .65 if target.intent=="charging" else 1.0
	var previous_x: float=target.position.x
	target.swim_clock+=dt*factor
	target.position.x-=target.speed*dt*factor
	target.position.y=target.base_y+sin(target.swim_clock*.9)*12
	if target.pending:
		target.position.x=maxf(minf(previous_x,140),target.position.x)
		return false
	if frozen or not challenge or target.kind=="supply": return false
	match target.intent:
		"cruise":
			if not target.fired and target.position.x<900:
				target.intent="charging"
				target.intent_left=maxf(2.8,(3.0+str(target.word).length()*.45)/difficulty)
		"charging":
			target.intent_left=maxf(0,target.intent_left-dt)
			if target.intent_left<=0:
				target.fired=true;target.intent="cruise"
				return true
	return false
