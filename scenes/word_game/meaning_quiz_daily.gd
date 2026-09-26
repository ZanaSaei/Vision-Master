class_name MeaningQuizDaily
extends RefCounted

const DATA_PATH := "res://data/extracted_words.json"
const DAILY_QUESTION_COUNT := 10


static func questions_for_date(date_key: String) -> Array[Dictionary]:
	var words: Array[Dictionary] = _load_words()
	var pool: Array[Dictionary] = MeaningQuizQuestionBuilder.build_questions(words)
	var selected: Array[Dictionary] = []
	if pool.is_empty():
		return selected
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(date_key)
	var count: int = mini(DAILY_QUESTION_COUNT, pool.size())
	for _index: int in count:
		var pick: int = rng.randi_range(0, pool.size() - 1)
		selected.append(pool[pick])
		pool.remove_at(pick)
	return selected


static func _load_words() -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	if not FileAccess.file_exists(DATA_PATH):
		return words
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Array:
		return words
	for raw: Variant in parsed:
		if raw is Dictionary:
			words.append(raw)
	return words
