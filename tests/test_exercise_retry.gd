extends Node
# ============================================================
# Phase A regression tests: "Try Again" resets the existing exercise
# controls in place, WITHOUT calling build() again.
#
# These tests instantiate a real ExerciseEngine, answer it, grade it, then
# drive the retry path (_on_check_pressed when already graded) and assert that
# the answers/selections/inputs return to their initial state and that transient
# grading presentation (feedback labels, score banner, inline cloze colours) is
# cleared — while the UI tree itself is not rebuilt.
# ============================================================

func _new_engine(exercise: Dictionary) -> ExerciseEngine:
	var e := ExerciseEngine.new()
	add_child(e)
	e.build(exercise)
	return e

func _collect(root: Node, predicate: Callable, out: Array) -> Array:
	if predicate.call(root):
		out.append(root)
	for c in root.get_children():
		_collect(c, predicate, out)
	return out

func _toggle_buttons(root: Node) -> Array:
	return _collect(root, func(n: Node) -> bool: return n is Button and not (n is ExerciseDropdown) and (n as Button).toggle_mode, [])

func _line_edits(root: Node) -> Array:
	return _collect(root, func(n: Node) -> bool: return n is LineEdit, [])

func _dropdowns(root: Node) -> Array:
	return _collect(root, func(n: Node) -> bool: return n is ExerciseDropdown, [])

func _buttons_with_text(root: Node, label: String) -> Array:
	return _collect(root, func(n: Node) -> bool: return n is Button and (n as Button).text == label, [])


# ------------------------------------------------------------
# multiple_choice
# ------------------------------------------------------------
func test_multiple_choice_retry_resets_selection() -> void:
	var ex := {
		"type": "multiple_choice",
		"exercise_id": "t_mc",
		"items": [{"question": "Pick one", "options": ["a", "b", "c"], "answer": 1}],
	}
	var e := _new_engine(ex)
	var btns := _toggle_buttons(e)
	assert(btns.size() == 3, "expected 3 option buttons, got %d" % btns.size())

	(btns[1] as Button).button_pressed = true
	assert(int(e._items[0]["get"].call()) == 1, "answer should read option 1 before grading")

	e.grade_all()
	assert(e._is_graded, "engine should be graded after grade_all()")
	assert(e._score_banner != null and e._score_banner.visible, "score banner visible after grading")
	var fb: Label = e._items[0]["feedback"]
	assert(fb.visible, "feedback label visible after grading")

	# Try Again path.
	e._on_check_pressed()
	assert(not e._is_graded, "engine not graded after retry")
	assert(int(e._items[0]["get"].call()) == -1, "selection cleared after retry")
	for b in btns:
		assert(not (b as Button).button_pressed, "no option button stays pressed after retry")
	assert(not fb.visible, "feedback label hidden after retry")
	assert(e._score_banner != null and not e._score_banner.visible, "score banner hidden after retry")
	assert(e._check_btn.text == e._t("check_answer"), "Check button restored to Check Answer")


# ------------------------------------------------------------
# fill_blank
# ------------------------------------------------------------
func test_fill_blank_retry_clears_input() -> void:
	var ex := {
		"type": "fill_blank",
		"exercise_id": "t_fb",
		"items": [{"text": "I ___ home.", "answer": ["go"]}],
	}
	var e := _new_engine(ex)
	var edits := _line_edits(e)
	assert(edits.size() == 1, "expected one LineEdit")
	(edits[0] as LineEdit).text = "go"
	e.grade_all()
	e._on_check_pressed()
	assert((edits[0] as LineEdit).text == "", "line edit cleared after retry")


