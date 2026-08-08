class_name LetterScrambleBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var scrambled: String = str(item_dict.get("scrambled", ""))
		var spaced := ""
		for i in scrambled.length():
			spaced += scrambled[i].to_upper()
			if i < scrambled.length() - 1:
				spaced += "  "

		var label := ExerciseTheme.make_label(spaced, "title", "primary", true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(label)

		var hint_raw = item_dict.get("hint", "")
		if get_en_text(hint_raw) != "":
			var hint := ExerciseTheme.make_label("Hint: " + get_en_text(hint_raw), "hint", "muted", false)
			hint.set_meta("text_fa", get_fa_text(hint_raw))
			item_vbox.add_child(hint)

		var le := make_line_edit("Type the word...", gesture_handler)
		item_vbox.add_child(le)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("letter_scramble", _get_answer_func(le), item_dict.get("answer", ""), fb)
		items.append(item_data)

func _get_answer_func(le: LineEdit) -> Callable:
	return func(): return le.text
