class_name MultipleChoiceExercise
extends GrammarExercise


var questions: Array = []

var question_label: Label
var instruction_label: Label
var options_container: VBoxContainer


func setup(data: Dictionary) -> void:
	super.setup(data)

	questions = data.get("questions", [])

	_build_ui()
	_show_question()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()

	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	margin.add_theme_constant_override(
		"margin_left",
		24
	)

	margin.add_theme_constant_override(
		"margin_right",
		24
	)

	margin.add_theme_constant_override(
		"margin_top",
		24
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		24
	)

	add_child(margin)

	var main := VBoxContainer.new()

	main.add_theme_constant_override(
		"separation",
		18
	)

	margin.add_child(main)

	instruction_label = Label.new()

	instruction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	instruction_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	instruction_label.add_theme_font_size_override(
		"font_size",
		18
	)

	main.add_child(instruction_label)

	question_label = Label.new()

	question_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	question_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	question_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	question_label.custom_minimum_size = Vector2(
		0,
		140
	)

	question_label.add_theme_font_size_override(
		"font_size",
		26
	)

	main.add_child(question_label)

	var spacer := Control.new()

	spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	main.add_child(spacer)

	options_container = VBoxContainer.new()

	options_container.add_theme_constant_override(
		"separation",
		14
	)

	main.add_child(options_container)


func _show_question() -> void:
	if current_index >= questions.size():
		complete()
		return

	answered = false

	for child in options_container.get_children():
		child.queue_free()

	var question: Dictionary = questions[
		current_index
	]

	instruction_label.text = str(
		exercise_data.get(
			"instruction_fa",
			"گزینهٔ درست را انتخاب کن."
		)
	)

	question_label.text = str(
		question.get(
			"question",
			""
		)
	)

	var options: Array = question.get(
		"options",
		[]
	)

	for i in range(options.size()):
		var button := GrammarButton.new()

		button.variant = (
			GrammarButton.ButtonVariant.SECONDARY
		)

		button.custom_minimum_size = Vector2(
			0,
			64
		)

		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		button.text = str(
			options[i]
		)

		button.set_meta(
			"answer_index",
			i
		)

		button.pressed.connect(
			func():
				_on_answer_pressed(button)
		)

		options_container.add_child(
			button
		)

		GrammarAnimation.appear(
			button,
			i * 0.04
		)

	GrammarAnimation.appear(
		question_label
	)


func _on_answer_pressed(
	button: GrammarButton
) -> void:

	if answered:
		return

	answered = true

	var question: Dictionary = questions[
		current_index
	]

	var correct_index := int(
		question.get(
			"correct",
			-1
		)
	)

	var selected_index := int(
		button.get_meta(
			"answer_index",
			-1
		)
	)

	var correct := (
		selected_index == correct_index
	)

	if correct:
		button.set_correct_state()
	else:
		button.set_wrong_state()

		# Also show the correct answer.
		for child in options_container.get_children():
			if child is GrammarButton:
				var option_button := child as GrammarButton

				var index := int(
					option_button.get_meta(
						"answer_index",
						-1
					)
				)

				if index == correct_index:
					option_button.set_correct_state()
					break

	var explanation := ""

	if correct:
		explanation = str(
			question.get(
				"explanation_fa",
				"آفرین! پاسخ درست است."
			)
		)
	else:
		explanation = str(
			question.get(
				"wrong_explanation_fa",
				"این گزینه درست نیست. دوباره فکر کن."
			)
		)

	submit_result(
		correct,
		explanation
	)


func continue_to_next() -> void:
	current_index += 1

	_show_question()
