class_name UnscrambleExercise
extends GrammarExercise

var counter_label: Label
var answer_card: PanelContainer
var placeholder_label: Label
var answer_container: HFlowContainer
var words_container: HFlowContainer
var clear_button: GrammarButton
var check_button: GrammarButton
var selected_words: Array[String] = []

var _blanks_mode := false
var _blank_words: Array[String] = []
var _blank_buttons: Array[GrammarButton] = []
var _blank_sources: Array = []
var _bank_buttons := {}
var _word_button_width: int = 0


func setup(data: Dictionary) -> void:
	super.setup(data)
	_build_ui()
	_show_item()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	# Counter Pill
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top_bar)

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
	instruction.text = GrammarTheme.bidi_fix(str(exercise_data.get("instruction_fa", "کلمات را مرتب کن.")))
	instruction.text_direction = Control.TEXT_DIRECTION_RTL
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	instruction.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	instruction.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	root.add_child(instruction)

	# Dedicated Answer Tray Card
	answer_card = PanelContainer.new()
	var tray_style := GrammarTheme.info_card_style()
	tray_style.border_width_bottom = 3
	tray_style.border_color = GrammarTheme.accent_color()
	tray_style.content_margin_left = 20
	tray_style.content_margin_right = 20
	tray_style.content_margin_top = 20
	tray_style.content_margin_bottom = 20
	answer_card.add_theme_stylebox_override("panel", tray_style)
	answer_card.custom_minimum_size = Vector2(0, 145)
	answer_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(answer_card)

	var tray_stack := VBoxContainer.new()
	tray_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	answer_card.add_child(tray_stack)

	placeholder_label = Label.new()
	GrammarTheme.set_bidi_text(placeholder_label, "کلمات پایین را به ترتیب لمس کنید تا جمله ساخته شود...")
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder_label.add_theme_font_size_override("font_size", 28)
	placeholder_label.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	placeholder_label.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	tray_stack.add_child(placeholder_label)

	answer_container = HFlowContainer.new()
	answer_container.alignment = FlowContainer.ALIGNMENT_CENTER
	answer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer_container.add_theme_constant_override("h_separation", 10)
	answer_container.add_theme_constant_override("v_separation", 10)
	tray_stack.add_child(answer_container)

	# Word Bank Area
	words_container = HFlowContainer.new()
	words_container.alignment = FlowContainer.ALIGNMENT_CENTER
	words_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words_container.custom_minimum_size = Vector2(0, 120)
	words_container.add_theme_constant_override("h_separation", 10)
	words_container.add_theme_constant_override("v_separation", 10)
	root.add_child(words_container)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# Action Row: Clear Button + Check Button
	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 14)
	root.add_child(action_row)

	clear_button = GrammarButton.new()
	clear_button.variant = GrammarButton.ButtonVariant.SECONDARY
	clear_button.text = "↺ پاک کردن"
	clear_button.min_height = 112
	clear_button.font_size = 34
	clear_button.no_clip = true
	clear_button.custom_minimum_size = Vector2(280, 112)
	clear_button.pressed.connect(retry_current)
	action_row.add_child(clear_button)

	check_button = GrammarButton.new()
	check_button.variant = GrammarButton.ButtonVariant.PRIMARY
	check_button.text = "✓ بررسی"
	check_button.min_height = 112
	check_button.font_size = 44
	check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_button.pressed.connect(_check_answer)
	action_row.add_child(check_button)


func _update_tray_state() -> void:
	if _blanks_mode:
		placeholder_label.visible = false
		var any_filled := false
		var all_filled := true
		for w in _blank_words:
			if w != "":
				any_filled = true
			else:
				all_filled = false
		clear_button.disabled = not any_filled
		check_button.disabled = not all_filled
	else:
		var empty := selected_words.is_empty()
		placeholder_label.visible = empty
		clear_button.disabled = empty
		check_button.disabled = empty


