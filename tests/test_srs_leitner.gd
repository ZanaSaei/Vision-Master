extends Node
## ============================================================
##  SPACED REPETITION / LEITNER TESTS
##
##  Covers the scheduler maths, the saved-words + review-words save
##  system, and the queue semantics the WordReview scene relies on.
##
##  These tests call Global.save_word()/remove_word(), which write to user://.
##  The test runner invokes every test_* method INDIVIDUALLY in addition to
##  running them from _ready, so protecting the files in _ready alone is not
##  enough — each test that touches disk has to wrap itself in _protect(),
##  which snapshots both save files and restores them afterwards.
## ============================================================

const SAVED_PATH   := "user://saved_words.json"
const REVIEW_PATH  := "user://review_words.json"

var _failures := 0
var _parked := {}


func _ready() -> void:
	_park_user_files()

	test_interval_ordering()
	test_hard_never_outlasts_good()
	test_interval_is_capped()
	test_again_stays_due_today()
	test_preview_matches_schedule()
	test_preview_does_not_mutate()
	test_corrupt_fields_are_normalised()
	test_sanitize_drops_junk_and_duplicates()
	test_save_word_is_idempotent()
	test_save_seeds_srs_fields()
	test_remove_is_a_noop_when_absent()
	test_remove_saved_word_keeps_review_card()
	test_remove_review_word_keeps_saved_word()
	test_resaving_restores_missing_review_card()
	test_review_word_reschedules_in_both_lists()
	test_due_words_returns_copies()
	test_due_words_sorts_most_overdue_first()
	test_due_words_caps_new_cards()
	test_corrupt_save_file_loads_empty()

	_restore_user_files()

	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)


############################################################
# SCHEDULER MATHS
############################################################

## The four ratings must never disagree about which is sooner: picking a
## harsher answer has to bring the card back at least as early.
func test_interval_ordering() -> void:
	for reps in [0, 1, 2, 5, 12]:
		var entry := _entry(0.0, 2.5, reps)
		var again: Dictionary = Global._compute_srs_result(entry, "again")
		var hard: Dictionary  = Global._compute_srs_result(entry, "hard")
		var good: Dictionary  = Global._compute_srs_result(entry, "good")
		var easy: Dictionary  = Global._compute_srs_result(entry, "easy")

		print("reps=%d  again=%d hard=%d good=%d easy=%d" % [
			reps, again["due"], hard["due"], good["due"], easy["due"]
		])
		_check(again["due"] <= hard["due"], "again must not be later than hard (reps=%d)" % reps)
		_check(hard["due"] <= good["due"], "hard must not be later than good (reps=%d)" % reps)
		_check(good["due"] <= easy["due"], "good must not be later than easy (reps=%d)" % reps)


## Regression: a brand new card rated "hard" used to compute 1.2 days, which
## ceil() turned into +2 days, pushing it FURTHER away than "good" (+1 day).
func test_hard_never_outlasts_good() -> void:
	var fresh := _entry(0.0, 2.5, 0)
	var hard := Global._compute_srs_result(fresh, "hard")
	var good := Global._compute_srs_result(fresh, "good")
	var easy := Global._compute_srs_result(fresh, "easy")
	print("new card: hard=+%d(%s) good=+%d(%s) easy=+%d(%s)" % [
		hard["due"], Global._format_interval(hard["interval"], "hard"),
		good["due"], Global._format_interval(good["interval"], "good"),
		easy["due"], Global._format_interval(easy["interval"], "easy"),
	])
	_check(hard["due"] <= good["due"], "hard on a new card must not outlast good")
	# The three choices must be visibly distinct on the very first card, or
	# the student sees the same "۱ روز" on two buttons and cannot choose.
	_check(hard["due"] < good["due"], "hard must be sooner than good on a new card")
	_check(good["due"] < easy["due"], "good must be sooner than easy on a new card")
	_check(Global._format_interval(hard["interval"], "hard") == "امروز",
		"a sub-day hard interval must read as today, not '۱ روز'")
	_check(Global._format_interval(good["interval"], "good") == "۱ روز",
		"good on a new card should read as one day")
	_check(Global._format_interval(easy["interval"], "easy") != "۱ روز",
		"easy on a new card must not also read as one day")


