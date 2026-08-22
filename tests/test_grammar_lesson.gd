extends Node
# Validates the grammar feedback loop that the GrammarLesson fix relies on.
# GrammarLesson._on_answer_selected now routes correct/wrong answers to
# FeedbackPopup.show_correct() / show_wrong() (previously it called the blank
# _show_popup(), so feedback was stale/empty). These tests verify the popup
# displays the correct state and explanation for both paths.
#
# FeedbackPopup._build_ui() is called manually (not via _ready()) so the test
# is deterministic regardless of tree/ready timing.

func test_feedback_popup_correct_state() -> void:
	var popup := FeedbackPopup.new()
	popup._build_ui()

	popup.show_correct("Good job!")
	assert(popup.visible, "popup should be shown for a correct answer")
	assert(popup.title_label.text.contains("عالی"), "correct should show success title, got: " + popup.title_label.text)
	assert(popup.explanation_label.text == "Good job!", "correct should show its explanation")
	popup.queue_free()

func test_feedback_popup_wrong_state() -> void:
	var popup := FeedbackPopup.new()
	popup._build_ui()

	popup.show_wrong("Try again.")
	assert(popup.visible, "popup should be shown for a wrong answer")
	assert(popup.title_label.text.contains("نزدیک"), "wrong should show retry title, got: " + popup.title_label.text)
	assert(popup.explanation_label.text == "Try again.", "wrong should show its explanation")
	popup.queue_free()

func test_grammar_lesson_routes_to_show_correct() -> void:
	# Verify GrammarLesson._on_answer_selected calls show_correct/show_wrong
	# (not the stale _show_popup path). We inspect the popup's state directly.
	var lesson: Control = (load("res://scenes/grammar/scripts/GrammarLesson.gd") as GDScript).new()
	lesson._build_ui()
	var real_popup: FeedbackPopup = lesson.feedback_popup
	real_popup._build_ui()

	lesson.lesson_data = {"title_fa": "test", "xp_per_correct": 10}
	lesson.units = [{
		"type": "multiple_choice",
		"questions": [{
			"question": "q", "options": ["A", "B"], "correct": 0,
			"explanation_fa": "RIGHT-EXP", "wrong_explanation_fa": "WRONG-EXP"
		}]
	}]
	lesson.current_unit_index = 0
	lesson._show_unit()

	var ex: MultipleChoiceExercise = null
	for c in lesson.content_container.get_children():
		if c is MultipleChoiceExercise:
			ex = c
			break
	assert(ex != null, "exercise should be created")
	ex.options_container.get_child(0).pressed.emit()

	assert(real_popup.visible, "feedback popup should appear after answering")
	assert(real_popup.title_label.text.contains("عالی"), "correct path should show success, got: " + real_popup.title_label.text)
	assert(real_popup.explanation_label.text == "RIGHT-EXP", "correct path should show explanation")
	assert(lesson.xp == 10, "correct answer awards XP")
	assert(lesson.xp_label.text == "⭐ 10", "XP label updates live, got: " + lesson.xp_label.text)
	lesson.queue_free()

func test_unscramble_blanks_mode() -> void:
	# The unscramble exercise must also support a template + word-bank
	# format (e.g. "______ he ______ able to be here?" with words [be, Will]).
	var ex := UnscrambleExercise.new()
	ex.setup({
		"type": "unscramble",
		"instruction_fa": "جاهای خالی را پر کن.",
		"items": [{
			"template": "______ he ______ able to be here?",
			"options": ["be", "Will"],
			"answer": ["Will", "be"]
		}]
	})
	assert(ex._blanks_mode, "blanks mode should be auto-detected from template+options")
	assert(ex._blank_buttons.size() == 2, "should render 2 blanks, got " + str(ex._blank_buttons.size()))
	assert(ex._bank_buttons.size() == 2, "should render 2 word-bank buttons, got " + str(ex._bank_buttons.size()))

	var will_btn: GrammarButton = ex._bank_buttons["Will"]
	var be_btn: GrammarButton = ex._bank_buttons["be"]
	ex._fill_blank(will_btn, "Will")
	ex._fill_blank(be_btn, "be")
	assert(ex._blank_words[0] == "Will" and ex._blank_words[1] == "be", "bank words fill blanks in order")
	assert(ex._check_blanks_answer(ex.exercise_data["items"][0]), "correct blanks answer should pass")
	ex.queue_free()

	# A wrong order must fail.
	var ex2 := UnscrambleExercise.new()
	ex2.setup({
		"type": "unscramble",
		"items": [{
			"template": "______ he ______ able to be here?",
			"options": ["be", "Will"],
			"answer": ["Will", "be"]
		}]
	})
	var be2: GrammarButton = ex2._bank_buttons["be"]
	var will2: GrammarButton = ex2._bank_buttons["Will"]
	ex2._fill_blank(be2, "be")
	ex2._fill_blank(will2, "Will")
	assert(ex2._check_blanks_answer(ex2.exercise_data["items"][0]) == false, "wrong order should fail")
	ex2.queue_free()

func test_grammar_data_loads_generically() -> void:
	# The system must load any lesson from data/grammar/vision{book}_lesson{lesson}.json
	var data: Dictionary = GrammarData.load_lesson(1, 1)
	assert(data.has("units"), "loaded lesson should contain units")
	assert(data.get("units", []).size() > 0, "lesson should have at least one unit")
	# Each unit must declare a known type so the system can render it
	var known := ["learn", "multiple_choice", "fill_blank", "true_false", "matching", "unscramble"]
	for u in data.get("units", []):
		assert(u.get("type", "") in known, "unit type must be known: " + str(u.get("type")))
	# Missing files resolve to an empty dict (no crash)
	var missing: Dictionary = GrammarData.load_lesson(9, 9)
	assert(missing.is_empty(), "missing lesson should return empty dict, not error")
