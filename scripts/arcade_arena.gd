class_name ArcadeArena
extends GameArena

var bursts: Array[Dictionary] = []
var strike := 0.0
var last_impact := ""
var blue_attack_age := -1.0
var coral_attack_age := -1.0
var blue_reaction_age := -1.0
var coral_reaction_age := -1.0
var blue_start_approach := 0.0
var enemy_lean := 0.0
var knockout_age := -1.0
var seen_knockouts := 0
var combat_contact_count := 0
var trail_clock := 0.0
var motion := ArcadeMotion.new()
var rival_motion := ArcadeMotion.new()
var boxing_clips: Array[SpriteFrames] = []
var reaction_echoes: Array[Dictionary] = []
var nitro_age := -1.0
var shield_pulse := 0.0
var impact_freeze := 0.0
var pose_clock := 0.0
var previous_correct := 0
var charge_flash := 0.0
var checkpoint_age := 0.0
var checkpoint_label := ""
var visual_distance := 0.0
var visual_rival := 0.0
var visual_enemy_hp := 100.0
var visual_player_hp := 100.0
var approach := 0.0
var pop_reactions: Array[Dictionary] = []
var pop_motion := ArcadeMotion.new()
const MOLE_HOLE = preload("res://assets/mole-hole-v11.svg")
const MOLE_RIM = preload("res://assets/mole-rim-v11.svg")
const CORAL := Color("e96b70")
const BLUE := Color("448fce")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	art.setup(run.mode)
	setup_backdrop(art.background)
	motion.setup(run.mode)
	if run.mode=="racing": rival_motion.setup("racing_rival")
	if run.mode=="balloons": pop_motion.setup("balloon_pop")
	if run.mode=="fighter":
		boxing_clips = BoxingMotion.load_clips()
		run.punch_started.connect(on_punch_started)
	juice.reduced_motion = reduced_motion
	run.impact.connect(on_impact)
	run.key_feedback.connect(on_key_feedback)

func on_impact(kind: String, point: Vector2, power: int) -> void:
	var knockout_event := false
	if kind=="skill":
		if run.mode=="racing":
			nitro_age=0.0
			return
		shield_pulse = 0.65
		var location := Vector2(350,410) if run.mode=="fighter" else track_point(visual_distance,0)-Vector2(65,0) if run.mode=="racing" else Vector2(520,480)
		record_impact(location,3)
		juice.burst(location,Color("8ae3eb"),2,"spark")
		return
	if kind in ["moles","aliens"]:
		reaction_echoes.append({"point":point,"age":0.0,"kind":kind})
		if reaction_echoes.size()>8:
			reaction_echoes.pop_front()
	if kind=="racing":
		nitro_age = 0.0
		return
	elif kind=="balloons" and not reduced_motion:
		juice.burst(point,PlayTheme.CORAL,3,"petal")
		juice.burst(point,PlayTheme.YELLOW,2,"confetti")
		pop_reactions.append({"point":point,"age":0.0,"sprite":["balloon_coral","balloon_blue","balloon_gold"][clampi(roundi((point.x-200)/320),0,2)]})
		if pop_reactions.size()>8:
			pop_reactions.pop_front()
	if kind==run.mode and run.context=="training" and run.kills>0 and run.kills%6==0 and run.kills<run.goal:
		checkpoint_age = 1.6
		checkpoint_label = "阶段完成 · 技能充满"
		juice.burst(Vector2(520,100),PlayTheme.YELLOW,1,"confetti")
	if kind=="aliens" and power%3==0:
		shield_pulse = 0.65
	if run.mode=="fighter":
		point = Vector2(392,390) if kind in ["miss","block"] else Vector2(662,390)
		combat_contact_count += 1
		if kind in ["miss","block"]:
			coral_attack_age = maxf(coral_attack_age,ArcadeRun.PUNCH_CONTACT)
			blue_reaction_age = 0.0
		else:
			blue_attack_age = maxf(blue_attack_age,ArcadeRun.PUNCH_CONTACT)
			coral_reaction_age = 0.0
			coral_attack_age = -1.0
		if seen_knockouts!=run.knockout_serial:
			seen_knockouts = run.knockout_serial
			knockout_age = 0.0
			knockout_event = true
	var tier := 3 if knockout_event else GameFeel.tier(power if kind==run.mode else 0,kind in ["fighter","moles","miss","block"])
	impact_freeze = 0.0 if reduced_motion or tier==1 else .04 if tier==2 else .065
	record_impact(point,tier,CORAL if kind=="miss" else BLUE if kind=="block" else PlayTheme.YELLOW)
	bursts.append({"kind":kind,"point":point,"power":power,"life":0.7})
	if bursts.size()>18:
		bursts.pop_front()
	var color: Color = {"aliens":Color("88eaff"),"balloons":Color("ffcb72"),"moles":Color("d5b079"),"fighter":Color("ffd574"),"miss":CORAL}.get(kind,Color("a1e8c1"))
	juice.burst(point,color,tier,"soil" if kind=="moles" else "petal" if kind=="balloons" else "speed" if kind=="racing" else "spark")
	if kind in ["fighter","aliens","racing"]:
		juice.jet(point,Vector2.RIGHT if kind=="fighter" else Vector2.LEFT if kind=="racing" else Vector2.UP,color,tier)
	strike = 0.5
	last_impact = kind

