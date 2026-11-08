extends "res://autoload/BackButtonHandler.gd"

const HUB_SCENE := "res://scenes/word_game/WordGameHub.tscn"
const LEARNING_SCENE := "res://scenes/word_game/WordGameLearning.tscn"
const OPTIONS_COUNT := 4
const DATA_PATH := "res://data/extracted_words.json"
const FONT: FontFile = preload("res://ui/fonts/Vazirmatn-Regular.ttf")

const BOOK_ACCENTS := {
	1: Color("#3B82F6"),
	2: Color("#22C55E"),
	3: Color("#EF4444"),
}
const FALLBACK_ACCENT := Color("#3B82F6")

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var title_label: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var content: VBoxContainer = $Content

var _mode: String = ""
var _book: int = 1
var _lesson: int = 1
var _questions: Array[Dictionary] = []
var _question_index: int = 0
var _timer: Timer

var _book_row: HBoxContainer = null
var _lesson_column: VBoxContainer = null
var _summary_label: Label = null


func _ready() -> void:
	Global.style_header($HeaderBar)
	back_button.pressed.connect(_on_back_pressed)
	_timer = Timer.new()
	_timer.wait_time = 0.1
	_timer.timeout.connect(_on_learning_timer_tick)
	add_child(_timer)
	_show_book_select()


func _on_back_pressed() -> void:
	if _mode == "question" or _mode == "result":
		_timer.stop()
		_show_book_select()
		return
	TransitionManager.change_scene_now(LEARNING_SCENE)


func _on_android_back_pressed() -> void:
	_on_back_pressed()


func _accent_for(book: int) -> Color:
	return BOOK_ACCENTS.get(book, FALLBACK_ACCENT)


func _show_book_select() -> void:
	_mode = "book_select"
	_clear_content()
	title_label.text = "بازی معنی"

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var intro := Label.new()
	intro.name = "IntroLabel"
	intro.text = "کدام کتاب و کدام درس؟"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_override("font", MenuStyle.vazir_bold())
	intro.add_theme_font_size_override("font_size", 42)
	intro.add_theme_color_override("font_color", Color("#1E293B"))
	column.add_child(intro)

	_book_row = HBoxContainer.new()
	_book_row.name = "BookRow"
	_book_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_book_row.add_theme_constant_override("separation", 14)
	column.add_child(_book_row)

	_summary_label = Label.new()
	_summary_label.name = "SummaryLabel"
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_override("font", MenuStyle.vazir())
	_summary_label.add_theme_font_size_override("font_size", 30)
	_summary_label.add_theme_color_override("font_color", Color("#64748B"))
	column.add_child(_summary_label)

	_lesson_column = VBoxContainer.new()
	_lesson_column.name = "LessonColumn"
	_lesson_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lesson_column.add_theme_constant_override("separation", 16)
	column.add_child(_lesson_column)

	_refresh_selection()


func _refresh_selection() -> void:
	if _book_row == null or _lesson_column == null:
		return
	for child in _book_row.get_children():
		_book_row.remove_child(child)
		child.queue_free()
	for child in _lesson_column.get_children():
		_lesson_column.remove_child(child)
		child.queue_free()

	var books := ScrambledData.books()
	for book_data: Dictionary in books:
		_book_row.add_child(_make_book_button(book_data))

	if books.is_empty():
		_summary_label.text = ""
		_lesson_column.add_child(_make_label("هنوز واژه‌ای در بانک ثبت نشده است.", 30, true))
		return

	var book_data := ScrambledData.book_data(_book)
	if book_data.is_empty():
		_summary_label.text = ""
		_lesson_column.add_child(_make_label("برای این کتاب درسی ثبت نشده است.", 30, true))
		return

	_summary_label.text = "%s · %s — %s درس، %s کلمه" % [
		str(book_data.get("title", "Vision %d" % _book)),
		str(book_data.get("grade_fa", "")),
		MenuStyle.persian_digits(str(book_data.get("lesson_count", 0))),
		MenuStyle.persian_digits(str(book_data.get("word_count", 0))),
	]

	var lessons: Array = book_data.get("lessons", [])
	for lesson_data: Dictionary in lessons:
		_lesson_column.add_child(_make_lesson_button(lesson_data))


