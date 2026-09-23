class_name WordleStats
extends RefCounted
## ============================================================
##  WORDLE STATS — the player's daily-puzzle record.
##
##  Deliberately tiny: one JSON file next to the puzzle save holding four
##  counters plus a per-attempt histogram, so the end-of-game card can show
##  a streak without a separate statistics screen.
##
##  ROLLOVER RULE: a streak only survives when yesterday's puzzle was
##  played, which is why the day index of the last recorded puzzle is
##  stored alongside the streak. Recording is idempotent per puzzle id, so
##  re-opening a finished board (or restoring a save) can never inflate the
##  record.
##
##  Every read is guarded: a missing or corrupt file simply starts a fresh
##  record instead of breaking the game screen.
## ============================================================

const SAVE_PATH := "user://wordle_stats.json"

## Histogram buckets, one per possible attempt count (1..MAX_GUESSES).
const MAX_ATTEMPTS_BUCKETS := 6

static var _data: Dictionary = {}
static var _loaded := false


## ------------------------------------------------------------
##  RECORDING
## ------------------------------------------------------------
## Records the outcome of one daily puzzle.
## Returns true when this call was the one that counted (false when the
## puzzle was already recorded, or when `puzzle_id` is empty).
static func record_result(won: bool, attempts: int, puzzle_id: String,
		day_index: int = -1) -> bool:
	_ensure_loaded()
	if puzzle_id.is_empty() or str(_data.get("last_puzzle_id", "")) == puzzle_id:
		return false
	if day_index < 0:
		day_index = WordleDaily.day_index()

	var previous_day := int(_data.get("last_day_index", -1))
	_data["last_puzzle_id"] = puzzle_id
	_data["last_day_index"] = day_index
	_data["played"] = int(_data["played"]) + 1

	if won:
		_data["won"] = int(_data["won"]) + 1
		# Consecutive only when the previous puzzle was the day before.
		_data["current_streak"] = (int(_data["current_streak"]) + 1) \
			if previous_day == day_index - 1 else 1
		_data["best_streak"] = maxi(int(_data["best_streak"]), int(_data["current_streak"]))
		var bucket := clampi(attempts - 1, 0, MAX_ATTEMPTS_BUCKETS - 1)
		var histogram: Array = _data["distribution"]
		histogram[bucket] = int(histogram[bucket]) + 1
	else:
		_data["current_streak"] = 0

	_save()
	return true


## ------------------------------------------------------------
##  READS
## ------------------------------------------------------------
static func get_played() -> int:
	_ensure_loaded()
	return int(_data["played"])


static func get_wins() -> int:
	_ensure_loaded()
	return int(_data["won"])


static func get_current_streak() -> int:
	_ensure_loaded()
	return int(_data["current_streak"])


static func get_best_streak() -> int:
	_ensure_loaded()
	return int(_data["best_streak"])


## Wins per attempt count: index 0 = solved on the first try, ... index 5.
static func get_distribution() -> Array:
	_ensure_loaded()
	return (_data["distribution"] as Array).duplicate()


## Puzzle id of the last recorded game ("" when nothing was recorded yet).
static func get_last_puzzle_id() -> String:
	_ensure_loaded()
	return str(_data["last_puzzle_id"])


## Drops the in-memory copy so the next read re-parses the file.
## Used by the test runner after it puts the real file back.
static func reset_cache() -> void:
	_data = {}
	_loaded = false


## ------------------------------------------------------------
##  INTERNALS
## ------------------------------------------------------------
static func _default_data() -> Dictionary:
	return {
		"played": 0,
		"won": 0,
		"current_streak": 0,
		"best_streak": 0,
		"last_day_index": -1,
		"last_puzzle_id": "",
		"distribution": [0, 0, 0, 0, 0, 0],
	}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = _default_data()

	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("WordleStats: ignoring an unreadable %s" % SAVE_PATH)
		return

	var stored: Dictionary = json.data
	_data["played"] = maxi(0, int(stored.get("played", 0)))
	_data["won"] = maxi(0, int(stored.get("won", 0)))
	_data["current_streak"] = maxi(0, int(stored.get("current_streak", 0)))
	_data["best_streak"] = maxi(0, int(stored.get("best_streak", 0)))
	_data["last_day_index"] = int(stored.get("last_day_index", -1))
	_data["last_puzzle_id"] = str(stored.get("last_puzzle_id", ""))

	var histogram: Array = _data["distribution"]
	var stored_histogram = stored.get("distribution", [])
	if stored_histogram is Array:
		for i in mini(stored_histogram.size(), MAX_ATTEMPTS_BUCKETS):
			histogram[i] = maxi(0, int(stored_histogram[i]))


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("WordleStats: cannot write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_data))
	file.close()