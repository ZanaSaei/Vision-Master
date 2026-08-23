extends Node
# Verifies the new grammar unit-unlock progression and start-at-unit logic:
#  - completing a بخش unlocks the next one in persisted Global state
#  - the lesson starts at the chosen unit index (clamped to a valid range)
# NOTE: these tests mutate Global (autoload) state, which persists to the
# real progress.json via Global._save_progress(). To guarantee the tests can
# NEVER destroy the player's real saved progress (XP/unlocks), the original
# progress.json bytes are backed up in _init() and restored verbatim in
# _exit_tree(), regardless of what the tests do in between.

var _backup := ""
var _orig_unlocked: Variant = null
var _orig_start: int = 0
var _orig_xp: Variant = null
var _orig_completed: Variant = null

const TEST_PROGRESS_PATH := "user://progress.json"


func _init() -> void:
	if FileAccess.file_exists(TEST_PROGRESS_PATH):
		var f: FileAccess = FileAccess.open(TEST_PROGRESS_PATH, FileAccess.READ)
		_backup = f.get_as_text()
		f.close()


func _exit_tree() -> void:
	# Restore the real progress file byte-for-byte so tests never wipe the
	# player's saved XP / unlocked units.
	if _backup != "":
		var f: FileAccess = FileAccess.open(TEST_PROGRESS_PATH, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()


func _restore() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	if _orig_unlocked == null:
		Global.grammar_unlocked_units.erase(key)
	else:
		Global.grammar_unlocked_units[key] = _orig_unlocked
	Global.grammar_start_unit_index = _orig_start
	if _orig_xp == null:
		Global.grammar_xp.erase(key)
	else:
		Global.grammar_xp[key] = _orig_xp
	if _orig_completed == null:
		Global.grammar_completed_units.erase(key)
	else:
		Global.grammar_completed_units[key] = _orig_completed


func test_grammar_unlock_progression() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	_orig_unlocked = Global.grammar_unlocked_units.get(key, null)
	_orig_start = Global.grammar_start_unit_index

	Global.grammar_unlocked_units.erase(key)
	assert(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson) == 1, "new book/lesson starts with 1 unit unlocked")

	var lesson_script: GDScript = load("res://scenes/grammar/scripts/GrammarLesson.gd")
	var lesson: Control = lesson_script.new()
	lesson.units = [{}, {}, {}]
	# Mirrors the real flow: current_unit_index still points at the completed
	# بخش when _sync_grammar_progress() is called (reward popup flow).
	lesson.current_unit_index = 0
	lesson._sync_grammar_progress()
	assert(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson) == 2, "completing بخش 1 unlocks بخش 2, got " + str(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson)))

	lesson.current_unit_index = 2
	lesson._sync_grammar_progress()
	assert(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson) == 3, "unlock count capped at total units, got " + str(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson)))
	lesson.free()

	_restore()


func test_lesson_starts_at_chosen_unit() -> void:
	_orig_start = Global.grammar_start_unit_index
	var lesson_script: GDScript = load("res://scenes/grammar/scripts/GrammarLesson.gd")
	var lesson: Control = lesson_script.new()
	Global.set_grammar_start_unit(5)
	lesson._ready()
	assert(lesson.current_unit_index == 5, "lesson starts at chosen index 5, got " + str(lesson.current_unit_index))
	assert(Global.grammar_start_unit_index == 0, "start index is consumed/reset after use")
	lesson.free()
	_restore()


func test_start_index_clamped() -> void:
	_orig_start = Global.grammar_start_unit_index
	var lesson_script: GDScript = load("res://scenes/grammar/scripts/GrammarLesson.gd")
	var lesson: Control = lesson_script.new()
	Global.set_grammar_start_unit(99999)
	lesson._ready()
	var expected: int = lesson.units.size() - 1
	assert(lesson.current_unit_index == expected, "start index clamped to last valid index " + str(expected) + ", got " + str(lesson.current_unit_index))
	lesson.free()
	_restore()


