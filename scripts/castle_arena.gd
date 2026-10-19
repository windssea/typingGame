class_name CastleArena
extends GameArena

signal pad_selected(index: int)
var battle: CastleRun
var banner_time := 3.0
var shake := 0.0
var terrain: Node2D
var enemy_motion := ArcadeMotion.new()
var enemy_reactions: Dictionary = {}
var last_enemy_flash: Dictionary = {}
var label_offsets: Dictionary = {}
const ROYAL_MAP = preload("res://assets/worlds/royal-battlefield.png")
const GUARD_IDLE = preload("res://assets/animations/royal-guard-idle-v002/idle.tres")

func _ready() -> void:
	battle = run as CastleRun
	art.setup("castle")
	enemy_motion.setup("castle")
	juice.reduced_motion = reduced_motion
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	battle.effect.connect(receive_effect)
	battle.phase_changed.connect(func(): banner_time = 3.0)
	battle.key_feedback.connect(on_key_feedback)

func receive_effect(kind: String, origin: Vector2, destination: Vector2, amount: int) -> void:
	var duration := 0.8
	if kind in ["boss","wave","rage","interrupt"]:
		banner_time = 3.0
	if kind in ["damage","quake"]:
		shake = 0.26
	if kind == "defeat":
		duration = 1.2
	if kind in ["fire","ember","ice","storm","defeat","build","damage","quake","interrupt"]:
		var tint: Color = {"ice":Color("74dcff"),"storm":Color("b192ff"),"damage":Color("ed8b71"),"defeat":Color("ffd261")}.get(kind,Color("ffb34d"))
		juice.burst(destination,tint,3 if kind in ["quake","defeat"] else 1,"confetti" if kind=="defeat" else "spark")
	effects.append({"kind":kind,"from":origin,"to":destination,"amount":amount,"life":duration,"duration":duration})
	if effects.size() > 90:
		effects.pop_front()

func _process(delta: float) -> void:
	if battle == null:
		return
	if not battle.paused:
		clock += delta
		step_feedback(delta)
		for id in label_offsets.keys():
			if battle.target_by_id(id).is_empty():
				label_offsets.erase(id)
		var active_ids: Array = []
		for target in battle.targets:
			if target.kind!="goblin":
				continue
			active_ids.append(target.id)
			if target.flash>float(last_enemy_flash.get(target.id,0))+0.001:
				enemy_reactions[target.id] = 0.0
			last_enemy_flash[target.id] = target.flash
			if enemy_reactions.has(target.id):
				enemy_reactions[target.id] += delta
				if enemy_reactions[target.id]>=enemy_motion.duration("hit"):
					enemy_reactions.erase(target.id)
		for id in last_enemy_flash.keys():
			if id not in active_ids:
				last_enemy_flash.erase(id)
				enemy_reactions.erase(id)
		juice.step(delta)
		banner_time = maxf(0,banner_time-delta)
		shake = maxf(0,shake-delta)
		for effect in effects.duplicate():
			effect.life -= delta
			if effect.life <= 0:
				effects.erase(effect)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and battle.can_build():
		for i in range(CastleRun.PADS.size()):
			if event.position.distance_to(CastleRun.PADS[i]) < 43:
				battle.selected_pad = i
				pad_selected.emit(i)
				accept_event()

func _draw() -> void:
	if battle == null:
		return
	if shake > 0 and not reduced_motion:
		draw_set_transform(Vector2(sin(clock*90)*shake*10,cos(clock*73)*shake*7))
	draw_battlefield()
	for i in range(CastleRun.PADS.size()):
		draw_pad(i)
	var guard_frame := 0 if reduced_motion else int(clock*GUARD_IDLE.get_animation_speed("idle"))%GUARD_IDLE.get_frame_count("idle")
	draw_texture_rect(GUARD_IDLE.get_frame_texture("idle",guard_frame),Rect2(CastleRun.KEEP+Vector2(-110,24),Vector2(96,96)),false)
	panel(Rect2(CastleRun.KEEP+Vector2(-55,84),Vector2(110,9)),Color("dbe7dc"),4)
	panel(Rect2(CastleRun.KEEP+Vector2(-55,84),Vector2(110*float(battle.hp)/battle.max_hp,9)),MINT,4)
	var ordered := battle.targets.duplicate()
	ordered.sort_custom(func(a,b): return a.position.y < b.position.y)
	for target in ordered:
		draw_enemy(target)
	for effect in effects:
		draw_effect(effect)
	juice.draw(self)
	var occupied: Array[Rect2] = []
	for target in ordered:
		draw_target_label(target,occupied)
	draw_set_transform(Vector2.ZERO)
	draw_top_status()

