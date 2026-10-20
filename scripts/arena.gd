class_name GameArena
extends Control

const FONT = preload("res://assets/ui-font.ttf")
const INK := PlayTheme.TEXT
const GOLD := PlayTheme.ORANGE
const MINT := PlayTheme.TEAL
var run: GameRun
var decorative := false
var reduced_motion := false
var clock := 0.0
var effects: Array[Dictionary] = []
var art := GeneratedArt.new()
var juice := GameJuice.new()
var feel := GameFeel.new()
var key_pulse := 0.0
var error_pulse := 0.0
var input_point := Vector2.ZERO
var recent_key := ""
var key_beats: Array[Dictionary] = []
var displayed_wpm := 0.0
var sprint_steps := 0.0
var sprint_running := false
var world_offset := Vector2.ZERO
var cannon_x := 680.0
var cannon_angle := 0.0
var cannon_barrel: AtlasTexture
var cannon_base: AtlasTexture
var emission_clock := 0.0
var label_rects: Dictionary = {}
var label_layouts: Dictionary = {}
var label_offsets: Dictionary = {}
var label_order: Array[Dictionary] = []
var impact_age := 1.0
var impact_tier := 1
var impact_point := Vector2.ZERO
var backdrop: TextureRect
var backdrop_external := false
var native_vfx: EngineVfx
var coach_motion := ArcadeMotion.new()
var coach_age := -1.0
const BREEZE = preload("res://shaders/scene_breeze.gdshader")

func setup_backdrop(texture: Texture2D) -> void:
	backdrop = TextureRect.new()
	backdrop.name = "LivingBackdrop"
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size = size
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BREEZE
	shader_material.set_shader_parameter("strength",0.0 if reduced_motion else 1.0)
	shader_material.set_shader_parameter("world_kind",1 if run.mode in ["castle","moles"] else 2 if run.mode in ["aliens","rain"] else 3 if run.mode=="bubbles" else 4 if run.mode=="balloons" else 0)
	backdrop.material = shader_material
	add_child(backdrop)
	native_vfx=EngineVfx.new()
	native_vfx.arena=self
	add_child(native_vfx)

func draw_scene_background() -> void:
	if is_instance_valid(backdrop):
		if not backdrop_external:
			backdrop.size = size
		backdrop.material.set_shader_parameter("clock",clock)
	WorldAtmosphere.paint(self,run.mode,clock,size,reduced_motion)

func layout_labels(candidates: Array[Dictionary], actors: Array[Rect2], blocked: Array[Rect2] = []) -> void:
	var selected: int = run.recommended_target().get("id",-1)
	candidates.sort_custom(func(a,b): return a.target.id==selected if (a.target.id==selected)!=(b.target.id==selected) else int(a.target.id)<int(b.target.id))
	var occupied: Array[Rect2] = blocked.duplicate()
	label_order = candidates
	label_rects.clear()
	label_layouts.clear()
	for entry in candidates:
		var target: Dictionary = entry.target
		var active: bool = target.id==selected
		var layout := TypingPrompt.measure(target.word,minf(480,size.x-32),52 if active else 42,32)
		var extent: Vector2 = layout.size
		var center: Vector2 = entry.center
		var rect := TypingPrompt.place(center,extent,Rect2(12,12,size.x-24,size.y-28),occupied,actors,label_offsets.get(target.id,Vector2.ZERO))
		label_offsets[target.id] = rect.position-(center-extent*.5)
		label_rects[target.id] = rect
		label_layouts[target.id] = layout
		occupied.append(rect)
	for id in label_offsets.keys():
		if not label_rects.has(id):
			label_offsets.erase(id)
	juice.protected_regions.clear()
	for rect in label_rects.values():
		juice.protected_regions.append(rect.grow(8))

