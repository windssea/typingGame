class_name ArcadeArena
extends GameArena

var bursts: Array[Dictionary] = []
var trauma := 0.0
var strike := 0.0
var last_impact := ""
const CORAL := Color("e96b70")
const BLUE := Color("448fce")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	art.setup(run.mode)
	run.impact.connect(on_impact)

func on_impact(kind: String, point: Vector2, power: int) -> void:
	bursts.append({"kind":kind,"point":point,"power":power,"life":0.7})
	strike = 0.5
	last_impact = kind
	if kind in ["fighter", "aliens", "miss"]:
		trauma = minf(1,trauma+(0.65 if power>0 and power%5==0 else 0.45))

func _process(delta: float) -> void:
	if run != null and not run.paused:
		clock += delta
		trauma = maxf(0,trauma-delta*2.5)
		strike = maxf(0,strike-delta)
		for burst in bursts.duplicate():
			burst.life -= delta
			if burst.life <= 0:
				bursts.erase(burst)
	queue_redraw()

func _draw() -> void:
	if run == null:
		return
	var backgrounds := {"balloons":Color("e9f7ff"),"aliens":Color("eef0ff"),"moles":Color("e9f5d9"),"racing":Color("eef7fe"),"fighter":Color("f5edff")}
	panel(Rect2(Vector2.ZERO,size),backgrounds[run.mode],24,Color("cbdff0"))
	draw_texture_rect(art.background,Rect2(Vector2.ZERO,size),false)
	var offset := Vector2.ZERO if reduced_motion else Vector2(sin(clock*45),cos(clock*38))*trauma*trauma*7
	draw_set_transform(offset)
	if not art.sprites.is_empty():
		draw_generated_game()
	else:
		match run.mode:
			"balloons": balloons()
			"aliens": aliens()
			"moles": moles()
			"racing": racing()
			"fighter": fighter()
	for burst in bursts:
		draw_burst(burst)
	draw_set_transform(Vector2.ZERO)
	# Words stay still and above feedback; readability takes priority over particles.
	for target in run.targets:
		var p: Vector2 = target.position
		if run.mode in ["balloons", "moles"]:
			p += Vector2(0,-65)
		elif run.mode == "aliens":
			p += Vector2(0,-55)
		word_plate(target,p,run.locked == target.id)
		if run.mode != "racing":
			var fraction: float = clampf(target.remaining/target.duration,0,1)
			panel(Rect2(p+Vector2(-42,20),Vector2(84,4)),Color("d4e3ee"),2)
			panel(Rect2(p+Vector2(-42,20),Vector2(84*fraction,4)),CORAL if fraction<0.25 else MINT,2)
	panel(Rect2(24,588,992,43),Color("ffffff"),8)
	var notes := {"balloons":"输入击破气球 · 越靠近顶部，越需要优先处理", "aliens":"输入发射激光 · 每三连击补充护盾 · 拦截俯冲外星舰", "moles":"输入举牌文字敲击地鼠 · 训练中漏掉不会扣体力", "racing":"完整输入推进赛程 · 三连击氮气加速 · 挑战需先于对手冲线", "fighter":"在蓄力条耗尽前输入 · 重拳打断攻击 · 四次命中击倒一位对手"}
	write(notes[run.mode],Vector2(44,616),17,Color("455d75"))

func banner(title: String, subtitle: String) -> void:
	panel(Rect2(16,14,1008,76),Color(1,1,1,0.95),16)
	write(title,Vector2(32,43),24,GOLD)
	write(subtitle,Vector2(32,74),16,Color("586d84"))
	write("%03d%%" % roundi(run.distance*100) if run.mode=="racing" else "%02d / %02d" % [run.kills,run.goal],Vector2(920,43),23,MINT,true)

