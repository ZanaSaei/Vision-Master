class_name ErrorCorrectionBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var s_raw = item_dict.get("sentence", item_dict.get("text", ""))
		var sentence_text := get_en_text(s_raw)
		var wrong: String = str(item_dict.get("wrong_word", item_dict.get("target", "")))

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

		var marked := sentence_text
		if wrong != "":
			marked = sentence_text.replace(wrong, "[color=#DC2626][u]" + wrong + "[/u][/color]")
		rtl.text = marked
		item_vbox.add_child(rtl)

		var le := make_line_edit("Type the correction...", gesture_handler)
		item_vbox.add_child(le)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("error_correction", get_line_answer_func(le), item_dict.get("answer", ""), fb)
		item_data.explanation_en = get_en_text(item_dict.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(item_dict.get("explanation", ""))
		items.append(item_data)