func draw_target_labels() -> void:
	var selected: int = run.recommended_target().get("id",-1)
	for i in range(label_order.size()-1,-1,-1):
		var entry: Dictionary = label_order[i]
		var target: Dictionary = entry.target
		var active: bool = target.id==selected
		var rect: Rect2 = label_rects[target.id]
		var edge := Color("bb6256") if active and error_pulse>0 else PlayTheme.PRIMARY if active else Color("afc9d4")
		# A quiet, close-fitting label. Association comes from placement, never a leader line.
		draw_style_box(PlayTheme.surface(Color("fff1c9") if active else Color(.88,.95,.98,.90),edge if active else Color.TRANSPARENT,10),rect)
		TypingPrompt.paint(self,target.word,target.typed,rect,label_layouts[target.id],active,active and error_pulse>0)
		if target.has("health"):
			var fraction: float = clampf(float(target.health)/target.max_health,0,1)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.end-Vector2(10,4),Color("d5e7de"),3,true)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.position+Vector2(10+(rect.size.x-20)*fraction,rect.size.y-4),MINT,3,true)
		elif target.has("remaining") and run.mode!="racing":
			var fraction: float = clampf(target.remaining/target.duration,0,1)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.end-Vector2(10,4),Color("d9e7eb"),3,true)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.position+Vector2(10+(rect.size.x-20)*fraction,rect.size.y-4),PlayTheme.CORAL if fraction<.25 else MINT,3,true)

func record_impact(point: Vector2, tier := 1, tint := PlayTheme.YELLOW) -> void:
	if is_instance_valid(native_vfx): native_vfx.impact(point,tier,tint)
	feel.reduced_motion = reduced_motion
	feel.hit(point,tier,tint)
	impact_point = point
	impact_tier = tier
	impact_age = 0

func draw_impact() -> void:
	feel.draw(self,juice.protected_regions)
	if impact_age>.28 or reduced_motion or impact_tier<2:
		return
	var phase := impact_age/.28
	var color := Color("ffdc84") if impact_tier<3 else Color("a3e7fa")
	for i in range(3):
		var angle := i*TAU/3+.3
		SoftStroke.arc(self,impact_point,22+phase*(45+impact_tier*7),angle,angle+.65,Color(color,(1-phase)*.7),2.5)

func on_key_feedback(character: String, accepted: bool, point: Vector2) -> void:
	recent_key = character
	input_point = point
	if accepted:
		error_pulse = 0.0
		key_pulse = 0.22
		key_beats.append({"point":point,"life":0.32})
		if key_beats.size()>6:
			key_beats.pop_front()
	else:
		error_pulse = 0.24

func step_feedback(delta: float) -> void:
	feel.reduced_motion = reduced_motion
	feel.step(delta)
	impact_age += delta
	key_pulse = maxf(0,key_pulse-delta)
	error_pulse = maxf(0,error_pulse-delta)
	displayed_wpm = lerpf(displayed_wpm,run.wpm(),1-exp(-delta*7))
	if run.mode=="rain":
		var target := run.recommended_target()
		var goal: float = (Vector2(target.position)-Vector2(680,558)).angle()+PI/2 if not target.is_empty() else 0.0
		cannon_angle = goal if reduced_motion else lerp_angle(cannon_angle,goal,1-exp(-delta*14))
		cannon_x = 680
	for beat in key_beats.duplicate():
		beat.life -= delta
		if beat.life<=0:
			key_beats.erase(beat)

func draw_key_beats() -> void:
	pass

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if run != null:
		art.setup(run.mode)
		if run.mode=="rain":
			cannon_barrel=AtlasTexture.new()
			cannon_barrel.atlas=art.sprites.cannon
			cannon_barrel.region=Rect2(0,0,448,300)
			cannon_base=AtlasTexture.new()
			cannon_base.atlas=art.sprites.cannon
			cannon_base.region=Rect2(0,300,448,148)
		if run.mode in ["dojo","sprint"]:
			coach_motion.setup("robot" if run.mode=="sprint" else "coach")
		setup_backdrop(art.background)
		clip_contents = true
		juice.reduced_motion = reduced_motion
		run.key_feedback.connect(on_key_feedback)
		run.spell.connect(func(a, b, lightning):
			var point: Vector2 = Vector2(1020,300) if run.mode=="dojo" else Vector2(sprint_runner_x(),586) if run.mode=="sprint" else b
			var origin: Vector2 = Vector2(cannon_x+24,544) if run.mode=="rain" else a
			effects.append({"from":origin,"to":point,"lightning":lightning,"life":0.55})
			juice.burst(point,PlayTheme.SKY if run.mode in ["bubbles","rain"] else PlayTheme.YELLOW,2 if lightning else 1,{"bubbles":"droplet","rain":"ember","dojo":"confetti","sprint":"speed"}.get(run.mode,"spark"))
			juice.jet(point,Vector2.UP if run.mode=="bubbles" else Vector2.RIGHT,PlayTheme.SKY,1)
			record_impact(point,3 if lightning else 2 if run.mode=="rain" else GameFeel.tier(run.combo,false)))
		run.spell.connect(func(_a,_b,_l):
			if coach_age<0:
				coach_age = 0.0)
		run.projectile_launched.connect(func(_shot): key_pulse=.22)

