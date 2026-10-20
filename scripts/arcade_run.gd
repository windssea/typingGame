class_name ArcadeRun
extends GameRun

signal impact(kind: String, point: Vector2, power: int)

const MODES := ["balloons", "aliens", "moles", "racing", "fighter"]
var goal := 24
var shield := 40:
	set(value):
		if shield!=value:
			shield = value
			hud_changed.emit()
var distance := 0.0:
	set(value):
		var changed := int(distance*200)!=int(value*200)
		distance = value
		if changed:
			hud_changed.emit()
var rival := 0.0
var boost := 0.0
var enemy_hp := 100
var round_number := 1
var misses := 0
var skill_charge := 0
var skill_time := 0.0
var skill_uses := 0
var guard_ready := false
var previous_hole := -1

func skill_name() -> String:
	return {"balloons":"微风减速","aliens":"护盾脉冲","moles":"专注时刻","racing":"干扰对手","fighter":"准备格挡"}.get(mode,"")

func activate_skill() -> bool:
	if paused or done or skill_charge<3 or skill_time>0:
		return false
	skill_charge = 0
	skill_uses += 1
	skill_time = 4.0
	if mode=="aliens":
		shield = mini(60,shield+12)
	elif mode=="racing":
		rival = maxf(0,rival-0.08)
	elif mode=="fighter":
		guard_ready = true
	impact.emit("skill",Vector2(520,350),3)
	feedback = skill_name()+"！"+("对手退后 8%" if mode=="racing" else "专注输入，目标时间暂缓" if mode in ["moles","balloons","aliens"] else "下一次反击被格挡")
	return true

func setup(mode_id: String, lesson_data: Dictionary, pace := 1.0, seed_value := 0) -> void:
	super.setup(mode_id, lesson_data, pace, seed_value)
	goal = (24 if mode=="racing" else 18) if context == "training" else 30
	if context=="challenge":
		goal += SessionOptions.rank_index(challenge_rank)*6
	feedback = "输入目标文字；先找准手指，再追求连击"
	var initials: Array[String] = []
	for word in lesson.words:
		var initial := str(word).left(1)
		if not initials.has(initial):
			initials.append(initial)
	var count := mini(3,initials.size()) if mode in ["balloons", "aliens"] else 1
	if str(lesson.id) == "phrases":
		count = 1
	for i in range(count):
		spawn_target()

func time_budget(word: String) -> float:
	# Beginners have time to look between the target, keyboard and finger coach.
	return (12.0 + word.length() * 2.0 if context == "training" else 5.0 + word.length() * 0.65) / difficulty

func spawn_target() -> void:
	super.spawn_target()
	var target: Dictionary = targets.back()
	var lane := 0
	while targets.any(func(t): return t.id != target.id and t.get("lane", -1) == lane):
		lane += 1
	target.lane = lane
	target.duration = time_budget(target.word)
	target.remaining = target.duration
	target.feature = ""
	if mode=="balloons" and target.lane==2:
		target.feature = "bonus"
	elif mode=="aliens" and target.id%4==3:
		target.feature = "supply"
	elif mode=="aliens" and target.id%4==2:
		target.feature = "scout"
		target.duration *= 0.8
		target.remaining = target.duration
	elif mode=="moles" and target.id%4==3:
		target.feature = "bonus"
	match mode:
		"balloons": target.position = Vector2(200 + lane * 320, 490)
		"aliens": target.position = Vector2(200 + lane * 320, 180)
		"moles":
			var holes := [0,1,2,3,4,5]
			holes.erase(previous_hole)
			target.lane = holes[rng.randi_range(0,holes.size()-1)]
			previous_hole = target.lane
			target.position = Vector2(240 + (target.lane % 3) * 280, 300 + (target.lane / 3) * 170)
		"racing": target.position = Vector2(520, 164)
		"fighter": target.position = Vector2(700, 240)
	# A lesson's vocabulary never changes with the game skin or difficulty.

func priority(target: Dictionary) -> float:
	return float(target.remaining)

func step(delta: float) -> void:
	if paused or done:
		return
	var left := minf(delta, 0.5)
	while left > 0.0001 and not done:
		var tick := minf(left, 0.05)
		advance(tick)
		left -= tick

