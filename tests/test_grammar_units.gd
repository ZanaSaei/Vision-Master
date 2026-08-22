extends Node
# Verifies the new grammar unit-unlock progression and start-at-unit logic:
#  - completing a unit unlocks the next one in persisted Global state
#  - the lesson starts at the chosen unit index (clamped to a valid range)
# NOTE: these tests mutate Global (autoload) state, so each saves the prior
# value and restores it afterward to avoid contaminating real saved progress.

var _orig_unlocked: Variant = null
var _orig_start: int = 0


func _restore() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	if _orig_unlocked == null:
		Global.grammar_unlocked_units.erase(key)
	else:
		Global.grammar_unlocked_units[key] = _orig_unlocked
	Global.grammar_start_unit_index = _orig_start
	Global._save_progress()


func test_grammar_unlock_progression() -> void:
	var key: String = "%d_%d" % [Global.current_book, Global.current_lesson]
	_orig_unlocked = Global.grammar_unlocked_units.get(key, null)
	_orig_start = Global.grammar_start_unit_index

	Global.grammar_unlocked_units.erase(key)
	assert(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson) == 1, "new book/lesson starts with 1 unit unlocked")

	var lesson_script: GDScript = load("res://scenes/grammar/scripts/GrammarLesson.gd")
	var lesson: Control = lesson_script.new()
	lesson.units = [{}, {}, {}]
	lesson.current_unit_index = 0
	lesson.current_unit_index += 1
	lesson._sync_grammar_progress()
	assert(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson) == 2, "completing unit 0 unlocks unit 1, got " + str(Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson)))

	lesson.current_unit_index = 3
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
