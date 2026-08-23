extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# WORKBOOK SCENE — Each Part is a separate swipeable page
# Page 1: Part I (Reading Comprehension)
# Page 2: Part II (Vocabulary)
# Page 3: Part III (Grammar)
# Page 4: Part IV (Pronunciation)
# Page 5: Part V (Writing)
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

# Teal accent for Workbook
const ACCENT := Color("#0D9488")

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var translation_toggle: Button = $HeaderBar/HeaderContent/TranslationToggleButton
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _data: Dictionary = {}
var _current_book: int = 0
var _current_lesson: int = 0

# Master Farsi-translation switch. Starts off so translations are hidden on
# open; the header toggle flips it and shows/hides every passage, grammar
# note, and exercise translation.
var show_translation: bool = false
var _engines: Array = []       # ExerciseEngine instances on the current page
var _fa_labels: Array = []     # Farsi labels from passage/grammar-note cards
var _theme_targets: Array[Callable] = []  # restyle callbacks for dynamic nodes


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold    = load(FONT_BOLD_PATH)
	font_farsi   = load(FONT_VAZIRMATN)
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	translation_toggle.pressed.connect(_on_translation_toggle_pressed)
	page_view.set_accent(ACCENT)

	_current_book = Global.current_book
	_current_lesson = Global.current_lesson
	header_title.text = "Lesson %d\nWorkbook" % _current_lesson
	_update_toggle_button_text()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	_data = Global.load_category("workbook", _current_book, _current_lesson)
	
	if _data.is_empty():
		_show_empty_message()
		return
	
	_build_workbook_pages()


# ============================================================
# THEME
# ============================================================
# Returns the given fixed color in dark mode (identical to today) or the
# matching palette role in light mode.
func _palette(dark_color: Color, role: String) -> Color:
	return dark_color if Global.theme_is_dark() else Global.get_theme_color(role)


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	# Full-screen page background.
	var background := get_node_or_null("Background") as ColorRect
	if background:
		background.color = Color(0.17254902, 0.21960784, 0.49803922, 1) \
			if Global.theme_is_dark() else Global.get_theme_color("bg_base")
	# Restyle every dynamically built themed node for the current mode.
	for target in _theme_targets:
		target.call()


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()


# ============================================================
# SHOW MESSAGE IF NO DATA
# ============================================================
func _show_empty_message() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	banner.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	
	var icon := Label.new()
	icon.text = "📝"
	icon.add_theme_font_size_override("font_size", 72)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(icon)
	
	var title := Label.new()
	title.text = "Workbook"
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold: title.add_theme_font_override("font", font_bold)
	vb.add_child(title)
	
	banner.add_child(vb)
	page.add_child(banner)
	
	var msg := Label.new()
	msg.text = "📚 Workbook content for Lesson %d is not available yet.\n\nPlease check that the workbook.json file exists at:\nres://data/workbook.json" % _current_lesson
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_size_override("font_size", 36)
	msg.add_theme_color_override("font_color", _palette(Color("#64748B"), "text_dim"))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theme_targets.append(func() -> void:
		msg.add_theme_color_override("font_color", _palette(Color("#64748B"), "text_dim")))
	if font_regular: msg.add_theme_font_override("font", font_regular)
	page.add_child(msg)
	
	page_view.add_page("empty", "Workbook", "📝", page)


# ============================================================
# BUILD WORKBOOK PAGES — One page per Part
# ============================================================
func _build_workbook_pages() -> void:
	var lesson_title: Dictionary = _data.get("lesson_title", {})
	var parts: Array = _data.get("parts", [])
	
	if parts.is_empty():
		_show_empty_message()
		return
	
	# Create a page for each part
	for i in parts.size():
		var part: Dictionary = parts[i]
		var page := _build_part_page(i + 1, part, lesson_title)
		page_view.add_page("part_%d" % (i + 1), "Part %s" % _number_to_roman(i + 1), "📄", page)


