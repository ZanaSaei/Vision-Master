extends Node
## ============================================================
##  SCRAMBLED WORDS TESTS — run with run_scene on TestScrambledWords.tscn.
##
##  Covers the pure game modules: the word bank, the deterministic daily
##  picker, the scramble/solve rules, the score table and both records
##  (daily competition + practice), plus the session state machine and the
##  drag-and-drop board. The UI screens themselves are exercised by running
##  ScrambledWords.tscn, which needs the real autoloads.
##
##  The daily and practice records write to user://, so the runner parks the
##  player's real file first and puts it back afterwards: running the tests
##  must never eat a recorded score.
## ============================================================

const SAVE_PATH := "user://scrambled_words.json"

var _failures := 0
var _parked := ""


func _ready() -> void:
	_park_user_file()

	test_bank()
	test_daily_picker()
	test_scramble()
	test_score_table()
	test_daily_record()
	test_practice_record()
	test_learning_session()
	test_competition_session()

	await test_board_drag()

	_restore_user_file()

	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)


############################################################
# user:// HOUSEKEEPING
############################################################
func _park_user_file() -> void:
	_parked = "" if not FileAccess.file_exists(SAVE_PATH) else FileAccess.get_file_as_string(SAVE_PATH)
	_remove_save()


func _restore_user_file() -> void:
	_remove_save()
	if not _parked.is_empty():
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_parked)
			file.close()
	ScrambledScoreManager.reset_cache()


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


############################################################
# WORD BANK
############################################################
func test_bank() -> void:
	ScrambledData.reset_cache()
	_check(ScrambledData.book_count() >= 3, "the bank has at least three books (%d)" % ScrambledData.book_count())
	_check(ScrambledData.has_book(1) and ScrambledData.has_lesson(1, 2), "Vision 1 / Lesson 2 exists")
	_check(ScrambledData.word_count(1, 2) >= 10,
		"Vision 1 / Lesson 2 is playable (%d words)" % ScrambledData.word_count(1, 2))
	_check(not ScrambledData.lesson_title_fa(1, 2).is_empty(), "the lesson carries its Persian title")

	var expected := 0
	var letters_ok := true
	var meanings_ok := true
	for book_data in ScrambledData.books():
		for lesson_data in book_data["lessons"]:
			expected += int(lesson_data["word_count"])
			var seen := {}
			for entry in lesson_data["words"]:
				var spelling := str(entry["word"])
				if spelling.length() < 3 or spelling.length() > 12:
					letters_ok = false
				for ch in spelling:
					var lower := ch.to_lower()
					if lower < "a" or lower > "z":
						letters_ok = false
				if str(entry["meaning"]).is_empty():
					meanings_ok = false
				var key := spelling.to_lower()
				if seen.has(key):
					letters_ok = false
				seen[key] = true
	_check(letters_ok, "every word is 3-12 latin letters and unique inside its lesson")
	_check(meanings_ok, "every word carries an English meaning")
	_check(ScrambledData.all_words().size() == expected,
		"the flat bank matches the lesson totals (%d words)" % expected)
	var ordered := ScrambledData.words_ordered(1, 2)
	_check(ordered.size() == ScrambledData.word_count(1, 2), "ordering a lesson keeps every word")
	var ramp_ok := true
	for i in range(1, ordered.size()):
		if str(ordered[i]["word"]).length() < str(ordered[i - 1]["word"]).length():
			ramp_ok = false
	_check(ramp_ok, "learning deals the shortest words first")


############################################################
# DAILY PICKER
############################################################
func test_daily_picker() -> void:
	ScrambledDailyPicker.reset_cache()
	_check(ScrambledDailyPicker.pick().size() == ScrambledDailyPicker.WORDS_PER_DAY,
		"today's challenge deals five words (%d)" % ScrambledDailyPicker.pick().size())

	var first := _word_list(ScrambledDailyPicker.pick_for_day(1000))
	_check(first == _word_list(ScrambledDailyPicker.pick_for_day(1000)),
		"the same day always deals the same words")
	_check(first != _word_list(ScrambledDailyPicker.pick_for_day(1001)),
		"the next day deals a different set")

	var overlap := false
	for word in _word_list(ScrambledDailyPicker.pick_for_day(1001)):
		if first.has(word):
			overlap = true
	_check(not overlap, "consecutive days never share a word")

	var bank := _word_list(ScrambledData.all_words())
	var in_bank := true
	for word in first:
		if not bank.has(word):
			in_bank = false
	_check(in_bank, "every daily word comes from the bank")
	_check(_word_list(ScrambledDailyPicker.pick()) == _word_list(
		ScrambledDailyPicker.pick_for_day(ScrambledDailyPicker.day_index())),
		"pick() is today's window of the frozen order")
	_check(ScrambledDailyPicker.puzzle_id().begins_with("scrambled-"),
		"the puzzle id carries the date (%s)" % ScrambledDailyPicker.puzzle_id())
	_check(not ScrambledDailyPicker.time_left_text().is_empty(),
		"the countdown reads (%s)" % ScrambledDailyPicker.time_left_text())
	var left := ScrambledDailyPicker.seconds_until_next_day()
	_check(left > 0 and left <= ScrambledDailyPicker.SECONDS_PER_DAY, "the countdown stays inside one day")
