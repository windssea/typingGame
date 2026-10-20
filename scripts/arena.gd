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
var key_pulse := 0.0
var error_pulse := 0.0
var input_point := Vector2.ZERO
var recent_key := ""
var key_beats: Array[Dictionary] = []
var displayed_wpm := 0.0
var world_offset := Vector2.ZERO
var cannon_x := 680.0
var label_rects: Dictionary = {}
var label_layouts: Dictionary = {}
var label_offsets: Dictionary = {}
var label_order: Array[Dictionary] = []
var impact_age := 1.0
var impact_tier := 1
var impact_point := Vector2.ZERO
var backdrop: TextureRect
var backdrop_external := false
var coach_motion := ArcadeMotion.new()
var coach_age := -1.0
const BREEZE = preload("res://shaders/scene_breeze.gdshader")

func setup_backdrop(texture: Texture2D) -> void:
	backdrop = TextureRect.new()
	backdrop.name = "LivingBackdrop"
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = size
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BREEZE
	shader_material.set_shader_parameter("strength",0.0 if reduced_motion else 1.0)
	shader_material.set_shader_parameter("world_kind",1 if run.mode in ["castle","moles"] else 2 if run.mode in ["aliens","rain"] else 3 if run.mode=="bubbles" else 4 if run.mode=="balloons" else 0)
	backdrop.material = shader_material
	add_child(backdrop)

func draw_scene_background() -> void:
	if is_instance_valid(backdrop):
		if not backdrop_external:
			backdrop.size = size
		backdrop.material.set_shader_parameter("clock",clock)

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
		var layout := TypingPrompt.measure(target.word,minf(480,size.x-32),52 if active else 38,32)
		var extent: Vector2 = layout.size
		var center: Vector2 = entry.center-Vector2(0,maxf(0,extent.y-58)*.5)
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
		var source: Vector2 = entry.source
		if not rect.grow(6).has_point(source):
			SoftStroke.line(self,source,source.clamp(rect.position,rect.end),Color(.2,.5,.7,.55) if active else Color(.35,.5,.6,.25),2.0 if active else 1.5)
		var edge := Color("bb6256") if active and error_pulse>0 else PlayTheme.PRIMARY if active else Color("afc9d4")
		if active:
			draw_style_box(PlayTheme.surface(Color(.24,.58,.82,.18),Color.TRANSPARENT,16),rect.grow(5))
		draw_style_box(PlayTheme.game_panel(Color("fff0bd") if active else Color("e3edf2"),Color("cf9e44") if active and error_pulse<=0 else edge,14,4),rect)
		TypingPrompt.paint(self,target.word,target.typed,rect,label_layouts[target.id],active,active and error_pulse>0)
		if target.has("health"):
			var fraction: float = clampf(float(target.health)/target.max_health,0,1)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.end-Vector2(10,4),Color("d5e7de"),3,true)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.position+Vector2(10+(rect.size.x-20)*fraction,rect.size.y-4),MINT,3,true)
		elif target.has("remaining") and run.mode!="racing":
			var fraction: float = clampf(target.remaining/target.duration,0,1)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.end-Vector2(10,4),Color("d9e7eb"),3,true)
			draw_line(rect.position+Vector2(10,rect.size.y-4),rect.position+Vector2(10+(rect.size.x-20)*fraction,rect.size.y-4),PlayTheme.CORAL if fraction<.25 else MINT,3,true)

func record_impact(point: Vector2, tier := 1) -> void:
	impact_point = point
	impact_tier = tier
	impact_age = 0

func draw_impact() -> void:
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
		key_pulse = 0.22
		key_beats.append({"point":point,"life":0.32})
		if key_beats.size()>6:
			key_beats.pop_front()
	else:
		error_pulse = 0.24

func step_feedback(delta: float) -> void:
	impact_age += delta
	key_pulse = maxf(0,key_pulse-delta)
	error_pulse = maxf(0,error_pulse-delta)
	displayed_wpm = lerpf(displayed_wpm,run.wpm(),1-exp(-delta*7))
	if run.mode=="rain":
		var target := run.recommended_target()
		var goal: float = float(target.position.x)-24 if not target.is_empty() else 656.0
		cannon_x = goal if reduced_motion else lerpf(cannon_x,goal,1-exp(-delta*10))
	for beat in key_beats.duplicate():
		beat.life -= delta
		if beat.life<=0:
			key_beats.erase(beat)

