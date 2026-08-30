extends Node
# Guard test for the "dull first-page boxes" bug fix in the grammar lesson.
#
# Root cause: GrammarLesson.gd was NOT listed in Global.SELF_THEMED_SCRIPTS,
# so Global._style_walk re-themed every PanelContainer in the lesson with a
# plain surface-only style (no shadow / no surface_alt), clobbering the
# theme-aware cards built by LearningUnitView. Exercises looked fine because
# they are created after the one-time scene_changed walk.
#
# This test reads the source file directly so it is deterministic in any
# runner context (autoloads may not be present in the test process).

func test_grammar_lesson_is_self_themed() -> void:
	var f := FileAccess.open("res://autoload/Global.gd", FileAccess.READ)
	if f == null:
		print("grammar theme guard: SKIP (could not read Global.gd)")
		return
	var txt: String = f.get_as_text()
	f.close()
	var ok: bool = txt.contains('"grammar_lesson.gd"')
	print("Global.SELF_THEMED_SCRIPTS lists grammar_lesson.gd: ", ok)
	assert(ok, "grammar_lesson.gd missing from Global.SELF_THEMED_SCRIPTS")
