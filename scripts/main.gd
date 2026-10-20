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
var pause_button: Button
var captured := false
var modal_focus: Dictionary = {}
var screen_stack: Array[Dictionary] = []
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
	screen_stack.clear()
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
		stage.settings_room = page=="profile"
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
	item.theme_type_variation = "PrimaryButton" if primary else "Button"
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if parent is Container:
		item.custom_minimum_size = dimensions
		item.size_flags_horizontal = Control.SIZE_FILL
	item.pressed.connect(func():
		if is_instance_valid(soundscape):
			soundscape.cue("confirm",-18)
		callback.call())
	parent.add_child(item)
	item.pivot_offset = dimensions/2
	item.mouse_entered.connect(func(): animate_button(item,1.012))
	item.mouse_exited.connect(func(): animate_button(item,1.0))
	item.focus_entered.connect(func(): animate_button(item,1.012))
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
	var row := UiLayout.row(parent,12)
	row.position = at
	var title := UiLayout.text(row,"训练速度",18)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(SessionOptions.SPEEDS.size()):
		var index := i
		button(SessionOptions.SPEED_NAMES[i],Vector2.ZERO,Vector2(176,48),func(): select_speed(index),is_equal_approx(pace,SessionOptions.SPEEDS[i]),row).name = "TrainingSpeed%d" % i

func menu_content() -> VBoxContainer:
	var safe := UiLayout.margin(layer,0)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:
		safe.add_theme_constant_override("margin_"+side,{"left":300,"top":48,"right":50,"bottom":40}[side])
	return UiLayout.column(safe,24)

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
	var rail := MarginContainer.new()
	rail.name = "NavigationRail"
	rail.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = 24
	rail.offset_top = 40
	rail.offset_right = 238
	rail.offset_bottom = -40
	layer.add_child(rail)
	var stack := UiLayout.column(rail,16)
	var brand := UiLayout.text(stack,"指尖挑战",32)
	brand.add_theme_color_override("font_outline_color",Color("eff9f2"))
	brand.add_theme_constant_override("outline_size",4)
	UiLayout.space(stack,52)
	button("打字训练",Vector2.ZERO,Vector2(208,60),show_lessons,active=="lessons",stack).name = "TrainingNav"
	button("打字挑战",Vector2.ZERO,Vector2(208,60),show_challenges,active=="challenges",stack).name = "ChallengeNav"
	UiLayout.space(stack,0,true)
	var badge := add_badge("moles",Vector2.ZERO,Vector2(200,160),stack)
	badge.custom_minimum_size = Vector2(200,160)
	var progress := UiLayout.column(UiLayout.margin(UiLayout.card(stack,Color("f0f8ff")),16),8)
	UiLayout.text(progress,"Lv. %02d  ·  %d XP" % [1+int(store.data.xp/100),store.data.xp],19)
	UiLayout.text(progress,"已掌握 %d / 10 节" % store.data.completed.size(),16,MINT)
	button("存档与设置",Vector2.ZERO,Vector2(194,48),show_profile,false,stack).name = "ProfileUtility"
	sound_button = button("F2 声音开" if store.data.settings.get("sound",true) else "F2 声音关",Vector2.ZERO,Vector2(194,44),toggle_sound,false,stack)


