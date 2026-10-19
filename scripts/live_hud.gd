class_name LiveHud
extends Control

const FONT = preload("res://assets/ui-font.ttf")
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

func refresh(run: GameRun) -> void:
	var status := "体力"
	var last := str(run.hp)
	var fraction := float(run.kills)/18
	note = "%d / 18 个目标" % run.kills
	if run is CastleRun:
		status = "城防"
		note = "第 %d / 6 波 · %s" % [run.wave,"建设时间" if run.phase=="build" else "守护城堡"]
		fraction = float(run.wave-1)/6
	elif run is ArcadeRun:
		note = "%d / %d 个目标" % [run.kills,run.goal]
		if run.context=="training" and run.goal==18:
			note = "训练 %d / 3 段 · 完成 %d / 18 · 每六次命中获得阶段奖励" % [mini(3,1+run.kills/6),run.kills]
		fraction = run.distance if run.mode=="racing" else float(run.kills)/run.goal
		if run.mode=="aliens":
			status = "护盾"
			last = str(run.shield)
	elif run.mode in ["rain","sprint"]:
		var seconds := 90.0 if run.mode=="rain" else 60.0
		note = "还剩 %d 秒 · 稳住你的节奏" % maxi(0,ceili(seconds-run.elapsed))
		if run.mode=="sprint" and run.context=="challenge":
			var rank := SessionOptions.rank_index(run.challenge_rank)
			note = "还剩 %d 秒 · 目标 %d 字符 / %d%% 准确率" % [maxi(0,ceili(seconds-run.elapsed)),[18,36,60][rank],[85,90,95][rank]]
		fraction = clampf(run.elapsed/seconds,0,1)
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
	var style := PlayTheme.surface(Color.WHITE,Color("deebf5"),18)
	draw_style_box(style,Rect2(Vector2.ZERO,Vector2(780,102)))
	if combo_glow>0:
		draw_style_box(PlayTheme.surface(Color(0.72,0.94,0.83,combo_glow),Color.TRANSPARENT,12),Rect2(391,8,178,56))
	for i in range(values.size()):
		var x := 22+i*190
		draw_string(FONT,Vector2(x,24),values[i][0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,PlayTheme.MUTED)
		draw_string(FONT,Vector2(x,54),values[i][1],HORIZONTAL_ALIGNMENT_LEFT,-1,26,PlayTheme.TEAL if i==2 else PlayTheme.TEXT)
	draw_string(FONT,Vector2(22,80),note,HORIZONTAL_ALIGNMENT_LEFT,-1,13,PlayTheme.MUTED)
	draw_line(Vector2(22,91),Vector2(758,91),Color("e4eef5"),5,true)
	if shown_progress>0:
		draw_line(Vector2(22,91),Vector2(22+736*shown_progress,91),PlayTheme.TEAL,5,true)
