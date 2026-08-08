class_name ClozeBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	# Cloze renders its own passage (Engine skips the common passage for this type).
	var p_raw = data.raw.get("passage", "")
	var passage := ExerciseTheme.make_label(get_en_text(p_raw), "body_small", "muted", false)
	passage.set_meta("text_fa", get_fa_text(p_raw))
	parent.add_child(passage)

	var blanks: Array = data.raw.get("blanks", [])
	for i in blanks.size():
		var blank: Dictionary = blanks[i]
		var item_vbox := create_item_container(parent)

		var label := ExerciseTheme.make_label("(%d) ______" % (i + 1), "body_small", "text", true)
		item_vbox.add_child(label)

		var options: Array = blank.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(get_option_text(opt))

		var ob := make_option_dropdown(option_texts, gesture_handler)
		item_vbox.add_child(ob)

		var answer: Variant = resolve_dropdown_answer(blank.get("answer", ""), options, option_texts)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("cloze", get_dropdown_answer_func(ob), answer, fb)
		item_data.explanation_en = get_en_text(blank.get("explanation", ""))
		item_data.explanation_fa = get_fa_text(blank.get("explanation", ""))
		items.append(item_data)
