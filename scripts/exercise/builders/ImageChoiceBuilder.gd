class_name ImageChoiceBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var question := get_en_text(data.raw.get("question", data.raw.get("prompt", "")))
	if question != "":
		parent.add_child(ExerciseTheme.make_label(question, "body_small", "text", true))

	var options: Array = data.raw.get("options", [])

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)

	var group := ButtonGroup.new()
	var option_btns: Array[Button] = []

	for opt in options:
		var b := make_image_option_button(opt, group, gesture_handler)
		option_btns.append(b)
		flow.add_child(b)

	var answer: Variant = data.raw.get("answer", -1)
	if answer is String:
		answer = find_option_index(options, answer)

	var fb := make_feedback(parent)
	var item_data := ExerciseData.Item.new("image_choice", _get_answer_func(option_btns), answer, fb)
	item_data.explanation_en = get_en_text(data.raw.get("explanation", ""))
	item_data.explanation_fa = get_fa_text(data.raw.get("explanation", ""))
	items.append(item_data)

func _get_answer_func(option_btns: Array[Button]) -> Callable:
	return func():
		for i in option_btns.size():
			if option_btns[i].button_pressed:
				return i
		return -1
