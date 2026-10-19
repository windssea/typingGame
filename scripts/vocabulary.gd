class_name Vocabulary
extends RefCounted

static var bank: Dictionary = {}

static func data() -> Dictionary:
	if bank.is_empty():
		bank = JSON.parse_string(FileAccess.get_file_as_string("res://data/a2-vocabulary.json"))
	return bank

static func topics() -> Array:
	return [{"id":"mixed","name":"全部主题"}]+data().topics

static func supports(lesson: Dictionary) -> bool:
	return lesson.id in ["short_words","long_words","shift","phrases"]

static func lesson(base: Dictionary, topic := "mixed") -> Dictionary:
	var result := base.duplicate(true)
	if not supports(base):
		return result
	var words: Array[String] = []
	var meanings: Dictionary = {}
	for entry in data().entries:
		if topic!="mixed" and entry.topic!=topic:
			continue
		var value: String = entry.text
		if base.id=="phrases":
			if entry.kind!="phrase":
				continue
		else:
			if entry.kind!="word":
				continue
			if base.id!="shift" and value!=value.to_lower():
				continue
			if base.id=="short_words" and value.length()>4:
				continue
			if base.id=="long_words" and (value.length()<5 or value.length()>12):
				continue
			if base.id=="shift":
				value = value.capitalize()
		words.append(value)
		meanings[value] = entry.meaning
	if not words.is_empty():
		result.words = words
		result.meanings = meanings
		result.vocabulary_topic = topic
	return result

static func meaning(lesson_data: Dictionary, word: String) -> String:
	return lesson_data.get("meanings",{}).get(word,"")
