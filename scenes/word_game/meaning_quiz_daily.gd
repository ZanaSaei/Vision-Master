class_name MeaningQuizDaily
extends RefCounted

const DATA_PATH := "res://data/extracted_words.json"
const DAILY_QUESTION_COUNT := 10
const SECONDS_PER_DAY := 86400


static func now_utc_unix() -> int:
	return int(Time.get_unix_time_from_system())


static func date_key() -> String:
	return Time.get_date_string_from_unix_time(now_utc_unix())


static func puzzle_id() -> String:
	return "meaning-%s" % date_key()


static func seconds_until_next_day() -> int:
	var now: int = now_utc_unix()
	var day_start: int = int(floor(float(now) / float(SECONDS_PER_DAY))) * SECONDS_PER_DAY
	return maxi(1, day_start + SECONDS_PER_DAY - now)


static func time_left_text() -> String:
	var left: int = seconds_until_next_day()
	var hours: int = int(floor(float(left) / 3600.0))
	var minutes: int = int(floor(float(left % 3600) / 60.0))
	if hours > 0:
		return "%s ساعت و %s دقیقه" % [digits(hours), digits(minutes)]
	if minutes > 0:
		return "%s دقیقه" % digits(minutes)
	return "کمتر از یک دقیقه"


static func digits(value: int) -> String:
	var output: String = ""
	for character: String in str(value):
		var code: int = character.unicode_at(0)
		output += char(code + 1728) if code >= 48 and code <= 57 else character
	return output


static func questions_for_date(question_date_key: String) -> Array[Dictionary]:
	var words: Array[Dictionary] = _load_words()
	var pool: Array[Dictionary] = MeaningQuizQuestionBuilder.build_questions(words)
	var selected: Array[Dictionary] = []
	if pool.is_empty():
		return selected
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(question_date_key)
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
