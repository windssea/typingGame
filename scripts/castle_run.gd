class_name CastleRun
extends GameRun

signal effect(kind: String, origin: Vector2, destination: Vector2, amount: int)
signal phase_changed

const KEEP := Vector2(520, 330)
const PADS := [Vector2(350,240), Vector2(690,240), Vector2(350,440), Vector2(690,440)]
const WAVE_COUNTS := [6, 8, 7, 10, 12, 9]
const ENEMIES := {
	"goblin":{"name":"哥布林", "health":32, "speed":1.0, "damage":12, "gold":14},
	"wolf":{"name":"疾行兽", "health":25, "speed":1.55, "damage":10, "gold":16},
	"guard":{"name":"铁盾卫", "health":85, "speed":0.67, "damage":22, "gold":24},
	"shaman":{"name":"荒野萨满", "health":52, "speed":0.75, "damage":15, "gold":25},
	"bomber":{"name":"爆破兵", "health":44, "speed":0.9, "damage":30, "gold":23},
	"boss":{"name":"裂岩统领", "health":330, "speed":0.34, "damage":45, "gold":90}
}
const TOWERS := {
	"fire":{"name":"火焰塔", "cost":60, "damage":22, "range":250.0, "cooldown":1.3, "description":"火焰溅射 · 清理密集敌群"},
	"ice":{"name":"寒冰塔", "cost":70, "damage":10, "range":280.0, "cooldown":1.6, "description":"减速 50% · 争取输入时间"},
	"storm":{"name":"雷电塔", "cost":85, "damage":19, "range":270.0, "cooldown":1.8, "description":"连锁闪电 · 同时打击两敌"}
}
const UPGRADES := {
	"power":{"name":"烈焰精通", "description":"火球伤害 +14", "cost":65},
	"chain":{"name":"雷霆回响", "description":"连击雷电伤害 +16", "cost":65},
	"walls":{"name":"坚固城墙", "description":"城防上限 +25，并恢复 25", "cost":55}
}
var phase := "build"
var gold := 110
var max_hp := 100
var energy := 0
var towers: Array[Dictionary] = []
var upgrades := {"power":0,"chain":0,"walls":0}
var selected_pad := 0
var bosses_defeated := 0
var repair_count := 0
var boss_spawned := false
var banner := "黎明前的准备"
var boss_warning := 0.0
var words_completed := 0

func setup(mode_id: String, lesson_data: Dictionary, pace := 1.0, seed_value := 0) -> void:
	super.setup(mode_id, lesson_data, pace, seed_value)
	feedback = "先在四处基座建塔，再点击「开始第 1 波」。正确输入为塔充能。"

func allows_typing() -> bool:
	return phase == "assault"

func tower_at(pad: int) -> Dictionary:
	for tower in towers:
		if tower.pad == pad:
			return tower
	return {}

func can_build() -> bool:
	return phase == "build" and not done and not paused

func build_tower(pad: int, kind: String) -> bool:
	if not can_build() or pad < 0 or pad >= PADS.size() or not TOWERS.has(kind) or not tower_at(pad).is_empty():
		return false
	if gold < TOWERS[kind].cost:
		feedback = "金币不足，击退下一波敌人后再建设。"
		return false
	gold -= TOWERS[kind].cost
	towers.append({"pad":pad,"kind":kind,"level":1,"cooldown":0.0})
	feedback = TOWERS[kind].name + "已建造。完成一个输入目标，获得 2 点塔能量。"
	effect.emit("build",PADS[pad],PADS[pad],0)
	phase_changed.emit()
	return true

func tower_upgrade_cost(pad: int) -> int:
	var tower := tower_at(pad)
	return 45 + int(tower.get("level",1)) * 20

func upgrade_tower(pad: int) -> bool:
	var tower := tower_at(pad)
	if not can_build() or tower.is_empty() or tower.level >= 3 or gold < tower_upgrade_cost(pad):
		return false
	gold -= tower_upgrade_cost(pad)
	tower.level += 1
	feedback = "%s升级到 %d 级：伤害和射程提升。" % [TOWERS[tower.kind].name,tower.level]
	effect.emit("build",PADS[pad],PADS[pad],0)
	phase_changed.emit()
	return true

func purchase_upgrade(kind: String) -> bool:
	if not can_build() or not UPGRADES.has(kind) or upgrades[kind] >= 3:
		return false
	var cost: int = UPGRADES[kind].cost + upgrades[kind] * 25
	if gold < cost:
		return false
	gold -= cost
	upgrades[kind] += 1
	if kind == "walls":
		max_hp += 25
		hp = mini(max_hp,hp + 25)
	feedback = UPGRADES[kind].name + "已强化。"
	effect.emit("build",KEEP,KEEP,0)
	phase_changed.emit()
	return true

