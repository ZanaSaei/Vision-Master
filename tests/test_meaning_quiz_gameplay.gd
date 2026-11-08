extends SceneTree

# ============================================================
#  Automated Gameplay & System Test for Meaning Quiz (Wordef)
# ============================================================

func _initialize() -> void:
	print("--- Starting Meaning Quiz Gameplay Tests ---")
	var scene_res := load("res://scenes/word_game/MeaningQuiz.tscn") as PackedScene
	assert(scene_res != null, "MeaningQuiz.tscn must exist and load.")

	var quiz := scene_res.instantiate() as Control
	assert(quiz != null, "MeaningQuiz must instantiate.")
	root.add_child(quiz)
	quiz._ready()

	# 1. Verify selection mode initial state
	assert(quiz.get("_mode") == "book_select", "Initial mode should be book_select")
	print("✓ Initial mode is book_select")

	# 2. Test starting a lesson quiz
	quiz._start_learning(1, 1)
	assert(quiz.get("_mode") == "quiz", "Mode should switch to quiz")
	var questions: Array = quiz.get("_questions")
	assert(questions.size() >= 4, "Must generate at least 4 questions for lesson 1")
	print("✓ Generated %d varied questions for Book 1 Lesson 1" % questions.size())

	# 3. Verify question structure
	var kinds_found: Dictionary = {}
	for i in questions.size():
		var q: Dictionary = questions[i]
		assert(q.has("kind"), "Question must have kind")
		assert(q.has("correct_answer"), "Question must have correct_answer")
		assert(q.has("options"), "Question must have options")
		var options: Array = q["options"]
		assert(options.size() == 4, "Each question must have 4 options")
		assert(options.has(q["correct_answer"]), "Options must include correct answer")

		# Check uniqueness of options
		var unique_set: Dictionary = {}
		for opt in options:
			unique_set[str(opt)] = true
		assert(unique_set.size() == 4, "All 4 options must be distinct")

		kinds_found[str(q["kind"])] = true

	print("✓ Question varieties present in lesson: %s" % str(kinds_found.keys()))

	# 4. Simulate a correct answer on Question 0
	var current_q: Dictionary = questions[0]
	var correct_ans: String = str(current_q["correct_answer"])
	var score_before: int = int(quiz.get("_score"))
	var streak_before: int = int(quiz.get("_streak"))

	var dummy_btn := Button.new()
	quiz.add_child(dummy_btn)
	quiz._on_option_selected(dummy_btn, correct_ans, current_q)

	var score_after: int = int(quiz.get("_score"))
	var streak_after: int = int(quiz.get("_streak"))
	assert(score_after > score_before, "Score must increase on correct answer")
	assert(streak_after == streak_before + 1, "Streak must increment on correct answer")
	print("✓ Correct answer awarded %d points; streak is now %d" % [score_after - score_before, streak_after])

	# 5. Simulate a wrong answer on Question 1
	var q1: Dictionary = questions[1]
	var wrong_ans := ""
	for opt in q1["options"]:
		if str(opt) != str(q1["correct_answer"]):
			wrong_ans = str(opt)
			break

	var dummy_btn_wrong := Button.new()
	quiz.add_child(dummy_btn_wrong)
	quiz._busy = false # reset busy for the test
	quiz._on_option_selected(dummy_btn_wrong, wrong_ans, q1)

	var streak_after_wrong: int = int(quiz.get("_streak"))
	assert(streak_after_wrong == 0, "Streak must reset to 0 on wrong answer")
	assert(dummy_btn_wrong.disabled == true, "Wrong button must be disabled")
	print("✓ Wrong answer reset streak to 0 and disabled button")

	# 6. Test results screen
	quiz._question_index = questions.size()
	quiz._show_result()
	assert(quiz.get("_mode") == "result", "Mode should be result")
	print("✓ Results screen opened smoothly with celebration")

	dummy_btn.queue_free()
	dummy_btn_wrong.queue_free()
	quiz.queue_free()
	print("--- All Meaning Quiz tests passed successfully! ---")
	quit()
