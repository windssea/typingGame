class_name CastlePanel
extends Control

var app: Control
var battle: CastleRun
var live_label: Label
var target_label: Label
var observed_phase := ""

func _ready() -> void:
	battle.phase_changed.connect(rebuild)
	rebuild()

func rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_text: String = focused.text if focused is Button and is_ancestor_of(focused) else ""
	for child in get_children():
		remove_child(child)
		child.queue_free()
	observed_phase = battle.phase
	app.panel(Vector2.ZERO,Vector2(290,650),Color("ffffff"),self)
	app.label("防线指挥所",Vector2(20,18),23,GameArena.GOLD,self)
	live_label = app.label("",Vector2(20,58),18,GameArena.MINT,self)
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

func build_controls() -> void:
	app.label("1–4 选基座 · U 升级塔",Vector2(20,105),16,Color("293c59"),self)
	for i in range(4):
		app.button(str(i+1),Vector2(20+i*64,141),Vector2(57,40),func(): battle.selected_pad=i; rebuild(),i==battle.selected_pad,self)
	var tower := battle.tower_at(battle.selected_pad)
	if tower.is_empty():
		var i := 0
		for kind in ["fire","ice","storm"]:
			var definition: Dictionary = CastleRun.TOWERS[kind]
			var control: Button = app.button("%s  %d G" % [definition.name,definition.cost],Vector2(20,201+i*49),Vector2(250,43),func(): battle.build_tower(battle.selected_pad,kind),false,self)
			control.disabled = battle.gold < definition.cost
			control.tooltip_text = definition.description
			i += 1
	else:
		app.label("%s · Lv.%d" % [CastleRun.TOWERS[tower.kind].name,tower.level],Vector2(20,199),21,GameArena.GOLD,self)
		app.label(CastleRun.TOWERS[tower.kind].description,Vector2(20,239),15,Color("586d84"),self)
		var control: Button = app.button("已达最高等级" if tower.level>=3 else "升级防御塔  %d G" % battle.tower_upgrade_cost(tower.pad),Vector2(20,281),Vector2(250,44),func(): battle.upgrade_tower(battle.selected_pad),false,self)
		control.disabled = tower.level>=3 or battle.gold < battle.tower_upgrade_cost(tower.pad)
	app.label("Q/W/E 建塔 · A/S/D 强化",Vector2(20,357),15,Color("293c59"),self)
	var i := 0
	for kind in ["power","chain","walls"]:
		var level: int = battle.upgrades[kind]
		var cost: int = CastleRun.UPGRADES[kind].cost+level*25
		var text_value := "%s %d/3 · %d G" % [CastleRun.UPGRADES[kind].name,level,cost]
		var control: Button = app.button(text_value,Vector2(20,391+i*45),Vector2(250,39),func(): battle.purchase_upgrade(kind),false,self)
		control.disabled = level>=3 or battle.gold<cost
		control.tooltip_text = CastleRun.UPGRADES[kind].description
		i += 1
	var repair: Button = app.button("修复城防 +35 · 35 G",Vector2(20,533),Vector2(250,40),func(): battle.repair(),false,self)
	repair.disabled = battle.hp>=battle.max_hp or battle.gold<35
	app.label("R 修复 · N 开战 · Enter 确认",Vector2(20,575),13,Color("586d84"),self)
	app.button("开始第 %d 波  →" % battle.wave,Vector2(20,592),Vector2(250,44),func(): battle.begin_wave(),true,self)

func battle_controls() -> void:
	app.label("正确输入，为防御塔充能",Vector2(20,108),17,Color("293c59"),self)
	app.label("每完成一次目标 +2 能量\n每次塔攻击消耗 1 能量\n五连击自动释放连锁雷电",Vector2(20,145),16,Color("586d84"),self)
	app.label("战场情报",Vector2(20,245),20,GameArena.GOLD,self)
	var enemy_rows := [["疾行兽","移动迅速，优先拦截"],["铁盾卫","高生命，需要多次施法"],["荒野萨满","周期治疗附近敌人"],["爆破兵","突破造成大量城防损失"],["统领 / 王","输入它的符文打断蓄力"]]
	for i in range(enemy_rows.size()):
		app.label(enemy_rows[i][0],Vector2(20,284+i*48),16,Color("293c59"),self)
		app.label(enemy_rows[i][1],Vector2(20,307+i*48),14,Color("586d84"),self)
	target_label = app.label("",Vector2(20,543),16,GameArena.MINT,self)
	app.label("波间可继续建造和强化。",Vector2(20,611),15,Color("586d84"),self)

func _process(_delta: float) -> void:
	update_live()

func update_live() -> void:
	if is_instance_valid(live_label):
		live_label.text = "金币 %d G    能量 %d / 20" % [battle.gold,battle.energy]
	if is_instance_valid(target_label):
		var target := battle.target_by_id(battle.locked)
		target_label.text = "输入首字符选择目标" if target.is_empty() else "锁定：%s\n生命 %d / %d" % [CastleRun.ENEMIES[target.kind].name,maxi(0,target.health),target.max_health]

