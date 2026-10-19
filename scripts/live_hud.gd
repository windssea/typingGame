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
			note = "%d / 18" % run.kills
		fraction = run.distance if run.mode=="racing" else float(run.kills)/run.goal
		if run.mode=="aliens":
			status = "护盾"
			last = str(run.shield)
	elif run.mode in ["rain","sprint"]:
		var seconds := 90.0 if run.mode=="rain" else 60.0
		note = "剩余 %d 秒" % maxi(0,ceili(seconds-run.elapsed))
		if run.mode=="sprint" and run.context=="challenge":
			var rank := SessionOptions.rank_index(run.challenge_rank)
			note = "还剩 %d 秒 · 目标 %d 字符 / %d%% 准确率" % [maxi(0,ceili(seconds-run.elapsed)),[18,36,60][rank],[85,90,95][rank]]
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
	draw_style_box(PlayTheme.game_panel(Color("f7fffc"),Color("bfdcd7"),14,3),Rect2(0,63,780,39))
	for i in range(values.size()):
		var x := i*198
		var tint: Color = [PlayTheme.ORANGE,PlayTheme.TEAL,PlayTheme.PRIMARY,Color("a54e50")][i]
		var fill: Color = [Color("fff8de"),Color("eefff6"),Color("eef7ff"),Color("fff1eb")][i]
		if i==2:
			fill = fill.lerp(Color("bdebd1"),combo_glow)
		draw_style_box(PlayTheme.game_panel(fill,fill.darkened(.15),14,4),Rect2(x,0,186,58))
		var glyph: String = ["score","accuracy","combo","speed" if values[i][0]=="速度 WPM" else "health"][i]
		GameGlyph.draw(self,glyph,Vector2(x+23,30),12,tint)
		draw_string(FONT,Vector2(x+45,20),values[i][0],HORIZONTAL_ALIGNMENT_LEFT,-1,14,PlayTheme.MUTED)
		draw_string(FONT,Vector2(x+45,48),values[i][1],HORIZONTAL_ALIGNMENT_LEFT,-1,28,tint)
	draw_string(FONT,Vector2(16,81),note,HORIZONTAL_ALIGNMENT_LEFT,-1,14,PlayTheme.MUTED)
	draw_line(Vector2(16,92),Vector2(764,92),Color("d8e9e6"),5,true)
	if shown_progress>0:
		draw_line(Vector2(16,92),Vector2(16+748*shown_progress,92),PlayTheme.TEAL,5,true)