func on_punch_started(attack: Dictionary) -> void:
	if attack.side==0:
		blue_start_approach = approach
		blue_attack_age = 0.0
		blue_reaction_age = -1.0
		if knockout_age>=0 and knockout_age<.55: knockout_age=.55
	else:
		coral_attack_age = 0.0
		coral_reaction_age = -1.0
	queue_redraw()

# Feet move through a short eased step before contact and settle afterward.
# The word layer never inherits this transform.
func punch_step(age: float, start := 0.0, reach := 128.0) -> float:
	if reduced_motion or age<0: return 0.0
	if age<ArcadeRun.PUNCH_CONTACT:
		return lerpf(start,reach,smoothstep(0.0,ArcadeRun.PUNCH_CONTACT,age))
	return lerpf(reach,0.0,smoothstep(ArcadeRun.PUNCH_CONTACT,ArcadeRun.PUNCH_CONTACT+.28,age))

func visual_reaction_delta(delta: float) -> float:
	return delta if reduced_motion else GameFeel.pose_step(delta,impact_freeze)

func _process(delta: float) -> void:
	if run != null and not run.paused:
		clock += delta
		step_feedback(delta)
		var follow := 1-exp(-delta*12)
		if run.mode=="fighter":
			var target := run.recommended_target()
			var preparation := float(target.get("typed",0))/maxi(1,str(target.get("word","")).length())
			approach = 0.0 if reduced_motion else lerpf(approach,preparation*44,follow)
			var intent: String = target.get("intent","")
			enemy_lean = lerpf(enemy_lean,14.0 if intent=="windup" else -10.0 if intent=="exposed" else 0.0,follow)
			if blue_reaction_age>=0: blue_reaction_age += visual_reaction_delta(delta)
			if coral_reaction_age>=0: coral_reaction_age += visual_reaction_delta(delta)
			if knockout_age>=0: knockout_age += delta
		visual_distance = lerpf(visual_distance,run.distance,follow)
		visual_rival = lerpf(visual_rival,run.rival,follow)
		visual_enemy_hp = lerpf(visual_enemy_hp,run.enemy_hp,1-exp(-delta*4))
		visual_player_hp = lerpf(visual_player_hp,run.hp,1-exp(-delta*4))
		# Freeze only the character pose for an impact beat; input, timers and FX continue.
		var visual_delta := delta if reduced_motion else GameFeel.pose_step(delta,impact_freeze)
		impact_freeze = maxf(0,impact_freeze-delta)
		pose_clock += visual_delta
		shield_pulse = maxf(0,shield_pulse-delta)
		charge_flash = maxf(0,charge_flash-delta)
		checkpoint_age = maxf(0,checkpoint_age-delta)
		if previous_correct!=run.correct:
			charge_flash = 0.18
			previous_correct = run.correct
		if nitro_age>=0:
			nitro_age += delta
		for echo in reaction_echoes.duplicate():
			echo.age += visual_delta
			if echo.age>=maxf(0.6,motion.duration("hit")):
				reaction_echoes.erase(echo)
		for remnant in pop_reactions.duplicate():
			remnant.age += delta
			if remnant.age>=1.0:
				pop_reactions.erase(remnant)
		juice.step(delta)
		if blue_attack_age>=0:
			blue_attack_age += visual_delta
		if coral_attack_age>=0:
			coral_attack_age += visual_delta
		trail_clock -= delta
		if trail_clock<=0:
			trail_clock = 0.05
			if run.mode=="aliens":
				juice.trail(Vector2(520+sin(clock*3)*7,560),Vector2(0,65),Color("7ae2ff"),8)
			# Racing exhaust belongs to the engine's bounded emitters, not circles
			# stamped into the scene every frame.
		strike = maxf(0,strike-visual_delta)
		for burst in bursts.duplicate():
			burst.life -= delta
			if burst.life <= 0:
				bursts.erase(burst)
	queue_redraw()

