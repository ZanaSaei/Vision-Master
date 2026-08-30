extends "res://autoload/BackButtonHandler.gd"

# ============================================================
# VOCABULARY DEVELOPMENT SCENE — three swipeable pages
# Page 1 "Learn"    → theory + reference tables
# Page 2 "Examples" → worked examples with word highlighting
# Page 3 "Practice" → interactive exercises
#
# Dark-theme harmonized version.
# Titles are kept on one line with wrapping disabled.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Global scale applied to every text size so fonts render larger.
const FONT_SCALE := 1.25

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

# ---------- Dark theme ----------
const APP_BG := Color("#0b1229")
const PANEL_BG := Color("#0f1b3d")
const PANEL_BORDER := Color("#2d3a6a")

const TEXT_LIGHT := Color("#F1F5F9")
const TEXT_SOFT := Color("#CBD5E1")
const TEXT_MUTED := Color("#94A3B8")

const SUCCESS := Color("#34D399")

# Distinct purple accent.
const ACCENT := Color("#7C3AED")

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile
var font_italic: FontFile

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView
@onready var background: ColorRect = $Background

var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}
var _data: Dictionary = {}


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_farsi = load(FONT_VAZIRMATN)

	# Optional italic font is not required.
	font_italic = null

	if font_bold:
		header_title.add_theme_font_override("font", font_bold)

	# Keep header readable on the current theme.
	header_title.add_theme_color_override("font_color", _text_color())

	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)
	# Restyle live when the app theme toggles.
	Global.on_theme_changed(_apply_theme)

	# Put a dark background behind the whole PageView.
	_add_page_view_background()

	header_title.text = "Lesson %d\nVocabulary" % Global.current_lesson

	_data = Global.load_category(
		"vocabulary_development",
		Global.current_book,
		Global.current_lesson
	)

	if _data.is_empty():
		return

	page_view.add_page("learn", "یادگیری", "📖", _build_learn_page())
	page_view.add_page("examples", "مثال‌ها", "💡", _build_examples_page())
	page_view.add_page("practice", "تمرین", "✏️", _build_practice_page())

	# Force backgrounds for PageView scroll areas.
	_apply_dark_scroll_background(page_view)

	_play_reveal(0)
	_apply_theme()


# ============================================================
# DARK THEME HELPERS
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

		if child is Control:
			_apply_dark_scroll_background(child)


func _dark_tint(color: Color, amount := 0.16) -> Color:
	# Creates a panel color tinted by the given accent color (theme surface).
	return Global.get_theme_color("surface").lerp(Color(color.r, color.g, color.b, 1.0), amount)


func _contrast_color(bg: Color) -> Color:
	# Chooses readable text color for colored banners/buttons.
	if bg.get_luminance() > 0.6:
		return Color("#0b1229")
	return Color.WHITE


func _text_color() -> Color:
	# Pure white in dark theme, pure black in light theme — maximum contrast.
	return Color.WHITE if Global.theme_is_dark() else Color.BLACK


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	header_title.add_theme_color_override("font_color", _text_color())
	# Scene background (behind the header) — from the theme source.
	if background != null:
		background.color = Global.get_theme_color("bg_base")
	# PageView background behind the content.
	if page_view.has_meta("dark_bg"):
		var bg: ColorRect = page_view.get_meta("dark_bg")
		bg.color = Global.get_theme_color("bg_base")
	_apply_dark_scroll_background(page_view)


# ============================================================
# PAGE 1 — LEARN
# ============================================================

func _build_learn_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	_page_reveals[0] = []

	# Topic banner.
	var topic_en := str(_data.get("topic", {}).get("en", "Vocabulary"))
	var topic_fa := str(_data.get("topic", {}).get("fa", "واژگان"))

	page.add_child(_make_topic_banner("📚", topic_en, topic_fa))

	# Definition card.
	var theory: Dictionary = _data.get("theory", {})

	if not theory.is_empty():
		var def: Dictionary = theory.get("definition", {})

		if not def.is_empty():
			var card := _make_text_card(
				str(def.get("en", "")),
				str(def.get("fa", "")),
				_dark_tint(ACCENT),
				ACCENT
			)

			page.add_child(card)
			_page_reveals[0].append(card)

		# Key points.
		var points: Array = theory.get("key_points", [])

		for point in points:
			page.add_child(_make_bullet(
				str(point.get("en", "")),
				str(point.get("fa", ""))
			))

	# Reference table.
	if _data.has("reference_table"):
		page.add_child(_make_section_title("Reference Table"))

		var table := _make_reference_table(_data["reference_table"])
		page.add_child(table)
		_page_reveals[0].append(table)

	return page


# ============================================================
# PAGE 2 — EXAMPLES
# ============================================================

func _build_examples_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	_page_reveals[1] = []

	page.add_child(_make_topic_banner("💡", "Examples", "مثال‌ها"))

	var examples: Array = _data.get("examples", [])

	if examples.is_empty():
		var empty := _make_label("No examples available yet.", 36, _text_color(), false)
		page.add_child(empty)
		return page

	for ex in examples:
		var card := _make_example_card(ex)
		page.add_child(card)
		_page_reveals[1].append(card)

	return page


