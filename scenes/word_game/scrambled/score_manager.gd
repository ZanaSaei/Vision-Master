class_name ScrambledScoreManager
extends RefCounted

const SAVE_PATH := "user://scrambled_words.json"
const SCHEMA := 1
const WORDS_PER_DAY := ScrambledDailyPicker.WORDS_PER_DAY
const MAX_WORD_POINTS := 100
const MIN_WORD_POINTS := 10
const HINT_PENALTY := 10
const MAX_DAILY_SCORE := MAX_WORD_POINTS * WORDS_PER_DAY
const MIN_DAILY_SCORE := MIN_WORD_POINTS * WORDS_PER_DAY
const SCORE_TABLE := [
	{"seconds": 10.0, "points": 100},
	{"seconds": 30.0, "points": 60},
	{"seconds": 50.0, "points": 40},
	{"seconds": 60.0, "points": 30},
]
const SLOWEST_POINTS := 20
const RATINGS := [
	{"min_score": 450, "label": "شگفت‌انگیز!", "emoji": ""},
	{"min_score": 350, "label": "خیلی خوب", "emoji": "🌟"},
	{"min_score": 250, "label": "خوب", "emoji": "👍"},
	{"min_score": 150, "label": "قابل قبول", "emoji": "🙂"},
	{"min_score": 0, "label": "دوباره تلاش کن", "emoji": ""},
]
static var _data: Dictionary = {}
static var _loaded := false

static func base_points_for(seconds: float) -> int:
	for row in SCORE_TABLE:
		if seconds <= float(row["seconds"]):
			return int(row["points"])
	return SLOWEST_POINTS

static func points_for(seconds: float, hint_used: bool) -> int:
	var points := base_points_for(seconds)
	if hint_used:
		points = int(floor(float(points) / 2.0))
	return maxi(MIN_WORD_POINTS, points)

static func rating_for(score: int) -> Dictionary:
	for band in RATINGS:
		if score >= int(band["min_score"]):
			return band
	return RATINGS[RATINGS.size() - 1]

static func today_key() -> String:
	return ScrambledDailyPicker.date_key()

static func today_score() -> int:
	_ensure_loaded()
	return int(_today_entry().get("score", 0))

static func today_attempts() -> int:
	_ensure_loaded()
	return int(_today_entry().get("attempts", 0))

static func today_played() -> bool:
	return today_attempts() > 0

static func best_score() -> int:
	_ensure_loaded()
	return int(_data.get("best_daily", 0))

static func best_score_date() -> String:
	_ensure_loaded()
	return str(_data.get("best_daily_date", ""))

static func played_days() -> int:
	_ensure_loaded()
	return (_data.get("daily", {}) as Dictionary).size()

static func total_attempts() -> int:
	_ensure_loaded()
	var total := 0
	for entry in (_data.get("daily", {}) as Dictionary).values():
		if entry is Dictionary:
			total += int((entry as Dictionary).get("attempts", 0))
	return total

static func save_daily_attempt(score: int, words_played: int, hints_used: int, seconds: float) -> bool:
	_ensure_loaded()
	var key := today_key()
	var daily: Dictionary = _data["daily"]
	var entry: Dictionary = daily.get(key, {}) if daily.get(key) is Dictionary else {}
	var previous_best := int(entry.get("score", 0))
	var improved := score > previous_best
	entry["score"] = maxi(previous_best, score)
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	entry["words"] = maxi(0, words_played)
	entry["hints"] = maxi(0, hints_used)
	entry["seconds"] = snappedf(maxf(0.0, seconds), 0.1)
	daily[key] = entry
	_data["daily"] = daily
	_data["played_days"] = daily.size()
	if score > int(_data.get("best_daily", 0)):
		_data["best_daily"] = score
		_data["best_daily_date"] = key
	_save()
	return improved

