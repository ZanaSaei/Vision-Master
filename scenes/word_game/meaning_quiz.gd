extends "res://autoload/BackButtonHandler.gd"

const HUB_SCENE := "res://scenes/word_game/WordGame.tscn"
const QUESTION_SECONDS := 30.0
const OPTIONS_COUNT := 4
const DAILY_QUESTION_COUNT := 10
const BASE_POINTS := 100
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
var _score: int = 0
var _mistakes: int = 0
var _seconds_left: float = QUESTION_SECONDS
var _timer: Timer
var _daily_available: bool = true
var _is_learning: bool = false
var _confirm_dialog: ConfirmationDialog
var _daily_stats: Dictionary = {}
var _attempt_recorded: bool = false


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_daily_status()
	_create_leave_dialog()
	_timer = Timer.new()
	_timer.wait_time = 0.1
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_show_modes()


func _on_back_pressed() -> void:
	if _mode == "question" and not _is_learning:
		_confirm_dialog.popup_centered(Vector2i(760, 360))
		return
	if _mode == "question" and _is_learning:
		_timer.stop()
		_show_modes()
		return
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


func _create_leave_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "خروج از مسابقه"
	_confirm_dialog.dialog_text = "با خروج، مسابقه امروز تمام می‌شود و تا فردا قابل بازی نیست.\nآیا خارج می‌شوید؟"
	_confirm_dialog.ok_button_text = "خروج از مسابقه"
	_confirm_dialog.cancel_button_text = "ادامه بازی"
	_confirm_dialog.confirmed.connect(_confirm_leave_competition)
	add_child(_confirm_dialog)


func _confirm_leave_competition() -> void:
	_timer.stop()
	_consume_daily_attempt()
	_show_modes()


func _consume_daily_attempt() -> void:
	if not _attempt_recorded:
		_save_daily_status()
		_attempt_recorded = true
	_daily_available = false


func _load_daily_status() -> void:
	var today: String = MeaningQuizDaily.date_key()
	var stats_config: ConfigFile = ConfigFile.new()
	if stats_config.load("user://meaning_quiz.cfg") == OK:
		_daily_stats = stats_config.get_value("stats", "data", {})
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://meaning_quiz.cfg") == OK:
		var previous_date: String = str(config.get_value("daily", "date", ""))
		_daily_available = previous_date != today
		if _daily_available:
			_daily_stats["today_score"] = 0
			_attempt_recorded = false
		else:
			_attempt_recorded = true
	else:
		_daily_available = true
		_attempt_recorded = false


func _save_daily_status() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("daily", "date", MeaningQuizDaily.date_key())
	_daily_stats["last_date"] = MeaningQuizDaily.date_key()
	_daily_stats["plays"] = int(_daily_stats.get("plays", 0)) + 1
	_daily_stats["best_score"] = maxi(int(_daily_stats.get("best_score", 0)), _score)
	_daily_stats["today_score"] = _score
	_daily_stats["last_score"] = _score
	config.set_value("stats", "data", _daily_stats)
	var error: Error = config.save("user://meaning_quiz.cfg")
	if error != OK:
		push_warning("Meaning quiz: couldn't save daily completion (%d)" % error)


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
	var competition: Button = _make_button("مسابقه روزانه\n۱۰ پرسش · ۳۰ ثانیه برای هر پرسش")
	competition.disabled = not _daily_available
	if not _daily_available:
		competition.text = "مسابقه امروز انجام شده است\nمسابقه بعدی: %s" % MeaningQuizDaily.time_left_text()
	else:
		competition.text += "\nبه‌روزرسانی روزانه تا %s دیگر" % MeaningQuizDaily.time_left_text()
	competition.pressed.connect(_start_competition)
	content.add_child(competition)
	_animate_in(competition, 2)
	var stats_card: PanelContainer = _make_stats_card()
	content.add_child(stats_card)
	_animate_in(stats_card, 3)
	var note: Label = _make_label("پرسش مسابقه می‌تواند معنی، مترادف یا متضاد باشد. زمان پاسخ روی امتیاز اثر دارد.", 27, false)
	content.add_child(note)


func _make_stats_card() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 230)
	panel.add_theme_stylebox_override("panel", _card_style(Color("#E0F2FE"), Color("#0284C7")))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title: Label = _make_label("آمار مسابقه شما", 34, true)
	column.add_child(title)
	var plays: int = int(_daily_stats.get("plays", 0))
	var best: int = int(_daily_stats.get("best_score", 0))
	var last: int = int(_daily_stats.get("last_score", 0))
	column.add_child(_make_label("تعداد مسابقه‌ها: %d   |   بهترین امتیاز: %d   |   آخرین امتیاز: %d" % [plays, best, last], 25, true))
	return panel


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




func _start_competition() -> void:
	if not _daily_available:
		return
	var day_key: String = MeaningQuizDaily.date_key()
	_questions = MeaningQuizDaily.questions_for_date(day_key)
	if _questions.size() < DAILY_QUESTION_COUNT:
		_show_message("واژه‌های کافی برای ساخت پرسش‌های معتبر وجود ندارد.")
		return
	_attempt_recorded = false
	_is_learning = false
	_mode = "question"
	_question_index = 0
	_score = 0
	_show_question()


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
	_is_learning = true
	for entry: Dictionary in _questions:
		entry["_learning"] = true
	_mode = "question"
	_question_index = 0
	_score = 0
	_show_question()