func repair() -> bool:
	if not can_build() or hp >= max_hp or gold < 35:
		return false
	gold -= 35
	hp = mini(max_hp, hp + 35)
	repair_count += 1
	feedback = "城防修复 +35。"
	phase_changed.emit()
	return true

func begin_wave() -> bool:
	if not can_build():
		return false
	phase = "assault"
	spawned = 0
	boss_spawned = false
	spawn_clock = 0.6
	banner = "第 %d 波 · %s" % [wave,wave_name()]
	feedback = "输入符文施放火球；连续完成 5 次目标，释放连锁雷电。"
	effect.emit("wave",KEEP,KEEP,wave)
	phase_changed.emit()
	return true

func wave_name() -> String:
	return ["森林哨兵","疾影突袭","裂岩统领","巫术之夜","爆破军团","最后的王座"][wave-1]

func choose_word() -> String:
	return next_word()

func spawn_target() -> void:
	var pool := ["goblin"]
	if wave >= 2:
		pool.append("wolf")
	if wave >= 3:
		pool.append("guard")
	if wave >= 4:
		pool.append("shaman")
	if wave >= 5:
		pool.append("bomber")
	var kind: String = pool[rng.randi_range(0,pool.size()-1)]
	if wave in [3,6] and not boss_spawned and spawned >= 2:
		kind = "boss"
		boss_spawned = true
	spawn_enemy(kind)
	spawned += 1

func spawn_enemy(kind: String) -> Dictionary:
	var definition: Dictionary = ENEMIES[kind]
	var position := Vector2.ZERO
	for trial in range(16):
		var angle := rng.randf_range(0,TAU)
		position = KEEP + Vector2(cos(angle)*455,sin(angle)*240)
		if targets.all(func(t): return position.distance_to(t.position) > 105):
			break
	var health: int = definition.health
	if kind == "boss" and wave == 6:
		health = 550
	if context=="challenge":
		health = ceili(health*(1.0+SessionOptions.rank_index(challenge_rank)*0.2))
	var target := {"id":next_id,"word":choose_word(),"typed":0,"position":position,
		"speed":float(lesson.speed)*float(definition.speed)*difficulty*(1.0+(wave-1)*0.07),
		"kind":kind,"health":health,"max_health":health,"slow":0.0,"flash":0.0,
		"timer":8.0,"windup":0.0,"rage":false,"phase":0.0,"siege":0.0}
	target.speed *= minf(1,5.0/maxi(5,str(target.word).length()))
	targets.append(target)
	next_id += 1
	if kind == "boss":
		banner = "BOSS 降临 · " + ("灰烬之王" if wave == 6 else "裂岩统领")
		effect.emit("boss",position,position,0)
	return target

func priority(target: Dictionary) -> float:
	return target.position.distance_to(KEEP) / maxf(1,target.speed)

func step(delta: float) -> void:
	if done or paused or phase != "assault":
		return
	# Substeps keep simultaneous damage and charge consumption stable after a slow frame.
	var remaining := minf(delta,0.5)
	while remaining > 0 and not done and phase == "assault":
		var dt := minf(remaining,0.05)
		advance(dt)
		remaining -= dt

func advance(dt: float) -> void:
	elapsed += dt
	spawn_clock -= dt
	var cap := 2 if str(lesson.id) == "phrases" else 7
	if spawn_clock <= 0 and targets.size() < cap and spawned < WAVE_COUNTS[wave-1]:
		spawn_target()
		spawn_clock = maxf(2.6,5.2-wave*0.3)/difficulty
	for target in targets.duplicate():
		target.slow = maxf(0,target.slow-dt)
		target.flash = maxf(0,target.flash-dt)
		target.phase += dt * 5
		var speed: float = target.speed * (0.5 if target.slow > 0 else 1.0)
		if target.rage:
			speed *= 1.3
		target.position = target.position.move_toward(KEEP,speed*dt)
		if target.kind == "shaman":
			target.timer -= dt
			if target.timer <= 0:
				target.timer = 7.0
				for other in targets:
					if other.id != target.id and other.position.distance_to(target.position) < 170:
						other.health = mini(other.max_health,other.health+12)
						effect.emit("heal",target.position,other.position,12)
		if target.kind == "boss":
			update_boss(target,dt)
			if done:
				return
		if target.position.distance_to(KEEP) < 62:
			if target.kind == "boss":
				target.siege -= dt
				if target.siege <= 0:
					target.siege = 3.5
					damage_castle(18)
			else:
				damage_castle(ENEMIES[target.kind].damage)
				remove_target(target)
			if done:
				return
	update_towers(dt)
	if targets.is_empty() and spawned >= WAVE_COUNTS[wave-1]:
		if wave == 6:
			finish(true)
		else:
			gold += 45
			wave += 1
			phase = "build"
			locked = -1
			banner = "防线守住了 · 建设与整备"
			feedback = "获得 45 金币补给。可以建塔、升级或修复，准备好后开始下一波。"
			phase_changed.emit()

