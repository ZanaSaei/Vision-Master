extends Node
# Verifies the spaced-repetition (SRS) backend in Global.gd:
#  - interval/ease math for again / hard / good / easy
#  - get_due_words() ordering: due reviews before new cards, new-card cap
#  - save/review/remove keeps saved_words and review_words in sync
#
# NOTE: these tests access Global DIRECTLY as an autoload singleton name
# (get_node_or_null("/root/Global") returns null in this runner's context).
# They MUTATE Global's in-memory arrays and the real user://saved_words.json /
# review_words.json, so the originals are backed up (files byte-for-byte +
# in-memory deep copies) and restored in _exit_tree() so the player's real
# data is never harmed.

const SAVED_PATH := "user://saved_words.json"
const REVIEW_PATH := "user://review_words.json"

var _saved_backup := ""
var _review_backup := ""
var _orig_saved: Array = []
var _orig_review: Array = []
var _captured := false


func _init() -> void:
	if FileAccess.file_exists(SAVED_PATH):
		var f := FileAccess.open(SAVED_PATH, FileAccess.READ)
		_saved_backup = f.get_as_text()
		f.close()
	if FileAccess.file_exists(REVIEW_PATH):
		var f := FileAccess.open(REVIEW_PATH, FileAccess.READ)
		_review_backup = f.get_as_text()
		f.close()


func _ready() -> void:
	if Global != null:
		_orig_saved = Global.saved_words.duplicate(true)
		_orig_review = Global.review_words.duplicate(true)
		_captured = true


func _exit_tree() -> void:
	# Restore in-memory state so other tests never see our mutations.
	if _captured and Global != null:
		Global.saved_words = _orig_saved.duplicate(true)
		Global.review_words = _orig_review.duplicate(true)
	# Restore the files byte-for-byte so the player's real data is untouched.
	_restore_file(SAVED_PATH, _saved_backup)
	_restore_file(REVIEW_PATH, _review_backup)


func _restore_file(path: String, text: String) -> void:
	if text == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _word(name: String, due: float = -1.0) -> Dictionary:
	var d := {"word": name, "book": 1, "lesson": 1}
	if due >= 0.0:
		d["srs_due"] = int(due)
	return d


func _in_array(arr: Array, word: String) -> bool:
	for e in arr:
		if e.get("word") == word:
			return true
	return false


# ---------- SRS interval math ----------

func test_interval_math_new_card() -> void:
	var entry := _word("x")
	entry["srs_interval"] = 0.0
	entry["srs_ease"] = 2.5
	entry["srs_reps"] = 0

	var today: int = Global.call("_today_day_number")

	var again: Dictionary = Global.call("_compute_srs_result", entry, "again")
	var hard: Dictionary = Global.call("_compute_srs_result", entry, "hard")
	var good: Dictionary = Global.call("_compute_srs_result", entry, "good")
	var easy: Dictionary = Global.call("_compute_srs_result", entry, "easy")

	var ok := true
	ok = ok and again["reps"] == 0 and again["ease"] == 2.3 and again["interval"] == 0.0 and again["due"] == today
	ok = ok and hard["reps"] == 1 and is_equal_approx(hard["ease"], 2.35) and is_equal_approx(hard["interval"], 1.2) and hard["due"] == today + 2
	ok = ok and good["reps"] == 1 and good["interval"] == 1.0 and good["due"] == today + 1
	ok = ok and easy["reps"] == 1 and easy["interval"] == 2.0 and is_equal_approx(easy["ease"], 2.65) and easy["due"] == today + 2

	print("interval math new: ", "PASS" if ok else "FAIL")
	assert(ok, "SRS interval math for a new card is wrong")


func test_interval_math_mature_card() -> void:
	var entry := _word("x")
	entry["srs_interval"] = 10.0
	entry["srs_ease"] = 2.5
	entry["srs_reps"] = 5

	var today: int = Global.call("_today_day_number")

	var again: Dictionary = Global.call("_compute_srs_result", entry, "again")
	var hard: Dictionary = Global.call("_compute_srs_result", entry, "hard")
	var good: Dictionary = Global.call("_compute_srs_result", entry, "good")
	var easy: Dictionary = Global.call("_compute_srs_result", entry, "easy")

	var ok := true
	ok = ok and again["reps"] == 0 and again["interval"] == 0.0 and again["due"] == today
	ok = ok and hard["reps"] == 6 and is_equal_approx(hard["ease"], 2.35) and is_equal_approx(hard["interval"], 12.0) and hard["due"] == today + 12
	ok = ok and good["reps"] == 6 and is_equal_approx(good["interval"], 25.0) and good["due"] == today + 25
	ok = ok and easy["reps"] == 6 and is_equal_approx(easy["interval"], 32.5) and easy["due"] == today + 33 and is_equal_approx(easy["ease"], 2.65)

	print("interval math mature: ", "PASS" if ok else "FAIL")
	assert(ok, "SRS interval math for a mature card is wrong")


