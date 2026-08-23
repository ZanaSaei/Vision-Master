class_name UnscrambleExercise
extends GrammarExercise


var answer_container: HFlowContainer
var words_container: HFlowContainer
var check_button: GrammarButton

var selected_words: Array[String] = []

# True when the current item uses the template/word-bank ("blanks") format
# instead of the classic full-sentence unscramble format.
var _blanks_mode := false
var _blank_words: Array[String] = []
var _blank_buttons: Array[GrammarButton] = []
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

	instruction.text = str(
		exercise_data.get(
			"instruction_fa",
			"کلمات را مرتب کن."
		)
	)

	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	instruction.add_theme_font_size_override(
		"font_size",
		GrammarTheme.BODY_SIZE
	)

	instruction.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	root.add_child(
		instruction
	)

	answer_container = HFlowContainer.new()

	answer_container.alignment = (
		FlowContainer.ALIGNMENT_CENTER
	)

	answer_container.custom_minimum_size = Vector2(
		0,
		110
	)

	answer_container.add_theme_constant_override(
		"h_separation",
		8
	)

	answer_container.add_theme_constant_override(
		"v_separation",
		8
	)

	root.add_child(
		answer_container
	)

	words_container = HFlowContainer.new()

	words_container.alignment = (
		FlowContainer.ALIGNMENT_CENTER
	)

	words_container.add_theme_constant_override(
		"h_separation",
		8
	)

	words_container.add_theme_constant_override(
		"v_separation",
		8
	)

	root.add_child(
		words_container
	)

	check_button = GrammarButton.new()

	check_button.variant = (
		GrammarButton.ButtonVariant.PRIMARY
	)

	check_button.text = "بررسی ✓"

	check_button.pressed.connect(
		_check_answer
	)

	root.add_child(
		check_button
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

	selected_words.clear()
	_word_button_width = 0

	for child in answer_container.get_children():
		child.queue_free()

	for child in words_container.get_children():
		child.queue_free()

	_blanks_mode = false
	_blank_words.clear()
	_blank_buttons.clear()
	_bank_buttons.clear()

	var item: Dictionary = items[current_index]

	if item.has("template") and item.has("options"):
		_blanks_mode = true
		_show_blanks_item(item)
	else:
		_show_sentence_item(item)


func _measure_uniform_word_width(words: Array) -> int:
	var font: Font = GrammarTheme.get_fa_bold()
	var widest: float = 0.0

	for w in words:
		var s := str(w)
		widest = maxf(
			widest,
			GrammarTheme.measure_text(
				font,
				s,
				GrammarTheme.BUTTON_FONT_SIZE,
				-1.0,
				HORIZONTAL_ALIGNMENT_LEFT
			).x
		)

	var width := int(ceil(widest + 34.0))
	if width < 80:
		width = 80
	return width


# Classic format: shuffle all words, user taps them in order to build
# the full sentence.
func _show_sentence_item(item: Dictionary) -> void:

	var words: Array = item.get(
		"words",
		[]
	).duplicate()

	_word_button_width = _measure_uniform_word_width(words)

	words.shuffle()

	for word in words:

		var button := GrammarButton.new()

		button.variant = (
			GrammarButton.ButtonVariant.SECONDARY
		)

		button.play_click_sound = false
		button.neutral_states = true

		button.text = str(word)

		# All word chips use the size of the largest word in the item so
		# the row stays visually even and no letters get clipped.
		button.custom_minimum_size = Vector2(
			_word_button_width,
			0
		)

		button.min_height = 62

		button.no_clip = true

		button.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER
		)

		button.add_theme_font_size_override(
			"font_size",
			GrammarTheme.BUTTON_FONT_SIZE
		)

		button.pressed.connect(
			func():
				_select_word(
					button,
					str(word)
				)
		)

		words_container.add_child(
			button
		)

		GrammarAnimation.appear(
			button
		)


