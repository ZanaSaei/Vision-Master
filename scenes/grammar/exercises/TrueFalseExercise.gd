class_name TrueFalseExercise
extends GrammarExercise


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

	var container := VBoxContainer.new()

	container.add_theme_constant_override(
		"separation",
		18
	)

	add_child(container)

	var instruction := Label.new()

	instruction.text = str(
		exercise_data.get(
			"instruction_fa",
			"درست یا غلط؟"
		)
	)

	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	instruction.add_theme_font_size_override(
		"font_size",
		19
	)

	container.add_child(instruction)

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

	statement_label.custom_minimum_size = Vector2(
		0,
		180
	)

	statement_label.add_theme_font_size_override(
		"font_size",
		23
	)

	container.add_child(statement_label)

	true_button = GrammarButton.new()

	true_button.variant = (
		GrammarButton.ButtonVariant.SECONDARY
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
