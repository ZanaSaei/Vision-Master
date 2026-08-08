class_name MatchingBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var exercise_options: Array = data.raw.get("options", [])

	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var text := ExerciseTheme.make_label(get_item_main_text(item_dict), "body_small", "text", false)
		item_vbox.add_child(text)

		var options: Array = item_dict.get("options", exercise_options)
		var option_texts: Array = []
		for opt in options:
			option_texts.append(get_option_text(opt))

		var ob := make_option_dropdown(option_texts, gesture_handler)
		item_vbox.add_child(ob)

		var answer: Variant = item_dict.get("answer", "")
		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = get_option_text(opt)
					break

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("matching", _get_answer_func(ob), answer, fb)
		items.append(item_data)

func _get_answer_func(ob: ExerciseDropdown) -> Callable:
	return func():
		if ob.selected > 0:
			return ob.get_item_text(ob.selected)
		return ""
