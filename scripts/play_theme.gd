class_name PlayTheme
extends RefCounted

# Text colors stay darker than toy/art colors so small labels remain readable.
const BACKGROUND := Color("f4f9fd")
const SURFACE := Color("ffffff")
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

static func game_panel(color := Color.WHITE, edge := BORDER, radius := 20, depth := 4) -> StyleBoxFlat:
	var box := surface(color,edge,radius)
	box.border_width_left = 2
	box.border_width_right = 2
	box.border_width_top = 2
	box.border_width_bottom = depth
	box.shadow_color = Color(.18,.35,.42,.09)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0,3)
	return box

static func game_button(primary := false, state := "normal") -> StyleBoxFlat:
	var fill := Color("ffe7a8") if primary else Color("f7fffc")
	var edge := Color("dfbc67") if primary else Color("a4c9c3")
	var depth := 5
	if state=="hover":
		fill = Color("fff0bb") if primary else Color("e8fff4")
		edge = Color("c9993e") if primary else Color("63ac9b")
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