func update_boss(target: Dictionary, dt: float) -> void:
	if target.health <= target.max_health * 0.5 and not target.rage:
		target.rage = true
		banner = "BOSS 狂暴 · 击中它可中断蓄力"
		effect.emit("rage",target.position,target.position,0)
	if target.windup > 0:
		target.windup -= dt
		if target.windup <= 0:
			effect.emit("quake",target.position,KEEP,18)
			damage_castle(18)
			target.timer = 9.0 if target.rage else 12.0
	else:
		target.timer -= dt
		if target.timer <= 0:
			# Long phrases receive a genuinely achievable interrupt window.
			target.windup = maxf(4.5,str(target.word).length()*0.7) / difficulty
			feedback = "统领正在蓄力！完成它的符文可打断震地攻击。"
			effect.emit("warning",target.position,KEEP,0)

func damage_castle(amount: int) -> void:
	if context=="challenge":
		amount = ceili(amount*(1.0+SessionOptions.rank_index(challenge_rank)*0.15))
	hp = maxi(0,hp-amount)
	combo = 0
	feedback = "城堡受到 %d 点伤害，优先拦截最近的敌人。" % amount
	effect.emit("damage",KEEP,KEEP,amount)
	if hp <= 0:
		finish(false)

func on_word_completed(target: Dictionary) -> void:
	words_completed += 1
	energy = mini(20,energy+2)
	var pos: Vector2 = target.position
	var amount: int = 36 + upgrades.power * 14
	if target.kind == "boss" and target.windup > 0:
		target.windup = 0.0
		target.timer = 10.0
		feedback = "蓄力打断！继续攻击弱点。"
		effect.emit("interrupt",pos,pos,0)
	damage_enemy(target,amount,"fire",KEEP)
	if combo > 0 and combo % 5 == 0:
		feedback = "五连击 · 雷霆连锁！"
		var nearby := targets.duplicate()
		nearby.sort_custom(func(a,b): return priority(a)<priority(b))
		var source := KEEP
		for other in nearby.slice(0,3):
			damage_enemy(other,40+upgrades.chain*16,"storm",source)
			source = other.position
	if targets.has(target):
		target.word = choose_word()
		target.typed = 0
		locked = target.id

func damage_enemy(target: Dictionary, amount: int, kind: String, source: Vector2) -> void:
	if not targets.has(target):
		return
	target.health -= amount
	target.flash = 0.22
	effect.emit(kind,source,target.position,amount)
	if target.health <= 0:
		score += str(target.word).length()*10 + mini(combo,20)*5
		kills += 1
		gold += ENEMIES[target.kind].gold
		if target.kind == "boss":
			bosses_defeated += 1
			score += 500
			banner = "统领已击败！"
		effect.emit("defeat",target.position,target.position,ENEMIES[target.kind].gold)
		remove_target(target)

func remove_target(target: Dictionary) -> void:
	if locked == target.id:
		# Tower kills preserve the player's already accepted characters.
		locked = -1
	targets.erase(target)

func update_towers(dt: float) -> void:
	for tower in towers:
		tower.cooldown = maxf(0,tower.cooldown-dt)
		if tower.cooldown > 0 or energy <= 0:
			continue
		var def: Dictionary = TOWERS[tower.kind]
		var origin: Vector2 = PADS[tower.pad]
		var reach: float = def.range + (tower.level-1)*22
		var available := targets.filter(func(t): return t.position.distance_to(origin) <= reach)
		available.sort_custom(func(a,b): return priority(a)<priority(b))
		if available.is_empty():
			continue
		energy -= 1
		tower.cooldown = def.cooldown / (1.0+(tower.level-1)*0.15)
		var target: Dictionary = available[0]
		var amount: int = int(def.damage) + (tower.level-1)*10
		damage_enemy(target,amount,tower.kind,origin)
		if tower.kind == "ice" and targets.has(target):
			target.slow = 3.0 + tower.level
		elif tower.kind == "storm" and available.size() > 1:
			damage_enemy(available[1],amount,"storm",target.position)
		elif tower.kind == "fire":
			for other in available.slice(1):
				if other.position.distance_to(target.position) < 95:
					damage_enemy(other,int(amount*0.5),"ember",target.position)

func finish(success: bool) -> void:
	phase = "finished"
	super.finish(success)
