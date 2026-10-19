class_name ArcadeArena
extends GameArena

var bursts: Array[Dictionary] = []
var trauma := 0.0
var strike := 0.0
var last_impact := ""
var blue_attack_age := -1.0
var coral_attack_age := -1.0
var trail_clock := 0.0
var motion := ArcadeMotion.new()
var reaction_echoes: Array[Dictionary] = []
var nitro_age := -1.0
var shield_pulse := 0.0
var impact_freeze := 0.0
var pose_clock := 0.0
var previous_correct := 0
var charge_flash := 0.0
var checkpoint_age := 0.0
var checkpoint_label := ""
const CORAL := Color("e96b70")
const BLUE := Color("448fce")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	art.setup(run.mode)
	motion.setup(run.mode)
	juice.reduced_motion = reduced_motion
	run.impact.connect(on_impact)

func on_impact(kind: String, point: Vector2, power: int) -> void:
	if kind=="skill":
		shield_pulse = 0.65
		var location := Vector2(350,410) if run.mode=="fighter" else Vector2(120+run.rival*770,510) if run.mode=="racing" else Vector2(520,480)
		juice.burst(location,Color("8ae3eb"),2,"spark")
		return
	if kind in ["moles","aliens"]:
		reaction_echoes.append({"point":point,"age":0.0,"kind":kind})
		if reaction_echoes.size()>8:
			reaction_echoes.pop_front()
	if kind=="racing":
		nitro_age = 0.0
	if kind==run.mode and run.context=="training" and run.kills>0 and run.kills%6==0 and run.kills<run.goal:
		checkpoint_age = 1.6
		checkpoint_label = "阶段完成！技能已充满 · 下一段继续冒险"
		juice.burst(Vector2(520,100),PlayTheme.YELLOW,1,"confetti")
	if kind=="aliens" and power%3==0:
		shield_pulse = 0.65
	if kind!="miss":
		impact_freeze = 0.045 if kind in ["moles","fighter"] else 0.025
	if run.mode=="fighter":
		point = Vector2(420,410) if kind in ["miss","block"] else Vector2(635,410)
		if kind in ["miss","block"]:
			coral_attack_age = 0.0
		else:
			blue_attack_age = 0.0
	bursts.append({"kind":kind,"point":point,"power":power,"life":0.7})
	if bursts.size()>18:
		bursts.pop_front()
	var color: Color = {"aliens":Color("88eaff"),"balloons":Color("ffcb72"),"moles":Color("d5b079"),"fighter":Color("ffd574"),"miss":CORAL}.get(kind,Color("a1e8c1"))
	juice.burst(point,color,3 if power>0 and power%5==0 else 1,"soil" if kind=="moles" else "confetti" if kind=="balloons" else "spark")
	strike = 0.5
	last_impact = kind
	if kind in ["fighter", "aliens", "miss"]:
		trauma = minf(1,trauma+(0.65 if power>0 and power%5==0 else 0.45))

