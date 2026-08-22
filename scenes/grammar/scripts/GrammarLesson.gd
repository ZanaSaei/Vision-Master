extends Control


const DATA_PATH := "res://data/grammar/vision1_lesson1.json"


var lesson_data: Dictionary = {}
var units: Array = []

var current_unit_index := 0
var current_question_index := 0

var xp := 0
var correct_answers := 0

var title_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var xp_label: Label

var content_container: VBoxContainer
var feedback_popup: FeedbackPopup

var next_button: Button


func _ready() -> void:
	_load_lesson()

	_build_ui()

	_show_unit()


func _load_lesson() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error(
			"Grammar JSON not found: " + DATA_PATH
		)

		return

	var file := FileAccess.open(
		DATA_PATH,
		FileAccess.READ
	)

	var text := file.get_as_text()

	var json := JSON.new()

	var error := json.parse(text)

	if error != OK:
		push_error(
			"JSON error: " +
			json.get_error_message()
		)

		return

	var data = json.data

	if not data is Dictionary:
		push_error("Grammar JSON root must be a Dictionary.")
		return

	lesson_data = data.get(
		"lesson",
		{}
	)

	units = lesson_data.get(
		"units",
		[]
	)


func _build_ui() -> void:
	var background := ColorRect.new()

	background.color = Color("#F7F9FC")

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(background)

	var safe_area := MarginContainer.new()

	safe_area.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	safe_area.add_theme_constant_override(
		"margin_left",
		18
	)

	safe_area.add_theme_constant_override(
		"margin_right",
		18
	)

	safe_area.add_theme_constant_override(
		"margin_top",
		16
	)

	safe_area.add_theme_constant_override(
		"margin_bottom",
		16
	)

	add_child(safe_area)

	var main := VBoxContainer.new()

	main.add_theme_constant_override(
		"separation",
		14
	)

	safe_area.add_child(main)

	# TOP BAR

	var top_bar := HBoxContainer.new()

	top_bar.custom_minimum_size = Vector2(0, 50)

	main.add_child(top_bar)

	var back_button := Button.new()

	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(52, 52)
	back_button.add_theme_font_size_override(
		"font_size",
		32
	)
	back_button.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT
	)
	back_button.add_theme_color_override(
		"font_hover_color",
		GrammarTheme.PRIMARY_DARK
	)
	GrammarTheme.style_secondary_button(back_button)

	back_button.pressed.connect(
		_on_back_pressed
	)

	top_bar.add_child(back_button)

	title_label = Label.new()

	title_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		21
	)
	title_label.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT
	)

	var title_font := GrammarTheme.get_fa_bold()

	if title_font != null:
		title_label.add_theme_font_override(
			"font",
			title_font
		)

	top_bar.add_child(title_label)

	xp_label = Label.new()

	xp_label.name = "XPLabel"

	xp_label.text = "⭐ 0"

	xp_label.custom_minimum_size = Vector2(65, 50)

	xp_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	xp_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	xp_label.add_theme_font_size_override(
		"font_size",
		17
	)
	xp_label.add_theme_color_override(
		"font_color",
		GrammarTheme.XP
	)
	xp_label.add_theme_font_override(
		"font",
		GrammarTheme.get_fa_bold()
	)

	top_bar.add_child(xp_label)

	# PROGRESS

	var progress_row := HBoxContainer.new()

	progress_row.add_theme_constant_override(
		"separation",
		10
	)

	main.add_child(progress_row)

	progress_label = Label.new()

	progress_label.custom_minimum_size = Vector2(70, 35)

	progress_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	progress_label.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	progress_row.add_child(progress_label)

	progress_bar = ProgressBar.new()

	progress_bar.show_percentage = false

	progress_bar.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	progress_bar.custom_minimum_size = Vector2(0, 14)

	var accent_str: String = lesson_data.get(
		"theme_color",
		""
	)

	var accent: Color = (
		Color(accent_str)
		if accent_str != ""
		else GrammarTheme.PRIMARY
	)

	progress_bar.add_theme_stylebox_override(
		"background",
		GrammarTheme.rounded_box(
			Color("#E9EDF5"),
			8
		)
	)

	progress_bar.add_theme_stylebox_override(
		"fill",
		GrammarTheme.rounded_box(
			accent,
			8
		)
	)

	progress_row.add_child(progress_bar)

	# CONTENT

	var scroll := ScrollContainer.new()

	scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	main.add_child(scroll)

	content_container = VBoxContainer.new()

	content_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	content_container.add_theme_constant_override(
		"separation",
		18
	)

	scroll.add_child(content_container)

	# FEEDBACK

	feedback_popup = FeedbackPopup.new()

	main.add_child(feedback_popup)

	feedback_popup.continue_pressed.connect(
		_on_feedback_continue
	)