func _make_book_button(book_data: Dictionary) -> Button:
	var book := int(book_data.get("book", 0))
	var accent := _accent_for(book)
	var selected := (book == _book)
	var button := Button.new()
	button.name = "Book%d" % book
	button.text = str(book_data.get("title", "Vision %d" % book))
	button.custom_minimum_size = Vector2(240, 108)
	button.add_theme_font_override("font", MenuStyle.nunito())
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_color_override("font_color", Color.WHITE if selected else Color("#334155"))

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(24)
	if selected:
		sb.bg_color = accent
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	else:
		sb.bg_color = Color.WHITE
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color("#E2E8F0")
		sb.shadow_color = Color(0, 0, 0, 0.04)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", sb)

	var sb_hover := sb.duplicate() as StyleBoxFlat
	if not selected:
		sb_hover.bg_color = Color("#F8FAFC")
	button.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb.duplicate() as StyleBoxFlat
	if not selected:
		sb_pressed.bg_color = Color("#F1F5F9")
	button.add_theme_stylebox_override("pressed", sb_pressed)
	button.add_theme_stylebox_override("focus", sb)

	button.pressed.connect(func() -> void:
		Sfx.click()
		_book = book
		_refresh_selection())
	UiMotion.wire_microinteractions(button)
	return button


func _make_lesson_button(lesson_data: Dictionary) -> Button:
	var lesson := int(lesson_data.get("lesson", 0))
	var words := int(lesson_data.get("word_count", 0))
	var title_fa := str(lesson_data.get("title_fa", ""))
	var accent := _accent_for(_book)

	var button := Button.new()
	button.name = "Lesson%d" % lesson
	button.custom_minimum_size = Vector2(0, 148)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(26)
	sb.border_width_left = 8
	sb.border_color = accent
	sb.shadow_color = Color(0, 0, 0, 0.06)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", sb)

	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color("#F8FAFC")
	button.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color("#F1F5F9")
	button.add_theme_stylebox_override("pressed", sb_pressed)
	button.add_theme_stylebox_override("focus", sb)

	button.pressed.connect(func() -> void:
		Sfx.click()
		_start_learning(_book, lesson))
	UiMotion.wire_microinteractions(button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	button.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lesson_num := MenuStyle.persian_digits(str(lesson))
	if title_fa.is_empty():
		title.text = "درس %s" % lesson_num
	else:
		title.text = "درس %s · %s" % [lesson_num, title_fa]
	title.add_theme_font_override("font", MenuStyle.vazir_bold())
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#1E293B"))
	row.add_child(title)

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	pill_sb.set_corner_radius_all(14)
	pill_sb.content_margin_left = 16
	pill_sb.content_margin_right = 16
	pill_sb.content_margin_top = 6
	pill_sb.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", pill_sb)

	var pill_label := Label.new()
	pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_label.text = "%s واژه" % MenuStyle.persian_digits(str(words))
	pill_label.add_theme_font_override("font", MenuStyle.vazir())
	pill_label.add_theme_font_size_override("font_size", 26)
	pill_label.add_theme_color_override("font_color", accent)
	pill.add_child(pill_label)
	row.add_child(pill)

	var note := Label.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.text = "تمرین واژگان، معنی و مترادف"
	note.add_theme_font_override("font", MenuStyle.vazir())
	note.add_theme_font_size_override("font_size", 26)
	note.add_theme_color_override("font_color", Color("#64748B"))
	col.add_child(note)

	return button


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
	title_label.text = "پرسش %s از %s" % [MenuStyle.persian_digits(str(_question_index + 1)), MenuStyle.persian_digits(str(_questions.size()))]
	content.add_child(_make_question_card("معنی واژهٔ زیر کدام است؟", str(entry.get("word", "")), true))
	var options: Array[String] = _make_options(entry, true)
	for option: String in options:
		var answer_button: Button = _make_button(option)
		_style_answer_button(answer_button, option == str(entry.get("_correct", "")))
		answer_button.pressed.connect(_answer.bind(answer_button, option, entry, true))
		content.add_child(answer_button)
		_animate_in(answer_button, content.get_child_count() - 1)


func _make_question_card(prompt_text: String, word: String, _learning: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 240)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_width_left = 6
	sb.border_color = _accent_for(_book)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", sb)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var prompt := _make_label(prompt_text, 28, true)
	prompt.add_theme_color_override("font_color", Color("#64748B"))
	column.add_child(prompt)

	var word_label: Label = Label.new()
	word_label.text = word
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.add_theme_font_override("font", MenuStyle.nunito())
	word_label.add_theme_font_size_override("font_size", 56)
	word_label.add_theme_color_override("font_color", _accent_for(_book))
	column.add_child(word_label)
	return panel


func _answer(button: Button, option: String, entry: Dictionary, _learning: bool) -> void:
	if option == str(entry.get("_correct", entry.get("answer", ""))):
		Sfx.click()
		_question_index += 1
		_show_question()
	else:
		UiMotion.shake(button)


func _show_result() -> void:
	_mode = "result"
	_clear_content()
	title_label.text = "نتیجه"

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 24)
	content.add_child(col)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", sb)

	var card_col := VBoxContainer.new()
	card_col.alignment = BoxContainer.ALIGNMENT_CENTER
	card_col.add_theme_constant_override("separation", 14)
	card.add_child(card_col)

	var emoji := Label.new()
	emoji.text = "🎉"
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.add_theme_font_size_override("font_size", 64)
	card_col.add_child(emoji)

	var done_lbl := _make_label("درس به پایان رسید!", 42, true)
	done_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	done_lbl.add_theme_color_override("font_color", Color("#1E293B"))
	card_col.add_child(done_lbl)

	var praise := _make_label("آفرین! تمام واژگان این درس را تمرین کردید.", 30, true)
	praise.add_theme_color_override("font_color", Color("#64748B"))
	card_col.add_child(praise)

	col.add_child(card)

	var again := Button.new()
	again.text = "بازگشت به انتخاب درس"
	again.custom_minimum_size = Vector2(0, 110)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.add_theme_font_override("font", MenuStyle.vazir_bold())
	again.add_theme_font_size_override("font_size", 34)
	again.add_theme_color_override("font_color", Color.WHITE)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color("#2563EB")
	btn_sb.set_corner_radius_all(24)
	again.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color("#1D4ED8")
	again.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed := btn_sb.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color("#1E40AF")
	again.add_theme_stylebox_override("pressed", btn_pressed)
	again.add_theme_stylebox_override("focus", btn_sb)

	again.pressed.connect(func() -> void:
		Sfx.click()
		_show_book_select())
	UiMotion.wire_microinteractions(again)
	col.add_child(again)


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
		var value: String = str(other.get("meaning_fa", ""))
		if value != correct and not candidates.has(value):
			candidates.append(value)
	var bank: Array[Dictionary] = _load_lesson_words(_book, _lesson)
	for other: Dictionary in bank:
		var value: String = str(other.get("meaning_fa", ""))
		if value != correct and value != "" and not candidates.has(value):
			candidates.append(value)
	if candidates.size() < OPTIONS_COUNT - 1:
		for l in range(1, 5):
			if candidates.size() >= OPTIONS_COUNT - 1:
				break
			var other_words := _load_lesson_words(_book, l)
			for other: Dictionary in other_words:
				var value: String = str(other.get("meaning_fa", ""))
				if value != correct and value != "" and not candidates.has(value):
					candidates.append(value)
	candidates.shuffle()
	var options: Array[String] = [correct]
	for i: int in mini(OPTIONS_COUNT - 1, candidates.size()):
		options.append(candidates[i])
	options.shuffle()
	return options


