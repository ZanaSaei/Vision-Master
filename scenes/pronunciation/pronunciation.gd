extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# PRONUNCIATION SCENE — powered by data/v_pronunciation.json
# ------------------------------------------------------------
# Structure of the data file (books -> lessons -> pages):
#   books: [ { "book": "Vision N", "lessons": [ ... ] } ]
#   lesson: { "lesson_number", "lesson_title", "pronunciation_topic",
#             "pages": [ tip | exercise ] }
#   tip:      { "page_type":"tip", "content_en", "content_fa" }
#   exercise: { "page_type":"exercise", "exercise_letter":"A", ... }
#
# PAGING BEHAVIOUR:
#   * Page 1 shows only the pretty Tip box + an extra Persian explanation.
#   * Every exercise lives on its own page (A, B, ...).
#   * Exercises that require the workbook (e.g. "Go to Part IV...")
#     are skipped entirely.
#
# INTERACTIVE EXERCISES:
#   Answerable exercises carry an "engine" object in the JSON; they are
#   rendered with the shared ExerciseEngine (multiple-choice, etc.) with
#   the options/answers authored in data/v_pronunciation.json. Exercises
#   that only need listening/repeating stay as plain read-only cards.
#
# AUDIO:
#   Each exercise (A, B, ...) maps to the audio file
#   assets/audio/v{book}/l{lesson}/p{n}.mp3  (A=1, B=2, ...).
#   The audio button (shown at the top of the exercise) is only rendered
#   when that file actually exists; it opens the shared AudioPanel.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"
const PRONUNCIATION_DATA_PATH := "res://data/v_pronunciation.json"

# Global scale applied to every text size so fonts render larger.
const FONT_SCALE := 1.15

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

# ---------- Accent / status colors ----------
const ACCENT := Color("#0891B2")
const EXERCISE_ACCENT := Color("#0EA5E9")
const TIP_BORDER := Color("#F59E0B")
const TIP_TITLE := Color("#F59E0B")

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView
@onready var background: ColorRect = $Background
@onready var audio_panel = $AudioPanel

var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}
var _data: Dictionary = {}

func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_farsi = load(FONT_VAZIRMATN)

	if font_bold:
		header_title.add_theme_font_override("font", font_bold)
	# The bar owns its title's type ramp; see HeaderBarStyler.
	HeaderBarStyler.style_title(header_title)

	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)
	Global.on_theme_changed(_apply_theme)
	_add_page_view_background()

	if audio_panel != null:
		audio_panel.audio_closed.connect(func(): _on_audio_closed())
		# Swiping on the AudioPanel (slider/buttons) must never swipe pages.
		page_view.add_swipe_blocker(audio_panel)

	header_title.text = MenuStyle.persian_digits("درس %d\nتلفظ" % Global.current_lesson)
	_data = _load_v_pronunciation()
	if _data.is_empty():
		return

	_build_pages()
	_apply_dark_scroll_background(page_view)
	_play_reveal(0)
	_apply_theme()

