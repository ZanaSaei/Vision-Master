class_name OpenEndedBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var q := get_item_main_text(item_dict)
		if q != "":
			var q_label := ExerciseTheme.make_label(q, "body_small", "text", false)
			item_vbox.add_child(q_label)

		var te := make_text_edit(gesture_handler)
		item_vbox.add_child(te)

		# Rubric checkboxes
		var rubric: Array = item_dict.get("rubric", data.raw.get("rubric", []))
		for r in rubric:
			var cb := make_checkbox(get_en_text(r), gesture_handler)
			item_vbox.add_child(cb)

		# Optional self-check checkbox
		var default_self_check := str(data.get_type()) == "pronunciation"
		var self_check := bool(item_dict.get("self_check", data.raw.get("self_check", default_self_check)))
		if self_check:
			var done_check := make_checkbox("I practiced this aloud / I completed this.", gesture_handler)
			item_vbox.add_child(done_check)

		# Sample answer (hidden until the Engine reveals it)
		var sample_text := get_en_text(item_dict.get("sample_answer", ""))
		var sample: Label = null
		if sample_text != "":
			sample = ExerciseTheme.make_label("Sample answer: " + sample_text, "body_small", "success", false)
			sample.set_meta("text_fa", get_fa_text(item_dict.get("sample_answer", "")))
			sample.visible = false
			item_vbox.add_child(sample)

		var item_data := ExerciseData.Item.new("open_ended", get_text_edit_answer_func(te), null, null)
		item_data.text_edit = te
		item_data.sample_label = sample
		items.append(item_data)
