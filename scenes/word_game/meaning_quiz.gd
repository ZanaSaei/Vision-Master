extends "res://autoload/BackButtonHandler.gd"

const HUB_SCENE := "res://scenes/word_game/WordGameHub.tscn"
const OPTIONS_COUNT := 4
const DATA_PATH := "res://data/extracted_words.json"
const FONT: FontFile = preload("res://assets/fonts/Vazirmatn-Regular.ttf")

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var title_label: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var content: VBoxContainer = $Content

var _mode: String = ""
var _book: int = 1
var _lesson: int = 1
var _questions: Array[Dictionary] = []
var _question_index: int = 0
var _timer: Timer


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_timer = Timer.new()
	_timer.wait_time = 0.1
	_timer.timeout.connect(_on_learning_timer_tick)
	add_child(_timer)
	_show_modes()


func _on_back_pressed() -> void:
	if _mode == "question" or _mode == "result":
		_timer.stop()
		_show_modes()
		return
	if _mode == "lesson_select":
		_show_book_select()
		return
	if _mode == "book_select":
		_show_modes()
		return
	get_tree().change_scene_to_file(HUB_SCENE)


func _on_android_back_pressed() -> void:
	_on_back_pressed()


func _show_modes() -> void:
	_mode = "select"
	_clear_content()
	title_label.text = "بازی معنی"
	var heading: Label = _make_label("یک شیوه را برای تمرین انتخاب کنید", 38, true)
	content.add_child(heading)
	_animate_in(heading, 0)
	var learning: Button = _make_button("یادگیری درس\nبدون زمان و امتیاز")
	learning.pressed.connect(_show_book_select)
	content.add_child(learning)
	_animate_in(learning, 1)


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style




func _show_book_select() -> void:
	_mode = "book_select"
	_clear_content()
	title_label.text = "یادگیری · انتخاب کتاب"
	content.add_child(_make_label("کتاب موردنظر را انتخاب کنید", 38, true))
	var found_book: bool = false
	for book: int in [1, 2, 3]:
		var path: String = "res://data/v%d_vocabularies.json" % book
		if not FileAccess.file_exists(path):
			continue
		found_book = true
		var button: Button = _make_button("Vision %d" % book)
		button.pressed.connect(_show_lesson_select.bind(book))
		content.add_child(button)
	if not found_book:
		_show_message("فایل واژگان کتاب‌ها پیدا نشد.")


func _show_lesson_select(book: int) -> void:
	_book = book
	_mode = "lesson_select"
	_clear_content()
	title_label.text = "یادگیری · کتاب %d" % book
	content.add_child(_make_label("درس را انتخاب کنید", 38, true))
	var lessons: Array[int] = _get_book_lessons(book)
	for lesson: int in lessons:
		var button: Button = _make_button("درس %d" % lesson)
		button.pressed.connect(_start_learning.bind(book, lesson))
		content.add_child(button)
	if lessons.is_empty():
		content.add_child(_make_label("درسی برای این کتاب پیدا نشد.", 28, true))


func _start_learning(book: int, lesson: int) -> void:
	_book = book
	_lesson = lesson
	_questions = _load_lesson_words(book, lesson)
	if _questions.size() < OPTIONS_COUNT:
		_show_message("این درس برای ساخت پرسش به دست‌کم چهار واژه نیاز دارد.")
		return
	_questions.shuffle()
	_mode = "question"
	_question_index = 0
	_show_question()


func _show_question() -> void:
	_timer.stop()
	_clear_content()
	if _question_index >= _questions.size():
		_show_result()
		return
	var entry: Dictionary = _questions[_question_index]
	title_label.text = "پرسش %d از %d" % [_question_index + 1, _questions.size()]
	content.add_child(_make_question_card("واژه را به معنی درست وصل کنید", str(entry.get("word", "")), true))
	var options: Array[String] = _make_options(entry, true)
	for option: String in options:
		var answer_button: Button = _make_button(option)
		_style_answer_button(answer_button, option == str(entry.get("_correct", "")))
		answer_button.pressed.connect(_answer.bind(option, entry, true))
		content.add_child(answer_button)
		_animate_in(answer_button, content.get_child_count() - 1)


func _make_question_card(question: String, word: String, learning: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 230)
	panel.add_theme_stylebox_override("panel", _card_style(Color("#FFFFFF"), Color("#A5B4FC")))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_make_label("واژه را به معنی درست وصل کنید" if learning else "گزینهٔ درست را انتخاب کنید", 26, true))
	var prompt: Label = _make_label(question, 42, true)
	prompt.custom_minimum_size = Vector2(0, 80)
	column.add_child(prompt)
	var word_label: Label = _make_label(word, 54, true)
	word_label.text_direction = Control.TEXT_DIRECTION_LTR
	word_label.add_theme_color_override("font_color", Color("#1D4ED8"))
	column.add_child(word_label)
	return panel


