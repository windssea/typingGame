class_name PlayTheme
extends RefCounted

# Text colors stay darker than toy/art colors so small labels remain readable.
const BACKGROUND := Color("f7f9fd")
const SURFACE := Color("ffffff")
const BORDER := Color("dbe5ef")
const TEXT := Color("293c59")
const MUTED := Color("586d84")
const PRIMARY := Color("4263d7")
const TEAL := Color("13766b")
const ORANGE := Color("a65220")
const YELLOW := Color("ffd56b")
const CORAL := Color("ff8a86")
const MINT := Color("72d5b1")
const SKY := Color("78bcf3")
const LILAC := Color("b4a0ee")
const PASTELS := [Color("e8f3ff"),Color("e5f7ef"),Color("fff1ce"),Color("fce9ef"),Color("efeaff")]

static func surface(color: Color, border := BORDER, radius := 20, raised := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	if raised:
		box.shadow_color = Color(0.19,0.29,0.48,0.08)
		box.shadow_size = 1
		box.shadow_offset = Vector2(0,5)
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
		result.set_stylebox("normal",control,surface(SURFACE))
		result.set_stylebox("panel",control,surface(SURFACE))
		result.set_stylebox("hover",control,surface(PASTELS[0]))
		result.set_stylebox("focus",control,surface(Color.TRANSPARENT,PRIMARY))
	result.set_color("font_placeholder_color","TextEdit",MUTED)
	result.set_color("caret_color","TextEdit",PRIMARY)
	result.set_color("selection_color","TextEdit",Color("d3e4ff"))
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