func _process(delta: float) -> void:
	if run == null or not run.paused:
		clock += delta
		if run!=null:
			step_feedback(delta)
			if coach_age>=0:
				coach_age += delta
				if coach_age>=coach_motion.duration("cheer"):
					coach_age = -1
		if run!=null and run.mode=="sprint":
			var previous := sprint_steps
			sprint_steps = float(run.correct) if reduced_motion else move_toward(sprint_steps,float(run.correct),delta*maxf(6,(run.correct-sprint_steps)*12))
			sprint_running = absf(sprint_steps-previous)>.0001
		juice.step(delta)
		emission_clock+=delta
		if emission_clock>=.035 and run!=null:
			emission_clock=0.0
			for target in run.targets:
				if run.mode=="rain":
					var direction: Vector2=target.get("velocity",Vector2.DOWN).normalized()
					juice.trail(target.position-direction*20,-direction*42,Color("77d9ff"),6)
			for shot in run.projectiles:
				juice.trail(shot.position,(shot.previous-shot.position).normalized()*65,Color("a7edff") if shot.kind in ["ice","torpedo","interceptor"] else Color("ffb56e"),4)
		for effect in effects.duplicate():
			effect.life -= delta
			if effect.life <= 0:
				effects.erase(effect)
	queue_redraw()