func _process(delta: float) -> void:
	if run != null and not run.paused:
		clock += delta
		# Freeze only the character pose for an impact beat; input, timers and FX continue.
		impact_freeze = maxf(0,impact_freeze-delta)
		if impact_freeze<=0 or reduced_motion:
			pose_clock += delta
		shield_pulse = maxf(0,shield_pulse-delta)
		charge_flash = maxf(0,charge_flash-delta)
		checkpoint_age = maxf(0,checkpoint_age-delta)
		if previous_correct!=run.correct:
			charge_flash = 0.18
			previous_correct = run.correct
		if nitro_age>=0:
			nitro_age += delta
		for echo in reaction_echoes.duplicate():
			echo.age += delta
			if echo.age>=maxf(0.6,motion.duration("hit")):
				reaction_echoes.erase(echo)
		juice.step(delta)
		if blue_attack_age>=0:
			blue_attack_age += delta
		if coral_attack_age>=0:
			coral_attack_age += delta
		trail_clock -= delta
		if trail_clock<=0:
			trail_clock = 0.05
			if run.mode=="aliens":
				juice.trail(Vector2(520+sin(clock*3)*7,560),Vector2(0,65),Color("7ae2ff"),8)
			elif run.mode=="racing":
				var p := Vector2(70+run.distance*770,364)
				juice.trail(p,Vector2(-120,15),Color("d9e3f2"),7)
				if run.boost>0 and run.combo>=3:
					juice.trail(p,Vector2(-220,0),Color("67e5ff"),11)
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
	draw_atmosphere()
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
	draw_skill_field()
	for burst in bursts:
		draw_burst(burst)
	if checkpoint_age>0:
		panel(Rect2(242,77,560,33),Color(1,0.96,0.82,0.96),12)
		write(checkpoint_label,Vector2(522,100),17,PlayTheme.ORANGE,true)
	juice.draw(self)
	draw_set_transform(Vector2.ZERO)
	# Words stay still and above feedback; readability takes priority over particles.
	for target in run.targets:
		var p: Vector2 = target.position
		if run.mode in ["balloons", "moles"]:
			p += Vector2(0,-65)
			p.y = maxf(100,p.y)
		elif run.mode == "aliens":
			p += Vector2(0,-55)
		var suggested := run.recommended_target()
		var active: bool = not suggested.is_empty() and suggested.id==target.id
		word_plate(target,p,active)
		if active:
			draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-38),p+Vector2(6,-38),p+Vector2(0,-29)]),PlayTheme.PRIMARY)
		if run.mode != "racing":
			var fraction: float = clampf(target.remaining/target.duration,0,1)
			panel(Rect2(p+Vector2(-42,20),Vector2(84,4)),Color("d4e3ee"),2)
			panel(Rect2(p+Vector2(-42,20),Vector2(84*fraction,4)),CORAL if fraction<0.25 else MINT,2)
		var feature: String = target.get("feature","")
		if not feature.is_empty():
			var badge: Vector2 = target.position+Vector2(0,52 if run.mode=="aliens" else 63)
			var color: Color = MINT if feature=="supply" else CORAL if feature=="scout" else PlayTheme.ORANGE
			panel(Rect2(badge-Vector2(54,18),Vector2(108,25)),Color(1,1,1,0.94),10)
			write({"supply":"补给 +8 盾","scout":"快速侦察舰","bonus":"奖励 +40 分"}[feature],badge,13,color,true)
	panel(Rect2(24,588,992,43),Color(1,1,1,0.96),14)
	var notes := {"balloons":"输入击破气球 · 越靠近顶部，越需要优先处理", "aliens":"输入发射激光 · 每三连击补充护盾 · 拦截俯冲外星舰", "moles":"输入举牌文字敲击地鼠 · 训练中漏掉不会扣体力", "racing":"完整输入推进赛程 · 三连击氮气加速 · 挑战需先于对手冲线", "fighter":"在蓄力条耗尽前输入 · 重拳打断攻击 · 四次命中击倒一位对手"}
	write(notes[run.mode],Vector2(44,615),16,Color("455d75"))

func draw_atmosphere() -> void:
	if reduced_motion:
		return
	for i in range(16):
		var p := Vector2(fposmod(i*193.0-clock*(18 if run.mode=="aliens" else 5),1040),110+fposmod(i*113.0+sin(clock+i)*8,440))
		if run.mode=="racing":
			var y := 350.0 if i%2==0 else 505.0
			var x := fposmod(i*139.0-clock*(320 if run.boost>0 and run.combo>=3 else 90),1040)
			draw_line(Vector2(x,y),Vector2(x+32,y),Color(1,1,1,0.36),2,true)
		else:
			draw_circle(p,1.5+i%3,Color(1,0.96,0.7,0.24+sin(clock*2+i)*0.12))

