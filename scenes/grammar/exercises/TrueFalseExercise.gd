class_name TrueFalseExercise
extends GrammarExercise

var counter_label: Label
var statement_card: PanelContainer
var statement_label: Label
var true_button: GrammarButton
var false_button: GrammarButton


func setup(data: Dictionary) -> void:
	super.setup(data)
	_build_ui()
	_show_item()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_top", 16)
	outer_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(outer_margin)

	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 20)
	outer_margin.add_child(container)

	# Counter Pill
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(top_bar)

	var pill := PanelContainer.new()
	var pill_style := GrammarTheme.rounded_box(GrammarTheme.accent_soft_color(), 16, GrammarTheme.accent_color(), 1)
	pill_style.content_margin_left = 16
	pill_style.content_margin_right = 16
	pill_style.content_margin_top = 6
	pill_style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", pill_style)
	top_bar.add_child(pill)

	counter_label = Label.new()
	counter_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	counter_label.add_theme_font_size_override("font_size", GrammarTheme.CAPTION_SIZE)
	counter_label.add_theme_color_override("font_color", GrammarTheme.accent_color())
	pill.add_child(counter_label)

	var instruction := Label.new()
	GrammarTheme.set_bidi_text(
		instruction,
		str(exercise_data.get("instruction_fa", "مشخص کن جمله زیر درست است یا غلط:"))
	)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	instruction.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	instruction.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	container.add_child(instruction)

	# Statement Card
	statement_card = PanelContainer.new()
	var card_style := GrammarTheme.info_card_style()
	card_style.border_width_bottom = 4
	card_style.border_color = GrammarTheme.accent_color()
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	statement_card.add_theme_stylebox_override("panel", card_style)
	statement_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statement_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	statement_card.custom_minimum_size = Vector2(0, 190)
	container.add_child(statement_card)

	statement_label = Label.new()
	statement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	statement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	statement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	statement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statement_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	statement_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
	statement_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	statement_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	statement_card.add_child(statement_label)

	# Side-by-side True / False Buttons
	var btn_row := HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 18)
	container.add_child(btn_row)

	true_button = GrammarButton.new()
	true_button.variant = GrammarButton.ButtonVariant.SECONDARY
	true_button.play_click_sound = false
	true_button.neutral_states = true
	true_button.min_height = 116
	true_button.font_size = 40
	true_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	true_button.text = "✓ درست"
	true_button.pressed.connect(func() -> void: _answer(true))
	btn_row.add_child(true_button)

	false_button = GrammarButton.new()
	false_button.variant = GrammarButton.ButtonVariant.SECONDARY
	false_button.play_click_sound = false
	false_button.neutral_states = true
	false_button.min_height = 116
	false_button.font_size = 40
	false_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	false_button.text = "✗ غلط"
	false_button.pressed.connect(func() -> void: _answer(false))
	btn_row.add_child(false_button)


func _show_item() -> void:
	var items: Array = exercise_data.get("items", [])
	if current_index >= items.size():
		complete()
		return
	answered = false

	true_button.reset_state()
	false_button.reset_state()

	GrammarTheme.set_bidi_text(counter_label, "سوال %d از %d" % [current_index + 1, items.size()])

	var item: Dictionary = items[current_index]
	GrammarTheme.set_bidi_text(statement_label, str(item.get("statement", "")))

	GrammarAnimation.appear(statement_card)
	GrammarAnimation.appear(true_button, 0.06)
	GrammarAnimation.appear(false_button, 0.12)


func _answer(value: bool) -> void:
	if answered:
		return
	answered = true
	var item: Dictionary = exercise_data["items"][current_index]
	var expected := bool(item.get("answer", false))
	var correct := (value == expected)
	var explanation := str(item.get("explanation_fa", ""))

	if correct:
		if value:
			true_button.set_correct_state()
		else:
			false_button.set_correct_state()
	else:
		if value:
			true_button.set_wrong_state()
		else:
			false_button.set_wrong_state()

	submit_result(correct, explanation)


func continue_to_next() -> void:
	current_index += 1
	_show_item()


func retry_current() -> void:
	_show_item()


func get_current_hint() -> String:
	var items: Array = exercise_data.get("items", [])
	if current_index >= items.size():
		return ""
	var item: Dictionary = items[current_index]
	var hint := str(item.get("hint_fa", ""))
	if hint.is_empty():
		hint = str(item.get("fa", ""))
	if hint.is_empty():
		hint = "جمله را با دقت بخوان؛ آیا ادعا درست است یا نادرست؟"
	return hint
