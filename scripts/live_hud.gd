class_name LiveHud
extends Control

const FONT = preload("res://assets/ui-font.ttf")
var snapshot := ""
var values: Array = []
var note := ""
var progress := 0.0

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
		queue_redraw()

func _draw() -> void:
	var style := PlayTheme.surface(Color.WHITE,Color("deebf5"),18)
	draw_style_box(style,Rect2(Vector2.ZERO,Vector2(780,102)))
	for i in range(values.size()):
		var x := 22+i*190
		draw_string(FONT,Vector2(x,24),values[i][0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,PlayTheme.MUTED)
		draw_string(FONT,Vector2(x,54),values[i][1],HORIZONTAL_ALIGNMENT_LEFT,-1,26,PlayTheme.TEAL if i==2 else PlayTheme.TEXT)
	draw_string(FONT,Vector2(22,80),note,HORIZONTAL_ALIGNMENT_LEFT,-1,13,PlayTheme.MUTED)
	draw_line(Vector2(22,91),Vector2(758,91),Color("e4eef5"),5,true)
	if progress>0:
		draw_line(Vector2(22,91),Vector2(22+736*progress,91),PlayTheme.TEAL,5,true)
