class_name OddOneOutBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var words_raw: Array = item_dict.get("words", item_dict.get("options", []))
		var word_texts: Array = []
		for w in words_raw:
			word_texts.append(get_option_text(w))

		var question_text := "Which word does not belong?"
		if item_dict.has("question"):
			question_text = get_en_text(item_dict.get("question", ""))
		var q_label := ExerciseTheme.make_label(question_text, "body_small", "text", true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = 2 if word_texts.size() >= 4 else 1
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(grid)

		for w in word_texts:
			var b := make_select_button(str(w), group, ExerciseTheme.COLORS.warning, gesture_handler)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item_dict.get("answer", -1)
		if answer is String:
			answer = find_option_index(word_texts, answer)

		var answer_display := ""
		if answer is int and answer >= 0 and answer < word_texts.size():
			answer_display = str(word_texts[answer])

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("odd_one_out", _get_answer_func(option_btns), answer, fb)
		item_data.answer_display = answer_display
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		items.append(item_data)

func _get_answer_func(option_btns: Array[Button]) -> Callable:
	return func():
		for i in option_btns.size():
			if option_btns[i].button_pressed:
				return i
		return -1
