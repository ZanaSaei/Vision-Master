class_name WordleGame
extends RefCounted
## ============================================================
##  WORDLE GAME — game state machine + local persistence.
##
##  Pure logic: owns the answer, the guesses, the in-progress row and
##  the overall state (PLAYING / WON / LOST). Validation is delegated to
##  WordleVocab; evaluation to WordleEvaluator. Persistence goes to
##  user://wordle_save.json (same user:// JSON pattern as the rest of
##  the app) so progress survives closing the app mid-puzzle.
##
##  SAVE POLICY — only inputs are stored:
##  the file holds the puzzle id and the words the player typed. The answer
##  comes from the daily engine and every colour is a pure function of
##  (answer, guess), so both are recomputed on load. A stale or half-written
##  file therefore degrades into "less progress" — never into a wrong board,
##  and never into a save that only an older build can read.
## ============================================================

enum State { PLAYING, WON, LOST }

const MAX_GUESSES := 6
const SAVE_PATH := "user://wordle_save.json"

var puzzle_id: String = ""
var answer: String = ""
var guesses: Array[String] = []
## Derived: one Array[int] of WordleEvaluator scores per guess. Never loaded
## from disk — recomputed from (answer, guess) by _rebuild_evaluations().
var evaluations: Array = []
var current_row: String = ""
var state: State = State.PLAYING


func _init(p_answer: String, p_puzzle_id: String) -> void:
	answer = p_answer.to_upper()
	puzzle_id = p_puzzle_id
	# Validate: the answer must be a playable word. This catches
	# configuration errors early (e.g. empty pool, wrong word length).
	if answer.is_empty() or not is_valid_guess(answer):
		push_warning("WordleGame: answer '%s' is not a valid playable word" % answer)


func get_state() -> State:
	return state


func is_finished() -> bool:
	return state != State.PLAYING


func attempts_used() -> int:
	return guesses.size()


func remaining_attempts() -> int:
	return MAX_GUESSES - guesses.size()


## The word currently being typed on the board.
func get_current_row() -> String:
	return current_row


## True when `word` is the right length AND in the game dictionary.
## The answer itself is always valid even if it only entered the pool
## via a synonym/antonym (it is by construction in the pool anyway).
func is_valid_guess(word: String) -> bool:
	var u := word.to_upper()
	if u.length() != answer.length():
		return false
	return WordleVocab.is_valid_word(u)


## Appends a letter to the current row (if room and still playing).
func add_letter(letter: String) -> bool:
	if is_finished() or current_row.length() >= answer.length():
		return false
	current_row += letter.to_upper()
	return true


## Removes the last letter of the current row.
func remove_letter() -> bool:
	if is_finished() or current_row.is_empty():
		return false
	current_row = current_row.substr(0, current_row.length() - 1)
	return true


## Submits the current row.
## Returns a result Dictionary:
##   { ok: bool, reason: "length" | "not_a_word" }  on rejection
##   { ok: true, evaluation: Array[int], won: bool }
## Rejected guesses do NOT consume an attempt.
func submit_current_row() -> Dictionary:
	if is_finished() or current_row.length() != answer.length():
		return { "ok": false, "reason": "length" }
	if not is_valid_guess(current_row):
		return { "ok": false, "reason": "not_a_word" }

	var guess := current_row
	var evaluation := WordleEvaluator.evaluate(answer, guess)
	guesses.append(guess)
	evaluations.append(evaluation)
	current_row = ""

	var won := WordleEvaluator.is_win(evaluation)
	if won:
		state = State.WON
	elif guesses.size() >= MAX_GUESSES:
		state = State.LOST

	save()
	return { "ok": true, "evaluation": evaluation, "won": won }


## Best score earned for every letter the player has already tried, used to
## colour the on-screen keyboard. A key is never downgraded:
## CORRECT > PRESENT > ABSENT. Letters never typed are absent from the
## dictionary, so the caller can fall back to a neutral style for them.
func get_keyboard_states() -> Dictionary:
	var best: Dictionary = {}
	for row_index in guesses.size():
		if row_index >= evaluations.size():
			break
		var evaluation: Array = evaluations[row_index]
		var word: String = guesses[row_index]
		for i in mini(word.length(), evaluation.size()):
			var letter := word[i]
			var score: int = int(evaluation[i])
			if score > int(best.get(letter, -1)):
				best[letter] = score
	return best


## ------------------------------------------------------------
##  PERSISTENCE
## ------------------------------------------------------------
func save() -> void:
	var payload := {
		"puzzle_id": puzzle_id,
		"guesses": guesses,
		"state": int(state),  # written for readability, never trusted
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("WordleGame: cannot write %s (%s)"
			% [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(payload))
	file.close()


## Parsed save file, or {} when it is missing or unreadable.
static func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("WordleGame: ignoring an unreadable %s" % SAVE_PATH)
		return {}
	return json.data


## Restores the progress of the puzzle `p_puzzle_id` for `p_answer`.
## Returns null when there is nothing to restore: no file, an unreadable
## file, or — the usual case — a file written for another day's puzzle,
## which is ignored so today always starts clean.
static func load_for_puzzle(p_answer: String, p_puzzle_id: String) -> WordleGame:
	var data := read_save()
	if data.is_empty() or str(data.get("puzzle_id", "")) != p_puzzle_id:
		return null

	var game := WordleGame.new(p_answer, p_puzzle_id)
	var stored_guesses = data.get("guesses", [])
	if stored_guesses is Array:
		for value in stored_guesses:
			if game.guesses.size() >= MAX_GUESSES:
				break  # never restore more rows than the board has
			if value is String and not str(value).is_empty():
				game.guesses.append(str(value).to_upper())
	game._rebuild_evaluations()
	game._recompute_state()
	return game


## Removes a save that belongs to another day, so user:// never keeps a
## puzzle nobody can finish. Returns true when a file was deleted.
static func discard_stale_save(p_puzzle_id: String) -> bool:
	var data := read_save()
	if data.is_empty() or str(data.get("puzzle_id", "")) == p_puzzle_id:
		return false
	var error := DirAccess.remove_absolute(SAVE_PATH)
	if error != OK:
		push_warning("WordleGame: cannot delete the stale save (%s)" % error_string(error))
		return false
	return true


## Convenience: returns today's game — restored from disk when a save
## for today's puzzle exists, otherwise a fresh one (not yet saved).
static func load_or_create_today() -> WordleGame:
	var daily_answer := WordleDaily.get_daily_word()
	if daily_answer.is_empty():
		push_error("WordleGame: no daily word — the vocabulary pool is empty")
		return null
	var id := WordleDaily.puzzle_id()
	var restored := load_for_puzzle(daily_answer, id)
	if restored != null:
		return restored
	discard_stale_save(id)  # yesterday's board has no future
	return WordleGame.new(daily_answer, id)


## Recomputes every row's colours from the answer. Stored colours are never
## trusted: they are derived data, and JSON numbers come back as floats.
func _rebuild_evaluations() -> void:
	evaluations.clear()
	for guess in guesses:
		evaluations.append(WordleEvaluator.evaluate(answer, guess))


## Derives WON / LOST / PLAYING from the guesses that are on the board, so a
## restored game can never disagree with what the player sees.
func _recompute_state() -> void:
	state = State.PLAYING
	for evaluation in evaluations:
		if WordleEvaluator.is_win(evaluation):
			state = State.WON
			return
	if guesses.size() >= MAX_GUESSES:
		state = State.LOST
