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
	assert(popup.explanation_label.text.contains("امتحان کن"), "wrong should show a 'try again' message (never the correct answer), got: " + popup.explanation_label.text)
	assert(popup.continue_button.text.contains("امتحان کن"), "wrong should offer a retry button, got: " + popup.continue_button.text)
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
	# XP is awarded only when a whole بخش finishes, never per answer.
	assert(lesson.xp == 0, "no XP for a single answer")
	assert(lesson.xp_label.text == "⭐ 0", "XP label stays put per-answer, got: " + lesson.xp_label.text)
	lesson.queue_free()

func test_wrong_answer_stays_on_question() -> void:
	# A wrong answer must NOT reveal the correct option or advance; the
	# learner retries the same question. A correct answer still advances.
	var lesson: Control = (load("res://scenes/grammar/scripts/GrammarLesson.gd") as GDScript).new()
	lesson._build_ui()
	var real_popup: FeedbackPopup = lesson.feedback_popup
	real_popup._build_ui()

	lesson.lesson_data = {"title_fa": "test"}
	lesson.units = [{
		"type": "multiple_choice",
		"questions": [
			{"question": "q1", "options": ["A", "B"], "correct": 0, "wrong_explanation_fa": "W1", "explanation_fa": "E1"},
			{"question": "q2", "options": ["C", "D"], "correct": 0, "wrong_explanation_fa": "W2", "explanation_fa": "E2"},
		]
	}]
	lesson.current_unit_index = 0
	lesson._show_unit()

	var ex: MultipleChoiceExercise = lesson._current_exercise()
	assert(ex != null, "exercise should be created")

	# Answer wrong (option index 1).
	ex.options_container.get_child(1).pressed.emit()
	assert(real_popup.is_correct == false, "wrong answer marks the popup as wrong")
	assert(real_popup.explanation_label.text.contains("امتحان کن"), "wrong feedback says try again")
	# The correct option must NOT have been revealed.
	for child in ex.options_container.get_children():
		var b: GrammarButton = child as GrammarButton
		if int(b.get_meta("answer_index", -1)) == 0:
			assert(not b.disabled and not b.has_meta("grammar_correct"), "correct option must not be revealed on a wrong answer")
			break

	# Continuing after a wrong answer stays on the same question (retry).
	lesson._on_feedback_continue()
	assert(ex.current_index == 0, "wrong answer must NOT advance to the next question")
	assert(ex.answered == false, "retry unlocks the question again")

	# Now answer correctly and continue -> advances to the next question.
	ex.options_container.get_child(0).pressed.emit()
	assert(real_popup.is_correct, "correct answer marks the popup as correct")
	lesson._on_feedback_continue()
	assert(ex.current_index == 1, "correct answer advances to the next question")

	lesson.queue_free()


func test_matching_feedback_shows_before_reward() -> void:
	# Matching: the "عالی بود" feedback must appear immediately when the
	# last pair is found; the بخش reward must wait for the continue tap.
	var progress_path := "user://progress.json"
	var backup := ""
	if FileAccess.file_exists(progress_path):
		backup = FileAccess.open(progress_path, FileAccess.READ).get_as_text()

	var lesson: Control = (load("res://scenes/grammar/scripts/GrammarLesson.gd") as GDScript).new()
	lesson._build_ui()
	var real_popup: FeedbackPopup = lesson.feedback_popup
	real_popup._build_ui()
	var reward: RewardPopup = lesson.reward_popup
	reward._build_ui()
	reward.hide()

	lesson.lesson_data = {"title_fa": "test"}
	lesson.units = [
		{"type": "matching", "items": [
			{"left": "a", "right": "A"},
			{"left": "b", "right": "B"},
		]},
		{"type": "learn", "title_fa": "x", "body_fa": "y"},
	]
	lesson.current_unit_index = 0
	lesson._show_unit()

	var ex: MatchingExercise = lesson._current_exercise()
	assert(ex != null, "matching exercise should be created")

	# Match every pair (left button then the right button with the same value).
	for left_button in ex.left_buttons:
		var value := str(left_button.get_meta("match_value", ""))
		var right_button: GrammarButton = null
		for rb in ex.right_buttons:
			if str(rb.get_meta("match_value", "")) == value and not rb.disabled:
				right_button = rb
				break
		ex._select(left_button, true)
		ex._select(right_button, false)

	# Feedback shows immediately; the reward has NOT appeared yet.
	assert(real_popup.visible, "feedback popup should show right after all pairs are found")
	assert(real_popup.is_correct, "feedback should be the success state")
	assert(reward.visible == false, "reward popup must NOT show before the continue tap")

	# Tapping continue now completes the unit and shows the reward.
	lesson._on_feedback_continue()
	assert(reward.visible, "reward popup should show after the continue tap")

	lesson.queue_free()

	# Restore the real progress file.
	if backup != "":
		FileAccess.open(progress_path, FileAccess.WRITE).store_string(backup)


