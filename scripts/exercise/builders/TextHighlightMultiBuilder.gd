class_name TextHighlightMultiBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var categories := normalize_categories(data.raw.get("categories", []))
	if categories.is_empty():
		categories = normalize_categories(["A", "B"])

	var passage_text := get_en_text(data.raw.get("passage", data.raw.get("reading", "")))

	var tokens: Array = []
	if data.raw.has("tokens"):
		for t in data.raw.get("tokens", []):
			tokens.append(get_option_text(t))
	else:
		tokens = Array(passage_text.split(" ", false))

	# Legend showing category colors
	var legend := HFlowContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 8)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(legend)

	for c in categories:
		var chip := ExerciseTheme.make_label(str(c["label"]), "tiny", "text", true)
		chip.add_theme_color_override("font_color", c["color"])
		legend.add_child(chip)

	var hint := ExerciseTheme.make_label("Tap a word to change its label. Tap again to cycle.", "hint", "muted", false)
	parent.add_child(hint)

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)

	var selected_cat: Array = []
	var buttons: Array = []
	for i in tokens.size():
		selected_cat.append("")

	# Parse the answer map (index → category id)
	var answer_map: Dictionary = {}
	var ans_raw: Variant = data.raw.get("answer_indices", data.raw.get("answers", {}))
	if ans_raw is Array:
		for i in ans_raw.size():
			var cat_id := category_id_from_value(ans_raw[i], categories)
			if cat_id != "":
				answer_map[i] = cat_id
	elif ans_raw is Dictionary:
		for k in ans_raw:
			var idx := int(str(k))
			answer_map[idx] = category_id_from_value(ans_raw[k], categories)

	for i in tokens.size():
		var idx := i
		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 0)
		flow.add_child(pair)

		var wb := Button.new()
		wb.mouse_filter = Control.MOUSE_FILTER_PASS
		wb.text = str(tokens[idx])
		wb.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.body)
		if ExerciseTheme.font_regular:
			wb.add_theme_font_override("font", ExerciseTheme.font_regular)
		_update_multi_word_style(wb, "", categories)
		pair.add_child(wb)
		buttons.append(wb)
		gesture_handler.register_control(wb)
		wb.pressed.connect(_on_multi_word_pressed.bind(idx, buttons, selected_cat, categories))

		var fb := Label.new()
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.tiny)
		fb.visible = false
		pair.add_child(fb)

		var item_data := ExerciseData.Item.new(
			"text_highlight_multi",
			func(): return str(selected_cat[idx]),
			str(answer_map.get(idx, "")),
			fb
		)
		items.append(item_data)

func _on_multi_word_pressed(idx: int, buttons: Array, selected_cat: Array, categories: Array) -> void:
	if categories.is_empty():
		return
	var current := -1
	for i in categories.size():
		if str(categories[i]["id"]) == str(selected_cat[idx]):
			current = i
			break
	var next := current + 1
	if next >= categories.size():
		selected_cat[idx] = ""
	else:
		selected_cat[idx] = str(categories[next]["id"])
	_update_multi_word_style(buttons[idx], str(selected_cat[idx]), categories)

func _update_multi_word_style(btn: Button, cat_id: String, categories: Array) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	if cat_id == "":
		style.bg_color = Color(1, 1, 1, 0)
		style.border_width_bottom = 1
		style.border_color = Color("#CBD5E1")
	else:
		var col := get_category_color(cat_id, categories)
		style.bg_color = Color(col.r, col.g, col.b, 0.22)
		style.border_width_bottom = 3
		style.border_color = col
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
