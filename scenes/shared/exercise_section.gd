extends VBoxContainer

# ============================================================
#  EXERCISE SECTION — reusable interactive component
#  Instance this scene and call setup(exercises) from any
#  content scene (Conversation, Reading, Grammar, etc.) to
#  render the book's actual checkable activities.
#
#  Supported exercise "type" values:
#    multiple_choice | true_false | matching | fill_blank |
#    ordering | short_answer
# ============================================================

const CORRECT_COLOR := Color("#16A34A")
const WRONG_COLOR    := Color("#DC2626")
const NEUTRAL_COLOR  := Color("#E2E8F0")
const ACCENT_COLOR   := Color("#2563EB")

# Internal state per exercise, keyed by exercise index
var _exercise_widgets: Array = []


func setup(exercises: Array) -> void:
	for child in get_children():
		child.queue_free()
	_exercise_widgets.clear()

	if exercises.is_empty():
		return

	var header := Label.new()
	header.text = "📝 تمرین‌ها"
	header.add_theme_font_size_override("font_size", 46)
	header.add_theme_color_override("font_color", ACCENT_COLOR)
	header.text_direction = Control.TEXT_DIRECTION_RTL
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(header)

	for i in exercises.size():
		var ex: Dictionary = exercises[i]
		var card := _build_exercise_card(i, ex)
		add_child(card)

	var check_button := Button.new()
	check_button.text = "بررسی پاسخ‌ها"
	check_button.custom_minimum_size = Vector2(0, 70)
	check_button.add_theme_font_size_override("font_size", 44)
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT_COLOR
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	check_button.add_theme_stylebox_override("normal", style)
	check_button.add_theme_color_override("font_color", Color.WHITE)
	check_button.pressed.connect(_on_check_pressed)
	add_child(check_button)


