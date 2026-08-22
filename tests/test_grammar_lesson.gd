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