func draw_skill_field() -> void:
	if run.mode=="fighter" and run.guard_ready:
		var alpha := 0.6 if reduced_motion else 0.5+sin(clock*3)*0.1
		draw_arc(Vector2(350,430),80,-PI/2,PI/2,40,Color(0.4,0.85,1,alpha),5,true)
		panel(Rect2(250,275,196,33),Color(0.92,0.98,1,0.94),12)
		write("格挡已准备 · 抵挡一次反击",Vector2(348,297),13,BLUE,true)
	elif run.skill_time>0 and run.mode in ["moles","balloons"]:
		for target in run.targets:
			var p: Vector2 = target.position
			var radius := 63.0 if reduced_motion else 63+sin(clock*3)*5
			draw_arc(p,radius,0,TAU,48,Color(0.3,0.76,0.85,0.55),2,true)
			if not reduced_motion:
				for i in range(3):
					var angle := clock*1.3+i*TAU/3
					draw_circle(p+Vector2.from_angle(angle)*radius,3,Color("c6f4ed"))
	elif run.mode=="racing" and run.skill_time>3:
		var point := Vector2(120+run.rival*770,510)
		draw_arc(point,65,0,TAU,40,Color(0.4,0.8,1,run.skill_time-3),3,true)
		panel(Rect2(point+Vector2(-66,50),Vector2(132,29)),Color.WHITE,10)
		write("干扰成功 -8%",point+Vector2(0,70),15,BLUE,true)

func sprite_pose(id: String, center: Vector2, bounds: Vector2, angle: float, stretch: Vector2) -> void:
	draw_set_transform(center,angle,stretch)
	art.draw_sprite(self,id,Vector2.ZERO,bounds)
	draw_set_transform(Vector2.ZERO)

func banner(title: String, subtitle: String) -> void:
	panel(Rect2(20,18,570,48),Color(1,1,1,0.94),16)
	draw_circle(Vector2(40,42),5,MINT)
	write(title,Vector2(54,49),21,INK)
	write(subtitle,Vector2(227,48),14,PlayTheme.MUTED)
	panel(Rect2(770,18,248,48),Color(1,1,1,0.94),16)
	var streak := run.combo%3
	for i in range(3):
		draw_circle(Vector2(795+i*19,42),5,MINT if i<streak or (run.combo>0 and streak==0) else Color("dbe7ee"))
	write("连击 %d" % run.combo,Vector2(854,49),17,MINT)
	if run.combo>=3 and not reduced_motion:
		draw_arc(Vector2(1000,42),8,-PI/2,-PI/2+TAU*minf(1,strike*2),20,PlayTheme.ORANGE,2,true)

func motion_sprite(state: String, seconds: float, center: Vector2, bounds: Vector2, tint := Color.WHITE) -> bool:
	var texture := motion.texture(state,seconds,reduced_motion)
	if texture==null:
		return false
	draw_texture_rect(texture,Rect2(center-bounds/2,bounds),false,tint)
	return true

