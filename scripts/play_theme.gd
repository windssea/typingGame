class_name PlayTheme
extends RefCounted

# Text colors stay darker than toy/art colors so small labels remain readable.
const BACKGROUND := Color("f4f9fd")
const SURFACE := Color("e4f0f4")
const BORDER := Color("d8e5f1")
const TEXT := Color("2d405b")
const MUTED := Color("596d85")
const PRIMARY := Color("416db4")
const ACTION := Color("ffe2af")
const ACTION_EDGE := Color("e9c88d")
const ACTION_INK := Color("5b4327")
const TEAL := Color("13766b")
const ORANGE := Color("a65220")
const YELLOW := Color("ffd56b")
const CORAL := Color("ff8a86")
const MINT := Color("72d5b1")
const SKY := Color("78bcf3")
const LILAC := Color("b4a0ee")
const PASTELS := [Color("e8f3ff"),Color("e5f7ef"),Color("fff1ce"),Color("fce9ef"),Color("efeaff")]

static func decorated_panel(tint := SURFACE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = preload("res://assets/generated/ui-panel-v14.png")
	# Fixed bevel pixels, stretched quiet center: no distortion of corner ornaments.
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,28)
		box.set_content_margin(side,0)
	box.modulate_color = Color.WHITE.lerp(tint,.12)
	return box

static func game_panel(color := Color.WHITE, edge := BORDER, radius := 20, depth := 4) -> StyleBoxFlat:
	var box := surface(color,edge,radius)
	box.border_width_bottom = mini(depth,2)
	box.shadow_color = Color(.18,.35,.42,.045)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0,2)
	return box

static func game_button(primary := false, state := "normal") -> StyleBox:
	if state!="disabled":
		var painted := StyleBoxTexture.new()
		painted.texture = preload("res://assets/generated/ui-button-gold-v14.png") if primary else preload("res://assets/ui-button-blue-v14.svg")
		painted.set_texture_margin(SIDE_LEFT,28)
		painted.set_texture_margin(SIDE_RIGHT,28)
		painted.set_texture_margin(SIDE_TOP,16)
		painted.set_texture_margin(SIDE_BOTTOM,16)
		painted.modulate_color = Color(1.06,1.06,1.06) if state=="hover" else Color(.9,.94,.97) if state=="pressed" else Color.WHITE
		return painted
	var fill := Color("ffdf91") if primary else Color("d8eaf6")
	var edge := Color("e6bf67") if primary else Color("b7d2e5")
	var depth := 2
	if state=="hover":
		fill = Color("ffe9b0") if primary else Color("edf5ff")
		edge = Color("cf9e44") if primary else Color("91afd6")
	elif state=="pressed":
		fill = Color("f8d888") if primary else Color("d6f1e5")
		depth = 2
	elif state=="disabled":
		fill = Color("e8eeee")
		edge = Color("c6d2d5")
		depth = 2
	return game_panel(fill,edge,16,depth)

static func surface(color: Color, border := BORDER, radius := 20, raised := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	if raised:
		box.shadow_color = Color(0.24,0.39,0.53,0.035)
		box.shadow_size = 1
		box.shadow_offset = Vector2(0,2)
	return box

static func ui(font: Font) -> Theme:
	var result := Theme.new()
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color","Label",TEXT)
	result.set_font("font","Button",preload("res://assets/ui-heading.ttf"))
	result.set_font_size("font_size","Button",20)
	result.set_type_variation("PrimaryButton","Button")
	for variant in ["Button","PrimaryButton"]:
		var primary: bool = variant=="PrimaryButton"
		for state in ["normal","hover","pressed","disabled"]:
			var box := game_button(primary,state)
			box.content_margin_left = 16
			box.content_margin_right = 16
			box.content_margin_top = 5
			box.content_margin_bottom = 7
			result.set_stylebox(state,variant,box)
		var focus := surface(Color.TRANSPARENT,PRIMARY,16)
		focus.set_border_width_all(3)
		focus.expand_margin_left = 3
		focus.expand_margin_right = 3
		focus.expand_margin_top = 3
		focus.expand_margin_bottom = 3
		result.set_stylebox("focus",variant,focus)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			result.set_color(state,variant,ACTION_INK if primary else TEXT)
		result.set_color("font_disabled_color",variant,MUTED)
	for control in ["OptionButton","PopupMenu","TextEdit"]:
		result.set_color("font_color",control,TEXT)
		result.set_color("font_hover_color",control,PRIMARY)
		result.set_color("font_selected_color",control,TEXT)
		result.set_color("font_focus_color",control,TEXT)
		result.set_color("font_pressed_color",control,TEXT)
		result.set_color("font_disabled_color",control,MUTED)
		result.set_stylebox("normal",control,surface(SURFACE))
		result.set_stylebox("panel",control,surface(SURFACE))
		result.set_stylebox("hover",control,surface(PASTELS[0]))
		result.set_stylebox("focus",control,surface(Color.TRANSPARENT,PRIMARY))
	result.set_color("font_placeholder_color","TextEdit",MUTED)
	result.set_color("caret_color","TextEdit",PRIMARY)
	result.set_color("selection_color","TextEdit",Color("d3e4ff"))
	result.set_stylebox("slider","HSlider",game_panel(Color("dcece6"),Color("b3cbc3"),7,2))
	result.set_stylebox("grabber_area","HSlider",surface(Color("7bcbb0"),Color.TRANSPARENT,6))
	result.set_stylebox("grabber_area_highlight","HSlider",surface(Color("65bfa2"),Color.TRANSPARENT,6))
	result.set_stylebox("focus","HSlider",surface(Color.TRANSPARENT,PRIMARY,12))
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		result.set_icon(state,"HSlider",load("res://assets/slider-knob.svg"))
	for control in ["OptionButton","TextEdit"]:
		var input_box := surface(SURFACE)
		input_box.content_margin_left = 12
		input_box.content_margin_right = 12
		input_box.content_margin_top = 8
		input_box.content_margin_bottom = 8
		result.set_stylebox("normal",control,input_box)
	result.set_color("icon_normal_color","OptionButton",MUTED)
	result.set_color("icon_hover_color","OptionButton",PRIMARY)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		var thumb := surface(Color("a6bade"),Color.TRANSPARENT,6)
		thumb.content_margin_left = 6
		thumb.content_margin_right = 6
		result.set_stylebox(state,"VScrollBar",thumb)
	var track := surface(Color("eaf0f8"),Color.TRANSPARENT,6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	result.set_stylebox("scroll","VScrollBar",track)
	return result