func _show_unit() -> void:
	if current_unit_index >= units.size():
		_finish_lesson()
		return

	for child in content_container.get_children():
		child.queue_free()

	var unit: Dictionary = units[
		current_unit_index
	]

	var type := str(
		unit.get("type", "")
	)

	title_label.text = lesson_data.get(
		"title_fa",
		"گرامر"
	)

	progress_label.text = "%d / %d" % [
		current_unit_index + 1,
		units.size()
	]

	progress_bar.value = (
		float(current_unit_index)
		/ float(units.size())
	) * 100.0

	if type == "learn":
		_show_learning_unit(unit)

	elif type in [
	"multiple_choice",
	"fill_blank",
	"true_false",
	"matching",
	"unscramble"
	]:
		_show_exercise(unit)

	else:
		push_warning(
		"Unknown grammar unit type: " + type
		)


func _show_learning_unit(unit: Dictionary) -> void:
	var title := Label.new()

	title.text = str(
		unit.get("title_fa", "")
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		28
	)

	title.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT
	)

	content_container.add_child(title)

	GrammarAnimation.appear(title)

	var english_title := Label.new()

	english_title.text = str(
		unit.get("title_en", "")
	)

	english_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	english_title.add_theme_font_size_override(
		"font_size",
		19
	)

	english_title.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	content_container.add_child(
		english_title
	)

	var explanation_card := PanelContainer.new()

	explanation_card.custom_minimum_size = Vector2(
		0,
		150
	)

	GrammarTheme.style_card(
		explanation_card
	)

	var explanation_margin := MarginContainer.new()

	explanation_margin.add_theme_constant_override(
		"margin_left",
		18
	)

	explanation_margin.add_theme_constant_override(
		"margin_right",
		18
	)

	explanation_margin.add_theme_constant_override(
		"margin_top",
		12
	)

	explanation_margin.add_theme_constant_override(
		"margin_bottom",
		12
	)

	explanation_card.add_child(
		explanation_margin
	)

	content_container.add_child(
		explanation_card
	)

	var explanation := Label.new()

	explanation.text = str(
		unit.get("explanation", "")
	)

	explanation.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	explanation.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	explanation.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	explanation.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	explanation.add_theme_font_size_override(
		"font_size",
		19
	)

	explanation.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT
	)

	explanation_margin.add_child(explanation)

	# CARDS — structure patterns rendered as visual cards
	var cards: Array = unit.get(
		"cards",
		[]
	)

	var structure_fallback := str(
		unit.get("structure", "")
	)

	if cards.size() > 0 or structure_fallback != "":

		var cards_title := Label.new()

		cards_title.text = "ساختار"

		cards_title.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT
		)

		cards_title.add_theme_font_size_override(
			"font_size",
			21
		)

		cards_title.add_theme_color_override(
			"font_color",
			GrammarTheme.TEXT_SECONDARY
		)

		content_container.add_child(
			cards_title
		)

	if structure_fallback != "":

		var structure_label := Label.new()

		structure_label.text = structure_fallback

		structure_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		structure_label.add_theme_font_size_override(
			"font_size",
			24
		)

		content_container.add_child(
			structure_label
		)

	for card in cards:
		_add_example(card)

	# LEGACY EXAMPLES (if present alongside cards)
	var examples: Array = unit.get(
		"examples",
		[]
	)

	for example in examples:
		_add_example(
			example
		)

	next_button = Button.new()

	next_button.text = "متوجه شدم ✓"

	next_button.custom_minimum_size = Vector2(
		0,
		60
	)

	GrammarTheme.style_primary_button(
		next_button
	)

	next_button.pressed.connect(
		_on_learning_continue
	)

	content_container.add_child(
		next_button
	)

	GrammarAnimation.appear(
		next_button,
		0.2
	)