func write(value: String, at: Vector2, font_size: int, color: Color, centered := false) -> void:
	var offset := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5 if centered else 0.0
	draw_string(FONT, at - Vector2(offset, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func panel(rect: Rect2, color: Color, radius := 12, border := Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1)
	draw_style_box(style, rect)

func _draw() -> void:
	if decorative:
		draw_land(Vector2(290, 214), 0.83)
		castle(Vector2(290, 204), 1.0)
		for i in range(3):
			var p := Vector2(95 + i * 165, 305 + (i % 2) * 37)
			monster(p, i, false)
			panel(Rect2(p + Vector2(-25, -60), Vector2(50, 29)), INK, 6, Color("3d5c60"))
			write(["f", "j", "k"][i], p + Vector2(0, -39), 18, GOLD, true)
		return
	if run == null:
		return
	draw_scene_background()
	if run.mode == "dojo":
		juice.protected_regions = [Rect2(450,110,460,270)]
		draw_dojo()
		juice.draw(self)
		draw_impact()
		return
	if run.mode == "bubbles":
		draw_bubbles()
		juice.draw(self)
		draw_impact()
		draw_target_labels()
		return
	if run.mode == "sprint":
		juice.protected_regions = [Rect2(270,235,820,215),Rect2(620,125,120,95)]
		draw_sprint()
		juice.draw(self)
		draw_impact()
		return
	if run.mode == "castle":
		draw_land(GameRun.CENTER, 1.0)
		castle(GameRun.CENTER - Vector2(0, 12), 0.8)
		write("键 之 城", GameRun.CENTER + Vector2(0, 93), 15, GOLD, true)
	else:
		draw_style_box(PlayTheme.game_panel(Color("e9f6ff"),Color("aed1dd"),8,3),Rect2(50,582,1260,12))
		write("防 线", Vector2(680, 620), 16, GOLD, true)
		# A small interceptor visibly tracks the recommended threat.
		var recoil := 0.0 if reduced_motion else sin(clampf(impact_age/.24,0,1)*PI)*9
		var ship := Vector2(680,558+recoil)
		draw_ellipse_shadow(ship+Vector2(0,14),Vector2(31,6))
		if cannon_base!=null:
			draw_texture_rect(cannon_base,Rect2(ship+Vector2(-58,0),Vector2(116,38)),false)
			draw_set_transform(ship,cannon_angle)
			draw_texture_rect(cannon_barrel,Rect2(-58,-78,116,78),false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_colored_polygon(PackedVector2Array([ship+Vector2(-25,10),ship+Vector2(0,-21),ship+Vector2(25,10),ship]),PlayTheme.PRIMARY)
	var prompts: Array[Dictionary] = []
	var actors: Array[Rect2] = []
	for target in run.targets:
		var pos: Vector2 = target.position
		var suggested := run.recommended_target()
		var selected: bool = not suggested.is_empty() and target.id == suggested.id
		if run.mode == "castle":
			monster(pos, target.kind, selected)
		else:
			var velocity: Vector2=target.get("velocity",Vector2.DOWN)
			var tail := pos-velocity.normalized()*96
			if not reduced_motion:
				draw_line(tail,pos,Color(.2,.75,1,.14),22,true)
				draw_line(tail.lerp(pos,.3),pos,Color(.45,.9,1,.4),10,true)
				draw_line(tail.lerp(pos,.6),pos,Color(.8,.96,1,.8),4,true)
			draw_set_transform(pos,velocity.angle()-PI/4)
			art.draw_sprite(self,"comet",Vector2.ZERO,Vector2(64,68))
			draw_set_transform(Vector2.ZERO)
			if art.sprites.is_empty():
				draw_circle(pos,13,PlayTheme.SKY)
		if not target.get("pending",false): prompts.append({"target":target,"center":pos-Vector2(0,76),"source":pos-Vector2(0,20)})
		actors.append(Rect2(pos-Vector2(28,30),Vector2(56,62)))
	if not reduced_motion and run.mode!="rain":
		for effect in effects:
			var t: float = 1.0 - effect.life / 0.55
			if effect.lightning:
				var points := PackedVector2Array()
				for i in range(8):
					var p: Vector2 = effect.from.lerp(effect.to, i / 7.0)
					p += Vector2(0, sin(i * 13.0 + clock * 40) * 16)
					points.append(p)
				draw_polyline(points, Color(0.6, 0.85, 1, 1 - t), 3, true)
			else:
				var p: Vector2 = effect.from.lerp(effect.to, minf(1, t * 2))
				draw_circle(p, 16, Color(1, 0.57, 0.25, 0.18))
				draw_circle(p, 7, Color("ffbc69"))
				draw_circle(p, 3, Color("fff0c1"))
			draw_arc(effect.to, 10 + t * 32, 0, TAU, 24, Color(0.92, 0.76, 0.47, 1 - t), 2, true)
	layout_labels(prompts,actors)
	draw_flights()
	juice.draw(self)
	draw_impact()
	draw_key_beats()
	draw_target_labels()

func draw_flights() -> void:
	for shot in run.projectiles:
		var p: Vector2=shot.position
		var tint := Color("9feaff") if shot.kind in ["ice","torpedo","interceptor"] else Color("ffb25b")
		var trail: Array=shot.trail
		if trail.size()>1 and not reduced_motion:
			for i in range(1,trail.size()):
				var alpha := 1-float(i)/trail.size()
				draw_line(trail[i],trail[i-1],Color(tint,alpha*.18),9*alpha+1,true)
				draw_line(trail[i],trail[i-1],Color(tint,alpha*.8),3*alpha+1,true)
		var angle: float=(p-Vector2(shot.previous)).angle()+(PI if shot.kind in ["fire","ember","ice"] else 0.0)
		draw_set_transform(p,angle)
		if shot.kind in ["fire","ember","ice"]:
			art.draw_sprite(self,"iceball" if shot.kind=="ice" else "fireball",Vector2.ZERO,Vector2(64,42))
		else:
			draw_style_box(PlayTheme.surface(Color("fff3cf"),Color("4cb2d4"),5),Rect2(-15,-5,30,10))
			draw_colored_polygon(PackedVector2Array([Vector2(-9,-5),Vector2(-17,-11),Vector2(-17,0)]),PlayTheme.TEAL)
			draw_circle(Vector2(-20,0),4,tint)
		draw_set_transform(world_offset)

func draw_land(center: Vector2, scale_value: float) -> void:
	for i in range(3):
		draw_arc(center, (90 + i * 95) * scale_value, 0, TAU, 80, Color("cbdfe8"), 1, true)
	for i in range(4):
		var angle := i * PI / 2 + PI / 4
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * 90 * scale_value, center + direction * 280 * scale_value, Color("e7d5b7"), 32 * scale_value)
	for i in range(42):
		var angle := i * 2.39996
		var radius := (190.0 + fmod(i * 43, 150)) * scale_value
		var point := center + Vector2(cos(angle) * radius * 1.6, sin(angle) * radius * 0.78)
		if point.x < 28 or point.x > size.x - 28 or point.y < 30 or point.y > size.y - 20:
			continue
		if i % 3 == 0:
			tree(point, 0.6 + (i % 4) * 0.12)
		else:
			draw_line(point, point + Vector2(3, -5), Color("67ae7b"), 1)
			draw_line(point + Vector2(5, 0), point + Vector2(7, -4), Color("67ae7b"), 1)

func tree(p: Vector2, s: float) -> void:
	draw_line(p, p - Vector2(0, 22) * s, Color("465c50"), 3)
	for i in range(3):
		var top := p - Vector2(0, 18 + i * 12) * s
		draw_colored_polygon(PackedVector2Array([top + Vector2(-15, 10) * s, top + Vector2(15, 10) * s, top - Vector2(0, 17) * s]), Color("6bbb88") if i % 2 == 0 else Color("8ace98"))

func castle(p: Vector2, s: float) -> void:
	draw_set_transform(p+world_offset, 0, Vector2(s, s))
	draw_ellipse_shadow(Vector2(0, 54), Vector2(120, 38))
	draw_colored_polygon(PackedVector2Array([Vector2(-118, 53),Vector2(0, 95),Vector2(118, 53),Vector2(0, 12)]), Color("a7cbd6"))
	draw_rect(Rect2(-77, -28, 154, 96), Color("fff3d4"))
	draw_rect(Rect2(0, -28, 77, 96), Color("ebd9b0"))
	for i in range(6):
		draw_line(Vector2(-76, -14 + i * 15),Vector2(76, -14 + i * 15),Color("5f817d"), 1)
	for x in [-82, 82]:
		draw_rect(Rect2(x - 23, -57, 46, 119), Color("fff4d5"))
		draw_rect(Rect2(x, -57, 23, 119), Color("e6d7b0"))
		for dx in [-23, -5, 13]:
			draw_rect(Rect2(x + dx, -69, 10, 20), Color("fff9e8"))
		draw_rect(Rect2(x - 6, -33, 12, 25), INK)
	draw_rect(Rect2(-34, -95, 68, 110), Color("fff8e5"))
	draw_rect(Rect2(0, -95, 34, 110), Color("ecdcb7"))
	draw_colored_polygon(PackedVector2Array([Vector2(-46,-93),Vector2(0,-145),Vector2(46,-93)]), Color("8d9fe9"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-145),Vector2(46,-93),Vector2(0,-93)]), Color("687ec9"))
	draw_line(Vector2(0,-145),Vector2(0,-185),GOLD,3)
	draw_colored_polygon(PackedVector2Array([Vector2(2,-184),Vector2(42,-174),Vector2(2,-160)]),GOLD)
	draw_style_box(arch_style(), Rect2(-22, 11, 44, 57))
	draw_rect(Rect2(-7,-68,14,24),Color("edd294"))
	for x in [-48,48]:
		draw_circle(Vector2(x,16),7,Color("ffb86e"))
		draw_circle(Vector2(x,16),13,Color(1,0.7,0.3,0.1))
	draw_set_transform(world_offset)

