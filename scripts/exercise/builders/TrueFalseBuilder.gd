class_name TrueFalseBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var statement := ExerciseTheme.make_label(get_item_main_text(item_dict), "body", "text", false)
		item_vbox.add_child(statement)

		var group := ButtonGroup.new()
		var t_btn := make_select_button("True", group, ExerciseTheme.COLORS.primary, gesture_handler)
		var f_btn := make_select_button("False", group, ExerciseTheme.COLORS.primary, gesture_handler)
		item_vbox.add_child(t_btn)
		item_vbox.add_child(f_btn)

		var ans: Variant = item_dict.get("answer", true)
		if ans is String:
			var s := ExerciseData.normalize(str(ans))
			ans = (s == "true" or s == "t" or s == "yes" or s == "y")

		var corr_raw = item_dict.get("correction", item_dict.get("explanation", ""))
		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new("true_false", _get_answer_func(t_btn, f_btn), ans, fb)
		item_data.explanation_en = get_en_text(corr_raw)
		item_data.explanation_fa = get_fa_text(corr_raw)
		items.append(item_data)

func _get_answer_func(t_btn: Button, f_btn: Button) -> Callable:
	return func():
		if t_btn.button_pressed:
			return true
		if f_btn.button_pressed:
			return false
		return null