func _draw() -> void:
	if run == null:
		return
	var backgrounds := {"balloons":Color("e9f7ff"),"aliens":Color("eef0ff"),"moles":Color("e9f5d9"),"racing":Color("eef7fe"),"fighter":Color("f5edff")}
	draw_scene_background()
	prepare_prompts()
	draw_atmosphere()
	world_offset = feel.offset()
	draw_set_transform(world_offset)
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
	draw_enemy_intentions()
	draw_anticipation()
	for burst in bursts:
		draw_burst(burst)
	juice.draw(self)
	draw_impact()
	world_offset = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	# Words remain above all action feedback.
	draw_target_labels()

func prepare_prompts() -> void:
	var prompts: Array[Dictionary] = []
	var actors: Array[Rect2] = []
	var blocked: Array[Rect2] = []
	if run.mode in ["aliens","fighter"]:
		blocked.append(Rect2(20,18,220,48))
	if run.mode=="fighter":
		actors.assign([Rect2(240,270,240,300),Rect2(575,270,245,300)])
		blocked.append(Rect2(20,20,1000,110))
		blocked.append(Rect2(220,198,250,44))
	elif run.mode=="racing":
		actors.assign([Rect2(track_point(visual_distance,0)-Vector2(90,58),Vector2(180,116)),Rect2(track_point(visual_rival,1)-Vector2(90,58),Vector2(180,116))])
	for target in run.targets:
		var p: Vector2 = target.position
		var center := p
		var source := p
		if run.mode=="balloons":
			center -= Vector2(0,103)
			source -= Vector2(0,43)
			actors.append(Rect2(p-Vector2(57,50),Vector2(114,138)))
		elif run.mode=="aliens":
			center -= Vector2(0,92)
			source -= Vector2(0,28)
			actors.append(Rect2(p-Vector2(72,42),Vector2(144,92)))
		elif run.mode=="moles":
			center -= Vector2(0,110)
			source -= Vector2(0,40)
			actors.append(Rect2(p-Vector2(61,65),Vector2(122,102)))
			actors.append(Rect2(p+Vector2(45,-124),Vector2(96,105)))
		elif run.mode=="fighter":
			center = Vector2(700,219)
			source = Vector2(690,320)
		prompts.append({"target":target,"center":center,"source":source})
	layout_labels(prompts,actors,blocked)

func draw_enemy_intentions() -> void:
	# Only imminent actions receive a short, local cue. No rings or tracking arrows.
	for target in run.targets:
		if target.get("intent","")=="windup" and run.mode=="fighter":
			TypingPrompt.glyph(self,"!",Vector2(773,310),42,CORAL,.2)

func draw_anticipation() -> void:
	var target := run.recommended_target()
	if target.is_empty(): return
	var fraction := float(target.typed)/maxi(1,str(target.word).length())
	if run.mode=="moles" and fraction>0:
		if not reaction_echoes.any(func(e): return e.point.distance_to(target.position)<65 and e.age<.22):
			sprite_pose("mallet",target.position+Vector2(73,-80-fraction*14),Vector2(90,90),-.65-fraction*.4,Vector2.ONE)

func draw_mole(texture: Texture2D, point: Vector2, emergence: float, tint := Color.WHITE) -> void:
	if texture==null:
		return
	# Reveal the character through the hole without scaling its anatomy flat.
	var full := Rect2(point-Vector2(91,98)+Vector2(0,(1-emergence)*95),Vector2(182,182))
	var height := clampf(point.y+27-full.position.y,0,182)
	if height>0:
		draw_texture_rect_region(texture,Rect2(full.position,Vector2(182,height)),Rect2(0,0,texture.get_width(),texture.get_height()*height/182),tint)
	draw_texture_rect(MOLE_RIM,Rect2(point+Vector2(-80,27),Vector2(160,34)),false)
	draw_set_transform(world_offset)

func draw_atmosphere() -> void:
	if reduced_motion or run.mode=="racing":
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
	if run.skill_time>0 and run.mode in ["moles","balloons"]:
		for target in run.targets:
			var p: Vector2 = target.position
			var radius := 63.0 if reduced_motion else 63+sin(clock*3)*5
			draw_arc(p,radius,0,TAU,48,Color(0.3,0.76,0.85,0.55),2,true)
			if not reduced_motion:
				for i in range(3):
					var angle := clock*1.3+i*TAU/3
					draw_circle(p+Vector2.from_angle(angle)*radius,3,Color("c6f4ed"))

