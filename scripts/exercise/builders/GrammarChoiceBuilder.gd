class_name GrammarChoiceBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var sentence: String = get_en_text(item_dict.get("sentence", item_dict.get("text", "")))
		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", ExerciseTheme.FONT_SIZES.body_small)
		rtl.add_theme_color_override("default_color", ExerciseTheme.COLORS.text)
		if ExerciseTheme.font_regular:
			rtl.add_theme_font_override("normal_font", ExerciseTheme.font_regular)
		rtl.text = sentence.replace("___", "[color=#2563EB][u]___[/u][/color]")
		item_vbox.add_child(rtl)

		var options: Array = item_dict.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = maxi(mini(option_texts.size(), 2), 1)
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(grid)

		for opt in option_texts:
			var b := make_select_button(str(opt), group, ExerciseTheme.COLORS.info, gesture_handler)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item_dict.get("answer", -1)
		if answer is String:
			answer = find_option_index(options, answer)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("grammar_choice", _get_answer_func(option_btns), answer, fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		items.append(item_data)

func _get_answer_func(option_btns: Array[Button]) -> Callable:
	return func():
		for i in option_btns.size():
			if option_btns[i].button_pressed:
				return i
		return -1
