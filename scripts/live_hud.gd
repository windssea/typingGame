class_name LiveHud
extends Control

const FONT = preload("res://assets/ui-heading.ttf")
var snapshot := ""
var values: Array = []
var note := ""
var progress := 0.0
var shown_progress := 0.0
var combo_glow := 0.0
var last_combo := 0
var progress_tween: Tween
var combo_tween: Tween
var reduced_motion := false
var mode_id:=""
var round_number:=1
var refresh_count := 0

func refresh(run: GameRun) -> void:
	mode_id=run.mode
	if run is ArcadeRun: round_number=run.round_number
	refresh_count += 1
	var status := "体力"
	var last := str(run.hp)
	var fraction := float(run.kills)/18
	note = "%d / 18" % run.kills
	if run is CastleRun:
		status = "城防"
		note = "第 %d / 6 波 · %d 金币 · 能量 %d" % [run.wave,run.gold,run.energy]
		fraction = float(run.wave-1)/6
	elif run is AdventureRun:
		note = "敌方城堡 %d%%" % (100*run.core/run.core_max) if run.mode=="royal" else "%d / %d 份餐点" % [run.kills,run.goal] if run.mode=="restaurant" else "%d / %d 拦截与补给" % [run.kills,run.goal]
		fraction = 1.0-float(run.core)/run.core_max if run.mode=="royal" else float(run.kills)/run.goal
	elif run is ArcadeRun:
		note = "%d / %d" % [run.kills,run.goal]
		if run.context=="training" and run.goal==18:
			note = "%d / 18" % run.kills
		fraction = run.distance if run.mode=="racing" else float(run.kills)/run.goal
		if run.mode=="racing": note="赛程 %d%%"%roundi(run.distance*100)
		if run.mode=="aliens":
			status = "船体"
			last = str(run.hp)
	elif run.mode in ["rain","sprint"]:
		var seconds := 90.0 if run.mode=="rain" else 60.0
		note = "剩余 %d 秒" % maxi(0,ceili(seconds-run.elapsed))
		if run.mode=="sprint" and run.context=="challenge":
			var rank := SessionOptions.rank_index(run.challenge_rank)
			note = "目标 %d 字符 · %d%% 准确率" % [[18,36,60][rank],[85,90,95][rank]]
		elif run.mode=="sprint":
			note = "60 秒自由冲刺"
		fraction = clampf(run.elapsed/seconds,0,1)
	if run.mode in ["dojo","bubbles","sprint","racing"]:
		status = "速度 WPM"
		last = "%.0f" % run.wpm()
	values = [["得分",str(run.score)],["准确率","%d%%" % roundi(run.accuracy()*100)],["连击",str(run.combo)],[status,last]]
	progress = clampf(fraction,0,1)
	var key := str(values)+note+str(snappedf(progress,0.005))+str(round_number)
	if key!=snapshot:
		snapshot = key
		if progress_tween and progress_tween.is_valid():
			progress_tween.kill()
		if is_inside_tree() and not reduced_motion:
			progress_tween = create_tween()
			progress_tween.tween_method(func(v: float): shown_progress=v; queue_redraw(),shown_progress,progress,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			shown_progress = progress
		if run.combo>last_combo and not reduced_motion and is_inside_tree():
			if combo_tween and combo_tween.is_valid():
				combo_tween.kill()
			combo_glow = 0.6
			combo_tween = create_tween()
			combo_tween.tween_method(func(v: float): combo_glow=v; queue_redraw(),combo_glow,0.0,0.3)
		last_combo = run.combo
		queue_redraw()

func _exit_tree() -> void:
	for tween in [progress_tween,combo_tween]:
		if tween and tween.is_valid():
			tween.kill()

func _draw() -> void:
	var width:=size.x
	var cell:=width/3.0
	for slot in range(3):
		var i:=slot+1
		if values.size()<=i:return
		var x:=slot*cell
		var tint:Color=[Color("b9f4df"),Color("ffe3a1"),Color("b8e9ff") if values[i][0]=="速度 WPM" else Color("ffc1b2")][slot]
		var icon:String=["accuracy","combo","speed" if values[i][0]=="速度 WPM" else "health"][slot]
		if mode_id=="fighter" and slot==2:icon="star"
		GameHudSkin.panel(self,Rect2(x+3,0,cell-6,50),1)
		GameGlyph.draw(self,icon,Vector2(x+26,25),12,tint)
		var value:String=values[i][1]+(" 连击" if i==2 else " WPM" if values[i][0]=="速度 WPM" else "")
		if mode_id=="fighter" and slot==2:value="ROUND %02d"%round_number
		GameHudSkin.text(self,value,Rect2(x+48,4,cell-62,42),29,tint)
	var note_width:=minf(width*.7,FONT.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+28)
	GameHudSkin.caption(self,note,Rect2(3,54,note_width,26),17,2)
	var meter:=Rect2(note_width+12,58,maxf(20,width-note_width-18),18)
	GameHudSkin.panel(self,meter,1)
	var inside:=meter.grow(-5)
	if shown_progress>0:
		draw_style_box(PlayTheme.surface(Color("ffd78b"),Color("ffeac0"),3),Rect2(inside.position,Vector2(inside.size.x*shown_progress,inside.size.y)))
