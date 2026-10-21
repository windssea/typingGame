class_name BridgeArena
extends GameArena

const DECK_Y := 534.0
const STEP := 46.0
const START := 320.0
const KEY_CENTER := Vector2(720,250)
var flight: Array[Dictionary] = []
var tile_age: Dictionary = {}
var beacon_flash := 0.0
var last_travel := 0.0
var moving := false
var landing_age := 1.0
var bridge: BridgeRun

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bridge = run as BridgeRun
	art.setup("dojo")
	setup_backdrop(art.background)
	backdrop.material.set_shader_parameter("world_kind",5)
	coach_motion.setup("coach")
	juice.reduced_motion = reduced_motion
	juice.protected_regions = [Rect2(140,135,1160,245)]
	run.key_feedback.connect(on_key_feedback)
	run.hud_changed.connect(queue_redraw)
	bridge.bridge_repaired.connect(repair_bridge)

func repair_bridge(tile: int) -> void:
	tile_age[tile-1] = 0.0
	var destination := Vector2(START+tile*STEP,DECK_Y)
	flight.append({"age":0.0,"to":destination})
	while flight.size()>12:
		flight.pop_front()
	juice.burst(destination,PlayTheme.YELLOW,2,"spark")
	record_impact(destination,2)
	if tile%6==0:
		beacon_flash = 1.2
		coach_age = 0.0
		juice.burst(destination-Vector2(0,105),PlayTheme.MINT,3,"confetti")
		juice.jet(destination,Vector2.UP,PlayTheme.SKY,3)
	queue_redraw()

func on_key_feedback(character: String, accepted: bool, point: Vector2) -> void:
	super.on_key_feedback(character,accepted,point)
	if accepted:
		error_pulse = 0.0
		var destination := Vector2(START+(run.kills+1)*STEP,DECK_Y)
		var target := run.recommended_target()
		if target.get("typed",0)>=str(target.get("word","")).length():
			juice.jet(destination,Vector2.UP,PlayTheme.SKY,1)
		else:
			juice.trail(destination,Vector2(0,-45),PlayTheme.SKY,3)
	queue_redraw()

func _process(delta: float) -> void:
	if run.paused:
		return
	clock += delta
	step_feedback(delta)
	moving = absf(bridge.travel-last_travel)>.0001
	landing_age += delta
	if floori(bridge.travel)>floori(last_travel):
		landing_age = 0.0
		juice.burst(Vector2(START+bridge.travel*STEP,DECK_Y),PlayTheme.YELLOW,1,"soil")
	last_travel = bridge.travel
	beacon_flash = maxf(0,beacon_flash-delta)
	backdrop.material.set_shader_parameter("restored",float(run.kills)/18)
	if coach_age>=0:
		coach_age += delta
		if coach_age>=coach_motion.duration("cheer"):
			coach_age = -1
	for tile in tile_age:
		tile_age[tile] += delta
	for comet in flight.duplicate():
		comet.age += delta
		if comet.age>.5:
			flight.erase(comet)
	juice.step(delta)
	queue_redraw()

func _draw() -> void:
	if bridge==null:
		return
	draw_scene_background()
	draw_path()
	draw_beacons()
	draw_runner()
	draw_comets()
	juice.draw(self)
	draw_prompt()
	draw_practice_keys()

func draw_path() -> void:
	for i in range(18):
		var built: bool = i<run.kills
		# Only the next landing is previewed. No wall of eighteen empty boxes.
		if not built and i!=run.kills:
			continue
		var age: float = tile_age.get(i,1.0)
		var rise := 0.0 if reduced_motion else 24*pow(maxf(0,1-age/.32),2)
		var rect := Rect2(START+STEP*(i+.35),DECK_Y+rise,STEP+1,22)
		if built:
			draw_style_box(PlayTheme.game_panel(Color("72c6cb"),Color("3d909b"),7,2),rect)
			draw_style_box(PlayTheme.surface(Color("f7e0a1"),Color.TRANSPARENT,5),Rect2(rect.position,Vector2(rect.size.x,8)))
		else:
			var target := run.recommended_target()
			var partial := float(target.get("typed",0))/maxi(1,str(target.get("word","")).length())
			draw_style_box(PlayTheme.surface(Color(.65,.9,1,.17+partial*.45),Color(.42,.76,.9,.5),7),rect)
		if built and (i+1)%6==0:
			for petal in range(3):
				var at := rect.position+Vector2(10+petal*13,-4)
				draw_circle(at,4,PlayTheme.YELLOW if petal%2 else PlayTheme.CORAL)

