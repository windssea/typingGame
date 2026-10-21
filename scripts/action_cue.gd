class_name ActionCue
extends Control

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

func _draw() -> void:
	if run==null:return
	var target:=run.recommended_target()
	if run is CastleRun and run.phase=="build":
		GameHudSkin.panel(self,Rect2(8,8,size.x-16,92),0)
		GameHudSkin.text(self,build_title,Rect2(28,16,size.x-56,34),27)
		GameHudSkin.text(self,build_hint,Rect2(28,54,size.x-56,28),21,Color("bae8df"))
		return
	if target.is_empty():
		draw_skill();return
	var word:String=target.word
	var next:=word.substr(target.typed,1)
	var data:=TypingGuide.mapping(next)
	var key_label:="空格" if next==" " else next
	GameHudSkin.panel(self,Rect2(8,8,416,92),1)
	TypingPrompt.key(self,Rect2(20,16,78,74),key_label,28 if next==" " else 48,true,not run.last_input_ok,clock)
	GameHudSkin.text(self,TypingGuide.NAMES[data.finger],Rect2(116,18,284,30),23)
	GameHudSkin.text(self,data.shift_hand+" Shift + "+data.key.to_upper() if data.shift else "回到 "+TypingGuide.HOMES[data.finger],Rect2(116,54,284,24),19,Color("b7e6df"))
	var meaning:=Vocabulary.meaning(run.lesson,word)
	if not run.last_input_ok:meaning="再试一次，进度保留"
	if not meaning.is_empty():
		GameHudSkin.panel(self,Rect2(446,8,440,92),2)
		GameGlyph.draw(self,"book",Vector2(478,54),14,Color("517a7d"))
		var shaped:=TextParagraph.new()
		for font_size in range(24,17,-1):
			shaped.clear();shaped.add_string(meaning,GameHudSkin.FONT,font_size);shaped.width=356
			if shaped.get_size().y<=66:break
		shaped.draw(get_canvas_item(),Vector2(506,21+(66-shaped.get_size().y)*.5),Color("973d35") if not run.last_input_ok else Color("274657"))
	draw_skill()

func draw_skill() -> void:
	if run is ArcadeRun or run is AdventureRun:
		var ready:bool=run.skill_charge>=3 and run.skill_time<=0
		GameHudSkin.panel(self,Rect2(960,8,392,92),3)
		TypingPrompt.key(self,Rect2(974,20,94,62),"空格",24,ready)
		GameHudSkin.text(self,run.skill_name(),Rect2(1084,18,246,30),23,Color("ffe1a0") if ready else Color("e1f0f0"))
		for i in range(3):
			var at:=Vector2(1095+i*24,72)
			draw_style_box(PlayTheme.surface(Color("14384d"),Color("4d7782"),4),Rect2(at-Vector2(8,8),Vector2(16,16)))
			if i<run.skill_charge:
				draw_colored_polygon(PackedVector2Array([at-Vector2(0,6),at+Vector2(5,0),at+Vector2(0,6),at-Vector2(5,0)]),Color("ffdc8a"))
		var note:="格挡就绪" if run is ArcadeRun and run.mode=="fighter" and run.guard_ready else "就绪" if ready else "%ds"%ceili(run.skill_time) if run.skill_time>0 else "%d / 3"%run.skill_charge
		GameHudSkin.text(self,note,Rect2(1180,57,150,28),20,Color("ffe1a0") if ready else Color("b8d2da"),true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.position.x>=980:
		if run is ArcadeRun or run is AdventureRun:
			run.activate_skill()
			accept_event()
