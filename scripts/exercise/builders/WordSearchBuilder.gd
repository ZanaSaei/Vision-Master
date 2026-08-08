class_name WordSearchBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var word_list: Array = data.raw.get("words", [])
	var correct_words := _get_correct_words(data, word_list)

	if word_list.is_empty():
		parent.add_child(ExerciseTheme.make_label("No words were provided for this word search.", "hint", "muted", false))
		return

	parent.add_child(ExerciseTheme.make_label("Tap the words:", "hint", "muted", true))

	var words_flow := HFlowContainer.new()
	words_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words_flow.add_theme_constant_override("h_separation", 14)
	words_flow.add_theme_constant_override("v_separation", 14)
	words_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(words_flow)

	for w in word_list:
		var word_text := get_option_text(w)
		if word_text == "":
			continue

		var wb := Button.new()
		wb.mouse_filter = Control.MOUSE_FILTER_PASS
		wb.text = word_text
		wb.toggle_mode = true
		wb.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.hint)
		wb.custom_minimum_size = Vector2(0, 64)
		wb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		wb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if ExerciseTheme.font_regular:
			wb.add_theme_font_override("font", ExerciseTheme.font_regular)
		_style_word_button(wb, "idle")
		wb.toggled.connect(_on_word_toggled.bind(wb))
		gesture_handler.register_control(wb)
		words_flow.add_child(wb)

		var is_correct := _is_word_correct(word_text, correct_words)
		var item_data := ExerciseData.Item.new("word_search_word", _get_toggle_func(wb), is_correct, null)
		item_data.word_button = wb
		items.append(item_data)

# ---------- Custom Grading Override ----------

func handles_custom_grading() -> bool:
	return true

func grade_custom(items: Array[ExerciseData.Item]) -> ExerciseGrader.Result:
	var result := ExerciseGrader.Result.new()
	var correct_total := 0
	var correct_selected := 0
	var wrong_selected := 0

	for item in items:
		if str(item.type) != "word_search_word":
			continue
		var btn: Button = item.word_button
		if btn == null:
			continue

		var is_correct: bool = bool(item.answer)
		var is_selected: bool = btn.button_pressed
		btn.disabled = true

		if is_correct:
			correct_total += 1
			if is_selected:
				correct_selected += 1
			_style_word_button(btn, "correct")
		else:
			if is_selected:
				wrong_selected += 1
				_style_word_button(btn, "wrong")
			else:
				_style_word_button(btn, "idle")

	result.correct_count = correct_selected
	result.total_count = correct_total

	if correct_total == 0:
		result.feedback_text = "No correct words were defined for this exercise."
		result.feedback_color = ExerciseTheme.COLORS.warning
	elif correct_selected == correct_total and wrong_selected == 0:
		result.feedback_text = "Excellent! All correct words chosen!"
		result.feedback_color = ExerciseTheme.COLORS.success
	elif wrong_selected > 0:
		result.feedback_text = "You chose %d/%d correct words and %d wrong words." % [correct_selected, correct_total, wrong_selected]
		result.feedback_color = ExerciseTheme.COLORS.error
	else:
		result.feedback_text = "You chose %d/%d correct words." % [correct_selected, correct_total]
		result.feedback_color = ExerciseTheme.COLORS.primary

	return result

# ---------- Helpers ----------

func _get_toggle_func(wb: Button) -> Callable:
	return func(): return wb.button_pressed

func _get_correct_words(data: ExerciseData, word_list: Array) -> Array:
	var raw: Variant = data.raw.get("answer_words", data.raw.get("correct_words", []))
	var source: Array = []
	if raw is Array and not raw.is_empty():
		source = raw
	elif raw is String and str(raw).strip_edges() != "":
		source = [raw]
	else:
		source = word_list

	var out: Array = []
	for w in source:
		var s := ExerciseData.normalize(get_option_text(w))
		if s != "":
			out.append(s)
	return out

func _is_word_correct(word_text: String, correct_words: Array) -> bool:
	var normalized_word := ExerciseData.normalize(word_text)
	for correct in correct_words:
		if ExerciseData.normalize(str(correct)) == normalized_word:
			return true
	return false

func _on_word_toggled(pressed: bool, btn: Button) -> void:
	if btn.disabled:
		return
	if pressed:
		_style_word_button(btn, "selected")
	else:
		_style_word_button(btn, "idle")

func _style_word_button(btn: Button, state: String) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1

	var bg := Color("#0f1b3d")
	var border := Color("#3d4a7a")
	var font_color := ExerciseTheme.COLORS.text

	match state:
		"selected":
			bg = ExerciseTheme.COLORS.warning
			border = ExerciseTheme.COLORS.warning
			font_color = Color("#241a00")
		"correct":
			bg = ExerciseTheme.COLORS.success
			border = ExerciseTheme.COLORS.success
			font_color = Color("#03251a")
		"wrong":
			bg = ExerciseTheme.COLORS.error
			border = ExerciseTheme.COLORS.error
			font_color = Color("#2b0505")
		_:
			bg = Color("#0f1b3d")
			border = Color("#3d4a7a")
			font_color = ExerciseTheme.COLORS.text

	style.bg_color = bg
	style.border_color = border
	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color)
