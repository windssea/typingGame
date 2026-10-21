class_name ActionCue
extends Control

const FONT = preload("res://assets/ui-font.ttf")
const VERBS := {"dojo":"点亮定位键","bubbles":"点亮泡泡","rain":"击碎陨石","sprint":"推进计时任务","castle":"施法攻击标记敌人","balloons":"击破气球","aliens":"发射激光","moles":"挥锤命中","racing":"推进赛车","fighter":"出拳打断"}
var run: GameRun
var cache := ""
var key_pulse := 0.0
var clock := 0.0
var reduced_motion := false
var build_title := "选一处基座，布置防线"
var build_hint := "完成输入，为防御塔充能"

func explain_build(title: String, detail: String) -> void:
	build_title = title
	build_hint = detail
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	run.key_feedback.connect(func(_key,accepted,_point): key_pulse = .18 if accepted else .26; queue_redraw())

func _process(delta: float) -> void:
	if run==null:
		return
	if key_pulse>0 and not run.paused:
		key_pulse = maxf(0,key_pulse-delta)
		queue_redraw()
	if not run.paused and not reduced_motion:
		clock += delta
	var target := run.recommended_target()
	var value := str([target.get("id",-1),target.get("typed",0),run.kills,run.combo,run.feedback,run.last_input_ok,run.paused,run.skill_charge if run is ArcadeRun or run is AdventureRun else 0,ceili(run.skill_time) if run is ArcadeRun or run is AdventureRun else 0])
	if cache!=value:
		cache = value
		queue_redraw()

func text(value: String, at: Vector2, font_size: int, tint := Color("fff1cd")) -> void:
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color("244153"))
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _draw() -> void:
	if run==null:
		return
	var target := run.recommended_target()
	if run is CastleRun and run.phase=="build":
		text(build_title,Vector2(24,46),28)
		text(build_hint,Vector2(24,83),24,PlayTheme.TEAL)
		return
	if target.is_empty():
		text("准备下一击",Vector2(24,64),24)
		draw_skill()
		return
	var word: String = target.word
	var next := word.substr(target.typed,1)
	var data := TypingGuide.mapping(next)
	var key_label := "空格" if next==" " else next
	var press := 0.0
	var key_rect := Rect2(14,16+press,78,74)
	TypingPrompt.key(self,key_rect,key_label,28 if next==" " else 48,true,not run.last_input_ok,clock)
	text(TypingGuide.NAMES[data.finger],Vector2(116,45),23)
	text(data.shift_hand+" Shift + " + data.key.to_upper() if data.shift else "回到 "+TypingGuide.HOMES[data.finger],Vector2(116,78),19,Color("a7e6db"))
	var meaning := Vocabulary.meaning(run.lesson,word)
	if not run.last_input_ok:
		text("再试一次，进度保留",Vector2(500,63),24,Color("a3433a"))
	elif not meaning.is_empty():
		# Definitions support the in-world word; do not repeat a second complete prompt.
		var shaped := TextParagraph.new()
		shaped.add_string(meaning,FONT,24)
		shaped.width = 450
		shaped.draw(get_canvas_item(),Vector2(470,35),Color("fff1cd"))
	draw_skill()

func draw_skill() -> void:
	if run is ArcadeRun or run is AdventureRun:
		var ready: bool = run.skill_charge>=3 and run.skill_time<=0
		draw_style_box(PlayTheme.game_panel(Color("ffdf84") if ready else Color("244c63"),Color("d8bc76"),9,3),Rect2(988,22,106,48))
		text("空格",Vector2(1017,54),22,PlayTheme.TEXT if ready else Color("fff1cd"))
		text(run.skill_name(),Vector2(1114,45),23,Color("ffdc86") if ready else Color("d5e9ec"))
		for i in range(3):
			var tint := PlayTheme.TEAL if i<run.skill_charge else Color("d9e5ed")
			var at := Vector2(1120+i*22,77)
			draw_colored_polygon(PackedVector2Array([at-Vector2(0,6),at+Vector2(5,0),at+Vector2(0,6),at-Vector2(5,0)]),tint)
		var skill_note := "格挡就绪" if run is ArcadeRun and run.mode=="fighter" and run.guard_ready else "就绪" if ready else "%ds" % ceili(run.skill_time) if run.skill_time>0 else "%d / 3" % run.skill_charge
		text(skill_note,Vector2(1203,82),18,Color("ffdc86") if ready else Color("b0c4d0"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.position.x>=980:
		if run is ArcadeRun or run is AdventureRun:
			run.activate_skill()
			accept_event()