############################################################
# SCRAMBLE / SOLVE RULES
############################################################
func test_scramble() -> void:
	var data := {"word": "planet", "meaning": "A world", "meaning_fa": "سیاره"}
	var a := ScrambledWordController.new()
	a.setup(data, 4242)
	_check(a.letter_count() == 6, "the controller keeps every letter")
	_check(ScrambledWordController.letters_to_text(a.letters) != "PLANET",
		"a seeded scramble is never already solved (%s)" % ScrambledWordController.letters_to_text(a.letters))

	var b := ScrambledWordController.new()
	b.setup(data, 4242)
	_check(ScrambledWordController.letters_to_text(a.letters) == ScrambledWordController.letters_to_text(b.letters),
		"the same seed deals the same scramble")

	var c := ScrambledWordController.new()
	c.setup(data, 99)
	_check(ScrambledWordController.letters_to_text(c.letters) != ScrambledWordController.letters_to_text(a.letters),
		"a different seed deals a different scramble")

	_check(a.is_solved(["P", "L", "A", "N", "E", "T"]), "the answer spells the word")
	_check(not a.is_solved(["P", "L", "A", "N", "E", "E"]), "a wrong letter does not")
	_check(not a.is_solved(["P", "L", "A", "N", "E"]), "a short board does not")

	_check(a.misplaced(["P", "L", "A", "N", "E", "T"]).is_empty(), "a solved board has no misplaced letter")
	_check(a.misplaced(["P", "L", "A", "N", "T", "E"]) == [4, 5], "the last two letters are reported misplaced")
	_check(a.is_near_miss(["P", "L", "A", "N", "T", "E"]), "two wrong letters is a near miss")
	_check(not a.is_near_miss(["T", "E", "N", "A", "L", "P"]), "a scrambled board is not a near miss")

	# A word whose letters are all the same cannot be scrambled.
	var same := ScrambledWordController.new()
	same.setup({"word": "mmm"}, 7)
	_check(ScrambledWordController.letters_to_text(same.letters) == "MMM",
		"an unscramblable word keeps its order instead of looping forever")


############################################################
# SCORE TABLE
############################################################
func test_score_table() -> void:
	_check(ScrambledScoreManager.points_for(5.0, false) == 100, "under 10s is worth 100")
	_check(ScrambledScoreManager.points_for(10.0, false) == 100, "exactly 10s is still 100")
	_check(ScrambledScoreManager.points_for(10.1, false) == 60, "past 10s is worth 60")
	_check(ScrambledScoreManager.points_for(30.0, false) == 60, "exactly 30s is still 60")
	_check(ScrambledScoreManager.points_for(30.1, false) == 40, "past 30s is worth 40")
	_check(ScrambledScoreManager.points_for(50.0, false) == 40, "exactly 50s is still 40")
	_check(ScrambledScoreManager.points_for(50.1, false) == 30, "past 50s is worth 30")
	_check(ScrambledScoreManager.points_for(60.0, false) == 30, "exactly 60s is still 30")
	_check(ScrambledScoreManager.points_for(120.0, false) == 20, "a slow solve is worth 20")

	_check(ScrambledScoreManager.points_for(5.0, true) == 90, "a hint costs 10 points")
	_check(ScrambledScoreManager.points_for(120.0, true) == 10, "a hinted slow solve is worth 10")
	_check(ScrambledScoreManager.points_for(120.0, true) == ScrambledScoreManager.MIN_WORD_POINTS,
		"the penalty never drops a word below the floor")

	_check(ScrambledScoreManager.MAX_DAILY_SCORE == 500, "a perfect day is 500")
	_check(ScrambledScoreManager.MIN_DAILY_SCORE == 50, "the floor of a five-word day is 50")
	_check(str(ScrambledScoreManager.rating_for(500)["label"]) == "شگفت‌انگیز!", "500 rates top")
	_check(str(ScrambledScoreManager.rating_for(50)["label"]) == "دوباره تلاش کن", "50 rates bottom")
	_check(int(ScrambledScoreManager.rating_for(300)["min_score"]) == 250, "300 falls in the third band")


