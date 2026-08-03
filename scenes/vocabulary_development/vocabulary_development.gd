extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# VOCABULARY DEVELOPMENT SCENE — three swipeable pages
#   Page 1 "Learn"    → theory + reference tables
#   Page 2 "Examples" → worked examples with word highlighting
#   Page 3 "Practice" → interactive exercises
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile
var font_italic: FontFile

# Distinct purple accent — different from Grammar (blue) and Reading (teal)
const ACCENT := Color("#7C3AED")
const SOFT   := Color("#F5F3FF")

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}
var _data: Dictionary = {}


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold    = load(FONT_BOLD_PATH)
	font_farsi   = load(FONT_VAZIRMATN)
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	back_button.pressed.connect(_on_back_button_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)
	
	header_title.text = "Lesson %d\nVocabulary" % Global.current_lesson
	
	_data = Global.load_category("vocabulary_development", Global.current_book, Global.current_lesson)
	if _data.is_empty():
		return
	
	page_view.add_page("learn",    "Learn",    "📖", _build_learn_page())
	page_view.add_page("examples", "Examples", "💡", _build_examples_page())
	page_view.add_page("practice", "Practice", "✏️", _build_practice_page())
	
	_play_reveal(0)


# ============================================================
# PAGE 1 — LEARN (theory + reference tables)
# ============================================================
func _build_learn_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[0] = []
	
	# Topic banner
	var topic_en: String = _data.get("topic", {}).get("en", "Vocabulary")
	var topic_fa: String = _data.get("topic", {}).get("fa", "واژگان")
	page.add_child(_make_topic_banner("📚", topic_en, topic_fa))
	
	# Definition card
	var theory: Dictionary = _data.get("theory", {})
	if not theory.is_empty():
		var def: Dictionary = theory.get("definition", {})
		if not def.is_empty():
			var card := _make_text_card(def.get("en", ""), def.get("fa", ""), SOFT, ACCENT)
			page.add_child(card)
			_page_reveals[0].append(card)
		
		# Key points
		var points: Array = theory.get("key_points", [])
		for point in points:
			page.add_child(_make_bullet(point.get("en", ""), point.get("fa", "")))
	
	# Reference table (for Prefixes & Suffixes)
	if _data.has("reference_table"):
		page.add_child(_make_section_title("Reference Table"))
		page.add_child(_make_reference_table(_data["reference_table"]))
		_page_reveals[0].append(page.get_child(page.get_child_count() - 1))
	
	return page


# ============================================================
# PAGE 2 — EXAMPLES (worked examples with word highlighting)
# ============================================================
func _build_examples_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[1] = []
	
	page.add_child(_make_topic_banner("💡", "Examples", "مثال‌ها"))
	
	var examples: Array = _data.get("examples", [])
	if examples.is_empty():
		var empty := _make_label("No examples available yet.", 36, Color("#64748B"), false)
		page.add_child(empty)
		return page
	
	for ex in examples:
		var card := _make_example_card(ex)
		page.add_child(card)
		_page_reveals[1].append(card)
	
	return page


# ============================================================
# PAGE 3 — PRACTICE (interactive exercises)
# ============================================================
func _build_practice_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[2] = []
	
	page.add_child(_make_topic_banner("✏️", "Practice", "تمرین"))
	
	var intro := _make_text_card(
		"Test your understanding with these exercises!",
		"با این تمرین‌ها درک خود را بسنجید!",
		Color("#F0FDF4"), Color("#16A34A"))
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
	ic.add_theme_font_size_override("font_size", 72)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ic)
	
	var en_l := _make_label(en, 50, Color.WHITE, true)
	en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(en_l)
	
	var fa_l := _make_fa_label(fa, 36)
	fa_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
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
	vb.add_child(_make_label(en, 36, Color("#1E293B"), false))
	vb.add_child(_make_fa_label(fa, 31))
	card.add_child(vb)
	return card


func _make_bullet(en: String, fa: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(_make_label("•  " + en, 34, Color("#334155"), false))
	vb.add_child(_make_fa_label(fa, 29))
	return vb


func _make_example_card(ex: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	
	# Word pair (highlighted)
	var word_text: String = ex.get("word", "")
	var synonym_text: String = ex.get("synonym", "")
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_font_size_override("normal_font_size", 42)
	rtl.add_theme_color_override("default_color", Color("#1E293B"))
	rtl.text = "[color=#7C3AED][b]" + word_text + "[/b][/color]  =  [color=#16A34A][b]" + synonym_text + "[/b][/color]"
	if font_bold: rtl.add_theme_font_override("normal_font", font_bold)
	vb.add_child(rtl)
	
	# Example sentence
	var sentence: Dictionary = ex.get("sentence", {})
	if not sentence.is_empty():
		vb.add_child(_make_label(sentence.get("en", ""), 34, Color("#475569"), false))
		vb.add_child(_make_fa_label(sentence.get("fa", ""), 30))
	
	card.add_child(vb)
	return card


func _make_reference_table(table: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
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
		
		var affix := Label.new()
		affix.text = str(entry.get("affix", ""))
		affix.add_theme_font_size_override("font_size", 34)
		affix.add_theme_color_override("font_color", ACCENT)
		affix.custom_minimum_size.x = 120
		if font_bold: affix.add_theme_font_override("font", font_bold)
		row.add_child(affix)
		
		var meaning_en := Label.new()
		meaning_en.text = str(entry.get("meaning_en", ""))
		meaning_en.add_theme_font_size_override("font_size", 32)
		meaning_en.add_theme_color_override("font_color", Color("#1E293B"))
		meaning_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font_regular: meaning_en.add_theme_font_override("font", font_regular)
		row.add_child(meaning_en)
		
		var example := Label.new()
		example.text = str(entry.get("example", ""))
		example.add_theme_font_size_override("font_size", 30)
		example.add_theme_color_override("font_color", Color("#64748B"))
		if font_italic: example.add_theme_font_override("font", font_italic)
		row.add_child(example)
		
		vb.add_child(row)
	
	card.add_child(vb)
	return card


func _make_section_title(en: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(6, 44)
	row.add_child(bar)
	row.add_child(_make_label(en, 40, Color("#1E293B"), true))
	return row


func _make_label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold: l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular: l.add_theme_font_override("font", font_regular)
	return l


func _make_fa_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#64748B"))
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: l.add_theme_font_override("font", font_farsi)
	return l


# ============================================================
# ENTRANCE ANIMATION
# ============================================================
func _on_page_changed(index: int, _page_id: String) -> void:
	_play_reveal(index)


func _play_reveal(index: int) -> void:
	if _page_revealed.get(index, false): return
	_page_revealed[index] = true
	var cards: Array = _page_reveals.get(index, [])
	for i in cards.size():
		var card: Control = cards[i]
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.07 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
