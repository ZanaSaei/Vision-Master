extends Node
## ============================================================
##  WORDLE LIVE TESTS — run with run_scene on TestWordle.tscn.
##
##  Covers the pure game modules: vocabulary pool, daily engine,
##  evaluator, game state machine, save round-trip and the stats record.
##  (The UI itself — board, keyboard, cards — is exercised by running
##  WordOfDay.tscn, which needs the real autoloads.)
##
##  The save round-trip and stats tests write to user://, so the runner
##  parks the player's real files first and puts them back afterwards:
##  running the tests must never eat a real puzzle or a real streak.
## ============================================================

const GAME_SAVE := "user://wordle_save.json"
const STATS_SAVE := "user://wordle_stats.json"

var _failures := 0
var _parked: Dictionary = {}


func _ready() -> void:
	_park_user_files()

	test_pool()
	test_daily()
	test_evaluator()
	test_game()
	test_keyboard_states()
	test_save_round_trip()
	test_finished_states_reload()
	test_stale_save()
	test_stats()

	_restore_user_files()

	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)


############################################################
# user:// HOUSEKEEPING
############################################################
func _park_user_files() -> void:
	for path in [GAME_SAVE, STATS_SAVE]:
		_parked[path] = "" if not FileAccess.file_exists(path) else _read(path)
		_remove(path)


func _restore_user_files() -> void:
	for path in _parked:
		_remove(path)
		var content: String = _parked[path]
		if content.is_empty():
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(content)
			file.close()
	WordleStats.reset_cache()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


############################################################
# VOCABULARY POOL
############################################################
func test_pool() -> void:
	var pool := WordleVocab.get_word_pool()
	_check(pool.size() > 100, "pool is substantial (%d words)" % pool.size())

	var all_ok := true
	var unique := {}
	for word in pool:
		if not WordleVocab._passes_filter(word):
			all_ok = false
			print("  BAD WORD: ", word)
		unique[word] = true
	_check(all_ok, "every pool word passes the filter (5+ lowercase letters only)")
	_check(unique.size() == pool.size(), "pool is deduplicated")

	_check(WordleVocab.is_valid_word("about"), "a dictionary word is a valid guess")
	_check(not WordleVocab.is_valid_word("zzzzz"), "a nonsense word is not")
	_check(not WordleVocab.is_valid_word("cat"), "a word shorter than the minimum is not")

	var answers := WordleVocab.get_answer_pool()
	_check(answers.size() > 100 and answers.size() < pool.size(),
		"the answer pool is a subset of the guess pool (%d of %d)" % [answers.size(), pool.size()])
	_check(bool(WordleVocab.get_word_info(answers[0])["exact"]),
		"every answer-pool word has an entry of its own (%s)" % answers[0])

	# The filter shares one compiled regex; the second call must be the cache.
	var first := WordleVocab._word_regex()
	_check(first != null and first == WordleVocab._word_regex(), "the word regex is compiled once")

	# Synonym-only words used to render an end card full of dashes.
	var synonym_only := ""
	for word in pool:
		if WordleVocab.get_entry_meta(word).is_empty():
			synonym_only = word
			break
	_check(not synonym_only.is_empty(), "pool contains synonym-only words (%s)" % synonym_only)
	if not synonym_only.is_empty():
		var info := WordleVocab.get_word_info(synonym_only)
		_check(not info.meta.is_empty() and not bool(info.exact),
			"a synonym-only word now resolves to the entry that listed it")