func draw_generated_game() -> void:
	var titles := {"balloons":"风起气球节","aliens":"星港防卫线","moles":"地鼠的午后","racing":"键盘拉力赛","fighter":"指尖格斗馆"}
	banner(titles[run.mode],run.status_text())
	if run.mode == "moles":
		for i in range(6):
			var hole := Vector2(240+(i%3)*280,326+(i/3)*170)
			draw_set_transform(hole,0,Vector2(1,0.32))
			draw_circle(Vector2.ZERO,61,Color("ad8756"))
			draw_circle(Vector2.ZERO,52,Color("574839"))
			draw_set_transform(Vector2.ZERO)
	for target in run.targets:
		var p: Vector2 = target.position
		var bob := 0.0 if reduced_motion else sin(clock*2+target.id)*5
		match run.mode:
			"balloons":
				var sway := 0.0 if reduced_motion else sin(clock*2+target.id)*0.065
				sprite_pose(["balloon_coral","balloon_blue","balloon_gold"][target.lane%3],p+Vector2(bob,22),Vector2(117,155),sway,Vector2(1+sway,1-sway))
			"aliens":
				var reacting := reaction_echoes.any(func(e): return e.point.distance_to(p)<65 and e.age<0.65)
				if not reacting and not motion_sprite("idle",pose_clock+target.id*0.37,p+Vector2(0,bob),Vector2(190,190)):
					sprite_pose("ufo",p+Vector2(0,bob),Vector2(125,90),0,Vector2.ONE)
				draw_circle(p+Vector2(0,27),18+sin(clock*7)*4,Color(0.5,0.8,1,0.13))
			"moles":
				var emergence: float = 1.0 if reduced_motion else minf(clampf((target.duration-target.remaining)/0.24,0.12,1),clampf(target.remaining/0.25,0.12,1))
				var reveal := Vector2(0,36-43*emergence)
				var reacting := reaction_echoes.any(func(e): return e.point.distance_to(p)<65 and e.age<0.65)
				if not reacting and not motion_sprite("idle",pose_clock+target.id*0.41,p+reveal,Vector2(182,182*emergence)):
					sprite_pose("mole",p+reveal,Vector2(113,107),0,Vector2(1.05,emergence))
	var drawn_points: Array[Vector2] = []
	for index in range(reaction_echoes.size()-1,-1,-1):
		var echo: Dictionary = reaction_echoes[index]
		if drawn_points.any(func(p): return p.distance_to(echo.point)<65):
			continue
		drawn_points.append(echo.point)
		var alpha := 1.0-clampf((echo.age-0.28)/0.5,0,1)
		var bounds := Vector2(182,182) if echo.kind=="moles" else Vector2(190,190)
		var point: Vector2 = echo.point+Vector2(0,-7) if echo.kind=="moles" else echo.point
		motion_sprite("hit",echo.age,point,bounds,Color(1,1,1,alpha))
		if echo.kind=="moles" and not reduced_motion:
			for i in range(3):
				var angle: float = echo.age*7+i*TAU/3
				var star := point+Vector2(cos(angle)*35,-42+sin(angle)*7)
				draw_line(star-Vector2(4,0),star+Vector2(4,0),Color(1,0.8,0.3,alpha),2,true)
				draw_line(star-Vector2(0,4),star+Vector2(0,4),Color(1,0.8,0.3,alpha),2,true)
	if run.mode == "aliens":
		sprite_pose("ship",Vector2(520,518+ (0.0 if reduced_motion else sin(clock*3)*4)),Vector2(137,122),0.0 if reduced_motion else sin(clock*2)*0.035,Vector2.ONE)
		if run.shield>0:
			draw_arc(Vector2(520,518),84,PI,TAU,48,Color(0.65,0.93,1,0.8),3,true)
		if shield_pulse>0:
			var pulse := 1-shield_pulse/0.65
			draw_arc(Vector2(520,518),84+(0 if reduced_motion else pulse*30),PI,TAU,48,Color(0.45,0.9,1,1-pulse),4,true)
		if charge_flash>0:
			draw_circle(Vector2(520,471),8+charge_flash*45,Color(0.8,0.95,1,charge_flash*2))
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
		if run.boost>0 and run.combo>=3:
			art.draw_sprite(self,"impact",player-Vector2(65,0),Vector2(96,62))
		var state := "boost" if nitro_age>=0 and nitro_age<motion.duration("boost") else "idle"
		if not motion_sprite(state,nitro_age if state=="boost" else pose_clock,player,Vector2(205,205)):
			sprite_pose("car_mint",player,Vector2(136,88),0,Vector2.ONE)
		sprite_pose("car_coral",rival,Vector2(136,88),0.0 if reduced_motion else sin(clock*13)*0.012,Vector2.ONE)
		panel(Rect2(player-Vector2(52,71),Vector2(104,29)),Color.WHITE,9)
		write("你  %d%%" % roundi(run.distance*100),player-Vector2(33,50),17,MINT)
		panel(Rect2(rival-Vector2(52,71),Vector2(104,29)),Color.WHITE,9)
		write("陪练车" if run.context=="training" else "对手",rival-Vector2(29,50),17,CORAL)
		panel(Rect2(330,204,380,44),Color(1,1,1,0.95),12)
		write("三连击 · 氮气加速" if run.boost>0 and run.combo>=3 else "连续输入为赛车充能",Vector2(520,234),22,GOLD,true)
	elif run.mode == "fighter":
		var punch := 0.0 if reduced_motion else sin(clampf(strike/0.5,0,1)*PI)
		var left := Vector2(350,440)+Vector2(punch*(0 if last_impact=="block" else -16 if last_impact=="miss" else 55),0)
		var right := Vector2(690,440)+Vector2(punch*(-55 if last_impact in ["miss","block"] else 16),0)
		draw_ellipse_shadow(Vector2(350,560),Vector2(67,16))
		draw_ellipse_shadow(Vector2(690,560),Vector2(67,16))
		draw_texture_rect(BoxingMotion.texture(0,clock,blue_attack_age,reduced_motion),Rect2(left-Vector2(134,180),Vector2(340,340)),false)
		draw_texture_rect(BoxingMotion.texture(1,clock,coral_attack_age,reduced_motion),Rect2(right-Vector2(160,175),Vector2(320,320)),false)
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
			draw_line(Vector2(520,478),p,Color(1,1,1,(1-t)*0.9),2,true)
			draw_circle(Vector2(520,478),25*(1-t),Color(0.6,0.9,1,(1-t)*0.3))
		elif burst.kind=="miss" and run.mode=="aliens":
			draw_line(p,Vector2(520,518),Color(1,0.5,0.45,1-t),5,true)
		if burst.kind=="moles":
			var hammer := p+Vector2(35,-50-25*t)
			sprite_pose("mallet",hammer,Vector2(110,110),-0.7+sin(t*PI)*0.85,Vector2.ONE)
		if burst.kind=="balloons":
			# Short curled ribbons sell the pop without a full-screen flash.
			for i in range(6):
				var angle := i*TAU/6+0.2
				var tip := p+Vector2.from_angle(angle)*(18+70*t)
				draw_arc(tip,6+8*t,angle,angle+PI*1.2,12,Color([PlayTheme.CORAL,PlayTheme.SKY,PlayTheme.YELLOW][i%3],1-t),2,true)
		if burst.kind=="racing":
			for i in range(3):
				var trail_at := Vector2(90+run.distance*770-i*23,356)
				draw_line(trail_at-Vector2(35,12+i*3),trail_at+Vector2(4,-8+i*3),Color(0.45,0.86,1,(1-t)*0.6),3,true)
		if burst.kind=="fighter":
			art.draw_sprite(self,"impact",p,Vector2(160,130)*(1-t),Color(1,1,1,1-t))
		var radius := 100 if burst.power>0 and burst.power%5==0 else 65
		draw_arc(p,12+t*radius,0,TAU,32,Color(color,1-t),3*(1-t)+1,true)
		for i in range(12):
			var direction := Vector2.from_angle(i*TAU/12)
			var end := p+direction*(16+90*t)+Vector2(0,t*t*35)
			draw_line(end,end-direction*9,Color(color,1-t),3,true)
	var caption := "格挡！" if burst.kind=="block" else "漏过" if burst.kind=="miss" else ("重击！" if burst.kind=="fighter" else "推进！" if burst.kind=="racing" else "+ 命中")
	var caption_at := p+Vector2(0,-15-(0 if reduced_motion else t*42))
	if burst.kind=="aliens":
		caption_at = p+Vector2(0,100-t*12)
	elif burst.kind=="moles":
		caption_at = p+Vector2(79,-5-t*22)
	panel(Rect2(caption_at-Vector2(54,25),Vector2(108,35)),Color(1,1,1,(1-t)*0.92),12)
	write(caption,caption_at,23,Color(PlayTheme.ORANGE if burst.kind!="miss" else Color("b13b4e"),1-t),true)
