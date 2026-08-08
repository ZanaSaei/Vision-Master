class_name TokenLabelBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var default_labels: Array = data.raw.get("labels", [])
	if default_labels.is_empty():
		default_labels = ["S", "O", "V", "Adv"]

	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var inst := get_en_text(item_dict.get("instruction", ""))
		if inst != "":
			item_vbox.add_child(ExerciseTheme.make_label(inst, "hint", "muted", false))

		var labels_raw: Array = item_dict.get("labels", default_labels)
		var categories := normalize_categories(labels_raw)
		var label_ids: Array = []
		var label_names: Array = []
		for c in categories:
			label_ids.append(str(c["id"]))
			label_names.append(str(c["label"]))

		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 12)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(flow)

		var tokens: Array = item_dict.get("tokens", [])
		var token_answers: Array = item_dict.get("answers", [])

		for t_i in tokens.size():
			var token = tokens[t_i]
			var token_box := VBoxContainer.new()
			token_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			token_box.add_theme_constant_override("separation", 4)
			token_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			flow.add_child(token_box)

			var token_text := ""
			var ans := ""
			var expl_en := ""
			var expl_fa := ""
			if token is Dictionary:
				token_text = get_en_text(token.get("text", token.get("word", "")))
				ans = category_id_from_value(token.get("answer", ""), categories)
				expl_en = get_en_text(token.get("explanation", ""))
				expl_fa = get_fa_text(token.get("explanation", ""))
			else:
				token_text = get_en_text(token)
				if t_i < token_answers.size():
					ans = category_id_from_value(token_answers[t_i], categories)

			var word_label := ExerciseTheme.make_label(token_text, "body", "text", true)
			token_box.add_child(word_label)

			var ob := OptionButton.new()
			ob.mouse_filter = Control.MOUSE_FILTER_PASS
			ob.add_item("—")
			for lname in label_names:
				ob.add_item(lname)
			ob.selected = 0
			ob.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.tiny)
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if ExerciseTheme.font_regular:
				ob.add_theme_font_override("font", ExerciseTheme.font_regular)
			token_box.add_child(ob)
			gesture_handler.register_control(ob)

			var fb := make_feedback(token_box)
			var ids := label_ids.duplicate()
			var item_data := ExerciseData.Item.new("token_label", _get_token_answer_func(ob, ids), ans, fb)
			item_data.explanation_en = expl_en
			item_data.explanation_fa = expl_fa
			items.append(item_data)

func _get_token_answer_func(ob: OptionButton, ids: Array) -> Callable:
	return func():
		if ob.selected > 0 and ob.selected - 1 < ids.size():
			return ids[ob.selected - 1]
		return ""