############################################################
# RECORDS
############################################################
func test_daily_record() -> void:
	ScrambledScoreManager.reset_cache()
	_remove_save()
	_check(ScrambledScoreManager.today_score() == 0, "a fresh record starts at zero")
	_check(ScrambledScoreManager.played_days() == 0, "no day is played yet")
	_check(not ScrambledScoreManager.today_played(), "today is not played yet")

	_check(ScrambledScoreManager.save_daily_attempt(320, 5, 1, 41.5), "the first attempt sets the day's best")
	_check(ScrambledScoreManager.today_score() == 320, "the day keeps its score")
	_check(ScrambledScoreManager.today_attempts() == 1, "the attempt is counted")
	_check(ScrambledScoreManager.played_days() == 1, "the day is counted once")

	_check(not ScrambledScoreManager.save_daily_attempt(120, 5, 3, 90.0),
		"a worse replay does not replace the best")
	_check(ScrambledScoreManager.today_score() == 320, "the best score survives a worse replay")
	_check(ScrambledScoreManager.today_attempts() == 2, "replays are counted")

	_check(ScrambledScoreManager.save_daily_attempt(460, 5, 0, 33.0), "a better replay takes the best")
	_check(ScrambledScoreManager.today_score() == 460, "the day's best is updated")
	_check(ScrambledScoreManager.best_score() == 460, "the overall best follows")
	_check(ScrambledScoreManager.best_score_date() == ScrambledDailyPicker.date_key(), "the best date is today")
	_check(ScrambledScoreManager.total_attempts() == 3, "every attempt is counted")
	_check(ScrambledScoreManager.daily_history().size() == 1, "the history holds the played day")

	ScrambledScoreManager.reset_cache()
	_check(ScrambledScoreManager.today_score() == 460, "the record is read back from disk")
	_check(ScrambledScoreManager.played_days() == 1, "the played days survive a reload")

	# A corrupt file must never break a screen.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("{ this is not json")
		file.close()
	ScrambledScoreManager.reset_cache()
	_check(ScrambledScoreManager.today_score() == 0, "a corrupt record starts fresh")
	_check(ScrambledScoreManager.today_attempts() == 0, "a corrupt record keeps no attempts")


func test_practice_record() -> void:
	ScrambledScoreManager.reset_cache()
	_remove_save()
	var empty := ScrambledScoreManager.practice_stats(1, 2)
	_check(int(empty["words"]) == 0 and int(empty["plays"]) == 0, "an unpractised lesson reports zeros")

	ScrambledScoreManager.record_practice_word(1, 2, false, 12.0)
	ScrambledScoreManager.record_practice_word(1, 2, true, 30.5)
	ScrambledScoreManager.record_practice_word(1, 3, false, 8.0)
	var stats := ScrambledScoreManager.practice_stats(1, 2)
	_check(int(stats["words"]) == 2, "both words are recorded")
	_check(int(stats["hints"]) == 1, "the hinted word is counted")
	_check(is_equal_approx(float(stats["seconds"]), 42.5), "the time adds up (%s)" % str(stats["seconds"]))
	_check(ScrambledScoreManager.total_practice_words() == 3, "practice words add up across lessons")
	_check(int(ScrambledScoreManager.practice_stats(2, 1)["words"]) == 0, "another book stays untouched")

	ScrambledScoreManager.reset_cache()
	_check(int(ScrambledScoreManager.practice_stats(1, 2)["words"]) == 2, "practice survives a reload")
	_check(ScrambledScoreManager.practice_key(1, 2) == "1_2", "the practice key names the lesson")