# ============================================================
# DATA LOADING (data/v_pronunciation.json)
# ============================================================
func _load_v_pronunciation() -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(PRONUNCIATION_DATA_PATH):
		push_warning("Pronunciation data not found: " + PRONUNCIATION_DATA_PATH)
		return result

	var file := FileAccess.open(PRONUNCIATION_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open " + PRONUNCIATION_DATA_PATH)
		return result
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("v_pronunciation.json parse error: " + json.get_error_message())
		return result

	var root: Dictionary = json.data
	var lesson_entry := _find_lesson(root.get("books", []), Global.current_book, Global.current_lesson)
	if lesson_entry.is_empty():
		return result

	result["lesson_title"] = str(lesson_entry.get("lesson_title", ""))
	result["topic"] = str(lesson_entry.get("pronunciation_topic", ""))
	result["tip"] = {}
	result["exercises"] = []

	for page in lesson_entry.get("pages", []):
		match str(page.get("page_type", "")):
			"tip":
				result["tip"] = page
			"exercise":
				if _is_workbook_exercise(page):
					continue
				result["exercises"].append(page)

	return result

# Finds the requested lesson inside the nested books -> lessons structure.
func _find_lesson(books: Array, book_number: int, lesson_number: int) -> Dictionary:
	for book in books:
		var bn := _book_number(book)
		if bn != book_number:
			continue
		for lesson in book.get("lessons", []):
			if int(lesson.get("lesson_number", 0)) == lesson_number:
				return lesson
	return {}

# "Vision 1" -> 1, "Vision 2" -> 2, ...
func _book_number(book: Dictionary) -> int:
	var book_name := str(book.get("book", ""))
	var m := RegEx.new()
	m.compile("(\\d+)")
	var match := m.search(book_name)
	if match:
		return int(match.get_string(1))
	return -1

# Exercises that point to the school workbook are skipped on purpose.
func _is_workbook_exercise(page: Dictionary) -> bool:
	var en := str(page.get("instruction_en", "")).to_lower()
	var fa := str(page.get("instruction_fa", "")).to_lower()
	if "workbook" in en or "part iv" in en or "part 4" in en:
		return true
	if "کتاب کار" in fa or "بخش چهارم" in fa:
		return true
	return false

# ============================================================
# PAGE BUILDING
# ============================================================
func _build_pages() -> void:
	var exercises: Array = _data.get("exercises", [])
	var tip: Dictionary = _data.get("tip", {})

	# Page 0 = the tip box + extra Persian explanation (tip only).
	if not tip.is_empty():
		_add_page(_page_reveals.size(), _build_tip_page(tip))

	# Page 1, 2, ... = one exercise per page (A, B, ...).
	for i in range(exercises.size()):
		_add_page(_page_reveals.size(), _build_exercise_page(exercises[i]))

func _add_page(index: int, content: Control) -> void:
	var title := _page_title(index)
	page_view.add_page("pron_%d" % index, title, _page_icon(index), content)
	_apply_dark_scroll_background(page_view)

func _page_title(index: int) -> String:
	if index == 0:
		return "نکته"
	var exercises: Array = _data.get("exercises", [])
	if index - 1 < exercises.size():
		return _exercise_letter(exercises[index - 1])
	return "تمرین"

func _page_icon(index: int) -> String:
	if index == 0:
		return "📖"
	return "✏️"

func _build_tip_page(tip: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	var index := _page_reveals.size()
	_page_reveals[index] = []

	var banner := _make_lesson_banner(str(_data.get("lesson_title", "")), str(_data.get("topic", "")))
	page.add_child(banner)
	_page_reveals[index].append(banner)

	var tip_card := _make_tip_card(tip)
	page.add_child(tip_card)
	_page_reveals[index].append(tip_card)

	var info_card := _make_tip_info_card(tip)
	page.add_child(info_card)
	_page_reveals[index].append(info_card)
	return page

func _build_exercise_page(exercise: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	var index := _page_reveals.size()
	_page_reveals[index] = []
	var ex_card := _make_exercise_card(exercise)
	page.add_child(ex_card)
	_page_reveals[index].append(ex_card)
	return page

# ============================================================
# WIDGETS
# ============================================================
func _make_lesson_banner(lesson_title: String, topic: String) -> PanelContainer:
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(20)
	style.set_content_margin_all(22)
	banner.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	var title := _make_label(lesson_title, 44, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	if topic != "":
		var topic_l := _make_label(topic, 34, Color("E0F2FE"), false)
		topic_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(topic_l)

	banner.add_child(vb)
	return banner

# A colourful, framed box for the pronunciation tip.
func _make_tip_card(tip: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _tip_bg()
	style.set_corner_radius_all(18)
	style.border_width_left = 10
	style.border_color = TIP_BORDER
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var icon := Label.new()
	icon.text = "💡"
	icon.add_theme_font_size_override("font_size", int(58 * FONT_SCALE))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	var title := _make_label("Tip  /  نکته", 42, TIP_TITLE, true, false)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	vb.add_child(head)

	vb.add_child(_make_label(str(tip.get("content_en", "")), 37, _text_color(), false))

	var fa := str(tip.get("content_fa", ""))
	if fa != "":
		vb.add_child(_make_fa_label(fa, 33, _text_soft_color()))

	card.add_child(vb)
	return card

func _tip_bg() -> Color:
	if Global.theme_is_dark():
		return _dark_tint(TIP_BORDER)
	return Color("FEF3C7")

# Extra Persian explanation shown under the tip box to enrich the tip page.
# Reads "more_tip_fa" from the lesson's tip page in the JSON; falls back to
# a short generic explanation when a lesson has none.
func _make_tip_info_card(tip: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _info_bg()
	style.set_corner_radius_all(18)
	style.border_width_left = 10
	style.border_color = Color("#0EA5E9")
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var icon := Label.new()
	icon.text = "📌"
	icon.add_theme_font_size_override("font_size", int(54 * FONT_SCALE))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	var title := _make_label("توضیح بیشتر  /  More", 40, Color("#0369A1"), true, false)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	vb.add_child(head)

	var more := str(tip.get("more_tip_fa", "")).strip_edges()
	if more != "":
		# Lesson-specific, richer explanation authored in the JSON.
		vb.add_child(_make_fa_label(more, 32, _text_color()))
	else:
		var info := "آهنگ جمله (intonation) یعنی بالا و پایین رفتن صدای شما در هنگام صحبت. به پایان هر جمله دقت کنید: اگر جمله خبری باشد یا اطلاعات جدیدی بدهد، صدای شما معمولاً در پایان پایین می‌رود؛ اگر جمله سؤال بله/خیر یا بررسی اطلاعات باشد، صدای شما در پایان بالا می‌رود. برای یادگیری بهتر، هر جمله را چند بار بلند بخوانید و با گزینهٔ صدا مقایسه کنید تا این مهارت برایتان طبیعی شود."
		vb.add_child(_make_fa_label(info, 32, _text_color()))
		var hint := "💬 سعی کنید ابتدا به صدای ضبط‌شده گوش دهید، سپس همان جمله را با همان آهنگ تکرار کنید و صدای خودتان را ضبط و مقایسه کنید."
		vb.add_child(_make_fa_label(hint, 30, _text_soft_color()))

	card.add_child(vb)
	return card

func _info_bg() -> Color:
	if Global.theme_is_dark():
		return _dark_tint(Color("#38BDF8"))
	return Color("E0F2FE")

func _make_exercise_card(exercise: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface")
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = EXERCISE_ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)

	var letter := _exercise_letter(exercise)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(_make_letter_badge(letter))
	var ex_title := _make_label("Exercise  /  تمرین", 40, EXERCISE_ACCENT, true, false)
	ex_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ex_title)
	vb.add_child(head)

	# Audio button near the top of the exercise (only when an audio file exists).
	var audio_path := _exercise_audio_path(letter)
	if audio_path != "" and Content.has_asset(audio_path):
		vb.add_child(_make_audio_btn(audio_path))

	# Answerable exercises run inside the shared interactive ExerciseEngine.
	var engine_data: Dictionary = exercise.get("engine", {})
	if not engine_data.is_empty():
		_build_engine_block(vb, exercise, engine_data)
	else:
		var instr_en := str(exercise.get("instruction_en", ""))
		if instr_en != "":
			vb.add_child(_make_label(instr_en, 35, _text_color(), false))
		var instr_fa := str(exercise.get("instruction_fa", ""))
		if instr_fa != "":
			vb.add_child(_make_fa_label(instr_fa, 30, _text_soft_color()))

		var note_text := str(exercise.get("note", ""))
		if note_text != "" and note_text.to_lower() != "none":
			vb.add_child(_make_note_label(note_text))

		for item in exercise.get("items", []):
			vb.add_child(_make_item_row(item))

		var text_en := str(exercise.get("text_en", ""))
		if text_en != "":
			vb.add_child(_make_item_row({"en": text_en, "fa": str(exercise.get("text_fa", ""))}))

		for line in exercise.get("dialogue", []):
			vb.add_child(_make_dialogue_line(line))

	card.add_child(vb)
	return card

# ============================================================
# INTERACTIVE ENGINE BLOCK (answerable exercises)
# ============================================================
func _build_engine_block(target_vb: VBoxContainer, exercise: Dictionary, engine_data: Dictionary) -> void:
	var merged := exercise.duplicate(true)
	merged["type"] = str(engine_data.get("type", "multiple_choice"))
	merged["items"] = engine_data.get("items", [])
	if engine_data.has("options"):
		merged["options"] = engine_data.get("options", [])
	if engine_data.has("passage"):
		merged["passage"] = engine_data.get("passage", "")
	if engine_data.has("note"):
		merged["note"] = engine_data.get("note", "")
	# The engine reads "instruction" (en/fa) directly.
	merged["instruction"] = {
		"en": str(exercise.get("instruction_en", "")),
		"fa": str(exercise.get("instruction_fa", ""))
	}
	# Our own header already shows the letter badge, so don't duplicate it.
	merged["show_letter"] = false

	var engine := ExerciseEngine.new()
	target_vb.add_child(engine)
	engine.build(merged)
	_apply_dark_scroll_background(engine)

func _make_letter_badge(letter: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = EXERCISE_ACCENT
	style.set_corner_radius_all(30)
	style.set_content_margin_all(10)
	badge.add_theme_stylebox_override("panel", style)

	var l := Label.new()
	l.text = letter
	l.add_theme_font_size_override("font_size", int(44 * FONT_SCALE))
	l.add_theme_color_override("font_color", Color.WHITE)
	if font_bold:
		l.add_theme_font_override("font", font_bold)
	badge.add_child(l)
	return badge

func _make_note_label(text: String) -> PanelContainer:
	var note := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.0)
	style.set_corner_radius_all(10)
	style.border_width_bottom = 2
	style.border_color = _dark_tint(ACCENT)
	style.set_content_margin_all(10)
	note.add_theme_stylebox_override("panel", style)
	var l := _make_label(text, 27, _text_soft_color(), false)
	l.add_theme_font_style_override("italic", true)
	note.add_child(l)
	return note

func _make_item_row(item: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _item_bg()
	style.set_corner_radius_all(12)
	if not Global.theme_is_dark():
		style.border_width_left = 4
		style.border_color = EXERCISE_ACCENT
	style.set_content_margin_all(14)
	row.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var en := str(item.get("en", ""))
	if en != "":
		vb.add_child(_make_label(en, 35, _text_color(), false))
	var fa := str(item.get("fa", ""))
	if fa != "":
		vb.add_child(_make_fa_label(fa, 29, _text_soft_color()))
	row.add_child(vb)
	return row

func _item_bg() -> Color:
	if Global.theme_is_dark():
		return _dark_tint(Color("38BDF8"))
	return Color("E0F2FE")

func _make_dialogue_line(line: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if Global.theme_is_dark():
		style.bg_color = _dark_tint(Color("A78BFA"))
	else:
		style.bg_color = Color("EDE9FE")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var badge := _make_letter_badge(str(line.get("speaker", "?")))
	badge.modulate = Color("8B5CF6")
	hb.add_child(badge)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var en := str(line.get("en", ""))
	if en != "":
		vb.add_child(_make_label(en, 33, _text_color(), false))
	var fa := str(line.get("fa", ""))
	if fa != "":
		vb.add_child(_make_fa_label(fa, 28, _text_soft_color()))
	hb.add_child(vb)

	row.add_child(hb)
	return row

# ============================================================
# AUDIO BUTTON -> shared AudioPanel
# ============================================================
# Maps the exercise letter to an index: A=1, B=2, C=3, ...
func _letter_index(letter: String) -> int:
	var code := letter.unicode_at(0)
	if code >= 65 and code <= 90:   # 'A'..'Z'
		return code - 65 + 1
	return 1

func _exercise_letter(exercise: Dictionary) -> String:
	var letter := str(exercise.get("exercise_letter", ""))
	if letter == "":
		return "?"
	return letter

func _exercise_audio_path(letter: String) -> String:
	if letter == "?":
		return ""
	var filename := "p%d.mp3" % _letter_index(letter)
	return Global.get_audio_path(Global.current_book, Global.current_lesson, filename)

func _make_audio_btn(audio_path: String) -> Button:
	var btn := Button.new()
	btn.text = "🔊  پخش صدا"
	btn.custom_minimum_size = Vector2(300, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.add_theme_font_size_override("font_size", int(32 * FONT_SCALE))

	var style := StyleBoxFlat.new()
	style.bg_color = Color("0EA5E9")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("38BDF8")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	if font_bold:
		btn.add_theme_font_override("font", font_bold)

	btn.pressed.connect(func():
		_tap_scale(btn)
		_open_audio(audio_path)
	)
	return btn

func _open_audio(audio_path: String) -> void:
	if audio_panel == null or not is_instance_valid(audio_panel):
		return
	audio_panel.load_and_play(audio_path)

func _on_audio_closed() -> void:
	pass

# ============================================================
# THEME / STYLE HELPERS
# ============================================================
func _add_page_view_background() -> void:
	if page_view.has_meta("dark_bg"):
		return
	var bg := ColorRect.new()
	bg.color = Global.get_theme_color("bg_base")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_view.add_child(bg)
	page_view.move_child(bg, 0)
	page_view.set_meta("dark_bg", bg)

func _apply_dark_scroll_background(root: Control) -> void:
	for child in root.get_children():
		if child is ScrollContainer:
			var style := StyleBoxFlat.new()
			style.bg_color = Global.get_theme_color("bg_base")
			child.add_theme_stylebox_override("panel", style)
		elif child is Control:
			_apply_dark_scroll_background(child)

func _dark_tint(color: Color, amount := 0.18) -> Color:
	return Global.get_theme_color("surface").lerp(Color(color.r, color.g, color.b, 1.0), amount)

func _text_color() -> Color:
	return Color.WHITE if Global.theme_is_dark() else Color.BLACK

func _text_soft_color() -> Color:
	if Global.theme_is_dark():
		return Color("CBD5E1")
	return Color(0.25, 0.28, 0.34)

func _apply_theme() -> void:
	if not is_inside_tree():
		return
	HeaderBarStyler.style_title(header_title)
	if background != null:
		background.color = Global.get_theme_color("bg_base")
	if page_view.has_meta("dark_bg"):
		var bg: ColorRect = page_view.get_meta("dark_bg")
		bg.color = Global.get_theme_color("bg_base")
	_apply_dark_scroll_background(page_view)

func _make_label(text: String, font_size: int, color: Color, bold: bool, do_wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if do_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.add_theme_font_size_override("font_size", int(float(font_size) * FONT_SCALE))
	l.add_theme_color_override("font_color", color)
	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)
	return l

func _make_fa_label(text: String, font_size: int, color: Color = Color.WHITE, do_wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if do_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.add_theme_font_size_override("font_size", int(float(font_size) * FONT_SCALE))
	l.add_theme_color_override("font_color", color)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi:
		l.add_theme_font_override("font", font_farsi)
	return l

# ============================================================
# INTERACTION / NAVIGATION
# ============================================================
func _on_page_changed(index: int, _page_id: String) -> void:
	_play_reveal(index)

func _play_reveal(index: int) -> void:
	if _page_revealed.get(index, false):
		return
	_page_revealed[index] = true
	var cards: Array = _page_reveals.get(index, [])
	for i in cards.size():
		var card: Control = cards[i]
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(
			card,
			"modulate:a",
			1.0,
			0.3
		).set_delay(0.07 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _tap_scale(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(0.94, 0.94), 0.06)
	t.tween_property(control, "scale", Vector2.ONE, 0.1)

func _on_home_pressed() -> void:
	if audio_panel != null and is_instance_valid(audio_panel):
		audio_panel.stop_and_close()
	_tap_scale(home_button)
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_back_button_pressed() -> void:
	if audio_panel != null and is_instance_valid(audio_panel):
		audio_panel.stop_and_close()
	_tap_scale(back_button)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()