func _add_example(example: Dictionary) -> void:
	var card := PanelContainer.new()

	card.custom_minimum_size = Vector2(
		0,
		120
	)

	GrammarTheme.style_card(
		card
	)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		16
	)

	margin.add_theme_constant_override(
		"margin_right",
		16
	)

	margin.add_theme_constant_override(
		"margin_top",
		10
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		10
	)

	card.add_child(margin)

	content_container.add_child(card)

	var box := VBoxContainer.new()

	box.add_theme_constant_override(
		"separation",
		6
	)

	margin.add_child(box)

	var english := Label.new()

	english.text = str(
		example.get("en", "")
	)

	english.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	english.add_theme_font_size_override(
		"font_size",
		23
	)

	english.add_theme_color_override(
		"font_color",
		GrammarTheme.PRIMARY_DARK
	)

	english.add_theme_font_override(
		"font",
		GrammarTheme.get_en_bold()
	)

	box.add_child(english)

	var persian := Label.new()

	persian.text = str(
		example.get("fa", "")
	)

	persian.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	persian.add_theme_font_size_override(
		"font_size",
		17
	)

	persian.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	box.add_child(persian)

	GrammarAnimation.appear(
		card,
		0.1
	)


func _show_exercise(
	unit: Dictionary
) -> void:

	var type := str(
		unit.get(
			"type",
			""
		)
	)

	var exercise := ExerciseFactory.create_exercise(
		type
	)

	if exercise == null:
		return

	exercise.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	exercise.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	exercise.setup(
		unit
	)

	content_container.add_child(
		exercise
	)

	exercise.answer_selected.connect(
		_on_answer_selected
	)

	exercise.exercise_completed.connect(
		_on_exercise_completed
	)

func _on_answer_selected(
	correct: bool,
	explanation: String
) -> void:

	if correct:
		xp += int(
			lesson_data.get(
				"xp_per_correct",
				10
			)
		)

		correct_answers += 1

		_update_xp_label()

		feedback_popup.show_correct(explanation)
	else:
		feedback_popup.show_wrong(explanation)


func _update_xp_label() -> void:

	if xp_label != null:
		xp_label.text = "⭐ %d" % xp


func _on_feedback_continue() -> void:

	for child in content_container.get_children():

		if child is GrammarExercise:

			child.continue_to_next()

			return

func _get_current_exercise() -> MultipleChoiceExercise:
	for child in content_container.get_children():
		if child is MultipleChoiceExercise:
			return child

	return null


func _on_learning_continue() -> void:
	current_unit_index += 1
	_show_unit()


func _on_exercise_completed() -> void:
	current_unit_index += 1

	if current_unit_index >= units.size():
		_finish_lesson()
	else:
		_show_unit()


func _finish_lesson() -> void:
	for child in content_container.get_children():
		child.queue_free()

	progress_bar.value = 100

	var title := Label.new()

	title.text = "🎉 درس تمام شد!"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		32
	)

	content_container.add_child(title)

	var subtitle := Label.new()

	subtitle.text = "آفرین! تو اولین بخش گرامر را کامل کردی."

	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle.add_theme_font_size_override(
		"font_size",
		19
	)

	content_container.add_child(subtitle)

	var reward := Label.new()

	reward.text = "⭐ %d XP" % xp

	reward.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	reward.add_theme_font_size_override(
		"font_size",
		30
	)

	content_container.add_child(reward)

	GrammarAnimation.appear(title)
	GrammarAnimation.appear(
		reward,
		0.2
	)


func _on_back_pressed() -> void:
	TransitionManager.change_scene(
		"res://scenes/lesson_menu/LessonMenu.tscn"
	)
