class_name CategorizeBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var categories: Array = data.raw.get("categories", [])
	var category_texts: Array = []
	for cat in categories:
		category_texts.append(get_option_text(cat))

	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var text := ExerciseTheme.make_label(get_item_main_text(item_dict), "body_small", "text", false)
		item_vbox.add_child(text)

		var ob := make_option_dropdown(category_texts, gesture_handler, "Category")
		item_vbox.add_child(ob)

		var answer: Variant = resolve_dropdown_answer(item_dict.get("answer", ""), categories, category_texts)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("categorize", get_dropdown_answer_func(ob), answer, fb)
		items.append(item_data)