func _show_item() -> void:
	var items: Array = exercise_data.get("items", [])
	if current_index >= items.size():
		complete()
		return
	answered = false
	selected_words.clear()
	_word_button_width = 0

	for child in answer_container.get_children():
		child.queue_free()
	for child in words_container.get_children():
		child.queue_free()

	_blanks_mode = false
	_blank_words.clear()
	_blank_buttons.clear()
	_blank_sources.clear()
	_bank_buttons.clear()

	GrammarTheme.set_bidi_text(counter_label, "سوال %d از %d" % [current_index + 1, items.size()])

	var item: Dictionary = items[current_index]
	if item.has("template") and item.has("options"):
		_blanks_mode = true
		_show_blanks_item(item)
	else:
		_show_sentence_item(item)

	_update_tray_state()
	GrammarAnimation.appear(answer_card)
	call_deferred("_constrain_flow_widths")


func _constrain_flow_widths() -> void:
	var avail: float = size.x
	if avail <= 0.0:
		avail = 1000.0
	avail -= 48.0
	_cap_flow_container(answer_container, avail)
	_cap_flow_container(words_container, avail)


func _cap_flow_container(container: Container, avail: float) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Label:
			var font: Font = child.get_theme_font("font")
			var fsize: int = child.get_theme_font_size("font_size")
			var tw: Vector2 = GrammarTheme.measure_text(font, child.text, fsize, -1.0, HORIZONTAL_ALIGNMENT_LEFT)
			if tw.x > avail:
				child.custom_minimum_size = Vector2(avail, 0)
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif child is Button:
			if child.custom_minimum_size.x > avail:
				child.custom_minimum_size = Vector2(avail, child.custom_minimum_size.y)


func _measure_uniform_word_width(words: Array) -> int:
	var font: Font = GrammarTheme.get_fa_bold()
	var widest: float = 0.0
	for w in words:
		var s := str(w)
		widest = maxf(
			widest,
			GrammarTheme.measure_text(font, s, GrammarTheme.BUTTON_FONT_SIZE, -1.0, HORIZONTAL_ALIGNMENT_LEFT).x
		)
	var width := int(ceil(widest + 38.0))
	if width < 88:
		width = 88
	return width


func _show_sentence_item(item: Dictionary) -> void:
	var words: Array = item.get("words", []).duplicate()
	_word_button_width = _measure_uniform_word_width(words)
	words.shuffle()

	for i in range(words.size()):
		var word := str(words[i])
		var button := GrammarButton.new()
		button.variant = GrammarButton.ButtonVariant.SECONDARY
		button.play_click_sound = false
		button.neutral_states = true
		button.text = word
		button.custom_minimum_size = Vector2(_word_button_width, 0)
		button.min_height = 68
		button.no_clip = true
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", GrammarTheme.BUTTON_FONT_SIZE)
		button.pressed.connect(func() -> void: _select_word(button, word))
		words_container.add_child(button)
		GrammarAnimation.appear(button, i * 0.03)


func _show_blanks_item(item: Dictionary) -> void:
	var template := str(item.get("template", ""))
	var parts := template.split("___")
	for i in range(parts.size()):
		var part := parts[i].strip_edges()
		if not part.is_empty():
			var label := Label.new()
			GrammarTheme.set_bidi_text(label, part)
			label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			label.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
			label.add_theme_color_override("font_color", GrammarTheme.text_color())
			answer_container.add_child(label)

		if i < parts.size() - 1:
			var blank := GrammarButton.new()
			blank.variant = GrammarButton.ButtonVariant.SECONDARY
			blank.play_click_sound = false
			blank.neutral_states = true
			blank.text = "(%d)" % (i + 1)
			blank.custom_minimum_size = Vector2(72, 0)
			blank.min_height = 58
			blank.no_clip = true
			blank.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			blank.add_theme_font_size_override("font_size", GrammarTheme.BODY_LARGE_SIZE)
			blank.set_meta("blank_index", i)
			blank.pressed.connect(func() -> void: _remove_blank(blank))
			_blank_buttons.append(blank)
			answer_container.add_child(blank)
			_blank_words.append("")
			_blank_sources.append(null)

	var options: Array = item.get("options", []).duplicate()
	_word_button_width = _measure_uniform_word_width(options)
	options.shuffle()

	for idx in range(options.size()):
		var word := str(options[idx])
		var btn := GrammarButton.new()
		btn.variant = GrammarButton.ButtonVariant.SECONDARY
		btn.play_click_sound = false
		btn.neutral_states = true
		btn.text = word
		btn.custom_minimum_size = Vector2(_word_button_width, 0)
		btn.min_height = 68
		btn.no_clip = true
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", GrammarTheme.BUTTON_FONT_SIZE)
		btn.pressed.connect(func() -> void: _fill_blank(btn, word))
		_bank_buttons[word] = btn
		words_container.add_child(btn)
		GrammarAnimation.appear(btn, idx * 0.03)