func draw_key_beats() -> void:
	if reduced_motion:
		return
	for beat in key_beats:
		var phase: float = 1-beat.life/0.32
		draw_arc(beat.point,18+phase*24,0,TAU,32,Color(0.25,0.65,0.88,(1-phase)*0.4),2,true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if run != null:
		art.setup(run.mode)
		if run.mode in ["dojo","sprint"]:
			coach_motion.setup("coach")
		setup_backdrop(art.background)
		clip_contents = true
		juice.reduced_motion = reduced_motion
		run.key_feedback.connect(on_key_feedback)
		run.spell.connect(func(a, b, lightning):
			var point: Vector2 = Vector2(1020,300) if run.mode=="dojo" else Vector2(340+680*fposmod(run.correct,20)/20,496) if run.mode=="sprint" else b
			var origin: Vector2 = Vector2(cannon_x+24,544) if run.mode=="rain" else a
			effects.append({"from":origin,"to":point,"lightning":lightning,"life":0.55})
			juice.burst(point,PlayTheme.SKY if run.mode in ["bubbles","rain"] else PlayTheme.YELLOW,2 if lightning else 1,{"bubbles":"droplet","rain":"ember","dojo":"confetti","sprint":"speed"}.get(run.mode,"spark"))
			juice.jet(point,Vector2.UP if run.mode=="bubbles" else Vector2.RIGHT,PlayTheme.SKY,1)
			record_impact(point,3 if lightning else 1))
		run.spell.connect(func(_a,_b,_l):
			if coach_age<0:
				coach_age = 0.0)

func _process(delta: float) -> void:
	if run == null or not run.paused:
		clock += delta
		if run!=null:
			step_feedback(delta)
			if coach_age>=0:
				coach_age += delta
				if coach_age>=coach_motion.duration("cheer"):
					coach_age = -1
		juice.step(delta)
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
		juice.protected_regions = [Rect2(300,275,760,145)]
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
		var ship := Vector2(cannon_x,572+recoil)
		draw_ellipse_shadow(ship+Vector2(0,14),Vector2(31,6))
		if art.sprites.has("cannon"):
			art.draw_sprite(self,"cannon",ship,Vector2(92,92))
		else:
			draw_colored_polygon(PackedVector2Array([ship+Vector2(-25,10),ship+Vector2(0,-21),ship+Vector2(25,10),ship]),PlayTheme.PRIMARY)
		if key_pulse>0:
			draw_line(ship+Vector2(24,-30),input_point,Color(0.38,0.8,1,key_pulse*2),4,true)
	var prompts: Array[Dictionary] = []
	var actors: Array[Rect2] = []
	for target in run.targets:
		var pos: Vector2 = target.position
		var suggested := run.recommended_target()
		var selected: bool = not suggested.is_empty() and target.id == suggested.id
		if run.mode == "castle":
			monster(pos, target.kind, selected)
		else:
			if not reduced_motion:
				for j in range(5):
					draw_circle(pos-Vector2(sin(clock*4+target.id+j)*4,18+j*12),9-j,Color(0.4,0.74,1,0.2-j*0.025))
			art.draw_sprite(self,"comet",pos,Vector2(64,68))
			if art.sprites.is_empty():
				draw_circle(pos,13,PlayTheme.SKY)
			draw_arc(pos, 19, 0, TAU, 24, GOLD if selected else MINT, 1.5, true)
		prompts.append({"target":target,"center":pos-Vector2(0,72),"source":pos-Vector2(0,20)})
		actors.append(Rect2(pos-Vector2(28,30),Vector2(56,62)))
	if not reduced_motion:
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
	juice.draw(self)
	draw_impact()
	draw_key_beats()
	draw_target_labels()

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

func draw_sprint() -> void:
	panel(Rect2(275,25,810,595),Color(.81,.92,.95,.9),30)
	art.draw_sprite(self,"stopwatch",Vector2(410,141),Vector2(100,105))
	art.draw_sprite(self,"trophy",Vector2(947,142),Vector2(100,105))
	var remaining := maxf(0,60-run.elapsed)
	write("%02d" % ceili(remaining),Vector2(680,185),64,GOLD,true)
	var speed_fraction := clampf(displayed_wpm/60.0,0,1)
	for i in range(24):
		var angle := PI*0.8+i*PI*1.4/23
		var point := Vector2(680,158)+Vector2.from_angle(angle)*78
		draw_line(point,point+Vector2.from_angle(angle)*8,PlayTheme.TEAL if i/24.0<speed_fraction else Color("d5e6f0"),4,true)
	draw_line(Vector2(300,219),Vector2(1060,219),Color("d5e1f1"),6,true)
	draw_line(Vector2(300,219),Vector2(300+760*remaining/60,219),MINT,6,true)
	if not run.targets.is_empty():
		var target: Dictionary = run.targets[0]
		training_word(target,Vector2(680,365),112 if str(target.word).length()==1 else 76,740)
	# Per-character motion on a miniature track; the text itself stays fixed.
	var track_y := 507.0
	draw_line(Vector2(327,track_y),Vector2(1033,track_y),Color("ddeaf3"),4,true)
	var progress := fposmod(run.correct,20)/20.0
	var runner := Vector2(340+680*progress,track_y-11)
	var frame := coach_motion.texture("run",clock,reduced_motion)
	if frame!=null:
		draw_texture_rect(frame,Rect2(runner-Vector2(73,122),Vector2(146,146)),false)
	write("%d 次完成" % run.kills,Vector2(680,575),25,MINT,true)
