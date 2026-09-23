class_name ScrambledGameManager
extends RefCounted
## ============================================================
##  GAME MANAGER — the session state machine of «بازی املا».
##
##  One session is one run of either mode:
##    LEARNING    — a whole lesson, words dealt short-to-long, no score and
##                  no pressure, the meaning available after 30s.
##    COMPETITION — the five words of the day, the meaning after 60s, one
##                  score per word from the time table and one daily total.
##
##  The manager is static on purpose: the gameplay screen drives it, the
##  results screen reads it, and moving between screens never loses the
##  session in progress.
## ============================================================

enum Mode { LEARNING, COMPETITION }
enum State { IDLE, PLAYING, SOLVED, FINISHED }

## The meaning of the word becomes available after this long — generous in
## learning mode, where spelling matters more than speed, and twice as long
## in the competition, where the meaning costs points.
const LEARNING_HINT_DELAY := 30.0
const COMPETITION_HINT_DELAY := 60.0

## Beat between solving a word and the next one being dealt.
const NEXT_WORD_DELAY := 1.8

static var mode: Mode = Mode.LEARNING
static var state: State = State.IDLE
static var book := 1
static var lesson := 1
static var controller: ScrambledWordController = null
## True when the run that just finished took the day's best score.
static var last_run_new_best := false

static var _words: Array = []
static var _index := 0
static var _results: Array = []
static var _word_started_ms := 0
static var _word_hint_used := false
static var _session_started_ms := 0
static var _hints_used := 0
## "book_lesson" -> how often it has been played: replays get a fresh
## scramble, while the first run of a lesson is always dealt the same way.
static var _play_counts: Dictionary = {}


## ------------------------------------------------------------- starting --
## Deals a lesson in learning mode. Returns false when the lesson has no
## playable words (the screens then show their empty-bank card).
static func start_learning(p_book: int, p_lesson: int) -> bool:
	return _start(Mode.LEARNING, ScrambledData.words_ordered(p_book, p_lesson), p_book, p_lesson)


## Deals today's five words in competition mode.
static func start_competition() -> bool:
	var words := ScrambledDailyPicker.pick()
	var first: Dictionary = {}
	if not words.is_empty() and words[0] is Dictionary:
		first = words[0]
	return _start(Mode.COMPETITION, words, int(first.get("book", 1)), int(first.get("lesson", 1)))


static func _start(p_mode: Mode, words: Array, p_book: int, p_lesson: int) -> bool:
	if words.is_empty():
		state = State.IDLE
		return false
	mode = p_mode
	book = p_book
	lesson = p_lesson
	_words = words
	_index = 0
	_results = []
	_hints_used = 0
	last_run_new_best = false
	_session_started_ms = Time.get_ticks_msec()
	state = State.PLAYING
	_deal_current_word()
	return true


static func _deal_current_word() -> void:
	var data := current_word_data()
	controller = ScrambledWordController.new()
	controller.setup(data, _scramble_seed(data, _index))
	_word_hint_used = false
	_word_started_ms = Time.get_ticks_msec()


## The scramble seed of a word. Competition seeds come from the day alone, so
## everybody spells the same arrangement; learning seeds add how often the
## lesson has been played, so a replay is a fresh puzzle.
static func _scramble_seed(word_data: Dictionary, position: int) -> int:
	var base := str(word_data.get("word", "")).hash()
	if mode == Mode.COMPETITION:
		return base ^ (ScrambledDailyPicker.day_index() * 7919 + position * 104729)
	var plays := int(_play_counts.get(_lesson_key(), 0))
	return base ^ (plays * 15485863 + position * 7919)


static func _lesson_key() -> String:
	return ScrambledScoreManager.practice_key(book, lesson)


## ------------------------------------------------------------- the word --
static func current_word_data() -> Dictionary:
	if _index < 0 or _index >= _words.size():
		return {}
	var entry = _words[_index]
	return entry if entry is Dictionary else {}


static func word_count() -> int:
	return _words.size()


## 1-based position of the word being spelled, for the "کلمه ۲ از ۵" chip.
static func word_position() -> int:
	return _index + 1


static func is_last_word() -> bool:
	return _index >= _words.size() - 1


static func is_competition() -> bool:
	return mode == Mode.COMPETITION


static func mode_label() -> String:
	return "مسابقه روزانه" if mode == Mode.COMPETITION else "یادگیری"


static func hint_delay() -> float:
	return COMPETITION_HINT_DELAY if mode == Mode.COMPETITION else LEARNING_HINT_DELAY


## Seconds spent on the word being spelled right now.
static func elapsed_seconds() -> float:
	if controller == null:
		return 0.0
	if state == State.PLAYING:
		return float(Time.get_ticks_msec() - _word_started_ms) / 1000.0
	return _last_word_seconds()


static func _last_word_seconds() -> float:
	if _results.is_empty():
		return 0.0
	return float((_results[_results.size() - 1] as Dictionary).get("seconds", 0.0))


static func mark_hint_used() -> void:
	_word_hint_used = true


static func current_word_hint_used() -> bool:
	return _word_hint_used