func _build_exercise_card(index: int, ex: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F8FAFC")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)

	# Instruction / prompt text
	var prompt := Label.new()
	prompt.text = ex.get("prompt", "")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD
	prompt.add_theme_font_size_override("font_size", 44)
	prompt.text_direction = Control.TEXT_DIRECTION_RTL
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(prompt)

	var type: String = ex.get("type", "")
	match type:
		"multiple_choice":
			inner.add_child(_build_multiple_choice(index, ex))
		"true_false":
			inner.add_child(_build_true_false(index, ex))
		"matching":
			inner.add_child(_build_matching(index, ex))
		"fill_blank":
			inner.add_child(_build_fill_blank(index, ex))
		"ordering":
			inner.add_child(_build_ordering(index, ex))
		"short_answer":
			inner.add_child(_build_short_answer(index, ex))
		_:
			push_warning("Unknown exercise type: " + type)

	card.add_child(inner)
	return card


# ----------------------------------------------------------------
#  MULTIPLE CHOICE
# ----------------------------------------------------------------
func _build_multiple_choice(index: int, ex: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var group := ButtonGroup.new()
	var option_buttons: Array = []

	for option in ex.get("options", []):
		var btn := Button.new()
		btn.text = option
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 42)
		box.add_child(btn)
		option_buttons.append(btn)

	_exercise_widgets.append({
		"index": index, "type": "multiple_choice",
		"buttons": option_buttons, "correct": ex.get("correct_index", 0)
	})
	return box


# ----------------------------------------------------------------
#  TRUE / FALSE
# ----------------------------------------------------------------
func _build_true_false(index: int, ex: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var group := ButtonGroup.new()
	var true_btn := Button.new()
	true_btn.text = "درست"
	true_btn.toggle_mode = true
	true_btn.button_group = group
	true_btn.custom_minimum_size = Vector2(0, 60)
	true_btn.add_theme_font_size_override("font_size", 42)
	true_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var false_btn := Button.new()
	false_btn.text = "نادرست"
	false_btn.toggle_mode = true
	false_btn.button_group = group
	false_btn.custom_minimum_size = Vector2(0, 60)
	false_btn.add_theme_font_size_override("font_size", 42)
	false_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(true_btn)
	row.add_child(false_btn)

	_exercise_widgets.append({
		"index": index, "type": "true_false",
		"true_btn": true_btn, "false_btn": false_btn,
		"correct": ex.get("correct", true)
	})
	return row


# ----------------------------------------------------------------
#  MATCHING (dropdown per left-item — simple & reliable on mobile)
# ----------------------------------------------------------------
func _build_matching(index: int, ex: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var left_items: Array = ex.get("left", [])
	var right_items: Array = ex.get("right", [])
	var correct_map: Array = ex.get("correct_map", [])  # e.g. [2,0,1] means left[0]→right[2]

	var dropdowns: Array = []

	for i in left_items.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var left_label := Label.new()
		left_label.text = left_items[i]
		left_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		left_label.add_theme_font_size_override("font_size", 40)
		left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_label.text_direction = Control.TEXT_DIRECTION_RTL
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var dropdown := OptionButton.new()
		for j in right_items.size():
			dropdown.add_item(right_items[j], j)
		dropdown.custom_minimum_size = Vector2(220, 60)

		row.add_child(left_label)
		row.add_child(dropdown)
		box.add_child(row)
		dropdowns.append(dropdown)

	_exercise_widgets.append({
		"index": index, "type": "matching",
		"dropdowns": dropdowns, "correct": correct_map
	})
	return box


# ----------------------------------------------------------------
#  FILL IN THE BLANK (supports multiple blanks via {0}, {1}, ...)
# ----------------------------------------------------------------
func _build_fill_blank(index: int, ex: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var sentence: String = ex.get("sentence", "")
	var blanks: Array = ex.get("accepted_answers", [])  # array of arrays (accepted answers per blank)
	var parts := sentence.split("___")

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)

	var line_edits: Array = []

	for i in parts.size():
		var text_lbl := Label.new()
		text_lbl.text = parts[i]
		text_lbl.add_theme_font_size_override("font_size", 42)
		flow.add_child(text_lbl)

		if i < parts.size() - 1:
			var edit := LineEdit.new()
			edit.custom_minimum_size = Vector2(160, 55)
			edit.add_theme_font_size_override("font_size", 40)
			flow.add_child(edit)
			line_edits.append(edit)

	box.add_child(flow)

	_exercise_widgets.append({
		"index": index, "type": "fill_blank",
		"line_edits": line_edits, "correct": blanks
	})
	return box


# ----------------------------------------------------------------
#  ORDERING (tap words in order to build the sentence)
# ----------------------------------------------------------------
func _build_ordering(index: int, ex: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var words: Array = ex.get("words", []).duplicate()
	words.shuffle()
	var correct_sentence: String = ex.get("correct_sentence", "")

	var assembly_label := Label.new()
	assembly_label.text = "..."
	assembly_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	assembly_label.add_theme_font_size_override("font_size", 44)
	assembly_label.add_theme_color_override("font_color", ACCENT_COLOR)
	var assembly_panel := PanelContainer.new()
	var assembly_style := StyleBoxFlat.new()
	assembly_style.bg_color = Color("#EFF6FF")
	assembly_style.corner_radius_top_left = 10
	assembly_style.corner_radius_top_right = 10
	assembly_style.corner_radius_bottom_left = 10
	assembly_style.corner_radius_bottom_right = 10
	assembly_style.content_margin_left = 12
	assembly_style.content_margin_right = 12
	assembly_style.content_margin_top = 10
	assembly_style.content_margin_bottom = 10
	assembly_panel.add_theme_stylebox_override("panel", assembly_style)
	assembly_panel.add_child(assembly_label)
	box.add_child(assembly_panel)

	var word_flow := HFlowContainer.new()
	word_flow.add_theme_constant_override("h_separation", 8)
	word_flow.add_theme_constant_override("v_separation", 8)

	var assembled: Array = []

	var reset_btn := Button.new()
	reset_btn.text = "شروع دوباره"
	reset_btn.custom_minimum_size = Vector2(0, 50)

	for word in words:
		var btn := Button.new()
		btn.text = word
		btn.custom_minimum_size = Vector2(0, 55)
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(func():
			if btn.visible:
				assembled.append(word)
				assembly_label.text = " ".join(assembled)
				btn.visible = false
		)
		word_flow.add_child(btn)

	reset_btn.pressed.connect(func():
		assembled.clear()
		assembly_label.text = "..."
		for child in word_flow.get_children():
			child.visible = true
	)

	box.add_child(word_flow)
	box.add_child(reset_btn)

	_exercise_widgets.append({
		"index": index, "type": "ordering",
		"assembly_label": assembly_label, "correct": correct_sentence
	})
	return box


# ----------------------------------------------------------------
#  SHORT ANSWER (free text — self-check via model answer reveal)
# ----------------------------------------------------------------
func _build_short_answer(index: int, ex: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var text_edit := TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 100)
	text_edit.add_theme_font_size_override("font_size", 40)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(text_edit)

	var reveal_btn := Button.new()
	reveal_btn.text = "نمایش پاسخ نمونه"
	reveal_btn.custom_minimum_size = Vector2(0, 50)

	var model_label := Label.new()
	model_label.text = ex.get("model_answer", "")
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	model_label.add_theme_font_size_override("font_size", 40)
	model_label.add_theme_color_override("font_color", Color("#16A34A"))
	model_label.visible = false

	reveal_btn.pressed.connect(func(): model_label.visible = true)

	box.add_child(reveal_btn)
	box.add_child(model_label)

	# Short answer isn't auto-graded, so it's excluded from _exercise_widgets
	return box


# ----------------------------------------------------------------
#  CHECK ANSWERS — grades every widget type at once
# ----------------------------------------------------------------
func _on_check_pressed() -> void:
	for w in _exercise_widgets:
		match w["type"]:
			"multiple_choice":
				_grade_multiple_choice(w)
			"true_false":
				_grade_true_false(w)
			"matching":
				_grade_matching(w)
			"fill_blank":
				_grade_fill_blank(w)
			"ordering":
				_grade_ordering(w)


func _grade_multiple_choice(w: Dictionary) -> void:
	var buttons: Array = w["buttons"]
	var correct_idx: int = w["correct"]
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i == correct_idx:
			btn.modulate = CORRECT_COLOR
		elif btn.button_pressed:
			btn.modulate = WRONG_COLOR


func _grade_true_false(w: Dictionary) -> void:
	var true_btn: Button = w["true_btn"]
	var false_btn: Button = w["false_btn"]
	var correct: bool = w["correct"]

	if correct:
		true_btn.modulate = CORRECT_COLOR
		if false_btn.button_pressed:
			false_btn.modulate = WRONG_COLOR
	else:
		false_btn.modulate = CORRECT_COLOR
		if true_btn.button_pressed:
			true_btn.modulate = WRONG_COLOR


func _grade_matching(w: Dictionary) -> void:
	var dropdowns: Array = w["dropdowns"]
	var correct_map: Array = w["correct"]
	for i in dropdowns.size():
		var dd: OptionButton = dropdowns[i]
		if i < correct_map.size() and dd.selected == correct_map[i]:
			dd.modulate = CORRECT_COLOR
		else:
			dd.modulate = WRONG_COLOR


func _grade_fill_blank(w: Dictionary) -> void:
	var line_edits: Array = w["line_edits"]
	var accepted: Array = w["correct"]
	for i in line_edits.size():
		var edit: LineEdit = line_edits[i]
		var answer := edit.text.strip_edges().to_lower()
		var accepted_list: Array = accepted[i] if i < accepted.size() else []
		var is_correct := false
		for valid in accepted_list:
			if answer == String(valid).to_lower():
				is_correct = true
				break
		edit.modulate = CORRECT_COLOR if is_correct else WRONG_COLOR


func _grade_ordering(w: Dictionary) -> void:
	var label: Label = w["assembly_label"]
	var correct: String = w["correct"]
	var built := label.text.strip_edges().to_lower()
	if built == correct.strip_edges().to_lower():
		label.add_theme_color_override("font_color", CORRECT_COLOR)
	else:
		label.add_theme_color_override("font_color", WRONG_COLOR)
