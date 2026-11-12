extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  بازی معنی (Wordef) — Meaning & Vocabulary Quiz Game
#
#  Engaging 4-option vocabulary quiz with multiple dynamic question formats
#  (English to Persian, Persian to English, Synonyms, Antonyms), audio
#  pronunciation playback, responsive tactile feedback, streak multipliers,
#  animated progress HUD, and a rewarding 3-star celebratory results screen.
# ============================================================

const HUB_SCENE := "res://scenes/word_game/WordGameHub.tscn"
const LEARNING_SCENE := "res://scenes/word_game/WordGameLearning.tscn"
const CONFETTI_SCENE := preload("res://scenes/word_game/scrambled/ui/ConfettiBurst.tscn")
const FONT: FontFile = preload("res://ui/fonts/Vazirmatn-Regular.ttf")

const OPTIONS_COUNT := 4
const BASE_POINTS := 100
const STREAK_BONUS_POINTS := 25

const BOOK_ACCENTS := {
	1: Color("#3B82F6"), # Vision 1 (Blue)
	2: Color("#10B981"), # Vision 2 (Emerald)
	3: Color("#EF4444"), # Vision 3 (Red)
}
const FALLBACK_ACCENT := Color("#3B82F6")

const WORD_TYPE_FA := {
	"noun": "اسم",
	"proper noun": "اسم خاص",
	"noun phrase": "عبارت اسمی",
	"verb": "فعل",
	"adjective": "صفت",
	"adverb": "قید",
	"determiner": "تعیین‌کننده",
	"pronoun": "ضمیر",
	"preposition": "حرف اضافه",
	"conjunction": "حرف ربط",
	"interjection": "صوت",
	"phrase": "عبارت",
	"idiom": "اصطلاح",
}

const PRAISE_LINES := [
	"آفرین! 👏",
	"عالی بود! 🔥",
	"درسته! ✨",
	"فوق‌العاده! 🌟",
	"پیاپی و دقیق! ⚡",
	"تسلط کامل! 🎯",
]

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var title_label: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var content: VBoxContainer = $Content
@onready var background: ColorRect = $Background

var _mode: String = "" # "book_select", "quiz", "result"
var _is_daily_challenge: bool = false
var _book: int = 1
var _lesson: int = 1
var _questions: Array[Dictionary] = []
var _question_index: int = 0
var _score: int = 0
var _streak: int = 0
var _max_streak: int = 0
var _correct_first_try: int = 0
var _made_mistake_on_current: bool = false
var _start_time: int = 0
var _busy: bool = false

var _confetti: ScrambledConfettiBurst = null

# Selection Screen UI
var _book_row: HBoxContainer = null
var _lesson_column: VBoxContainer = null
var _summary_label: Label = null

# Quiz HUD UI
var _hud_container: VBoxContainer = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _streak_label: Label = null
var _streak_pill: PanelContainer = null
var _score_label: Label = null
var _score_pill: PanelContainer = null
var _current_hint_box: VBoxContainer = null


func _ready() -> void:
	Global.style_header($HeaderBar)
	if background != null:
		background.color = Color("#EEF6FF")
		if Global.get("_theme") != null:
			background.color = MenuStyle.c("bg")
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	UiMotion.wire_microinteractions(back_button)

	if CONFETTI_SCENE != null:
		_confetti = CONFETTI_SCENE.instantiate() as ScrambledConfettiBurst
		add_child(_confetti)

	if DailyChallengeState.selected_game == "wordef":
		_start_daily_challenge(DailyChallengeState.selected_date)
	else:
		_show_book_select()


func _on_back_pressed() -> void:
	if not _is_daily_challenge and (_mode == "quiz" or _mode == "result"):
		_show_book_select()
		return
	var return_target: String = DailyChallengeState.return_scene if DailyChallengeState.return_scene != "" else LEARNING_SCENE
	DailyChallengeState.return_scene = ""
	DailyChallengeState.selected_game = ""
	TransitionManager.change_scene_now(return_target)


func _on_android_back_pressed() -> void:
	_on_back_pressed()


func _accent_for(book: int) -> Color:
	return BOOK_ACCENTS.get(book, FALLBACK_ACCENT)


# ══════════════════════════════════════════════════════════════
#  BOOK & LESSON SELECTION
# ══════════════════════════════════════════════════════════════