func draw_beacons() -> void:
	for i in range(3):
		var lit: bool = run.kills>=(i+1)*6
		var at := Vector2(START+(i+1)*6*STEP,DECK_Y-85)
		if lit:
			draw_style_box(PlayTheme.surface(Color("7ea4a5"),Color.TRANSPARENT,5),Rect2(at+Vector2(-4,0),Vector2(8,85)))
			draw_circle(at,34+sin(clock*2)*2 if not reduced_motion else 34,Color(.98,.86,.37,.15))
			draw_circle(at,24,Color("f7d46b"))
		else:
			draw_circle(at,21,Color("82a5ae"))
		GameGlyph.draw(self,"star",at,14,Color("fff5b9") if lit else Color("bedce4"))
	GameHudSkin.caption(self,"%d / 18"%run.kills,Rect2(600,24,240,68),30,1)

func draw_runner() -> void:
	var jump := 0.0 if reduced_motion or not moving else sin(fposmod(bridge.travel,1)*PI)*28
	var slip := 0.0 if reduced_motion else sin(error_pulse/.24*PI)*16
	var foot := Vector2(START+bridge.travel*STEP-slip,DECK_Y-jump)
	var state := "run" if moving else "cheer" if coach_age>=0 else "idle"
	var frame := coach_motion.texture(state,coach_age if state=="cheer" else clock,reduced_motion)
	if frame!=null:
		draw_ellipse_shadow(Vector2(foot.x,DECK_Y+5),Vector2(38,7))
		var squash := 0.0 if reduced_motion else GameFeel.kick(landing_age,.24)
		draw_set_transform(foot,0,Vector2(1+squash*.10,1-squash*.09))
		draw_texture_rect(frame,Rect2(Vector2(-145,-246),Vector2(290,290)),false)
		draw_set_transform(Vector2.ZERO)

func draw_comets() -> void:
	if reduced_motion:
		return
	for comet in flight:
		var fraction: float = clampf(comet.age/.5,0,1)
		var point := KEY_CENTER.lerp(comet.to,fraction)
		point.y -= sin(fraction*PI)*70
		for i in range(5):
			var t: float = maxf(0,fraction-i*.025)
			var tail := KEY_CENTER.lerp(comet.to,t)-Vector2(0,sin(t*PI)*70)
			draw_circle(tail,7-i,Color(1,.88,.42,(1-fraction)*(.8-i*.1)))
		draw_circle(point,8,Color("fff3ba"))

func draw_prompt() -> void:
	var target := run.recommended_target()
	if target.is_empty():
		GameHudSkin.caption(self,"星桥修好了！",Rect2(460,210,520,100),50,0)
		return
	var word: String = target.word
	var next := word.substr(target.typed,1)
	var shift: bool = TypingGuide.mapping(next).shift
	if word.length()==1:
		var rect := Rect2(620,148,200,210)
		var caption := "空格" if next==" " else next
		TypingPrompt.key(self,rect,caption,68 if next==" " else 144,true,error_pulse>0,clock)
		if shift:
			GameHudSkin.caption(self,"Shift +",Rect2(620,106,200,36),22,1)
	else:
		var layout := TypingPrompt.measure(word,1080,88,52)
		var rect := Rect2(Vector2(720,250)-layout.size*.5,layout.size)
		TypingPrompt.paint(self,word,target.typed,rect,layout,true,error_pulse>0,true,clock,key_pulse,reduced_motion,run.mode)
		var meaning := Vocabulary.meaning(run.lesson,word)
		if not meaning.is_empty() and layout.rows.size()==1:
			GameHudSkin.caption(self,meaning,Rect2(500,330,440,48),26,2)
	if error_pulse>0:
		GameHudSkin.caption(self,"再试一次",Rect2(600,640,240,44),25,2)

func draw_practice_keys() -> void:
	var target := run.recommended_target()
	if target.is_empty():
		return
	var next := str(target.word).substr(target.typed,1)
	var mapping := TypingGuide.mapping(next)
	var keys: String = run.lesson.get("keys","")
	# Teach just today's keys. The full keyboard and hand diagram are available with F1.
	if keys.length()>10:
		GameHudSkin.caption(self,TypingGuide.NAMES[mapping.finger]+(" + "+mapping.shift_hand+" Shift" if mapping.shift else ""),Rect2(470,750,500,72),28,1)
		return
	var width := 100.0 if keys.length()<=4 else 76.0
	var left := 720-keys.length()*(width+16)*.5
	for i in range(keys.length()):
		var key := keys.substr(i,1)
		var active: bool = key==mapping.key
		var press := 0.0
		var at := Vector2(left+i*(width+16),751+press)
		TypingPrompt.key(self,Rect2(at,Vector2(width,80)),key.to_upper(),44,active,false,clock)
		var finger: int = TypingGuide.mapping(key).finger
		GameHudSkin.caption(self,TypingGuide.NAMES[finger].replace("手",""),Rect2(at+Vector2(0,84),Vector2(width,32)),19,1)