func sprite_pose(id: String, center: Vector2, bounds: Vector2, angle: float, stretch: Vector2) -> void:
	draw_set_transform(center+world_offset,angle,stretch)
	art.draw_sprite(self,id,Vector2.ZERO,bounds)
	draw_set_transform(world_offset)

func track_point(fraction: float, lane: int) -> Vector2:
	# Use exactly the TextureRect's cover crop, including the wider scenery parent.
	var source:=art.background.get_size()
	var factor:=maxf(backdrop.size.x/source.x,backdrop.size.y/source.y)
	var crop_offset: Vector2=(backdrop.size-source*factor)*.5
	var uv:=Vector2(.22+.54*fraction,.545 if lane==0 else .781)
	var global_point: Vector2=backdrop.get_global_transform()*(crop_offset+source*uv*factor)
	return get_global_transform().affine_inverse()*global_point

func banner(title: String, _subtitle: String) -> void:
	GameHudSkin.caption(self,title,Rect2(20,18,220,48),24,0)

func motion_sprite(state: String, seconds: float, center: Vector2, bounds: Vector2, tint := Color.WHITE, angle := 0.0, stretch := Vector2.ONE) -> bool:
	var texture := motion.texture(state,seconds,reduced_motion)
	if texture==null:
		return false
	draw_set_transform(center+world_offset,angle,stretch)
	draw_texture_rect(texture,Rect2(-bounds/2,bounds),false,tint)
	draw_set_transform(world_offset)
	return true

