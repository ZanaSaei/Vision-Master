class_name TrueFalseExercise
extends GrammarExercise


var statement_label: Label
var true_button: GrammarButton
var false_button: GrammarButton
var statement_box: Control


func setup(data: Dictionary) -> void:
	super.setup(data)

	_build_ui()
	_show_item()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var outer_margin := MarginContainer.new()

	outer_margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	outer_margin.add_theme_constant_override(
		"margin_left",
		20
	)

	outer_margin.add_theme_constant_override(
		"margin_right",
		20
	)

	outer_margin.add_theme_constant_override(
		"margin_top",
		16
	)

	outer_margin.add_theme_constant_override(
		"margin_bottom",
		16
	)

	add_child(outer_margin)

	var container := VBoxContainer.new()

	container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	container.add_theme_constant_override(
		"separation",
		22
	)

	container.alignment = BoxContainer.ALIGNMENT_BEGIN

	outer_margin.add_child(container)

	var instruction := Label.new()

	instruction.text = str(
		exercise_data.get(
			"instruction_fa",
			"درست یا غلط؟"
		)
	)

	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	instruction.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	instruction.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	instruction.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BODY_SMALL_SIZE
	)

	instruction.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	container.add_child(instruction)

	statement_box = MarginContainer.new()

	statement_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	statement_box.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	statement_box.add_theme_constant_override(
		"margin_left",
		0
	)

	statement_box.add_theme_constant_override(
		"margin_right",
		0
	)
	statement_box.custom_minimum_size = Vector2(
		650,
		180
	)

	statement_label = Label.new()

	statement_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	statement_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	statement_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	statement_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	statement_label.custom_minimum_size = Vector2(
		650,
		180
	)

	statement_label.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BODY_SMALL_SIZE
	)

	statement_label.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT
	)

	statement_box.add_child(statement_label)

	container.add_child(statement_box)

	true_button = GrammarButton.new()

	true_button.variant = (
		GrammarButton.ButtonVariant.SECONDARY
	)

	true_button.play_click_sound = false
	true_button.neutral_states = true

	true_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	true_button.text = "✓ درست"

	true_button.pressed.connect(
		func():
			_answer(true)
	)

	container.add_child(
		true_button
	)

	false_button = GrammarButton.new()

	false_button.variant = (
		GrammarButton.ButtonVariant.SECONDARY
	)

	false_button.play_click_sound = false
	false_button.neutral_states = true

	false_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	false_button.text = "✗ غلط"

	false_button.pressed.connect(
		func():
			_answer(false)
	)

	container.add_child(
		false_button
	)



func _show_item() -> void:
	var items: Array = exercise_data.get(
		"items",
		[]
	)

	if current_index >= items.size():
		complete()
		return

	answered = false

	# Clear any correct/wrong highlight left over from the previous
	# item so the selected option does not carry into the next question.
	true_button.reset_state()
	false_button.reset_state()

	var item: Dictionary = items[
		current_index
	]

	statement_label.text = str(
		item.get(
			"statement",
			""
		)
	)

	GrammarAnimation.appear(
		statement_label
	)

	GrammarAnimation.appear(
		true_button,
		0.08
	)

	GrammarAnimation.appear(
		false_button,
		0.14
	)


func _answer(value: bool) -> void:
	if answered:
		return

	answered = true

	var item: Dictionary = exercise_data[
		"items"
	][current_index]

	var expected := bool(
		item.get(
			"answer",
			false
		)
	)

	var correct := (
		value == expected
	)

	var explanation := str(
		item.get(
			"explanation_fa",
			""
		)
	)

	submit_result(
		correct,
		explanation
	)

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


func continue_to_next() -> void:
	current_index += 1

	_show_item()


func retry_current() -> void:
	# Reset the two buttons and re-show the same statement for a retry.
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