static func daily_history(limit: int = 7) -> Array:
	_ensure_loaded()
	var keys: Array = (_data.get("daily", {}) as Dictionary).keys()
	keys.sort()
	var out: Array = []
	for i in range(keys.size() - 1, -1, -1):
		if out.size() >= limit:
			break
		var key := str(keys[i])
		var entry: Dictionary = (_data["daily"] as Dictionary).get(key, {})
		out.append({"date": key, "score": int(entry.get("score", 0)), "attempts": int(entry.get("attempts", 0))})
	return out

static func practice_key(book: int, lesson: int) -> String:
	return "%d_%d" % [book, lesson]

static func record_practice_word(book: int, lesson: int, hint_used: bool, seconds: float) -> void:
	_ensure_loaded()
	var key := practice_key(book, lesson)
	var practice: Dictionary = _data["practice"]
	var entry: Dictionary = practice.get(key, {}) if practice.get(key) is Dictionary else {}
	entry["plays"] = int(entry.get("plays", 0)) + 1
	entry["words"] = int(entry.get("words", 0)) + 1
	entry["hints"] = int(entry.get("hints", 0)) + (1 if hint_used else 0)
	entry["seconds"] = snappedf(float(entry.get("seconds", 0.0)) + maxf(0.0, seconds), 0.1)
	practice[key] = entry
	_data["practice"] = practice
	_save()

static func practice_stats(book: int, lesson: int) -> Dictionary:
	_ensure_loaded()
	var entry = (_data.get("practice", {}) as Dictionary).get(practice_key(book, lesson), {})
	var out := {"plays": 0, "words": 0, "hints": 0, "seconds": 0.0}
	if entry is Dictionary:
		out["plays"] = int(entry.get("plays", 0))
		out["words"] = int(entry.get("words", 0))
		out["hints"] = int(entry.get("hints", 0))
		out["seconds"] = float(entry.get("seconds", 0.0))
	return out

static func total_practice_words() -> int:
	_ensure_loaded()
	var total := 0
	for entry in (_data.get("practice", {}) as Dictionary).values():
		if entry is Dictionary:
			total += int((entry as Dictionary).get("words", 0))
	return total

static func practice_summary() -> Dictionary:
	_ensure_loaded()
	var out := {"lessons": 0, "words": 0, "hints": 0, "seconds": 0.0}
	for entry in (_data.get("practice", {}) as Dictionary).values():
		if not (entry is Dictionary):
			continue
		out["lessons"] = int(out["lessons"]) + 1
		out["words"] = int(out["words"]) + int((entry as Dictionary).get("words", 0))
		out["hints"] = int(out["hints"]) + int((entry as Dictionary).get("hints", 0))
		out["seconds"] = float(out["seconds"]) + float((entry as Dictionary).get("seconds", 0.0))
	return out

static func reset_cache() -> void:
	_data = {}
	_loaded = false

static func _today_entry() -> Dictionary:
	var entry = (_data.get("daily", {}) as Dictionary).get(today_key(), {})
	return entry if entry is Dictionary else {}

static func _default_data() -> Dictionary:
	return {"schema": SCHEMA, "best_daily": 0, "best_daily_date": "", "played_days": 0, "daily": {}, "practice": {}}

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("ScrambledScoreManager: ignoring an unreadable %s" % SAVE_PATH)
		return
	var stored: Dictionary = json.data
	_data["schema"] = int(stored.get("schema", SCHEMA))
	_data["best_daily"] = maxi(0, int(stored.get("best_daily", 0)))
	_data["best_daily_date"] = str(stored.get("best_daily_date", ""))
	var daily = stored.get("daily", {})
	if daily is Dictionary:
		_data["daily"] = daily
	var practice = stored.get("practice", {})
	if practice is Dictionary:
		_data["practice"] = practice
	_data["played_days"] = (_data["daily"] as Dictionary).size()

static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("ScrambledScoreManager: cannot write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_data, "  "))
	file.close()