func advance(delta: float) -> void:
	elapsed += delta
	skill_time = maxf(0,skill_time-delta)
	boost = maxf(0, boost - delta)
	if mode == "racing":
		# Rival pace is based on this lesson's target lengths, not a fixed WPM gate.
		var average := 0.0
		for word in lesson.words:
			average += time_budget(word)
		average /= lesson.words.size()
		rival = minf(1, rival + delta / (average * goal * 0.7))
		if context == "challenge" and rival >= 1:
			finish(false)
			return
	for target in targets.duplicate():
		if mode == "racing":
			continue
		target.remaining -= delta*(0.2 if skill_time>0 and mode in ["moles","balloons","aliens"] else 1.0)
		var fraction: float = clampf(target.remaining / target.duration, 0, 1)
		if mode == "balloons":
			target.position.y = 115 + fraction * 375
		elif mode == "aliens":
			target.position.y = 440 - fraction * 260
		if target.remaining <= 0:
			miss_target(target)
			if done:
				return

func miss_target(target: Dictionary) -> void:
	misses += 1
	combo = 0
	if locked == target.id:
		locked = -1
	var damage := 10 if context == "training" else 20
	if context=="challenge":
		damage += SessionOptions.rank_index(challenge_rank)*5
	if mode == "aliens":
		var absorbed := mini(shield, damage)
		shield -= absorbed
		damage -= absorbed
	if mode=="fighter" and guard_ready:
		damage = 0
		guard_ready = false
	# Moles retreat in training: repetition without a failure countdown.
	if mode == "moles" and context == "training":
		damage = 0
	hp = maxi(0, hp - damage)
	impact.emit("block" if mode=="fighter" and damage==0 else "miss", target.position, damage)
	feedback = "地鼠藏起来了，下一只慢慢找准键位" if damage == 0 and mode == "moles" else "错过目标！优先输入计时条最短的目标"
	targets.erase(target)
	if hp <= 0:
		finish(false)
	else:
		spawn_target()

func on_word_completed(target: Dictionary) -> void:
	var point: Vector2 = target.position
	skill_charge = mini(3,skill_charge+1)
	if target.get("feature","")=="bonus":
		score += 40
		skill_charge = mini(3,skill_charge+1)
	elif target.get("feature","")=="supply":
		shield = mini(60,shield+8)
	defeat(target, combo % 5 == 0)
	if context=="training" and kills%6==0 and kills<goal:
		skill_charge = 3
	impact.emit(mode, point, combo)
	match mode:
		"aliens":
			if combo % 3 == 0:
				shield = mini(60, shield + 12)
			wave = 1 + kills / 8
			feedback = "激光命中！三连击恢复护盾 · 当前护盾 %d" % shield
		"racing":
			distance = minf(1, distance + (1.15 if combo>=3 else 1.0) / goal)
			boost = 0.9 if combo < 3 else 1.5
			feedback = "氮气加速！三连击后每次推进距离增加 15%" if combo>=3 else "稳定推进！连续准确输入三次可获得氮气加速"
		"fighter":
			enemy_hp = maxi(0, enemy_hp - 25)
			feedback = "打断攻击！%d 连击 · 重拳命中" % combo
			if enemy_hp == 0:
				round_number += 1
				enemy_hp = 100
				feedback = "击倒对手！下一位拳手登场"
		"balloons": feedback = "气球爆开！%d 连击" % combo
		"moles": feedback = "敲中了！%d 连击" % combo
	if (mode == "racing" and distance >= 1) or kills >= goal:
		finish(true)
	elif kills + targets.size() < goal:
		spawn_target()

func status_text() -> String:
	match mode:
		"aliens": return "护盾 %d · 船体 %d" % [shield, hp]
		"racing": return "赛程 %d%%" % roundi(distance * 100)
		"fighter": return "体力 %d · 对手 %d" % [hp, mini(round_number, ceili(goal / 4.0))]
		"moles": return "漏掉 %d · 体力 %d" % [misses, hp]
	return "机会 %d" % ceili(hp / (10.0 if context == "training" else 20.0))
