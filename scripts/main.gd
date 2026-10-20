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
	backdrop.color = Color("dfede8") if page=="game" else BG
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
		button(("✓ " if is_equal_approx(pace,SessionOptions.SPEEDS[i]) else "")+SessionOptions.SPEED_NAMES[i],Vector2.ZERO,Vector2(176,48),func(): select_speed(index),is_equal_approx(pace,SessionOptions.SPEEDS[i]),row).name = "TrainingSpeed%d" % i

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
		UiLayout.illustrate(card,GeneratedArt.background_path(recommended_mode() if i==0 else "aliens"),Color("d7eee0") if i==0 else Color("d7eafa"))
		var content := UiLayout.column(UiLayout.margin(card,24),12)
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(center)
		var badge := add_badge(recommended_mode() if i==0 else "aliens",Vector2.ZERO,Vector2(360,220),center)
		badge.custom_minimum_size = Vector2(360,220)
		var caption := UiLayout.row(content,12)
		UiLayout.text(caption,"打字训练" if i==0 else "打字挑战",34)
		UiLayout.space(caption,0,true)
		if i==0:
			button("选课程",Vector2.ZERO,Vector2(128,44),show_lessons,false,caption).name = "ChooseCourse"
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
	return ["dojo","dojo","aliens","moles","racing","balloons","fighter","racing","aliens","sprint"][lesson_index]

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
	if mode=="dojo":
		return "修好星桥 · 点亮三座星灯"
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
		var tint: Color = PlayTheme.PASTELS[GameContent.modes().find(definition)%5]
		var card := UiLayout.card(grid,tint)
		UiLayout.illustrate(card,GeneratedArt.background_path(mode.id),tint,.32,.48)
		card.custom_minimum_size = Vector2(350,290)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content := UiLayout.column(UiLayout.margin(card,14),10)
		var art := Control.new()
		art.custom_minimum_size.y = 128
		art.clip_contents = true
		content.add_child(art)
		var mascot := add_badge(mode.id,Vector2.ZERO,Vector2(160,112),art)
		mascot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mascot.offset_left = -80
		mascot.offset_top = -56
		mascot.offset_right = 80
		mascot.offset_bottom = 56
		mascot.reduced_motion = true
		UiLayout.text(content,mode.name+(" · 推荐" if purpose=="training" and mode.id==recommended_mode() else ""),24)
		var rule := UiLayout.text(content,mission_goal(mode.id,purpose),16,MUTED)
		rule.custom_minimum_size.y = 46
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiLayout.space(content,0,true)
		var enter := button("进入挑战  →" if purpose=="challenge" else "开始训练  →",Vector2.ZERO,Vector2(0,46),func(): start_game(mode.id,purpose),false,content)
		enter.name = "Mission_"+str(mode.id)
		enter.focus_entered.connect(func():
			GeneratedArt.warm_props(mode.id)
			enter.theme_type_variation = "PrimaryButton"
			mascot.reduced_motion = store.data.settings.reduced_motion)
		enter.focus_exited.connect(func():
			enter.theme_type_variation = "Button"
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
	order.erase(recommended_mode())
	order.push_front(recommended_mode())
	var modes := GameContent.modes()
	modes.sort_custom(func(a,b): return order.find(a.id)<order.find(b.id))
	game_grid(modes,Vector2.ZERO,Vector2.ZERO,"training",content)
	var footer := UiLayout.row(content,16)
	button("返回课程",Vector2.ZERO,Vector2(180,48),show_lessons,false,footer)
	UiLayout.space(footer,0,true)
	vocabulary_button(Vector2.ZERO,footer)
	layer.find_child("Mission_"+recommended_mode(),true,false).grab_focus()

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
	selector.name = "ChallengeText"
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lesson in lessons:
		selector.add_item(lesson.name)
	selector.selected = lesson_index
	selector.item_selected.connect(func(index):
		lesson_index=index
		store.data.last_lesson=index
		store.save_profile()
		show_challenges()
		layer.find_child("ChallengeText",true,false).grab_focus())
	setup.add_child(selector)
	var ranks := UiLayout.row(content,12)
	for i in range(3):
		var index := i
		button(("✓ " if i==challenge_index else "")+SessionOptions.RANK_NAMES[i]+"  "+str(SessionOptions.RANK_SPEEDS[i])+"×",Vector2.ZERO,Vector2(200,48),func(): select_rank(index),i==challenge_index,ranks).name = "ChallengeRank%d" % i
	var modes := GameContent.modes().filter(func(m): return m.id not in ["dojo","bubbles"])
	game_grid(modes,Vector2.ZERO,Vector2.ZERO,"challenge",content)
	var footer := UiLayout.row(content)
	UiLayout.space(footer,0,true)
	vocabulary_button(Vector2.ZERO,footer)
	selector.grab_focus()

func vocabulary_button(at: Vector2, parent: Control = layer) -> void:
	var active := Vocabulary.supports(lessons[lesson_index])
	var title := "词库与主题" if active else "词库 · 第 6 课起使用"
	if active and vocabulary_topic!="mixed":
		for topic in Vocabulary.topics():
			if topic.id==vocabulary_topic:
				title = "KET 主题 · "+str(topic.name)+"  ▾"
	button(title,at,Vector2(280,48),show_vocabulary,false,parent).name = "VocabularySettings"

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
			show_training_games()
		layer.find_child("VocabularySettings",true,false).grab_focus())
	content.add_child(selector)
	UiLayout.text(content,"从短词到短句，随课程逐步增加难度。",20,MUTED)
	UiLayout.text(content,"A1–A2 范围独立训练词库",18,MUTED)
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
	layer.find_child("Course%d" % lesson_index,true,false).grab_focus()


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
	var content := menu_content()
	UiLayout.text(content,"让手指找到自己的位置",34)
	var body := UiLayout.row(content,24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	typing_guide = TypingGuide.new()
	typing_guide.wide = true
	typing_guide.custom_minimum_size = Vector2(600,580)
	body.add_child(typing_guide)
	var copy := UiLayout.column(body,24)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiLayout.text(copy,"双手，回到基准行",26)
	var homes := UiLayout.text(copy,"左手 A S D F\n右手 J K L ;\n拇指轻放空格键",24)
	homes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiLayout.text(copy,"摸到 F / J 的凸点，\n不看键盘也能找到起点。",21,MINT)
	var tips := UiLayout.text(copy,"击键后回到原位。\n大写与符号，用另一只手按 Shift。",21)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiLayout.space(copy,0,true)
	var note := UiLayout.text(copy,"按下实体键，查看分工。\n示意图不会检测真实手势。",18,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var samples := UiLayout.row(content,12)
	for value in ["f","j","a","k","F","?"," "]:
		button("空格" if value==" " else value,Vector2.ZERO,Vector2(100,56),func(): typing_guide.preview_character=value,false,samples)
	UiLayout.space(samples,0,true)
	button("开始练习  →",Vector2.ZERO,Vector2(260,56),show_lessons,true,samples).grab_focus()

func show_game_guide() -> void:
	if run == null or run.done or guide_open:
		return
	guide_was_paused = run.paused
	run.paused = true
	guide_open = true
	var content := dialog_content(modal(),1160)
	var row := UiLayout.row(content,32)
	var coach := TypingGuide.new()
	coach.wide = true
	coach.custom_minimum_size = Vector2(600,580)
	coach.run = run
	row.add_child(coach)
	var copy := UiLayout.column(row,20)
	copy.custom_minimum_size.x = 420
	UiLayout.text(copy,"指法与规则",30,GOLD)
	var goal := UiLayout.text(copy,mission_goal(run.mode,run.context),21,MINT)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_rules := "敲下金色按键，修好脚下的桥。\n每六步点亮一座星灯。\n按错保留进度，重试即可。" if run is BridgeRun else "输入高亮词牌上的完整文字。\nTab 换目标，退格撤回一字。"+("\n命中三次后，F3 释放技能。" if run is ArcadeRun else "")
	var tactics: String = {"fighter":"蓄力时完成单词，打出双倍重拳。\nF3 格挡反击，抓住下一次破绽。", "aliens":"红圈亮起即将俯冲，输入击落。\n补给舰恢复护盾，俯冲拦截有奖励。", "castle":"输入萨满符文打断治疗。\n爆破兵点火时，输入符文拆弹。"}.get(run.mode, "")
	if not tactics.is_empty(): action_rules += "\n\n"+tactics
	var rules := UiLayout.text(copy,action_rules+"\n\nF2 开关声音 · Esc 暂停",20)
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
	for metric in [[str(int(store.data.xp)),"总经验"],["%d / 10" % store.data.completed.size(),"已掌握课程"]]:
		var cell := UiLayout.column(ribbon,4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiLayout.text(cell,metric[0],28,GOLD)
		UiLayout.text(cell,metric[1],17,MUTED)
	var body := UiLayout.row(content,24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var settings := UiLayout.framed(body,Color("d5e9e4"))
	settings.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls := UiLayout.column(UiLayout.margin(settings,28),12)
	UiLayout.text(controls,"声音与偏好",26)
	volume_control("音乐","music_volume",Vector2.ZERO,controls)
	volume_control("音效","sfx_volume",Vector2.ZERO,controls)
	button("减少动态效果："+("开" if store.data.settings.reduced_motion else "关"),Vector2.ZERO,Vector2(0,48),func():
		store.data.settings.reduced_motion = not store.data.settings.reduced_motion
		store.save_profile()
		show_profile()
		layer.find_child("ReducedMotion",true,false).grab_focus(),false,controls).name = "ReducedMotion"
	UiLayout.space(controls,20)
	UiLayout.text(controls,"冒险存档",24)
	var backups := UiLayout.row(controls,12)
	button("导出存档备份",Vector2.ZERO,Vector2(278,50),export_save,false,backups).name = "ExportSave"
	button("导入存档备份",Vector2.ZERO,Vector2(278,50),show_import,false,backups)
	var status := UiLayout.text(controls,store.status,18,MINT)
	status.visible = "备份" in store.status or "失败" in store.status
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := UiLayout.text(controls,"进度自动保存在此设备，导出备份可迁移。",18,MUTED)
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
	var cheer := UiLayout.text(companion_column,"",22)
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
		practice.get_parent().get_parent().hide()
	for i in range(mini(6,stats.size())):
		var cell := UiLayout.column(UiLayout.margin(UiLayout.card(keys,Color("e5efdc")),8),4)
		UiLayout.text(cell,"空格" if stats[i].key==" " else stats[i].key,26,GOLD)
		UiLayout.text(cell,"错误 %d 次" % stats[i].miss,15,MUTED)
	layer.find_child("MusicVolume",true,false).grab_focus()

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
	layer.find_child("ExportSave",true,false).grab_focus()

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
	var surface := UiLayout.framed(center,Color("e4efdd"))
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
	run = BridgeRun.new() if mode=="dojo" else CastleRun.new() if mode == "castle" else (ArcadeRun.new() if mode in ArcadeRun.MODES else GameRun.new())
	run.context = purpose
	run.challenge_rank = SessionOptions.RANK_IDS[challenge_index] if purpose=="challenge" else "normal"
	run.setup(mode,Vocabulary.lesson(lessons[lesson_index],vocabulary_topic),pace if purpose=="training" else SessionOptions.RANK_SPEEDS[challenge_index])
	soundscape.bind_run(run)
	run.ended.connect(finish_game)
	if mode=="dojo":
		start_bridge_stage()
		return
	var title := ""
	for definition in GameContent.modes():
		if definition.id == mode:
			title = definition.name
	var shell := GameShell.new()
	shell.wide_stage = mode!="castle"
	layer.add_child(shell)
	var title_label := UiLayout.text(shell.heading,title,28)
	title_label.name = "GameTitle"
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
	pause_button = button("暂停 Esc",Vector2.ZERO,Vector2(116,48),toggle_pause,false,shell.actions)
	pause_button.focus_mode = Control.FOCUS_NONE
	var arena: GameArena = CastleArena.new() if mode == "castle" else (ArcadeArena.new() if run is ArcadeRun else GameArena.new())
	arena.size = Vector2(1040,650) if mode=="castle" or run is ArcadeRun else Vector2(1360,650)
	arena.run = run
	arena.reduced_motion = store.data.settings.reduced_motion
	shell.field.add_child(arena)
	if run is ArcadeRun:
		# Keep the simulation/actor proportions intact; the scenery fills the wider stage.
		arena.position.x = 160
		arena.remove_child(arena.backdrop)
		shell.field.add_child(arena.backdrop)
		shell.field.move_child(arena.backdrop,0)
		arena.backdrop.show_behind_parent = false
		arena.backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		arena.backdrop_external = true
	if mode == "castle":
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

func start_bridge_stage() -> void:
	var arena := BridgeArena.new()
	arena.name = "BridgeWorld"
	arena.size = Vector2(1440,900)
	arena.run = run
	arena.reduced_motion = store.data.settings.reduced_motion
	layer.add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := UiLayout.margin(layer,0)
	safe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	safe.offset_left = 32
	safe.offset_right = -32
	safe.offset_top = 24
	safe.offset_bottom = 80
	var header := UiLayout.row(safe,12)
	var title := UiLayout.text(header,"星桥快跑",32)
	title.add_theme_constant_override("outline_size",4)
	title.add_theme_color_override("font_outline_color",Color("d7eff5"))
	UiLayout.space(header,0,true)
	var help := button("F1 指法",Vector2.ZERO,Vector2(100,48),show_game_guide,false,header)
	help.focus_mode = Control.FOCUS_NONE
	pause_button = button("暂停 Esc",Vector2.ZERO,Vector2(126,48),toggle_pause,false,header)
	pause_button.focus_mode = Control.FOCUS_NONE
	castle_audio = CastleAudio.new()
	castle_audio.battle = run
	castle_audio.enabled = store.data.settings.get("sound",true)
	layer.add_child(castle_audio)

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
	if "失败" in store.status:
		UiLayout.text(content,store.status,18,PlayTheme.ORANGE)
	var mode := run.mode
	var mastered: bool = session_context=="training" and run.won and run.accuracy()>=.9 and run.correct>=18 and lesson_index<lessons.size()-1
	var actions := UiLayout.row(content,16)
	button("继续下一课  →" if mastered else "再练一次",Vector2.ZERO,Vector2(340,56),continue_training if mastered else func(): start_game(mode,session_context),true,actions).grab_focus()
	button("选择其他训练" if session_context=="training" else "选择其他挑战",Vector2.ZERO,Vector2(340,56),show_training_games if session_context=="training" else show_challenges,false,actions)
