class_name PassiveTransformationBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var active_text: String = get_en_text(item_dict.get("active", item_dict.get("prompt", "")))
		var label := ExerciseTheme.make_label("Active: " + active_text, "body", "text", true)
		item_vbox.add_child(label)

		var hint_text := get_en_text(item_dict.get("hint", "Rewrite in passive voice:"))
		var hint := ExerciseTheme.make_label("Task: " + hint_text, "hint", "muted", false)
		item_vbox.add_child(hint)

		var le := make_line_edit("Type the passive sentence...", gesture_handler)
		item_vbox.add_child(le)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("passive_transformation", get_line_answer_func(le), item_dict.get("answer", []), fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		item_data.compiled_patterns = compile_patterns(item_dict.get("answer_patterns", []))
		item_data.required_words = item_dict.get("required_words", [])
		item_data.forbidden_words = item_dict.get("forbidden_words", [])
		items.append(item_data)
