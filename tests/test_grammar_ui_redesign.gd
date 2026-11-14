extends Node
# ============================================================
#  TEST SUITE: Grammar UI & UX Redesign Verification
# ============================================================

func _ready() -> void:
	print("--- Starting Grammar UI/UX Redesign Test Suite ---")

	_test_theme_factories()
	_test_learning_unit_view()
	_test_multiple_choice_exercise()
	_test_fill_blank_exercise()
	_test_true_false_exercise()
	_test_matching_exercise()
	_test_unscramble_exercise()
	_test_feedback_bottom_sheet()
	_test_reward_popup()

	print("--- ALL GRAMMAR UI/UX REDESIGN TESTS PASSED SUCCESSFULLY! ---")


func _test_theme_factories() -> void:
	print("Testing GrammarTheme helpers...")
	var speaker := GrammarTheme.make_speaker_button("I will study English.")
	assert(speaker != null, "Speaker button must be created")
	assert(speaker.custom_minimum_size.x > 0, "Speaker button has minimum size")
	speaker.queue_free()

	var badge := GrammarTheme.make_badge("Test Badge", Color.BLUE, Color.WHITE, 24)
	assert(badge != null, "Badge panel must be created")
	badge.queue_free()

	var bottom_sheet_sb := GrammarTheme.bottom_sheet_style(Color.GREEN)
	assert(bottom_sheet_sb.corner_radius_top_left == 32, "Bottom sheet has rounded top left")
	assert(bottom_sheet_sb.corner_radius_top_right == 32, "Bottom sheet has rounded top right")
	assert(bottom_sheet_sb.corner_radius_bottom_left == 0, "Bottom sheet has flat bottom left")
	print("PASS  GrammarTheme factories verified")


func _test_learning_unit_view() -> void:
	print("Testing LearningUnitView...")
	var container := VBoxContainer.new()
	add_child(container)

	var sample_unit := {
		"title_fa": "آینده ساده با Will",
		"title_en": "Simple Future with Will",
		"explanation": "برای صحبت درباره آینده از will استفاده می‌کنیم.",
		"structure": "subject + will + base verb",
		"cards": [
			{"en": "I will help you.", "fa": "من به تو کمک خواهم کرد."},
			{"en": "They will travel tomorrow.", "fa": "آن‌ها فردا سفر خواهند کرد."}
		]
	}

	LearningUnitView.render(container, sample_unit)
	assert(container.get_child_count() > 0, "Container should have rendered content cards")

	# Check formula chips presence
	var found_formula_card := false
	for child in container.get_children():
		if child is PanelContainer:
			found_formula_card = true
			break
	assert(found_formula_card, "Formula or explanation cards rendered")

	container.queue_free()
	print("PASS  LearningUnitView rendering verified")


func _test_multiple_choice_exercise() -> void:
	print("Testing MultipleChoiceExercise...")
	var mc := MultipleChoiceExercise.new()
	add_child(mc)

	var sample_data := {
		"instruction_fa": "گزینه درست را انتخاب کن.",
		"questions": [
			{
				"question": "I ______ help you.",
				"options": ["will", "am", "have", "do"],
				"correct": 0,
				"explanation_fa": "will درست است."
			}
		]
	}

	mc.setup(sample_data)
	assert(mc.get_item_count() == 1, "Question count should be 1")
	assert(mc.question_label.text.contains("help"), "Question label must be set")
	assert(mc._option_buttons.size() == 4, "Should have 4 option buttons")
	assert(mc._option_buttons[0].text.begins_with("A."), "First option button should have A. prefix")
	assert(mc._option_buttons[1].text.begins_with("B."), "Second option button should have B. prefix")

	# Simulate choosing the correct answer
	var answered_signal_fired := false
	var signal_correct := false
	mc.answer_selected.connect(func(correct: bool, _exp: String) -> void:
		answered_signal_fired = true
		signal_correct = correct
	)

	mc._on_answer_pressed(mc._option_buttons[0])
	assert(answered_signal_fired, "answer_selected signal should fire")
	assert(signal_correct, "Answer should be correct")

	mc.queue_free()
	print("PASS  MultipleChoiceExercise verified")


func _test_fill_blank_exercise() -> void:
	print("Testing FillBlankExercise...")
	var fb := FillBlankExercise.new()
	add_child(fb)

	var sample_data := {
		"instruction_fa": "جای خالی را پر کن.",
		"items": [
			{
				"text": "She ______ a book.",
				"answers": ["will read", "will be reading"],
				"explanation_fa": "will read درست است."
			}
		]
	}

	fb.setup(sample_data)
	assert(fb.get_item_count() == 1, "Item count should be 1")
	assert(fb.input != null, "Input box exists")
	assert(fb.chips_container != null, "Chips container exists")

	# Test live in-sentence preview
	fb.input.text = "will read"
	fb._on_input_text_changed("will read")
	assert(fb.prompt_label.text.contains("will read"), "Live preview updates dynamically in prompt")

	var fb_correct := false
	fb.answer_selected.connect(func(correct: bool, _exp: String) -> void:
		fb_correct = correct
	)
	fb._check_answer()
	assert(fb_correct, "Typed answer 'will read' should be evaluated as correct")

	fb.queue_free()
	print("PASS  FillBlankExercise verified")


