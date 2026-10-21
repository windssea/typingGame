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
		note = "敌方城堡 %d%%" % (100*run.core/run.core_max) if run.mode=="royal" else "%d / %d 份餐点" % [run.kills,run.goal] if run.mode=="restaurant" else "%d / %d 份补给" % [run.kills,run.goal]
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
	var key := str(values)+note+str(snappedf(progress,0.005))
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
	# Keep only actionable in-run values. Score and detailed labels belong in the result.
	var width := size.x
	var cell := width/3.0
	for slot in range(3):
		var i := slot+1
		if values.size()<=i:
			return
		var x := slot*cell
		var tint: Color = [Color("a7f0d9"),Color("ffdd80"),Color("ffb4ad")][slot]
		var glyph: String = ["accuracy","combo","speed" if values[i][0]=="速度 WPM" else "health"][slot]
		if mode_id=="fighter" and slot==2: glyph="star"
		GameGlyph.draw(self,glyph,Vector2(x+22,27),12,tint)
		var value: String = values[i][1]+(" 连击" if i==2 else " WPM" if values[i][0]=="速度 WPM" else "")
		if mode_id=="fighter" and slot==2: value="ROUND %02d"%round_number
		draw_string(FONT,Vector2(x+44,38),value,HORIZONTAL_ALIGNMENT_LEFT,-1,30,tint)
	draw_string(FONT,Vector2(14,70),note,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff1cd"))
	draw_line(Vector2(14,78),Vector2(width-14,78),Color(.75,.84,.88,.25),3,true)
	if shown_progress>0:
		draw_line(Vector2(14,78),Vector2(14+(width-28)*shown_progress,78),Color("ffdb83"),3,true)
