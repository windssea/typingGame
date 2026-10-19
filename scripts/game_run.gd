class_name GameRun
extends RefCounted

signal spell(origin: Vector2, target: Vector2, lightning: bool)
signal ended
signal key_feedback(character: String, accepted: bool, point: Vector2)

var mode: String
var lesson: Dictionary
var targets: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var spawn_clock := 0.5
var hp := 100
var score := 0
var kills := 0
var combo := 0
var best_combo := 0
var correct := 0
var attempts := 0
var key_stats: Dictionary = {}
var locked := -1
var next_id := 0
var wave := 1
var spawned := 0
var done := false
var won := false
var paused := false
var feedback := "输入目标的第一个字母即可锁定"
var difficulty := 1.0
var context := "training"
var challenge_rank := "normal"
var word_bag: Array = []
var recent_words: Array[String] = []
var last_word := ""
var last_meaning := ""
var last_completion_point := Vector2.INF
const CENTER := Vector2(680, 345)

func setup(mode_id: String, lesson_data: Dictionary, pace := 1.0, seed_value := 0) -> void:
	mode = mode_id
	lesson = lesson_data
	difficulty = pace
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	if mode == "dojo":
		spawn_target()
	elif mode == "sprint":
		spawn_target()
	elif mode == "bubbles":
		for i in range(4):
			spawn_target()

func accuracy() -> float:
	return float(correct) / attempts if attempts > 0 else 1.0

func wpm() -> float:
	return correct / 5.0 / (maxf(elapsed, 1.0) / 60.0)

func target_by_id(id: int) -> Dictionary:
	for target in targets:
		if target.id == id:
			return target
	return {}

func recommended_target() -> Dictionary:
	var target := target_by_id(locked)
	if not target.is_empty():
		return target
	if targets.is_empty():
		return {}
	var ordered := targets.duplicate()
	ordered.sort_custom(higher_priority)
	return ordered[0]

func higher_priority(a: Dictionary, b: Dictionary) -> bool:
	var first := priority(a)
	var second := priority(b)
	return int(a.id)<int(b.id) if is_equal_approx(first,second) else first<second