func test_interval_is_capped() -> void:
	var wild := _entry(200.0, 3.0, 9)
	var r := Global._compute_srs_result(wild, "easy")
	print("capped interval=", r["interval"])
	_check(r["interval"] <= Global.SRS_MAX_INTERVAL, "interval exceeded SRS_MAX_INTERVAL")


## "again" is re-queued inside the same session, so it must stay due today.
func test_again_stays_due_today() -> void:
	var e := _entry(5.0, 2.5, 3)
	var r := Global._compute_srs_result(e, "again")
	_check(r["due"] == Global._today_day_number(), "again should be due today")
	_check(r["reps"] == 0, "again should reset the repetition count")
	_check(r["interval"] == 0.0, "again should clear the interval")


## The label shown on the button is derived from the same interval that
## schedules the card, so the promise made to the student is kept.
func test_preview_matches_schedule() -> void:
	var e := _entry(1.2, 2.5, 3)
	var preview := Global.preview_intervals(e)
	var real := Global._compute_srs_result(e, "hard")
	var shown := Global._format_interval(real["interval"], "hard")
	print("hard: label=", shown, " interval=", real["interval"])
	_check(preview["hard"] == shown, "preview label must match the formatted interval")
	_check(shown == "۱ روز", "1.2 days should read as one day, got: " + shown)


## preview_intervals() is called on every "Show answer" tap. It used to call
## _ensure_srs_fields() on the caller's dictionary, leaking scheduler defaults
## into whatever entry the scene was holding.
func test_preview_does_not_mutate() -> void:
	var e := {"word": "Solo", "book": 1, "lesson": 1}
	Global.preview_intervals(e)
	_check(not e.has("srs_due"), "preview_intervals must not add SRS fields to the caller's entry")
	_check(not e.has("srs_ease"), "preview_intervals must not add SRS fields to the caller's entry")


## A hand-edited or older save can hold strings/nulls where numbers belong.
func test_corrupt_fields_are_normalised() -> void:
	var junk := {"srs_interval": "abc", "srs_ease": null, "srs_reps": "x", "srs_due": null}
	Global._ensure_srs_fields(junk)
	print("normalised -> ", junk)
	_check(junk["srs_interval"] == 0.0, "bad interval should fall back to 0")
	_check(junk["srs_due"] == -1, "bad due should fall back to -1 (new)")
	_check(junk["srs_reps"] == 0, "bad reps should fall back to 0")
	_check(junk["srs_ease"] >= Global.SRS_MIN_EASE, "bad ease should fall back into range")


func test_sanitize_drops_junk_and_duplicates() -> void:
	var raw: Array = [
		{"word": "Apple", "book": 1, "lesson": 1},
		{"word": "apple", "book": 1, "lesson": 1},   # duplicate, case-insensitive
		"not a dictionary",                          # junk
		{"book": 1, "lesson": 1},                    # no word
		{"word": "Book", "book": 1, "lesson": 1},
	]
	var clean: Array = Global._sanitize_word_list(raw)
	print("sanitized ", raw.size(), " -> ", clean.size())
	_check(clean.size() == 2, "expected 2 clean entries, got " + str(clean.size()))
	for e in clean:
		_check(e.has("srs_due"), "sanitized entries must carry SRS fields")


############################################################
# SAVE SYSTEM
############################################################

func test_save_word_is_idempotent() -> void:
	_protect(func():
		_reset()
		Global.save_word({"word": "Apple", "book": 1, "lesson": 1})
		Global.save_word({"word": "Apple", "book": 1, "lesson": 1})
		_check(Global.saved_words.size() == 1, "saving the same word twice must not duplicate it")
		_check(Global.review_words.size() == 1, "saving the same word twice must not duplicate the review card")
	)


func test_save_seeds_srs_fields() -> void:
	_protect(func():
		_reset()
		Global.save_word({"word": "Apple", "book": 1, "lesson": 1})
		_check(Global.review_words.size() == 1, "saving should add a review card")
		var card: Dictionary = Global.review_words[0]
		_check(card.get("srs_due") == -1, "a new card must start as due == -1 (new)")
		_check(card.get("book") == 1 and card.get("lesson") == 1,
			"identity fields must be stored")
		# Regression: a bare {word, book, lesson} payload used to be stored
		# verbatim, producing a review card with a completely blank back face.
		_check(not str(card.get("meaning_en", "")).is_empty(),
			"a saved card must carry meaning_en (blank back face bug)")
		_check(not str(card.get("meaning_fa", "")).is_empty(),
			"a saved card must carry meaning_fa")
	)


