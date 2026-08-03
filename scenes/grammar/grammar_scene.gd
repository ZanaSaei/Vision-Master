extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# GRAMMAR SCENE — three swipeable pages via PageView
#   Page 1 "Book"    → textbook explanation + book exercises
#   Page 2 "Master"  → deep explanations, mistakes, Persian tips
#   Page 3 "Practice"→ extra drills
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile
var font_farsi: FontFile

# ---------- Per-topic theme ----------
const GRAMMAR_THEMES := {
	"Future Tense (will)":                     {"accent": Color("#2563EB"), "icon": "🔮"},
	"Adjectives (Comparative & Superlative)":  {"accent": Color("#0891B2"), "icon": "⚖️"},
	"Past Progressive":                        {"accent": Color("#7C3AED"), "icon": "⏳"},
	"Modals (can, may, must, should)":         {"accent": Color("#EA580C"), "icon": "🚦"},
	"Countable and Uncountable Nouns":         {"accent": Color("#059669"), "icon": "🧮"},
	"Present Perfect":                         {"accent": Color("#DB2777"), "icon": "✅"},
	"Conditional Type I":                      {"accent": Color("#CA8A04"), "icon": "🔀"},
	"Passive Voice":                           {"accent": Color("#0891B2"), "icon": "🔄"},
	"Relative Clauses":                        {"accent": Color("#7C3AED"), "icon": "🔗"},
	"Passive Voice with Modals":               {"accent": Color("#059669"), "icon": "🔐"},
}
const DEFAULT_THEME := {"accent": Color("#2563EB"), "icon": "📐"}

# ---------- Formula chip colors (the signature visual) ----------
const ROLE_COLORS := {
	"subject":  Color("#2563EB"),
	"aux":      Color("#D97706"),
	"verb":     Color("#16A34A"),
	"object":   Color("#7C3AED"),
	"negative": Color("#DC2626"),
	"other":    Color("#64748B"),
}

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _theme: Dictionary = DEFAULT_THEME
var _page_reveals: Dictionary = {}   # page_index -> Array[Control]
var _page_revealed: Dictionary = {}  # page_index -> bool


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold    = load(FONT_BOLD_PATH)
	font_italic  = load(FONT_ITALIC_PATH)
	font_farsi   = load(FONT_VAZIRMATN)
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	back_button.pressed.connect(_on_back_button_pressed)
	page_view.page_changed.connect(_on_page_changed)
	
	header_title.text = "Lesson %d\nGrammar" % Global.current_lesson
	
	var data: Dictionary = Global.load_category("grammar", Global.current_book, Global.current_lesson)
	if data.is_empty():
		return
	
	_theme = GRAMMAR_THEMES.get(data.get("grammar_topic", {}).get("en", ""), DEFAULT_THEME)
	page_view.set_accent(_theme["accent"])
	
	# ---- Build the three pages ----
	page_view.add_page("book",    "Book",    "📖", _build_book_page(data))
	page_view.add_page("master",  "Master",  "🎓", _build_master_page(data))
	page_view.add_page("practice","Practice","💪", _build_practice_page(data))
	
	_play_reveal(0)