############################################################
# DAILY ENGINE
############################################################
func test_daily() -> void:
	var first: String = WordleDaily.get_daily_word()
	var second: String = WordleDaily.get_daily_word()
	_check(first == second and not first.is_empty(), "same day -> same word (%s)" % first)

	var sequence := WordleDaily._shuffled_sequence()
	var sequence_set := {}
	for word in sequence:
		sequence_set[word] = true
	_check(sequence_set.size() == sequence.size(), "the shuffled sequence has no repeats")

	var day := WordleDaily.day_index()
	_check(sequence[day % sequence.size()] == first, "daily word = sequence[day % size]")
	_check(sequence[(day + 1) % sequence.size()] != first, "the next day yields a different word")
	_check(WordleVocab.get_answer_pool().has(first),
		"the daily word is an entry word, not a derived form (%s)" % first)
	_check(WordleDaily.puzzle_id() == "wordle-%s" % WordleDaily.puzzle_id().replace("wordle-", ""),
		"puzzle_id format (%s)" % WordleDaily.puzzle_id())

	var left := WordleDaily.seconds_until_next_word()
	_check(left > 0 and left <= WordleDaily.SECONDS_PER_DAY,
		"countdown to the next word is inside the day (%d s)" % left)
	_check(not WordleDaily.format_until_next_word().is_empty(),
		"countdown formats in Persian (%s)" % WordleDaily.format_until_next_word())


############################################################
# EVALUATOR
############################################################
func test_evaluator() -> void:
	_eval("LEVER", "LEVEL", [2, 2, 2, 2, 0])
	_eval("LEVER", "LEVER", [2, 2, 2, 2, 2])
	_eval("LEVER", "EZZEE", [1, 0, 0, 2, 0])
	_eval("CRANE", "CRONY", [2, 2, 0, 2, 0])
	_eval("ABBAA", "AAABB", [2, 1, 1, 1, 1])
	_eval("SPEED", "DZZZZ", [1, 0, 0, 0, 0])
	# The answer's single L is consumed by the exact match at index 0, so the
	# trailing L of the guess is absent — the class docs call out this case.
	_eval("LEVEL", "LEVER", [2, 2, 2, 2, 0])

	# Guards: an empty evaluation is not a win, and a length mismatch must
	# never read past the end of the answer.
	_check(not WordleEvaluator.is_win([]), "an empty evaluation is NOT a win")
	_check(WordleEvaluator.is_win([2, 2, 2]), "an all-correct row is a win")
	_check(not WordleEvaluator.is_win([2, 2, 1]), "a row with a yellow letter is not a win")
	_check(WordleEvaluator.evaluate("ABOUT", "CAT") == [0, 0, 0],
		"a short guess is reported absent instead of crashing")
	_check(WordleEvaluator.evaluate("ABOUT", "ABOUTS").size() == 6,
		"a long guess returns one code per guessed letter")
	_check(WordleEvaluator.evaluate("", "ABOUT") == [0, 0, 0, 0, 0],
		"an empty answer cannot win by accident")


func _eval(answer: String, guess: String, expected: Array) -> void:
	var got: Array = WordleEvaluator.evaluate(answer, guess)
	if got != expected:
		print("  expected ", expected, " got ", got)
	_check(got == expected, "eval %s vs %s" % [answer, guess])


############################################################
# GAME LOOP
############################################################
func test_game() -> void:
	var game := WordleGame.new("ABOUT", "wordle-test")
	_check(game.is_valid_guess("ADULT"), "a dictionary guess is accepted")
	_check(not game.is_valid_guess("QWERT"), "a nonsense guess is rejected")
	_check(not game.is_valid_guess("CAT"), "a wrong-length guess is rejected")

	game.current_row = "QWERT"
	var rejected: Dictionary = game.submit_current_row()
	_check(not rejected.ok and game.attempts_used() == 0,
		"a rejected guess consumes no attempt")
	_check(rejected.reason == "not_a_word", "the rejection reason is reported")

	game.current_row = "CAT"
	var short: Dictionary = game.submit_current_row()
	_check(not short.ok and short.reason == "length", "a short row is rejected as a length problem")

	game.current_row = "ADULT"
	var accepted: Dictionary = game.submit_current_row()
	_check(accepted.ok and game.attempts_used() == 1, "a valid guess consumes one attempt")
	_check(game.remaining_attempts() == WordleGame.MAX_GUESSES - 1, "the attempt counter moves")

	game.current_row = "ABOUT"
	var winning: Dictionary = game.submit_current_row()
	_check(winning.won and game.get_state() == WordleGame.State.WON,
		"the answer ends the puzzle as WON")
	_check(game.is_finished(), "a won puzzle reports finished")
	_check(not game.add_letter("Z"), "a finished puzzle takes no more letters")


