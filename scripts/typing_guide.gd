class_name TypingGuide
extends Control

const FONT = preload("res://assets/ui-font.ttf")
const NAMES := ["左手小指", "左手无名指", "左手中指", "左手食指", "右手食指", "右手中指", "右手无名指", "右手小指", "拇指"]
const HOMES := ["A", "S", "D", "F", "J", "K", "L", ";", "空格"]
const COLORS := [Color("e99bb7"), Color("edb960"), Color("98ca7f"), Color("65c5c0"), Color("65c5c0"), Color("98ca7f"), Color("edb960"), Color("e99bb7"), Color("9baee6")]
const GROUPS := ["`1qaz", "2wsx", "3edc", "45rtfgvb", "67yuhjnm", "8ik,", "9ol.", "0p;/-=[]\\'", " "]
var run: GameRun
var preview_character := "f"
var current := ""

static func mapping(character: String) -> Dictionary:
	var shifted := "~!@#$%^&*()_+{}|:\"<>?"
	var plain := "`1234567890-=[]\\;',./"
	var physical := character.to_lower()
	var needs_shift := character != physical
	var index := shifted.find(character) if character.length() == 1 else -1
	if index >= 0:
		physical = plain.substr(index, 1)
		needs_shift = true
	var finger := 8
	for i in range(GROUPS.size()):
		if physical.length() == 1 and physical in GROUPS[i]:
			finger = i
			break
	return {"key":physical, "finger":finger, "shift":needs_shift, "shift_hand":"右手小指" if finger < 4 else "左手小指"}

func suggested_character() -> String:
	if run == null:
		return preview_character
	if run.targets.is_empty():
		return ""
	var target := run.recommended_target()
	return str(target.word).substr(target.typed, 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var next := suggested_character()
	if next != current:
		current = next
		queue_redraw()

func text(value: String, p: Vector2, font_size := 16, color := PlayTheme.MUTED) -> void:
	draw_string(FONT,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func box(rect: Rect2, color: Color, border := PlayTheme.BORDER, radius := 12) -> void:
	draw_style_box(PlayTheme.game_panel(color,border,radius,3),rect)

func _draw() -> void:
	box(Rect2(0,0,300,580),Color("fafff8"),Color("bed5ca"),24)
	box(Rect2(12,12,276,155),Color("fff4d9"),Color.TRANSPARENT,16)
	text("我的指法小教练",Vector2(20,35),22,PlayTheme.ORANGE)
	var data := mapping(current)
	var key_label := "空格" if current == " " else current
	text(key_label if current != "" else "准备",Vector2(22,122),40,PlayTheme.TEXT)
	text(NAMES[data.finger] if current != "" else "双手回到基准行",Vector2(117,117),18,PlayTheme.TEXT)
	var instruction: String = "+ " + data.shift_hand + " Shift" if data.shift else "回到 " + HOMES[data.finger]
	text("" if current == "" else instruction,Vector2(20,156),17)
	# Full US QWERTY, including both Shift keys and punctuation.
	draw_set_transform(Vector2(12,181),0,Vector2(0.42,0.42))
	var rows := ["`1234567890-=", "qwertyuiop[]\\", "asdfghjkl;'", "zxcvbnm,./"]
	for r in range(rows.size()):
		for c in range(rows[r].length()):
			var key: String = rows[r].substr(c,1)
			var finger: int = mapping(key).finger
			var p := Vector2(12+r*14+c*46, r*49)
			var active: bool = current != "" and data.key == key
			box(Rect2(p,Vector2(42,43)),COLORS[finger] if active else COLORS[finger].lightened(0.8),COLORS[finger].darkened(0.15),8)
			text(key.to_upper(),p+Vector2(12,28),24,PlayTheme.TEXT)
			if key in "fj":
				draw_line(p+Vector2(12,36),p+Vector2(28,36),PlayTheme.TEXT,3)
	for side in range(2):
		var active: bool = data.shift and ((side == 0 and data.finger >= 4) or (side == 1 and data.finger < 4))
		var rect := Rect2(12+side*491,202,107,42)
		box(rect,PlayTheme.YELLOW if active else Color("edf2fa"))
		text("L Shift" if side == 0 else "R Shift",rect.position+Vector2(10,28),21,PlayTheme.TEXT)
	box(Rect2(148,202,305,42),COLORS[8] if current == " " else Color("edf2fa"))
	text("SPACE",Vector2(265,231),22,PlayTheme.TEXT)
	draw_set_transform(Vector2.ZERO)
	text("手指分工",Vector2(20,316),18)
	for side in range(2):
		var base := Vector2(24+side*145,460)
		box(Rect2(base,Vector2(106,72)),Color("fff0df"),Color("e8c9a8"),24)
		for digit in range(4):
			var finger := digit if side == 0 else digit+4
			var lengths := [48,70,82,65] if side == 0 else [65,82,70,48]
			var p := base+Vector2(digit*26, -lengths[digit]+12)
			var active: bool = current != "" and (data.finger == finger or (data.shift and finger == (7 if data.finger < 4 else 0)))
			box(Rect2(p,Vector2(23,lengths[digit]+20)),COLORS[finger] if active else COLORS[finger].lightened(0.72),COLORS[finger].darkened(0.1),11)
			text(HOMES[finger],p+Vector2(5,23),16,PlayTheme.TEXT)
		var thumb := base+Vector2(91 if side == 0 else -9,35)
		box(Rect2(thumb,Vector2(24,52)),COLORS[8] if current == " " else Color("e5eafa"),COLORS[8],12)
		text("左手" if side == 0 else "右手",base+Vector2(29,61),16)