############################################################
# SESSIONS
############################################################
func test_learning_session() -> void:
	ScrambledScoreManager.reset_cache()
	_remove_save()
	ScrambledGameManager.reset()
	ScrambledGameManager.reset_play_counts()

	_check(ScrambledGameManager.start_learning(1, 2), "learning mode deals Vision 1 / Lesson 2")
	_check(ScrambledGameManager.mode == ScrambledGameManager.Mode.LEARNING, "the mode is learning")
	_check(ScrambledGameManager.word_count() == ScrambledData.word_count(1, 2), "the whole lesson is dealt")
	_check(ScrambledGameManager.word_position() == 1, "the session starts on the first word")
	_check(ScrambledGameManager.hint_delay() == ScrambledGameManager.LEARNING_HINT_DELAY,
		"learning offers the hint after 30s")
	_check(ScrambledGameManager.controller != null, "the first word has a controller")
	_check(not ScrambledGameManager.controller.letters.is_empty(), "the board is dealt letters")
	_check(ScrambledGameManager.current_word_potential_points() == 0, "learning mode scores nothing")

	var first_word := ScrambledGameManager.controller.word
	var entry := ScrambledGameManager.solve_current_word()
	_check(str(entry.get("word", "")) == first_word, "the solved word is recorded")
	_check(ScrambledGameManager.correct_count() == 1, "one word is spelled")
	_check(int(ScrambledScoreManager.practice_stats(1, 2)["words"]) == 1,
		"learning practice is written word by word")
	_check(ScrambledGameManager.solve_current_word().is_empty(), "a solved word cannot be solved twice")

	_check(ScrambledGameManager.advance(), "the session moves to the second word")
	_check(ScrambledGameManager.state == ScrambledGameManager.State.PLAYING, "the new word is playable")
	_check(ScrambledGameManager.current_word_hint_used() == false, "the hint flag resets per word")
	ScrambledGameManager.mark_hint_used()
	_check(ScrambledGameManager.current_word_hint_used(), "the hint flag is remembered")

	var guard := 0
	while ScrambledGameManager.state != ScrambledGameManager.State.FINISHED and guard < 500:
		ScrambledGameManager.solve_current_word()
		ScrambledGameManager.advance()
		guard += 1
	_check(ScrambledGameManager.state == ScrambledGameManager.State.FINISHED, "the lesson ends on its last word")
	_check(ScrambledGameManager.correct_count() == ScrambledData.word_count(1, 2),
		"every word of the lesson was spelled (%d)" % ScrambledGameManager.correct_count())
	_check(ScrambledGameManager.hints_used() == 1, "the hint is counted once")
	_check(int(ScrambledScoreManager.practice_stats(1, 2)["words"]) == ScrambledData.word_count(1, 2),
		"the practice record ends with the whole lesson")
	_check(ScrambledGameManager.average_seconds() >= 0.0, "the session reports an average time")


func test_competition_session() -> void:
	ScrambledScoreManager.reset_cache()
	_remove_save()
	ScrambledGameManager.reset()

	_check(ScrambledGameManager.start_competition(), "competition mode deals today's words")
	_check(ScrambledGameManager.mode == ScrambledGameManager.Mode.COMPETITION, "the mode is competition")
	_check(ScrambledGameManager.word_count() == ScrambledDailyPicker.WORDS_PER_DAY, "five words are dealt")
	_check(ScrambledGameManager.hint_delay() == ScrambledGameManager.COMPETITION_HINT_DELAY,
		"competition offers the hint after 60s")
	_check(ScrambledGameManager.current_word_potential_points() == 100, "a fresh word is worth the top band")
	_check(ScrambledGameManager.total_score() == 0, "a fresh run scores nothing")

	# The daily board is frozen: a replay deals the very same scramble.
	var letters_before := ScrambledWordController.letters_to_text(ScrambledGameManager.controller.letters)
	ScrambledGameManager.mark_hint_used()
	var entry := ScrambledGameManager.solve_current_word()
	_check(int(entry.get("points", 0)) > 0, "a solved daily word scores")
	_check(ScrambledGameManager.total_score() == int(entry.get("points", 0)), "the total follows the word")
	_check(ScrambledGameManager.total_score() == ScrambledScoreManager.points_for(
		float(entry["seconds"]), true), "the recorded points come from the score table")

	ScrambledGameManager.reset()
	_check(ScrambledGameManager.start_competition(), "the daily run can be replayed")
	_check(ScrambledWordController.letters_to_text(ScrambledGameManager.controller.letters) == letters_before,
		"the daily scramble is identical on a replay")

	# Quitting halfway keeps the points already earned.
	ScrambledGameManager.mark_hint_used()
	ScrambledGameManager.solve_current_word()
	ScrambledGameManager.abandon()
	_check(ScrambledScoreManager.today_played(), "a quit daily run still records its score")
	_check(ScrambledScoreManager.today_score() > 0, "the partial score is kept")
	_check(ScrambledScoreManager.today_attempts() == 1, "abandoning counts as one attempt")

	# A fully played run replaces the day's best.
	_check(ScrambledGameManager.start_competition(), "a second run starts")
	ScrambledGameManager.mark_hint_used()
	var guard := 0
	while ScrambledGameManager.state != ScrambledGameManager.State.FINISHED and guard < 50:
		ScrambledGameManager.solve_current_word()
		ScrambledGameManager.advance()
		guard += 1
	_check(ScrambledGameManager.state == ScrambledGameManager.State.FINISHED, "the daily run finishes")
	_check(ScrambledGameManager.correct_count() == ScrambledDailyPicker.WORDS_PER_DAY,
		"all five words were spelled (%d)" % ScrambledGameManager.correct_count())
	_check(ScrambledScoreManager.today_attempts() == 2, "the replay is counted as a second attempt")
	_check(ScrambledScoreManager.today_score() == ScrambledGameManager.total_score(),
		"the fully played run owns the day's best (%d)" % ScrambledScoreManager.today_score())


