class_name GameJuice
extends RefCounted

# Visual-only particles. This RNG and clock never alter game state or typing timing.
const LIMIT := 280
var particles: Array[Dictionary] = []
var reduced_motion := false
var rng := RandomNumberGenerator.new()
var serial := 0
var protected_regions: Array[Rect2] = []

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
		var tint: Color = [Color("ffbf68"),Color("78cafa"),Color("f58d9d"),Color("a3dfaf")][i%4] if kind=="confetti" else color
		var gravity: float = {"confetti":180.0,"soil":280.0,"petal":95.0,"droplet":240.0,"ember":-55.0,"snow":45.0}.get(kind,35.0)
		particles.append({"p":point,"v":direction*rng.randf_range(45,130+tier*65),"life":life,"total":life,"color":tint if i%3 else Color.WHITE,"radius":rng.randf_range(2,5+tier),"angle":rng.randf_range(0,TAU),"spin":rng.randf_range(-7,7),"kind":kind,"gravity":gravity})
	if not reduced_motion and tier>=2:
		if particles.size()>=LIMIT:
			particles.pop_front()
		particles.append({"p":point,"v":Vector2.ZERO,"life":0.45,"total":0.45,"color":color,"radius":20.0+tier*8,"angle":0.0,"spin":0.0,"kind":"ring","gravity":0.0})

func trail(point: Vector2, velocity: Vector2, color: Color, radius := 5.0) -> void:
	if reduced_motion or particles.size()>=LIMIT:
		return
	particles.append({"p":point,"v":velocity,"life":0.45,"total":0.45,"color":color,"radius":radius,"angle":0.0,"spin":0.0,"kind":"glow","gravity":0.0})

func jet(point: Vector2, direction: Vector2, color: Color, tier := 1) -> void:
	if reduced_motion:
		return
	for i in range(7+tier*3):
		if particles.size()>=LIMIT:
			particles.pop_front()
		var life := rng.randf_range(.16,.35)
		var axis := direction.normalized().rotated(rng.randf_range(-.42,.42))
		particles.append({"p":point,"v":axis*rng.randf_range(180,340+tier*65),"life":life,"total":life,"color":color,"radius":rng.randf_range(4,9),"angle":axis.angle(),"spin":0.0,"kind":"streak","gravity":0.0})

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
		var footprint := Rect2(p-Vector2.ONE*radius*2,Vector2.ONE*radius*4)
		if protected_regions.any(func(rect): return rect.intersects(footprint)):
			continue
		if item.kind=="ring":
			canvas.draw_arc(p,item.radius+(1-alpha)*60,0,TAU,32,color,1+alpha*3,true)
		elif item.kind=="confetti":
			var axis := Vector2.from_angle(item.angle)*radius
			var cross_axis := axis.orthogonal()*(0.25+absf(sin(item.angle*2))*0.5)
			canvas.draw_colored_polygon(PackedVector2Array([p-axis,p+cross_axis,p+axis,p-cross_axis]),color)
		elif item.kind=="soil":
			canvas.draw_circle(p,radius,Color(item.color,alpha*0.65))
			canvas.draw_circle(p+Vector2(-radius*0.2,-radius*0.25),radius*0.4,Color(0.95,0.83,0.65,alpha*0.55))
		elif item.kind in ["streak","speed"]:
			var axis := Vector2.from_angle(item.angle)*radius*3
			canvas.draw_line(p-axis,p+axis,color,2.5,true)
			canvas.draw_line(p-axis*.4,p+axis*.6,Color(1,1,1,alpha),1,true)
		elif item.kind in ["petal","snow","droplet","ember"]:
			var axis := Vector2.from_angle(item.angle)*radius
			if item.kind=="droplet":
				axis = Vector2(0,-radius*1.6)
			var cross_axis := axis.orthogonal()*(.42 if item.kind=="petal" else .65)
			canvas.draw_colored_polygon(PackedVector2Array([p-axis,p-cross_axis,p+axis*1.4,p+cross_axis]),color)
			canvas.draw_circle(p-axis*.2,maxf(1,radius*.2),Color(1,1,1,alpha*.65))
		elif item.kind=="spark":
			var axis := Vector2.from_angle(item.angle)*radius
			SoftStroke.line(canvas,p-axis,p+axis,color,1.8)
		else:
			if item.kind=="glow":
				canvas.draw_circle(p,radius*2.2,Color(item.color,alpha*0.16))
			canvas.draw_circle(p,radius,color)