# ============================================================
# BUILD SINGLE PART PAGE
# ============================================================
# ============================================================
# BUILD SINGLE PART PAGE
# ============================================================
func _build_part_page(part_num: int, part: Dictionary, lesson_title: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	
	# Part banner
	var part_title: Dictionary = part.get("part_title", {})
	page.add_child(_make_part_banner(part_num, part_title, lesson_title))
	
	# --- NEW: Show reading passage if it exists (Part I) ---
	if part.has("passage"):
		var passage: Dictionary = part["passage"]
		var passage_card := _make_passage_card(passage)
		page.add_child(passage_card)
	
	# --- NEW: Show grammar note if it exists (Part III) ---
	if part.has("grammar_note"):
		var grammar_note: Dictionary = part["grammar_note"]
		var note_card := _make_grammar_note_card(grammar_note)
		page.add_child(note_card)
	
	# Exercises for this part
	var exercises: Array = part.get("exercises", [])
	for exercise in exercises:
		var engine := ExerciseEngine.new()
		
		# Choose which exercise types show the audio button.
		# Must be set BEFORE build().
		engine.audio_types = [
			"multiple_choice",
			"fill_blank",
			"cloze",
		]
		
		engine.audio_panel_scene_path = "res://scenes/shared/AudioPanel.tscn"
		
		page.add_child(engine)
		engine.build(exercise)
		engine.set_show_translation(show_translation)
		_engines.append(engine)
	
	# Bottom spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 120)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)
	
	return page

# ============================================================
# WIDGETS
# ============================================================
func _make_part_banner(part_num: int, part_title: Dictionary, lesson_title: Dictionary) -> PanelContainer:
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	banner.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	
	# Part number
	var num_label := Label.new()
	num_label.text = "Part %s" % _number_to_roman(part_num)
	num_label.add_theme_font_size_override("font_size", 50)
	num_label.add_theme_color_override("font_color", Color.WHITE)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold: num_label.add_theme_font_override("font", font_bold)
	vb.add_child(num_label)
	
	# Part title (EN)
	var title_en := Label.new()
	title_en.text = part_title.get("en", "")
	title_en.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_en.add_theme_font_size_override("font_size", 38)
	title_en.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	title_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_regular: title_en.add_theme_font_override("font", font_regular)
	vb.add_child(title_en)
	
	# Part title (FA)
	var title_fa := Label.new()
	title_fa.text = part_title.get("fa", "")
	title_fa.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_fa.add_theme_font_size_override("font_size", 34)
	title_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	title_fa.text_direction = Control.TEXT_DIRECTION_RTL
	title_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_farsi: title_fa.add_theme_font_override("font", font_farsi)
	vb.add_child(title_fa)
	
	# Lesson title (smaller, at bottom)
	var lesson_en := Label.new()
	lesson_en.text = "Lesson: " + lesson_title.get("en", "")
	lesson_en.autowrap_mode = TextServer.AUTOWRAP_WORD
	lesson_en.add_theme_font_size_override("font_size", 30)
	lesson_en.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	lesson_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_regular: lesson_en.add_theme_font_override("font", font_regular)
	vb.add_child(lesson_en)
	
	banner.add_child(vb)
	return banner


# ============================================================
# PASSAGE CARD (for Reading Comprehension parts)
# ============================================================
func _make_passage_card(passage: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _palette(Color("#F8FAFC"), "surface")
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	_theme_targets.append(func() -> void:
		style.bg_color = _palette(Color("#F8FAFC"), "surface"))
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	
	# Header
	var header := Label.new()
	header.text = "📖 Reading Passage"
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", ACCENT)
	if font_bold: header.add_theme_font_override("font", font_bold)
	vb.add_child(header)
	
	# English and Farsi are split into paragraphs and interleaved, so each
	# English paragraph is immediately followed by its Farsi translation
	# instead of showing the whole text in English and then all in Farsi.
	var en_text: String = passage.get("en", "")
	var fa_text: String = passage.get("fa", "")
	var en_paras := _split_paragraphs(en_text)
	var fa_paras := _split_paragraphs(fa_text)

	if fa_paras.size() > 0 and fa_paras.size() == en_paras.size():
		for i in en_paras.size():
			vb.add_child(_make_passage_en_label(en_paras[i]))
			vb.add_child(_make_passage_fa_label(fa_paras[i]))
	else:
		# Fallback: show the full English text then the full Farsi text.
		if en_text != "":
			vb.add_child(_make_passage_en_label(en_text))
		if fa_text != "":
			vb.add_child(_make_passage_fa_label(fa_text))

	card.add_child(vb)
	return card


# Splits text into non-empty paragraphs on blank lines ("\n\n").
func _split_paragraphs(text: String) -> Array:
	var out: Array = []
	for p in text.split("\n\n"):
		var s := p.strip_edges()
		if s != "":
			out.append(p)
	return out


func _make_passage_en_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", _palette(Color("#1E293B"), "text"))
	if font_regular:
		label.add_theme_font_override("font", font_regular)
	_theme_targets.append(func() -> void:
		label.add_theme_color_override("font_color", _palette(Color("#1E293B"), "text")))
	return label


func _make_passage_fa_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", _palette(Color("#64748B"), "text_dim"))
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi:
		label.add_theme_font_override("font", font_farsi)
	label.visible = show_translation
	_fa_labels.append(label)
	_theme_targets.append(func() -> void:
		label.add_theme_color_override("font_color", _palette(Color("#64748B"), "text_dim")))
	return label


# ============================================================
# GRAMMAR NOTE CARD (for Grammar parts)
# ============================================================
func _make_grammar_note_card(grammar_note: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _palette(Color("#FEF9C3"), "surface")
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = _palette(Color("#CA8A04"), "border")
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	_theme_targets.append(func() -> void:
		style.bg_color = _palette(Color("#FEF9C3"), "surface")
		style.border_color = _palette(Color("#CA8A04"), "border"))
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	
	# Header
	var header := Label.new()
	header.text = "📐 Grammar Note"
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", _palette(Color("#92400E"), "accent"))
	if font_bold: header.add_theme_font_override("font", font_bold)
	vb.add_child(header)
	_theme_targets.append(func() -> void:
		header.add_theme_color_override("font_color", _palette(Color("#92400E"), "accent")))
	
	# English explanation
	var en_text: String = grammar_note.get("en", "")
	if en_text != "":
		var en_label := Label.new()
		en_label.text = en_text
		en_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		en_label.add_theme_font_size_override("font_size", 34)
		en_label.add_theme_color_override("font_color", _palette(Color("#1E293B"), "text"))
		if font_regular: en_label.add_theme_font_override("font", font_regular)
		vb.add_child(en_label)
		_theme_targets.append(func() -> void:
			en_label.add_theme_color_override("font_color", _palette(Color("#1E293B"), "text")))
	
	# Farsi explanation
	var fa_text: String = grammar_note.get("fa", "")
	if fa_text != "":
		var fa_label := Label.new()
		fa_label.text = fa_text
		fa_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		fa_label.add_theme_font_size_override("font_size", 32)
		fa_label.add_theme_color_override("font_color", _palette(Color("#78716C"), "text_dim"))
		fa_label.text_direction = Control.TEXT_DIRECTION_RTL
		fa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if font_farsi: fa_label.add_theme_font_override("font", font_farsi)
		fa_label.visible = show_translation
		_fa_labels.append(fa_label)
		vb.add_child(fa_label)
		_theme_targets.append(func() -> void:
			fa_label.add_theme_color_override("font_color", _palette(Color("#78716C"), "text_dim")))
	
	card.add_child(vb)
	return card


func _number_to_roman(num: int) -> String:
	match num:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
		6: return "VI"
		7: return "VII"
		8: return "VIII"
		9: return "IX"
		10: return "X"
		_: return str(num)


# ============================================================
# TRANSLATION TOGGLE
# ============================================================
# Flips the master switch and applies it to every Farsi label already on
# the page: workbook passage/grammar-note labels plus each exercise
# engine's translations. Toggling only changes .visible, so the layout
# (which already reserves space for the labels) never reflows.
func _on_translation_toggle_pressed() -> void:
	show_translation = !show_translation
	_update_toggle_button_text()
	for label in _fa_labels:
		if is_instance_valid(label):
			label.visible = show_translation
	for engine in _engines:
		if is_instance_valid(engine):
			engine.set_show_translation(show_translation)


func _update_toggle_button_text() -> void:
	if translation_toggle == null:
		return
	translation_toggle.text = "🔽 Hide Translation" if show_translation else "🔼 Show Translation"


# Returns the user to the main menu.
func _on_home_pressed() -> void:
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")


# ============================================================
# NAVIGATION
# ============================================================
func _on_back_button_pressed() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