func test_keyboard_states() -> void:
	# Real pool words, so the game actually accepts the guess: the previous
	# version of this test typed words the dictionary rejects (LEVEL, REVEL),
	# so nothing was submitted and every colour check failed.
	var answer := _first_playable_word(0)
	var misplaced := ""
	var misplaced_codes: Array = []
	for candidate in WordleVocab.get_word_pool():
		if candidate.length() != answer.length() or candidate == answer:
			continue
		var codes := WordleEvaluator.evaluate(answer, candidate)
		if codes.has(WordleEvaluator.Score.PRESENT):
			misplaced = candidate
			misplaced_codes = codes
			break

	_check(not misplaced.is_empty(),
		"found a guess with a misplaced letter (%s vs %s)" % [misplaced, answer])
	if misplaced.is_empty():
		return

	var game := WordleGame.new(answer, "wordle-test-keyboard")
	game.current_row = misplaced
	var result: Dictionary = game.submit_current_row()
	_check(result.ok, "the sampled guess is accepted by the game")

	var states := game.get_keyboard_states()
	var present_letter := ""
	for i in misplaced.length():
		if int(misplaced_codes[i]) == WordleEvaluator.Score.PRESENT:
			present_letter = misplaced[i]
			break
	_check(int(states.get(present_letter, -1)) == WordleEvaluator.Score.PRESENT,
		"keyboard: a misplaced letter turns yellow (%s)" % present_letter)

	game.current_row = answer
	_check(game.submit_current_row().won, "the answer is accepted and solves the puzzle")
	states = game.get_keyboard_states()
	var all_green := true
	for letter in answer:
		if int(states.get(letter, -1)) != WordleEvaluator.Score.CORRECT:
			all_green = false
	_check(all_green, "keyboard: every letter of a solved word is green")

	# White-box: the aggregator keeps the BEST score per letter, so a later
	# row that scores a letter lower can never repaint a green key.
	# (B is CORRECT in row one and PRESENT in row two.)
	var aggregate := WordleGame.new("ABOUT", "wordle-test-aggregate")
	aggregate.guesses.append("ABOUT")
	aggregate.evaluations.append(WordleEvaluator.evaluate("ABOUT", "ABOUT"))
	aggregate.guesses.append("BUNCH")
	aggregate.evaluations.append(WordleEvaluator.evaluate("ABOUT", "BUNCH"))
	var aggregate_states := aggregate.get_keyboard_states()
	_check(int(aggregate_states.get("B", -1)) == WordleEvaluator.Score.CORRECT,
		"keyboard: a green key is never downgraded by a later row")
	_check(not aggregate_states.has("Z"), "keyboard: untried letters stay out of the states")


## The first pool word of `length` characters (any length when 0): a word the
## game is guaranteed to accept.
func _first_playable_word(length: int) -> String:
	for word in WordleVocab.get_word_pool():
		if length == 0 or word.length() == length:
			return word
	return ""


############################################################
# PERSISTENCE
############################################################
func test_save_round_trip() -> void:
	var game := WordleGame.new("ABOUT", "wordle-test-save")
	game.current_row = "ADULT"
	game.submit_current_row()
	_check(FileAccess.file_exists(WordleGame.SAVE_PATH), "submitting writes the save")

	var payload := WordleGame.read_save()
	_check(not payload.has("answer"), "the save stores inputs only (no answer, no colours)")

	var restored := WordleGame.load_for_puzzle("ABOUT", "wordle-test-save")
	_check(restored != null, "the save is restored for the same puzzle id")
	if restored != null:
		_check(restored.guesses.size() == 1 and restored.guesses[0] == "ADULT",
			"the typed guesses survive the round trip")
		_check(restored.evaluations.size() == 1, "colours are recomputed for the restored row")
		var ints_only := true
		for code in restored.evaluations[0]:
			if typeof(code) != TYPE_INT:
				ints_only = false
		_check(ints_only, "restored colours are ints, not JSON floats")
		_check(restored.get_state() == WordleGame.State.PLAYING,
			"an unfinished day restores as PLAYING")
		_check(restored.get_current_row().is_empty(), "a half-typed row is not restored")

	_check(WordleGame.load_for_puzzle("ABOUT", "some-other-day") == null,
		"a save for another puzzle id is ignored")


