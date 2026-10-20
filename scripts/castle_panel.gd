class_name CastlePanel
extends Control

var app: Control
var battle: CastleRun
var live_label: Label
var target_label: Label
var observed_phase := ""
var content: VBoxContainer
var update_pending := false

func _ready() -> void:
	battle.phase_changed.connect(rebuild)
	battle.hud_changed.connect(request_update)
	battle.key_feedback.connect(func(_key,_accepted,_point): request_update())
	battle.effect.connect(func(_kind,_origin,_destination,_amount): request_update())
	rebuild()

func request_update() -> void:
	if not update_pending:
		update_pending = true
		update_live.call_deferred()

func rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_text: String = focused.text if focused is Button and is_ancestor_of(focused) else ""
	for child in get_children():
		remove_child(child)
		child.queue_free()
	observed_phase = battle.phase
	var surface := UiLayout.framed(self,Color("daeee9"))
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = UiLayout.column(UiLayout.margin(surface,24),6)
	UiLayout.text(content,"布置防线" if battle.phase=="build" else "守城魔法",26,PlayTheme.TEXT)
	live_label = UiLayout.text(content,"",20,PlayTheme.TEAL)
	if battle.phase == "build":
		build_controls()
	else:
		battle_controls()
	update_live()
	restore_focus.call_deferred(focus_text)

func restore_focus(value: String) -> void:
	if battle.phase != "build" or battle.paused or battle.done:
		return
	for control in find_children("*", "Button", true, false):
		if control.text == value and not control.disabled:
			control.grab_focus()
			return
	app.ensure_keyboard_focus()

func command(key: String, value: String, callback: Callable, primary := false, parent: Control = content) -> Button:
	var row := UiLayout.row(parent,6)
	var shortcut := UiLayout.text(row,key,18,PlayTheme.TEAL)
	shortcut.custom_minimum_size.x = 24
	shortcut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var control: Button = app.button(value,Vector2.ZERO,Vector2(0,44),callback,primary,row)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size",17)
	control.focus_entered.connect(func(): show_detail(control))
	control.mouse_entered.connect(func(): show_detail(control))
	return control

func show_detail(control: Button) -> void:
	var cue: ActionCue = app.layer.find_child("InputDock",true,false)
	if cue!=null:
		cue.explain_build(control.text,control.tooltip_text if not control.tooltip_text.is_empty() else "先布置好防线，再迎接下一波")

func build_controls() -> void:
	var pads := UiLayout.row(content,6)
	for i in range(4):
		app.button(str(i+1),Vector2.ZERO,Vector2(57,44),func(): battle.selected_pad=i; rebuild(),i==battle.selected_pad,pads)
	var towers := UiLayout.column(content,6)
	towers.custom_minimum_size.y = 144
	var tower := battle.tower_at(battle.selected_pad)
	if tower.is_empty():
		for i in range(3):
			var kind: String = ["fire","ice","storm"][i]
			var definition: Dictionary = CastleRun.TOWERS[kind]
			var control := command(["Q","W","E"][i],"%s  %d G" % [definition.name,definition.cost],func(): battle.build_tower(battle.selected_pad,kind),false,towers)
			control.disabled = battle.gold < definition.cost
			control.tooltip_text = definition.description
	else:
		UiLayout.text(towers,"%s · Lv.%d" % [CastleRun.TOWERS[tower.kind].name,tower.level],24)
		var detail := UiLayout.text(towers,CastleRun.TOWERS[tower.kind].description,18,PlayTheme.TEAL)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiLayout.space(towers,0,true)
		var control := command("U","已达最高等级" if tower.level>=3 else "升级防御塔  %d G" % battle.tower_upgrade_cost(tower.pad),func(): battle.upgrade_tower(battle.selected_pad),false,towers)
		control.disabled = tower.level>=3 or battle.gold < battle.tower_upgrade_cost(tower.pad)
	for i in range(3):
		var kind: String = ["power","chain","walls"][i]
		var level: int = battle.upgrades[kind]
		var cost: int = CastleRun.UPGRADES[kind].cost+level*25
		var control := command(["A","S","D"][i],"%s %d/3 · %d G" % [CastleRun.UPGRADES[kind].name,level,cost],func(): battle.purchase_upgrade(kind))
		control.disabled = level>=3 or battle.gold<cost
		control.tooltip_text = CastleRun.UPGRADES[kind].description
	var repair := command("R","修复城防 +35 · 35 G",func(): battle.repair())
	repair.disabled = battle.hp>=battle.max_hp or battle.gold<35
	UiLayout.space(content,0,true)
	command("N","开始第 %d 波  →" % battle.wave,func(): battle.begin_wave(),true)

func battle_controls() -> void:
	UiLayout.space(content,20)
	UiLayout.text(content,"当前威胁",22,PlayTheme.MUTED)
	target_label = UiLayout.text(content,"",26,PlayTheme.TEXT)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiLayout.space(content,0,true)
	UiLayout.text(content,"五连击，召唤雷电",24,PlayTheme.TEAL)
	UiLayout.text(content,"完成输入，为塔充能",20,PlayTheme.MUTED)

func update_live() -> void:
	update_pending = false
	if is_instance_valid(live_label):
		live_label.text = "%d 金币 · %d / 20 能量" % [battle.gold,battle.energy]
	if is_instance_valid(target_label):
		var target := battle.recommended_target()
		target_label.text = "等待下一位敌人" if target.is_empty() else "%s\n生命 %d / %d" % [CastleRun.ENEMIES[target.kind].name,maxi(0,target.health),target.max_health]+("\n"+EnemyTactics.caption(target) if not EnemyTactics.caption(target).is_empty() else "")
