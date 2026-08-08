class_name WordBuildingBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var options: Array = data.raw.get("options", [])
	var option_texts: Array = []
	for opt in options:
		option_texts.append(get_option_text(opt))

	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", ExerciseTheme.SPACING.tight)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(row)

		var prefix_label := ExerciseTheme.make_label(get_en_text(item_dict.get("prefix", "")) + "  +", "title", "text", true)
		row.add_child(prefix_label)

		var ob := make_option_dropdown(option_texts, gesture_handler)
		row.add_child(ob)

		var answer: Variant = resolve_dropdown_answer(item_dict.get("answer", ""), options, option_texts)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("word_building", get_dropdown_answer_func(ob), answer, fb)
		items.append(item_data)
