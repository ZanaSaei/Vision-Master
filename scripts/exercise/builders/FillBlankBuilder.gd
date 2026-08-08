class_name FillBlankBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var text := ExerciseTheme.make_label(get_item_main_text(item_dict), "body_small", "text", false)
		item_vbox.add_child(text)

		var hint := get_en_text(item_dict.get("hint", ""))
		if hint != "":
			item_vbox.add_child(ExerciseTheme.make_label("Hint: " + hint, "hint", "muted", false))

		var le := make_line_edit("Type your answer...", gesture_handler)
		item_vbox.add_child(le)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("fill_blank", _get_answer_func(le), item_dict.get("answer", []), fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		item_data.compiled_patterns = compile_patterns(item_dict.get("answer_patterns", []))
		item_data.required_words = item_dict.get("required_words", [])
		item_data.forbidden_words = item_dict.get("forbidden_words", [])
		items.append(item_data)

func _get_answer_func(le: LineEdit) -> Callable:
	return func(): return le.text