func draw_generated_game() -> void:
	if run.mode=="aliens":
		banner("第 %d 阵" % mini(run.wave,4), "")
	elif run.mode=="fighter":
		var intent := EnemyTactics.caption(run.recommended_target())
	if run.mode == "moles":
		for i in range(6):
			var hole := Vector2(240+(i%3)*280,326+(i/3)*170)
			draw_texture_rect(MOLE_HOLE,Rect2(hole-Vector2(80,34),Vector2(160,68)),false)
	for target in run.targets:
		var p: Vector2 = target.position
		var bob := 0.0 if reduced_motion else sin(clock*2+target.id)*5
		match run.mode:
			"balloons":
				var sway := 0.0 if reduced_motion else sin(clock*2+target.id)*0.065
				var inflate := 0.0 if reduced_motion else float(target.typed)/str(target.word).length()*.13
				sprite_pose(["balloon_coral","balloon_blue","balloon_gold"][target.lane%3],p+Vector2(bob,22),Vector2(117,155)*(1+inflate),sway,Vector2(1+sway,1-sway))
			"aliens":
				if not motion_sprite("idle",pose_clock+target.id*0.37,p+Vector2(0,bob),Vector2(190,190)):
					sprite_pose("ufo",p+Vector2(0,bob),Vector2(125,90),0,Vector2.ONE)
			"moles":
				var emergence: float = 1.0 if reduced_motion else minf(clampf((target.duration-target.remaining)/0.24,0.12,1),clampf(target.remaining/0.25,0.12,1))
				var reacting := reaction_echoes.any(func(e): return e.point.distance_to(p)<65 and e.age<0.65)
				if not reacting:
					draw_mole(motion.texture("idle",pose_clock+target.id*.41,reduced_motion),p,emergence)
	for remnant in pop_reactions:
		var frame := pop_motion.texture("idle",remnant.age,reduced_motion)
		if frame!=null:
			draw_texture_rect(frame,Rect2(remnant.point-Vector2(155,145),Vector2(310,310)),false)
	var drawn_points: Array[Vector2] = []
	for index in range(reaction_echoes.size()-1,-1,-1):
		var echo: Dictionary = reaction_echoes[index]
		if drawn_points.any(func(p): return p.distance_to(echo.point)<65):
			continue
		drawn_points.append(echo.point)
		var alpha := 1.0-clampf((echo.age-0.28)/0.5,0,1)
		var bounds := Vector2(182,182) if echo.kind=="moles" else Vector2(190,190)
		var point: Vector2 = echo.point+Vector2(0,-7) if echo.kind=="moles" else echo.point+Vector2(35,38+echo.age*100)
		if echo.kind=="moles":
			draw_mole(motion.texture("hit",echo.age,reduced_motion),echo.point,1-clampf((echo.age-.25)/.5,0,1),Color(1,1,1,alpha))
		else:
			motion_sprite("hit",echo.age,point,bounds,Color(1,1,1,alpha),0.0 if reduced_motion else echo.age*.5)
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
		GameHudSkin.panel(self,Rect2(26,499,215,64),1)
		GameHudSkin.text(self,"护盾 %d / 60"%run.shield,Rect2(42,507,180,27),20,Color("bfefff"))
		panel(Rect2(40,540,185,9),Color("d3e6f3"),4)
		panel(Rect2(40,540,185*run.shield/60.0,9),BLUE,4)
	elif run.mode == "racing":
		var suspension := 0.0 if reduced_motion else sin(clampf(impact_age/.3,0,1)*PI)
		var player := track_point(visual_distance,0)-Vector2(0,suspension*3)
		var rival := track_point(visual_rival,1)
		for lane in range(2):
			var finish:=track_point(1.0,lane)
			for row in range(8):
				for col in range(2):
					draw_rect(Rect2(finish+Vector2(col*11-11,row*12-48),Vector2(11,12)),Color("fff6dc") if (row+col)%2==0 else Color("294453"))
			for end in [-1,1]:
				draw_line(finish+Vector2(-14,end*51),finish+Vector2(14,end*51),Color("d69d45"),5,true)
		var state := "boost" if nitro_age>=0 and nitro_age<motion.duration("boost") else "idle"
		if not motion_sprite(state,nitro_age if state=="boost" else pose_clock,player,Vector2(256,256),Color.WHITE,-suspension*.025,Vector2(1+suspension*.025,1-suspension*.02)):
			sprite_pose("car_mint",player,Vector2(136,88),0,Vector2.ONE)
		var rival_texture:=rival_motion.texture("idle",pose_clock+.7,reduced_motion)
		if rival_texture!=null:
			draw_texture_rect(rival_texture,Rect2(rival-Vector2(128,128),Vector2(256,256)),false)
		else: sprite_pose("car_coral",rival,Vector2(160,106),0,Vector2.ONE)
		GameHudSkin.caption(self,"你",Rect2(player-Vector2(34,91),Vector2(68,30)),20,1)
		GameHudSkin.caption(self,"陪练" if run.context=="training" else "对手",Rect2(rival-Vector2(42,91),Vector2(84,30)),20,1)

	elif run.mode == "fighter":
		var recoil_left := 0.0 if reduced_motion or blue_reaction_age<0 else sin(clampf(blue_reaction_age/.28,0,1)*PI)*18
		var recoil_right := 0.0 if reduced_motion or coral_reaction_age<0 else sin(clampf(coral_reaction_age/.28,0,1)*PI)*22
		var blue_active := blue_attack_age>=0 and blue_attack_age<.5
		var coral_active := coral_attack_age>=0 and coral_attack_age<.5
		var left := Vector2(350+(punch_step(blue_attack_age,blue_start_approach) if blue_active else approach)-recoil_left,440)
		var right := Vector2(690+enemy_lean-(punch_step(coral_attack_age,0,152) if coral_active else 0.0)+recoil_right,440)
		draw_ellipse_shadow(Vector2(left.x,560),Vector2(67,16))
		draw_ellipse_shadow(Vector2(right.x,560),Vector2(67,16))
		var blocking: bool = run.guard_ready or (last_impact=="block" and blue_reaction_age>=0 and blue_reaction_age<.38)
		draw_texture_rect(BoxingMotion.texture(0,pose_clock,blue_attack_age,reduced_motion,boxing_clips,blue_reaction_age if last_impact!="block" else -1.0,blocking),Rect2(left-Vector2(134,180),Vector2(340,340)),false)
		var opponent_alpha := 1.0
		if not reduced_motion and knockout_age>=0 and knockout_age<.75:
			opponent_alpha = 1.0-smoothstep(.08,.42,knockout_age) if knockout_age<.55 else smoothstep(.55,.75,knockout_age)
		draw_texture_rect(BoxingMotion.texture(1,pose_clock,coral_attack_age,reduced_motion,boxing_clips,coral_reaction_age),Rect2(right-Vector2(160,175),Vector2(320,320)),false,Color(1,1,1,opponent_alpha))
		if knockout_age>=0 and knockout_age<.65:
			GameHudSkin.caption(self,"击倒！",Rect2(440,120,160,64),40,0)
		for side in range(2):
			var x := 50+side*560
			var health: int = run.hp if side==0 else run.enemy_hp
			if side==1 and knockout_age>=0 and knockout_age<.75:
				health=roundi(health*smoothstep(.55,.75,knockout_age))
			FightMeter.paint(self,Rect2(x,35,380,34),health,visual_player_hp if side==0 else 0.0 if knockout_age>=0 and knockout_age<.75 else visual_enemy_hp,side)
			GameHudSkin.caption(self,"蓝拳 · 你" if side==0 else "红拳 · 对手",Rect2(x,75,160,34),20,1)
			GameHudSkin.caption(self,str(health),Rect2(x+304,75,76,34),22,1)
		GameHudSkin.caption(self,"VS",Rect2(473,27,94,65),32,0)
		if run.combo>1 or (strike>0 and run.last_tactic=="counter"):
			GameHudSkin.caption(self,"破招！双倍重拳" if strike>0 and run.last_tactic=="counter" else "%d 连击"%run.combo,Rect2(220,198,250,44),25,0)

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
	GameHudSkin.caption(self,"护盾 %d / 60"%run.shield,Rect2(24,499,220,44),22,1)

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
	GameHudSkin.caption(self,"你",Rect2(player-Vector2(34,85),Vector2(68,32)),20,1)
	GameHudSkin.caption(self,"陪练" if run.context=="training" else "对手",Rect2(rival-Vector2(42,85),Vector2(84,32)),20,1)

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
	banner("指尖格斗馆", "第 %d 位对手" % run.round_number)
	for i in range(14):
		var p := Vector2(65+i*72,250+(i%2)*15)
		draw_circle(p,15,Color("e7b7bd"))
		panel(Rect2(p+Vector2(-20,19),Vector2(40,56)),Color("c4b0de"),12)
	draw_colored_polygon(PackedVector2Array([Vector2(105,350),Vector2(900,350),Vector2(1000,566),Vector2(38,566)]),Color("d3c8f0"))
	for y in [345,400,455]:
		draw_line(Vector2(80,y),Vector2(950,y),Color("ffffff"),4,true)
	for x in [80,950]:
		draw_line(Vector2(x,325),Vector2(x,555),CORAL,12,true)
	var punch := 0.0 if reduced_motion else GameFeel.kick(.5-strike,.34)
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
	GameHudSkin.caption(self,"你 · %d"%run.hp,Rect2(65,125,200,38),22,1)
	GameHudSkin.caption(self,"对手 · %d"%run.enemy_hp,Rect2(625,125,200,38),22,1)
	if run.combo>1:
		GameHudSkin.caption(self,"%d 连击"%run.combo,Rect2(220,198,250,44),25,0)