func test_remove_is_a_noop_when_absent() -> void:
	_protect(func():
		_reset()
		Global.save_word({"word": "Keep", "book": 1, "lesson": 1})
		var before := Global.saved_words.duplicate(true)
		Global.remove_word("Nope", 9, 9)
		_check(Global.saved_words.duplicate(true) == before, "removing an absent word must not change the list")
	)


## Flashcard removal clears only the saved list, not the Leitner queue.
func test_remove_saved_word_keeps_review_card() -> void:
	_protect(func():
		_reset()
		Global.save_word({"word": "Keep in review", "book": 1, "lesson": 1})
		Global.remove_word("Keep in review", 1, 1)
		_check(Global.saved_words.is_empty(), "word should be gone from saved_words")
		_check(Global.review_words.size() == 1,
			"removing a flashcard bookmark must preserve the review card")
	)


## Removing in Word Review clears only the Leitner queue, not the bookmark.
func test_remove_review_word_keeps_saved_word() -> void:
	_protect(func():
		_reset()
		Global.save_word({"word": "Keep saved", "book": 1, "lesson": 1})
		Global.remove_review_word("Keep saved", 1, 1)
		_check(Global.review_words.is_empty(), "word should be gone from review_words")
		_check(Global.saved_words.size() == 1,
			"removing a review card must preserve the flashcard bookmark")
	)


## Saving a bookmark again restores its missing Leitner card without duplicating it.
func test_resaving_restores_missing_review_card() -> void:
	_protect(func():
		_reset()
		Global.save_word({"word": "Restore", "book": 1, "lesson": 1})
		Global.remove_review_word("Restore", 1, 1)
		Global.save_word({"word": "Restore", "book": 1, "lesson": 1})
		_check(Global.saved_words.size() == 1, "resaving must not duplicate bookmark")
		_check(Global.review_words.size() == 1, "resaving must restore review card")
	)


## Regression: review_word() only searched saved_words, so a card living only
## in review_words was never rescheduled and stayed due forever.
func test_review_word_reschedules_in_both_lists() -> void:
	_protect(func():
		var today := Global._today_day_number()
		Global.review_words = [_entry(0.0, 2.5, 0)]
		Global.review_words[0]["word"] = "Solo"
		Global.review_words[0]["book"] = 2
		Global.review_words[0]["lesson"] = 3
		Global.saved_words = []

		Global.review_word("Solo", 2, 3, "good")
		var due: int = Global.review_words[0]["srs_due"]
		print("review-only card rescheduled to ", due, " (today=", today, ")")
		_check(due == today + 1, "a card present only in review_words must still be rescheduled")

		# And the mirror direction: present in saved_words only.
		Global.review_words = []
		Global.saved_words = [_entry(0.0, 2.5, 0)]
		Global.saved_words[0]["word"] = "Mirror"
		Global.saved_words[0]["book"] = 1
		Global.saved_words[0]["lesson"] = 1
		Global.review_word("Mirror", 1, 1, "easy")
		_check(Global.saved_words[0]["srs_due"] == today + 2, "saved-only card must be rescheduled")
	)


############################################################
# QUEUE SEMANTICS
############################################################

## get_due_words() returned live references into Global.review_words, so the
## scene's interval previews and re-queueing wrote straight into the store.
func test_due_words_returns_copies() -> void:
	_reset()
	Global.review_words = [_entry(0.0, 2.5, 0)]
	Global.review_words[0]["word"] = "Copy"
	var due := Global.get_due_words()
	_check(due.size() == 1, "card should be due")
	due[0]["srs_reps"] = 999
	_check(Global.review_words[0]["srs_reps"] == 0, "get_due_words leaked a live reference into Global")
	_reset()


