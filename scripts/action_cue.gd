class_name ActionCue
extends Control

const FONT = preload("res://assets/ui-font.ttf")
const VERBS := {"dojo":"点亮定位键","bubbles":"点亮泡泡","rain":"击碎陨石","sprint":"推进计时任务","castle":"施法攻击标记敌人","balloons":"击破气球","aliens":"发射激光","moles":"挥锤命中","racing":"推进赛车","fighter":"出拳打断"}
var run: GameRun
var cache := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if run==null:
		return
	var target := run.recommended_target()
	var value := str([target.get("id",-1),target.get("typed",0),run.kills,run.combo,run.feedback,run.last_input_ok,run.paused,run.skill_charge if run is ArcadeRun else 0,ceili(run.skill_time) if run is ArcadeRun else 0])
	if cache!=value:
		cache = value
		queue_redraw()

func text(value: String, at: Vector2, font_size: int, tint := PlayTheme.TEXT) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _draw() -> void:
	if run==null:
		return
	draw_style_box(PlayTheme.game_panel(Color("fffef6"),Color("b8d6da"),20,5),Rect2(0,0,1360,88))
	var target := run.recommended_target()
	if run is CastleRun and run.phase=="build":
		text("建设阶段",Vector2(22,34),25)
		text("Q 火焰塔 · W 寒冰塔 · E 雷电塔 · N 开始这一波",Vector2(22,66),18,PlayTheme.TEAL)
		return
	if target.is_empty():
		text("等待目标",Vector2(22,51),24)
		return
	var word: String = target.word
	var next := word.substr(target.typed,1)
	var key_label := "空格" if next==" " else next
	draw_style_box(PlayTheme.game_panel(Color("eaf7ff") if run.last_input_ok else Color("ffebe5"),Color("8cbddd") if run.last_input_ok else Color("d28e85"),13,5),Rect2(15,15,62,58))
	text(key_label,Vector2(27,54),28)
	text("已锁定" if run.last_input_ok and run.locked>=0 else "输入" if run.last_input_ok else "按键不匹配 · 进度保留",Vector2(94,26),16,PlayTheme.MUTED if run.last_input_ok else Color("a3433a"))
	var word_size := 29 if FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,29).x<398 else 21
	text(word,Vector2(94,64),word_size)
	if target.typed>0:
		text(word.substr(0,target.typed),Vector2(94,64),word_size,PlayTheme.TEAL)
	var action: String = "领取补给 · 恢复 8 点护盾" if target.get("feature","")=="supply" else VERBS.get(run.mode,"完成目标")
	text(action,Vector2(520,32),20,PlayTheme.TEAL)
	var meaning := Vocabulary.meaning(run.lesson,word)
	text(meaning,Vector2(520,62),18,PlayTheme.MUTED)
	if run is ArcadeRun:
		draw_line(Vector2(972,16),Vector2(972,73),Color("dfebf2"),1)
		var ready: bool = run.skill_charge>=3 and run.skill_time<=0
		draw_style_box(PlayTheme.game_panel(Color("ffedb8") if ready else Color("edf5f7"),Color("dfbd6a") if ready else Color("c3d5db"),8,3),Rect2(990,15,42,31))
		text("F3",Vector2(998,38),18)
		text(run.skill_name(),Vector2(1045,38),21,PlayTheme.TEAL if ready else PlayTheme.TEXT)
		for i in range(3):
			var tint := PlayTheme.TEAL if i<run.skill_charge else Color("d9e5ed")
			var at := Vector2(1001+i*20,62)
			draw_colored_polygon(PackedVector2Array([at-Vector2(0,6),at+Vector2(5,0),at+Vector2(0,6),at-Vector2(5,0)]),tint)
		var skill_note := "格挡就绪" if run.mode=="fighter" and run.guard_ready else "就绪" if ready else "%ds" % ceili(run.skill_time) if run.skill_time>0 else "%d / 3" % run.skill_charge
		text(skill_note,Vector2(1072,65),15,PlayTheme.TEAL if ready else PlayTheme.MUTED)
	else:
		text("Tab 换目标 · 退格 撤回",Vector2(1000,51),16,PlayTheme.MUTED)