func draw_battlefield() -> void:
	draw_texture_rect(ROYAL_MAP,Rect2(Vector2.ZERO,size),false)
	# Paths, movement, tower pads and damage remain gameplay data, independent of the backdrop.
	return

func draw_legacy_battlefield() -> void:
	panel(Rect2(Vector2.ZERO,size),Color("d6edbd"),18,Color("aacb99"))
	# Irregular forest floor patches and sunlit grass retain a hand-built map feel.
	for i in range(78):
		var p := Vector2(25+fmod(i*137.7,990),65+fmod(i*77.3,570))
		draw_circle(p,19+fmod(i*13,49),Color("cee7b3") if i%2 else Color("dbefc4"))
	# Four distinct approach roads meet at the keep's raised stone court.
	var routes := [PackedVector2Array([Vector2(40,100),Vector2(210,175),Vector2(365,280),CastleRun.KEEP]),
		PackedVector2Array([Vector2(1000,105),Vector2(840,190),Vector2(690,290),CastleRun.KEEP]),
		PackedVector2Array([Vector2(48,590),Vector2(235,525),Vector2(370,405),CastleRun.KEEP]),
		PackedVector2Array([Vector2(990,585),Vector2(810,510),Vector2(680,410),CastleRun.KEEP])]
	for route in routes:
		draw_polyline(route,Color("c9d6a6"),62,true)
		draw_polyline(route,Color("e0c89a"),48,true)
		draw_polyline(route,Color("f4dfb0"),28,true)
	for i in range(100):
		var p := Vector2(35+fmod(i*119.3,970),78+fmod(i*83.7,550))
		if p.distance_to(CastleRun.KEEP)<145:
			continue
		draw_line(p,p+Vector2(-2,-6),Color("8abb6d"),1.5,true)
		draw_line(p+Vector2(4,0),p+Vector2(5,-9),Color("97c579"),1.5,true)
		if i%4==0:
			draw_circle(p+Vector2(8,-3),2,Color("e9ae54"))
	# A small creek frames the western grove; the battlefield remains unobstructed.
	var stream := PackedVector2Array([Vector2(150,0),Vector2(130,85),Vector2(105,130),Vector2(90,240),Vector2(35,320),Vector2(0,340)])
	draw_polyline(stream,Color("a5d6c8"),34,true)
	draw_polyline(stream,Color("79c7ea"),21,true)
	draw_polyline(stream,Color("c4efff"),5,true)
	for i in range(12):
		var p := Vector2(119+i%3*7,80+i*4)
		draw_line(p,p+Vector2(13,1),Color("b4baa0"),2,true)
	for i in range(26):
		var p := Vector2(24+fmod(i*155,1000),22+fmod(i*99,600))
		if p.distance_to(CastleRun.KEEP) < 220 or (p.x>150 and p.x<880 and p.y>130 and p.y<520):
			continue
		pine(p,0.7+(i%4)*0.15)
	for i in range(11):
		pine(Vector2(190+i*60,36+(i%3)*16),0.65+(i%2)*0.2)
		pine(Vector2(220+i*59,625+(i%2)*9),0.7)
	# Raised circular courtyard, cobble edging, and a living ward.
	draw_circle(CastleRun.KEEP+Vector2(0,12),126,Color("b4cc9c"))
	draw_circle(CastleRun.KEEP,120,Color("eadfba"))
	draw_circle(CastleRun.KEEP,108,Color("f8edce"))
	for i in range(32):
		var a := i*TAU/32
		var p := CastleRun.KEEP+Vector2(cos(a),sin(a))*114
		draw_line(p-Vector2(cos(a),sin(a))*5,p+Vector2(cos(a),sin(a))*5,Color("ffffff"),7,true)
	draw_arc(CastleRun.KEEP,99,0,TAU,96,Color(0.55,0.84,0.7,0.28),2,true)
	for i in range(8):
		var a := i*TAU/8+(0.0 if reduced_motion else clock*0.03)
		var p := CastleRun.KEEP+Vector2(cos(a),sin(a))*99
		draw_circle(p,3,Color("39a584"))
	for p in [Vector2(265,150),Vector2(770,150),Vector2(270,555),Vector2(780,555)]:
		draw_line(p,p+Vector2(0,-30),Color("5a503b"),5)
		flame(p-Vector2(0,32),0.65)