func show_home() -> void:
	page = "home"
	run = null
	clear_ui()
	var safe := UiLayout.margin(layer,40)
	safe.name = "HomeLayout"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := UiLayout.column(safe,24)
	var header := UiLayout.row(stack,12)
	var brand := UiLayout.text(header,"指尖挑战",32)
	brand.add_theme_color_override("font_outline_color",Color("eff9f2"))
	brand.add_theme_constant_override("outline_size",6)
	UiLayout.space(header,0,true)
	button("存档与设置",Vector2.ZERO,Vector2(172,48),show_profile,false,header).name = "ProfileUtility"
	sound_button = button("F2 声音开" if store.data.settings.get("sound",true) else "F2 声音关",Vector2.ZERO,Vector2(140,48),toggle_sound,false,header)
	var welcome := UiLayout.column(stack,4)
	var title := UiLayout.text(welcome,"小手就位，冒险开打！",42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := UiLayout.text(welcome,"从第一个按键，到流畅的单词连击",21,MINT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cards := UiLayout.row(stack,24)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(2):
		var card := UiLayout.card(cards,Color("d7eee0") if i==0 else Color("d7eafa"))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiLayout.illustrate(card,"res://assets/generated/"+("moles-background" if i==0 else "aliens-background")+".png",Color("d7eee0") if i==0 else Color("d7eafa"))
		var content := UiLayout.column(UiLayout.margin(card,24),12)
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(center)
		var badge := add_badge("moles" if i==0 else "aliens",Vector2.ZERO,Vector2(360,220),center)
		badge.custom_minimum_size = Vector2(360,220)
		UiLayout.text(content,"打字训练" if i==0 else "打字挑战",34)
		UiLayout.text(content,"从 F / J 开始，逐步练习单词。" if i==0 else "选好难度，用连击改变战局。",20,MUTED)
		var launch := button("继续训练  →" if i==0 else "选择挑战  →",Vector2.ZERO,Vector2(0,60),begin_recommended_training if i==0 else show_challenges,i==0,content)
		launch.name = "StartTraining" if i==0 else "StartChallenge"
		if i==0:
			launch.grab_focus()
	var footer := UiLayout.row(UiLayout.margin(UiLayout.card(stack,Color("d7eee0")),20),20)
	var next_course := UiLayout.column(footer,4)
	UiLayout.text(next_course,"继续成长 · "+str(lessons[lesson_index].name),22)
	UiLayout.text(next_course,"已掌握 %d / 10 节" % store.data.completed.size(),17,MINT)
	UiLayout.space(footer,0,true)
	UiLayout.text(footer,"Lv. %02d  ·  %d XP" % [1+int(store.data.xp/100),store.data.xp],22)


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

func game_grid(modes: Array, at: Vector2, dimensions: Vector2, purpose: String, parent: Control = layer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "GameCollection"
	scroll.position = at
	scroll.size = dimensions
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	parent.add_child(scroll)
	if parent is Container:
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for definition in modes:
		var mode: Dictionary = definition
		var card := UiLayout.card(grid,PlayTheme.PASTELS[GameContent.modes().find(definition)%5])
		card.custom_minimum_size = Vector2(350,290)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content := UiLayout.column(UiLayout.margin(card,14),10)
		var art := Control.new()
		art.custom_minimum_size.y = 116
		art.clip_contents = true
		content.add_child(art)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = load("res://assets/generated/"+("balloons-background-v2" if mode.id=="balloons" else str(mode.id)+"-background")+".png")
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var mascot := add_badge(mode.id,Vector2.ZERO,Vector2(160,112),art)
		mascot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mascot.offset_left = -80
		mascot.offset_top = -56
		mascot.offset_right = 80
		mascot.offset_bottom = 56
		mascot.reduced_motion = true
		UiLayout.text(content,mode.name,24)
		var rule := UiLayout.text(content,mission_goal(mode.id,purpose),16,MUTED)
		rule.custom_minimum_size.y = 46
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiLayout.space(content,0,true)
		var enter := button("进入挑战  →" if purpose=="challenge" else "开始训练  →",Vector2.ZERO,Vector2(0,46),func(): start_game(mode.id,purpose),false,content)
		enter.name = "Mission_"+str(mode.id)
		enter.focus_entered.connect(func():
			card.add_theme_stylebox_override("panel",PlayTheme.surface(Color("f5f9ff"),PlayTheme.PRIMARY,20))
			mascot.reduced_motion = store.data.settings.reduced_motion)
		enter.focus_exited.connect(func():
			card.add_theme_stylebox_override("panel",PlayTheme.surface(PlayTheme.PASTELS[GameContent.modes().find(definition)%5]))
			mascot.reduced_motion = true)


func show_training_games() -> void:
	page = "training_games"
	run = null
	clear_ui()
	navigation("lessons")
	var content := menu_content()
	UiLayout.text(content,"选择训练任务",34)
	UiLayout.text(content,lessons[lesson_index].name,22,MINT)
	speed_controls(Vector2.ZERO,content)
	var order := ["moles","balloons","aliens","racing","fighter","dojo","bubbles","rain","sprint","castle"]
	var modes := GameContent.modes()
	modes.sort_custom(func(a,b): return order.find(a.id)<order.find(b.id))
	game_grid(modes,Vector2.ZERO,Vector2.ZERO,"training",content)
	var footer := UiLayout.row(content,16)
	button("返回课程",Vector2.ZERO,Vector2(180,48),show_lessons,false,footer)
	UiLayout.space(footer,0,true)
	vocabulary_button(Vector2.ZERO,footer)

func show_challenges() -> void:
	page = "challenges"
	run = null
	clear_ui()
	navigation("challenges")
	var content := menu_content()
	UiLayout.text(content,"挑战准备",36)
	var setup := UiLayout.row(content,16)
	var text_label := UiLayout.text(setup,"挑战文本",21,MINT)
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = 48
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lesson in lessons:
		selector.add_item(lesson.name)
	selector.selected = lesson_index
	selector.item_selected.connect(func(index):
		lesson_index=index
		store.data.last_lesson=index
		store.save_profile()
		show_challenges())
	setup.add_child(selector)
	var ranks := UiLayout.row(content,12)
	for i in range(3):
		var index := i
		button(SessionOptions.RANK_NAMES[i]+"  "+str(SessionOptions.RANK_SPEEDS[i])+"×",Vector2.ZERO,Vector2(200,48),func(): select_rank(index),i==challenge_index,ranks).name = "ChallengeRank%d" % i
	var modes := GameContent.modes().filter(func(m): return m.id not in ["dojo","bubbles"])
	game_grid(modes,Vector2.ZERO,Vector2.ZERO,"challenge",content)
	var footer := UiLayout.row(content)
	UiLayout.space(footer,0,true)
	vocabulary_button(Vector2.ZERO,footer)

func vocabulary_button(at: Vector2, parent: Control = layer) -> void:
	var active := Vocabulary.supports(lessons[lesson_index])
	var title := "KET 词库 · 709 词 / 24 主题" if active else "KET 词库 · 第 6 课起使用"
	if active and vocabulary_topic!="mixed":
		for topic in Vocabulary.topics():
			if topic.id==vocabulary_topic:
				title = "KET 主题 · "+str(topic.name)+"  ▾"
	button(title,at,Vector2(360,48),show_vocabulary,active,parent).name = "VocabularySettings"

func show_vocabulary() -> void:
	var content := dialog_content(modal(),780)
	UiLayout.text(content,"把单词带进冒险",32)
	UiLayout.text(content,"709 个核心词 · 48 条短句 · 24 个生活主题",20,MINT)
	var selector := OptionButton.new()
	selector.name = "VocabularyTopic"
	selector.custom_minimum_size = Vector2(700,56)
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
	content.add_child(selector)
	UiLayout.text(content,"短词 → 长词 → 大小写 → 完整短句",21)
	UiLayout.text(content,"第 6 课起使用主题词汇，基础指法课程保持原有键位。",18,MUTED)
	UiLayout.text(content,"独立编写，参照 Cambridge A2 Key 2025 词表范围。",16,MUTED)
	button("返回继续",Vector2.ZERO,Vector2(700,54),close_modal,true,content)
	selector.grab_focus()

func show_lessons() -> void:
	page = "lessons"
	run = null
	clear_ui()
	navigation("lessons")
	var safe := UiLayout.margin(layer,0)
	safe.name = "CourseLayout"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:
		safe.add_theme_constant_override("margin_"+side,{"left":300,"top":48,"right":50,"bottom":48}[side])
	var content := UiLayout.column(safe,24)
	var header := UiLayout.row(content,16)
	UiLayout.text(header,"今天，练好一组按键",34)
	UiLayout.space(header,0,true)
	button("学习手指摆放",Vector2.ZERO,Vector2(200,48),show_fingering,false,header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",14)
	content.add_child(grid)
	for i in range(lessons.size()):
		var lesson: Dictionary = lessons[i]
		var selected: bool = i==lesson_index
		var tint: Color = [Color("d4ede7"),Color("d9e8fa"),Color("f4e7ba"),Color("e8dcf5"),Color("d8eddf")][int(i/2)]
		var card := UiLayout.card(grid,tint.lightened(.12) if selected else tint)
		if selected:
			card.add_theme_stylebox_override("panel",PlayTheme.surface(tint,PlayTheme.PRIMARY,20))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var row := UiLayout.row(UiLayout.margin(card,16),14)
		var stamp := CourseStamp.new()
		stamp.custom_minimum_size = Vector2(56,60)
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stamp.number = i+1
		stamp.mastered = store.data.completed.has(lesson.id)
		stamp.active = selected
		row.add_child(stamp)
		var copy := UiLayout.column(row,6)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiLayout.text(copy,str(lesson.name).substr(5),21,GOLD if selected else TEXT)
		var detail := UiLayout.text(copy,["F / J","D F / J K","A S D F / J K L ;","Q W E R T / Y U I O P","Z X C V B / N M","2–4 字母词","5–12 字母词","数字与字母组合","Shift · 大小写","空格 · 标点 · 短句"][i],16,MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var select := button("✓ 已选" if selected else "选择",Vector2.ZERO,Vector2(92,46),func(): select_lesson(i),selected,row)
		select.name = "Course%d" % i
		select.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var footer := UiLayout.row(content,16)
	button("进入本课训练任务  →",Vector2.ZERO,Vector2(300,56),show_training_games,true,footer).name = "EnterTrainingTasks"
	UiLayout.space(footer,0,true)
	UiLayout.text(footer,"%02d / 10  ·  %s" % [lesson_index+1,str(lessons[lesson_index].name).substr(5)],19,MINT)


func select_lesson(index: int) -> void:
	lesson_index = index
	store.data.last_lesson = index
	store.save_profile()
	show_lessons()
	layer.find_child("Course%d" % index,true,false).grab_focus()

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
	run.paused = true
	guide_open = true
	var content := dialog_content(modal(),900)
	var row := UiLayout.row(content,32)
	var coach := TypingGuide.new()
	coach.custom_minimum_size = Vector2(300,580)
	coach.run = run
	row.add_child(coach)
	var copy := UiLayout.column(row,20)
	copy.custom_minimum_size.x = 480
	UiLayout.text(copy,"指法与规则",30,GOLD)
	var goal := UiLayout.text(copy,mission_goal(run.mode,run.context),21,MINT)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rules := UiLayout.text(copy,"输入高亮词牌上的完整文字。\nTab 换目标，退格撤回一字。\n"+("命中三次后，F3 释放技能。\n" if run is ArcadeRun else "")+"\n左手 A S D F · 右手 J K L ;\n拇指轻放空格，F / J 凸点定位。\n高亮手指负责下一个按键。\n击键后回到基准行，手腕放松。",20)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiLayout.space(copy,0,true)
	UiLayout.text(copy,"指法为教学示意，不检测真实手势。",16,MUTED)
	button("摆好了，继续  Esc",Vector2.ZERO,Vector2(0,56),close_game_guide,true,copy).grab_focus()

func close_game_guide() -> void:
	guide_open = false
	close_modal()
	if run != null:
		run.paused = guide_was_paused

func show_profile() -> void:
	page = "profile"
	run = null
	clear_ui()
	navigation("profile")
	var content := menu_content()
	content.add_theme_constant_override("separation",16)
	var title := UiLayout.text(content,"我的冒险营地",32)
	title.add_theme_color_override("font_outline_color",Color("e9f4e4"))
	title.add_theme_constant_override("outline_size",5)
	var ribbon := UiLayout.row(UiLayout.margin(UiLayout.card(content,Color("d6e8cc")),16),32)
	for metric in [[str(int(store.data.xp)),"总经验"],["%d / 10" % store.data.completed.size(),"已掌握课程"],[str(store.data.records.size()),"成绩记录"]]:
		var cell := UiLayout.column(ribbon,4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiLayout.text(cell,metric[0],28,GOLD)
		UiLayout.text(cell,metric[1],17,MUTED)
	var body := UiLayout.row(content,24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var settings := UiLayout.card(body,Color("d5e9e4"))
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls := UiLayout.column(UiLayout.margin(settings,20),12)
	UiLayout.text(controls,"声音与偏好",26)
	volume_control("音乐","music_volume",Vector2.ZERO,controls)
	volume_control("音效","sfx_volume",Vector2.ZERO,controls)
	button("减少动态效果："+("开" if store.data.settings.reduced_motion else "关"),Vector2.ZERO,Vector2(0,48),func(): store.data.settings.reduced_motion = not store.data.settings.reduced_motion; store.save_profile(); show_profile(),false,controls)
	UiLayout.space(controls,0,true)
	var backups := UiLayout.row(controls,12)
	button("导出存档备份",Vector2.ZERO,Vector2(278,50),export_save,true,backups)
	button("导入存档备份",Vector2.ZERO,Vector2(278,50),show_import,false,backups)
	var status := UiLayout.text(controls,store.status,16,MINT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := UiLayout.text(controls,"进度保存在当前浏览器，导出备份可用于恢复。",16,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		UiLayout.text(controls,"浏览器未允许持久化，请导出备份。",17,GOLD)
	var companion_column := UiLayout.column(body,12)
	companion_column.custom_minimum_size.x = 380
	var companion := MenuCompanion.new()
	companion.reduced_motion = store.data.settings.reduced_motion
	companion.custom_minimum_size = Vector2(380,380)
	companion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	companion_column.add_child(companion)
	var cheer := UiLayout.text(companion_column,"每一点进步，都值得庆祝。",22)
	cheer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cheer.add_theme_color_override("font_outline_color",Color("e9f4e4"))
	cheer.add_theme_constant_override("outline_size",4)
	if not OS.has_feature("web"):
		button("打开存档目录",Vector2.ZERO,Vector2(220,46),func(): OS.shell_open(ProjectSettings.globalize_path("user://")),false,companion_column)
	var practice := UiLayout.row(UiLayout.margin(UiLayout.card(content,Color("f2dfac")),12),24)
	var practice_title := UiLayout.text(practice,"值得再练的按键",22)
	practice_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stats: Array = []
	for key in store.data.key_stats:
		var value: Dictionary = store.data.key_stats[key]
		if value.miss>0:
			stats.append({"key":key,"miss":value.miss,"hit":value.hit})
	stats.sort_custom(func(a,b): return float(a.miss)/maxf(1,a.hit+a.miss)>float(b.miss)/maxf(1,b.hit+b.miss))
	var keys := UiLayout.row(practice,12)
	if stats.is_empty():
		UiLayout.text(keys,"暂未记录易错键，继续保持！",18,MUTED)
	for i in range(mini(6,stats.size())):
		var cell := UiLayout.column(UiLayout.margin(UiLayout.card(keys,Color("e5efdc")),8),4)
		UiLayout.text(cell,"空格" if stats[i].key==" " else stats[i].key,26,GOLD)
		UiLayout.text(cell,"错误 %d 次" % stats[i].miss,15,MUTED)

func volume_control(title: String, setting: String, at: Vector2, parent: Control = layer) -> void:
	var row := UiLayout.row(parent,16)
	row.position = at
	var caption := UiLayout.text(row,title,20)
	caption.custom_minimum_size.x = 48
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var slider := HSlider.new()
	slider.name = "MusicVolume" if setting=="music_volume" else "SfxVolume"
	slider.custom_minimum_size = Vector2(240,44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(store.data.settings.get(setting,.45 if setting=="music_volume" else .7))*100
	row.add_child(slider)
	var amount := UiLayout.text(row,"%d%%" % int(slider.value),18,MINT)
	amount.custom_minimum_size.x = 56
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	var covered: Control = overlay if is_instance_valid(overlay) else layer
	var disabled: Dictionary = {}
	for control in covered.find_children("*", "Control", true, false):
		if control.focus_mode!=Control.FOCUS_NONE:
			disabled[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(overlay):
		overlay.hide()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(.09,.2,.31,.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var surface := panel(Vector2(370,175),Vector2(700,550),Color("e4efdd"),root)
	surface.name = "DefaultModalSurface"
	screen_stack.append({"root":root,"focus":previous_focus,"disabled":disabled})
	modal_focus = disabled
	overlay = root
	return root

func close_modal() -> void:
	if screen_stack.is_empty():
		return
	var entry: Dictionary = screen_stack.pop_back()
	entry.root.hide()
	entry.root.queue_free()
	for control in entry.disabled:
		if is_instance_valid(control):
			control.focus_mode = entry.disabled[control]
	overlay = null if screen_stack.is_empty() else screen_stack.back().root
	modal_focus = {} if screen_stack.is_empty() else screen_stack.back().disabled
	if is_instance_valid(overlay):
		overlay.show()
	if is_instance_valid(entry.focus) and entry.focus.is_inside_tree():
		entry.focus.grab_focus()
	else:
		ensure_keyboard_focus.call_deferred()

func dialog_content(root: Control, width := 700) -> VBoxContainer:
	root.get_node("DefaultModalSurface").hide()
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface := UiLayout.card(center,Color("e4efdd"))
	surface.name = "GameDialog"
	surface.custom_minimum_size.x = width
	return UiLayout.column(UiLayout.margin(surface,32),20)

func show_import() -> void:
	var content := dialog_content(modal(),780)
	UiLayout.text(content,"恢复冒险进度",30)
	UiLayout.text(content,"粘贴备份文件内容，导入将替换当前进度。",19,MUTED)
	var input := TextEdit.new()
	input.custom_minimum_size = Vector2(700,260)
	input.placeholder_text = "在这里粘贴 JSON 存档内容"
	content.add_child(input)
	var error := UiLayout.text(content,"",17,Color("a3433a"))
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := UiLayout.row(content,16)
	button("验证并恢复",Vector2.ZERO,Vector2(340,52),func():
		if store.import_text(input.text):
			lesson_index = int(store.data.last_lesson)
			show_profile()
		else:
			error.text = "格式或版本不兼容，或写入失败。当前进度未变更。",true,actions)
	button("取消",Vector2.ZERO,Vector2(340,52),close_modal,false,actions)
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
	var shell := GameShell.new()
	layer.add_child(shell)
	var title_label := UiLayout.text(shell.heading,title,28)
	title_label.name = "GameTitle"
	UiLayout.text(shell.heading,("训练 %.2f× · " % pace if purpose=="training" else "挑战 · "+SessionOptions.RANK_NAMES[challenge_index]+" · ")+str(lessons[lesson_index].name).substr(5),16,MUTED)
	live_hud = LiveHud.new()
	live_hud.reduced_motion = store.data.settings.reduced_motion
	live_hud.custom_minimum_size = Vector2(660,80)
	live_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.header.add_child(live_hud)
	shell.header.move_child(live_hud,1)
	var guide_button := button("F1 指法",Vector2.ZERO,Vector2(88,48),show_game_guide,false,shell.actions)
	guide_button.focus_mode = Control.FOCUS_NONE
	castle_audio = CastleAudio.new()
	castle_audio.battle = run
	castle_audio.enabled = store.data.settings.get("sound",true)
	layer.add_child(castle_audio)
	sound_button = button("F2 声音开" if castle_audio.enabled else "F2 声音关",Vector2.ZERO,Vector2(98,48),toggle_sound,false,shell.actions)
	sound_button.add_theme_font_size_override("font_size",15)
	sound_button.focus_mode = Control.FOCUS_NONE
	pause_button = button("暂停 Esc",Vector2.ZERO,Vector2(116,48),toggle_pause,false,shell.actions)
	pause_button.focus_mode = Control.FOCUS_NONE
	var arena: GameArena = CastleArena.new() if mode == "castle" else (ArcadeArena.new() if run is ArcadeRun else GameArena.new())
	arena.size = Vector2(1040,650) if mode=="castle" or run is ArcadeRun else Vector2(1360,650)
	if not run is CastleRun and not run is ArcadeRun:
		arena.scale = Vector2.ONE * (1040.0/1360.0)
	arena.run = run
	arena.reduced_motion = store.data.settings.reduced_motion
	shell.field.add_child(arena)
	if mode != "castle":
		typing_guide = TypingGuide.new()
		typing_guide.custom_minimum_size = Vector2(300,580)
		typing_guide.run = run
		shell.sidebar.add_child(typing_guide)
		UiLayout.space(shell.sidebar,0,true)
		var session_card := UiLayout.card(shell.sidebar,Color("edf5ff"))
		var info := UiLayout.column(UiLayout.margin(session_card,10),0)
		var goal := UiLayout.text(info,mission_goal(mode,purpose),16,TEXT)
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not run is ArcadeRun:
			var ledger := TrainingLedger.new()
			ledger.position = Vector2(0,510)
			ledger.run = run
			shell.field.add_child(ledger)
	else:
		castle_panel = CastlePanel.new()
		castle_panel.custom_minimum_size = Vector2(300,650)
		castle_panel.app = self
		castle_panel.battle = run
		shell.sidebar.add_child(castle_panel)
		arena.pad_selected.connect(func(_index): castle_panel.rebuild())
	var cue := ActionCue.new()
	cue.reduced_motion = store.data.settings.reduced_motion
	cue.name = "InputDock"
	cue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cue.run = run
	shell.dock.add_child(cue)
	run.hud_changed.connect(request_hud_refresh)
	if run is CastleRun:
		run.phase_changed.connect(request_hud_refresh)
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
	wire_keyboard_neighbors()
	if get_viewport().gui_get_focus_owner() != null:
		return
	var controls := keyboard_controls()
	if not controls.is_empty():
		controls[0].grab_focus()

func wire_keyboard_neighbors() -> void:
	var controls := keyboard_controls()
	for i in range(controls.size()):
		var control := controls[i]
		control.focus_next = control.get_path_to(controls[(i+1)%controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(i-1,controls.size())])
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			var best: Control = control
			var cost := INF
			for candidate in controls:
				var delta := candidate.get_global_rect().get_center()-control.get_global_rect().get_center()
				var axis: float = delta.x if side in [SIDE_LEFT,SIDE_RIGHT] else delta.y
				if (axis<=4 and side in [SIDE_RIGHT,SIDE_BOTTOM]) or (axis>=-4 and side in [SIDE_LEFT,SIDE_TOP]):
					continue
				var cross: float = absf(delta.y) if side in [SIDE_LEFT,SIDE_RIGHT] else absf(delta.x)
				var distance: float = absf(axis)+cross*3
				if distance<cost:
					cost = distance
					best = candidate
			control.set_focus_neighbor(side,control.get_path_to(best))

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
	if not captured and ("--preview" in OS.get_cmdline_user_args() or "--preview-castle" in OS.get_cmdline_user_args()):
		captured = true
		capture_preview.call_deferred()

func capture_preview() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var filename := "castle-preview.png" if "--preview-castle" in OS.get_cmdline_user_args() else "home-preview.png"
	get_viewport().get_texture().get_image().save_png("res://build/"+filename)
	get_tree().quit()

var hud_refresh_pending := false

func request_hud_refresh() -> void:
	if hud_refresh_pending:
		return
	hud_refresh_pending = true
	update_hud.call_deferred()

func update_hud() -> void:
	hud_refresh_pending = false
	if is_instance_valid(live_hud) and run!=null:
		live_hud.refresh(run)

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
	var content := dialog_content(root)
	var header := UiLayout.row(content,20)
	var badge := add_badge(run.mode,Vector2.ZERO,Vector2(110,100),header)
	badge.custom_minimum_size = Vector2(110,100)
	badge.reduced_motion = true
	var copy := UiLayout.column(header,8)
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiLayout.text(copy,"冒险暂停中",32)
	UiLayout.text(copy,"计时与敌人已暂停，随时回来继续。",19,MUTED)
	UiLayout.space(content,8)
	button("继续挑战  Esc" if session_context=="challenge" else "继续训练  Esc",Vector2.ZERO,Vector2(620,56),toggle_pause,true,content).grab_focus()
	button("返回训练与挑战",Vector2.ZERO,Vector2(620,48),show_home,false,content)

func finish_game() -> void:
	store.record_run(run,lesson_index)
	var root := modal()
	var content := dialog_content(root,780)
	var header := UiLayout.row(content,24)
	var seal := ResultSeal.new()
	seal.custom_minimum_size = Vector2(100,116)
	seal.stars = (1 if run.accuracy()<.9 else 2 if run.accuracy()<.98 else 3) if run.won else 0
	seal.reduced_motion = store.data.settings.reduced_motion
	header.add_child(seal)
	var copy := UiLayout.column(header,8)
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiLayout.text(copy,("训练完成，真棒！" if session_context=="training" else "漂亮，完成挑战！") if run.won else "再来一次，突破自己！",32)
	UiLayout.text(copy,"最高连击 %d  ·  击破 %d  ·  +%d XP" % [run.best_combo,run.kills,run.kills*5],20,MINT)
	var metrics := UiLayout.row(content,16)
	for metric in [[str(run.score),"得分"],["%d%%" % roundi(run.accuracy()*100),"准确率"],["%.1f" % run.wpm(),"有效 WPM"]]:
		var tile := UiLayout.card(metrics,Color("d2e8e4"))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := UiLayout.column(UiLayout.margin(tile,18),4)
		UiLayout.text(column,metric[0],38)
		UiLayout.text(column,metric[1],17,MUTED)
	if run is CastleRun:
		UiLayout.text(content,"统领 %d / 2 · 建造 %d 座塔 · 抵达第 %d 波" % [run.bosses_defeated,run.towers.size(),run.wave],18,GOLD)
	if session_context=="training" and run.won:
		UiLayout.text(content,"已掌握本课" if run.accuracy()>=.9 and run.correct>=18 else "掌握目标：准确率 90%，有效输入 18 字符",18,MINT)
	UiLayout.text(content,store.status,16,MUTED)
	var mode := run.mode
	var mastered: bool = session_context=="training" and run.won and run.accuracy()>=.9 and run.correct>=18 and lesson_index<lessons.size()-1
	var actions := UiLayout.row(content,16)
	button("继续下一课  →" if mastered else "再练一次",Vector2.ZERO,Vector2(340,56),continue_training if mastered else func(): start_game(mode,session_context),true,actions).grab_focus()
	button("选择其他训练" if session_context=="training" else "选择其他挑战",Vector2.ZERO,Vector2(340,56),show_training_games if session_context=="training" else show_challenges,false,actions)
