class_name ActionCue
extends Control

const FONT = preload("res://assets/ui-font.ttf")
const VERBS := {"dojo":"点亮定位键","bubbles":"点亮泡泡","rain":"击碎陨石","sprint":"推进计时任务","castle":"施法攻击标记敌人","balloons":"击破气球","aliens":"发射激光","moles":"挥锤命中","racing":"推进赛车","fighter":"出拳打断"}
var run: GameRun
var cache := ""
var key_pulse := 0.0
var reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	run.key_feedback.connect(func(_key,accepted,_point): key_pulse = .18 if accepted else .26; queue_redraw())

func _process(delta: float) -> void:
	if run==null:
		return
	if key_pulse>0 and not run.paused:
		key_pulse = maxf(0,key_pulse-delta)
		queue_redraw()
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
	draw_style_box(PlayTheme.game_panel(Color("fffef6"),Color("a6cbd4"),20,5),Rect2(0,0,1360,108))
	var target := run.recommended_target()
	if run is CastleRun and run.phase=="build":
		text("建设阶段",Vector2(24,42),28)
		text("Q 火焰塔 · W 寒冰塔 · E 雷电塔 · N 开始这一波",Vector2(24,79),22,PlayTheme.TEAL)
		return
	if target.is_empty():
		text("等待目标",Vector2(24,65),30)
		return
	var word: String = target.word
	var next := word.substr(target.typed,1)
	var key_label := "空格" if next==" " else next
	var shift: bool = TypingGuide.mapping(next).shift
	var press := 0.0 if reduced_motion else minf(1,key_pulse/.18)*3
	var key_rect := Rect2(12,9+press,110,86)
	draw_style_box(PlayTheme.game_panel(Color("fff0bd") if run.last_input_ok else Color("ffddd1"),Color("c39038") if run.last_input_ok else Color("c86e61"),13,5-int(press)),key_rect)
	text("Shift +" if shift else "下一键",Vector2(27,29+press),15,PlayTheme.TEXT)
	var key_font := 30 if next==" " else 49
	var key_width := TypingPrompt.FONT.get_string_size(key_label,HORIZONTAL_ALIGNMENT_LEFT,-1,key_font).x
	draw_string(TypingPrompt.FONT,Vector2(67-key_width/2,79+press),key_label,HORIZONTAL_ALIGNMENT_LEFT,-1,key_font,PlayTheme.TEXT)
	var layout := TypingPrompt.measure(word,834,46,32)
	var meaning := Vocabulary.meaning(run.lesson,word)
	if layout.rows.size()==1:
		text(meaning if run.last_input_ok else "按键不匹配 · 进度保留",Vector2(150,26),18,PlayTheme.TEAL if run.last_input_ok else Color("a3433a"))
	TypingPrompt.paint(self,word,target.typed,Rect2(134,32 if layout.rows.size()==1 else 0,834,76),layout,true,not run.last_input_ok,false)
	if run is ArcadeRun:
		draw_line(Vector2(980,16),Vector2(980,92),Color("dfebf2"),1)
		var ready: bool = run.skill_charge>=3 and run.skill_time<=0
		draw_style_box(PlayTheme.game_panel(Color("ffedb8") if ready else Color("edf5f7"),Color("dfbd6a") if ready else Color("c3d5db"),8,3),Rect2(1000,20,46,34))
		text("F3",Vector2(1008,44),18)
		text(run.skill_name(),Vector2(1060,45),21,PlayTheme.TEAL if ready else PlayTheme.TEXT)
		for i in range(3):
			var tint := PlayTheme.TEAL if i<run.skill_charge else Color("d9e5ed")
			var at := Vector2(1013+i*22,77)
			draw_colored_polygon(PackedVector2Array([at-Vector2(0,6),at+Vector2(5,0),at+Vector2(0,6),at-Vector2(5,0)]),tint)
		var skill_note := "格挡就绪" if run.mode=="fighter" and run.guard_ready else "就绪" if ready else "%ds" % ceili(run.skill_time) if run.skill_time>0 else "%d / 3" % run.skill_charge
		text(skill_note,Vector2(1093,82),18,PlayTheme.TEAL if ready else PlayTheme.MUTED)
	else:
		text("Tab 换目标 · 退格 撤回",Vector2(1000,64),16,PlayTheme.MUTED)