func pine(p: Vector2, s: float) -> void:
	draw_ellipse_shadow(p,Vector2(28,10)*s)
	draw_line(p,p-Vector2(0,48)*s,Color("5d5140"),7*s)
	for i in range(3):
		var top := p-Vector2(0,20+i*16)*s
		var points := PackedVector2Array([top+Vector2(-28+i*5,10)*s,top+Vector2(26-i*4,10)*s,top+Vector2(0,-35)*s])
		draw_colored_polygon(points,Color("6eae79"))
		points[0] += Vector2(5,-5)*s
		points[1] += Vector2(-5,-5)*s
		draw_colored_polygon(points,Color("95ce86") if i%2==0 else Color("acd997"))
		draw_line(points[2],top+Vector2(-12,0)*s,Color("d2eeb1"),2,true)

func flame(p: Vector2,s: float) -> void:
	var flicker := 1.0 if reduced_motion else 1+sin(clock*12+p.x)*0.12
	for i in range(3,0,-1):
		draw_circle(p,12*i*s,Color(1,0.65,0.25,0.025))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-7,5)*s,p+Vector2(-10,-6)*s,p+Vector2(0,-22*flicker)*s,p+Vector2(8,-4)*s,p+Vector2(6,6)*s]),Color("f7a650"))
	draw_circle(p-Vector2(0,4)*s,4*s,Color("ffe6a1"))

func fortress(p: Vector2,s: float) -> void:
	# Reuse the keep silhouette, surrounded by a wider gatehouse, banners, and details.
	castle(p-Vector2(0,15),s)
	for dx in [-65,65]:
		var at := p+Vector2(dx,10)*s
		draw_line(at-Vector2(0,35),at+Vector2(0,12),Color("d3bd85"),2)
		draw_colored_polygon(PackedVector2Array([at-Vector2(8,31),at+Vector2(8,-31),at+Vector2(8,0),at+Vector2(0,8),at+Vector2(-8,0)]),Color("39626f"))
		draw_circle(at-Vector2(0,15),3,GOLD)
		flame(at+Vector2(0,21),0.55)
	for i in range(4):
		draw_line(p+Vector2(-19,49+i*6),p+Vector2(19,49+i*6),Color("9ea18a"),4,true)
	write("誓 光 要 塞",p+Vector2(0,98),13,Color("ede2bc"),true)
	var health_width := 100.0*float(battle.hp)/battle.max_hp
	panel(Rect2(p+Vector2(-52,106),Vector2(104,7)),Color("20332e"),3)
	draw_rect(Rect2(p+Vector2(-50,108),Vector2(health_width,3)),MINT)