func test_xp_awarded_only_on_unit_completion() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	_orig_xp = Global.grammar_xp.get(key, null)
	_orig_unlocked = Global.grammar_unlocked_units.get(key, null)
	_orig_start = Global.grammar_start_unit_index
	_orig_completed = Global.grammar_completed_units.get(key, null)
	Global.grammar_xp.erase(key)
	Global.grammar_unlocked_units.erase(key)
	Global.grammar_completed_units.erase(key)

	var lesson_script: GDScript = load("res://scenes/grammar/scripts/GrammarLesson.gd")
	var lesson: Control = lesson_script.new()
	lesson.lesson_data = {"title_fa": "test", "xp_per_unit": 10}
	lesson.units = [{}, {}]
	lesson.current_unit_index = 0
	# _on_exercise_completed finishes the current بخش: it syncs progress,
	# awards XP, then shows the reward (reward popup is null in this context,
	# so guard the reward call below to avoid a null deref).
	lesson.xp = 0
	lesson._sync_grammar_progress()
	lesson._award_unit_xp()
	assert(lesson.xp == 10, "completing a بخش awards xp_per_unit, got " + str(lesson.xp))
	assert(Global.get_grammar_xp(Global.current_book, Global.current_lesson) == 10, "XP persisted to Global, got " + str(Global.get_grammar_xp(Global.current_book, Global.current_lesson)))
	assert(lesson._last_award == 10, "last award tracks the granted amount")
	lesson.free()
	_restore()


func test_no_xp_on_unit_replay() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	_orig_xp = Global.grammar_xp.get(key, null)
	_orig_unlocked = Global.grammar_unlocked_units.get(key, null)
	_orig_start = Global.grammar_start_unit_index
	_orig_completed = Global.grammar_completed_units.get(key, null)
	Global.grammar_xp.erase(key)
	Global.grammar_unlocked_units.erase(key)
	Global.grammar_completed_units.erase(key)

	var lesson_script: GDScript = load("res://scenes/grammar/scripts/GrammarLesson.gd")
	var lesson: Control = lesson_script.new()
	lesson.lesson_data = {"title_fa": "test", "xp_per_unit": 10}
	lesson.units = [{}, {}]
	lesson.current_unit_index = 0
	lesson.xp = 0
	# First completion awards XP and records the unit as done.
	lesson._award_unit_xp()
	assert(lesson.xp == 10, "first completion awards XP, got " + str(lesson.xp))

	# Replaying the same unit (same index) awards no additional XP.
	lesson.xp = 0
	lesson._award_unit_xp()
	assert(lesson.xp == 0, "replaying a completed unit awards no XP, got " + str(lesson.xp))
	assert(lesson._last_award == 0, "replay last_award should be 0, got " + str(lesson._last_award))
	lesson.free()
	_restore()


func test_no_content_for_missing_lesson() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	_orig_xp = Global.grammar_xp.get(key, null)
	_orig_unlocked = Global.grammar_unlocked_units.get(key, null)
	_orig_start = Global.grammar_start_unit_index

	var saved_book: int = Global.current_book
	var saved_lesson: int = Global.current_lesson
	Global.current_book = 2
	Global.current_lesson = 1  # no vision2_lesson1.json exists

	var units_script: GDScript = load("res://scenes/grammar/scripts/GrammarUnits.gd")
	var screen: Control = units_script.new()
	screen._load_lesson()
	assert(screen.units.is_empty(), "a lesson with no grammar JSON should expose no units")
	screen._build_ui()
	assert(screen._unit_buttons.size() == 0, "no unit cards are built when content is missing")
	# A "no content yet" label should be present instead of the unit grid.
	var found_empty: bool = false
	for child in _all_descendants(screen):
		if child is Label and str(child.text).contains("هنوز محتوایی نیست"):
			found_empty = true
			break
	assert(found_empty, "a 'no content yet' message should be shown for missing lessons")

	Global.current_book = saved_book
	Global.current_lesson = saved_lesson
	screen.free()
	_restore()


func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_descendants(c))
	return out