func arch_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	return style

func draw_ellipse_shadow(p: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		points.append(p + Vector2(cos(i * TAU / 32) * radius.x, sin(i * TAU / 32) * radius.y))
	draw_colored_polygon(points, Color(0.18,0.32,0.41,0.16))

func monster(p: Vector2, kind: int, selected: bool) -> void:
	var tint: Color = [Color("8cac68"),Color("b88d68"),Color("a18ac1")][kind]
	var s: float = [1.0,0.82,1.2][kind]
	if selected:
		draw_arc(p, 26 * s, 0, TAU, 28, GOLD, 2, true)
	draw_ellipse_shadow(p + Vector2(0, 15),Vector2(22,7) * s)
	draw_line(p+Vector2(-7,8)*s,p+Vector2(-9,19)*s,Color("394c42"),5)
	draw_line(p+Vector2(7,8)*s,p+Vector2(9,19)*s,Color("394c42"),5)
	draw_circle(p, 16*s, tint.darkened(0.25))
	draw_circle(p-Vector2(0,10)*s, 13*s, tint)
	for direction in [-1,1]:
		draw_colored_polygon(PackedVector2Array([p+Vector2(direction*8,-17)*s,p+Vector2(direction*24,-20)*s,p+Vector2(direction*12,-6)*s]),tint)
		draw_circle(p+Vector2(direction*5,-12)*s,2.5,INK)
		draw_circle(p+Vector2(direction*5,-13)*s,1,Color("f9e8b3"))
	if kind == 2:
		draw_line(p+Vector2(21,17),p+Vector2(21,-20),Color("c1b7a0"),4)
		draw_circle(p+Vector2(21,-22),6,Color("b9a2db"))

func word_plate(target: Dictionary, at: Vector2, selected: bool) -> void:
	var layout := TypingPrompt.measure(target.word,minf(size.x-28,700),36 if selected else 29,25)
	var rect := Rect2((at-layout.size*.5).clamp(Vector2(12,12),size-layout.size-Vector2(12,12)),layout.size)
	draw_style_box(PlayTheme.game_panel(Color("f3fcff") if selected else Color.WHITE,PlayTheme.PRIMARY if selected else Color("bfd3e5"),13,4),rect)
	TypingPrompt.paint(self,target.word,target.typed,rect,layout,selected,error_pulse>0)

func training_word(target: Dictionary, at: Vector2, preferred_size: int, max_width: float) -> void:
	var layout := TypingPrompt.measure(target.word,max_width,preferred_size,30)
	var rect := Rect2(at-Vector2(layout.size.x*.5,layout.font+8),layout.size)
	TypingPrompt.paint(self,target.word,target.typed,rect,layout,true,error_pulse>0)

func draw_dojo() -> void:
	var press := 0.0 if reduced_motion else key_pulse/0.22
	art.draw_sprite(self,"key",Vector2(354,236+press*10),Vector2(140+press*9,140-press*9))
	panel(Rect2(470,140,420,174),Color("f6df9f"),28,Color("e6c579"))
	if run.targets.is_empty():
		return
	var target: Dictionary = run.targets[0]
	var word: String = target.word
	var next: String = word.substr(target.typed,1)
	training_word(target,Vector2(680,255),64,400)
	# Genuine native-frame mascot animation, not a stick-figure proxy.
	var buddy := Vector2(1020,225)
	draw_ellipse_shadow(buddy+Vector2(0,95),Vector2(48,9))
	var state := "cheer" if coach_age>=0 else "idle"
	var coach := coach_motion.texture(state,coach_age if state=="cheer" else clock,reduced_motion)
	if coach!=null:
		draw_texture_rect(coach,Rect2(buddy-Vector2(145,145),Vector2(290,290)),false)
	write("%d / 18" % run.kills,Vector2(1020,354),22,MINT,true)
	write("下一个按键：" + ("空格" if next == " " else next),Vector2(680,376),20,MINT,true)
	var rows := ["1234567890", "qwertyuiop", "asdfghjkl;'", "zxcvbnm,./"]
	var finger_hint := TypingGuide.mapping(next)
	var physical_key: String = finger_hint.key
	for r in range(rows.size()):
		var row: String = rows[r]
		for col in range(row.length()):
			var key := row.substr(col,1)
			var rect := Rect2(385 + col * 57 + r * 12, 410 + r * 48, 49, 40)
			var active := key == physical_key
			if active and not reduced_motion:
				rect.position.y += press*4
			panel(rect, PlayTheme.YELLOW if active else Color("dceef1"),9,PlayTheme.PRIMARY if active else Color("ccddec"))
			write(key.to_upper(),rect.position+Vector2(24,28),18,INK if active else Color("405a77"),true)
			if key in "fj":
				draw_line(rect.position+Vector2(18,34),rect.position+Vector2(30,34),INK if active else GOLD,2)
	for side in range(2):
		var active: bool = finger_hint.shift and ((side == 0 and finger_hint.finger >= 4) or (side == 1 and finger_hint.finger < 4))
		var x := 295 if side==0 else 1045
		panel(Rect2(x,554,90,40),PlayTheme.YELLOW if active else Color("dceef1"),9)
		write("Shift",Vector2(x+45,581),17,INK if active else Color("405a77"),true)
	panel(Rect2(570,607,260,30),PlayTheme.YELLOW if next == " " else Color("dceef1"),9)
	write("SPACE",Vector2(700,628),15,INK if next == " " else Color("405a77"),true)

func draw_bubbles() -> void:
	for i in range(20):
		var p := Vector2(70+fmod(i*173,1230),150+fmod(i*97,440))
		draw_circle(p,3+(i%5),Color(0.5,0.8,0.8,0.08))
	var prompts: Array[Dictionary] = []
	var actors: Array[Rect2] = []
	for target in run.targets:
		var p: Vector2 = target.position
		if not reduced_motion:
			p.y += sin(clock*0.8+target.id)*9
		var suggested := run.recommended_target()
		var selected: bool = not suggested.is_empty() and target.id==suggested.id
		var radius := 75.0
		var ripple: float = 0.0 if reduced_motion else sin(clock*2.2+target.id)*0.025+(key_pulse/.22*.065 if selected else 0)
		draw_set_transform(p,0,Vector2(1+ripple,1-ripple))
		art.draw_sprite(self,"bubble",Vector2.ZERO,Vector2(166,166))
		draw_set_transform(Vector2.ZERO)
		draw_circle(p,radius,Color(0.4,0.8,0.75,0.08))
		prompts.append({"target":target,"center":target.position-Vector2(0,112),"source":p-Vector2(0,68)})
		actors.append(Rect2(p-Vector2(60,60),Vector2(120,120)))
	layout_labels(prompts,actors)
	for effect in effects:
		var t: float = 1-effect.life/0.55
		draw_arc(effect.to,75+t*35,0,TAU,40,Color(0.6,0.9,0.8,1-t),2,true)
		if not reduced_motion:
			for i in range(10):
				var angle := i*TAU/10
				var drop: Vector2 = effect.to+Vector2.from_angle(angle)*(45+t*95)+Vector2(0,t*t*30)
				draw_circle(drop,(1-t)*6,Color(0.35,0.75,0.85,1-t))
	draw_key_beats()

func sprint_runner_x() -> float:
	return 150+fposmod(sprint_steps,40)/40.0*1060

func draw_sprint() -> void:
	var remaining := maxf(0,60-run.elapsed)
	panel(Rect2(550,42,260,78),Color("214e69"),22)
	var seconds := ceili(remaining)
	write("%02d:%02d" % [seconds/60,seconds%60],Vector2(680,98),52,Color("fff4d7"),true)
	SoftStroke.line(self,Vector2(575,114),Vector2(785,114),Color("47788b"),4)
	SoftStroke.line(self,Vector2(575,114),Vector2(575+210*remaining/60,114),PlayTheme.YELLOW,4)
	if not run.targets.is_empty():
		var target: Dictionary = run.targets[0]
		var layout := TypingPrompt.measure(target.word,960,132 if str(target.word).length()==1 else 104,42)
		var rect := Rect2(Vector2(680,285)-layout.size*.5,layout.size)
		TypingPrompt.paint(self,target.word,target.typed,rect,layout,true,error_pulse>0)
	var runner := Vector2(sprint_runner_x(),568)
	var running_seconds := clock if sprint_running else 0.0
	var frame := coach_motion.texture("run" if coach_motion.clips.has("run") and sprint_running else "idle",running_seconds,reduced_motion)
	draw_ellipse_shadow(runner+Vector2(0,13),Vector2(37,8))
	if frame!=null:
		draw_texture_rect(frame,Rect2(runner-Vector2(110,176),Vector2(220,220)),false)
	art.draw_sprite(self,"trophy",Vector2(1220,542),Vector2(72,90))
