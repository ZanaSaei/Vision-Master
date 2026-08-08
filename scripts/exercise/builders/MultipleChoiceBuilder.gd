class_name MultipleChoiceBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var q_label := ExerciseTheme.make_label(get_item_main_text(item_dict), "title", "text", true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var options: Array = item_dict.get("options", [])

		for opt in options:
			var b := make_select_button(get_option_text(opt), group, ExerciseTheme.COLORS.primary, gesture_handler)
			option_btns.append(b)
			item_vbox.add_child(b)

		# Resolve the correct answer to an index
		var raw_answer: Variant = item_dict.get("answer", -1)
		var answer_index := _resolve_answer_index(raw_answer, options)

		# Build the display text from the resolved index
		var answer_display := ""
		if answer_index >= 0 and answer_index < options.size():
			answer_display = get_option_text(options[answer_index])

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("multiple_choice", _get_answer_func(option_btns), answer_index, fb)
		item_data.answer_display = answer_display
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		items.append(item_data)

# Resolves the answer (int, float, or string) to a valid option index.
func _resolve_answer_index(raw_answer: Variant, options: Array) -> int:
	if raw_answer is int:
		return raw_answer
	elif raw_answer is float:
		return int(raw_answer)
	elif raw_answer is String:
		return find_option_index(options, raw_answer)
	return -1

func _get_answer_func(option_btns: Array[Button]) -> Callable:
	return func():
		for i in option_btns.size():
			if option_btns[i].button_pressed:
				return i
		return -1