func draw_generated_game() -> void:
	var titles := {"balloons":"风起气球节","aliens":"星港防卫线","moles":"地鼠的午后","racing":"键盘拉力赛","fighter":"指尖格斗馆"}
	banner(titles[run.mode],run.status_text())
	if run.mode == "moles":
		for i in range(6):
			var hole := Vector2(240+(i%3)*280,326+(i/3)*170)
			draw_ellipse_shadow(hole,Vector2(66,20))
			draw_arc(hole,57,0,PI,32,Color("9e713f"),5,true)
	for target in run.targets:
		var p: Vector2 = target.position
		var bob := 0.0 if reduced_motion else sin(clock*2+target.id)*5
		match run.mode:
			"balloons":
				art.draw_sprite(self,["balloon_coral","balloon_blue","balloon_gold"][target.lane%3],p+Vector2(bob,22),Vector2(117,155))
			"aliens":
				art.draw_sprite(self,"ufo",p+Vector2(0,bob),Vector2(125,90))
			"moles":
				art.draw_sprite(self,"mole",p+Vector2(0,-7),Vector2(113,107))
	if run.mode == "aliens":
		art.draw_sprite(self,"ship",Vector2(520,518),Vector2(137,122))
		if run.shield>0:
			draw_arc(Vector2(520,518),84,PI,TAU,48,Color(0.65,0.93,1,0.8),3,true)
		panel(Rect2(26,499,215,64),Color(1,1,1,0.95),12)
		write("护盾 %d / 60" % run.shield,Vector2(40,525),17,BLUE)
		panel(Rect2(40,540,185,9),Color("d3e6f3"),4)
		panel(Rect2(40,540,185*run.shield/60.0,9),BLUE,4)
	elif run.mode == "racing":
		var player := Vector2(120+run.distance*770,356)
		var rival := Vector2(120+run.rival*770,510)
		for y in [305,458]:
			for row in range(6):
				for col in range(2):
					draw_rect(Rect2(939+col*13,y+row*16,13,16),Color.WHITE if (row+col)%2==0 else INK)
		if run.boost>0:
			art.draw_sprite(self,"impact",player-Vector2(65,0),Vector2(96,62))
		art.draw_sprite(self,"car_mint",player,Vector2(136,88))
		art.draw_sprite(self,"car_coral",rival,Vector2(136,88))
		panel(Rect2(player-Vector2(52,71),Vector2(104,29)),Color.WHITE,9)
		write("你  %d%%" % roundi(run.distance*100),player-Vector2(33,50),17,MINT)
		panel(Rect2(rival-Vector2(52,71),Vector2(104,29)),Color.WHITE,9)
		write("陪练车" if run.context=="training" else "对手",rival-Vector2(29,50),17,CORAL)
		panel(Rect2(330,204,380,44),Color(1,1,1,0.95),12)
		write("三连击 · 氮气加速" if run.boost>0 else "连续输入为赛车充能",Vector2(520,234),22,GOLD,true)
	elif run.mode == "fighter":
		var punch := 0.0 if reduced_motion else sin(clampf(strike/0.5,0,1)*PI)
		var left := Vector2(350,440)+Vector2(punch*(120 if last_impact!="miss" else -20),0)
		var right := Vector2(690,440)+Vector2(punch*(-120 if last_impact=="miss" else 20),0)
		art.draw_sprite(self,"boxer_blue",left,Vector2(200,250))
		art.draw_sprite(self,"boxer_coral",right,Vector2(200,250))
		for side in range(2):
			var x := 50+side*560
			var health: int = run.hp if side==0 else run.enemy_hp
			panel(Rect2(x,105,380,65),Color(1,1,1,0.94),12)
			panel(Rect2(x+15,119,350,10),Color("deddee"),5)
			panel(Rect2(x+15,119,350*health/100.0,10),MINT if side==0 else CORAL,5)
			write(("你" if side==0 else "对手")+" · 体力 %d" % health,Vector2(x+15,154),17,INK)
		if run.combo>1:
			panel(Rect2(220,198,250,44),Color.WHITE,12)
			write("%d HIT COMBO" % run.combo,Vector2(345,230),25,GOLD,true)

