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
	var value := str([target.get("id",-1),target.get("typed",0),run.kills,run.combo,run.feedback,run.paused,run.skill_charge if run is ArcadeRun else 0,ceili(run.skill_time) if run is ArcadeRun else 0])
	if cache!=value:
		cache = value
		queue_redraw()

func text(value: String, at: Vector2, font_size: int, tint := PlayTheme.TEXT) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _draw() -> void:
	if run==null:
		return
	draw_style_box(PlayTheme.surface(Color.WHITE,Color("d7e7f0"),20),Rect2(0,0,1360,88))
	var target := run.recommended_target()
	if run is CastleRun and run.phase=="build":
		text("先建防御塔，再开始防守",Vector2(22,34),25)
		text("Q 火焰塔 · W 寒冰塔 · E 雷电塔 · N 开始这一波",Vector2(22,66),18,PlayTheme.TEAL)
		return
	if target.is_empty():
		text("下一位目标即将出现 · 双手回到 F / J",Vector2(22,51),24)
		return
	var word: String = target.word
	var next := word.substr(target.typed,1)
	var key_label := "空格" if next==" " else next
	draw_style_box(PlayTheme.surface(Color("eaf7ff"),Color("8cbddd"),13),Rect2(15,15,62,58))
	text(key_label,Vector2(27,54),28)
	text("现在输入 · "+("跟随已锁定目标" if run.locked>=0 else "先处理蓝色标记目标"),Vector2(94,26),14,PlayTheme.MUTED)
	var word_size := 29 if FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,29).x<398 else 21
	text(word,Vector2(94,64),word_size)
	if target.typed>0:
		text(word.substr(0,target.typed),Vector2(94,64),word_size,PlayTheme.TEAL)
	var action: String = "领取补给 · 恢复 8 点护盾" if target.get("feature","")=="supply" else VERBS.get(run.mode,"完成目标")
	text("输入完成 → "+action,Vector2(520,32),19,PlayTheme.TEAL)
	var note := "可直接输入其他目标的首字母来切换选择"
	if run.context=="training":
		var phase := mini(3,1+run.kills/6)
		note = "训练 %d / 3 · %s" % [phase,["先找准按键","试着连续命中","独立完成任务"][phase-1]]
	var meaning := Vocabulary.meaning(run.lesson,word)
	if not meaning.is_empty():
		note = meaning+"  ·  "+("刚刚："+run.last_word+" / "+run.last_meaning if not run.last_word.is_empty() else "完成输入，把词义一起记住")
		if FONT.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>435:
			note = meaning+"  ·  上个单词："+run.last_word
	text(note,Vector2(520,62),15,PlayTheme.MUTED)
	if run is ArcadeRun:
		draw_line(Vector2(972,16),Vector2(972,73),Color("dfebf2"),1)
		var ready: bool = run.skill_charge>=3 and run.skill_time<=0
		text("F3  "+run.skill_name(),Vector2(994,35),21,PlayTheme.TEAL if ready else PlayTheme.TEXT)
		for i in range(3):
			draw_circle(Vector2(1001+i*19,59),5,PlayTheme.TEAL if i<run.skill_charge else Color("d9e5ed"))
		var skill_note := "格挡已备好" if run.mode=="fighter" and run.guard_ready else "按下释放！" if ready else "生效 %ds" % ceili(run.skill_time) if run.skill_time>0 else "命中充能 %d/3" % run.skill_charge
		text(skill_note,Vector2(1072,65),15,PlayTheme.TEAL if ready else PlayTheme.MUTED)
	else:
		text("退格 撤回 · Tab 放弃锁定",Vector2(1000,38),16,PlayTheme.MUTED)
		text("F1 指法 · Esc 暂停",Vector2(1000,65),16,PlayTheme.MUTED)
