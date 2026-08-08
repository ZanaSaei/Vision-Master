class_name WordBankBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var bank: Array = data.raw.get("word_bank", [])
	var bank_texts: Array = []
	for w in bank:
		bank_texts.append(get_option_text(w))

	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var text := ExerciseTheme.make_label(get_item_main_text(item_dict), "body_small", "text", false)
		item_vbox.add_child(text)

		var ob := make_option_dropdown(bank_texts, gesture_handler, "Choose a word")
		item_vbox.add_child(ob)

		var answer: Variant = resolve_dropdown_answer(item_dict.get("answer", ""), bank, bank_texts)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("word_bank", get_dropdown_answer_func(ob), answer, fb)
		items.append(item_data)
