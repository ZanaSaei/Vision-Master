extends Control
## ============================================================
##  LESSON SELECT — pick a book, then the lesson to practise.
##
##  Everything here is built from ScrambledData, so adding a book, a lesson or
##  a word to res://data/scrambled_words.json is all it takes for it to show up
##  here (the folder README describes the format).
##
##  Each lesson button also carries the practice record of that lesson, which
##  is the closest thing learning mode has to a score: how many words have been
##  spelled correctly there so far.
## ============================================================

signal lesson_chosen(book: int, lesson: int)
signal back_requested()

const BOOK_ACCENTS := {
	1: Color("#3B82F6"),
	2: Color("#22C55E"),
	3: Color("#EF4444"),
}
const FALLBACK_ACCENT := DesignTokens.ACCENT

var _book := 1
var _book_row: HBoxContainer = null
var _lesson_column: VBoxContainer = null
var _summary_label: Label = null


func _ready() -> void:
	_book = _pick_initial_book()
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	_refresh()


func screen_title() -> String:
	return "انتخاب درس"


func handle_back() -> void:
	back_requested.emit()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	var background := get_node_or_null("Background") as ColorRect
	if background != null:
		background.color = ScrambledTheme.page_tint()
	_refresh()


## Opens on the last book played, falling back to the first book the bank has.
func _pick_initial_book() -> int:
	if ScrambledData.has_book(ScrambledGameManager.book):
		return ScrambledGameManager.book
	var books := ScrambledData.books()
	if books.is_empty():
		return 1
	return int(books[0]["book"])


func _accent_for(book: int) -> Color:
	return BOOK_ACCENTS.get(book, FALLBACK_ACCENT)


## ---------------------------------------------------------------- layout --
func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var intro := Label.new()
	intro.name = "IntroLabel"
	intro.text = "کدام کتاب و کدام درس؟"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_override("font", MenuStyle.vazir())
	intro.add_theme_font_size_override("font_size", 46)
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
	_summary_label.add_theme_font_size_override("font_size", 32)
	_summary_label.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	column.add_child(_summary_label)

	_lesson_column = VBoxContainer.new()
	_lesson_column.name = "LessonColumn"
	_lesson_column.add_theme_constant_override("separation", 14)
	column.add_child(_lesson_column)


## --------------------------------------------------------------- refresh --
func _refresh() -> void:
	if _book_row == null:
		return
	for child in _book_row.get_children():
		_book_row.remove_child(child)
		child.queue_free()
	for child in _lesson_column.get_children():
		_lesson_column.remove_child(child)
		child.queue_free()

	var books := ScrambledData.books()
	for book_data in books:
		_book_row.add_child(_make_book_button(book_data))

	if books.is_empty():
		_summary_label.text = ""
		_lesson_column.add_child(MenuStyle.make_tip_card(
			"هنوز واژه‌ای در بانک بازی ثبت نشده است.", ""))
		return

	var book_data := ScrambledData.book_data(_book)
	if book_data.is_empty():
		_summary_label.text = ""
		_lesson_column.add_child(MenuStyle.make_tip_card(
			"برای این کتاب درسی ثبت نشده است.", "📕"))
		return

	_summary_label.text = "%s · %s — %s درس، %s کلمه" % [
		str(book_data.get("title", "")),
		str(book_data.get("grade_fa", "")),
		digits(int(book_data.get("lesson_count", 0))),
		digits(int(book_data.get("word_count", 0))),
	]
	for lesson_data in book_data.get("lessons", []):
		_lesson_column.add_child(_make_lesson_button(lesson_data))


## Book chips: the open book is filled with its own accent, the others are
## flat cards, so the choice is obvious at a glance.
func _make_book_button(book_data: Dictionary) -> Button:
	var book := int(book_data.get("book", 0))
	var accent := _accent_for(book)
	var selected := book == _book
	var button := Button.new()
	button.name = "Book%d" % book
	button.text = str(book_data.get("title", "Vision %d" % book))
	button.custom_minimum_size = Vector2(240, 108)
	button.add_theme_font_override("font", MenuStyle.nunito())
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_color_override("font_color",
		MenuStyle.on_accent(accent) if selected else MenuStyle.text())
	var normal := MenuStyle.card_style(accent, 24, false, not selected)
	if selected:
		normal = ScrambledTheme.chip_style(accent, 24, ScrambledTheme.tile_edge(accent), 3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", MenuStyle.card_hover_style(accent, 24, not selected))
	button.add_theme_stylebox_override("pressed", MenuStyle.card_pressed_style(accent, 24, not selected))
	button.add_theme_stylebox_override("focus", normal)
	button.pressed.connect(func() -> void:
		Sfx.click()
		_book = book
		_refresh())
	MenuStyle.wire_microinteractions(button)
	return button


## One lesson: the Persian title, how many words it holds, and what the player
## has already spelled there.
func _make_lesson_button(lesson_data: Dictionary) -> Button:
	var lesson := int(lesson_data.get("lesson", 0))
	var words := int(lesson_data.get("word_count", 0))
	var accent := _accent_for(_book)
	var button := Button.new()
	button.name = "Lesson%d" % lesson
	button.custom_minimum_size = Vector2(0, 148)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", MenuStyle.card_style(accent, 26, false, true))
	button.add_theme_stylebox_override("hover", MenuStyle.card_hover_style(accent, 26, true))
	button.add_theme_stylebox_override("pressed", MenuStyle.card_pressed_style(accent, 26, true))
	button.add_theme_stylebox_override("focus", MenuStyle.card_hover_style(accent, 26, true))
	button.pressed.connect(func() -> void:
		Sfx.click()
		lesson_chosen.emit(_book, lesson))
	MenuStyle.wire_microinteractions(button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	button.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = _lesson_label(lesson, str(lesson_data.get("title_fa", "")))
	title.add_theme_font_override("font", MenuStyle.vazir())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", MenuStyle.text())
	row.add_child(title)
	var count: Label = MenuStyle.pill_label("%s کلمه" % digits(words), accent, 28)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)

	var record := ScrambledScoreManager.practice_stats(_book, lesson)
	var note := Label.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.text = _practice_note(record)
	note.add_theme_font_override("font", MenuStyle.vazir())
	note.add_theme_font_size_override("font_size", 28)
	note.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	column.add_child(note)
	return button


func _lesson_label(lesson: int, title_fa: String) -> String:
	var number := digits(lesson)
	if title_fa.is_empty():
		return "درس %s" % number
	return "درس %s · %s" % [number, title_fa]


func _practice_note(record: Dictionary) -> String:
	var words := int(record.get("words", 0))
	if words <= 0:
		return "هنوز تمرین نشده"
	return "%s کلمه تمرین شده · %s بار بازی" % [digits(words), digits(int(record.get("plays", 0)))]


func digits(value: int) -> String:
	return MenuStyle.persian_digits(str(value))