func next_word() -> String:
	if word_bag.is_empty():
		word_bag = lesson.words.duplicate()
		for i in range(word_bag.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var value = word_bag[i]
			word_bag[i] = word_bag[j]
			word_bag[j] = value
	var choice := 0
	var best := -100
	for i in range(word_bag.size()):
		var value: String = word_bag[i]
		var rating := 4 if not recent_words.has(value) else 0
		if not targets.any(func(t): return t.word[0]==value[0]):
			rating += 2
		if not targets.any(func(t): return t.word==value):
			rating += 1
		if rating>best:
			choice = i
			best = rating
		if best==7:
			break
	var word: String = word_bag[choice]
	word_bag.remove_at(choice)
	recent_words.append(word)
	while recent_words.size()>mini(8,maxi(1,lesson.words.size()-1)):
		recent_words.pop_front()
	return word

func spawn_target() -> void:
	var word := next_word()
	var position := CENTER
	if mode == "rain":
		position = Vector2(150 + (next_id % 5) * 260, 82)
	if mode == "dojo":
		position = CENTER
	elif mode == "sprint":
		position = CENTER
	elif mode == "bubbles":
		# Six anchors for four bubbles: the next bubble never obscures the pop.
		for offset in range(6):
			var lane := (next_id+offset)%6
			var candidate := Vector2(245+(lane%3)*430,215+(lane/3)*215)
			if candidate.distance_to(last_completion_point)>1 and targets.all(func(t): return t.position.distance_to(candidate)>1):
				position = candidate
				break
	var kind := next_id % 3
	var speed: float = float(lesson.speed) * difficulty * (1.0 + (wave - 1) * 0.12)
	if kind == 1:
		speed *= 1.25
	elif kind == 2:
		speed *= 0.8
	# Preserve an achievable travel time for words and sentences at every pace.
	if mode=="rain":
		speed = minf(speed,493.0/((10.0+word.length()*1.2)/difficulty))
	targets.append({"id":next_id,"word":word,"typed":0,"position":position,"speed":speed,"kind":kind})
	next_id += 1
	spawned += 1

func step(delta: float) -> void:
	if done or paused:
		return
	elapsed += delta
	if mode in ["dojo", "bubbles"]:
		return
	if mode == "sprint":
		if elapsed >= 60:
			var rank := SessionOptions.rank_index(challenge_rank)
			finish(context!="challenge" or (correct>=[18,36,60][rank] and accuracy()>=[0.85,0.9,0.95][rank]))
		return
	if mode == "rain" and elapsed >= 90:
		finish(true)
		return
	spawn_clock -= delta
	var cap := 2 if str(lesson.id) == "phrases" else 5
	if spawn_clock <= 0 and targets.size() < cap:
		spawn_target()
		spawn_clock = 3.8 / difficulty
	for target in targets.duplicate():
		target.position.y += target.speed * delta
		var reached: bool = target.position.y > 575
		if reached:
			hp = maxi(0, hp - (20+5*SessionOptions.rank_index(challenge_rank) if context=="challenge" else 20))
			combo = 0
			feedback = "防线受损！先处理距离最近的目标"
			if locked == target.id:
				locked = -1
			targets.erase(target)
			if hp == 0:
				finish(false)
				return

func priority(target: Dictionary) -> float:
	if mode == "rain":
		return (575.0 - target.position.y) / target.speed
	return target.position.distance_to(CENTER) / target.speed

func type_character(character: String) -> bool:
	if done or paused or targets.is_empty() or not allows_typing():
		return false
	var target := target_by_id(locked)
	if target.is_empty():
		var candidates := targets.filter(func(t): return t.word.begins_with(character))
		candidates.sort_custom(higher_priority)
		if not candidates.is_empty():
			target = candidates[0]
			locked = target.id
		elif mode == "dojo":
			target = targets[0]
	var expected: String = str(target.word).substr(target.typed, 1) if not target.is_empty() else character
	var stat: Dictionary = key_stats.get(expected, {"hit":0,"miss":0})
	attempts += 1
	if target.is_empty() or expected != character:
		stat.miss += 1
		key_stats[expected] = stat
		combo = 0
		feedback = "按键不匹配，进度保留；继续输入高亮位置"
		key_feedback.emit(character,false,target.get("position",CENTER))
		return false
	stat.hit += 1
	key_stats[expected] = stat
	correct += 1
	target.typed += 1
	key_feedback.emit(character,true,target.position)
	feedback = "正确！保持节奏"
	if target.typed == str(target.word).length():
		last_word = target.word
		last_meaning = Vocabulary.meaning(lesson,target.word)
		combo += 1
		best_combo = maxi(best_combo, combo)
		on_word_completed(target)
	return true

func allows_typing() -> bool:
	return true

func on_word_completed(target: Dictionary) -> void:
	defeat(target, false)
	if mode in ["dojo", "bubbles"]:
		if kills >= 18:
			finish(true)
		elif mode == "dojo" or kills + targets.size() < 18:
			spawn_target()
	elif mode == "sprint":
		spawn_target()

func defeat(target: Dictionary, lightning: bool) -> void:
	last_completion_point = target.position
	spell.emit(CENTER, target.position, lightning)
	score += str(target.word).length() * 10 + mini(combo, 20) * 5
	kills += 1
	targets.erase(target)
	if locked == target.id:
		locked = -1

func backspace() -> void:
	if paused or done:
		return
	var target := target_by_id(locked)
	if not target.is_empty() and target.typed > 0:
		target.typed -= 1
		# Retracted correct characters cannot inflate WPM or accuracy by retyping.
		correct = maxi(0, correct - 1)
		if target.typed == 0:
			locked = -1

func cancel_target() -> void:
	var target := target_by_id(locked)
	if not target.is_empty():
		correct = maxi(0, correct - int(target.typed))
		target.typed = 0
	locked = -1
	feedback = "已解除锁定，请输入新的目标"

func finish(success: bool) -> void:
	if done:
		return
	done = true
	won = success
	ended.emit()
