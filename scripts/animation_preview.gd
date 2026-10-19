extends Control

const FRAMES_PATH := "res://assets/animations/royal-guard-idle-v002/idle.tres"
const FONT := preload("res://assets/ui-font.ttf")
var players: Array[AnimatedSprite2D] = []
var paused := false
var reduced := false
var status_label: Label
var play_button: Button

func _ready() -> void:
	theme = PlayTheme.ui(FONT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = PlayTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",24)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Grok / 动画样片"
	title.add_theme_font_size_override("font_size",32)
	title.add_theme_color_override("font_color",PlayTheme.TEXT)
	column.add_child(title)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color",PlayTheme.MUTED)
	column.add_child(status_label)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",24)
	column.add_child(row)
	var frames: SpriteFrames
	if ResourceLoader.exists(FRAMES_PATH):
		frames = load(FRAMES_PATH)
	for i in range(3):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel",PlayTheme.surface([Color("fff8e8"),Color("3b536c"),Color("83ad70")][i],Color("b79d6d"),18))
		row.add_child(cell)
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(190,330)
		cell.add_child(stage)
		var note := Label.new()
		note.text = ["48 / 剪影","96 / 游戏尺寸","192 / 边缘检查"][i]
		note.position = Vector2(20,20)
		note.add_theme_color_override("font_color",Color.WHITE if i==1 else Color("243044"))
		stage.add_child(note)
		if frames != null:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.scale = Vector2.ONE*[48.0,96.0,192.0][i]/128.0
			stage.add_child(sprite)
			stage.resized.connect(func(): sprite.position=stage.size/2+Vector2(0,20))
			sprite.position = stage.size/2+Vector2(0,20)
			sprite.play("idle")
			players.append(sprite)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",16)
	column.add_child(controls)
	play_button = Button.new()
	play_button.text = "暂停 / Space"
	play_button.custom_minimum_size = Vector2(220,56)
	play_button.pressed.connect(toggle_playback)
	controls.add_child(play_button)
	var reduce := Button.new()
	reduce.text = "减少动态 / R"
	reduce.custom_minimum_size = Vector2(220,56)
	reduce.pressed.connect(toggle_reduced)
	controls.add_child(reduce)
	var exit_button := Button.new()
	exit_button.text = "关闭 / Esc"
	exit_button.custom_minimum_size = Vector2(180,56)
	exit_button.pressed.connect(func(): get_tree().quit())
	controls.add_child(exit_button)
	play_button.grab_focus()
	refresh_status()
	if "--capture-animation-preview" in OS.get_cmdline_user_args():
		capture.call_deferred()

func toggle_playback() -> void:
	paused = not paused
	apply_playback()

func toggle_reduced() -> void:
	reduced = not reduced
	apply_playback()

func apply_playback() -> void:
	for player in players:
		if paused or reduced:
			player.pause()
			if reduced:
				player.frame = 0
		else:
			player.play("idle")
	play_button.text = "播放 / Space" if paused else "暂停 / Space"
	refresh_status()

func refresh_status() -> void:
	if players.is_empty():
		status_label.text = "尚无合格动画图集。先完成 Grok 生成与图集制作。"
	else:
		var frames := players[0].sprite_frames
		status_label.text = "idle · %d 帧 · %.3f FPS · 暂停 %s · 减少动态 %s\n透明图集候选；不改变伤害判定与玩家存档。" % [frames.get_frame_count("idle"),frames.get_animation_speed("idle"),str(paused),str(reduced)]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: toggle_playback()
		KEY_R: toggle_reduced()
		KEY_ESCAPE: get_tree().quit()
		_: return
	get_viewport().set_input_as_handled()

func capture() -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/animation-preview.png")
	get_tree().quit()