func test_finished_states_reload() -> void:
	var sample := _sample_words(7)
	_check(sample.size() == 7, "sampled %d playable words for the flow tests" % sample.size())
	if sample.size() < 7:
		return

	var won := WordleGame.new(sample[0], "wordle-test-won")
	won.current_row = sample[0]
	won.submit_current_row()
	_check(won.get_state() == WordleGame.State.WON, "solving on the first try wins")
	var reloaded_win := WordleGame.load_for_puzzle(sample[0], "wordle-test-won")
	_check(reloaded_win != null and reloaded_win.get_state() == WordleGame.State.WON,
		"a won day reloads as WON")

	var lost := WordleGame.new(sample[0], "wordle-test-lost")
	for i in range(1, 7):
		lost.current_row = sample[i]
		lost.submit_current_row()
	_check(lost.get_state() == WordleGame.State.LOST, "six misses end the puzzle as LOST")
	var reloaded_lost := WordleGame.load_for_puzzle(sample[0], "wordle-test-lost")
	if reloaded_lost == null:
		_check(false, "a lost day reloads from disk")
	else:
		_check(reloaded_lost.get_state() == WordleGame.State.LOST, "a lost day reloads as LOST")
		_check(reloaded_lost.evaluations.size() == WordleGame.MAX_GUESSES,
			"every restored row carries its colours back")


func test_stale_save() -> void:
	var yesterday := WordleGame.new("ABOUT", "wordle-1999-01-01")
	yesterday.current_row = "ADULT"
	yesterday.submit_current_row()
	_check(FileAccess.file_exists(WordleGame.SAVE_PATH), "a save from an earlier day is on disk")

	var today := WordleGame.load_or_create_today()
	_check(today != null, "today's game is created even with a stale file present")
	_check(not FileAccess.file_exists(WordleGame.SAVE_PATH),
		"the stale save is deleted instead of lingering in user://")
	_check(today != null and today.attempts_used() == 0, "today starts with an empty board")


############################################################
# RECORD / STREAKS
############################################################
func test_stats() -> void:
	WordleStats.reset_cache()
	_check(WordleStats.get_played() == 0, "an empty record starts at zero")

	_check(WordleStats.record_result(true, 4, "wordle-2026-01-10", 1000),
		"the first result is recorded")
	_check(not WordleStats.record_result(true, 4, "wordle-2026-01-10", 1000),
		"recording the same puzzle twice is ignored")
	_check(WordleStats.get_played() == 1 and WordleStats.get_wins() == 1,
		"played and won move exactly once")

	WordleStats.record_result(true, 2, "wordle-2026-01-11", 1001)
	_check(WordleStats.get_current_streak() == 2, "a win the next day extends the streak")

	WordleStats.record_result(false, 6, "wordle-2026-01-12", 1002)
	_check(WordleStats.get_current_streak() == 0, "a loss breaks the streak")
	_check(WordleStats.get_best_streak() == 2, "the best streak is remembered")

	WordleStats.record_result(true, 3, "wordle-2026-01-20", 1010)
	_check(WordleStats.get_current_streak() == 1, "a gap of days restarts the streak at one")

	var histogram := WordleStats.get_distribution()
	_check(int(histogram[1]) == 1 and int(histogram[2]) == 1 and int(histogram[3]) == 1,
		"the attempt histogram counts the three wins (%s)" % str(histogram))

	WordleStats.reset_cache()
	_check(WordleStats.get_played() == 4, "the record is read back from disk")
	_check(WordleStats.get_last_puzzle_id() == "wordle-2026-01-20", "the last puzzle id is kept")


############################################################
# HELPERS
############################################################
## The first `count` five-letter words of the pool — sample[0] is the answer
## for the flow tests, the rest are seven legal guesses.
func _sample_words(count: int) -> Array[String]:
	var sample: Array[String] = []
	for word in WordleVocab.get_word_pool():
		if word.length() == 5:
			sample.append(word)
		if sample.size() >= count:
			break
	return sample


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS  " if condition else "FAIL  ") + label)