func _test_true_false_exercise() -> void:
	print("Testing TrueFalseExercise...")
	var tf := TrueFalseExercise.new()
	add_child(tf)

	var sample_data := {
		"instruction_fa": "درست یا غلط بودن را مشخص کن.",
		"items": [
			{
				"statement": "We will gone tomorrow.",
				"correct": false,
				"explanation_fa": "بعد از will باید شکل ساده فعل بیاید."
			}
		]
	}

	tf.setup(sample_data)
	assert(tf.true_button != null, "True button exists")
	assert(tf.false_button != null, "False button exists")

	var tf_correct := false
	tf.answer_selected.connect(func(correct: bool, _exp: String) -> void:
		tf_correct = correct
	)

	# Learner selects False (which is the correct evaluation of the incorrect sentence)
	tf._answer(false)
	assert(tf_correct, "Selecting False should be correct for an ungrammatical sentence")

	tf.queue_free()
	print("PASS  TrueFalseExercise verified")


func _test_matching_exercise() -> void:
	print("Testing MatchingExercise...")
	var match_ex := MatchingExercise.new()
	add_child(match_ex)

	var sample_data := {
		"instruction_fa": "جفت‌ها را متصل کن.",
		"items": [
			{"left": "I will", "right": "I'll"},
			{"left": "You will", "right": "You'll"}
		]
	}

	match_ex.setup(sample_data)
	assert(match_ex.left_buttons.size() == 2, "2 left buttons")
	assert(match_ex.right_buttons.size() == 2, "2 right buttons")

	# Select left button 0
	match_ex._select(match_ex.left_buttons[0], true)
	assert(match_ex.selected_left == match_ex.left_buttons[0], "Left button selected")

	# Find matching right button and select it
	var target_val: String = str(match_ex.left_buttons[0].get_meta("match_value"))
	var matching_right: GrammarButton = null
	for r_btn in match_ex.right_buttons:
		if str(r_btn.get_meta("match_value")) == target_val:
			matching_right = r_btn
			break
	assert(matching_right != null, "Matching right button exists")

	match_ex._select(matching_right, false)
	assert(match_ex.matched == 1, "One pair matched")

	match_ex.queue_free()
	print("PASS  MatchingExercise verified")


func _test_unscramble_exercise() -> void:
	print("Testing UnscrambleExercise...")
	var unscramble := UnscrambleExercise.new()
	add_child(unscramble)

	var sample_data := {
		"instruction_fa": "کلمات را مرتب کن.",
		"items": [
			{
				"words": ["I", "will", "go"],
				"answer": "I will go",
				"hint_fa": "I will go"
			}
		]
	}

	unscramble.setup(sample_data)
	assert(unscramble.words_container.get_child_count() == 3, "Word bank has 3 words")
	assert(unscramble.speaker_button != null, "Speaker button exists on tray")

	# Select words in order
	for target_word in ["I", "will", "go"]:
		for child in unscramble.words_container.get_children():
			if child is GrammarButton and child.text == target_word and not child.disabled:
				unscramble._select_word(child, target_word)
				break

	assert(unscramble.selected_words.size() == 3, "All 3 words selected into tray")
	assert(unscramble._assembled_sentence == "I will go", "Assembled sentence is correct")

	var unscramble_correct := false
	unscramble.answer_selected.connect(func(correct: bool, _exp: String) -> void:
		unscramble_correct = correct
	)
	unscramble._check_answer()
	assert(unscramble_correct, "Unscramble sentence should evaluate to correct")

	unscramble.queue_free()
	print("PASS  UnscrambleExercise verified")


func _test_feedback_bottom_sheet() -> void:
	print("Testing FeedbackPopup Bottom Sheet...")
	var popup := FeedbackPopup.new()
	add_child(popup)

	assert(popup._sheet != null, "Bottom sheet exists")
	assert(popup._sheet.anchor_top == 1.0, "Anchored to bottom")

	popup.show_correct("توضیحات درست")
	assert(popup.visible, "Popup is visible")
	assert(popup.is_correct, "is_correct is true")

	popup.show_wrong("توضیحات غلط")
	assert(not popup.is_correct, "is_correct is false")

	popup.queue_free()
	print("PASS  FeedbackPopup Bottom Sheet verified")


func _test_reward_popup() -> void:
	print("Testing RewardPopup...")
	var reward := RewardPopup.new()
	add_child(reward)

	reward.show_reward("بخش کامل شد", 10, "ادامه", true, 5)
	assert(reward.visible, "Reward popup is visible")
	assert(reward.bonus_label.visible, "Bonus label is visible when bonus_xp > 0")

	reward.queue_free()
	print("PASS  RewardPopup verified")