func balloons() -> void:
	banner("风起气球节", "看清一个目标，让字母变成一场小小的烟花。")
	draw_circle(Vector2(930,124),29,PlayTheme.YELLOW)
	for i in range(10):
		var ray := Vector2.from_angle(i*TAU/10)
		draw_line(Vector2(930,124)+ray*37,Vector2(930,124)+ray*44,PlayTheme.YELLOW,4,true)
	for i in range(5):
		var p := Vector2(100+i*216,145+(i%2)*58)
		for j in range(3):
			draw_circle(p+Vector2(j*24,cos(j)*8),26,Color("ffffff"))
	for i in range(3):
		draw_circle(Vector2(180+i*390,810+i*30),300,Color("b5e3ac") if i%2==0 else Color("c8edb8"))
	for target in run.targets:
		var p: Vector2 = target.position
		var tint: Color = [PlayTheme.CORAL,PlayTheme.SKY,PlayTheme.YELLOW][target.lane%3]
		var sway := 0.0 if reduced_motion else sin(clock*1.8+target.id)*8
		draw_polyline(PackedVector2Array([p+Vector2(0,42),p+Vector2(sway,75),p+Vector2(-sway,100)]),Color("83a8b8"),2,true)
		draw_set_transform(p,0,Vector2(0.85,1))
		draw_circle(Vector2.ZERO,47,tint.darkened(0.18))
		draw_circle(Vector2(-8,-8),34,tint)
		draw_arc(Vector2(-5,-7),27,PI*1.03,PI*1.45,20,tint.lightened(0.5),5,true)
		for x in [-11,11]:
			draw_circle(Vector2(x,5),3,INK)
		draw_arc(Vector2(0,13),8,0.2,PI-0.2,16,INK,2,true)
		draw_colored_polygon(PackedVector2Array([Vector2(0,44),Vector2(-7,54),Vector2(7,54)]),tint)
		draw_set_transform(Vector2.ZERO)
	# A little launch stand grounds the otherwise floating play field.
	panel(Rect2(460,520,120,46),Color("e7b46c"),9)
	for i in range(4):
		draw_line(Vector2(474+i*27,525),Vector2(474+i*27,561),GOLD,3,true)

func aliens() -> void:
	banner("星港防卫线", "第 %d 阵 · %s" % [mini(run.wave,4),run.status_text()])
	for i in range(65):
		var p := Vector2(32+fmod(i*137.5,970),100+fmod(i*97.3,435))
		draw_circle(p,1+(i%3)*0.6,Color(0.47,0.46,0.8,0.22+(i%4)*0.09))
	draw_circle(Vector2(910,130),62,Color("c6b7ef"))
	draw_arc(Vector2(910,130),77,-0.5,2.7,48,Color("ae98e0"),12,true)
	for target in run.targets:
		var p: Vector2 = target.position
		var bob := 0.0 if reduced_motion else sin(clock*4+target.id)*4
		p.y += bob
		draw_circle(p-Vector2(0,13),25,Color("9fcceb"))
		draw_circle(p-Vector2(0,16),18,Color("a6df90"))
		for direction in [-1,1]:
			draw_circle(p+Vector2(direction*7,-18),4,INK)
		panel(Rect2(p-Vector2(43,5),Vector2(86,20)),Color("9b8bda"),12)
		for x in [-28,0,28]:
			draw_circle(p+Vector2(x,7),3,CORAL)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-13,17),p+Vector2(13,17),p+Vector2(0,38)]),Color(0.55,0.85,1,0.2))
	var ship := Vector2(520,518)
	draw_colored_polygon(PackedVector2Array([ship+Vector2(-65,25),ship+Vector2(-20,-12),ship+Vector2(0,-55),ship+Vector2(20,-12),ship+Vector2(65,25),ship]),Color("4d9ae1"))
	draw_colored_polygon(PackedVector2Array([ship+Vector2(-12,5),ship+Vector2(0,-36),ship+Vector2(12,5)]),PlayTheme.YELLOW)
	if run.shield>0:
		draw_arc(ship,84,PI,TAU,48,Color(0.5,0.8,1,0.25+run.shield/100.0),3,true)
	panel(Rect2(32,544,200,10),Color("d3e6f3"),4)
	panel(Rect2(32,544,200*run.shield/60.0,10),BLUE,4)
	write("护盾 %d / 60" % run.shield,Vector2(32,531),16,BLUE)

