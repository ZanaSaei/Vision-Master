class_name TransformationBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var prompt := ExerciseTheme.make_label(get_item_main_text(item_dict), "body_small", "text", true)
		item_vbox.add_child(prompt)

		var task_raw = item_dict.get("task", "")
		if get_en_text(task_raw) != "":
			var task := ExerciseTheme.make_label("Task: " + get_en_text(task_raw), "hint", "muted", false)
			task.set_meta("text_fa", get_fa_text(task_raw))
			item_vbox.add_child(task)

		var le := make_line_edit("Write your answer...", gesture_handler)
		item_vbox.add_child(le)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("transformation", get_line_answer_func(le), item_dict.get("answer", []), fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		item_data.compiled_patterns = compile_patterns(item_dict.get("answer_patterns", []))
		item_data.required_words = item_dict.get("required_words", [])
		item_data.forbidden_words = item_dict.get("forbidden_words", [])
		items.append(item_data)
