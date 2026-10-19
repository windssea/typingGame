class_name GameJuice
extends RefCounted

# Visual-only particles. This RNG and clock never alter game state or typing timing.
const LIMIT := 280
var particles: Array[Dictionary] = []
var reduced_motion := false
var rng := RandomNumberGenerator.new()
var serial := 0

func _init() -> void:
	rng.seed = 8751

func burst(point: Vector2, color: Color, tier := 1, kind := "spark") -> void:
	serial += 1
	var count := 4 if reduced_motion else 18+tier*10
	for i in range(count):
		if particles.size()>=LIMIT:
			particles.pop_front()
		var direction := Vector2.from_angle(rng.randf_range(0,TAU))
		var life := rng.randf_range(0.35,0.8)+tier*0.06
		particles.append({"p":point,"v":direction*rng.randf_range(45,130+tier*65),"life":life,"total":life,"color":color if i%3 else Color.WHITE,"radius":rng.randf_range(2,5+tier),"angle":rng.randf_range(0,TAU),"spin":rng.randf_range(-7,7),"kind":kind,"gravity":180.0 if kind in ["confetti","soil"] else 35.0})
	if not reduced_motion:
		if particles.size()>=LIMIT:
			particles.pop_front()
		particles.append({"p":point,"v":Vector2.ZERO,"life":0.45,"total":0.45,"color":color,"radius":20.0+tier*8,"angle":0.0,"spin":0.0,"kind":"ring","gravity":0.0})

func trail(point: Vector2, velocity: Vector2, color: Color, radius := 5.0) -> void:
	if reduced_motion or particles.size()>=LIMIT:
		return
	particles.append({"p":point,"v":velocity,"life":0.45,"total":0.45,"color":color,"radius":radius,"angle":0.0,"spin":0.0,"kind":"glow","gravity":0.0})

func step(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var item: Dictionary = particles[i]
		item.life -= delta
		if item.life<=0:
			particles.remove_at(i)
			continue
		item.p += item.v*delta
		item.v.y += item.gravity*delta
		item.v *= exp(-1.7*delta)
		item.angle += item.spin*delta

func draw(canvas: CanvasItem) -> void:
	for item in particles:
		var alpha: float = clampf(item.life/item.total,0,1)
		var color := Color(item.color,alpha)
		var radius: float = item.radius*(0.35+alpha*0.65)
		var p: Vector2 = item.p
		if item.kind=="ring":
			canvas.draw_arc(p,item.radius+(1-alpha)*60,0,TAU,32,color,1+alpha*3,true)
		elif item.kind=="confetti":
			var axis := Vector2.from_angle(item.angle)*radius
			canvas.draw_line(p-axis,p+axis,color,radius*0.7,true)
		elif item.kind=="spark":
			var axis := Vector2.from_angle(item.angle)*radius
			canvas.draw_line(p-axis*1.7,p+axis*1.7,color,1.5,true)
			canvas.draw_line(p-axis.orthogonal(),p+axis.orthogonal(),color,1.5,true)
		else:
			if item.kind=="glow":
				canvas.draw_circle(p,radius*2.2,Color(item.color,alpha*0.16))
			canvas.draw_circle(p,radius,color)