func moles() -> void:
	banner("地鼠的午后", "六个洞口，找准举牌的小家伙。")
	for i in range(48):
		var p := Vector2(34+fmod(i*183,980),180+fmod(i*73,380))
		draw_line(p,p+Vector2(-3,-8),Color("78b56c"),2,true)
		draw_line(p,p+Vector2(4,-6),Color("78b56c"),2,true)
	for i in range(6):
		var p := Vector2(240+(i%3)*280,300+(i/3)*170)
		draw_ellipse_shadow(p+Vector2(0,27),Vector2(85,29))
		draw_arc(p+Vector2(0,16),65,0,PI,32,Color("a9ce8f"),8,true)
	for target in run.targets:
		var p: Vector2 = target.position
		draw_circle(p,44,Color("ac866b"))
		draw_circle(p+Vector2(-31,-26),15,Color("8e6b58"))
		draw_circle(p+Vector2(31,-26),15,Color("8e6b58"))
		draw_circle(p-Vector2(0,14),34,Color("c9a07c"))
		for x in [-13,13]:
			draw_circle(p+Vector2(x,-19),4,INK)
			draw_circle(p+Vector2(x-1,-21),1.5,Color.WHITE)
		draw_circle(p-Vector2(0,5),8,CORAL)
		draw_line(p+Vector2(-7,13),p+Vector2(7,13),Color("614a40"),2,true)
		draw_rect(Rect2(p+Vector2(-5,8),Vector2(10,13)),Color("f4dfb5"))
		panel(Rect2(p+Vector2(-31,-52),Vector2(62,10)),GOLD,3)

func car(p: Vector2, tint: Color, powered: bool) -> void:
	draw_ellipse_shadow(p+Vector2(0,12),Vector2(58,27))
	if powered:
		var length := 44.0 if reduced_motion else 40+sin(clock*40)*14
		draw_colored_polygon(PackedVector2Array([p+Vector2(-42,-10),p+Vector2(-42,10),p+Vector2(-42-length,0)]),CORAL)
		draw_line(p+Vector2(-45,0),p+Vector2(-62,0),GOLD,8,true)
	for x in [-25,25]:
		for y in [-22,22]:
			panel(Rect2(p+Vector2(x-10,y-6),Vector2(20,12)),Color("080f16"),3)
	panel(Rect2(p+Vector2(-46,-22),Vector2(92,44)),tint,12)
	panel(Rect2(p+Vector2(-11,-17),Vector2(34,34)),Color("17303e"),7)
	draw_line(p+Vector2(-40,-14),p+Vector2(-40,14),tint.lightened(0.35),4,true)
	for y in [-15,15]:
		draw_line(p+Vector2(38,y),p+Vector2(44,y),GOLD,4,true)

func racing() -> void:
	banner("键盘拉力赛", "训练自由完赛；挑战模式需率先冲线。")
	for lane in range(2):
		var y := 302+lane*155
		panel(Rect2(30,y,980,124),Color("d3e4f4"),10)
		for i in range(18):
			var movement := 0.0 if reduced_motion else fmod(clock*(130 if run.boost>0 else 35),55)
			draw_line(Vector2(46+i*55-movement,y+62),Vector2(68+i*55-movement,y+62),Color("ffffff"),3,true)
		for i in range(6):
			for j in range(2):
				draw_rect(Rect2(939+j*16,y+12+i*16,16,16),Color("ffffff") if (i+j)%2==0 else INK)
	var player := Vector2(120+run.distance*770,364)
	var rival := Vector2(120+run.rival*770,519)
	car(player,PlayTheme.MINT,run.boost>0)
	car(rival,CORAL,false)
	write("你  %d%%" % roundi(run.distance*100),player-Vector2(32,46),18,MINT)
	write("陪练车" if run.context=="training" else "对手",rival-Vector2(30,46),18,CORAL)
	write("连续输入为赛车充能",Vector2(520,225),20,GOLD,true)
	if run.combo>=3:
		write("NITRO  × %d" % run.combo,Vector2(520,266),26,MINT,true)

func boxer(p: Vector2, tint: Color, facing: int, attack: float) -> void:
	draw_ellipse_shadow(p+Vector2(0,98),Vector2(60,18))
	var lean := attack*facing*30
	draw_line(p+Vector2(-17,38),p+Vector2(-30,92),Color("40546b"),20,true)
	draw_line(p+Vector2(18,38),p+Vector2(33,92),Color("40546b"),20,true)
	panel(Rect2(p+Vector2(-28+lean,-43),Vector2(56,89)),tint,18)
	draw_circle(p+Vector2(lean,-72),29,Color("e0b58c"))
	draw_arc(p+Vector2(lean,-76),26,PI,TAU,20,tint.darkened(0.2),11,true)
	draw_line(p+Vector2(lean+facing*10,-26),p+Vector2(lean+facing*(47+attack*115),-30),Color("e0b58c"),14,true)
	draw_circle(p+Vector2(lean+facing*(54+attack*115),-30),21,tint.lightened(0.2))
	draw_circle(p+Vector2(lean-facing*29,-22),18,tint)
	draw_circle(p+Vector2(lean+facing*11,-75),3,INK)