# ---------- Due-queue ordering ----------

func test_due_reviews_before_new() -> void:
	var today: int = Global.call("_today_day_number")
	Global.saved_words = []
	Global.review_words = [
		_word("future", today + 30),              # not due yet — excluded
		_word("new_a"),                            # never studied — new
		_word("due_b", float(today - 1)),          # overdue review
		_word("new_c"),                            # never studied — new
	]

	var due: Array = Global.get_due_words()
	var ok := due.size() == 3                    # due_b + 2 new, future excluded
	ok = ok and due.size() > 0 and due[0].get("word") == "due_b"  # reviews first

	print("due ordering: ", "PASS" if ok else "FAIL", " -> ", due)
	assert(ok, "get_due_words must return due reviews before new cards")


func test_new_card_session_cap() -> void:
	var cap: int = Global.SRS_NEW_CARDS_PER_SESSION
	Global.saved_words = []
	Global.review_words = []
	for i in range(50):
		Global.review_words.append(_word("w%d" % i))

	var due: Array = Global.get_due_words()
	var ok: bool = due.size() == cap
	print("new cap: ", "PASS" if ok else "FAIL", " -> size=", due.size(), " cap=", cap)
	assert(ok, "new cards must be capped at SRS_NEW_CARDS_PER_SESSION")


# ---------- saved_words / review_words consistency ----------

func test_save_review_remove_consistency() -> void:
	# Start from a clean slate (restored later by _exit_tree).
	Global.saved_words = []
	Global.review_words = []

	# 1) save_word puts the word in BOTH arrays.
	Global.save_word({"word": "alpha", "book": 1, "lesson": 1, "meaning_en": "A"})
	var ok := _in_array(Global.saved_words, "alpha") and _in_array(Global.review_words, "alpha")
	print("consistency save: ", "PASS" if ok else "FAIL")
	assert(ok, "save_word must add to both saved_words and review_words")

	# 2) review_word syncs SRS into the review queue entry.
	Global.review_word("alpha", 1, 1, "good")
	var entry: Dictionary = {}
	for e in Global.review_words:
		if e.get("word") == "alpha":
			entry = e
			break
	ok = entry.get("srs_reps", -1) == 1 and entry.get("srs_due", -1) != -1
	print("consistency review-sync: ", "PASS" if ok else "FAIL", " -> reps=", entry.get("srs_reps"), " due=", entry.get("srs_due"))
	assert(ok, "review_word must propagate SRS state into review_words")

	# After "good" the word is scheduled in the future, so it is NOT due now.
	var due: Array = Global.get_due_words()
	ok = not _in_array(due, "alpha")
	print("consistency due-excluded: ", "PASS" if ok else "FAIL")
	assert(ok, "a freshly reviewed 'good' word must not be due today")

	# 3) remove_word removes from BOTH arrays.
	Global.remove_word("alpha", 1, 1)
	ok = not _in_array(Global.saved_words, "alpha") and not _in_array(Global.review_words, "alpha")
	print("consistency remove-word: ", "PASS" if ok else "FAIL")
	assert(ok, "remove_word must remove from both arrays")

	# 4) remove_review_word also removes from BOTH arrays.
	Global.save_word({"word": "beta", "book": 1, "lesson": 1, "meaning_en": "B"})
	Global.remove_review_word("beta", 1, 1)
	ok = not _in_array(Global.saved_words, "beta") and not _in_array(Global.review_words, "beta")
	print("consistency remove-review: ", "PASS" if ok else "FAIL")
	assert(ok, "remove_review_word must remove from both arrays")


func test_invalid_rating_ignored() -> void:
	var entry := _word("x")
	entry["srs_interval"] = 5.0
	entry["srs_ease"] = 2.5
	entry["srs_reps"] = 3

	var before: Dictionary = entry.duplicate(true)
	Global.call("_compute_srs_result", entry, "bogus")
	var unchanged: bool = true
	for k in before:
		if entry[k] != before[k]:
			unchanged = false
	print("invalid rating: ", "PASS" if unchanged else "FAIL")
	assert(unchanged, "an unknown rating must not change SRS state")