# Blank-fill format: a template sentence with ______ slots and a numbered
# word bank. The user taps bank words to fill the blanks in order.
func _show_blanks_item(item: Dictionary) -> void:

	var template := str(item.get("template", ""))

	var parts := template.split("______")

	for i in range(parts.size()):

		var part := parts[i].strip_edges()

		if not part.is_empty():

			var label := Label.new()

			label.text = part

			# Deliberately NO autowrap: inside the HFlowContainer, an
			# autowrapping label collapses to its minimum (single-letter)
			# width and wraps vertically. Each template segment should
			# render at its full text width on one line and flow inline.
			label.size_flags_horizontal = (
				Control.SIZE_SHRINK_CENTER
			)

			label.add_theme_font_size_override(
				"font_size",
				GrammarTheme.BODY_LARGE_SIZE
			)

			label.add_theme_color_override(
				"font_color",
				GrammarTheme.TEXT
			)

			answer_container.add_child(
				label
			)

		if i < parts.size() - 1:

			var blank := GrammarButton.new()

			blank.variant = (
				GrammarButton.ButtonVariant.SECONDARY
			)

			blank.play_click_sound = false
			blank.neutral_states = true

			blank.text = "%d" % (i + 1)

			# Compact slot so the blank fits inline with the sentence text
			# instead of a giant box. 52px wide gives a tappable square;
			# it grows to fit a filled-in word.
			blank.custom_minimum_size = Vector2(
				52,
				0
			)

			blank.min_height = 54

			blank.no_clip = true

			blank.size_flags_horizontal = (
				Control.SIZE_SHRINK_CENTER
			)

			blank.add_theme_font_size_override(
				"font_size",
				GrammarTheme.BODY_LARGE_SIZE
			)

			blank.set_meta(
				"blank_index",
				i
			)

			blank.pressed.connect(
				func():
					_remove_blank(blank)
			)

			_blank_buttons.append(
				blank
			)

			answer_container.add_child(
				blank
			)

			_blank_words.append("")

	var options: Array = item.get(
		"options",
		[]
	).duplicate()

	_word_button_width = _measure_uniform_word_width(options)

	options.shuffle()

	for w in options:

		var word := str(w)

		var btn := GrammarButton.new()

		btn.variant = (
			GrammarButton.ButtonVariant.SECONDARY
		)

		btn.play_click_sound = false
		btn.neutral_states = true

		btn.text = word

		# All bank words share the size of the largest word in the item.
		btn.custom_minimum_size = Vector2(
			_word_button_width,
			0
		)

		btn.min_height = 62

		btn.no_clip = true

		btn.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER
		)

		btn.add_theme_font_size_override(
			"font_size",
			GrammarTheme.BUTTON_FONT_SIZE
		)

		btn.pressed.connect(
			func():
				_fill_blank(btn, word)
		)

		_bank_buttons[word] = btn

		words_container.add_child(
			btn
		)

		GrammarAnimation.appear(
			btn
		)


func _fill_blank(btn: GrammarButton, word: String) -> void:

	if answered or btn.disabled:
		return

	for i in range(_blank_words.size()):
		if _blank_words[i] == "":
			_blank_words[i] = word
			_blank_buttons[i].text = word
			btn.disabled = true
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

	_blank_words[i] = ""

	blank.text = "%d" % (i + 1)

	var bank_btn = _bank_buttons.get(word)

	if bank_btn is GrammarButton:
		bank_btn.disabled = false


func _select_word(
	button: GrammarButton,
	word: String
) -> void:

	if button.disabled:
		return

	button.disabled = true

	selected_words.append(
		word
	)

	var answer_button := GrammarButton.new()

	answer_button.variant = (
		GrammarButton.ButtonVariant.SECONDARY
	)

	answer_button.play_click_sound = false
	answer_button.neutral_states = true

	answer_button.text = word

	# Share the same width as the largest word in the current item.
	answer_button.custom_minimum_size = Vector2(
		_word_button_width,
		0
	)

	answer_button.no_clip = true

	answer_button.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)

	answer_button.set_meta(
		"source_button",
		button
	)

	answer_button.pressed.connect(
		func():
			_remove_word(
				answer_button
			)
	)

	answer_container.add_child(
		answer_button
	)

	GrammarAnimation.appear(
		answer_button
	)


func _remove_word(
	answer_button: GrammarButton
) -> void:

	var word := answer_button.text

	var index := selected_words.find(
		word
	)

	if index >= 0:
		selected_words.remove_at(
			index
		)

	var source_button = answer_button.get_meta(
		"source_button",
		null
	)

	if source_button is GrammarButton:
		source_button.disabled = false

	answer_button.queue_free()


func _check_answer() -> void:

	if answered:
		return

	var items: Array = exercise_data.get(
		"items",
		[]
	)

	var item: Dictionary = items[
		current_index
	]

	var correct := false

	if _blanks_mode:
		correct = _check_blanks_answer(item)
	else:
		var expected := str(
			item.get(
				"answer",
				""
			)
		).to_lower().strip_edges()

		var actual := " ".join(
			selected_words
		).to_lower().strip_edges()

		correct = (actual == expected)

	answered = true

	if correct:

		submit_result(
			true,
			"🎉 عالی! جمله کاملاً درست است."
		)

	else:

		submit_result(
			false,
			"ترتیب کلمات هنوز درست نیست. دوباره امتحان کن."
		)


func _check_blanks_answer(item: Dictionary) -> bool:

	var expected: Array = item.get(
		"answer",
		[]
	)

	if expected.size() != _blank_words.size():
		return false

	for i in range(expected.size()):

		var a := str(
			_blank_words[i]
		).to_lower().strip_edges()

		var b := str(
			expected[i]
		).to_lower().strip_edges()

		if a != b:
			return false

	return true


func continue_to_next() -> void:
	current_index += 1

	_show_item()


func retry_current() -> void:
	# Rebuild the current item so the learner can re-arrange the words.
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
