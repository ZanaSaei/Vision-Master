class_name MatchingExercise
extends GrammarExercise


var left_container: VBoxContainer
var right_container: VBoxContainer

var selected_left: GrammarButton
var selected_right: GrammarButton

var matched := 0

var left_buttons: Array[GrammarButton] = []
var right_buttons: Array[GrammarButton] = []


func setup(data: Dictionary) -> void:
	super.setup(data)

	_build_ui()
	_create_items()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()

	root.add_theme_constant_override(
		"separation",
		14
	)

	add_child(root)

	var instruction := Label.new()

	instruction.text = str(
		exercise_data.get(
			"instruction_fa",
			"جفت‌های درست را پیدا کن."
		)
	)

	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	instruction.add_theme_font_size_override(
		"font_size",
		19
	)

	root.add_child(instruction)

	var columns := HBoxContainer.new()

	columns.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	columns.add_theme_constant_override(
		"separation",
		12
	)

	root.add_child(columns)

	left_container = VBoxContainer.new()

	left_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	left_container.add_theme_constant_override(
		"separation",
		10
	)

	columns.add_child(
		left_container
	)

	right_container = VBoxContainer.new()

	right_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	right_container.add_theme_constant_override(
		"separation",
		10
	)

	columns.add_child(
		right_container
	)


func _create_items() -> void:

	var items: Array = exercise_data.get(
		"items",
		[]
	)

	var shuffled_right := items.duplicate()

	shuffled_right.shuffle()

	for item in items:

		var button := _create_button(
			str(
				item.get(
					"left",
					""
				)
			),
			true
		)

		button.set_meta(
			"match_value",
			str(
				item.get(
					"right",
					""
				)
			)
		)

		left_container.add_child(
			button
		)

		left_buttons.append(
			button
		)

	for item in shuffled_right:

		var button := _create_button(
			str(
				item.get(
					"right",
					""
				)
			),
			false
		)

		button.set_meta(
			"match_value",
			str(
				item.get(
					"right",
					""
				)
			)
		)

		right_container.add_child(
			button
		)

		right_buttons.append(
			button
		)


func _create_button(
	text_value: String,
	is_left: bool
) -> GrammarButton:

	var button := GrammarButton.new()

	button.variant = (
		GrammarButton.ButtonVariant.SECONDARY
	)

	button.text = text_value

	button.custom_minimum_size = Vector2(
		0,
		65
	)

	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	button.add_theme_font_size_override(
		"font_size",
		16
	)

	button.set_meta(
		"is_left",
		is_left
	)

	button.pressed.connect(
		func():
			_select(
				button,
				is_left
			)
	)

	return button


func _select(
	button: GrammarButton,
	is_left: bool
) -> void:

	if button.disabled:
		return

	GrammarAnimation.press(
		button
	)

	if is_left:
		selected_left = button
	else:
		selected_right = button

	if (
		selected_left != null
		and selected_right != null
	):
		_check_pair()


func _check_pair() -> void:

	var left_value := str(
		selected_left.get_meta(
			"match_value",
			""
		)
	)

	var right_value := str(
		selected_right.get_meta(
			"match_value",
			""
		)
	)

	var correct := (
		left_value == right_value
	)

	if correct:

		selected_left.set_correct_state()
		selected_right.set_correct_state()

		matched += 1

		selected_left = null
		selected_right = null

		if matched >= left_buttons.size():

			submit_result(
				true,
				"🎉 عالی! همه‌ی جفت‌ها را پیدا کردی."
			)

			await get_tree().create_timer(
				0.4
			).timeout

			complete()

	else:

		GrammarAnimation.wrong(
			selected_left
		)

		GrammarAnimation.wrong(
			selected_right
		)

		submit_result(
			false,
			"این دو قسمت با هم جور نیستند. دوباره امتحان کن."
		)

		selected_left = null
		selected_right = null


func continue_to_next() -> void:
	current_index += 1