func draw_burst(burst: Dictionary) -> void:
	if burst.kind=="racing": return
	var t: float = 1-burst.life/0.7
	var p: Vector2 = burst.point
	var color: Color = CORAL if burst.kind=="miss" else PlayTheme.YELLOW
	if run.mode=="fighter":
		# Native contact particles already sell the hit. A second giant star and
		# a floating pale caption used to hide both the glove and the reaction.
		if burst.kind=="block" and t<.6:
			GameHudSkin.caption(self,"格挡！",Rect2(248,200,150,48),28,1)
		return
	if burst.kind=="fighter":
		p = Vector2(650,400)
	elif burst.kind=="miss" and run.mode=="fighter":
		p = Vector2(390,400)
	if not reduced_motion:
		if burst.kind=="aliens":
			SoftStroke.line(self,Vector2(520,478),p,Color(0.5,0.85,1,(1-t)*.22),12*(1-t)+1)
			SoftStroke.line(self,Vector2(520,478),p,Color(1,1,1,(1-t)*.9),2.5)
			draw_circle(Vector2(520,478),25*(1-t),Color(0.6,0.9,1,(1-t)*0.3))
		elif burst.kind=="miss" and run.mode=="aliens":
			draw_line(p,Vector2(520,518),Color(1,0.5,0.45,1-t),5,true)
		if burst.kind=="moles":
			var swing := sin(minf(1,t*4)*PI/2)
			var hammer := p+Vector2(70-swing*25,-90+swing*52-25*maxf(0,t-.3))
			sprite_pose("mallet",hammer,Vector2(110,110),-1.1+swing*1.2,Vector2.ONE)
		if burst.kind=="fighter":
			art.draw_sprite(self,"impact",p,Vector2(160,130)*(1-t),Color(1,1,1,1-t))
	# Combo and remaining health already have stable HUD widgets. Repeating them
	# as floating pale captions used to hide the balloon, mallet or ship hit.