func _answer(option: String, entry: Dictionary, _learning: bool) -> void:
	if option == str(entry.get("_correct", entry.get("answer", ""))):
		_question_index += 1
		_show_question()


func _show_result() -> void:
	_mode = "result"
	_clear_content()
	title_label.text = "نتیجه"
	content.add_child(_make_label("درس به پایان رسید", 42, true))
	content.add_child(_make_label("آفرین! تمرین این درس تمام شد.", 34, true))
	var again: Button = _make_button("بازگشت به درس‌ها")
	again.pressed.connect(_show_modes)
	content.add_child(again)


func _on_learning_timer_tick() -> void:
	_timer.stop()


func _make_options(entry: Dictionary, learning: bool) -> Array[String]:
	if not learning:
		var question_options: Array[String] = []
		for option: Variant in entry.get("options", []):
			question_options.append(str(option))
		return question_options
	var correct: String = str(entry.get("meaning_fa", ""))
	entry["_correct"] = correct
	var candidates: Array[String] = []
	for other: Dictionary in _questions:
		var value: String = str(other.get("meaning_fa", "") if learning else other.get("word", ""))
		if value != correct and not candidates.has(value):
			candidates.append(value)
	var bank: Array[Dictionary] = _load_extracted_words() if not learning else _load_lesson_words(_book, _lesson)
	for other: Dictionary in bank:
		var value: String = str(other.get("meaning_fa", "") if learning else other.get("word", ""))
		if value != correct and value != "" and not candidates.has(value):
			candidates.append(value)
	candidates.shuffle()
	var options: Array[String] = [correct]
	for i: int in mini(OPTIONS_COUNT - 1, candidates.size()):
		options.append(candidates[i])
	options.shuffle()
	return options


func _load_extracted_words() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(DATA_PATH):
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Array:
		return result
	for raw: Variant in parsed:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		if str(entry.get("word", "")).is_empty() or str(entry.get("meaning_fa", "")).is_empty():
			continue
		result.append(entry.duplicate())
	return result


func _load_lesson_words(book: int, lesson: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var path: String = "res://data/v%d_vocabularies.json" % book
	if not FileAccess.file_exists(path):
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		return result
	for lesson_data: Variant in parsed:
		if not lesson_data is Dictionary or int(lesson_data.get("book", 0)) != book or int(lesson_data.get("lesson", 0)) != lesson:
			continue
		var vocabulary: Dictionary = lesson_data.get("vocabulary", {})
		var words: Variant = vocabulary.get("words", [])
		if not words is Array:
			return result
		for raw: Variant in words:
			if raw is Dictionary:
				var entry: Dictionary = raw
				if not str(entry.get("word", "")).is_empty() and not str(entry.get("meaning_fa", "")).is_empty():
					result.append(entry.duplicate())
		return result
	return result


func _get_book_lessons(book: int) -> Array[int]:
	var result: Array[int] = []
	var path: String = "res://data/v%d_vocabularies.json" % book
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Array:
		return result
	for raw: Variant in parsed:
		if raw is Dictionary and int(raw.get("book", 0)) == book:
			result.append(int(raw.get("lesson", 0)))
	result.sort()
	return result


func _make_label(text: String, font_size: int, centered: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#17324D"))
	return label


func _style_answer_button(button: Button, _is_correct: bool) -> void:
	button.custom_minimum_size = Vector2(0, 118)
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color("#172554"))
	var base: StyleBoxFlat = _card_style(Color("#FFFFFF"), Color("#CBD5E1"))
	button.add_theme_stylebox_override("normal", base)
	button.add_theme_stylebox_override("hover", _card_style(Color("#EEF2FF"), Color("#6366F1")))
	button.add_theme_stylebox_override("pressed", _card_style(Color("#DBEAFE"), Color("#2563EB")))
	button.add_theme_stylebox_override("focus", _card_style(Color("#F8FAFC"), Color("#4F46E5")))


func _animate_in(control: Control, index: int) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2(0.97, 0.97)
	control.pivot_offset = control.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_interval(0.035 * index)
	tween.tween_property(control, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 150)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color.WHITE)
	var normal: StyleBoxFlat = _card_style(Color("#2563EB"), Color("#1D4ED8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#1D4ED8")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#1E40AF")
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _show_message(message: String) -> void:
	_clear_content()
	content.add_child(_make_label(message, 34, true))


func _clear_content() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