func test_skip_button_after_two_wrongs() -> void:
	# The "skip" escape hatch should appear only after the learner has
	# been wrong twice on the same question, and pressing it advances to
	# the next question.
	var lesson: Control = (load("res://scenes/grammar/scripts/GrammarLesson.gd") as GDScript).new()
	lesson._build_ui()
	var real_popup: FeedbackPopup = lesson.feedback_popup
	real_popup._build_ui()

	lesson.lesson_data = {"title_fa": "test"}
	lesson.units = [{
		"type": "multiple_choice",
		"questions": [
			{"question": "q1", "options": ["A", "B"], "correct": 0, "wrong_explanation_fa": "W", "explanation_fa": "E"},
			{"question": "q2", "options": ["C", "D"], "correct": 0, "wrong_explanation_fa": "W", "explanation_fa": "E"},
		]
	}]
	lesson.current_unit_index = 0
	lesson._show_unit()

	var ex: MultipleChoiceExercise = lesson._current_exercise()
	assert(ex != null, "exercise should be created")

	# First wrong answer -> no skip button yet.
	ex.options_container.get_child(1).pressed.emit()
	assert(real_popup.skip_button.visible == false, "no skip button after the first wrong answer")
	lesson._on_feedback_continue()  # retry the same question

	# Second wrong answer -> skip button appears.
	ex.options_container.get_child(1).pressed.emit()
	assert(real_popup.skip_button.visible == true, "skip button appears after two wrong answers")

	# Pressing skip advances to the next question.
	lesson._on_skip_pressed()
	assert(ex.current_index == 1, "skip advances to the next question")

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


func test_matching_wrong_pair_no_feedback() -> void:
	# A wrong pair in the matching exercise must NOT emit answer_selected
	# (which would pop the feedback popup) — it only shakes in place.
	var ex := MatchingExercise.new()
	ex.exercise_data = {
		"type": "matching",
		"items": [
			{"left": "L1", "right": "R1"},
			{"left": "L2", "right": "R2"},
			{"left": "L3", "right": "R3"},
		]
	}
	var emitted: Array = []
	ex.answer_selected.connect(func(correct: bool, explanation: String): emitted.append(correct))
	ex._build_ui()
	ex._create_items()

	var left: GrammarButton = ex.left_buttons[0]
	# Pick a right button whose match_value differs from the left button's, so
	# the pair is guaranteed to be wrong.
	var left_match: String = str(left.get_meta("match_value", ""))
	var wrong_right: GrammarButton = null
	for rb in ex.right_buttons:
		if str(rb.get_meta("match_value", "")) != left_match:
			wrong_right = rb
			break
	assert(wrong_right != null, "a non-matching right button should exist")

	ex._select(left, true)
	ex._select(wrong_right, false)
	assert(emitted.is_empty(), "wrong matching pair must not emit answer_selected (no feedback popup)")
	ex.queue_free()
