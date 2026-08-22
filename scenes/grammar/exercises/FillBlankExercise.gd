class_name FillBlankExercise
extends GrammarExercise


var prompt_label: Label
var input: LineEdit
var submit_button: GrammarButton


func setup(data: Dictionary) -> void:
	super.setup(data)

	_build_ui()
	_show_item()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var container := VBoxContainer.new()

	container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	container.add_theme_constant_override(
		"separation",
		22
	)

	container.alignment = BoxContainer.ALIGNMENT_CENTER

	add_child(container)

	var title := Label.new()

	title.text = str(
		exercise_data.get(
			"instruction_fa",
			"جمله را کامل کن."
		)
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	title.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BODY_SIZE
	)

	title.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	container.add_child(title)

	prompt_label = Label.new()

	prompt_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	prompt_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	prompt_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	prompt_label.custom_minimum_size = Vector2(
		0,
		140
	)

	prompt_label.add_theme_font_size_override(
		"font_size",
		GrammarTheme.HEADING_SIZE
	)

	prompt_label.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT
	)

	container.add_child(prompt_label)

	input = LineEdit.new()

	input.placeholder_text = (
		"پاسخ خود را بنویس..."
	)

	input.custom_minimum_size = Vector2(
		600,
		70
	)

	# Keep it a centered 1000-wide box instead of stretching edge-to-edge.
	input.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)

	input.alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	input.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BODY_LARGE_SIZE
	)

	container.add_child(input)

	submit_button = GrammarButton.new()

	submit_button.variant = (
		GrammarButton.ButtonVariant.PRIMARY
	)

	submit_button.text = "بررسی ✓"

	submit_button.pressed.connect(
		_check_answer
	)

	container.add_child(
		submit_button
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

	input.text = ""

	var item: Dictionary = items[
		current_index
	]

	prompt_label.text = str(
		item.get(
			"text",
			""
		)
	)

	GrammarAnimation.appear(
		prompt_label
	)

	GrammarAnimation.appear(
		input,
		0.08
	)

	GrammarAnimation.appear(
		submit_button,
		0.16
	)


func _check_answer() -> void:
	if answered:
		return

	var user_answer := input.text.strip_edges()

	if user_answer.is_empty():
		return

	var item: Dictionary = exercise_data[
		"items"
	][current_index]

	var answers: Array = item.get(
		"answers",
		[]
	)

	var normalized_user := (
		user_answer.to_lower()
	)

	var correct := false

	for answer in answers:
		var normalized_answer := str(
			answer
		).strip_edges().to_lower()

		if normalized_user == normalized_answer:
			correct = true
			break

	var explanation := ""

	if correct:
		explanation = str(
			item.get(
				"explanation_fa",
				"آفرین! پاسخ درست است."
			)
		)
	else:
		explanation = str(
			item.get(
				"wrong_explanation_fa",
				"پاسخ درست نیست. دوباره فکر کن."
			)
		)

	answered = true

	submit_result(
		correct,
		explanation
	)


func continue_to_next() -> void:
	current_index += 1

	_show_item()
