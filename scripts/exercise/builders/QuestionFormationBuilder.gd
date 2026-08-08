class_name QuestionFormationBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var prompt_text: String = get_en_text(item_dict.get("prompt", "Form a question:"))
		var label := ExerciseTheme.make_label(prompt_text, "body", "text", true)
		label.set_meta("text_fa", get_fa_text(item_dict.get("prompt", "")))
		item_vbox.add_child(label)

		var le := make_line_edit("Type your question...", gesture_handler)
		item_vbox.add_child(le)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("question_formation", get_line_answer_func(le), item_dict.get("answer", []), fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		item_data.compiled_patterns = compile_patterns(item_dict.get("answer_patterns", []))
		item_data.required_words = item_dict.get("required_words", [])
		item_data.forbidden_words = item_dict.get("forbidden_words", [])
		items.append(item_data)
