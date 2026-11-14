class_name MultipleChoiceExercise
extends GrammarExercise
# ============================================================
#  MULTIPLE CHOICE EXERCISE — Modern Grammar Quiz UX
# ============================================================
#  Features:
#   1. Elevated Question Card with top accent bar
#   2. Native TTS Pronunciation speaker button for English prompts
#   3. A/B/C/D circular option indicator badges
#   4. Tactile spring physics animations on choice selection
#   5. Visual reveal of correct answer upon mistake
# ============================================================

var questions: Array = []
var counter_label: Label
var instruction_label: Label
var question_card: PanelContainer
var question_label: Label
var options_container: Container
var _main: VBoxContainer
var _option_buttons: Array[GrammarButton] = []
var _long_mode_buttons: Array[GrammarButton] = []

const OPTION_LETTERS := ["A", "B", "C", "D", "E", "F"]


func setup(data: Dictionary) -> void:
	super.setup(data)
	questions = data.get("questions", [])
	_build_ui()
	_show_question()


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

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	_main = main
	margin.add_child(main)

	# --- 1. TOP BAR: Counter Pill + Instruction ---
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 12)
	main.add_child(top_bar)

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

	instruction_label = Label.new()
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	instruction_label.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	instruction_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	main.add_child(instruction_label)

	# --- 2. ELEVATED QUESTION CARD ---
	question_card = PanelContainer.new()
	var q_style := GrammarTheme.info_card_style()
	q_style.border_width_top = 4
	q_style.border_color = GrammarTheme.accent_color()
	q_style.content_margin_left = 24
	q_style.content_margin_right = 24
	q_style.content_margin_top = 22
	q_style.content_margin_bottom = 22
	question_card.add_theme_stylebox_override("panel", q_style)
	question_card.custom_minimum_size = Vector2(0, 160)
	question_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(question_card)

	var q_content_row := HBoxContainer.new()
	q_content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q_content_row.add_theme_constant_override("separation", 14)
	question_card.add_child(q_content_row)

	question_label = Label.new()
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question_label.add_theme_font_size_override("font_size", GrammarTheme.HEADING_SIZE)
	question_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	question_label.add_theme_font_override("font", GrammarTheme.get_en_bold())
	q_content_row.add_child(question_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(spacer)

	options_container = VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 14)
	main.add_child(options_container)


func _show_question() -> void:
	if current_index >= questions.size():
		complete()
		return
	answered = false

	if is_instance_valid(options_container) and options_container.get_parent() != null:
		_main.remove_child(options_container)
		options_container.queue_free()

	_option_buttons.clear()
	_long_mode_buttons.clear()

	var question: Dictionary = questions[current_index]
	var current_q_num := current_index + 1
	var total_q := questions.size()
	GrammarTheme.set_bidi_text(counter_label, "سوال %d از %d" % [current_q_num, total_q])
	GrammarTheme.set_bidi_text(
		instruction_label,
		str(exercise_data.get("instruction_fa", "گزینه درست را انتخاب کن."))
	)

	var raw_q: String = str(question.get("question", ""))
	GrammarTheme.set_bidi_text(question_label, raw_q)

	# Check question card row for audio speaker button
	var q_row := question_label.get_parent() as HBoxContainer
	if q_row != null:
		# Clean old speaker buttons if present
		for child in q_row.get_children():
			if child != question_label:
				q_row.remove_child(child)
				child.queue_free()
		# Add speaker button for English prompt
		if not GrammarTheme.is_fa_dominant(raw_q) and not raw_q.is_empty():
			var speak_clean := raw_q.replace("______", "blank").replace("_____", "blank")
			var speaker := GrammarTheme.make_speaker_button(speak_clean, 72.0)
			q_row.add_child(speaker)

	var options: Array = question.get("options", [])
	var long_mode := false
	for i in range(options.size()):
		if str(options[i]).split(" ", false).size() > 3:
			long_mode = true
			break

	if long_mode:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 14)
		options_container = vbox
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_container = grid

	_main.add_child(options_container)

	var long_mode_height: int = 0
	if long_mode:
		var texts: Array = []
		for i in range(options.size()):
			texts.append(GrammarTheme.bidi_fix(str(options[i])))
		long_mode_height = _long_mode_button_height(texts)

	for i in range(options.size()):
		var button := GrammarButton.new()
		button.variant = GrammarButton.ButtonVariant.SECONDARY
		button.play_click_sound = false
		button.neutral_states = true

		var opt_letter: String = OPTION_LETTERS[i] if i < OPTION_LETTERS.size() else str(i + 1)
		var opt_text := str(options[i])
		var full_opt_text := "%s. %s" % [opt_letter, opt_text]

		if long_mode:
			button.custom_minimum_size = Vector2(0, long_mode_height)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.no_clip = true
			_long_mode_buttons.append(button)
		else:
			button.custom_minimum_size = Vector2(0, 96)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		GrammarTheme.set_bidi_text(button, full_opt_text)
		button.set_meta("answer_index", i)
		button.pressed.connect(func() -> void: _on_answer_pressed(button))
		options_container.add_child(button)
		_option_buttons.append(button)
		GrammarAnimation.appear(button, i * 0.05)

	if long_mode:
		call_deferred("_equalize_long_mode_buttons")

	GrammarAnimation.appear(question_card)


func _long_mode_available_width() -> float:
	var available_width: float = float(_main.size.x if is_instance_valid(_main) else 0.0)
	if available_width <= 0.0:
		if is_inside_tree():
			available_width = float(get_viewport_rect().size.x)
		else:
			available_width = 800.0
		available_width -= float(GrammarTheme.SAFE_MARGIN * 2)
		available_width -= float(GrammarTheme.CONTENT_MARGIN * 2)
		available_width -= 24.0
	return available_width


func _long_mode_button_height(texts: Array) -> int:
	var available_width: float = _long_mode_available_width()
	var font: Font = GrammarTheme.get_fa_bold()
	var tallest: float = 0.0
	for i in range(texts.size()):
		var measured := GrammarTheme.measure_text(
			font,
			str(texts[i]),
			GrammarTheme.BUTTON_FONT_SIZE,
			maxf(240.0, available_width - 24.0),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		tallest = maxf(tallest, measured.y)
	var final_height: int = int(ceil(tallest + 34.0))
	if final_height < 92:
		final_height = 92
	return final_height


func _equalize_long_mode_buttons() -> void:
	if _long_mode_buttons.is_empty():
		return
	var texts: Array = []
	for button in _long_mode_buttons:
		texts.append(button.text)
	var final_height := _long_mode_button_height(texts)
	for button in _long_mode_buttons:
		button.custom_minimum_size = Vector2(0, final_height)


func _on_answer_pressed(button: GrammarButton) -> void:
	if answered:
		return
	answered = true
	var question: Dictionary = questions[current_index]
	var correct_index := int(question.get("correct", -1))
	var selected_index := int(button.get_meta("answer_index", -1))
	var correct := (selected_index == correct_index)

	if correct:
		button.set_correct_state()
	else:
		button.set_wrong_state()
		# Reveal correct answer for clear learning reinforcement
		for opt_btn in _option_buttons:
			if int(opt_btn.get_meta("answer_index", -1)) == correct_index:
				opt_btn.set_correct_state()

	var explanation := ""
	if correct:
		explanation = str(question.get("explanation_fa", "آفرین! پاسخ درست است."))
	else:
		explanation = str(question.get("wrong_explanation_fa", "این گزینه درست نیست. دوباره فکر کن."))

	submit_result(correct, explanation)


func continue_to_next() -> void:
	current_index += 1
	_show_question()


func retry_current() -> void:
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
