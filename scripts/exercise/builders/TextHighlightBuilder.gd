class_name TextHighlightBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var p_raw = data.raw.get("passage", "")
	var passage_text := get_en_text(p_raw)
	var words: PackedStringArray = passage_text.split(" ", false)
	var answer_indices: Array = data.raw.get("answer_indices", [])

	var hint := ExerciseTheme.make_label("Tap the words that match the instruction above.", "hint", "muted", false)
	parent.add_child(hint)

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)

	for i in words.size():
		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 0)
		flow.add_child(pair)

		var wb := make_word_toggle(words[i], gesture_handler)
		pair.add_child(wb)

		var fb := Label.new()
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.tiny)
		fb.visible = false
		pair.add_child(fb)

		var is_target: bool = answer_indices.has(i)
		var item_data := ExerciseData.Item.new("text_highlight", _get_toggle_func(wb), is_target, fb)
		items.append(item_data)

func _get_toggle_func(wb: Button) -> Callable:
	return func(): return wb.button_pressed
