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
# The exact bank button that currently fills each blank, so re-enabling on
# removal is precise even when the word bank contains duplicate words.
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

	# Instructions are Persian; force the RTL base direction so embedded
	# English tokens (will, going to, ...) cannot scramble the line.
	instruction.text = GrammarTheme.bidi_fix(
		instruction.text
	)
	instruction.text_direction = (
		Control.TEXT_DIRECTION_RTL
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

	# Constrain to the parent width so long text wraps inside the card
	# instead of spilling past the screen edge.
	answer_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
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

	# Constrain to the parent width so long words wrap inside the card
	# instead of spilling past the screen edge.
	words_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
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

	check_button.min_height = 112

	check_button.font_size = 46

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
	_blank_sources.clear()
	_bank_buttons.clear()

	var item: Dictionary = items[current_index]

	if item.has("template") and item.has("options"):
		_blanks_mode = true
		_show_blanks_item(item)
	else:
		_show_sentence_item(item)

	# After the container is laid out, cap every child's width to the
	# available width so no long text/word can ever overflow the screen.
	call_deferred("_constrain_flow_widths")


func _constrain_flow_widths() -> void:
	# Available width = this exercise's own width (the card's content
	# area), with a tiny safety margin. Fall back to a sane value if the
	# layout hasn't happened yet.
	var avail: float = size.x
	if avail <= 0.0:
		avail = 1000.0
	avail -= 8.0
	_cap_flow_container(answer_container, avail)
	_cap_flow_container(words_container, avail)


func _cap_flow_container(container: Container, avail: float) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Label:
			# Only wrap text that would actually be wider than the card,
			# so short inline segments keep their normal inline layout.
			var font: Font = child.get_theme_font("font")
			var fsize: int = child.get_theme_font_size("font_size")
			var tw: Vector2 = GrammarTheme.measure_text(
				font,
				child.text,
				fsize,
				-1.0,
				HORIZONTAL_ALIGNMENT_LEFT
			)
			if tw.x > avail:
				# Give the wrapped text a real, bounded width so it wraps
				# at word boundaries instead of spilling off the screen
				# or collapsing into a narrow vertical strip.
				child.custom_minimum_size = Vector2(avail, 0)
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif child is Button:
			if child.custom_minimum_size.x > avail:
				child.custom_minimum_size = Vector2(
					avail,
					child.custom_minimum_size.y
				)


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

			GrammarTheme.set_bidi_text(
				label,
				part
			)

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
				GrammarTheme.text_color()
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
			_blank_sources.append(null)

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
			if i < _blank_sources.size():
				_blank_sources[i] = btn
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

	# Re-enable the exact bank button that filled this blank. Using the
	# recorded source (not a word->button lookup) keeps duplicate words in
	# the bank from re-enabling the wrong chip.
	if i < _blank_sources.size() and _blank_sources[i] is GrammarButton:
		var bank_btn: GrammarButton = _blank_sources[i]
		bank_btn.disabled = false
		_blank_sources[i] = null


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
		var expected := _normalize_unscramble(str(item.get("answer", "")))
		var actual := _normalize_unscramble(" ".join(selected_words))

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


# Normalizes an assembled unscramble sentence so grading matches the neat
# stored answers: lowercase, collapse spaces, strip spaces before . ? , ، ؟.
func _normalize_unscramble(s: String) -> String:
	var out := s.strip_edges().to_lower()
	while out.contains("  "):
		out = out.replace("  ", " ")
	for punct in [" .", " ?", " ,", " ،", " ؟", " !", " :", " ;"]:
		out = out.replace(punct, punct.strip_edges())
	return out.strip_edges()
