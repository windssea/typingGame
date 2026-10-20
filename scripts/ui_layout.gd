class_name UiLayout
extends RefCounted

# Reference-space spacing; the viewport scales the entire 1440 × 900 composition.
static func margin(parent: Control, inset := 24) -> MarginContainer:
	var node := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		node.add_theme_constant_override("margin_"+edge,inset)
	parent.add_child(node)
	return node

static func column(parent: Control, gap := 16) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation",gap)
	parent.add_child(node)
	return node

static func row(parent: Control, gap := 16) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation",gap)
	parent.add_child(node)
	return node

static func space(parent: Control, height := 0, expand := false) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size.y = height
	if expand:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

static func text(parent: Control, value: String, font_size := 18, tint := PlayTheme.TEXT) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",tint)
	if font_size>=24:
		node.add_theme_font_override("font",preload("res://assets/ui-heading.ttf"))
	parent.add_child(node)
	return node

static func card(parent: Control, tint := PlayTheme.SURFACE) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel",PlayTheme.surface(tint))
	parent.add_child(node)
	return node

static func framed(parent: Control, tint := PlayTheme.SURFACE) -> PanelContainer:
	var node := card(parent,tint)
	node.add_theme_stylebox_override("panel",PlayTheme.decorated_panel(tint))
	return node

static func illustrate(parent: PanelContainer, path: String, tint: Color, shelf_start := .40, shelf_end := .70) -> void:
	var art := TextureRect.new()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.texture = load(path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ui_scene.gdshader")
	material.set_shader_parameter("tint",tint)
	material.set_shader_parameter("shelf_start",shelf_start)
	material.set_shader_parameter("shelf_end",shelf_end)
	art.material = material
	parent.add_child(art)
	parent.move_child(art,0)
