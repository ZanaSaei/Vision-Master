class_name MatchingExercise
extends GrammarExercise

var root: VBoxContainer
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_node_ready() and not left_buttons.is_empty():
			call_deferred("_equalize_button_heights")


func _get_item_count() -> int:
	var items: Array = exercise_data.get("items", [])
	return items.size()


func _get_base_button_height() -> int:
	var n := _get_item_count()
	if n >= 7:
		return 52
	elif n >= 5:
		return 58
	else:
		return 66


func _get_button_font_size() -> int:
	var n := _get_item_count()
	if n >= 7:
		return 22
	return GrammarTheme.BUTTON_FONT_SIZE_MATCHING


func _get_separation() -> int:
	var n := _get_item_count()
	if n >= 7:
		return 10
	elif n >= 5:
		return 12
	else:
		return 14


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(root)

	# Matched Pairs Counter Pill
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top_bar)

	var pill := PanelContainer.new()
	var pill_style := GrammarTheme.rounded_box(GrammarTheme.accent_soft_color(), 16, GrammarTheme.accent_color(), 1)
	pill_style.content_margin_left = 16
	pill_style.content_margin_right = 16
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
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

	var sep := _get_separation()
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	root.add_child(columns)

	left_container = VBoxContainer.new()
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_container.add_theme_constant_override("separation", sep)
	columns.add_child(left_container)

	right_container = VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.add_theme_constant_override("separation", sep)
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

	var base_h := _get_base_button_height()
	var font_sz := _get_button_font_size()

	for i in range(items.size()):
		var item: Dictionary = items[i]
		var button := _create_button(str(item.get("left", "")), true, base_h, font_sz)
		button.set_meta("match_value", str(item.get("right", "")))
		left_container.add_child(button)
		left_buttons.append(button)
		GrammarAnimation.appear(button, i * 0.04)

	for i in range(shuffled_right.size()):
		var item: Dictionary = shuffled_right[i]
		var button := _create_button(str(item.get("right", "")), false, base_h, font_sz)
		button.set_meta("match_value", str(item.get("right", "")))
		right_container.add_child(button)
		right_buttons.append(button)
		GrammarAnimation.appear(button, i * 0.04 + 0.02)

	_update_counter()


func _create_button(text_value: String, is_left: bool, base_height: int, font_size: int) -> GrammarButton:
	var button := GrammarButton.new()
	button.variant = GrammarButton.ButtonVariant.SECONDARY
	button.play_click_sound = false
	button.neutral_states = true
	button.min_height = base_height
	GrammarTheme.set_bidi_text(button, text_value)
	button.custom_minimum_size = Vector2(0, base_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", font_size)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.no_clip = true
	button.set_meta("is_left", is_left)
	button.pressed.connect(func() -> void: _select(button, is_left))
	return button


func _equalize_button_heights() -> void:
	if left_buttons.is_empty() or right_buttons.is_empty():
		return

	var count := mini(left_buttons.size(), right_buttons.size())
	var base_h := float(_get_base_button_height())

	var column_width: float = float(left_container.size.x)
	if column_width <= 0.0:
		var vp_width: float = float(get_viewport_rect().size.x)
		column_width = maxf(200.0, (vp_width - 64.0) * 0.5)

	var font: Font = GrammarTheme.get_fa_bold()
	var font_sz := _get_button_font_size()
	var max_text_w: float = maxf(140.0, column_width - 24.0)

	for i in count:
		var btn_left := left_buttons[i]
		var btn_right := right_buttons[i]

		var measured_left := GrammarTheme.measure_text(
			font,
			btn_left.text,
			font_sz,
			max_text_w,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var measured_right := GrammarTheme.measure_text(
			font,
			btn_right.text,
			font_sz,
			max_text_w,
			HORIZONTAL_ALIGNMENT_CENTER
		)

		var tallest_text := maxf(measured_left.y, measured_right.y)
		var row_h: int = int(ceil(maxf(base_h, tallest_text + 18.0)))

		btn_left.custom_minimum_size = Vector2(0, row_h)
		btn_right.custom_minimum_size = Vector2(0, row_h)

	_update_total_size()


func _update_total_size() -> void:
	if root == null or not is_instance_valid(root):
		return

	root.queue_sort()
	var req_h: float = root.get_combined_minimum_size().y
	# Ensure parent ScrollContainer has enough scroll range with bottom breathing space
	custom_minimum_size.y = req_h + 32.0

	var avail_h: float = size.y
	if avail_h <= 0.0:
		avail_h = maxf(400.0, get_viewport_rect().size.y * 0.55)

	if req_h < avail_h - 20.0:
		root.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		root.alignment = BoxContainer.ALIGNMENT_BEGIN


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
