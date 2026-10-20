class_name TrainingLedger
extends Control

const FONT = preload("res://assets/ui-font.ttf")
var run: GameRun
var history: Array[Dictionary] = []
var cache := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	run.spell.connect(func(_a,_b,_lightning):
		history.push_front({"word":run.last_word,"meaning":run.last_meaning})
		if history.size()>3:
			history.pop_back())

func _process(_delta: float) -> void:
	var value := str([run.correct,run.kills,run.feedback,run.last_word,ceili(run.elapsed)])
	if value!=cache:
		cache = value
		queue_redraw()

func text(value: String, at: Vector2, font_size: int, color := PlayTheme.TEXT) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	draw_style_box(PlayTheme.game_panel(Color("e1edd0"),Color("d9d6a9"),20,4),Rect2(0,0,1040,130))
	GameGlyph.draw(self,"training",Vector2(39,37),18,PlayTheme.TEAL)
	text("刚学会" if not run.last_meaning.is_empty() else "练习进度",Vector2(70,43),23)
	var target := run.recommended_target()
	var meaning := Vocabulary.meaning(run.lesson,str(target.get("word","")))
	if not meaning.is_empty():
		for i in range(history.size()):
			var at := Vector2(380+i*205,30)
			draw_style_box(PlayTheme.surface(Color("f4faf1"),Color("d4e5d3"),12),Rect2(at,Vector2(190,77)))
			var word: String = history[i].word
			var font_size := 19 if word.length()<14 else 14
			text(word,at+Vector2(12,27),font_size,PlayTheme.TEAL)
			text(history[i].meaning,at+Vector2(12,56),16)
	else:
		var count := 18 if run.mode in ["dojo","bubbles"] else mini(18,run.correct)
		for i in range(18):
			var at := Vector2(390+(i%9)*65,31+(i/9)*48)
			draw_style_box(PlayTheme.game_panel(Color("e6f5dc") if i<mini(count,run.kills if run.mode in ["dojo","bubbles"] else run.correct) else Color("f0f3e7"),Color("c4d6bd"),8,3),Rect2(at,Vector2(48,34)))
			if i<mini(count,run.kills if run.mode in ["dojo","bubbles"] else run.correct):
				GameGlyph.draw(self,"star",at+Vector2(24,17),9,PlayTheme.TEAL)
