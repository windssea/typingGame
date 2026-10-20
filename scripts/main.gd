extends Control

const FONT = preload("res://assets/ui-font.ttf")
const HEADING = preload("res://assets/ui-heading.ttf")
const BG := PlayTheme.BACKGROUND
const PANEL := PlayTheme.SURFACE
const LINE := PlayTheme.BORDER
const TEXT := PlayTheme.TEXT
const MUTED := PlayTheme.MUTED
const GOLD := PlayTheme.PRIMARY
const MINT := PlayTheme.TEAL
var store := ProfileStore.new()
var lessons := GameContent.lessons()
var lesson_index := 0
var pace := 1.0
var page := "home"
var layer: Control
var overlay: Control
var run: GameRun
var hud: Label
var hint: Label
var pause_button: Button
var captured := false
var modal_focus: Dictionary = {}
var castle_panel: CastlePanel
var session_context := "training"
var castle_audio: CastleAudio
var typing_guide: TypingGuide
var guide_open := false
var guide_was_paused := false
var previous_focus: Control
var sound_button: Button
var challenge_index := 0
var ui_tweens: Dictionary = {}
var live_hud: LiveHud
var vocabulary_topic := "mixed"
var soundscape: GameSoundscape
func _ready() -> void:
	# Public rebrand keeps the existing engine/save namespace for all old profiles.
	DisplayServer.window_set_title("指尖挑战 · 每一次输入，都有回应")
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa') && new URLSearchParams(location.search).has('qa_profile')",true):
		store.path = "user://browser-validation.json"
	store.load_profile()
	lesson_index = int(store.data.last_lesson)
	pace = float(store.data.settings.get("training_speed",1.0))
	challenge_index = SessionOptions.rank_index(store.data.settings.get("challenge_rank","normal"))
	vocabulary_topic = store.data.settings.get("vocabulary_topic","mixed")
	soundscape = GameSoundscape.new()
	soundscape.settings = store.data.settings
	add_child(soundscape)
	theme = PlayTheme.ui(FONT)
	show_home()
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')",true):
		var probe := WebGameProbe.new()
		probe.app = self
		add_child(probe)
	if "--preview-castle" in OS.get_cmdline_user_args():
		lesson_index = 6
		start_game("castle","challenge")
		run.gold = 600
		run.build_tower(0,"fire")
		run.build_tower(1,"ice")
		run.build_tower(2,"storm")
		run.wave = 6
		run.begin_wave()
		for i in range(5):
			run.spawn_target()
		run.energy = 12
		run.targets[0].position = Vector2(280,220)
		run.targets[1].position = Vector2(770,390)
		run.effect.emit("storm",Vector2(350,440),Vector2(280,220),29)
		run.effect.emit("fire",CastleRun.KEEP,Vector2(770,390),50)
		run.paused = true

func clear_ui() -> void:
	if is_instance_valid(soundscape):
		soundscape.settings = store.data.settings
		soundscape.apply_settings()
		if page!="game":
			soundscape.run = null
	modal_focus.clear()
	castle_panel = null
	castle_audio = null
	typing_guide = null
	guide_open = false
	sound_button = null
	live_hud = null
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	layer = Control.new()
	ui_tweens.clear()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = BG
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	if page!="game":
		var stage := MenuStage.new()
		stage.home = page=="home"
		stage.reduced_motion = store.data.settings.reduced_motion
		layer.add_child(stage)
	overlay = null

func style(color: Color, border := LINE, radius := 22) -> StyleBoxFlat:
	return PlayTheme.game_panel(color,border,radius,4)

func panel(at: Vector2, dimensions: Vector2, color := PANEL, parent: Control = layer) -> Panel:
	var item := Panel.new()
	item.position = at
	item.size = dimensions
	item.add_theme_stylebox_override("panel", style(color))
	parent.add_child(item)
	return item