func fighter() -> void:
	banner("指尖格斗馆", "第 %d 位对手 · 输入打断蓄力，稳住节奏形成连击。" % run.round_number)
	for i in range(14):
		var p := Vector2(65+i*72,250+(i%2)*15)
		draw_circle(p,15,Color("e7b7bd"))
		panel(Rect2(p+Vector2(-20,19),Vector2(40,56)),Color("c4b0de"),12)
	draw_colored_polygon(PackedVector2Array([Vector2(105,350),Vector2(900,350),Vector2(1000,566),Vector2(38,566)]),Color("d3c8f0"))
	for y in [345,400,455]:
		draw_line(Vector2(80,y),Vector2(950,y),Color("ffffff"),4,true)
	for x in [80,950]:
		draw_line(Vector2(x,325),Vector2(x,555),CORAL,12,true)
	var punch := 0.0 if reduced_motion else sin(clampf(strike/0.5,0,1)*PI)
	if last_impact == "miss":
		boxer(Vector2(355-punch*20,445),PlayTheme.SKY,1,0)
		boxer(Vector2(690-punch*120,445),CORAL,-1,punch)
	else:
		boxer(Vector2(355+punch*120,445),PlayTheme.SKY,1,punch)
		boxer(Vector2(690+punch*20,445),CORAL,-1,0)
	panel(Rect2(65,110,350,12),Color("deddee"),5)
	panel(Rect2(65,110,350*run.hp/100.0,12),MINT,5)
	panel(Rect2(625,110,350,12),Color("deddee"),5)
	panel(Rect2(625,110,350*run.enemy_hp/100.0,12),CORAL,5)
	write("你 · 体力 %d" % run.hp,Vector2(65,150),17,MINT)
	write("对手 · 体力 %d" % run.enemy_hp,Vector2(625,150),17,CORAL)
	if run.combo>1:
		write("%d HIT COMBO" % run.combo,Vector2(340,230),27,GOLD,true)

func draw_burst(burst: Dictionary) -> void:
	var t: float = 1-burst.life/0.7
	var p: Vector2 = burst.point
	var color: Color = CORAL if burst.kind=="miss" else PlayTheme.YELLOW
	if burst.kind=="fighter":
		p = Vector2(650,400)
	elif burst.kind=="miss" and run.mode=="fighter":
		p = Vector2(390,400)
	elif burst.kind=="racing":
		p = Vector2(200+run.distance*600,350)
	if not reduced_motion:
		if burst.kind=="aliens":
			draw_line(Vector2(520,478),p,Color(0.5,0.85,1,(1-t)*0.7),9*(1-t)+1,true)
		elif burst.kind=="miss" and run.mode=="aliens":
			draw_line(p,Vector2(520,518),Color(1,0.5,0.45,1-t),5,true)
		if burst.kind=="moles":
			var hammer := p+Vector2(35,-50-25*t)
			draw_line(hammer,hammer+Vector2(46,56),Color("b99774"),10,true)
			panel(Rect2(hammer-Vector2(28,12),Vector2(56,32)),PlayTheme.YELLOW,7)
		var radius := 100 if burst.power>0 and burst.power%5==0 else 65
		draw_arc(p,12+t*radius,0,TAU,32,Color(color,1-t),3*(1-t)+1,true)
		for i in range(12):
			var direction := Vector2.from_angle(i*TAU/12)
			var end := p+direction*(16+90*t)+Vector2(0,t*t*35)
			draw_line(end,end-direction*9,Color(color,1-t),3,true)
	var caption := "漏过" if burst.kind=="miss" else ("重击！" if burst.kind=="fighter" else "+ 命中")
	write(caption,p+Vector2(0,-15-(0 if reduced_motion else t*42)),23,Color(PlayTheme.ORANGE if burst.kind!="miss" else Color("b13b4e"),1-t),true)
