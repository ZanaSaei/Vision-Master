class_name UnscrambleExercise
extends GrammarExercise


var answer_container: HFlowContainer
var words_container: HFlowContainer
var check_button: GrammarButton

var selected_words: Array[String] = []


func setup(data: Dictionary) -> void:
	super.setup(data)

	_build_ui()
	_show_item()


func _build_ui() -> void:

	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()

	root.add_theme_constant_override(
		"separation",
		18
	)

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
		19
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

	for child in answer_container.get_children():
		child.queue_free()

	for child in words_container.get_children():
		child.queue_free()

	var words: Array = items[
		current_index
	].get(
		"words",
		[]
	).duplicate()

	words.shuffle()

	for word in words:

		var button := GrammarButton.new()

		button.variant = (
			GrammarButton.ButtonVariant.SECONDARY
		)

		button.text = str(word)

		button.custom_minimum_size = Vector2(
			100,
			52
		)

		button.add_theme_font_size_override(
			"font_size",
			18
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

	answer_button.text = word

	answer_button.custom_minimum_size = Vector2(
		90,
		50
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

	var expected := str(
		item.get(
			"answer",
			""
		)
	).to_lower().strip_edges()

	var actual := " ".join(
		selected_words
	).to_lower().strip_edges()

	var correct := (
		actual == expected
	)

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


func continue_to_next() -> void:
	current_index += 1

	_show_item()
