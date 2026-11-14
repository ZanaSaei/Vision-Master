class_name FillBlankExercise
extends GrammarExercise
# ============================================================
#  FILL BLANK EXERCISE — Modern Interactive Sentence UX
# ============================================================
#  Features:
#   1. Elevated Sentence Card with live in-sentence typing preview
#   2. Native TTS Pronunciation speaker button
#   3. Mobile Quick-Insert Character Chips (apostrophe ', hyphen -)
#   4. Dynamic responsive input field with quick clear button
#   5. Automatic Enter/Return key submit support
# ============================================================

var counter_label: Label
var prompt_card: PanelContainer
var prompt_label: Label
var live_preview_label: Label
var input: LineEdit
var clear_input_btn: Button
var submit_button: GrammarButton
var chips_container: HFlowContainer
var _raw_sentence: String = ""


func setup(data: Dictionary) -> void:
	super.setup(data)
	_build_ui()
	_show_item()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 18)
	margin.add_child(container)

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

	var title := Label.new()
	GrammarTheme.set_bidi_text(
		title,
		str(exercise_data.get("instruction_fa", "جای خالی را با کلمه مناسب کامل کن."))
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	title.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	title.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	container.add_child(title)

	# --- 2. ELEVATED SENTENCE CARD WITH LIVE PREVIEW ---
	prompt_card = PanelContainer.new()
	var card_style := GrammarTheme.info_card_style()
	card_style.border_width_top = 4
	card_style.border_color = GrammarTheme.accent_color()
	card_style.content_margin_left = 24
	card_style.content_margin_right = 24
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	prompt_card.add_theme_stylebox_override("panel", card_style)
	prompt_card.custom_minimum_size = Vector2(0, 170)
	prompt_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(prompt_card)

	var prompt_row := HBoxContainer.new()
	prompt_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_row.add_theme_constant_override("separation", 14)
	prompt_card.add_child(prompt_row)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_label.add_theme_font_size_override("font_size", GrammarTheme.HEADING_SIZE)
	prompt_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	prompt_label.add_theme_font_override("font", GrammarTheme.get_en_bold())
	prompt_row.add_child(prompt_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# --- 3. QUICK-INSERT HELPER CHIPS ---
	chips_container = HFlowContainer.new()
	chips_container.alignment = FlowContainer.ALIGNMENT_CENTER
	chips_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips_container.add_theme_constant_override("h_separation", 10)
	chips_container.add_theme_constant_override("v_separation", 8)
	container.add_child(chips_container)

	_build_quick_chips(["'", "-", "will", "won't", "not"])

	# --- 4. RESPONSIVE INPUT FIELD ROW ---
	var input_row := HBoxContainer.new()
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_theme_constant_override("separation", 10)
	container.add_child(input_row)

	input = LineEdit.new()
	input.placeholder_text = "پاسخ را بنویسید..."
	input.custom_minimum_size = Vector2(0, 100)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var input_style := GrammarTheme.rounded_box(Global.get_theme_color("surface_alt"), 20, GrammarTheme.accent_color(), 2)
	input_style.content_margin_left = 18
	input_style.content_margin_right = 18
	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_stylebox_override("focus", input_style)

	var fa_font := GrammarTheme.get_fa_regular()
	if fa_font != null:
		input.add_theme_font_override("font", fa_font)
	input.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
	input.add_theme_color_override("font_color", GrammarTheme.text_color())
	input.text_changed.connect(_on_input_text_changed)
	input.text_submitted.connect(func(_t: String) -> void: _check_answer())
	input_row.add_child(input)

	# Quick Clear Button (✕)
	clear_input_btn = Button.new()
	clear_input_btn.text = "✕"
	clear_input_btn.custom_minimum_size = Vector2(80, 100)
	clear_input_btn.focus_mode = Control.FOCUS_NONE
	clear_input_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var clear_style := GrammarTheme.rounded_box(GrammarTheme.accent_soft_color(), 20)
	clear_input_btn.add_theme_stylebox_override("normal", clear_style)
	clear_input_btn.add_theme_stylebox_override("hover", clear_style)
	clear_input_btn.add_theme_stylebox_override("pressed", clear_style)
	clear_input_btn.add_theme_font_size_override("font_size", 34)
	clear_input_btn.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	clear_input_btn.pressed.connect(func() -> void:
		input.text = ""
		_on_input_text_changed("")
	)
	input_row.add_child(clear_input_btn)

	# --- 5. PRIMARY CHECK BUTTON ---
	submit_button = GrammarButton.new()
	submit_button.variant = GrammarButton.ButtonVariant.PRIMARY
	submit_button.text = "بررسی پاسخ ✓"
	submit_button.min_height = 104
	submit_button.font_size = 44
	submit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submit_button.pressed.connect(_check_answer)
	container.add_child(submit_button)


func _build_quick_chips(tokens: Array) -> void:
	for child in chips_container.get_children():
		child.queue_free()

	for token in tokens:
		var btn := Button.new()
		btn.text = str(token)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(80, 56)
		var chip_style := GrammarTheme.rounded_box(Global.get_theme_color("surface_alt"), 16, Global.get_theme_color("border"), 1)
		chip_style.content_margin_left = 14
		chip_style.content_margin_right = 14
		var hover_style := GrammarTheme.rounded_box(GrammarTheme.accent_soft_color(), 16, GrammarTheme.accent_color(), 1)
		hover_style.content_margin_left = 14
		hover_style.content_margin_right = 14
		btn.add_theme_stylebox_override("normal", chip_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		btn.add_theme_font_override("font", GrammarTheme.get_en_bold())
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", GrammarTheme.accent_color())

		var t_val := str(token)
		btn.pressed.connect(func() -> void:
			input.text += t_val
			input.caret_column = input.text.length()
			_on_input_text_changed(input.text)
			GrammarAnimation.small_pop(btn)
		)
		chips_container.add_child(btn)


func _show_item() -> void:
	var items: Array = exercise_data.get("items", [])
	if current_index >= items.size():
		complete()
		return

	answered = false
	input.text = ""
	GrammarTheme.set_bidi_text(counter_label, "سوال %d از %d" % [current_index + 1, items.size()])

	var item: Dictionary = items[current_index]
	_raw_sentence = str(item.get("text", ""))

	_update_live_preview("")

	# Speaker pronunciation button in prompt row
	var prompt_row := prompt_label.get_parent() as HBoxContainer
	if prompt_row != null:
		for child in prompt_row.get_children():
			if child != prompt_label:
				prompt_row.remove_child(child)
				child.queue_free()
		if not GrammarTheme.is_fa_dominant(_raw_sentence) and not _raw_sentence.is_empty():
			var clean_speak := _raw_sentence.replace("______", "blank").replace("_____", "blank")
			var speaker := GrammarTheme.make_speaker_button(clean_speak, 72.0)
			prompt_row.add_child(speaker)

	GrammarAnimation.appear(prompt_card)
	GrammarAnimation.appear(input, 0.08)
	GrammarAnimation.appear(submit_button, 0.14)


func _on_input_text_changed(new_text: String) -> void:
	_update_live_preview(new_text)


func _update_live_preview(typed_text: String) -> void:
	if _raw_sentence.is_empty():
		return

	var display_sentence: String = _raw_sentence
	var blank_slot := "[ %s ]" % (typed_text if not typed_text.strip_edges().is_empty() else "______")

	if display_sentence.contains("______"):
		display_sentence = display_sentence.replace("______", blank_slot)
	elif display_sentence.contains("_____"):
		display_sentence = display_sentence.replace("_____", blank_slot)
	elif display_sentence.contains("___"):
		display_sentence = display_sentence.replace("___", blank_slot)
	elif not typed_text.is_empty():
		display_sentence = "%s  %s" % [display_sentence, blank_slot]

	GrammarTheme.set_bidi_text(prompt_label, display_sentence)


func _check_answer() -> void:
	if answered:
		return

	var user_answer := input.text.strip_edges()
	if user_answer.is_empty():
		GrammarAnimation.wrong(input)
		return

	var items: Array = exercise_data.get("items", [])
	if current_index >= items.size():
		return

	var item: Dictionary = items[current_index]
	var answers: Array = item.get("answers", [])
	var normalized_user := _normalize_answer(user_answer)
	var correct := false

	for answer in answers:
		var normalized_answer := _normalize_answer(str(answer))
		if normalized_user == normalized_answer:
			correct = true
			break

	var explanation := ""
	if correct:
		explanation = str(item.get("explanation_fa", "آفرین! پاسخ درست است."))
	else:
		explanation = str(item.get("wrong_explanation_fa", "پاسخ درست نیست. دوباره دقت کن."))

	answered = true
	submit_result(correct, explanation)


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
		hint = "به معنای جمله فکر کن و جای خالی را با کلمه مناسب پر کن."
	return hint


func _normalize_answer(s: String) -> String:
	var out := s.strip_edges().to_lower()
	out = out.replace(char(0x2019), "'")
	out = out.replace(char(0x2018), "'")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()
