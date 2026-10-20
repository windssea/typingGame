class_name GameShell
extends MarginContainer

var heading: VBoxContainer
var header: HBoxContainer
var actions: HBoxContainer
var field: Control
var sidebar: VBoxContainer
var dock: Control
var wide_stage := false

func _init() -> void:
	name = "GameShell"
	for edge in ["left","right"]:
		add_theme_constant_override("margin_"+edge,40)
	add_theme_constant_override("margin_top",24)
	add_theme_constant_override("margin_bottom",12)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := UiLayout.column(self,0)
	header = UiLayout.row(stack,16)
	header.custom_minimum_size.y = 80
	heading = UiLayout.column(header,4)
	heading.custom_minimum_size.x = 300
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Metrics are inserted between heading and actions by the caller.
	actions = UiLayout.row(header,8)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiLayout.space(stack,16)
	var body := UiLayout.row(stack,20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field = Control.new()
	field.name = "PlayfieldSlot"
	field.custom_minimum_size = Vector2(1360 if wide_stage else 1040,650)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(field)
	sidebar = UiLayout.column(body,0)
	sidebar.name = "AssistantSlot"
	sidebar.custom_minimum_size.x = 300
	sidebar.visible = not wide_stage
	UiLayout.space(stack,10)
	dock = Control.new()
	dock.custom_minimum_size.y = 108
	stack.add_child(dock)
