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
	call_deferred(
		"_equalize_button_heights"
	)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()

	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	root.add_theme_constant_override(
		"separation",
		20
	)

	root.alignment = BoxContainer.ALIGNMENT_CENTER

	add_child(root)

	var instruction := Label.new()

	GrammarTheme.set_bidi_text(
		instruction,
		str(
			exercise_data.get(
				"instruction_fa",
				"جفت‌های درست را پیدا کن."
			)
		)
	)

	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	# Let a long Persian instruction wrap inside the card instead of
	# overflowing the screen.
	instruction.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	instruction.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	instruction.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BODY_SIZE
	)

	instruction.add_theme_color_override(
		"font_color",
		GrammarTheme.text_secondary_color()
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
		30
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
		30
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

	button.play_click_sound = false
	button.neutral_states = true

	GrammarTheme.set_bidi_text(
		button,
		text_value
	)

	button.custom_minimum_size = Vector2(
		0,
		80
	)

	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	button.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BUTTON_FONT_SIZE_MATCHING
	)

	button.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	button.no_clip = true

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


func _equalize_button_heights() -> void:
	var all_buttons: Array[GrammarButton] = []
	all_buttons.append_array(left_buttons)
	all_buttons.append_array(right_buttons)
	if all_buttons.is_empty():
		return

	var column_width: float = float(left_container.size.x)
	if column_width <= 0.0:
		var vp_width: float = float(get_viewport_rect().size.x)
		column_width = maxf(240.0, (vp_width - 36.0) * 0.5)

	var font: Font = GrammarTheme.get_fa_bold()
	var tallest: float = 0.0

	for button in all_buttons:
		var measured := GrammarTheme.measure_text(
			font,
			button.text,
			GrammarTheme.BUTTON_FONT_SIZE_MATCHING,
			maxf(180.0, column_width - 18.0),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		tallest = maxf(tallest, measured.y)

	var final_height := int(ceil(tallest + 28.0))
	if final_height < 80:
		final_height = 80

	for button in all_buttons:
		button.custom_minimum_size = Vector2(
			0,
			final_height
		)


func _select(
	button: GrammarButton,
	is_left: bool
) -> void:

	if button.disabled:
		return

	GrammarAnimation.press(
		button
	)

	# Highlight the picked button and clear any previous pick in the
	# same column so it is always obvious what has been chosen.
	if is_left:
		if selected_left != null and selected_left != button:
			selected_left.clear_selected_state()
		selected_left = button
	else:
		if selected_right != null and selected_right != button:
			selected_right.clear_selected_state()
		selected_right = button

	button.set_selected_state()

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

		# Turned green and disabled (unselectable) by set_correct_state;
		# drop the selection highlight so they read as "matched".
		selected_left.clear_selected_state()
		selected_right.clear_selected_state()

		matched += 1

		selected_left = null
		selected_right = null

		if matched >= left_buttons.size():

			# Show the "عالی بود" feedback immediately when the last pair
			# is found. The بخش reward only appears once the learner taps
			# continue (continue_to_next), not before.
			submit_result(
				true,
				"🎉 عالی! همه‌ی جفت‌ها را پیدا کردی."
			)

	else:

		selected_left.clear_selected_state()
		selected_right.clear_selected_state()

		# Wrong pairs just shake in place — no feedback popup (the user
		# learns from the vibration and retries). So we do NOT call
		# submit_result(false, ...) here, which would show the popup.
		GrammarAnimation.wrong(
			selected_left
		)

		GrammarAnimation.wrong(
			selected_right
		)

		selected_left = null
		selected_right = null


func continue_to_next() -> void:
	# Matching is finished once every pair is found; the feedback popup's
	# continue button drives completion (which shows the بخش reward).
	complete()


func get_current_hint() -> String:
	return "ستون راست را با معنای درست در ستون چپ جفت کن."