func label(value: String, at: Vector2, font_size := 18, color := TEXT, parent: Control = layer) -> Label:
	var item := Label.new()
	item.text = value
	item.position = at
	item.add_theme_font_size_override("font_size", font_size)
	if font_size>=24:
		item.add_theme_font_override("font",HEADING)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func button(value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary := false, parent: Control = layer) -> Button:
	var item := Button.new()
	dimensions.y = maxf(44,dimensions.y)
	item.text = value
	item.position = at
	item.size = dimensions
	item.add_theme_font_override("font",HEADING)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_stylebox_override("normal",PlayTheme.game_button(primary))
	item.add_theme_stylebox_override("hover",PlayTheme.game_button(primary,"hover"))
	item.add_theme_stylebox_override("pressed",PlayTheme.game_button(primary,"pressed"))
	var focus := PlayTheme.surface(Color.TRANSPARENT,PlayTheme.PRIMARY,15)
	focus.set_border_width_all(3)
	item.add_theme_stylebox_override("focus", focus)
	item.add_theme_stylebox_override("disabled",PlayTheme.game_button(false,"disabled"))
	item.add_theme_color_override("font_disabled_color",Color("718197"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		item.add_theme_color_override(state, PlayTheme.ACTION_INK if primary else TEXT)
	item.pressed.connect(func():
		if is_instance_valid(soundscape):
			soundscape.cue("confirm",-18)
		callback.call())
	parent.add_child(item)
	item.pivot_offset = dimensions/2
	item.mouse_entered.connect(func(): animate_button(item,1.025))
	item.mouse_exited.connect(func(): animate_button(item,1.0))
	item.focus_entered.connect(func(): animate_button(item,1.025))
	item.focus_entered.connect(func():
		if is_instance_valid(soundscape):
			soundscape.cue("focus",-23))
	item.focus_exited.connect(func(): animate_button(item,1.0))
	item.button_down.connect(func(): animate_button(item,0.97))
	item.button_up.connect(func(): animate_button(item,1.0))
	ensure_keyboard_focus.call_deferred()
	return item

func animate_button(control: Control, factor: float) -> void:
	if store.data.settings.reduced_motion or not is_instance_valid(control) or not control.is_inside_tree() or not is_inside_tree():
		return
	var id := control.get_instance_id()
	if ui_tweens.has(id) and ui_tweens[id].is_valid():
		ui_tweens[id].kill()
	var tween := control.create_tween()
	ui_tweens[id] = tween
	tween.tween_property(control,"scale",Vector2.ONE*factor,0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _exit_tree() -> void:
	for tween in ui_tweens.values():
		if tween.is_valid():
			tween.kill()
	ui_tweens.clear()

func speed_controls(at: Vector2, parent: Control = layer) -> void:
	label("训练速度",at,17,TEXT,parent)
	for i in range(SessionOptions.SPEEDS.size()):
		var index := i
		button(SessionOptions.SPEED_NAMES[i],at+Vector2(100+i*164,-8),Vector2(154,42),func(): select_speed(index),is_equal_approx(pace,SessionOptions.SPEEDS[i]),parent).name = "TrainingSpeed%d" % i

func select_speed(index: int) -> void:
	pace = SessionOptions.SPEEDS[index]
	store.data.settings.training_speed = pace
	store.save_profile()
	show_training_games()
	layer.find_child("TrainingSpeed%d" % index,true,false).grab_focus()

func select_rank(index: int) -> void:
	challenge_index = index
	store.data.settings.challenge_rank = SessionOptions.RANK_IDS[index]
	store.save_profile()
	show_challenges()
	layer.find_child("ChallengeRank%d" % index,true,false).grab_focus()

func navigation(active: String) -> void:
	var logo := label("指尖挑战",Vector2(30,35),34)
	logo.add_theme_color_override("font_outline_color",Color.WHITE)
	logo.add_theme_constant_override("outline_size",4)
	button("打字训练",Vector2(22,179),Vector2(208,65),show_lessons,active!="challenges").name = "TrainingNav"
	button("打字挑战",Vector2(22,311),Vector2(208,65),show_challenges,active=="challenges").name = "ChallengeNav"
	add_badge("moles",Vector2(25,445),Vector2(200,160))
	panel(Vector2(24,624),Vector2(204,104),Color("fffae8"))
	label("Lv. %02d   ·   %d XP" % [1+int(store.data.xp/100),store.data.xp],Vector2(40,645),19)
	label("已掌握 %d / 10 节" % store.data.completed.size(),Vector2(40,685),16,MINT)
	button("存档与设置",Vector2(28,747),Vector2(194,46),show_profile).name = "ProfileUtility"
	sound_button = button("F2 声音开" if store.data.settings.get("sound",true) else "F2 声音关",Vector2(28,805),Vector2(194,44),toggle_sound)

func show_home() -> void:
	page = "home"
	run = null
	clear_ui()
	button("打字训练",Vector2(30,35),Vector2(174,52),show_lessons).name = "TrainingNav"
	button("打字挑战",Vector2(30,102),Vector2(174,52),show_challenges).name = "ChallengeNav"
	button("存档与设置",Vector2(1230,35),Vector2(180,52),show_profile).name = "ProfileUtility"
	var logo := label("指尖挑战",Vector2(570,33),64,TEXT)
	logo.add_theme_constant_override("outline_size",6)
	logo.add_theme_color_override("font_outline_color",Color.WHITE)
	label("小手就位，冒险开打！",Vector2(580,112),24,MINT)
	panel(Vector2(1190,105),Vector2(220,57),Color("fff7df"))
	label("Lv. %02d  ·  %d XP" % [1+int(store.data.xp/100),store.data.xp],Vector2(1208,121),19)
	sound_button = button("F2 声音开" if store.data.settings.get("sound",true) else "F2 声音关",Vector2(1230,175),Vector2(180,44),toggle_sound)
	for i in range(2):
		var x := 200+i*545
		var card := panel(Vector2(x,262),Vector2(495,450),Color("fffdf2") if i==0 else Color("f3fbff"))
		card.clip_contents = true
		add_badge("moles" if i==0 else "aliens",Vector2(95,4),Vector2(300,215),card)
		label("打字训练" if i==0 else "打字挑战",Vector2(32,222),35,TEXT,card)
		label("从 F / J 开始，逐步练习单词。" if i==0 else "选好难度，用连击改变战局。",Vector2(32,279),20,MUTED,card)
		var launch := button("继续训练  →" if i==0 else "选择挑战  →",Vector2(24,355),Vector2(447,58),begin_recommended_training if i==0 else show_challenges,i==0,card)
		launch.name = "StartTraining" if i==0 else "StartChallenge"
		if i==0:
			launch.grab_focus()
	panel(Vector2(304,752),Vector2(832,98),Color("fffdf0"))
	label("继续成长  /  "+lessons[lesson_index].name,Vector2(330,771),23)
	label("已掌握 %d / 10 节" % store.data.completed.size(),Vector2(330,814),18,MINT)
	label("Tab 选择  ·  Enter 出发  ·  Esc 返回",Vector2(520,867),16,TEXT)

func recommended_mode() -> String:
	return ["moles","balloons","aliens","moles","racing","balloons","fighter","racing","aliens","sprint"][lesson_index]

func begin_recommended_training() -> void:
	start_game(recommended_mode(),"training")

func continue_training() -> void:
	lesson_index = mini(lessons.size()-1,lesson_index+1)
	store.data.last_lesson = lesson_index
	store.save_profile()
	begin_recommended_training()

func add_badge(mode: String, at: Vector2, dimensions: Vector2, parent: Control = layer) -> ModeBadge:
	var badge := ModeBadge.new()
	badge.mode = mode
	badge.reduced_motion = store.data.settings.reduced_motion
	badge.position = at
	badge.size = dimensions
	parent.add_child(badge)
	return badge

func mission_goal(mode: String, purpose: String) -> String:
	if mode=="castle":
		return "守住六波进攻 · 击败两位统领"
	if mode=="rain":
		return "守住 90 秒 · 防线体力归零则失败"
	if mode=="sprint":
		return "60 秒内 ≥%d 字符 · 准确率 ≥%d%%" % [[18,36,60][challenge_index],[85,90,95][challenge_index]] if purpose=="challenge" else "60 秒专注输入 · 看见速度和准确率"
	if mode in ["dojo","bubbles"]:
		return "完成 18 次输入 · 不限时、没有失败"
	if mode=="racing":
		return "先于对手冲线 · F3 干扰对手" if purpose=="challenge" else "输入推进赛程 · 自由完赛"
	return "完成 %d 次命中 · 体力归零则失败" % (30+challenge_index*6) if purpose=="challenge" else "三个小阶段 · 完成 18 次命中"

func game_grid(modes: Array, at: Vector2, dimensions: Vector2, purpose: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "GameCollection"
	scroll.position = at
	scroll.size = dimensions
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",16)
	layer.add_child(scroll)
	scroll.add_child(grid)
	for definition in modes:
		var mode: Dictionary = definition
		var card := Panel.new()
		card.custom_minimum_size = Vector2(350,252)
		card.clip_contents = true
		card.add_theme_stylebox_override("panel",style(PANEL))
		grid.add_child(card)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = load("res://assets/generated/"+("balloons-background-v2" if mode.id=="balloons" else str(mode.id)+"-background")+".png")
		picture.position = Vector2(10,10)
		picture.size = Vector2(330,90)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		var mascot := add_badge(mode.id,Vector2(99,12),Vector2(150,85),card)
		mascot.reduced_motion = true
		var accent: Color = PlayTheme.PASTELS[GameContent.modes().find(definition)%PlayTheme.PASTELS.size()]
		var ribbon := panel(Vector2(0,0),Vector2(5,252),accent,card)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label(mode.name,Vector2(18,107),24,TEXT,card)
		var active_lesson := Vocabulary.lesson(lessons[lesson_index],vocabulary_topic)
		var examples: String = "  /  ".join(active_lesson.words.slice(0,3))
		if examples.length()>25:
			examples = str(active_lesson.words[0])
		label("输入："+examples,Vector2(18,145),17,GOLD,card)
		var rule := label(mission_goal(mode.id,purpose),Vector2(18,172),15,MUTED,card)
		rule.size = Vector2(314,22)
		rule.clip_text = true
		rule.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var enter := button("进入挑战  →" if purpose=="challenge" else "开始训练  →",Vector2(18,198),Vector2(314,44),func(): start_game(mode.id,purpose),false,card)
		enter.name = "Mission_"+str(mode.id)
		enter.focus_entered.connect(func():
			card.add_theme_stylebox_override("panel",PlayTheme.game_panel(Color("fffdf0"),PlayTheme.PRIMARY,22,5))
			mascot.reduced_motion = store.data.settings.reduced_motion)
		enter.focus_exited.connect(func():
			card.add_theme_stylebox_override("panel",style(PANEL))
			mascot.reduced_motion = true)

func show_training_games() -> void:
	page = "training_games"
	run = null
	clear_ui()
	navigation("lessons")
	label("选择训练任务",Vector2(300,46),34)
	label(lessons[lesson_index].name,Vector2(300,106),22,MINT)
	speed_controls(Vector2(300,176))
	var order := ["moles","balloons","aliens","racing","fighter","dojo","bubbles","rain","sprint","castle"]
	var modes := GameContent.modes()
	modes.sort_custom(func(a,b): return order.find(a.id)<order.find(b.id))
	game_grid(modes,Vector2(300,238),Vector2(1100,548),"training")
	button("返回课程",Vector2(300,807),Vector2(180,46),show_lessons)
	vocabulary_button(Vector2(930,807))

func show_challenges() -> void:
	page = "challenges"
	run = null
	clear_ui()
	navigation("challenges")
	label("挑战准备",Vector2(300,48),36)
	panel(Vector2(300,130),Vector2(1090,84))
	label("挑战文本",Vector2(324,153),21,MINT)
	var selector := OptionButton.new()
	selector.position = Vector2(520,148)
	selector.size = Vector2(845,45)
	for lesson in lessons:
		selector.add_item(lesson.name)
	selector.selected = lesson_index
	selector.item_selected.connect(func(index):
		lesson_index=index
		store.data.last_lesson=index
		store.save_profile()
		show_challenges())
	layer.add_child(selector)
	var modes := GameContent.modes().filter(func(m): return m.id not in ["dojo","bubbles"])
	for i in range(3):
		var index := i
		button(SessionOptions.RANK_NAMES[i]+"  "+str(SessionOptions.RANK_SPEEDS[i])+"×",Vector2(300+i*184,235),Vector2(172,46),func(): select_rank(index),i==challenge_index).name = "ChallengeRank%d" % i
	game_grid(modes,Vector2(300,298),Vector2(1100,520),"challenge")
	vocabulary_button(Vector2(1010,829))

func vocabulary_button(at: Vector2) -> void:
	var active := Vocabulary.supports(lessons[lesson_index])
	var title := "KET 词库 · 709 词 / 24 主题" if active else "KET 词库 · 第 6 课起使用"
	if active and vocabulary_topic!="mixed":
		for topic in Vocabulary.topics():
			if topic.id==vocabulary_topic:
				title = "KET 主题 · "+str(topic.name)+"  ▾"
	button(title,at,Vector2(360,43),show_vocabulary,active).name = "VocabularySettings"

func show_vocabulary() -> void:
	var root := modal()
	var dialog := Control.new()
	dialog.position = Vector2(370,175)
	dialog.size = Vector2(700,550)
	root.add_child(dialog)
	label("把单词带进冒险",Vector2(38,24),32,TEXT,dialog)
	label("709 个核心词 · 48 条短句 · 24 个生活主题",Vector2(38,80),19,MINT,dialog)
	label("基础指法不变；单词、大小写和句子课程使用这里的主题。",Vector2(38,117),17,MUTED,dialog)
	var selector := OptionButton.new()
	selector.name = "VocabularyTopic"
	selector.position = Vector2(38,168)
	selector.size = Vector2(624,54)
	var topics := Vocabulary.topics()
	for i in range(topics.size()):
		var count: int = Vocabulary.data().entries.filter(func(e): return e.kind=="word" and (topics[i].id=="mixed" or e.topic==topics[i].id)).size()
		selector.add_item(str(topics[i].name)+"  /  %d 词" % count)
		if topics[i].id==vocabulary_topic:
			selector.selected = i
	selector.item_selected.connect(func(index):
		vocabulary_topic = topics[index].id
		store.data.settings.vocabulary_topic = vocabulary_topic
		store.save_profile()
		close_modal()
		if page=="challenges":
			show_challenges()
		else:
			show_training_games())
	dialog.add_child(selector)
	label("短词：2–4 字母 → 长词：5–12 字母 → 大小写 → 完整短句",Vector2(38,255),18,TEXT,dialog)
	label("输入区显示中文词义，完成后回顾。主题成绩单独记录。\n词汇独立编写，参照 Cambridge A2 Key 2025 词表范围。",Vector2(38,302),17,MUTED,dialog)
	button("返回继续",Vector2(38,394),Vector2(624,52),close_modal,true,dialog)
	selector.grab_focus()

func show_lessons() -> void:
	page = "lessons"
	run = null
	clear_ui()
	navigation("lessons")
	label("先选今天要学的按键",Vector2(300,48),36)
	button("先学手指摆放",Vector2(1180,54),Vector2(210,46),show_fingering)
	for i in range(lessons.size()):
		var col := i % 2
		var row := i / 2
		var x := 300+col*550
		var y := 168+row*119
		var lesson: Dictionary = lessons[i]
		panel(Vector2(x,y),Vector2(530,103),Color("e5f0ff") if i == lesson_index else PANEL)
		var stamp := CourseStamp.new()
		stamp.position = Vector2(x+17,y+22)
		stamp.number = i+1
		stamp.mastered = store.data.completed.has(lesson.id)
		stamp.active = i==lesson_index
		layer.add_child(stamp)
		label(str(lesson.name).substr(5),Vector2(x+86,y+13),21,GOLD if i==lesson_index else TEXT)
		var detail := label(["F / J","D F / J K","A S D F / J K L ;","Q W E R T / Y U I O P","Z X C V B / N M","2–4 字母词","5–12 字母词","数字与字母组合","Shift · 大小写","空格 · 标点 · 短句"][i],Vector2(x+86,y+53),17,MUTED)
		detail.size = Vector2(335,40)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button("已选" if i==lesson_index else "选择",Vector2(x+423,y+13),Vector2(88,40),func(): select_lesson(i),i==lesson_index)
	button("进入本课训练任务  →",Vector2(300,791),Vector2(270,54),show_training_games,true)

func select_lesson(index: int) -> void:
	lesson_index = index
	store.data.last_lesson = index
	store.save_profile()
	show_lessons()

func show_fingering() -> void:
	page = "fingering"
	run = null
	clear_ui()
	navigation("lessons")
	label("让每个手指都有自己的位置。",Vector2(300,48),34)
	label("美式 QWERTY 指法示意 · 可按实体键盘，或点击示例查看手指分工",Vector2(300,111),17,MINT)
	typing_guide = TypingGuide.new()
	typing_guide.position = Vector2(300,177)
	layer.add_child(typing_guide)
	panel(Vector2(630,177),Vector2(760,435))
	label("01  找到基准行",Vector2(660,201),25,GOLD)
	label("左手：小指 A、无名指 S、中指 D、食指 F\n右手：食指 J、中指 K、无名指 L、小指 ;\n两只拇指轻放空格键，F / J 的凸点帮助盲定位。",Vector2(660,249),20)
	label("02  移动一个手指，其他手指自然放松",Vector2(660,357),24,GOLD)
	label("手指自然弯曲，肩膀与手腕放松，击键后回到基准行。\n先练 F / J，再扩展少量键位、连续组合、单词和句子。\n大写和上档符号：另一只手的小指按住 Shift 后击键。",Vector2(660,406),20)
	label("试一试：同色键区由同一个手指负责",Vector2(660,538),19,MINT)
	var samples := ["f","j","a","k","F","?"," "]
	for i in range(samples.size()):
		var value: String = samples[i]
		button("空格" if value==" " else value,Vector2(630+i*108,644),Vector2(94,58),func(): typing_guide.preview_character=value)
	label("示意图用于教学，不会检测你的真实手势。",Vector2(630,735),18,MUTED)
	button("回到课程，开始练习  →",Vector2(630,785),Vector2(375,52),show_lessons,true)

func show_game_guide() -> void:
	if run == null or run.done or guide_open:
		return
	guide_was_paused = run.paused
	if is_instance_valid(overlay):
		close_modal()
	run.paused = true
	guide_open = true
	var root := modal()
	panel(Vector2(300,100),Vector2(840,710),PANEL,root)
	var coach := TypingGuide.new()
	coach.position = Vector2(326,128)
	coach.run = run
	root.add_child(coach)
	label("指法与规则",Vector2(660,151),28,GOLD,root)
	var rules := label("目标："+mission_goal(run.mode,run.context)+"\n\n输入蓝色词牌上的完整文字。\nTab 换目标，退格撤回一字。\n"+("命中三次后，F3 释放技能。\n" if run is ArcadeRun else "")+"\n左手 A S D F · 右手 J K L ;\n拇指轻放空格，F / J 凸点定位。\n高亮手指负责下一个目标键。\n击键后回到基准行，手腕放松。\n\n指法为教学示意，不检测手势。\n帮助打开时，战斗与计时暂停。",Vector2(660,211),19,TEXT,root)
	rules.size = Vector2(430,400)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("摆好了，继续  Esc",Vector2(660,670),Vector2(440,55),close_game_guide,true,root).grab_focus()

func close_game_guide() -> void:
	guide_open = false
	close_modal()
	if run != null:
		run.paused = false
		if guide_was_paused:
			toggle_pause()

func show_profile() -> void:
	page = "profile"
	run = null
	clear_ui()
	navigation("profile")
	label("看见每一次进步。",Vector2(300,48),36)
	label(store.status,Vector2(302,110),18,MINT)
	panel(Vector2(300,174),Vector2(1090,138))
	label("总经验",Vector2(328,194),17,MUTED)
	label(str(int(store.data.xp)),Vector2(328,233),32,GOLD)
	label("已掌握课程",Vector2(650,194),17,MUTED)
	label("%d / 10" % store.data.completed.size(),Vector2(650,233),32,GOLD)
	label("已有成绩组合",Vector2(1000,194),17,MUTED)
	label(str(store.data.records.size()),Vector2(1000,233),32,GOLD)
	label("值得再练的按键",Vector2(300,349),25)
	var stats: Array = []
	for key in store.data.key_stats:
		var value: Dictionary = store.data.key_stats[key]
		if value.miss > 0:
			stats.append({"key":key,"miss":value.miss,"hit":value.hit})
	stats.sort_custom(func(a,b): return float(a.miss)/maxf(1,a.hit+a.miss) > float(b.miss)/maxf(1,b.hit+b.miss))
	if stats.is_empty():
		label("暂未记录易错键。继续练习，保持准确。",Vector2(300,400),19,MUTED)
	for i in range(mini(8,stats.size())):
		panel(Vector2(300+i*137,402),Vector2(121,100))
		label("空格" if stats[i].key==" " else stats[i].key,Vector2(320+i*137,411),28,GOLD)
		label("错误 %d 次" % stats[i].miss,Vector2(312+i*137,462),14,MUTED)
	label("声音与偏好",Vector2(300,537),25)
	volume_control("音乐音量","music_volume",Vector2(300,586))
	volume_control("音效音量","sfx_volume",Vector2(850,586))
	label("进度保存在当前浏览器；请定期导出备份。战斗中途状态不保存。",Vector2(300,643),16,MUTED)
	button("导出存档备份",Vector2(300,688),Vector2(210,52),export_save,true)
	button("导入存档备份",Vector2(530,688),Vector2(210,52),show_import)
	button("减少动态效果："+("开" if store.data.settings.reduced_motion else "关"),Vector2(760,688),Vector2(270,52),func(): store.data.settings.reduced_motion = not store.data.settings.reduced_motion; store.save_profile(); show_profile())
	if not OS.has_feature("web"):
		button("打开存档目录",Vector2(1050,688),Vector2(220,52),func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	label("备份文件名：keybound-backup.json。导入时打开文件，复制内容后粘贴即可。",Vector2(300,772),16,MUTED)
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		label("当前浏览器未允许持久化，请使用导出备份保存进度。",Vector2(300,817),18,GOLD)

func volume_control(title: String, setting: String, at: Vector2) -> void:
	label(title,at,18,TEXT)
	var slider := HSlider.new()
	slider.name = "MusicVolume" if setting=="music_volume" else "SfxVolume"
	slider.position = at+Vector2(110,-2)
	slider.size = Vector2(315,38)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(store.data.settings.get(setting,.45 if setting=="music_volume" else .7))*100
	layer.add_child(slider)
	var amount := label("%d%%" % int(slider.value),at+Vector2(440,0),18,MINT)
	slider.value_changed.connect(func(value):
		store.data.settings[setting] = value/100.0
		soundscape.apply_settings()
		amount.text = "%d%%" % int(value)
		store.save_profile())

func export_save() -> void:
	var value := JSON.stringify(store.data,"\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(value.to_utf8_buffer(),"keybound-backup.json","application/json")
		store.status = "已请求浏览器下载存档备份"
	else:
		var file := FileAccess.open("user://keybound-backup.json",FileAccess.WRITE)
		if file:
			file.store_string(value)
			file.close()
			store.status = "备份已保存，可点击「打开存档目录」找到备份文件。"
		else:
			store.status = "备份失败，请检查目录权限"
	show_profile()

func modal() -> Control:
	previous_focus = get_viewport().gui_get_focus_owner()
	for control in layer.find_children("*", "Control", true, false):
		if control.focus_mode!=Control.FOCUS_NONE:
			modal_focus[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.28,0.38,0.56,0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	panel(Vector2(370,175),Vector2(700,550),PANEL,root)
	overlay = root
	return root

func close_modal() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	for control in modal_focus:
		if is_instance_valid(control):
			control.focus_mode = modal_focus[control]
	modal_focus.clear()
	if is_instance_valid(previous_focus) and previous_focus.is_inside_tree():
		previous_focus.grab_focus()
	else:
		ensure_keyboard_focus.call_deferred()

func show_import() -> void:
	var root := modal()
	label("恢复存档备份",Vector2(410,211),30,TEXT,root)
	label("粘贴备份文件中的 JSON。导入将替换当前学习进度。",Vector2(410,269),18,MUTED,root)
	var input := TextEdit.new()
	input.position = Vector2(410,320)
	input.size = Vector2(620,260)
	input.placeholder_text = "在这里粘贴 JSON 存档内容"
	root.add_child(input)
	var error := label("",Vector2(410,589),16,GOLD,root)
	button("验证并恢复",Vector2(410,646),Vector2(240,48),func():
		if store.import_text(input.text):
			lesson_index = int(store.data.last_lesson)
			show_profile()
		else:
			error.text = "无法恢复：格式或版本不兼容，或写入失败。当前进度未变更。",true,root)
	button("取消",Vector2(680,646),Vector2(160,48),close_modal,false,root)
	input.grab_focus()

func start_game(mode: String, purpose := "training") -> void:
	page = "game"
	session_context = purpose
	clear_ui()
	run = CastleRun.new() if mode == "castle" else (ArcadeRun.new() if mode in ArcadeRun.MODES else GameRun.new())
	run.context = purpose
	run.challenge_rank = SessionOptions.RANK_IDS[challenge_index] if purpose=="challenge" else "normal"
	run.setup(mode,Vocabulary.lesson(lessons[lesson_index],vocabulary_topic),pace if purpose=="training" else SessionOptions.RANK_SPEEDS[challenge_index])
	soundscape.bind_run(run)
	run.ended.connect(finish_game)
	var title := ""
	for definition in GameContent.modes():
		if definition.id == mode:
			title = definition.name
	label("指尖 / " + title,Vector2(40,24),28,GOLD)
	label(("训练 %.2f× / " % pace if purpose=="training" else "挑战 · "+SessionOptions.RANK_NAMES[challenge_index]+" / ")+lessons[lesson_index].name,Vector2(40,75),17,MUTED)
	hud = label("",Vector2(500,35),22,TEXT)
	hud.visible = false
	live_hud = LiveHud.new()
	live_hud.reduced_motion = store.data.settings.reduced_motion
	live_hud.position = Vector2(430,14)
	live_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(live_hud)
	pause_button = button("暂停  Esc",Vector2(1230,28),Vector2(170,48),toggle_pause)
	pause_button.focus_mode = Control.FOCUS_NONE
	var arena: GameArena = CastleArena.new() if mode == "castle" else (ArcadeArena.new() if run is ArcadeRun else GameArena.new())
	arena.position = Vector2(40,120)
	arena.size = Vector2(1040,650) if mode=="castle" or run is ArcadeRun else Vector2(1360,650)
	if not run is CastleRun and not run is ArcadeRun:
		arena.scale = Vector2.ONE * (1040.0/1360.0)
	arena.run = run
	arena.reduced_motion = store.data.settings.reduced_motion
	layer.add_child(arena)
	if mode != "castle":
		typing_guide = TypingGuide.new()
		typing_guide.position = Vector2(1100,120)
		typing_guide.run = run
		layer.add_child(typing_guide)
		if not run is ArcadeRun:
			var ledger := TrainingLedger.new()
			ledger.position = Vector2(40,630)
			ledger.run = run
			layer.add_child(ledger)
	if mode == "castle":
		castle_panel = CastlePanel.new()
		castle_panel.position = Vector2(1110,120)
		castle_panel.app = self
		castle_panel.battle = run
		layer.add_child(castle_panel)
		arena.pad_selected.connect(func(_index): castle_panel.rebuild())
	if run!=null:
		castle_audio = CastleAudio.new()
		castle_audio.battle = run
		castle_audio.enabled = store.data.settings.get("sound",true)
		layer.add_child(castle_audio)
		sound_button = button("F2 声音开" if castle_audio.enabled else "F2 声音关",Vector2(1318,82),Vector2(82,34),toggle_sound)
		sound_button.add_theme_font_size_override("font_size",14)
		sound_button.focus_mode = Control.FOCUS_NONE
	var guide_button := button("F1 帮助" if mode=="castle" else "F1 指法与规则",Vector2(1230,82) if mode=="castle" else Vector2(1100,720),Vector2(80,44) if mode=="castle" else Vector2(300,44),show_game_guide)
	guide_button.add_theme_font_size_override("font_size",14)
	guide_button.focus_mode = Control.FOCUS_NONE
	hint = label("",Vector2(42,798),20,MINT)
	hint.visible = false
	var cue := ActionCue.new()
	cue.position = Vector2(40,780)
	cue.reduced_motion = store.data.settings.reduced_motion
	cue.name = "InputDock"
	cue.size = Vector2(1360,108)
	cue.run = run
	layer.add_child(cue)
	update_hud()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode==KEY_F2 and page!="game" and not is_instance_valid(overlay):
		toggle_sound()
		get_viewport().set_input_as_handled()
		return
	if page == "game" and run != null and run.done and event.keycode == KEY_ESCAPE:
		show_home()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and page != "game":
		if is_instance_valid(overlay):
			close_modal()
		elif page in ["training_games", "fingering"]:
			show_lessons()
		else:
			show_home()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_TAB and (page != "game" or is_instance_valid(overlay) or (run is CastleRun and run.phase == "build")):
		cycle_keyboard_focus(-1 if event.shift_pressed else 1)
		get_viewport().set_input_as_handled()
		return
	if page == "fingering" and event is InputEventKey and event.pressed and event.unicode >= 32 and event.unicode <= 126 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		typing_guide.preview_character = String.chr(event.unicode)
		get_viewport().set_input_as_handled()
		return
	if page != "game" or run == null or run.done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			if guide_open:
				close_game_guide()
			else:
				show_game_guide()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F2:
			toggle_sound()
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_F3 and run is ArcadeRun and not guide_open and not is_instance_valid(overlay):
			run.activate_skill()
			get_viewport().set_input_as_handled()
			return
		if guide_open:
			if event.keycode == KEY_ESCAPE:
				close_game_guide()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
		elif run.paused:
			return
		elif not run.allows_typing():
			if run is CastleRun and castle_build_key(event.keycode):
				get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BACKSPACE:
			run.backspace()
		elif event.keycode == KEY_TAB:
			run.cancel_target()
		elif event.unicode >= 32 and event.unicode <= 126 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			run.type_character(String.chr(event.unicode))
		get_viewport().set_input_as_handled()

func toggle_sound() -> void:
	var enabled: bool = not store.data.settings.get("sound",true)
	if is_instance_valid(castle_audio):
		castle_audio.enabled = enabled
	store.data.settings.sound = enabled
	soundscape.apply_settings()
	store.save_profile()
	if is_instance_valid(sound_button):
		sound_button.text = "F2 声音开" if enabled else "F2 声音关"

func keyboard_controls() -> Array[Control]:
	var root: Control = overlay if is_instance_valid(overlay) else layer
	var controls: Array[Control] = []
	for node in root.find_children("*", "Control", true, false):
		if node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree() and not node.is_queued_for_deletion():
			if node is BaseButton and node.disabled:
				continue
			controls.append(node)
	return controls

func ensure_keyboard_focus() -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	var controls := keyboard_controls()
	if not controls.is_empty():
		controls[0].grab_focus()

func cycle_keyboard_focus(direction: int) -> void:
	var controls := keyboard_controls()
	if controls.is_empty():
		return
	var index := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(index+direction,controls.size())].grab_focus()

func castle_build_key(key: int) -> bool:
	if key >= KEY_1 and key <= KEY_4:
		run.selected_pad = key-KEY_1
		castle_panel.rebuild()
	elif key in [KEY_Q, KEY_W, KEY_E]:
		run.build_tower(run.selected_pad,{KEY_Q:"fire",KEY_W:"ice",KEY_E:"storm"}[key])
	elif key == KEY_U:
		run.upgrade_tower(run.selected_pad)
	elif key in [KEY_A,KEY_S,KEY_D]:
		run.purchase_upgrade({KEY_A:"power",KEY_S:"chain",KEY_D:"walls"}[key])
	elif key == KEY_R:
		run.repair()
	elif key == KEY_N:
		run.begin_wave()
	else:
		return false
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and run != null and not run.paused and not run.done:
		toggle_pause()

func _process(delta: float) -> void:
	if page == "game" and run != null:
		run.step(delta)
		update_hud()
	if not captured and ("--preview" in OS.get_cmdline_user_args() or "--preview-castle" in OS.get_cmdline_user_args()):
		captured = true
		capture_preview.call_deferred()

func capture_preview() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var filename := "castle-preview.png" if "--preview-castle" in OS.get_cmdline_user_args() else "home-preview.png"
	get_viewport().get_texture().get_image().save_png("res://build/"+filename)
	get_tree().quit()

func update_hud() -> void:
	if not is_instance_valid(hud) or run == null:
		return
	if is_instance_valid(live_hud):
		live_hud.refresh(run)
	var progress := "第 %d / 6 波" % run.wave
	if run.mode in ["dojo","bubbles"]:
		progress = "%d / 18 目标" % run.kills
	elif run.mode == "rain":
		progress = "剩余 %d 秒" % maxi(0,ceili(90-run.elapsed))
	elif run.mode == "sprint":
		progress = "剩余 %d 秒" % maxi(0,ceili(60-run.elapsed))
	elif run is ArcadeRun:
		progress = "%d / %d · %s" % [run.kills,run.goal,run.status_text()]
		if run.mode == "racing":
			progress = run.status_text()
	hud.add_theme_font_size_override("font_size",18 if run is ArcadeRun else 22)
	hud.text = "%s    %s    准确 %d%%    连击 %d" % [progress,"城防 %d" % run.hp if run.mode in ["castle","rain"] else "得分 %d" % run.score,roundi(run.accuracy()*100),run.combo]
	hint.text = run.feedback

func toggle_pause() -> void:
	if guide_open:
		close_game_guide()
		return
	if run == null or run.done:
		return
	if run.paused:
		run.paused = false
		close_modal()
		return
	run.paused = true
	var root := modal()
	label("休息一下，冒险等你回来。",Vector2(410,227),30,TEXT,root)
	label("计时与敌人已暂停。\n\n准备好后，双手回到 F / J 定位键。\n离开本局不会保存本局成绩。",Vector2(410,310),20,MUTED,root)
	button("继续挑战" if session_context=="challenge" else "继续训练",Vector2(410,524),Vector2(620,54),toggle_pause,true,root).grab_focus()
	button("返回训练与挑战",Vector2(410,602),Vector2(620,48),show_home,false,root)

func finish_game() -> void:
	store.record_run(run,lesson_index)
	var root := modal()
	var seal := ResultSeal.new()
	seal.position = Vector2(955,200)
	seal.stars = (1 if run.accuracy()<.9 else 2 if run.accuracy()<.98 else 3) if run.won else 0
	seal.reduced_motion = store.data.settings.reduced_motion
	root.add_child(seal)
	label("完成啦！给自己一个赞！" if run.won else "再试一次，你会更熟练！",Vector2(410,213),30,GOLD,root)
	label("%d" % run.score,Vector2(410,328),44,TEXT,root)
	label("得分",Vector2(412,391),16,MUTED,root)
	label("%d%%" % roundi(run.accuracy()*100),Vector2(620,328),44,MINT,root)
	label("准确率",Vector2(623,391),16,MUTED,root)
	label("%.1f" % run.wpm(),Vector2(850,328),44,GOLD,root)
	label("有效 WPM",Vector2(853,391),16,MUTED,root)
	label("最高连击 %d   ·   击破 %d   ·   +%d XP" % [run.best_combo,run.kills,run.kills*5],Vector2(410,455),20,TEXT,root)
	if run is CastleRun:
		label("统领 %d / 2   ·   建造 %d 座塔   ·   抵达第 %d 波" % [run.bosses_defeated,run.towers.size(),run.wave],Vector2(410,485),16,GOLD,root)
	label(store.status,Vector2(410,521),16,MUTED,root)
	var mode := run.mode
	var mastered: bool = session_context=="training" and run.won and run.accuracy()>=0.9 and run.correct>=18 and lesson_index<lessons.size()-1
	button("继续下一课  →" if mastered else "再练一次",Vector2(410,563),Vector2(290,54),continue_training if mastered else func(): start_game(mode,session_context),true,root).grab_focus()
	button("选择其他训练" if session_context=="training" else "选择其他挑战",Vector2(720,563),Vector2(310,54),show_training_games if session_context=="training" else show_challenges,false,root)
	if session_context=="training" and run.won:
		label("已掌握本课" if run.accuracy()>=.9 and run.correct>=18 else "掌握目标：准确率 90%，有效输入 18 字符",Vector2(410,657),18,MINT,root)