# ------------------------------------------------------------
# cloze
# ------------------------------------------------------------
func test_cloze_retry_clears_choices_and_grading() -> void:
	var ex := {
		"type": "cloze",
		"exercise_id": "t_cloze",
		"passage": "I (1) ______ to school and (2) ______ books.",
		"blanks": [
			{"options": ["go", "goes"], "answer": 0},
			{"options": ["read", "reads"], "answer": 0},
		],
	}
	var e := _new_engine(ex)
	assert(e._cloze_choices.size() == 2, "expected 2 cloze blanks")
	e._cloze_choices[0] = "go"
	e._cloze_choices[1] = "read"
	e.grade_all()
	assert(e._cloze_graded_all, "cloze graded after grade_all()")
	e._on_check_pressed()
	assert(not e._cloze_graded_all, "cloze grading flag cleared after retry")
	for c in e._cloze_choices:
		assert(str(c) == "", "every cloze blank cleared after retry")
	for g in e._cloze_graded:
		assert(not bool(g), "every cloze graded flag cleared after retry")


# ------------------------------------------------------------
# ordering
# ------------------------------------------------------------
func test_ordering_retry_restores_original_order() -> void:
	var ex := {
		"type": "ordering",
		"exercise_id": "t_ord",
		"items": [{"text": "First"}, {"text": "Second"}, {"text": "Third"}],
		"answer_order": [0, 1, 2],
	}
	var e := _new_engine(ex)
	assert(e._items[0]["get"].call() == [0, 1, 2], "ordering starts in source order")

	# Press the first down-arrow to move item 0 down one slot.
	var downs := _buttons_with_text(e, "↓")
	assert(downs.size() == 3, "expected three down arrows")
	(downs[0] as Button).pressed.emit()
	assert(e._items[0]["get"].call() == [1, 0, 2], "arrow reorders the list")

	e.grade_all()
	e._on_check_pressed()
	assert(e._items[0]["get"].call() == [0, 1, 2], "retry restores the original order")


# ------------------------------------------------------------
# matching (custom dropdown)
# ------------------------------------------------------------
func test_matching_retry_resets_dropdown() -> void:
	var ex := {
		"type": "matching",
		"exercise_id": "t_match",
		"options": ["A", "B"],
		"items": [{"text": "q", "answer": 0}],
	}
	var e := _new_engine(ex)
	var dds := _dropdowns(e)
	assert(dds.size() == 1, "expected one dropdown")
	var dd: ExerciseDropdown = dds[0]
	dd.selected = 1
	assert(str(e._items[0]["get"].call()) == "A", "dropdown answer reads selected item")
	e.grade_all()
	e._on_check_pressed()
	assert(dd.selected == 0, "dropdown reset to placeholder after retry")
	assert(str(e._items[0]["get"].call()) == "", "dropdown answer empty after retry")


# ------------------------------------------------------------
# text_highlight (word toggles)
# ------------------------------------------------------------
func test_text_highlight_retry_clears_word_toggles() -> void:
	var ex := {
		"type": "text_highlight",
		"exercise_id": "t_th",
		"passage": "the cat sat",
		"answer_indices": [0],
	}
	var e := _new_engine(ex)
	var btns := _toggle_buttons(e)
	assert(btns.size() == 3, "expected three word toggles")
	(btns[0] as Button).button_pressed = true
	e.grade_all()
	e._on_check_pressed()
	for b in btns:
		assert(not (b as Button).button_pressed, "word toggle cleared after retry")


# ------------------------------------------------------------
# The UI tree must NOT be rebuilt by a retry.
# ------------------------------------------------------------
func test_retry_preserves_ui_tree() -> void:
	var ex := {
		"type": "multiple_choice",
		"exercise_id": "t_tree",
		"items": [{"question": "Pick one", "options": ["a", "b"], "answer": 0}],
	}
	var e := _new_engine(ex)
	var before := _toggle_buttons(e)
	assert(before.size() == 2)
	e.grade_all()
	e._on_check_pressed()
	var after := _toggle_buttons(e)
	assert(after.size() == before.size(), "button count unchanged after retry")
	for i in before.size():
		assert(is_same(before[i], after[i]), "the same Button instance survives a retry (no rebuild)")