func _fill_blank(btn: GrammarButton, word: String) -> void:
	if answered or btn.disabled:
		return
	for i in range(_blank_words.size()):
		if _blank_words[i] == "":
			Sfx.click()
			_blank_words[i] = word
			_blank_buttons[i].text = word
			_blank_buttons[i].set_selected_state()
			GrammarAnimation.small_pop(_blank_buttons[i])
			btn.disabled = true
			if i < _blank_sources.size():
				_blank_sources[i] = btn
			_update_tray_state()
			return


func _remove_blank(blank: GrammarButton) -> void:
	if answered:
		return
	var i := int(blank.get_meta("blank_index", -1))
	if i < 0 or i >= _blank_words.size():
		return
	var word: String = _blank_words[i]
	if word == "":
		return
	Sfx.click()
	_blank_words[i] = ""
	blank.text = "(%d)" % (i + 1)
	blank.clear_selected_state()
	if i < _blank_sources.size() and _blank_sources[i] is GrammarButton:
		var bank_btn: GrammarButton = _blank_sources[i]
		bank_btn.disabled = false
		_blank_sources[i] = null
	_update_tray_state()


func _select_word(button: GrammarButton, word: String) -> void:
	if answered or button.disabled:
		return
	Sfx.click()
	button.disabled = true
	selected_words.append(word)

	var answer_button := GrammarButton.new()
	answer_button.variant = GrammarButton.ButtonVariant.SECONDARY
	answer_button.play_click_sound = false
	answer_button.neutral_states = true
	answer_button.text = word
	answer_button.custom_minimum_size = Vector2(_word_button_width, 0)
	answer_button.min_height = 64
	answer_button.no_clip = true
	answer_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	answer_button.set_selected_state()
	answer_button.set_meta("source_button", button)
	answer_button.pressed.connect(func() -> void: _remove_word(answer_button))
	answer_container.add_child(answer_button)
	GrammarAnimation.appear(answer_button)
	_update_tray_state()


func _remove_word(answer_button: GrammarButton) -> void:
	if answered:
		return
	Sfx.click()
	var word := answer_button.text
	var index := selected_words.find(word)
	if index >= 0:
		selected_words.remove_at(index)
	var source_button = answer_button.get_meta("source_button", null)
	if source_button is GrammarButton:
		source_button.disabled = false
	answer_button.queue_free()
	_update_tray_state()


func _check_answer() -> void:
	if answered:
		return
	var items: Array = exercise_data.get("items", [])
	var item: Dictionary = items[current_index]
	var correct := false

	if _blanks_mode:
		correct = _check_blanks_answer(item)
	else:
		var expected := _normalize_unscramble(str(item.get("answer", "")))
		var actual := _normalize_unscramble(" ".join(selected_words))
		correct = (actual == expected)

	answered = true
	if correct:
		GrammarAnimation.correct(answer_card)
		submit_result(true, "عالی! جمله کاملاً درست است.")
	else:
		GrammarAnimation.wrong(answer_card)
		submit_result(false, "ترتیب کلمات هنوز درست نیست. دوباره امتحان کن.")


func _check_blanks_answer(item: Dictionary) -> bool:
	var expected: Array = item.get("answer", [])
	if expected.size() != _blank_words.size():
		return false
	for i in range(expected.size()):
		var a := str(_blank_words[i]).to_lower().strip_edges()
		var b := str(expected[i]).to_lower().strip_edges()
		if a != b:
			return false
	return true


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
		hint = str(item.get("fa", ""))
	if hint.is_empty():
		hint = "کلمات را طوری مرتب کن که یک جملهٔ درست و معنادار بسازی."
	return hint


func _normalize_unscramble(s: String) -> String:
	var out := s.strip_edges().to_lower()
	while out.contains("  "):
		out = out.replace("  ", " ")
	for punct in [" .", " ?", " ,", " ،", " ؟", " !", " :", " ;"]:
		out = out.replace(punct, punct.strip_edges())
	return out.strip_edges()
