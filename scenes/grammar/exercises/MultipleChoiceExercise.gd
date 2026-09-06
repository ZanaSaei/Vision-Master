class_name MultipleChoiceExercise
extends GrammarExercise


var questions: Array = []

var question_label: Label
var instruction_label: Label
var options_container: Container

var _main: VBoxContainer
var _long_mode_buttons: Array[GrammarButton] = []


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

	_main = main

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
		GrammarTheme.BODY_SIZE
	)

	instruction_label.add_theme_color_override(
		"font_color",
		GrammarTheme.text_secondary_color()
	)

	instruction_label.add_theme_font_override(
		"font",
		GrammarTheme.get_fa_bold()
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
		GrammarTheme.HEADING_SIZE
	)

	question_label.add_theme_color_override(
		"font_color",
		GrammarTheme.text_color()
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

	# Drop the previous question's option container immediately (not just
	# queue_free, which defers to end of frame). Otherwise the stale,
	# already-answered buttons linger behind the new buttons' fade-in and
	# can show as a "selected" option — most visibly on the last one.
	if is_instance_valid(options_container) \
			and options_container.get_parent() != null:
		_main.remove_child(options_container)
		options_container.queue_free()

	var question: Dictionary = questions[
		current_index
	]

	GrammarTheme.set_bidi_text(
		instruction_label,
		str(
			exercise_data.get(
				"instruction_fa",
				"گزینهٔ درست را انتخاب کن."
			)
		)
	)

	GrammarTheme.set_bidi_text(
		question_label,
		str(
			question.get(
				"question",
				""
			)
		)
	)

	var options: Array = question.get(
		"options",
		[]
	)

	# Short options (<= 3 words) sit in a 2x2 grid; longer sentence
	# options get one full-width line each so the whole sentence fits.
	var long_mode := false

	for i in range(options.size()):
		if str(options[i]).split(" ", false).size() > 3:
			long_mode = true
			break

	_long_mode_buttons.clear()

	if long_mode:
		var vbox := VBoxContainer.new()

		vbox.add_theme_constant_override(
			"separation",
			14
		)

		options_container = vbox
	else:
		var grid := GridContainer.new()

		grid.columns = 2

		grid.add_theme_constant_override(
			"h_separation",
		14
		)

		grid.add_theme_constant_override(
			"v_separation",
			14
		)

		grid.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		options_container = grid

	_main.add_child(
		options_container
	)

	for i in range(options.size()):
		var button := GrammarButton.new()

		button.variant = (
			GrammarButton.ButtonVariant.SECONDARY
		)

		button.play_click_sound = false
		button.neutral_states = true

		if long_mode:
			# Full-width buttons for long options, with a shared height
			# based on the tallest wrapped sentence.
			button.custom_minimum_size = Vector2(
				0,
				78
			)

			button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)

			button.autowrap_mode = (
				TextServer.AUTOWRAP_WORD_SMART
			)

			button.no_clip = true

			_long_mode_buttons.append(button)
		else:
			# Half-width cells in the 2-column grid.
			button.custom_minimum_size = Vector2(
				0,
				72
			)

			button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)

		GrammarTheme.set_bidi_text(
			button,
			str(
				options[i]
			)
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

	if long_mode:
		call_deferred(
			"_equalize_long_mode_buttons"
		)

	GrammarAnimation.appear(
		question_label
	)


func _equalize_long_mode_buttons() -> void:
	if _long_mode_buttons.is_empty():
		return

	var available_width: float = float(options_container.size.x)
	if available_width <= 0.0:
		available_width = float(get_viewport_rect().size.x)
		available_width -= float(GrammarTheme.SAFE_MARGIN * 2)
		available_width -= float(GrammarTheme.CONTENT_MARGIN * 2)
		available_width -= 24.0

	var font: Font = GrammarTheme.get_fa_bold()
	var tallest: float = 0.0

	for button in _long_mode_buttons:
		var measured := GrammarTheme.measure_text(
			font,
			button.text,
			GrammarTheme.BUTTON_FONT_SIZE,
			maxf(240.0, available_width - 24.0),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		tallest = maxf(tallest, measured.y)

	var final_height := int(ceil(tallest + 34.0))
	if final_height < 78:
		final_height = 78

	for button in _long_mode_buttons:
		button.custom_minimum_size = Vector2(
			0,
			final_height
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
		# Deliberately do NOT reveal the correct option — the learner just
		# retries (the hint bulb can help).

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


func retry_current() -> void:
	# Rebuild the same question's options so the learner can pick again.
	_show_question()


func get_current_hint() -> String:
	if current_index >= questions.size():
		return ""
	var q: Dictionary = questions[current_index]
	var hint := str(q.get("hint_fa", ""))
	if hint.is_empty():
		hint = str(q.get("wrong_explanation_fa", ""))
	if hint.is_empty():
		hint = "به معنی هر گزینه خوب دقت کن و جمله را دوباره بخوان."
	return hint
