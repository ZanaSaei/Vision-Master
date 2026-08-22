extends Node
# Verifies ExerciseEngine grades the block JSON format used by
# V1_Grammar_All_Lessons.json and emits exercise_checked(correct, total) —
# which the exam page's single "Check All Answers" button relies on.

func _make_engine() -> ExerciseEngine:
	var e := ExerciseEngine.new()
	add_child(e)
	return e

func test_multiple_choice() -> void:
	var block := {
		"type": "multiple_choice",
		"instruction": "Choose the best answer.",
		"items": [
			{"question": "Humans ______ destroy nature.", "options": ["will", "are", "do", "did"], "answer": 0},
			{"question": "She ______ to the museum.", "options": ["go", "goes", "going"], "answer": 1},
		],
	}
	var e := _make_engine()
	e.hide_footer_buttons = true
	var result: Array = []
	e.exercise_checked.connect(func(_id, correct, total): result.append([correct, total]))
	e.build(block)
	e.call("_on_check_pressed")
	var ok: bool = result.size() == 1 and result[0][0] == 0 and result[0][1] == 2
	print("multiple_choice: ", "PASS" if ok else "FAIL", " -> ", result)
	assert(ok, "multiple_choice grading/signal failed")
	e.queue_free()

func test_fill_blank() -> void:
	var block := {
		"type": "fill_blank",
		"instruction": "Complete the sentence.",
		"items": [
			{"text": "I ___ (save) nature.", "answer": ["will save"]},
			{"text": "They ___ (go) home.", "answer": ["will go"]},
			{"text": "We ___ (protect) animals.", "answer": ["will protect"]},
		],
	}
	var e := _make_engine()
	e.hide_footer_buttons = true
	var result: Array = []
	e.exercise_checked.connect(func(_id, correct, total): result.append([correct, total]))
	e.build(block)
	e.call("_on_check_pressed")
	var ok: bool = result.size() == 1 and result[0][0] == 0 and result[0][1] == 3
	print("fill_blank: ", "PASS" if ok else "FAIL", " -> ", result)
	assert(ok, "fill_blank grading/signal failed")
	e.queue_free()

func test_matching() -> void:
	var block := {
		"type": "matching",
		"instruction": "Match column A with column B.",
		"items": [
			{"text": "If people protect nature,", "options": ["animals will not die out.", "It's going to rain."], "answer": "animals will not die out."},
			{"text": "Look at the sky!", "options": ["animals will not die out.", "It's going to rain."], "answer": "It's going to rain."},
		],
	}
	var e := _make_engine()
	e.hide_footer_buttons = true
	var result: Array = []
	e.exercise_checked.connect(func(_id, correct, total): result.append([correct, total]))
	e.build(block)
	e.call("_on_check_pressed")
	var ok: bool = result.size() == 1 and result[0][0] == 0 and result[0][1] == 2
	print("matching: ", "PASS" if ok else "FAIL", " -> ", result)
	assert(ok, "matching grading/signal failed")
	e.queue_free()