func draw_pad(index: int) -> void:
	var p: Vector2 = CastleRun.PADS[index]
	var tower := battle.tower_at(index)
	var selected := index == battle.selected_pad and battle.phase == "build"
	if selected:
		var reach: float = 230.0 if tower.is_empty() else float(CastleRun.TOWERS[tower.kind].range)+(tower.level-1)*22
		draw_circle(p,reach,Color(0.6,0.79,0.64,0.035))
		draw_arc(p,reach,0,TAU,80,Color(0.65,0.85,0.67,0.3),1,true)
	draw_ellipse_shadow(p+Vector2(0,13),Vector2(39,16))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-30,4),p+Vector2(0,-14),p+Vector2(30,4),p+Vector2(0,22)]),Color("d8dfb6") if selected else Color("b7ce9c"))
	draw_arc(p,37,0,TAU,40,GOLD if selected else Color("789c62"),2 if selected else 1,true)
	if tower.is_empty():
		draw_line(p-Vector2(10,0),p+Vector2(10,0),GOLD if selected else MINT,2,true)
		draw_line(p-Vector2(0,10),p+Vector2(0,10),GOLD if selected else MINT,2,true)
		write(str(index+1),p+Vector2(0,49),15,GOLD,true)
		return
	var tint: Color = {"fire":Color("ffb96d"),"ice":Color("a2e6ec"),"storm":Color("c7b5ff")}[tower.kind]
	if art.sprites.has("tower_"+str(tower.kind)):
		var pulse := 0.0 if reduced_motion else sin(clock*3+index)*0.025
		var recovery: float = float(tower.cooldown)/(float(CastleRun.TOWERS[tower.kind].cooldown)/(1.0+(tower.level-1)*.15))
		var kick := 0.0 if reduced_motion else clampf((recovery-.82)/.18,0,1)*.08
		draw_circle(p-Vector2(0,65),28+sin(clock*3)*3,Color(tint,0.13))
		draw_arc(p,31,-PI/2,-PI/2+TAU*maxf(.001,1-recovery),40,Color(tint,.65),2,true)
		art.draw_sprite(self,"tower_"+str(tower.kind),p-Vector2(0,36-kick*80),Vector2(100*(1-pulse+kick),116*(1+pulse-kick))*(1.0+(tower.level-1)*0.1))
		for i in range(tower.level):
			draw_circle(p+Vector2((i-(tower.level-1)/2.0)*10,29),3,tint)
		write(str(index+1),p+Vector2(0,51),14,GOLD,true)
		return
	draw_rect(Rect2(p+Vector2(-17,-32),Vector2(34,43)),Color("65766e"))
	draw_rect(Rect2(p+Vector2(0,-32),Vector2(17,43)),Color("425751"))
	for i in range(3):
		draw_line(p+Vector2(-17,-22+i*12),p+Vector2(17,-22+i*12),Color("a2ad93"),2,true)
	draw_ellipse_shadow(p+Vector2(0,-32),Vector2(26,10))
	if tower.kind == "fire":
		draw_line(p+Vector2(-19,-32),p+Vector2(19,-32),Color("c1ac81"),7,true)
		flame(p-Vector2(0,39),1.0+tower.level*0.14)
	elif tower.kind == "ice":
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-78),p+Vector2(18,-48),p+Vector2(0,-27),p+Vector2(-18,-48)]),tint)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-78),p+Vector2(18,-48),p+Vector2(0,-27)]),Color("4f9bb2"))
	else:
		draw_line(p-Vector2(0,30),p-Vector2(0,58),Color("b1a2b1"),6,true)
		draw_circle(p-Vector2(0,66),13,tint)
		draw_arc(p-Vector2(0,66),22,clock,clock+TAU*0.8,30,Color("826cae"),3,true)
	for i in range(tower.level):
		draw_circle(p+Vector2((i-(tower.level-1)/2.0)*10,29),3,tint)
	write(str(index+1),p+Vector2(0,51),14,GOLD,true)