# ============================================================
# PAGE 3 — PRACTICE
# ============================================================

func _build_practice_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	_page_reveals[2] = []

	page.add_child(_make_topic_banner("✏️", "Practice", "تمرین"))

	var intro := _make_text_card(
		"Test your understanding with these exercises!",
		"با این تمرین‌ها درک خود را بسنجید!",
		_dark_tint(SUCCESS, 0.10),
		SUCCESS
	)

	page.add_child(intro)
	_page_reveals[2].append(intro)

	for exercise in _data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
		_page_reveals[2].append(engine)

	return page


# ============================================================
# WIDGETS
# ============================================================

func _make_topic_banner(icon: String, en: String, fa: String) -> PanelContainer:
	var banner := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(20)
	style.set_content_margin_all(26)

	banner.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", int(72 * FONT_SCALE))
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ic)

	var text_color := _contrast_color(ACCENT)
	var sub_color := Color(text_color.r, text_color.g, text_color.b, 0.85)

	# Banner title: one line, no wrapping.
	var en_l := _make_label(en, 50, text_color, true)
	en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(en_l)

	var fa_l := _make_fa_label(fa, 36, sub_color)
	fa_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(fa_l)

	banner.add_child(vb)
	return banner


func _make_text_card(en: String, fa: String, bg: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_color = border
	style.set_content_margin_all(18)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	# Body text stays wrapped.
	vb.add_child(_make_label(en, 36, _text_color(), false))
	vb.add_child(_make_fa_label(fa, 31, _text_color()))

	card.add_child(vb)
	return card


func _make_bullet(en: String, fa: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	vb.add_child(_make_label("•  " + en, 34, _text_color(), false))
	vb.add_child(_make_fa_label(fa, 29, _text_color()))

	return vb


func _make_example_card(ex: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface")
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)

	# Word pair.
	var word_text := str(ex.get("word", ""))
	var synonym_text := str(ex.get("synonym", ""))

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Make the colored English word line much larger and bold.
	rtl.add_theme_font_size_override("normal_font_size", int(45 * FONT_SCALE))
	rtl.add_theme_font_size_override("bold_font_size", int(45 * FONT_SCALE))
	rtl.add_theme_color_override("default_color", _text_color())

	# Slightly brighter colors improve visibility on the dark panel.
	rtl.text = (
		"[color=#C4B5FD][b]" + word_text + "[/b][/color]"
		+ "  =  "
		+ "[color=#6EE7B7][b]" + synonym_text + "[/b][/color]"
	)

	if font_bold:
		rtl.add_theme_font_override("normal_font", font_bold)
		rtl.add_theme_font_override("bold_font", font_bold)

	vb.add_child(rtl)

	# Example sentence.
	var sentence: Dictionary = ex.get("sentence", {})
	if not sentence.is_empty():
		# Increase the English and Persian example sentences too.
		vb.add_child(_make_label(str(sentence.get("en", "")), 42, _text_color(), false))
		vb.add_child(_make_fa_label(str(sentence.get("fa", "")), 36, _text_color()))

	card.add_child(vb)
	return card

func _make_reference_table(table: Array) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface")
	style.set_corner_radius_all(14)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(18)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	for entry in table:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Affix label is a small title-like cell, so keep it on one line.
		var affix := _make_label(
			str(entry.get("affix", "")),
			34,
			ACCENT.lightened(0.25),
			true,
			false
		)
		affix.custom_minimum_size.x = 120
		row.add_child(affix)

		var meaning_en := _make_label(
			str(entry.get("meaning_en", "")),
			32,
			_text_color(),
			false
		)
		meaning_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(meaning_en)

		var example := _make_label(
			str(entry.get("example", "")),
			30,
			_text_color(),
			false
		)
		example.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if font_italic:
			example.add_theme_font_override("font", font_italic)

		row.add_child(example)

		vb.add_child(row)

	card.add_child(vb)
	return card


func _make_section_title(en: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(6, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	# Section title: one line, no wrapping, fills horizontally.
	var title := _make_label(en, 40, _text_color(), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	return row


func _make_label(text: String, font_size: int, color: Color, bold: bool, do_wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable wrapping for titles when requested.
	if do_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Apply global scale, then slightly shrink very long one-line titles.
	var base := int(float(font_size) * FONT_SCALE)
	var final_size := base
	if not do_wrap:
		if text.length() > 30:
			final_size = int(float(base) * 0.85)
		if text.length() > 55:
			final_size = int(float(base) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
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

	# Apply global scale, then slightly shrink very long one-line Persian titles.
	var base := int(float(font_size) * FONT_SCALE)
	var final_size := base
	if not do_wrap:
		if text.length() > 34:
			final_size = int(float(base) * 0.85)
		if text.length() > 60:
			final_size = int(float(base) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", color)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if font_farsi:
		l.add_theme_font_override("font", font_farsi)

	return l


# ============================================================
# ENTRANCE ANIMATION
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


# ============================================================
# NAVIGATION
# ============================================================

func _on_home_pressed() -> void:
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_back_button_pressed() -> void:
	back_button.pivot_offset = back_button.size / 2.0

	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
