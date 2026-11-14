class_name TrueFalseExercise
extends GrammarExercise
# ============================================================
#  TRUE / FALSE EXERCISE — High-Contrast Dual Choice UX
# ============================================================
#  Features:
#   1. Elevated Statement Card with native TTS audio pronunciation
#   2. High-contrast, beautifully themed choice cards (True=Green, False=Red)
#   3. Center-pivot tactile spring physics animations
#   4. Clear visual resolution revealing correct choice on mistake
# ============================================================

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

	# --- 1. TOP BAR: Counter Pill + Instruction ---
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 12)
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
		str(exercise_data.get("instruction_fa", "مشخص کن جمله زیر از نظر گرامری درست است یا غلط:"))
	)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	instruction.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	instruction.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	container.add_child(instruction)

	# --- 2. ELEVATED STATEMENT CARD ---
	statement_card = PanelContainer.new()
	var card_style := GrammarTheme.info_card_style()
	card_style.border_width_top = 4
	card_style.border_color = GrammarTheme.accent_color()
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 26
	card_style.content_margin_bottom = 26
	statement_card.add_theme_stylebox_override("panel", card_style)
	statement_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statement_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	statement_card.custom_minimum_size = Vector2(0, 190)
	container.add_child(statement_card)

	var statement_row := HBoxContainer.new()
	statement_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statement_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	statement_row.add_theme_constant_override("separation", 14)
	statement_card.add_child(statement_row)

	statement_label = Label.new()
	statement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	statement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	statement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	statement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statement_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	statement_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
	statement_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	statement_label.add_theme_font_override("font", GrammarTheme.get_en_bold())
	statement_row.add_child(statement_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# --- 3. DUAL CHOICE CARDS (TRUE / FALSE) ---
	var btn_row := HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 18)
	container.add_child(btn_row)

	# TRUE (درست) Button with Emerald styling
	true_button = GrammarButton.new()
	true_button.variant = GrammarButton.ButtonVariant.SECONDARY
	true_button.play_click_sound = false
	true_button.neutral_states = true
	true_button.min_height = 124
	true_button.font_size = 42
	true_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	true_button.text = "✓  درست"
	_style_true_button(true_button)
	true_button.pressed.connect(func() -> void: _answer(true))
	btn_row.add_child(true_button)

	# FALSE (غلط) Button with Rose/Crimson styling
	false_button = GrammarButton.new()
	false_button.variant = GrammarButton.ButtonVariant.SECONDARY
	false_button.play_click_sound = false
	false_button.neutral_states = true
	false_button.min_height = 124
	false_button.font_size = 42
	false_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	false_button.text = "✗  غلط"
	_style_false_button(false_button)
	false_button.pressed.connect(func() -> void: _answer(false))
	btn_row.add_child(false_button)


func _style_true_button(btn: GrammarButton) -> void:
	var normal := GrammarTheme.rounded_box(GrammarTheme.success_soft_color(), 22, GrammarTheme.success_color(), 2)
	var hover := GrammarTheme.rounded_box(Color(GrammarTheme.success_color().r, GrammarTheme.success_color().g, GrammarTheme.success_color().b, 0.26), 22, GrammarTheme.success_color(), 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", GrammarTheme.success_color())
	btn.add_theme_color_override("font_hover_color", GrammarTheme.success_color())
	btn.add_theme_color_override("font_pressed_color", GrammarTheme.success_color())


func _style_false_button(btn: GrammarButton) -> void:
	var normal := GrammarTheme.rounded_box(GrammarTheme.error_soft_color(), 22, GrammarTheme.error_color(), 2)
	var hover := GrammarTheme.rounded_box(Color(GrammarTheme.error_color().r, GrammarTheme.error_color().g, GrammarTheme.error_color().b, 0.26), 22, GrammarTheme.error_color(), 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", GrammarTheme.error_color())
	btn.add_theme_color_override("font_hover_color", GrammarTheme.error_color())
	btn.add_theme_color_override("font_pressed_color", GrammarTheme.error_color())


func _show_item() -> void:
	var items: Array = exercise_data.get("items", [])
	if current_index >= items.size():
		complete()
		return
	answered = false

	_style_true_button(true_button)
	_style_false_button(false_button)
	true_button.disabled = false
	false_button.disabled = false

	GrammarTheme.set_bidi_text(counter_label, "سوال %d از %d" % [current_index + 1, items.size()])

	var item: Dictionary = items[current_index]
	var raw_stmt := str(item.get("statement", ""))
	GrammarTheme.set_bidi_text(statement_label, raw_stmt)

	# Audio speaker button in statement row
	var stmt_row := statement_label.get_parent() as HBoxContainer
	if stmt_row != null:
		for child in stmt_row.get_children():
			if child != statement_label:
				stmt_row.remove_child(child)
				child.queue_free()
		if not GrammarTheme.is_fa_dominant(raw_stmt) and not raw_stmt.is_empty():
			var speaker := GrammarTheme.make_speaker_button(raw_stmt, 76.0)
			stmt_row.add_child(speaker)

	GrammarAnimation.appear(statement_card)
	GrammarAnimation.appear(true_button, 0.06)
	GrammarAnimation.appear(false_button, 0.12)


func _answer(value: bool) -> void:
	if answered:
		return
	answered = true
	var item: Dictionary = exercise_data["items"][current_index]
	var correct_value := bool(item.get("correct", true))
	var is_correct := (value == correct_value)

	true_button.disabled = true
	false_button.disabled = true

	if is_correct:
		if value:
			true_button.set_correct_state()
		else:
			false_button.set_correct_state()
	else:
		if value:
			true_button.set_wrong_state()
			false_button.set_correct_state()
		else:
			false_button.set_wrong_state()
			true_button.set_correct_state()

	var explanation := ""
	if is_correct:
		explanation = str(item.get("explanation_fa", "آفرین! تشخیص شما کاملاً درست است."))
	else:
		explanation = str(item.get("wrong_explanation_fa", "این جمله درست نیست. به ساختار فعل و زمان دقت کن."))

	submit_result(is_correct, explanation)


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
		hint = "به زمان جمله و ساختار گرامری فاعل و فعل خوب دقت کن."
	return hint