func draw_enemy(target: Dictionary) -> void:
	var p: Vector2 = target.position
	var kind: String = target.kind
	var bob := 0.0 if reduced_motion else sin(target.phase)*2
	var s := 1.0
	if kind == "boss":
		s = 2.0
	draw_ellipse_shadow(p+Vector2(0,15),Vector2(23,9)*s)
	if target.id == battle.locked:
		draw_arc(p+Vector2(0,8),29*s,0,TAU,40,GOLD,2,true)
		for side in [-1,1]:
			draw_line(p+Vector2(side*33,-25),p+Vector2(side*33,-14),PlayTheme.PRIMARY,2,true)
			draw_line(p+Vector2(side*33,-25),p+Vector2(side*23,-25),PlayTheme.PRIMARY,2,true)
		if key_pulse>0:
			draw_arc(p,34*s,0,TAU,40,Color(.3,.7,1,key_pulse*2),3,true)
	if target.slow > 0:
		draw_circle(p,25*s,Color(0.5,0.85,1,0.12))
		draw_arc(p+Vector2(0,12),23*s,0,TAU,24,Color("a2e6ec"),2,true)
	if art.sprites.has(kind):
		var stride := 0.0 if reduced_motion else sin(target.phase*1.6)
		var recoil: Vector2 = Vector2.ZERO if reduced_motion else (p-CastleRun.KEEP).normalized()*target.flash*55
		draw_set_transform(p+recoil+Vector2(0,18),stride*0.045,Vector2(1+stride*0.025,1-absf(stride)*0.05))
		if kind=="goblin" and not enemy_motion.clips.is_empty():
			var state := "hit" if enemy_reactions.has(target.id) else "idle"
			var seconds: float = float(enemy_reactions.get(target.id,0)) if state=="hit" else clock+target.id*0.19
			var frame := enemy_motion.texture(state,seconds,reduced_motion)
			var facing := -1.0 if p.x>CastleRun.KEEP.x else 1.0
			draw_texture_rect(frame,Rect2(Vector2(-55*facing,-90+bob),Vector2(110*facing,110)),false,Color("fff0c2") if target.flash>0 else Color.WHITE)
		else:
			art.draw_sprite(self,kind,Vector2(0,-35+bob),Vector2(68,78)*s,Color("fff0c2") if target.flash>0 else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		if kind=="boss":
			if target.rage:
				draw_arc(p,61,clock,clock+TAU*0.9,50,Color("d67c59"),2,true)
			if target.windup>0:
				draw_arc(p,67,-PI/2,-PI/2+TAU*minf(1,target.windup/4.5),60,Color("ffb170"),4,true)
				write("蓄力中 · 输入打断",p+Vector2(0,81),16,Color("8f4a23"),true)
		return
	if kind == "wolf":
		var fur := Color("8c9c9c") if target.flash <= 0 else Color("fff5ce")
		for dx in [-17,-6,9,19]:
			draw_line(p+Vector2(dx,4),p+Vector2(dx+sin(target.phase+dx)*4,17),fur.darkened(0.2),5,true)
		draw_line(p+Vector2(-14,0),p+Vector2(14,-3),fur,24,true)
		draw_colored_polygon(PackedVector2Array([p+Vector2(8,-17),p+Vector2(24,-25),p+Vector2(21,-7),p+Vector2(35,-2),p+Vector2(18,5)]),fur)
		draw_circle(p+Vector2(22,-10),2,Color("ffd084"))
		draw_line(p+Vector2(-20,-2),p+Vector2(-33,-15),fur,8,true)
		return
	var tint: Color = {"goblin":Color("a6bb75"),"guard":Color("809d8e"),"shaman":Color("a6a2be"),"bomber":Color("ccae6e"),"boss":Color("b79c7d")}[kind]
	if target.flash > 0:
		tint = Color("fff4d7")
	p.y += bob
	var body: Color = Color("655067") if kind=="shaman" else Color("6c4d3e")
	if kind == "boss":
		body = Color("6f4342")
	draw_colored_polygon(PackedVector2Array([p+Vector2(-13,-9)*s,p+Vector2(13,-9)*s,p+Vector2(21,15)*s,p+Vector2(-20,15)*s]),body)
	for sign_value in [-1,1]:
		draw_line(p+Vector2(sign_value*7,10)*s,p+Vector2(sign_value*11,22+sin(target.phase+sign_value)*2)*s,Color("3c3831"),7*s,true)
		draw_line(p+Vector2(sign_value*12,-4)*s,p+Vector2(sign_value*23,4)*s,tint.darkened(0.15),6*s,true)
	draw_circle(p-Vector2(0,15)*s,15*s,tint)
	for direction in [-1,1]:
		draw_colored_polygon(PackedVector2Array([p+Vector2(direction*10,-23)*s,p+Vector2(direction*26,-25)*s,p+Vector2(direction*12,-12)*s]),tint)
		draw_line(p+Vector2(direction*3,-19)*s,p+Vector2(direction*9,-21)*s,Color("343b31"),3*s,true)
		draw_circle(p+Vector2(direction*6,-16)*s,2*s,Color("f2d78b"))
		draw_circle(p+Vector2(direction*6,-16)*s,0.9*s,INK)
	draw_line(p+Vector2(-5,-7)*s,p+Vector2(5,-7)*s,Color("484635"),2*s,true)
	if kind == "guard":
		draw_colored_polygon(PackedVector2Array([p+Vector2(-2,-38),p+Vector2(15,-25),p+Vector2(-17,-25)]),Color("c3bf9d"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-28,-4),p+Vector2(-8,-4),p+Vector2(-10,17),p+Vector2(-19,23),p+Vector2(-28,17)]),Color("a8b8b0"))
		draw_line(p+Vector2(-19,-1),p+Vector2(-19,16),Color("426b74"),4,true)
	elif kind == "shaman":
		draw_line(p+Vector2(25,21),p+Vector2(25,-39),Color("9f8d6b"),4,true)
		draw_circle(p+Vector2(25,-42),9,Color("a1c6ac"))
		draw_arc(p,48,0,TAU,32,Color(0.6,0.83,0.7,0.3),1,true)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-17,-27),p+Vector2(0,-51),p+Vector2(16,-27)]),Color("6c5582"))
	elif kind == "bomber":
		draw_circle(p+Vector2(24,3),13,Color("393c3b"))
		draw_arc(p+Vector2(24,3),12,0,TAU,20,Color("aaa17a"),2,true)
		draw_line(p+Vector2(24,-10),p+Vector2(30,-19),Color("d2b77d"),2,true)
		flame(p+Vector2(30,-19),0.35)
	elif kind == "boss":
		draw_colored_polygon(PackedVector2Array([p+Vector2(-25,-50),p+Vector2(-30,-73),p+Vector2(-10,-61),p+Vector2(0,-79),p+Vector2(11,-61),p+Vector2(29,-72),p+Vector2(25,-50)]),Color("d3b470"))
		draw_line(p+Vector2(48,30),p+Vector2(48,-49),Color("9a805b"),8,true)
		draw_rect(Rect2(p+Vector2(28,-63),Vector2(43,30)),Color("6c7a79"))
		draw_line(p+Vector2(28,-61),p+Vector2(71,-61),Color("b2b59e"),4,true)
		if target.rage:
			draw_arc(p,61,clock,clock+TAU*0.9,50,Color("d67c59"),2,true)
		if target.windup > 0:
			draw_arc(p,67,-PI/2,-PI/2+TAU*minf(1,target.windup/4.5),60,Color("ffb170"),4,true)
			write("蓄力中 · 输入打断",p+Vector2(0,81),16,Color("8f4a23"),true)

