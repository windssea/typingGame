class_name ProfileStore
extends RefCounted

const VERSION := 1
var path := "user://profile.json"
var data: Dictionary = fresh()
var status := "本地存档已就绪"

static func fresh() -> Dictionary:
	return {"version":VERSION,"xp":0,"completed":{},"records":{},"key_stats":{},"settings":{"reduced_motion":false},"last_lesson":0}

func parse_text(value: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(value) == OK else null

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != VERSION:
		return false
	for field in ["completed", "records", "key_stats", "settings"]:
		if not value.get(field) is Dictionary:
			return false
	for field in ["xp", "last_lesson"]:
		if not value.get(field) is float and not value.get(field) is int:
			return false
	if value.xp < 0 or value.xp > 100000000 or value.last_lesson < 0 or value.last_lesson > 9:
		return false
	if not value.settings.get("reduced_motion", false) is bool:
		return false
	if not value.settings.get("sound", true) is bool:
		return false
	var speed = value.settings.get("training_speed",1.0)
	if (not speed is float and not speed is int) or not speed in SessionOptions.SPEEDS:
		return false
	if not value.settings.get("challenge_rank","normal") in SessionOptions.RANK_IDS:
		return false
	if not value.settings.get("vocabulary_topic","mixed") in Vocabulary.topics().map(func(t): return t.id):
		return false
	for record in value.records.values():
		if not record is Dictionary:
			return false
		for field in ["score", "accuracy", "wpm"]:
			if not record.get(field) is float and not record.get(field) is int:
				return false
	for stat in value.key_stats.values():
		if not stat is Dictionary or not stat.get("hit") is float and not stat.get("hit") is int or not stat.get("miss") is float and not stat.get("miss") is int:
			return false
	return true

func load_profile() -> void:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var value = parse_text(FileAccess.get_file_as_string(candidate))
			if valid(value):
				data = value
				status = "已恢复备份存档" if candidate.ends_with(".bak") else "已读取本地存档"
				return
	if FileAccess.file_exists(path):
		status = "存档损坏，已使用新档；原文件保留"

func save_profile() -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		status = "存档写入失败，请导出备份"
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var old = parse_text(FileAccess.get_file_as_string(path))
		if valid(old):
			if DirAccess.copy_absolute(path, path + ".bak") != OK:
				status = "备份写入失败，旧存档已保留"
				return false
	var error := DirAccess.rename_absolute(path + ".tmp", path)
	status = "进度已保存到本机" if error == OK else "存档替换失败，请导出备份"
	return error == OK

func record_run(run: RefCounted, lesson_index: int) -> void:
	var id: String = run.context + ":" + run.mode + ":" + run.lesson.id
	id += SessionOptions.record_suffix(run.context,run.difficulty,run.challenge_rank)
	if run.lesson.has("vocabulary_topic"):
		id += ":a2:"+str(run.lesson.vocabulary_topic)
	var result: Dictionary = {"score":run.score,"accuracy":run.accuracy(),"wpm":run.wpm()}
	if result.score >= data.records.get(id, {}).get("score", -1):
		data.records[id] = result
	data.xp += run.kills * 5
	data.last_lesson = lesson_index
	if run.context == "training" and run.won and run.accuracy() >= 0.9 and run.correct >= 18:
		data.completed[run.lesson.id] = true
	for key in run.key_stats:
		var previous: Dictionary = data.key_stats.get(key, {"hit":0,"miss":0})
		previous.hit += run.key_stats[key].hit
		previous.miss += run.key_stats[key].miss
		data.key_stats[key] = previous
	save_profile()

func import_text(value: String) -> bool:
	if value.length() > 2000000:
		return false
	var parsed = parse_text(value)
	if not valid(parsed):
		return false
	var previous := data
	data = parsed
	if not save_profile():
		data = previous
		return false
	return true
