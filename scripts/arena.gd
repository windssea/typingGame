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
	key_pulse = maxf(0,key_pulse-delta)
	error_pulse = maxf(0,error_pulse-delta)
	displayed_wpm = lerpf(displayed_wpm,run.wpm(),1-exp(-delta*7))
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
	if run != null:
		art.setup(run.mode)
		clip_contents = true
		juice.reduced_motion = reduced_motion
		run.key_feedback.connect(on_key_feedback)
		run.spell.connect(func(a, b, lightning):
			effects.append({"from":a,"to":b,"lightning":lightning,"life":0.55})
			juice.burst(b,PlayTheme.SKY if lightning else PlayTheme.YELLOW,2 if lightning else 1,"spark"))

func _process(delta: float) -> void:
	if run == null or not run.paused:
		clock += delta
		if run!=null:
			step_feedback(delta)
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
	panel(Rect2(Vector2.ZERO, size), Color("edf7ff"), 18, Color("cbdff0"))
	draw_texture_rect(art.background,Rect2(Vector2.ZERO,size),false)
	if run.mode == "dojo":
		draw_dojo()
		juice.draw(self)
		return
	if run.mode == "bubbles":
		draw_bubbles()
		juice.draw(self)
		return
	if run.mode == "sprint":
		draw_sprint()
		juice.draw(self)
		return
	if run.mode == "castle":
		draw_land(GameRun.CENTER, 1.0)
		castle(GameRun.CENTER - Vector2(0, 12), 0.8)
		write("键 之 城", GameRun.CENTER + Vector2(0, 93), 15, GOLD, true)
	else:
		for i in range(5):
			var x := 150.0 + i * 260
			draw_line(Vector2(x, 40), Vector2(x, 575), Color("d5e6f3"), 1)
		draw_line(Vector2(50, 587), Vector2(1310, 587), GOLD, 2)
		write("防 线", Vector2(680, 620), 16, GOLD, true)
		# A small interceptor visibly tracks the recommended threat.
		var threat := run.recommended_target()
		var aim_x: float = threat.position.x if not threat.is_empty() else 680.0
		var ship := Vector2(aim_x,572)
		draw_ellipse_shadow(ship+Vector2(0,14),Vector2(31,6))
		draw_colored_polygon(PackedVector2Array([ship+Vector2(-25,10),ship+Vector2(0,-21),ship+Vector2(25,10),ship]),PlayTheme.PRIMARY)
		if key_pulse>0:
			draw_line(ship,Vector2(aim_x,input_point.y),Color(0.38,0.8,1,key_pulse*2),4,true)
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
		word_plate(target, pos + Vector2(0, -40), selected)
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
	juice.draw(self)
	draw_key_beats()

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
	draw_set_transform(p, 0, Vector2(s, s))
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
	draw_set_transform(Vector2.ZERO)

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
	var word: String = target.word
	var font_size := 32 if word.length()==1 else 26 if word.length()<10 else 22
	var text_width := FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := maxf(60,text_width+32)
	at.x = clampf(at.x, width / 2 + 12, size.x - width / 2 - 12)
	at.y = maxf(at.y, 20)
	if selected:
		panel(Rect2(at - Vector2(width / 2+4, 34), Vector2(width+8,56)),Color(0.35,0.65,0.88,0.16),17)
	var edge := PlayTheme.CORAL if selected and error_pulse>0 else PlayTheme.PRIMARY if selected else Color("bfd3e5")
	panel(Rect2(at - Vector2(width / 2, 30), Vector2(width, 48)), Color("effaff") if selected else Color.WHITE, 13,edge)
	var start := at+Vector2(-text_width/2,7)
	write(word,start,font_size,Color("293c59"))
	if target.typed > 0:
		var part := word.substr(0,target.typed)
		write(part,start,font_size,MINT)
	if selected:
		var prefix := FONT.get_string_size(word.substr(0,target.typed), HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var next_width := FONT.get_string_size(word.substr(target.typed,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_line(start+Vector2(prefix,6),start+Vector2(prefix+maxf(9,next_width),6),GOLD,3,true)

func training_word(target: Dictionary, at: Vector2, preferred_size: int, max_width: float) -> void:
	var word: String = target.word
	var font_size := preferred_size
	while font_size>18 and FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>max_width:
		font_size -= 2
	var width := FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var start := at-Vector2(width/2,0)
	write(word,start,font_size,INK)
	write(word.substr(0,target.typed),start,font_size,MINT)
	var prefix := FONT.get_string_size(word.substr(0,target.typed),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var next_width := FONT.get_string_size(word.substr(target.typed,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_line(start+Vector2(prefix,8),start+Vector2(prefix+maxf(9,next_width),8),GOLD,3,true)

func draw_dojo() -> void:
	panel(Rect2(275,22,810,62),Color(1,1,1,0.94),16)
	var press := 0.0 if reduced_motion else key_pulse/0.22
	art.draw_sprite(self,"key",Vector2(354,236+press*10),Vector2(140+press*9,140-press*9))
	panel(Rect2(454,115,452,226),Color(1,1,1,0.94),32,PlayTheme.YELLOW)
	write("把双手轻放在基准键位，让每次击键都有方向。",Vector2(680,65),22,Color("586d84"),true)
	if run.targets.is_empty():
		return
	var target: Dictionary = run.targets[0]
	var word: String = target.word
	var next: String = word.substr(target.typed,1)
	draw_arc(Vector2(680,235),102,0,TAU,96,Color("b4d5e9"),2,true)
	draw_arc(Vector2(680,235),102,-PI/2,-PI/2+TAU*maxf(0.002,run.kills/18.0),96,PlayTheme.TEAL,5,true)
	training_word(target,Vector2(680,255),64,400)
	# A keyboard coach waves its jointed arms on every successful stroke.
	var buddy := Vector2(1020,240)
	var bounce := 0.0 if reduced_motion else sin(clock*2)*3-press*12
	draw_ellipse_shadow(buddy+Vector2(0,70),Vector2(48,9))
	buddy.y += bounce
	panel(Rect2(buddy-Vector2(42,38),Vector2(84,81)),Color("d7f3ed"),24,PlayTheme.TEAL)
	for sign_value in [-1,1]:
		var elbow := buddy+Vector2(sign_value*57,12-press*26)
		draw_line(buddy+Vector2(sign_value*36,8),elbow,PlayTheme.TEAL,7,true)
		draw_line(elbow,buddy+Vector2(sign_value*64,-10-press*35),PlayTheme.TEAL,7,true)
		draw_circle(buddy+Vector2(sign_value*16,-7),5,INK)
		draw_line(buddy+Vector2(sign_value*20,44),buddy+Vector2(sign_value*26,61),PlayTheme.TEAL,7,true)
	draw_arc(buddy+Vector2(0,6),13,0.15,PI-0.15,20,PlayTheme.TEAL,3,true)
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
			panel(rect, PlayTheme.YELLOW if active else Color("ffffff"),9,PlayTheme.PRIMARY if active else Color("ccddec"))
			write(key.to_upper(),rect.position+Vector2(24,28),18,INK if active else Color("405a77"),true)
			if key in "fj":
				draw_line(rect.position+Vector2(18,34),rect.position+Vector2(30,34),INK if active else GOLD,2)
	for side in range(2):
		var active: bool = finger_hint.shift and ((side == 0 and finger_hint.finger >= 4) or (side == 1 and finger_hint.finger < 4))
		var x := 295 if side==0 else 1045
		panel(Rect2(x,554,90,40),PlayTheme.YELLOW if active else Color("ffffff"),9)
		write("Shift",Vector2(x+45,581),17,INK if active else Color("405a77"),true)
	panel(Rect2(570,607,260,30),PlayTheme.YELLOW if next == " " else Color("ffffff"),9)
	write("SPACE",Vector2(700,628),15,INK if next == " " else Color("405a77"),true)

func draw_bubbles() -> void:
	panel(Rect2(277,22,806,65),Color(1,1,1,0.94),16)
	panel(Rect2(420,533,520,65),Color(1,1,1,0.94),16)
	write("选一个泡泡，输入它的内容。慢慢来，不限时。",Vector2(680,64),24,MINT,true)
	for i in range(20):
		var p := Vector2(70+fmod(i*173,1230),150+fmod(i*97,440))
		draw_circle(p,3+(i%5),Color(0.5,0.8,0.8,0.08))
	for target in run.targets:
		var p: Vector2 = target.position
		if not reduced_motion:
			p.y += sin(clock*0.8+target.id)*9
		var suggested := run.recommended_target()
		var selected: bool = not suggested.is_empty() and target.id==suggested.id
		var radius := 75.0
		var ripple := 0.0 if reduced_motion else sin(clock*2.2+target.id)*0.025
		draw_set_transform(p,0,Vector2(1+ripple,1-ripple))
		art.draw_sprite(self,"bubble",Vector2.ZERO,Vector2(166,166))
		draw_set_transform(Vector2.ZERO)
		draw_circle(p,radius,Color(0.4,0.8,0.75,0.08))
		draw_arc(p,radius,0,TAU,64,GOLD if selected else Color("70b7ad"),2,true)
		draw_arc(p,radius-10,PI*1.1,PI*1.4,18,Color(0.8,1,0.9,0.45),3,true)
		word_plate(target,p+Vector2(0,6),selected)
	for effect in effects:
		var t: float = 1-effect.life/0.55
		draw_arc(effect.to,75+t*35,0,TAU,40,Color(0.6,0.9,0.8,1-t),2,true)
		if not reduced_motion:
			for i in range(10):
				var angle := i*TAU/10
				var drop: Vector2 = effect.to+Vector2.from_angle(angle)*(45+t*95)+Vector2(0,t*t*30)
				draw_circle(drop,(1-t)*6,Color(0.35,0.75,0.85,1-t))
	for i in range(18):
		draw_circle(Vector2(450+i*27,505),6,PlayTheme.MINT if i<run.kills else Color(0.5,0.7,0.8,0.2))
	draw_key_beats()
	write("%d / 18  个泡泡已点亮" % run.kills,Vector2(680,575),25,GOLD,true)

func draw_sprint() -> void:
	panel(Rect2(275,25,810,595),Color(1,1,1,0.9),30)
	art.draw_sprite(self,"stopwatch",Vector2(410,141),Vector2(100,105))
	art.draw_sprite(self,"trophy",Vector2(947,142),Vector2(100,105))
	write("极 速 60 秒",Vector2(680,64),24,MINT,true)
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
		training_word(target,Vector2(680,350),58,700)
		write("接下来输入："+str(target.word).substr(target.typed,1),Vector2(680,415),22,MINT,true)
		word_plate(target,Vector2(680,470),true)
	# Per-character motion on a miniature track; the text itself stays fixed.
	var track_y := 507.0
	draw_line(Vector2(327,track_y),Vector2(1033,track_y),Color("ddeaf3"),4,true)
	var progress := fposmod(run.correct,20)/20.0
	var runner := Vector2(340+680*progress,track_y-11)
	var stride := 0.0 if reduced_motion else sin(clock*(5+minf(displayed_wpm,50)*0.3))*7
	draw_circle(runner-Vector2(0,21),8,PlayTheme.YELLOW)
	draw_line(runner-Vector2(0,12),runner,PlayTheme.PRIMARY,7,true)
	for sign_value in [-1,1]:
		draw_line(runner,runner+Vector2(sign_value*stride,11),PlayTheme.PRIMARY,4,true)
	for i in range(5):
		write(str(i*5),Vector2(340+i*170,541),13,PlayTheme.MUTED,true)
	write("已完成 %d 个目标   /   %.1f WPM" % [run.kills,run.wpm()],Vector2(680,563),23,GOLD,true)
	write("先保持准确，再加快节奏。",Vector2(680,607),18,Color("586d84"),true)