func draw_target_label(target: Dictionary, occupied: Array[Rect2]) -> void:
	var word: String = target.word
	var font_size := 30 if word.length()==1 else 25 if word.length()<14 else 20
	var width := maxf(60,FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+24)
	var at: Vector2 = target.position-Vector2(width/2,79 if target.kind=="boss" else 63)
	at.x = clampf(at.x,12,size.x-width-12)
	var top_limit := 110.0 if battle.targets.any(func(t): return t.kind=="boss") else 72.0
	at.y = clampf(at.y,top_limit,size.y-74)
	var rect := Rect2(at+label_offsets.get(target.id,Vector2.ZERO),Vector2(width,50))
	rect.position = rect.position.clamp(Vector2(12,top_limit),Vector2(size.x-width-12,size.y-64))
	if occupied.any(func(r): return r.grow(5).intersects(rect)):
		var found := false
		for dy in [0,-56,56,-112,112,-168,168]:
			for dx in [0,-width-12,width+12]:
				var candidate := Rect2((at+Vector2(dx,dy)).clamp(Vector2(12,top_limit),Vector2(size.x-width-12,size.y-64)),rect.size)
				if not occupied.any(func(r): return r.grow(5).intersects(candidate)):
					rect = candidate
					found = true
					break
			if found:
				break
	label_offsets[target.id] = rect.position-at
	occupied.append(rect)
	var suggested := battle.recommended_target()
	var selected: bool = not suggested.is_empty() and target.id == suggested.id
	draw_line(rect.get_center()+Vector2(0,18),target.position-Vector2(0,22),Color(.3,.6,.86,.65) if selected else Color(.55,.68,.55,.4),2 if selected else 1,true)
	panel(rect,Color("effaff") if selected else Color.WHITE,9,PlayTheme.PRIMARY if selected else Color("adc593"))
	if selected:
		var tip := rect.get_center()+Vector2(0,-rect.size.y/2-6)
		draw_colored_polygon(PackedVector2Array([tip+Vector2(-6,-6),tip+Vector2(6,-6),tip]),PlayTheme.PRIMARY)
	write(word,rect.position+Vector2(12,29),font_size,Color("293c59"))
	if target.typed>0:
		write(word.substr(0,target.typed),rect.position+Vector2(12,29),font_size,MINT)
	var bar_width: float = (width-14)*maxf(0,float(target.health)/target.max_health)
	draw_rect(Rect2(rect.position+Vector2(7,36),Vector2(width-14,3)),Color("dfebd3"))
	draw_rect(Rect2(rect.position+Vector2(7,36),Vector2(bar_width,3)),Color("dca86d") if target.kind=="boss" else MINT)
	if selected:
		var prefix := FONT.get_string_size(word.substr(0,target.typed),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var next_width := FONT.get_string_size(word.substr(target.typed,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_line(rect.position+Vector2(12+prefix,33),rect.position+Vector2(12+prefix+maxf(9,next_width),33),GOLD,2,true)

func draw_effect(fx: Dictionary) -> void:
	var t: float = 1-fx.life/fx.duration
	var kind: String = fx.kind
	var tint: Color = {"ice":Color("a9e9ff"),"storm":Color("d0c1ff"),"heal":MINT,"damage":Color("f3947f"),"defeat":GOLD}.get(kind,Color("ffc277"))
	tint.a = 1-t
	var origin: Vector2 = fx.from-Vector2(0,30)
	var dest: Vector2 = fx.to-Vector2(0,10)
	if not reduced_motion:
		if kind == "storm":
			var points := PackedVector2Array()
			for i in range(10):
				var p := origin.lerp(dest,i/9.0)
				if i>0 and i<9:
					p += Vector2(sin(i*13+clock*37)*12,cos(i*17+clock*41)*13)
				points.append(p)
			draw_polyline(points,Color(0.55,0.4,1,(1-t)*0.25),10,true)
			draw_polyline(points,tint,3,true)
		elif kind in ["fire","ember","ice","heal"]:
			var travel := minf(1,t*2.8)
			var p := origin.lerp(dest,travel)
			for i in range(8):
				var trail := origin.lerp(dest,maxf(0,travel-i*0.025))
				draw_circle(trail,9-i*0.8,Color(tint.r,tint.g,tint.b,(1-i/8.0)*(1-t)*0.6))
			draw_circle(p,17,Color(tint.r,tint.g,tint.b,0.12*(1-t)))
			draw_circle(p,5,Color("fff8df"))
		if kind in ["fire","ice","ember","defeat","quake","build","damage"]:
			for i in range(10):
				var a := i*TAU/10
				var p := dest+Vector2(cos(a),sin(a))*(12+t*42)
				draw_circle(p,3*(1-t)+1,tint)
			draw_arc(dest,8+t*45,0,TAU,32,tint,2,true)
	if fx.amount>0 and kind not in ["wave"]:
		var text_value := "+%d G" % fx.amount if kind=="defeat" else ("+%d" if kind=="heal" else "-%d") % fx.amount
		write(text_value,dest+Vector2(45,16-t*28),17,tint,true)
	if kind == "interrupt":
		write("已打断",dest-Vector2(0,55+t*20),22,MINT,true)

func draw_top_status() -> void:
	panel(Rect2(16,14,1008,44),Color(1,1,1,0.95),14,Color("c8dcb8"))
	var text_value := battle.banner if banner_time>0 or battle.phase=="build" else "誓光林地 / 守住六波进攻"
	write(text_value,Vector2(34,43),19,GOLD)
	write("准备阶段 · 点击基座建塔" if battle.phase=="build" else "敌军  %02d / %02d" % [battle.spawned,CastleRun.WAVE_COUNTS[battle.wave-1]],Vector2(740,42),16,MINT)
	for target in battle.targets:
		if target.kind == "boss":
			panel(Rect2(260,64,520,40),Color("fff3e5"),12,Color("e0c7a9"))
			write("灰烬之王" if battle.wave==6 else "裂岩统领",Vector2(277,90),17,GOLD)
			draw_rect(Rect2(390,80,250,9),Color("e8d8d2"))
			draw_rect(Rect2(390,80,250*maxf(0,float(target.health)/target.max_health),9),Color("cb8761"))
			write("%d / %d" % [maxi(0,target.health),target.max_health],Vector2(663,91),15,Color("714b39"))