## What the word being spelled is still worth, so the gameplay screen can show
## the player what a hint is about to cost.
static func current_word_potential_points() -> int:
	if mode != Mode.COMPETITION or controller == null:
		return 0
	return ScrambledScoreManager.points_for(elapsed_seconds(), _word_hint_used)
## Records the solved word and returns its result entry.
static func solve_current_word() -> Dictionary:
	if controller == null or state != State.PLAYING:
		return {}
	var seconds := elapsed_seconds()
	var points := 0
	if mode == Mode.COMPETITION:
		points = ScrambledScoreManager.points_for(seconds, _word_hint_used)
	var entry := {
		"word": controller.word,
		"meaning": controller.meaning,
		"meaning_fa": controller.meaning_fa,
		"seconds": seconds,
		"hint_used": _word_hint_used,
		"points": points,
		"book": book,
		"lesson": lesson,
	}
	_results.append(entry)
	if _word_hint_used:
		_hints_used += 1
	state = State.SOLVED
	# Learning practice is recorded word by word, so leaving a long lesson
	# halfway never throws away what has already been spelled correctly.
	if mode == Mode.LEARNING:
		ScrambledScoreManager.record_practice_word(book, lesson, _word_hint_used, seconds)
	return entry


## Moves on to the next word. Returns false when the session is over.
static func advance() -> bool:
	if state == State.FINISHED:
		return false
	if is_last_word():
		finish()
		return false
	_index += 1
	_deal_current_word()
	state = State.PLAYING
	return true


## Reveal a single letter in the scrambled board.
## Returns the index of the letter that was corrected.
static func reveal_letter(current_arrangement: Array) -> int:
	if controller == null:
		return -1

	# Identify positions that are currently wrong
	var misplaced_indices := []
	for i in controller.target.size():
		if i >= current_arrangement.size() or \
		   str(current_arrangement[i]).to_upper() != controller.target[i]:
			misplaced_indices.append(i)

	if misplaced_indices.is_empty():
		return -1

	# Pick a random misplaced index
	var idx: int = misplaced_indices.pick_random()
	_word_hint_used = true
	_hints_used += 1

	return idx


## Closes a finished session and writes its records.
static func finish() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	if mode == Mode.COMPETITION:
		last_run_new_best = ScrambledScoreManager.save_daily_attempt(
			total_score(), _results.size(), _hints_used, session_seconds())
	_play_counts[_lesson_key()] = int(_play_counts.get(_lesson_key(), 0)) + 1


## Leaves a session early (the player pressed back). A competition keeps the
## points already earned, so quitting is never punished, and a lesson keeps
## the per-word practice it has already recorded.
static func abandon() -> void:
	if state == State.FINISHED:
		return
	if mode == Mode.COMPETITION and not _results.is_empty():
		state = State.FINISHED
		last_run_new_best = ScrambledScoreManager.save_daily_attempt(
			total_score(), _results.size(), _hints_used, session_seconds())
		_play_counts[_lesson_key()] = int(_play_counts.get(_lesson_key(), 0)) + 1
		return
	state = State.IDLE


## -------------------------------------------------------------- summary --
static func results() -> Array:
	return _results


static func correct_count() -> int:
	return _results.size()


## Words the player actually faced, so a run quit halfway reports honestly.
static func words_attempted() -> int:
	return maxi(_results.size(), word_position())


static func hints_used() -> int:
	return _hints_used


static func total_score() -> int:
	var total := 0
	for entry in _results:
		total += int((entry as Dictionary).get("points", 0))
	return total


static func session_seconds() -> float:
	return float(Time.get_ticks_msec() - _session_started_ms) / 1000.0


static func total_word_seconds() -> float:
	var total := 0.0
	for entry in _results:
		total += float((entry as Dictionary).get("seconds", 0.0))
	return total


static func average_seconds() -> float:
	if _results.is_empty():
		return 0.0
	return total_word_seconds() / float(_results.size())


## How the session's words were spelled, for the results card:
## fast (≤10s) · quick (≤30s) · steady (≤50s) · slow · hinted.
static func score_band_counts() -> Dictionary:
	var counts := {"fast": 0, "quick": 0, "steady": 0, "slow": 0, "hinted": 0}
	for entry in _results:
		var data: Dictionary = entry
		var seconds := float(data.get("seconds", 0.0))
		if bool(data.get("hint_used", false)):
			counts["hinted"] = int(counts["hinted"]) + 1
		elif seconds <= 10.0:
			counts["fast"] = int(counts["fast"]) + 1
		elif seconds <= 30.0:
			counts["quick"] = int(counts["quick"]) + 1
		elif seconds <= 50.0:
			counts["steady"] = int(counts["steady"]) + 1
		else:
			counts["slow"] = int(counts["slow"]) + 1
	return counts


## --------------------------------------------------------------- resets --
static func reset() -> void:
	_words = []
	_index = 0
	_results = []
	_hints_used = 0
	controller = null
	state = State.IDLE
	last_run_new_best = false


## Only for tests: forgets how often lessons have been played.
static func reset_play_counts() -> void:
	_play_counts = {}