func test_due_words_sorts_most_overdue_first() -> void:
	_reset()
	var today := Global._today_day_number()
	Global.review_words = [
		_due_card("Soon", today),
		_due_card("VeryLate", today - 30),
		_due_card("Middling", today - 5),
	]
	var due := Global.get_due_words()
	var order: Array = []
	for e in due:
		order.append(e["word"])
	print("order -> ", order)
	_check(order == ["VeryLate", "Middling", "Soon"], "due cards should be most-overdue first, got " + str(order))
	_reset()


## A big library must not dump every unseen word in one sitting.
func test_due_words_caps_new_cards() -> void:
	_reset()
	var cards: Array = []
	for i in 30:
		cards.append(_entry(0.0, 2.5, 0))
		cards[i]["word"] = "New%d" % i
		cards[i]["srs_due"] = -1
	Global.review_words = cards
	var due := Global.get_due_words()
	print("30 new cards -> queue of ", due.size())
	_check(due.size() == Global.SRS_NEW_CARDS_PER_SESSION, "new cards must be capped per session")
	_reset()


############################################################
# DISK LOADING
############################################################

## A truncated or hand-mangled save must degrade to an empty list, not crash
## at startup. json.data is null on a parse failure, so the Array type has to
## be verified before it reaches the sanitiser.
func test_corrupt_save_file_loads_empty() -> void:
	_protect(func():
		for bad in ["{not json at all", "null", "42", "{\"a\":1}", ""]:
			_write(SAVED_PATH, bad)
			var loaded: Array = Global._load_word_list_file(SAVED_PATH)
			_check(loaded.is_empty(), "corrupt save %s should load as empty" % bad)

		# A well-formed file with mixed junk still yields its good entries.
		_write(SAVED_PATH, JSON.stringify([
			{"word": "Good", "book": 1, "lesson": 1},
			"junk",
			{"word": "Good", "book": 1, "lesson": 1},
		]))
		var mixed: Array = Global._load_word_list_file(SAVED_PATH)
		print("mixed file -> ", mixed.size(), " entry(ies)")
		_check(mixed.size() == 1, "duplicate + junk should collapse to a single entry")

		# A missing file is not an error.
		_check(Global._load_word_list_file(SAVED_PATH).is_empty(), "missing file should load as empty")
	)


############################################################
# HELPERS
############################################################

func _entry(interval: float, ease: float, reps: int) -> Dictionary:
	return {
		"srs_interval": interval,
		"srs_ease": ease,
		"srs_reps": reps,
		"srs_due": 0,
	}


func _due_card(word: String, due: int) -> Dictionary:
	var e := _entry(0.0, 2.5, 2)
	e["word"] = word
	e["srs_due"] = due
	return e


func _reset() -> void:
	Global.saved_words = []
	Global.review_words = []


## Runs `body` with the player's saved_words.json / review_words.json safely
## snapshotted, then puts the originals back — even if an assert-style check
## inside the body bails out. Every test that calls a persisting Global method
## must run inside this, because the runner executes each test_* method on its
## own, where the _ready-level park/restore does not apply.
func _protect(body: Callable) -> void:
	var snapshot := {
		SAVED_PATH:  "" if not FileAccess.file_exists(SAVED_PATH)  else FileAccess.get_file_as_string(SAVED_PATH),
		REVIEW_PATH: "" if not FileAccess.file_exists(REVIEW_PATH) else FileAccess.get_file_as_string(REVIEW_PATH),
	}
	# Start from a known-empty slate so assertions only see what the test made.
	_remove_saves()
	_reset()
	body.call()
	_remove_saves()
	for path in snapshot.keys():
		var text: String = snapshot[path]
		if text.is_empty():
			continue
		_write(path, text)
	_reset()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	print("FAIL: ", message)


############################################################
# user:// HOUSEKEEPING
############################################################

func _park_user_files() -> void:
	_parked = {
		SAVED_PATH: "" if not FileAccess.file_exists(SAVED_PATH) else FileAccess.get_file_as_string(SAVED_PATH),
		REVIEW_PATH: "" if not FileAccess.file_exists(REVIEW_PATH) else FileAccess.get_file_as_string(REVIEW_PATH),
	}
	_remove_saves()


func _restore_user_files() -> void:
	_remove_saves()
	for path in _parked.keys():
		var text: String = _parked[path]
		if text.is_empty():
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
			file.close()
	_reset()


func _remove_saves() -> void:
	for path in [SAVED_PATH, REVIEW_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
