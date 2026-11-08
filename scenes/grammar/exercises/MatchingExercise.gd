class_name MatchingExercise
extends GrammarExercise

var counter_label: Label
var left_container: VBoxContainer
var right_container: VBoxContainer
var selected_left: GrammarButton
var selected_right: GrammarButton
var matched: int = 0
var left_buttons: Array[GrammarButton] = []
var right_buttons: Array[GrammarButton] = []


func setup(data: Dictionary) -> void:
	super.setup(data)
	_build_ui()
	_create_items()
	call_deferred("_equalize_button_heights")


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	# Matched Pairs Counter Pill
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top_bar)

	var pill := PanelContainer.new()
	var pill_style := GrammarTheme.rounded_box(GrammarTheme.accent_soft_color(), 16, GrammarTheme.accent_color(), 1)
	pill_style.content_margin_left = 18
	pill_style.content_margin_right = 18
	pill_style.content_margin_top = 6
	pill_style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", pill_style)
	top_bar.add_child(pill)

	counter_label = Label.new()
	counter_label.name = "CounterLabel"
	counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	counter_label.add_theme_font_size_override("font_size", GrammarTheme.CAPTION_SIZE)
	counter_label.add_theme_color_override("font_color", GrammarTheme.accent_color())
	pill.add_child(counter_label)

	var instruction := Label.new()
	GrammarTheme.set_bidi_text(
		instruction,
		str(exercise_data.get("instruction_fa", "جفت‌های درست را پیدا کن."))
	)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	instruction.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	instruction.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	root.add_child(instruction)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	left_container = VBoxContainer.new()
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_container.add_theme_constant_override("separation", 20)
	columns.add_child(left_container)

	right_container = VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.add_theme_constant_override("separation", 20)
	columns.add_child(right_container)


func _update_counter() -> void:
	if counter_label != null:
		GrammarTheme.set_bidi_text(counter_label, "🔗 جفت‌های پیدا شده: %d از %d" % [matched, left_buttons.size()])


func _create_items() -> void:
	matched = 0
	left_buttons.clear()
	right_buttons.clear()

	var items: Array = exercise_data.get("items", [])
	var shuffled_right := items.duplicate()
	shuffled_right.shuffle()

	for i in range(items.size()):
		var item: Dictionary = items[i]
		var button := _create_button(str(item.get("left", "")), true)
		button.set_meta("match_value", str(item.get("right", "")))
		left_container.add_child(button)
		left_buttons.append(button)
		GrammarAnimation.appear(button, i * 0.04)

	for i in range(shuffled_right.size()):
		var item: Dictionary = shuffled_right[i]
		var button := _create_button(str(item.get("right", "")), false)
		button.set_meta("match_value", str(item.get("right", "")))
		right_container.add_child(button)
		right_buttons.append(button)
		GrammarAnimation.appear(button, i * 0.04 + 0.02)

	_update_counter()


func _create_button(text_value: String, is_left: bool) -> GrammarButton:
	var button := GrammarButton.new()
	button.variant = GrammarButton.ButtonVariant.SECONDARY
	button.play_click_sound = false
	button.neutral_states = true
	GrammarTheme.set_bidi_text(button, text_value)
	button.custom_minimum_size = Vector2(0, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", GrammarTheme.BUTTON_FONT_SIZE_MATCHING)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.no_clip = true
	button.set_meta("is_left", is_left)
	button.pressed.connect(func() -> void: _select(button, is_left))
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

	var final_height: int = int(ceil(tallest + 28.0))
	if final_height < 84:
		final_height = 84
	for button in all_buttons:
		button.custom_minimum_size = Vector2(0, final_height)


func _select(button: GrammarButton, is_left: bool) -> void:
	if button.disabled:
		return
	Sfx.click()
	GrammarAnimation.press(button)

	if is_left:
		if selected_left != null and selected_left != button:
			selected_left.clear_selected_state()
		selected_left = button
	else:
		if selected_right != null and selected_right != button:
			selected_right.clear_selected_state()
		selected_right = button

	button.set_selected_state()

	if selected_left != null and selected_right != null:
		_check_pair()


func _check_pair() -> void:
	var left_value := str(selected_left.get_meta("match_value", ""))
	var right_value := str(selected_right.get_meta("match_value", ""))
	var correct := (left_value == right_value)

	if correct:
		selected_left.set_correct_state()
		selected_right.set_correct_state()
		selected_left.clear_selected_state()
		selected_right.clear_selected_state()
		matched += 1
		_update_counter()
		GrammarAnimation.small_pop(counter_label)
		selected_left = null
		selected_right = null

		if matched >= left_buttons.size():
			submit_result(true, "عالی! همه‌ی جفت‌ها را پیدا کردی.")
		else:
			Sfx.correct()
	else:
		Sfx.wrong()
		selected_left.clear_selected_state()
		selected_right.clear_selected_state()
		GrammarAnimation.wrong(selected_left)
		GrammarAnimation.wrong(selected_right)
		selected_left = null
		selected_right = null


func continue_to_next() -> void:
	complete()


func get_current_hint() -> String:
	return "هر عبارت در ستون چپ را با معادل درست آن در ستون راست جفت کن."
