class_name GrammarIdentificationBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var text_val: String = get_en_text(item_dict.get("text", item_dict.get("sentence", "")))
		var target: String = str(item_dict.get("target", ""))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", ExerciseTheme.FONT_SIZES.body)
		rtl.add_theme_color_override("default_color", ExerciseTheme.COLORS.text)
		if ExerciseTheme.font_regular:
			rtl.add_theme_font_override("normal_font", ExerciseTheme.font_regular)
		var highlighted := text_val
		if target != "":
			highlighted = text_val.replace(target, "[color=#DC2626][u]" + target + "[/u][/color]")
		rtl.text = highlighted
		item_vbox.add_child(rtl)

		var question := ExerciseTheme.make_label(
			"What is the grammatical form of the underlined word or phrase?",
			"hint", "muted", false
		)
		item_vbox.add_child(question)

		var options: Array = item_dict.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		for opt in option_texts:
			var b := make_select_button(str(opt), group, ExerciseTheme.COLORS.purple, gesture_handler)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = item_dict.get("answer", -1)
		if answer is String:
			answer = find_option_index(options, answer)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("grammar_identification", _get_answer_func(option_btns), answer, fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		items.append(item_data)

func _get_answer_func(option_btns: Array[Button]) -> Callable:
	return func():
		for i in option_btns.size():
			if option_btns[i].button_pressed:
				return i
		return -1