func _load_lesson_words(book: int, lesson: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var path: String = "res://data/v%d_vocabularies.json" % book
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			for lesson_data: Variant in parsed:
				if not lesson_data is Dictionary or int(lesson_data.get("book", 0)) != book or int(lesson_data.get("lesson", 0)) != lesson:
					continue
				var vocabulary: Dictionary = lesson_data.get("vocabulary", {})
				var words: Variant = vocabulary.get("words", [])
				if words is Array:
					for raw: Variant in words:
						if raw is Dictionary:
							var entry: Dictionary = raw
							if not str(entry.get("word", "")).is_empty() and not str(entry.get("meaning_fa", "")).is_empty():
								result.append(entry.duplicate())
					if result.size() >= OPTIONS_COUNT:
						return result
	# Fallback to ScrambledData when v%d_vocabularies was missing or too short.
	var seen: Dictionary = {}
	for entry: Dictionary in result:
		seen[str(entry.get("word", ""))] = true
	var fallback_words: Array = ScrambledData.words(book, lesson)
	for w: Variant in fallback_words:
		if not w is Dictionary:
			continue
		var fallback_entry: Dictionary = w
		var fallback_word: String = str(fallback_entry.get("word", ""))
		var fallback_meaning: String = str(fallback_entry.get("meaning_fa", fallback_entry.get("meaning", "")))
		if fallback_word.is_empty() or fallback_meaning.is_empty() or seen.has(fallback_word):
			continue
		seen[fallback_word] = true
		result.append({"word": fallback_word, "meaning_fa": fallback_meaning})
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
	button.add_theme_font_override("font", MenuStyle.vazir())
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color("#1E293B"))

	var base := StyleBoxFlat.new()
	base.bg_color = Color.WHITE
	base.set_corner_radius_all(24)
	base.border_width_left = 2
	base.border_width_top = 2
	base.border_width_right = 2
	base.border_width_bottom = 2
	base.border_color = Color("#E2E8F0")
	base.shadow_color = Color(0, 0, 0, 0.04)
	base.shadow_size = 6
	base.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", base)

	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#EEF2FF")
	hover.border_color = Color("#6366F1")
	button.add_theme_stylebox_override("hover", hover)

	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#DBEAFE")
	pressed.border_color = Color("#2563EB")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", base)
	UiMotion.wire_microinteractions(button)


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
	button.custom_minimum_size = Vector2(0, 118)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color("#1E293B"))
	return button


func _show_message(message: String) -> void:
	_clear_content()
	content.add_child(_make_label(message, 34, true))


func _clear_content() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