############################################################
# BOARD (the drag-and-drop itself)
############################################################
## The pure modules above never touch the screen, so the drag pipeline is
## exercised here against a real board: grab, drag past two slots, drop, and
## solve a three-letter word by two moves.
func test_board_drag() -> void:
	var board_scene: PackedScene = load("res://scenes/word_game/scrambled/TileBoard.tscn")
	var board := board_scene.instantiate()
	add_child(board)
	board.size = Vector2(1000, 420)
	await get_tree().process_frame
	await get_tree().process_frame

	var controller := ScrambledWordController.new()
	controller.setup({"word": "sun"}, 12345)
	var settled: Array = []
	board.arrangement_settled.connect(func(solved: bool) -> void: settled.append(solved))
	board.build(controller, false)
	await get_tree().process_frame

	_check(board.tile_count() == 3, "the board dealt three tiles")
	_check(ScrambledWordController.letters_to_text(board.tiles_letters())
		== ScrambledWordController.letters_to_text(controller.letters),
		"the board shows the scrambled letters (%s)" % board.current_text())
	_check(not board.is_solved(), "the dealt board is not solved")

	var first_tile: ScrambledTile = board.get_child(0)
	var second_tile: ScrambledTile = board.get_child(1)
	_check(first_tile.letter != "", "tiles carry letters")

	# Drag the first tile two slots to the right and drop it there.
	var start: Vector2 = first_tile.position + first_tile.size * 0.5
	board._on_tile_grabbed(first_tile, board.get_global_transform() * start)
	_check(first_tile.state == ScrambledTile.State.HELD, "a grabbed tile is held")
	_check(board.is_busy(), "the board knows a tile is carried")

	board._on_tile_dragged(first_tile,
		board.get_global_transform() * (Vector2(start.x + 700.0, start.y)))
	_check(board._preview_index == 2, "dragging right opens the third slot")
	board._on_tile_released(first_tile)
	await get_tree().create_timer(0.5).timeout
	_check(settled.size() >= 1 and not bool(settled[settled.size() - 1]),
		"the drop settled without solving")
	_check(first_tile.position.x > second_tile.position.x,
		"the carried tile landed in the slot it was dropped in")

	# Two more moves finish the word. The tile references are captured before
	# each grab: grabbing calls move_to_front(), which reorders the children,
	# so a fresh get_child(0) would name a different tile.
	var dragged: ScrambledTile = board.get_child(0)
	board._on_tile_grabbed(dragged,
		board.get_global_transform() * (dragged.position + Vector2(50, 50)))
	board._on_tile_dragged(dragged,
		board.get_global_transform() * (Vector2(dragged.position.x + 700.0, dragged.position.y)))
	board._on_tile_released(dragged)
	await get_tree().create_timer(0.5).timeout

	dragged = board.get_child(0)
	board._on_tile_grabbed(dragged,
		board.get_global_transform() * (dragged.position + Vector2(50, 50)))
	board._on_tile_dragged(dragged,
		board.get_global_transform() * (Vector2(dragged.position.x + 700.0, dragged.position.y)))
	board._on_tile_released(dragged)
	await get_tree().create_timer(0.5).timeout
	_check(bool(settled[settled.size() - 1]) == board.is_solved(),
		"the settle signal agrees with the board")
	_check(board.is_solved(), "the arranged board is solved (%s)" % board.current_text())
	_check(not board.is_busy(), "nothing is carried after a settle")

	board.queue_free()