func _show_book_select() -> void:
	_mode = "book_select"
	_clear_content()
	title_label.text = "بازی معنی (Wordef)"

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
	var lesson_buttons: Array[Button] = []
	for lesson_data: Dictionary in lessons:
		var btn := _make_lesson_button(lesson_data)
		_lesson_column.add_child(btn)
		lesson_buttons.append(btn)

	# Staggered smooth animation for lesson cards
	for i in lesson_buttons.size():
		var btn: Button = lesson_buttons[i]
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.97, 0.97)
		UiMotion.center_pivot(btn)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(btn, "modulate:a", 1.0, 0.22).set_delay(float(i) * 0.04)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.25).set_delay(float(i) * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	note.text = "تمرین واژگان، معنی فارسی و مترادف"
	note.add_theme_font_override("font", MenuStyle.vazir())
	note.add_theme_font_size_override("font_size", 26)
	note.add_theme_color_override("font_color", Color("#64748B"))
	col.add_child(note)

	return button


# ══════════════════════════════════════════════════════════════
#  GAME ENGINE & QUESTION GENERATION
# ══════════════════════════════════════════════════════════════

func _start_daily_challenge(date_key: String = "") -> void:
	_is_daily_challenge = true
	_book = 1
	_lesson = 1
	_score = 0
	_streak = 0
	_max_streak = 0
	_correct_first_try = 0
	_question_index = 0
	_start_time = int(Time.get_unix_time_from_system())
	_busy = false

	var all_words := _load_all_project_words()
	if all_words.size() < OPTIONS_COUNT:
		_show_message("واژگان کافی برای چالش روزانه یافت نشد.")
		return

	# Pick 5 words across all books in the project, deterministically seeded by date
	var pool := all_words.duplicate()
	var rng := RandomNumberGenerator.new()
	if not date_key.is_empty():
		rng.seed = hash("wordef_" + date_key)
	else:
		rng.randomize()

	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var picked_words: Array[Dictionary] = []
	for i in mini(5, pool.size()):
		picked_words.append(pool[i])

	_questions = _build_quiz_questions_from_pool(picked_words, all_words)
	if _questions.is_empty():
		_show_message("خطا در ساخت پرسش‌های چالش روزانه.")
		return
	if _questions.size() > 5:
		_questions = _questions.slice(0, 5)

	_mode = "quiz"
	_show_question()


func _start_learning(book: int, lesson: int) -> void:
	_is_daily_challenge = false
	_book = book
	_lesson = lesson
	_score = 0
	_streak = 0
	_max_streak = 0
	_correct_first_try = 0
	_question_index = 0
	_start_time = int(Time.get_unix_time_from_system())
	_busy = false

	var raw_words := _load_lesson_words(book, lesson)
	if raw_words.size() < OPTIONS_COUNT:
		_show_message("این درس برای ساخت پرسش به دست‌کم چهار واژه نیاز دارد.")
		return

	_questions = _build_quiz_questions(raw_words, book)
	if _questions.is_empty():
		_show_message("خطا در ایجاد پرسش‌های این درس.")
		return

	_mode = "quiz"
	_show_question()


func _build_quiz_questions(lesson_words: Array[Dictionary], book: int) -> Array[Dictionary]:
	# Build a distractor bank from this lesson + whole book
	var pool_words := _load_book_words(book)
	if pool_words.size() < OPTIONS_COUNT:
		pool_words = lesson_words
	return _build_quiz_questions_from_pool(lesson_words, pool_words)


func _build_quiz_questions_from_pool(lesson_words: Array[Dictionary], pool_words: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var all_persian_meanings: Array[String] = []
	var all_english_words: Array[String] = []
	for w: Dictionary in pool_words:
		var fa := str(w.get("meaning_fa", "")).strip_edges()
		var en := str(w.get("word", "")).strip_edges()
		if not fa.is_empty() and not all_persian_meanings.has(fa):
			all_persian_meanings.append(fa)
		if not en.is_empty() and not all_english_words.has(en):
			all_english_words.append(en)

	var count := lesson_words.size()
	for i in count:
		var entry: Dictionary = lesson_words[i]
		var word: String = str(entry.get("word", "")).strip_edges()
		var meaning_fa: String = str(entry.get("meaning_fa", "")).strip_edges()
		var audio: String = str(entry.get("audio", "")).strip_edges()
		var word_type: String = str(entry.get("word_type", "")).strip_edges()
		var phonetics: String = str(entry.get("phonetics", "")).strip_edges()
		var synonyms: Array[String] = _extract_terms(entry.get("synonyms", {}), "en")
		var antonyms: Array[String] = _extract_terms(entry.get("antonyms", {}), "en")

		if word.is_empty() or meaning_fa.is_empty():
			continue

		# Question variety:
		# ~55% English -> Persian Meaning
		# ~30% Persian -> English Word
		# ~15% Synonym or Antonym (if available)
		var kind := "en_to_fa"
		if i % 3 == 1:
			kind = "fa_to_en"
		elif i % 3 == 2:
			if not synonyms.is_empty():
				kind = "synonym"
			elif not antonyms.is_empty():
				kind = "antonym"
			else:
				kind = "en_to_fa"

		match kind:
			"en_to_fa":
				var options := _pick_options(meaning_fa, all_persian_meanings)
				if options.size() == OPTIONS_COUNT:
					result.append({
						"kind": "en_to_fa",
						"prompt_title": "معنی واژهٔ زیر کدام است؟",
						"display_text": word,
						"display_is_en": true,
						"raw_word": word,
						"audio": audio,
						"word_type": word_type,
						"phonetics": phonetics,
						"correct_answer": meaning_fa,
						"options": options,
						"options_are_en": false,
					})
			"fa_to_en":
				var options := _pick_options(word, all_english_words)
				if options.size() == OPTIONS_COUNT:
					result.append({
						"kind": "fa_to_en",
						"prompt_title": "کدام واژه به معنی زیر است؟",
						"display_text": meaning_fa,
						"display_is_en": false,
						"raw_word": word,
						"audio": audio,
						"word_type": word_type,
						"phonetics": phonetics,
						"correct_answer": word,
						"options": options,
						"options_are_en": true,
					})
			"synonym":
				var correct_syn: String = synonyms[0]
				var options := _pick_options(correct_syn, all_english_words, [word])
				if options.size() == OPTIONS_COUNT:
					result.append({
						"kind": "synonym",
						"prompt_title": "مترادف واژهٔ زیر کدام است؟",
						"display_text": word,
						"display_is_en": true,
						"raw_word": word,
						"audio": audio,
						"word_type": word_type,
						"phonetics": phonetics,
						"correct_answer": correct_syn,
						"options": options,
						"options_are_en": true,
					})
			"antonym":
				var correct_ant: String = antonyms[0]
				var options := _pick_options(correct_ant, all_english_words, [word])
				if options.size() == OPTIONS_COUNT:
					result.append({
						"kind": "antonym",
						"prompt_title": "متضاد واژهٔ زیر کدام است؟",
						"display_text": word,
						"display_is_en": true,
						"raw_word": word,
						"audio": audio,
						"word_type": word_type,
						"phonetics": phonetics,
						"correct_answer": correct_ant,
						"options": options,
						"options_are_en": true,
					})

	result.shuffle()
	return result


func _pick_options(correct: String, pool: Array[String], forbidden: Array[String] = []) -> Array[String]:
	var candidates: Array[String] = []
	for item in pool:
		if item != correct and not candidates.has(item) and not forbidden.has(item):
			candidates.append(item)
	candidates.shuffle()

	var options: Array[String] = [correct]
	for i in mini(OPTIONS_COUNT - 1, candidates.size()):
		options.append(candidates[i])
	options.shuffle()
	return options


func _extract_terms(dict_value: Variant, lang: String) -> Array[String]:
	var terms: Array[String] = []
	if not dict_value is Dictionary:
		return terms
	var list: Variant = dict_value.get(lang, [])
	if not list is Array:
		return terms
	for raw: Variant in list:
		var clean := str(raw).strip_edges()
		while clean.ends_with(".") or clean.ends_with("!") or clean.ends_with("?"):
			clean = clean.left(clean.length() - 1).strip_edges()
		if not clean.is_empty() and not terms.has(clean):
			terms.append(clean)
	return terms


# ══════════════════════════════════════════════════════════════
#  HUD & IN-GAME QUESTION DISPLAY
# ══════════════════════════════════════════════════════════════

func _show_question() -> void:
	if _question_index >= _questions.size():
		_show_result()
		return

	_clear_content()
	_current_hint_box = null
	_made_mistake_on_current = false
	_busy = false

	var q: Dictionary = _questions[_question_index]
	if _is_daily_challenge:
		title_label.text = "چالش روزانه · پرسش %s از %s" % [
			MenuStyle.persian_digits(str(_question_index + 1)),
			MenuStyle.persian_digits(str(_questions.size()))
		]
	else:
		title_label.text = "درس %s · واژهٔ %s" % [
			MenuStyle.persian_digits(str(_lesson)),
			MenuStyle.persian_digits(str(_question_index + 1))
		]

	# 1. Top HUD
	_hud_container = _create_hud()
	content.add_child(_hud_container)
	_update_hud(false)

	# 2. Question Card
	var question_card := _create_question_card(q)
	content.add_child(question_card)
	UiMotion.pop_in(question_card, 0.0)

	# 3. Answer Options
	var options: Array = q.get("options", [])
	var is_en_options: bool = bool(q.get("options_are_en", false))
	for i in options.size():
		var option_text: String = str(options[i])
		var btn := _create_answer_button(option_text, is_en_options)
		btn.pressed.connect(_on_option_selected.bind(btn, option_text, q))
		content.add_child(btn)
		_animate_option_in(btn, i)


func _create_hud() -> VBoxContainer:
	var hud := VBoxContainer.new()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_theme_constant_override("separation", 10)

	# Top stats bar: Streak (Left) & Score (Right)
	var stats_row := HBoxContainer.new()
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(stats_row)

	# Streak Pill
	_streak_pill = PanelContainer.new()
	var streak_sb := StyleBoxFlat.new()
	streak_sb.bg_color = Color("#FFF7ED")
	streak_sb.border_width_left = 2
	streak_sb.border_width_top = 2
	streak_sb.border_width_right = 2
	streak_sb.border_width_bottom = 2
	streak_sb.border_color = Color("#FED7AA")
	streak_sb.set_corner_radius_all(18)
	streak_sb.content_margin_left = 18
	streak_sb.content_margin_right = 18
	streak_sb.content_margin_top = 8
	streak_sb.content_margin_bottom = 8
	_streak_pill.add_theme_stylebox_override("panel", streak_sb)
	UiMotion.center_pivot(_streak_pill)

	_streak_label = Label.new()
	_streak_label.text = "🔥 %s پیاپی" % MenuStyle.persian_digits(str(_streak))
	_streak_label.add_theme_font_override("font", MenuStyle.vazir_bold())
	_streak_label.add_theme_font_size_override("font_size", 28)
	_streak_label.add_theme_color_override("font_color", Color("#EA580C"))
	_streak_pill.add_child(_streak_label)
	stats_row.add_child(_streak_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(spacer)

	# Score Pill
	_score_pill = PanelContainer.new()
	var score_sb := StyleBoxFlat.new()
	score_sb.bg_color = Color("#FEFCE8")
	score_sb.border_width_left = 2
	score_sb.border_width_top = 2
	score_sb.border_width_right = 2
	score_sb.border_width_bottom = 2
	score_sb.border_color = Color("#FEF08A")
	score_sb.set_corner_radius_all(18)
	score_sb.content_margin_left = 20
	score_sb.content_margin_right = 20
	score_sb.content_margin_top = 8
	score_sb.content_margin_bottom = 8
	_score_pill.add_theme_stylebox_override("panel", score_sb)
	UiMotion.center_pivot(_score_pill)

	_score_label = Label.new()
	_score_label.text = "⭐ %s امتیاز" % MenuStyle.persian_digits(str(_score))
	_score_label.add_theme_font_override("font", MenuStyle.vazir_bold())
	_score_label.add_theme_font_size_override("font_size", 28)
	_score_label.add_theme_color_override("font_color", Color("#B45309"))
	_score_pill.add_child(_score_label)
	stats_row.add_child(_score_pill)

	# Progress Bar & Counter
	var progress_row := HBoxContainer.new()
	progress_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_theme_constant_override("separation", 14)
	hud.add_child(progress_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.show_percentage = false
	_progress_bar.max_value = float(maxi(1, _questions.size()))

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color("#E2E8F0")
	pb_bg.set_corner_radius_all(7)
	_progress_bar.add_theme_stylebox_override("background", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = _accent_for(_book)
	pb_fill.set_corner_radius_all(7)
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	progress_row.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.add_theme_font_override("font", MenuStyle.vazir())
	_progress_label.add_theme_font_size_override("font_size", 26)
	_progress_label.add_theme_color_override("font_color", Color("#64748B"))
	progress_row.add_child(_progress_label)

	return hud


func _update_hud(animate: bool = true) -> void:
	if _progress_bar == null or _progress_label == null:
		return

	var current_q := _question_index + 1
	var total_q := _questions.size()
	_progress_label.text = "پرسش %s از %s" % [
		MenuStyle.persian_digits(str(current_q)),
		MenuStyle.persian_digits(str(total_q))
	]

	if animate:
		var tw := create_tween()
		tw.tween_property(_progress_bar, "value", float(_question_index), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_progress_bar.value = float(_question_index)

	if _score_label != null:
		_score_label.text = "⭐ %s امتیاز" % MenuStyle.persian_digits(str(_score))

	if _streak_label != null:
		_streak_label.text = "🔥 %s پیاپی" % MenuStyle.persian_digits(str(_streak))
		if _streak >= 2:
			_streak_label.add_theme_color_override("font_color", Color("#EA580C"))
		else:
			_streak_label.add_theme_color_override("font_color", Color("#94A3B8"))


func _create_question_card(q: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 270)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_width_left = 8
	sb.border_color = _accent_for(_book)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	# Top row: Prompt & Badge Tag
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(top_row)

	var prompt_lbl := Label.new()
	prompt_lbl.text = str(q.get("prompt_title", "معنی واژهٔ زیر کدام است؟"))
	prompt_lbl.add_theme_font_override("font", MenuStyle.vazir())
	prompt_lbl.add_theme_font_size_override("font_size", 28)
	prompt_lbl.add_theme_color_override("font_color", Color("#64748B"))
	prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(prompt_lbl)

	# Tag pill (Word Type or Kind)
	var tag_text := ""
	var raw_type := str(q.get("word_type", "")).to_lower().strip_edges()
	var kind := str(q.get("kind", ""))
	if kind == "synonym":
		tag_text = "مترادف"
	elif kind == "antonym":
		tag_text = "متضاد"
	elif WORD_TYPE_FA.has(raw_type):
		tag_text = WORD_TYPE_FA[raw_type]

	if not tag_text.is_empty():
		var tag_pill := PanelContainer.new()
		var tag_sb := StyleBoxFlat.new()
		tag_sb.bg_color = Color(_accent_for(_book).r, _accent_for(_book).g, _accent_for(_book).b, 0.12)
		tag_sb.set_corner_radius_all(12)
		tag_sb.content_margin_left = 14
		tag_sb.content_margin_right = 14
		tag_sb.content_margin_top = 4
		tag_sb.content_margin_bottom = 4
		tag_pill.add_theme_stylebox_override("panel", tag_sb)

		var tag_lbl := Label.new()
		tag_lbl.text = tag_text
		tag_lbl.add_theme_font_override("font", MenuStyle.vazir())
		tag_lbl.add_theme_font_size_override("font_size", 24)
		tag_lbl.add_theme_color_override("font_color", _accent_for(_book))
		tag_pill.add_child(tag_lbl)
		top_row.add_child(tag_pill)

	# Main Display Word
	var word_lbl := Label.new()
	word_lbl.text = str(q.get("display_text", ""))
	word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(q.get("display_is_en", true)):
		word_lbl.add_theme_font_override("font", MenuStyle.nunito())
		word_lbl.add_theme_font_size_override("font_size", 54)
		word_lbl.add_theme_color_override("font_color", _accent_for(_book))
	else:
		word_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
		word_lbl.add_theme_font_size_override("font_size", 42)
		word_lbl.add_theme_color_override("font_color", Color("#1E293B"))
	col.add_child(word_lbl)

	# Hint container for phonetics and pronunciation button (initially hidden until a wrong answer is chosen)
	var hint_box := VBoxContainer.new()
	hint_box.name = "HintBox"
	hint_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_box.add_theme_constant_override("separation", 10)
	hint_box.visible = false
	hint_box.modulate.a = 0.0

	# Phonetics row (if available)
	var phonetics := str(q.get("phonetics", "")).strip_edges()
	if not phonetics.is_empty():
		var phon_lbl := Label.new()
		phon_lbl.name = "PhoneticsLabel"
		phon_lbl.text = phonetics
		phon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phon_lbl.add_theme_font_override("font", MenuStyle.nunito())
		phon_lbl.add_theme_font_size_override("font_size", 28)
		phon_lbl.add_theme_color_override("font_color", Color("#94A3B8"))
		hint_box.add_child(phon_lbl)

	# Interactive Pronunciation Button (Speaker 🔊)
	var raw_word := str(q.get("raw_word", ""))
	var audio_file := str(q.get("audio", ""))
	if not raw_word.is_empty():
		var speaker_btn := Button.new()
		speaker_btn.name = "SpeakerButton"
		speaker_btn.text = "🔊  پخش تلفظ"
		speaker_btn.custom_minimum_size = Vector2(200, 56)
		speaker_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		speaker_btn.add_theme_font_override("font", MenuStyle.vazir())
		speaker_btn.add_theme_font_size_override("font_size", 26)
		speaker_btn.add_theme_color_override("font_color", Color("#2563EB"))

		var spk_sb := StyleBoxFlat.new()
		spk_sb.bg_color = Color("#EFF6FF")
		spk_sb.border_width_left = 1
		spk_sb.border_width_top = 1
		spk_sb.border_width_right = 1
		spk_sb.border_width_bottom = 1
		spk_sb.border_color = Color("#BFDBFE")
		spk_sb.set_corner_radius_all(16)
		spk_sb.content_margin_left = 18
		spk_sb.content_margin_right = 18
		speaker_btn.add_theme_stylebox_override("normal", spk_sb)

		var spk_hover := spk_sb.duplicate() as StyleBoxFlat
		spk_hover.bg_color = Color("#DBEAFE")
		speaker_btn.add_theme_stylebox_override("hover", spk_hover)
		speaker_btn.add_theme_stylebox_override("pressed", spk_hover)
		speaker_btn.add_theme_stylebox_override("focus", spk_sb)

		speaker_btn.pressed.connect(func() -> void:
			Global.play_word_audio(audio_file, raw_word)
			UiMotion.pop(speaker_btn, 1.15))
		UiMotion.wire_microinteractions(speaker_btn)
		hint_box.add_child(speaker_btn)

	col.add_child(hint_box)
	_current_hint_box = hint_box

	return card


func _create_answer_button(option_text: String, is_en: bool) -> Button:
	var btn := Button.new()
	btn.text = option_text
	btn.custom_minimum_size = Vector2(0, 114)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true

	if is_en:
		btn.add_theme_font_override("font", MenuStyle.nunito())
		btn.add_theme_font_size_override("font_size", 34)
	else:
		btn.add_theme_font_override("font", MenuStyle.vazir())
		btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color("#1E293B"))

	var base := StyleBoxFlat.new()
	base.bg_color = Color.WHITE
	base.set_corner_radius_all(24)
	base.border_width_left = 2
	base.border_width_top = 2
	base.border_width_right = 2
	base.border_width_bottom = 2
	base.border_color = Color("#E2E8F0")
	base.shadow_color = Color(0, 0, 0, 0.05)
	base.shadow_size = 8
	base.shadow_offset = Vector2(0, 2)
	base.content_margin_left = 24
	base.content_margin_right = 24
	btn.add_theme_stylebox_override("normal", base)

	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#F8FAFC")
	hover.border_color = Color("#94A3B8")
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#F1F5F9")
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", base)

	UiMotion.wire_microinteractions(btn)
	return btn


func _animate_option_in(control: Control, index: int) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2(0.95, 0.95)
	UiMotion.center_pivot(control)
	var tw := create_tween()
	tw.tween_interval(0.04 * float(index))
	tw.tween_property(control, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(control, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════════════════════
#  INTERACTIVE ANSWER HANDLING & GAME FEEL
# ══════════════════════════════════════════════════════════════

func _on_option_selected(button: Button, selected_option: String, q: Dictionary) -> void:
	if _busy:
		return

	var correct_answer := str(q.get("correct_answer", ""))
	if selected_option == correct_answer:
		# ── CORRECT ANSWER ──
		_busy = true
		Sfx.correct()

		# Also play pronunciation for sensory reinforcement
		var audio_file := str(q.get("audio", ""))
		var raw_word := str(q.get("raw_word", ""))
		if not raw_word.is_empty():
			Global.play_word_audio(audio_file, raw_word)

		# Style as Green Success
		button.text = "✓  " + selected_option
		button.add_theme_color_override("font_color", Color.WHITE)
		var correct_sb := StyleBoxFlat.new()
		correct_sb.bg_color = Color("#16A34A")
		correct_sb.border_width_left = 2
		correct_sb.border_width_top = 2
		correct_sb.border_width_right = 2
		correct_sb.border_width_bottom = 2
		correct_sb.border_color = Color("#15803D")
		correct_sb.set_corner_radius_all(24)
		correct_sb.shadow_color = Color(22.0 / 255.0, 163.0 / 255.0, 74.0 / 255.0, 0.35)
		correct_sb.shadow_size = 12
		correct_sb.shadow_offset = Vector2(0, 4)
		correct_sb.content_margin_left = 24
		correct_sb.content_margin_right = 24
		button.add_theme_stylebox_override("normal", correct_sb)
		button.add_theme_stylebox_override("hover", correct_sb)
		button.add_theme_stylebox_override("pressed", correct_sb)
		UiMotion.pop(button, 1.08)

		# Scoring & Streaks
		if not _made_mistake_on_current:
			_correct_first_try += 1
			_streak += 1
			_max_streak = maxi(_max_streak, _streak)
			var points := BASE_POINTS + (_streak - 1) * STREAK_BONUS_POINTS
			_score += points
			_float_points(points, button.global_position + Vector2(button.size.x * 0.5, 0.0))

			if _streak >= 3:
				var praise: String = PRAISE_LINES[randi() % PRAISE_LINES.size()]
				var vp_w: float = get_viewport_rect().size.x if is_inside_tree() else 1080.0
				_show_praise(praise, Vector2(vp_w * 0.5, 340.0))

		_update_hud(true)

		if is_inside_tree() and get_tree() != null:
			await get_tree().create_timer(0.46).timeout
		_question_index += 1
		_show_question()

	else:
		# ── WRONG ANSWER ──
		Sfx.wrong()
		UiMotion.shake(button)
		_made_mistake_on_current = true
		_streak = 0
		_update_hud(true)

		# Style as Red Error & Disable to prevent repeated mistakes
		button.text = "✗  " + selected_option
		button.add_theme_color_override("font_color", Color.WHITE)
		var wrong_sb := StyleBoxFlat.new()
		wrong_sb.bg_color = Color("#EF4444")
		wrong_sb.border_width_left = 2
		wrong_sb.border_width_top = 2
		wrong_sb.border_width_right = 2
		wrong_sb.border_width_bottom = 2
		wrong_sb.border_color = Color("#DC2626")
		wrong_sb.set_corner_radius_all(24)
		wrong_sb.content_margin_left = 24
		wrong_sb.content_margin_right = 24
		button.add_theme_stylebox_override("normal", wrong_sb)
		button.add_theme_stylebox_override("hover", wrong_sb)
		button.add_theme_stylebox_override("pressed", wrong_sb)
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Reveal phonetic and pronunciation button as a hint
		_show_hint_on_wrong_answer()


func _show_hint_on_wrong_answer() -> void:
	if _current_hint_box != null and is_instance_valid(_current_hint_box):
		if not _current_hint_box.visible:
			_current_hint_box.visible = true
			_current_hint_box.modulate.a = 0.0
			_current_hint_box.pivot_offset = _current_hint_box.size * 0.5
			var tw := create_tween()
			tw.tween_property(_current_hint_box, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(_current_hint_box, "scale", Vector2.ONE, 0.28) \
				.from(Vector2(0.92, 0.92)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _float_points(pts: int, origin_pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "+%s" % MenuStyle.persian_digits(str(pts))
	lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	lbl.add_theme_font_size_override("font_size", 44)
	lbl.add_theme_color_override("font_color", Color("#F59E0B"))
	lbl.position = origin_pos - Vector2(60, 40)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	UiMotion.center_pivot(lbl)
	lbl.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", origin_pos.y - 120.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)


func _show_praise(text: String, origin_pos: Vector2) -> void:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0F172A")
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	pill.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color("#FEF08A"))
	pill.add_child(lbl)

	pill.position = origin_pos - Vector2(120, 60)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)

	UiMotion.center_pivot(pill)
	pill.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pill, "position:y", origin_pos.y - 80.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(pill, "modulate:a", 0.0, 0.25)
	tw.tween_callback(pill.queue_free)


# ══════════════════════════════════════════════════════════════
#  RESULTS SCREEN (CELEBRATION & STATS)
# ══════════════════════════════════════════════════════════════

func _show_result() -> void:
	_mode = "result"
	_clear_content()
	title_label.text = "کارنامه و نتیجه"
	Sfx.complete()

	var vp_w: float = get_viewport_rect().size.x if is_inside_tree() else 1080.0
	if _confetti != null:
		_confetti.burst(Vector2(vp_w * 0.5, 450.0))

	var total_q := maxi(1, _questions.size())
	var accuracy := int(round(float(_correct_first_try) / float(total_q) * 100.0))
	var stars := 3 if accuracy >= 90 else (2 if accuracy >= 70 else (1 if accuracy >= 40 else 0))

	if _is_daily_challenge and DailyChallengeMock.is_active():
		var daily_pts: int = clampi(accuracy, 20, 100)
		DailyChallengeMock.complete_game(DailyChallengeState.selected_date, "wordef", daily_pts)
	var elapsed := maxi(1, int(Time.get_unix_time_from_system()) - _start_time)
	var minutes := int(elapsed / 60.0)
	var seconds := elapsed % 60

	if stars == 3 and is_inside_tree() and get_tree() != null:
		get_tree().create_timer(0.3).timeout.connect(func() -> void: Sfx.reward())

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

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	# Main Celebration Card
	var card := PanelContainer.new()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color.WHITE
	card_sb.set_corner_radius_all(32)
	card_sb.shadow_color = Color(0, 0, 0, 0.08)
	card_sb.shadow_size = 18
	card_sb.shadow_offset = Vector2(0, 6)
	card_sb.content_margin_left = 32
	card_sb.content_margin_right = 32
	card_sb.content_margin_top = 32
	card_sb.content_margin_bottom = 32
	card.add_theme_stylebox_override("panel", card_sb)
	col.add_child(card)

	var card_col := VBoxContainer.new()
	card_col.alignment = BoxContainer.ALIGNMENT_CENTER
	card_col.add_theme_constant_override("separation", 18)
	card.add_child(card_col)

	# ── 3-Star Display ──
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 18)
	card_col.add_child(stars_row)

	for star_idx in range(1, 4):
		var star_lbl := Label.new()
		star_lbl.text = "⭐" if star_idx <= stars else "☆"
		star_lbl.add_theme_font_size_override("font_size", 76)
		star_lbl.add_theme_color_override("font_color", Color("#F59E0B") if star_idx <= stars else Color("#CBD5E1"))
		stars_row.add_child(star_lbl)
		UiMotion.center_pivot(star_lbl)
		star_lbl.scale = Vector2(0.4, 0.4)
		var star_tw := create_tween()
		star_tw.tween_interval(0.12 * float(star_idx))
		star_tw.tween_property(star_lbl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Headline
	var headline_text := "فوق‌العاده و بی‌نقص! 🏆"
	var subtitle_text := "تسلط کامل بر تمام واژگان این درس"
	if stars == 2:
		headline_text = "بسیار عالی! 🌟"
		subtitle_text = "عملکرد درخشان در تمرین واژگان"
	elif stars == 1:
		headline_text = "آفرین بر تلاش شما! 👍"
		subtitle_text = "با یک بار تکرار به ۳ ستاره خواهید رسید"
	elif stars == 0:
		headline_text = "تمرین کلید موفقیت است! 💪"
		subtitle_text = "یک بار دیگر امتحان کنید تا مسلط شوید"

	var headline := Label.new()
	headline.text = headline_text
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_override("font", MenuStyle.vazir_bold())
	headline.add_theme_font_size_override("font_size", 42)
	headline.add_theme_color_override("font_color", Color("#1E293B"))
	card_col.add_child(headline)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", MenuStyle.vazir())
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color("#64748B"))
	card_col.add_child(subtitle)

	# ── 3 Stat Chips ──
	var stats_grid := HBoxContainer.new()
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_grid.add_theme_constant_override("separation", 14)
	card_col.add_child(stats_grid)

	stats_grid.add_child(_make_stat_box("🎯 دقت پاسخ", "%s٪" % MenuStyle.persian_digits(str(accuracy)), Color("#10B981")))
	stats_grid.add_child(_make_stat_box("🏆 امتیاز کل", MenuStyle.persian_digits(str(_score)), Color("#F59E0B")))
	stats_grid.add_child(_make_stat_box("🔥 رکورد زنجیره", "%s پاسخ" % MenuStyle.persian_digits(str(_max_streak)), Color("#EA580C")))

	# Time Spent
	var time_str := ""
	if minutes > 0:
		time_str = "⏱️ زمان صرف‌شده: %s دقیقه و %s ثانیه" % [
			MenuStyle.persian_digits(str(minutes)),
			MenuStyle.persian_digits(str(seconds))
		]
	else:
		time_str = "⏱️ زمان صرف‌شده: %s ثانیه" % MenuStyle.persian_digits(str(seconds))

	var time_lbl := Label.new()
	time_lbl.text = time_str
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_override("font", MenuStyle.vazir())
	time_lbl.add_theme_font_size_override("font_size", 26)
	time_lbl.add_theme_color_override("font_color", Color("#94A3B8"))
	card_col.add_child(time_lbl)

	# ── Action Buttons ──
	if _is_daily_challenge:
		var back_cal_btn := Button.new()
		back_cal_btn.text = "بازگشت به تقویم چالش 🗓️"
		back_cal_btn.custom_minimum_size = Vector2(0, 114)
		back_cal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back_cal_btn.add_theme_font_override("font", MenuStyle.vazir_bold())
		back_cal_btn.add_theme_font_size_override("font_size", 34)
		back_cal_btn.add_theme_color_override("font_color", Color.WHITE)

		var c_sb := StyleBoxFlat.new()
		c_sb.bg_color = Color("#2563EB")
		c_sb.set_corner_radius_all(24)
		c_sb.shadow_color = Color(37.0 / 255.0, 99.0 / 255.0, 235.0 / 255.0, 0.3)
		c_sb.shadow_size = 10
		c_sb.shadow_offset = Vector2(0, 4)
		back_cal_btn.add_theme_stylebox_override("normal", c_sb)
		var c_hover := c_sb.duplicate() as StyleBoxFlat
		c_hover.bg_color = Color("#1D4ED8")
		back_cal_btn.add_theme_stylebox_override("hover", c_hover)
		var c_press := c_sb.duplicate() as StyleBoxFlat
		c_press.bg_color = Color("#1E40AF")
		back_cal_btn.add_theme_stylebox_override("pressed", c_press)
		back_cal_btn.add_theme_stylebox_override("focus", c_sb)

		back_cal_btn.pressed.connect(func() -> void:
			Sfx.click()
			_on_back_pressed())
		UiMotion.wire_microinteractions(back_cal_btn)
		col.add_child(back_cal_btn)
		return

	if _has_next_lesson(_book, _lesson):
		var next_btn := Button.new()
		next_btn.text = "درس بعدی ❯"
		next_btn.custom_minimum_size = Vector2(0, 114)
		next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_btn.add_theme_font_override("font", MenuStyle.vazir_bold())
		next_btn.add_theme_font_size_override("font_size", 34)
		next_btn.add_theme_color_override("font_color", Color.WHITE)

		var n_sb := StyleBoxFlat.new()
		n_sb.bg_color = Color("#2563EB")
		n_sb.set_corner_radius_all(24)
		n_sb.shadow_color = Color(37.0 / 255.0, 99.0 / 255.0, 235.0 / 255.0, 0.3)
		n_sb.shadow_size = 10
		n_sb.shadow_offset = Vector2(0, 4)
		next_btn.add_theme_stylebox_override("normal", n_sb)
		var n_hover := n_sb.duplicate() as StyleBoxFlat
		n_hover.bg_color = Color("#1D4ED8")
		next_btn.add_theme_stylebox_override("hover", n_hover)
		var n_press := n_sb.duplicate() as StyleBoxFlat
		n_press.bg_color = Color("#1E40AF")
		next_btn.add_theme_stylebox_override("pressed", n_press)
		next_btn.add_theme_stylebox_override("focus", n_sb)

		next_btn.pressed.connect(func() -> void:
			Sfx.click()
			_start_learning(_book, _lesson + 1))
		UiMotion.wire_microinteractions(next_btn)
		col.add_child(next_btn)

	var replay_btn := Button.new()
	replay_btn.text = "تکرار این درس 🔄"
	replay_btn.custom_minimum_size = Vector2(0, 108)
	replay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_btn.add_theme_font_override("font", MenuStyle.vazir_bold())
	replay_btn.add_theme_font_size_override("font_size", 32)
	replay_btn.add_theme_color_override("font_color", Color("#1E293B"))

	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color.WHITE
	r_sb.border_width_left = 2
	r_sb.border_width_top = 2
	r_sb.border_width_right = 2
	r_sb.border_width_bottom = 2
	r_sb.border_color = Color("#CBD5E1")
	r_sb.set_corner_radius_all(24)
	r_sb.shadow_color = Color(0, 0, 0, 0.04)
	r_sb.shadow_size = 6
	r_sb.shadow_offset = Vector2(0, 2)
	replay_btn.add_theme_stylebox_override("normal", r_sb)
	var r_hover := r_sb.duplicate() as StyleBoxFlat
	r_hover.bg_color = Color("#F8FAFC")
	replay_btn.add_theme_stylebox_override("hover", r_hover)
	var r_press := r_sb.duplicate() as StyleBoxFlat
	r_press.bg_color = Color("#F1F5F9")
	replay_btn.add_theme_stylebox_override("pressed", r_press)
	replay_btn.add_theme_stylebox_override("focus", r_sb)

	replay_btn.pressed.connect(func() -> void:
		Sfx.click()
		_start_learning(_book, _lesson))
	UiMotion.wire_microinteractions(replay_btn)
	col.add_child(replay_btn)

	var select_btn := Button.new()
	select_btn.text = "انتخاب درس دیگر 📚"
	select_btn.custom_minimum_size = Vector2(0, 96)
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.add_theme_font_override("font", MenuStyle.vazir())
	select_btn.add_theme_font_size_override("font_size", 30)
	select_btn.add_theme_color_override("font_color", Color("#64748B"))
	select_btn.flat = true
	select_btn.pressed.connect(func() -> void:
		Sfx.click()
		_show_book_select())
	UiMotion.wire_microinteractions(select_btn)
	col.add_child(select_btn)


func _make_stat_box(title: String, val: String, accent_col: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, 120)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.08)
	sb.border_width_top = 4
	sb.border_color = accent_col
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_override("font", MenuStyle.vazir())
	t_lbl.add_theme_font_size_override("font_size", 22)
	t_lbl.add_theme_color_override("font_color", Color("#64748B"))
	col.add_child(t_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	v_lbl.add_theme_font_size_override("font_size", 32)
	v_lbl.add_theme_color_override("font_color", accent_col)
	col.add_child(v_lbl)

	return box


func _has_next_lesson(book: int, lesson: int) -> bool:
	var book_data := ScrambledData.book_data(book)
	var lessons: Array = book_data.get("lessons", [])
	for l_data: Variant in lessons:
		if l_data is Dictionary and int(l_data.get("lesson", 0)) == lesson + 1:
			return true
	return false


# ══════════════════════════════════════════════════════════════
#  DATA LOADING HELPERS
# ══════════════════════════════════════════════════════════════

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

	# Fallback to ScrambledData
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


func _load_book_words(book: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var path: String = "res://data/v%d_vocabularies.json" % book
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			for lesson_data: Variant in parsed:
				if not lesson_data is Dictionary or int(lesson_data.get("book", 0)) != book:
					continue
				var vocabulary: Dictionary = lesson_data.get("vocabulary", {})
				var words: Variant = vocabulary.get("words", [])
				if words is Array:
					for raw: Variant in words:
						if raw is Dictionary:
							var entry: Dictionary = raw
							if not str(entry.get("word", "")).is_empty() and not str(entry.get("meaning_fa", "")).is_empty():
								result.append(entry.duplicate())
	return result


func _load_all_project_words() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var seen: Dictionary = {}
	for b in [1, 2, 3]:
		var book_words := _load_book_words(b)
		for entry: Dictionary in book_words:
			var w: String = str(entry.get("word", "")).strip_edges().to_lower()
			if not w.is_empty() and not seen.has(w):
				seen[w] = true
				all.append(entry)
	var fallback_all: Array = ScrambledData.all_words()
	for raw: Variant in fallback_all:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var w: String = str(entry.get("word", "")).strip_edges()
		var fa: String = str(entry.get("meaning_fa", entry.get("meaning", ""))).strip_edges()
		if not w.is_empty() and not fa.is_empty() and not seen.has(w.to_lower()):
			seen[w.to_lower()] = true
			all.append({"word": w, "meaning_fa": fa})
	return all


func _make_label(text: String, font_size: int, centered: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#17324D"))
	return label


func _show_message(message: String) -> void:
	_clear_content()
	content.add_child(_make_label(message, 34, true))


func _clear_content() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