# ============================================================
# PAGE 1 — BOOK (textbook lesson + its exercises)
# ============================================================
func _build_book_page(data: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	var bg: Dictionary = data.get("book_grammar", {})
	_page_reveals[0] = []
	
	# --- Topic banner ---
	var topic_en: String = data.get("grammar_topic", {}).get("en", "Grammar")
	var topic_fa: String = data.get("grammar_topic", {}).get("fa", "دستور زبان")
	var banner := _make_topic_banner(str(_theme["icon"]), topic_en, topic_fa)
	page.add_child(banner)
	_page_reveals[0].append(banner)
	
	# --- Intro ---
	for intro in bg.get("intro", []):
		var card := _make_text_card(intro["en"], intro["fa"], Color("#F8FAFC"), _theme["accent"])
		page.add_child(card)
		_page_reveals[0].append(card)
	
	# --- Formula card (the signature) ---
	if bg.has("structure"):
		page.add_child(_make_section_title("Structure", "ساختار"))
		var formula := _make_formula_card(bg["structure"])
		page.add_child(formula)
		_page_reveals[0].append(formula)
	
	# --- Examples ---
	if not bg.get("examples", []).is_empty():
		page.add_child(_make_section_title("Examples", "مثال‌ها"))
		for ex in bg["examples"]:
			var card := _make_text_card(ex["en"], ex["fa"], Color.WHITE, _theme["accent"].lightened(0.4))
			page.add_child(card)
			_page_reveals[0].append(card)
	
	# --- Book exercises ---
	if not bg.get("exercises", []).is_empty():
		page.add_child(_make_section_title("Book Exercises", "تمرین‌های کتاب"))
		for exercise in bg["exercises"]:
			var engine := ExerciseEngine.new()
			page.add_child(engine)
			engine.build(exercise)
			_page_reveals[0].append(engine)
	
	return page


# ============================================================
# PAGE 2 — MASTER (deep understanding)
# ============================================================
func _build_master_page(data: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	var mastery: Dictionary = data.get("mastery", {})
	_page_reveals[1] = []
	
	# --- Page banner (same style as the Book page) ---
	var banner := _make_topic_banner("🎓", "Master the Grammar", "تسلط بر دستور زبان")
	page.add_child(banner)
	_page_reveals[1].append(banner)
	
	# --- Explanation sections ---
	for section in mastery.get("sections", []):
		var card := PanelContainer.new()
		var c_style := StyleBoxFlat.new()
		c_style.bg_color = Color.WHITE
		c_style.set_corner_radius_all(16)
		c_style.border_width_left = 5
		c_style.border_color = _theme["accent"]
		c_style.set_content_margin_all(20)
		card.add_theme_stylebox_override("panel", c_style)
		
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 12)
		sv.add_child(_make_label(section["title"]["en"], 40, Color("#1E293B"), true))
		sv.add_child(_make_fa_label(section["title"]["fa"], 32, Color("#64748B")))
		
		for point in section.get("points", []):
			sv.add_child(_make_bullet(point["en"], point["fa"]))
		
		for ex in section.get("examples", []):
			var ex_card := _make_text_card(ex["en"], ex["fa"], _theme["accent"].lightened(0.92), _theme["accent"].lightened(0.5))
			sv.add_child(ex_card)
		
		card.add_child(sv)
		page.add_child(card)
		_page_reveals[1].append(card)
	
	# --- Common mistakes (wrong ✗ / right ✓) ---
	if not mastery.get("common_mistakes", []).is_empty():
		page.add_child(_make_section_title("Common Mistakes", ""))
		for mistake in mastery["common_mistakes"]:
			var card := _make_mistake_card(mistake)
			page.add_child(card)
			_page_reveals[1].append(card)
	
	# --- Persian tips ---
	if not mastery.get("tips_fa", []).is_empty():
		page.add_child(_make_section_title("Key Tips", ""))
		for tip in mastery["tips_fa"]:
			var card := _make_insight_card("💡 " + str(tip))
			page.add_child(card)
			_page_reveals[1].append(card)
	
	# --- See also ---
	if mastery.has("see_also"):
		var see := _make_text_card(
			"See also: " + mastery["see_also"]["en"],
			"همچنین ببینید: " + mastery["see_also"]["fa"],
			Color("#FEF9C3"), Color("#CA8A04"))
		page.add_child(see)
		_page_reveals[1].append(see)
	
	return page


# ============================================================
# PAGE 3 — PRACTICE (extra drills)
# ============================================================
func _build_practice_page(data: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[2] = []
	
	# --- Page banner (same style as the Book page) ---
	var banner := _make_topic_banner("💪", "Extra Practice", "تمرین بیشتر")
	page.add_child(banner)
	_page_reveals[2].append(banner)
	
	# --- Encouragement intro ---
	var intro := _make_text_card(
		"The more you practice, the easier grammar becomes. Try these extra exercises!",
		"هرچه بیشتر تمرین کنید، دستور زبان آسان‌تر می‌شود. این تمرین‌های اضافی را امتحان کنید!",
		Color("#F0FDF4"), Color("#16A34A"))
	page.add_child(intro)
	_page_reveals[2].append(intro)
	
	# --- Extra exercises ---
	for exercise in data.get("extra_practice", {}).get("exercises", []):
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
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = _theme["accent"]
	b_style.set_corner_radius_all(20)
	b_style.set_content_margin_all(26)
	banner.add_theme_stylebox_override("panel", b_style)
	
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	
	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 72)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(ic)
	
	var en_label := _make_label(en, 50, Color.WHITE, true)
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(en_label)
	
	var fa_label := _make_fa_label(fa, 36, Color(1, 1, 1, 0.85))
	fa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(fa_label)
	
	banner.add_child(bv)
	return banner

func _make_formula_card(structure: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0F172A")   # dark board makes the chips pop
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	
	for form in structure:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = form["label"]["en"] + "  ·  " + form["label"]["fa"]
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color("#94A3B8"))
		if font_bold: lbl.add_theme_font_override("font", font_bold)
		row.add_child(lbl)
		
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("separation", 8)
		for i in form["parts"].size():
			if i > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.add_theme_font_size_override("font_size", 30)
				plus.add_theme_color_override("font_color", Color("#64748B"))
				plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				chips.add_child(plus)
			chips.add_child(_make_formula_chip(form["parts"][i]))
		row.add_child(chips)
		vbox.add_child(row)
	
	card.add_child(vbox)
	return card


func _make_formula_chip(part: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	var color: Color = ROLE_COLORS.get(part.get("role", "other"), Color("#64748B"))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	chip.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = part["text"]
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	if font_bold: lbl.add_theme_font_override("font", font_bold)
	chip.add_child(lbl)
	return chip


func _make_mistake_card(mistake: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(16)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var wrong := Label.new()
	wrong.text = "✗  " + mistake["wrong"]
	wrong.autowrap_mode = TextServer.AUTOWRAP_WORD
	wrong.add_theme_font_size_override("font_size", 36)
	wrong.add_theme_color_override("font_color", Color("#DC2626"))
	if font_regular: wrong.add_theme_font_override("font", font_regular)
	vbox.add_child(wrong)
	
	var right := Label.new()
	right.text = "✓  " + mistake["right"]
	right.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_theme_font_size_override("font_size", 36)
	right.add_theme_color_override("font_color", Color("#16A34A"))
	if font_bold: right.add_theme_font_override("font", font_bold)
	vbox.add_child(right)
	
	if mistake.get("note_fa", "") != "":
		vbox.add_child(_make_fa_label(mistake["note_fa"], 30, Color("#64748B")))
	
	card.add_child(vbox)
	_add_hover_lift(card)
	return card


func _make_text_card(en: String, fa: String, bg: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_color = border
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_make_label(en, 36, Color("#1E293B"), false))
	vbox.add_child(_make_fa_label(fa, 31, Color("#64748B")))
	card.add_child(vbox)
	_add_hover_lift(card)
	return card


func _make_bullet(en: String, fa: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(_make_label("•  " + en, 34, Color("#334155"), false))
	vb.add_child(_make_fa_label(fa, 29, Color("#94A3B8")))
	return vb


func _make_insight_card(text: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(14)
	style.border_width_right = 5
	style.border_color = _theme["accent"]
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color("#1E293B"))
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: lbl.add_theme_font_override("font", font_farsi)
	card.add_child(lbl)
	_add_hover_lift(card)
	return card


func _make_section_title(en: String, _fa: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	
	var bar := ColorRect.new()
	bar.color = _theme["accent"]
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


func _make_fa_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: l.add_theme_font_override("font", font_farsi)
	return l


func _add_hover_lift(control: Control) -> void:
	control.mouse_entered.connect(func():
		control.pivot_offset = control.size / 2.0
		var t := create_tween()
		t.tween_property(control, "scale", Vector2(1.015, 1.015), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	control.mouse_exited.connect(func():
		control.pivot_offset = control.size / 2.0
		var t := create_tween()
		t.tween_property(control, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


# ============================================================
# ENTRANCE — staggered reveal per page, on first visit
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


func _on_back_button_pressed() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
