extends Control

const FONT = preload("res://assets/ui-font.ttf")
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
var world_index := -1
const WORLD_NAMES := ["皇家奇幻战争","科幻星港","现代工坊","古文明遗迹","童话花园"]
const WORLD_MODES := [["castle","fighter"],["aliens","rain"],["racing","sprint"],["dojo","moles"],["balloons","bubbles"]]
const PORTALS = preload("res://assets/worlds/portals.png")

func _ready() -> void:
	store.load_profile()
	lesson_index = int(store.data.last_lesson)
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
	modal_focus.clear()
	castle_panel = null
	castle_audio = null
	typing_guide = null
	guide_open = false
	sound_button = null
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = BG
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var decor := PlayfulArt.new()
	decor.variant = "background"
	layer.add_child(decor)
	overlay = null

func style(color: Color, border := LINE, radius := 22) -> StyleBoxFlat:
	return PlayTheme.surface(color,border,radius,true)

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
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func button(value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary := false, parent: Control = layer) -> Button:
	var item := Button.new()
	item.text = value
	item.position = at
	item.size = dimensions
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_stylebox_override("normal", style(PlayTheme.ACTION if primary else Color.WHITE, PlayTheme.ACTION_EDGE if primary else LINE, 15))
	item.add_theme_stylebox_override("hover", style(Color("ffdf9f") if primary else Color("edf5ff"), Color("d8b16b") if primary else Color("a9c4e2"), 15))
	item.add_theme_stylebox_override("pressed", PlayTheme.surface(Color("ffda95") if primary else Color("e5f0fc"),PlayTheme.ACTION_EDGE if primary else Color("a9c4e2"),15))
	var focus := PlayTheme.surface(Color.TRANSPARENT,PlayTheme.PRIMARY,15)
	focus.set_border_width_all(2)
	item.add_theme_stylebox_override("focus", focus)
	item.add_theme_stylebox_override("disabled", PlayTheme.surface(Color("edf1f6"),Color("dce4ee"),15))
	item.add_theme_color_override("font_disabled_color",Color("718197"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		item.add_theme_color_override(state, PlayTheme.ACTION_INK if primary else TEXT)
	item.pressed.connect(callback)
	parent.add_child(item)
	ensure_keyboard_focus.call_deferred()
	return item

func navigation(active: String) -> void:
	panel(Vector2(0,0),Vector2(252,900),Color("ffffff"))
	panel(Vector2(28,31),Vector2(55,58),PlayTheme.YELLOW)
	label("K",Vector2(43,34),34,TEXT)
	label("键境",Vector2(100,39),30)
	label("键 盘 游 乐 园",Vector2(31,106),18,GOLD)
	label("小小手指，大大冒险！",Vector2(30,148),16,MUTED)
	var nav := [["home","游戏集合",show_home],["lessons","打字训练",show_lessons],["challenges","打字挑战",show_challenges],["library","玩法图鉴",show_library],["profile","学习档案",show_profile]]
	for i in range(nav.size()):
		button(nav[i][1],Vector2(24,223+i*64),Vector2(204,48),nav[i][2],active==nav[i][0])
	var pal := PlayfulArt.new()
	pal.variant = "sidebar"
	pal.position = Vector2(36,557)
	pal.scale = Vector2.ONE*0.8
	layer.add_child(pal)
	label("每天进步一点点",Vector2(30,686),20,GOLD)
	label("Lv. %02d  /  %d XP" % [1+int(store.data.xp/100),store.data.xp],Vector2(30,725),17)
	label("已掌握 %d / 10 节" % store.data.completed.size(),Vector2(30,759),16,MUTED)
	label("方向键 / Tab 选择 · Enter 确认",Vector2(24,816),13,MUTED)
	label("键境 · 可玩版 0.6",Vector2(30,845),14,MUTED)

func show_home() -> void:
	page = "home"
	run = null
	clear_ui()
	navigation("home")
	label("KEYBOUND / 键盘里的五个世界",Vector2(300,36),16,GOLD)
	label("小小手指，探索大大世界。",Vector2(300,72),38)
	label("先练 F 和 J，再把每一个单词变成冒险的力量。",Vector2(300,128),18,MUTED)
	panel(Vector2(300,175),Vector2(1090,100),Color("edf6ff"))
	label("继续学习  /  "+lessons[lesson_index].name,Vector2(324,189),23)
	label(lessons[lesson_index].hint,Vector2(324,231),16,MUTED)
	button("更换课程",Vector2(895,195),Vector2(172,54),show_lessons)
	button("继续本课  →",Vector2(1082,195),Vector2(280,54),show_training_games,true).grab_focus()
	label("五个世界，同一场成长",Vector2(300,289),21)
	for i in range(5):
		var index := i
		var card := button("",Vector2(300+i*220,330),Vector2(204,184),func(): select_world(index),world_index==i)
		card.name = "WorldPortal%d" % i
		var texture := AtlasTexture.new()
		texture.atlas = PORTALS
		texture.region = Rect2(i*PORTALS.get_width()/5.0,[365,405,385,370,445][i],PORTALS.get_width()/5.0,240)
		texture.filter_clip = true
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = texture
		picture.position = Vector2(4,4)
		picture.size = Vector2(196,126)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.clip_contents = true
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		label(WORLD_NAMES[i],Vector2(12,133),18,TEXT,card).mouse_filter = Control.MOUSE_FILTER_IGNORE
		label("◆ 当前世界 · 2款玩法" if i==world_index else "进入世界 · 2款玩法",Vector2(12,160),13,MUTED,card).mouse_filter = Control.MOUSE_FILTER_IGNORE
	label("全部小游戏" if world_index<0 else WORLD_NAMES[world_index]+" · 开始冒险",Vector2(300,539),23)
	button("全部十款游戏",Vector2(1195,530),Vector2(195,42),func(): world_index=-1; show_home(),world_index<0)
	game_grid(available_modes(),Vector2(300,584),Vector2(1100,242),"training")
	label("课程决定练习内容 · 世界决定游戏画面 · 每次结算自动保存成绩",Vector2(300,848),16,MUTED)

func select_world(index: int) -> void:
	world_index = index
	show_home()
	var card := layer.find_child("WorldPortal%d" % index,true,false) as Button
	if card!=null:
		card.grab_focus()

func available_modes() -> Array:
	if world_index<0:
		return GameContent.modes()
	return GameContent.modes().filter(func(mode): return mode.id in WORLD_MODES[world_index])

func add_badge(mode: String, at: Vector2, dimensions: Vector2, parent: Control = layer) -> void:
	var badge := ModeBadge.new()
	badge.mode = mode
	badge.position = at
	badge.size = dimensions
	parent.add_child(badge)

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
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	layer.add_child(scroll)
	scroll.add_child(grid)
	for i in range(modes.size()):
		var mode: Dictionary = modes[i]
		var card := Panel.new()
		card.custom_minimum_size = Vector2(350,241)
		card.add_theme_stylebox_override("panel",style(PANEL))
		grid.add_child(card)
		var cap := panel(Vector2(8,8),Vector2(334,77),PlayTheme.PASTELS[i%5],card)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_badge(mode.id,Vector2(242,7),Vector2(95,75),card)
		label(str(mode.tag).split("/")[-1].strip_edges(),Vector2(19,17),14,MUTED,card)
		label(mode.name,Vector2(19,49),24,TEXT,card)
		label(mode.description,Vector2(19,94),16,MUTED,card)
		label(mode.goal,Vector2(19,150),14,MINT,card)
		button("开始挑战  →" if purpose=="challenge" else "用本课内容开始",Vector2(19,184),Vector2(312,41),func(): start_game(mode.id,purpose),false,card)

func show_training_games() -> void:
	page = "training_games"
	run = null
	clear_ui()
	navigation("lessons")
	label("这节课，你想怎么玩？",Vector2(300,46),34)
	label(lessons[lesson_index].name+"  /  "+lessons[lesson_index].hint,Vector2(300,106),17,MINT)
	label("训练内容保持一致，只改变玩法。新手建议先选无压力练习。",Vector2(300,143),17,MUTED)
	game_grid(available_modes(),Vector2(300,194),Vector2(1100,590),"training")
	button("返回课程",Vector2(300,807),Vector2(180,46),show_lessons)
	button("舒缓节奏" if pace<1 else "标准节奏",Vector2(500,807),Vector2(180,46),func(): pace=0.65 if pace>=1 else 1.0; show_training_games())

func show_challenges() -> void:
	page = "challenges"
	run = null
	clear_ui()
	navigation("challenges")
	label("准备好，挑战自己。",Vector2(300,48),36)
	label("已学会输入？现在用速度、反应和策略，检验你的稳定性。",Vector2(302,111),18,MUTED)
	panel(Vector2(300,170),Vector2(1090,84))
	label("挑战文本："+lessons[lesson_index].name,Vector2(324,194),21,MINT)
	var selector := OptionButton.new()
	selector.position = Vector2(1020,188)
	selector.size = Vector2(345,45)
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
	game_grid(modes,Vector2(300,280),Vector2(1100,530),"challenge")
	label("挑战成绩单独记录。课程掌握情况只由训练更新。",Vector2(300,845),17,MUTED)

func show_lessons() -> void:
	page = "lessons"
	run = null
	clear_ui()
	navigation("lessons")
	label("从第一枚字母开始",Vector2(300,48),36)
	label("通关、准确率 ≥90% 且有效输入 ≥18 字符记录掌握。所有课程开放。",Vector2(302,107),17,MUTED)
	button("先学手指摆放",Vector2(1180,54),Vector2(210,46),show_fingering)
	for i in range(lessons.size()):
		var col := i % 2
		var row := i / 2
		var x := 300+col*550
		var y := 168+row*119
		var lesson: Dictionary = lessons[i]
		panel(Vector2(x,y),Vector2(530,103),Color("e5f0ff") if i == lesson_index else PANEL)
		label(lesson.name + ("  ✓" if store.data.completed.has(lesson.id) else ""),Vector2(x+18,y+13),21,GOLD if i==lesson_index else TEXT)
		label(lesson.description,Vector2(x+18,y+53),14,MUTED)
		button("已选" if i==lesson_index else "选择",Vector2(x+423,y+13),Vector2(88,40),func(): select_lesson(i),i==lesson_index)
	button("下一步：选择小游戏",Vector2(300,791),Vector2(270,54),show_training_games,true)
	button("舒缓" if pace < 1 else "标准",Vector2(590,791),Vector2(150,54),func(): pace = 0.65 if pace >= 1 else 1.0; show_lessons())
	label("节奏只影响敌人移动和刷新速度。",Vector2(749,807),17,MUTED)

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
	label("先摆好手，再继续。",Vector2(660,171),28,GOLD,root)
	label("左手 A S D F · 右手 J K L ;\n拇指轻放空格。\n\nF / J 凸点帮助找到起始位置。\n手指自然弯曲，手腕放松。\n\n高亮手指对应下一个目标键；\n输入后回到各自的基准键位。\n\n战斗与计时已暂停。",Vector2(660,239),20,TEXT,root)
	button("摆好了，继续  Esc",Vector2(660,670),Vector2(440,55),close_game_guide,true,root).grab_focus()

func close_game_guide() -> void:
	guide_open = false
	close_modal()
	if run != null:
		run.paused = false
		if guide_was_paused:
			toggle_pause()

func show_library() -> void:
	page = "library"
	run = null
	clear_ui()
	navigation("library")
	label("一套键盘，无数种冒险。",Vector2(300,48),36)
	label("10 款已可玩 · 下方为后续扩展规划 · 当前游戏请从游戏集合进入",Vector2(302,110),18,MUTED)
	var groups := [
		["01 / 基础与节奏","星火练习场 · 字母泡泡 · 指法花园\n节奏列车 · 双手鼓点 · 拼字积木"],
		["02 / 射击与反应","字母陨落 · 星际射手 · 西部快枪\n气球猎手 · 深海鱼雷 · 流星拦截"],
		["03 / 塔防与策略","守护键之城 · 符文炮台 · 四门要塞\n护送商队 · 元素防线 · 无尽围城"],
		["04 / 横版与冒险","键帽跑酷 · 云端攀登 · 矿洞逃生\n森林游侠 · 单词钩索 · 巨龙追逐"],
		["05 / 模拟与经营","魔药工坊 · 打字餐厅 · 邮局物语\n农场物语 · 修理小铺 · 城镇建设"],
		["06 / 高阶与挑战","符文地牢 · Boss 试炼 · 校对侦探\n代码工匠 · 每日远征 · 自定义训练"]]
	for i in range(groups.size()):
		var x := 300+(i%2)*550
		var y := 179+(i/2)*208
		panel(Vector2(x,y),Vector2(530,185))
		label(groups[i][0],Vector2(x+24,y+21),23,GOLD)
		label(groups[i][1],Vector2(x+24,y+72),19,MUTED)
	label("已可玩：气球、外星攻防、地鼠、赛车、格斗、城堡等十种游戏。",Vector2(300,838),17,MUTED)

func show_profile() -> void:
	page = "profile"
	run = null
	clear_ui()
	navigation("profile")
	label("看见每一次进步。",Vector2(300,48),36)
	label(store.status,Vector2(302,110),18,MINT)
	panel(Vector2(300,174),Vector2(1090,138))
	label("总经验",Vector2(328,194),17,MUTED)
	label(str(store.data.xp),Vector2(328,233),32,GOLD)
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
	label("存档与偏好",Vector2(300,554),25)
	label("存档保存在当前设备 / 浏览器。清理站点数据会删除网页存档，请定期导出。\n本版保存学习进度与结算成绩；不保存战斗中途状态。",Vector2(300,603),18,MUTED)
	button("导出存档备份",Vector2(300,688),Vector2(210,52),export_save,true)
	button("导入存档备份",Vector2(530,688),Vector2(210,52),show_import)
	button("减少动态效果："+("开" if store.data.settings.reduced_motion else "关"),Vector2(760,688),Vector2(270,52),func(): store.data.settings.reduced_motion = not store.data.settings.reduced_motion; store.save_profile(); show_profile())
	if not OS.has_feature("web"):
		button("打开存档目录",Vector2(1050,688),Vector2(220,52),func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	label("备份文件名：keybound-backup.json。导入时打开文件，复制内容后粘贴即可。",Vector2(300,772),16,MUTED)
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		label("当前浏览器未允许持久化，请使用导出备份保存进度。",Vector2(300,817),18,GOLD)

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
	for control in layer.find_children("*", "BaseButton", true, false):
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
	run.setup(mode,lessons[lesson_index],pace if purpose=="training" else 1.0)
	run.ended.connect(finish_game)
	var title := ""
	for definition in GameContent.modes():
		if definition.id == mode:
			title = definition.name
	label("K / " + title,Vector2(40,24),28,GOLD)
	label(("训练 / " if purpose=="training" else "挑战 / ")+lessons[lesson_index].name,Vector2(40,75),17,MUTED)
	hud = label("",Vector2(500,35),22,TEXT)
	pause_button = button("暂停  Esc",Vector2(1230,28),Vector2(170,48),toggle_pause)
	pause_button.focus_mode = Control.FOCUS_NONE
	var arena: GameArena = CastleArena.new() if mode == "castle" else (ArcadeArena.new() if run is ArcadeRun else GameArena.new())
	arena.position = Vector2(40,130)
	arena.size = Vector2(1040,650) if mode=="castle" or run is ArcadeRun else Vector2(1360,650)
	if not run is CastleRun and not run is ArcadeRun:
		arena.scale = Vector2.ONE * (1040.0/1360.0)
	arena.run = run
	arena.reduced_motion = store.data.settings.reduced_motion
	layer.add_child(arena)
	if mode != "castle":
		typing_guide = TypingGuide.new()
		typing_guide.position = Vector2(1100,130)
		typing_guide.run = run
		layer.add_child(typing_guide)
		if not run is ArcadeRun:
			panel(Vector2(40,652),Vector2(1040,128))
			label("找准手指，再追求速度。",Vector2(66,670),24,GOLD)
			label("右侧教练推荐最紧急目标的下一个按键；锁定后跟随当前目标。\n左右手食指先找到 F / J 凸点，每次击键后回到基准行。",Vector2(66,714),18,MUTED)
	if mode == "castle":
		castle_panel = CastlePanel.new()
		castle_panel.position = Vector2(1110,130)
		castle_panel.app = self
		castle_panel.battle = run
		layer.add_child(castle_panel)
		arena.pad_selected.connect(func(_index): castle_panel.rebuild())
	if mode == "castle" or run is ArcadeRun:
		castle_audio = CastleAudio.new()
		castle_audio.battle = run
		castle_audio.enabled = store.data.settings.get("sound",true)
		layer.add_child(castle_audio)
		sound_button = button("音效 F2：开" if castle_audio.enabled else "音效 F2：关",Vector2(1230,84),Vector2(170,32),toggle_sound)
		sound_button.focus_mode = Control.FOCUS_NONE
	var guide_button := button("指法 F1",Vector2(1100,84),Vector2(120,32),show_game_guide)
	guide_button.focus_mode = Control.FOCUS_NONE
	hint = label("",Vector2(42,798),20,MINT)
	label("%s  |  退格：撤回  Tab：换目标  F1：指法  F2：音效  Esc：暂停" % lessons[lesson_index].hint,Vector2(42,850),15,MUTED)
	update_hud()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
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
	if not is_instance_valid(castle_audio):
		return
	castle_audio.enabled = not castle_audio.enabled
	store.data.settings.sound = castle_audio.enabled
	store.save_profile()
	if is_instance_valid(sound_button):
		sound_button.text = "音效 F2：开" if castle_audio.enabled else "音效 F2：关"

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
	button("继续训练",Vector2(410,524),Vector2(620,54),toggle_pause,true,root).grab_focus()
	button("返回大厅",Vector2(410,602),Vector2(620,48),show_home,false,root)

func finish_game() -> void:
	store.record_run(run,lesson_index)
	var root := modal()
	label("完成啦！给自己一个赞！" if run.won else "再试一次，你会更熟练！",Vector2(410,213),30,GOLD,root)
	label("每一次练习，都在让双手更熟悉键盘。",Vector2(410,270),19,MUTED,root)
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
	button("再练一次",Vector2(410,563),Vector2(290,54),func(): start_game(mode,session_context),true,root).grab_focus()
	button("返回大厅",Vector2(720,563),Vector2(310,54),show_home,false,root)
	label("训练通关、准确率 ≥90% 且有效输入 ≥18 字符，记录掌握。" if session_context=="training" else "本次记录为挑战成绩，不改变课程掌握状态。",Vector2(410,657),15,MUTED,root)