func _show_question() -> void:
	_timer.stop()
	_clear_content()
	if _question_index >= _questions.size():
		_show_result()
		return
	var entry: Dictionary = _questions[_question_index]
	var learning: bool = _is_learning
	_seconds_left = QUESTION_SECONDS
	_mistakes = 0
	title_label.text = "پرسش %d از %d" % [_question_index + 1, _questions.size()]
	if learning:
		content.add_child(_make_question_card("واژه را به معنی درست وصل کنید", str(entry.get("word", "")), true))
	else:
		var question_text: String = _competition_prompt(entry)
		content.add_child(_make_question_card(question_text, str(entry.get("word", "")), false))
		var timer_label: Label = _make_label("۳۰ ثانیه", 30, true)
		timer_label.name = "TimerLabel"
		content.add_child(timer_label)
		var points_preview: Label = _make_label("پاسخ درست همین حالا: %d امتیاز · با هر اشتباه نصف می‌شود" % _current_question_points(), 25, true)
		points_preview.name = "QuestionPoints"
		content.add_child(points_preview)
		var progress: ProgressBar = ProgressBar.new()
		progress.name = "QuestionTimer"
		var progress_fill: StyleBoxFlat = StyleBoxFlat.new()
		progress_fill.bg_color = Color("#22C55E")
		progress_fill.set_corner_radius_all(20)
		progress.add_theme_stylebox_override("fill", progress_fill)
		var progress_bg: StyleBoxFlat = StyleBoxFlat.new()
		progress_bg.bg_color = Color("#DBEAFE")
		progress_bg.set_corner_radius_all(20)
		progress.add_theme_stylebox_override("background", progress_bg)
		progress.max_value = QUESTION_SECONDS
		progress.value = QUESTION_SECONDS
		content.add_child(progress)
		var point_label: Label = _make_label("امتیاز: %d" % _score, 28, true)
		content.add_child(point_label)
		_timer.start()
	var options: Array[String] = _make_options(entry, learning)
	for option: String in options:
		var answer_button: Button = _make_button(option)
		_style_answer_button(answer_button, option == str(entry.get("_correct", "")))
		answer_button.pressed.connect(_answer.bind(option, entry, learning))
		content.add_child(answer_button)
		_animate_in(answer_button, content.get_child_count() - 1)


func _competition_prompt(entry: Dictionary) -> String:
	var word: String = str(entry.get("word", ""))
	match str(entry.get("kind", "meaning")):
		"synonym":
			return "مترادف واژهٔ زیر کدام است؟\n%s" % word
		"antonym":
			return "متضاد واژهٔ زیر کدام است؟\n%s" % word
		_:
			return "معنی واژهٔ زیر چیست؟\n%s" % word


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


func _current_question_points() -> int:
	return maxi(0, int(floor(float(BASE_POINTS) * (_seconds_left / QUESTION_SECONDS) * pow(0.5, _mistakes))))


func _answer(option: String, entry: Dictionary, learning: bool) -> void:
	if option == str(entry.get("_correct", entry.get("answer", ""))):
		_timer.stop()
		if not learning:
			var earned: int = _current_question_points()
			_score += earned
		_question_index += 1
		_show_question()
		return
	if not learning:
		_mistakes += 1
		var points: Label = content.get_node_or_null("QuestionPoints") as Label
		if points != null:
			points.text = "پاسخ درست همین حالا: %d امتیاز · با هر اشتباه نصف می‌شود" % _current_question_points()


func _on_tick() -> void:
	_seconds_left = maxf(0.0, _seconds_left - _timer.wait_time)
	var progress: ProgressBar = content.get_node_or_null("QuestionTimer") as ProgressBar
	var label: Label = content.get_node_or_null("TimerLabel") as Label
	var points: Label = content.get_node_or_null("QuestionPoints") as Label
	if points != null:
		points.text = "پاسخ درست همین حالا: %d امتیاز · با هر اشتباه نصف می‌شود" % _current_question_points()
	if progress != null:
		progress.value = _seconds_left
	if label != null:
		label.text = "%.1f ثانیه" % _seconds_left
	if _seconds_left <= 0.0:
		_timer.stop()
		_question_index += 1
		_show_question()


func _show_result() -> void:
	_mode = "result"
	_clear_content()
	title_label.text = "نتیجه"
	content.add_child(_make_label("پرسش‌ها به پایان رسید", 42, true))
	if _is_learning:
		content.add_child(_make_label("آفرین! تمرین این درس تمام شد.", 34, true))
	else:
		content.add_child(_make_label("امتیاز شما: %d" % _score, 48, true))
		_consume_daily_attempt()
	var again: Button = _make_button("بازگشت به حالت‌ها")
	again.pressed.connect(_show_modes)
	content.add_child(again)


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