## Regression: the first word of a session is dealt in the same frame the
## screen lays out, so the board is built before it knows its size, and the
## real layout only arrives a frame later — in the middle of the deal. The row
## must end up visible and on its slots: the deal fades in from alpha 0, so a
## deal abandoned (rather than restarted) would leave the letters invisible,
## and one still aimed at the pre-layout row would land them off the track.
func test_board_first_word_layout() -> void:
	var board_scene: PackedScene = load("res://scenes/word_game/scrambled/TileBoard.tscn")
	var board: Control = board_scene.instantiate()
	add_child(board)
	# Deliberately without a size: exactly the first frame of a session.
	var controller := ScrambledWordController.new()
	controller.setup({"word": "sun"}, 777)
	board.build(controller, true)
	await get_tree().process_frame
	_check(board.tile_count() == 3, "the first word is dealt before the board is sized")

	# The layout lands mid-deal: the deal is restarted against the real row.
	board.size = Vector2(1000, 420)
	_check(board._dealing, "a layout change mid-deal restarts the deal")
	await get_tree().create_timer(0.9).timeout

	var row_y := -1.0
	for i in board.tile_count():
		var tile: ScrambledTile = board.get_child(i)
		_check(is_equal_approx(tile.modulate.a, 1.0),
			"letter %d is visible after the deal (alpha %.2f)" % [i, tile.modulate.a])
		var slot: Vector2 = board._slot_position(i)
		_check(tile.position.distance_to(slot) < 2.0,
			"letter %d landed on its slot (%.0f,%.0f vs %.0f,%.0f)" % [i,
				tile.position.x, tile.position.y, slot.x, slot.y])
		_check(tile.position.y >= 0.0
			and tile.position.y + tile.size.y <= board.size.y + 1.0,
			"letter %d sits inside the board" % i)
		if row_y < 0.0:
			row_y = tile.position.y
			_check(true, "the dealt row has a baseline")
		else:
			_check(is_equal_approx(tile.position.y, row_y),
				"letter %d shares the row baseline" % i)
	board.queue_free()


## The same check on the real screen, containers and all: the gameplay screen
## builds the board and deals the first word inside its own _ready(), so the
## board is always built before it has been laid out. This is the path the
## player sees first, and the one that must never show an empty row.
func test_gameplay_first_word_visible() -> void:
	ScrambledScoreManager.reset_cache()
	ScrambledGameManager.reset()
	_check(ScrambledGameManager.start_learning(1, 2),
		"a learning session on Vision 1 / Lesson 2 starts")
	var screen_scene: PackedScene = load("res://scenes/word_game/scrambled/Gameplay.tscn")
	var screen: Control = screen_scene.instantiate()
	add_child(screen)
	await get_tree().create_timer(1.0).timeout

	var board: ScrambledTileBoard = screen._board
	_check(board != null, "the gameplay screen owns a board")
	if board == null:
		screen.queue_free()
		return
	_check(board.size.y > 100.0, "the board has a real size (%.0f)" % board.size.y)
	_check(board.tile_count() > 0,
		"the first word was dealt (%d letters)" % board.tile_count())
	var row_y := -1.0
	for i in board.tile_count():
		var tile := board.get_child(i) as ScrambledTile
		_check(tile != null, "child %d is a tile" % i)
		_check(tile.modulate.a > 0.99,
			"the first word's letter %d is visible (alpha %.2f)" % [i, tile.modulate.a])
		_check(tile.size.x > 32.0, "letter %d has a real size (%.0f)" % [i, tile.size.x])
		_check(tile.position.y >= 0.0
			and tile.position.y + tile.size.y <= board.size.y + 1.0,
			"letter %d sits inside the board (%.0f..%.0f of %.0f)" % [i,
				tile.position.y, tile.position.y + tile.size.y, board.size.y])
		if row_y < 0.0:
			row_y = tile.position.y
		else:
			_check(is_equal_approx(tile.position.y, row_y),
				"letter %d shares the row baseline" % i)
	screen.queue_free()
	ScrambledGameManager.abandon()


############################################################
# HELPERS
############################################################
func _word_list(entries: Array) -> Array:
	var out: Array = []
	for entry in entries:
		out.append(str((entry as Dictionary).get("word", "")))
	return out


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS  " if condition else "FAIL  ") + label)
