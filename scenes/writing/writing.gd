extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# WRITING SCENE — three swipeable pages via PageView
#   Page 1 "Concept"  → definition + category cards
#   Page 2 "Forms"    → tables (Singular/Plural, Markers, etc.)
#   Page 3 "Practice" → interactive exercises
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

# Distinct pink accent — writing = creative expression
const ACCENT := Color("#DB2777")
const SOFT   := Color("#FDF2F8")

# Color palette for category chips / table type badges
const CATEGORY_COLORS := [
	Color("#2563EB"),  # blue
	Color("#16A34A"),  # green
	Color("#9333EA"),  # purple
	Color("#EA580C"),  # orange
	Color("#0891B2"),  # teal
	Color("#CA8A04"),  # amber
]

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
	
	header_title.text = "Lesson %d\nWriting" % Global.current_lesson
	
	_data = Global.load_category("writing", Global.current_book, Global.current_lesson)
	if _data.is_empty():
		return
	
	page_view.add_page("concept",  "Concept",  "💡", _build_concept_page())
	page_view.add_page("forms",    "Forms",    "📋", _build_forms_page())
	page_view.add_page("practice", "Practice", "✏️", _build_practice_page())
	
	_play_reveal(0)


# ============================================================
# PAGE 1 — CONCEPT (definition + category cards)
# ============================================================
func _build_concept_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[0] = []
	
	# Topic banner
	var topic_en: String = _data.get("topic", {}).get("en", "Writing")
	var topic_fa: String = _data.get("topic", {}).get("fa", "نوشتن")
	page.add_child(_make_topic_banner("✍️", topic_en, topic_fa))
	
	# Definition card
	var concept: Dictionary = _data.get("concept", {})
	if not concept.is_empty():
		var def: Dictionary = concept.get("definition", {})
		if not def.is_empty():
			var card := _make_text_card(def.get("en", ""), def.get("fa", ""), SOFT, ACCENT)
			page.add_child(card)
			_page_reveals[0].append(card)
		
		# Key points
		var points: Array = concept.get("key_points", [])
		for point in points:
			page.add_child(_make_bullet(point.get("en", ""), point.get("fa", "")))
		
		# Category cards (e.g., Person/Animal, Place, Thing, Idea)
		var categories: Array = concept.get("categories", [])
		if not categories.is_empty():
			page.add_child(_make_section_title("Types of Nouns"))
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 14)
			
			# ✅ CRITICAL: Make the grid expand horizontally
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			for i in categories.size():
				var cat: Dictionary = categories[i]
				var color: Color = CATEGORY_COLORS[i % CATEGORY_COLORS.size()]
				var card := _make_category_card(cat.get("name", {}), cat.get("examples", []), color)
				grid.add_child(card)
				_page_reveals[0].append(card)
			page.add_child(grid)
	
	return page

# ============================================================
# PAGE 2 — FORMS (tables: Singular/Plural, Markers, etc.)
# ============================================================
func _build_forms_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[1] = []
	
	page.add_child(_make_topic_banner("📋", "Forms & Rules", "شکل‌ها و قواعد"))
	
	var forms: Array = _data.get("forms", [])
	if forms.is_empty():
		var empty := _make_label("No forms available yet.", 36, Color("#64748B"), false)
		page.add_child(empty)
		return page
	
	for form in forms:
		var card := _make_form_card(form)
		page.add_child(card)
		_page_reveals[1].append(card)
	
	return page


# ============================================================
# PAGE 3 — PRACTICE (ExerciseEngine)
# ============================================================
func _build_practice_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[2] = []
	
	page.add_child(_make_topic_banner("✏️", "Practice", "تمرین"))
	
	var intro := _make_text_card(
		"Writing is a skill. The more you practice, the better you become!",
		"نوشتن یک مهارت است. هرچه بیشتر تمرین کنید، بهتر می‌شوید!",
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


func _make_category_card(name: Dictionary, examples: Array, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	
	# ✅ CRITICAL: Make the card expand to fill its grid cell
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(14)
	style.border_width_top = 5
	style.border_color = color
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	
	# Category name with colored badge
	var badge := Label.new()
	badge.text = str(name.get("en", ""))
	badge.add_theme_font_size_override("font_size", 34)
	badge.add_theme_color_override("font_color", color)
	if font_bold: badge.add_theme_font_override("font", font_bold)
	vb.add_child(badge)
	
	var fa_name := _make_fa_label(str(name.get("fa", "")), 28)
	vb.add_child(fa_name)
	
	# Examples as a flowing list
	for ex in examples:
		var ex_label := _make_label("·  " + str(ex), 30, Color("#475569"), false)
		ex_label.autowrap_mode = TextServer.AUTOWRAP_WORD  # ✅ Enable wrapping
		vb.add_child(ex_label)
	
	card.add_child(vb)
	return card

func _make_form_card(form: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	# ❌ REMOVE THIS LINE (was causing vertical overflow):
	# vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Title + subtitle
	vb.add_child(_make_label(str(form.get("title", {}).get("en", "")), 38, Color("#1E293B"), true))
	vb.add_child(_make_fa_label(str(form.get("title", {}).get("fa", "")), 30))
	vb.add_child(_make_label(str(form.get("subtitle", {}).get("en", "")), 32, Color("#64748B"), false))
	vb.add_child(_make_fa_label(str(form.get("subtitle", {}).get("fa", "")), 28))
	
	# Table
	var table: Array = form.get("table", [])
	if not table.is_empty():
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		
		# ✅ CORRECT: Only expand horizontally, NOT vertically
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# grid.size_flags_vertical = Control.SIZE_EXPAND_FILL  ← REMOVED!
		
		# Header row
		grid.add_child(_make_table_header("Type"))
		grid.add_child(_make_table_header("Singular"))
		grid.add_child(_make_table_header("Plural"))
		
		# Data rows
		for row in table:
			var type_color := Color("#2563EB") if str(row.get("type", "")).to_lower() == "regular" or str(row.get("type", "")).to_lower() == "common" else Color("#DB2777")
			grid.add_child(_make_table_cell(str(row.get("type", "")), type_color, true))
			grid.add_child(_make_table_cell(str(row.get("singular", "")), Color("#1E293B"), false))
			grid.add_child(_make_table_cell(str(row.get("plural", "")), Color("#1E293B"), false))
		
		vb.add_child(grid)
	
	card.add_child(vb)
	return card


func _make_table_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD  # ← ADD THIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # ← ADD THIS
	
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	l.add_theme_stylebox_override("normal", style)
	if font_bold: l.add_theme_font_override("font", font_bold)
	return l

func _make_table_cell(text: String, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# ✅ CRITICAL: Enable text wrapping so long content wraps instead of overflowing
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# ✅ Only expand horizontally (NOT vertically)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F8FAFC")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	l.add_theme_stylebox_override("normal", style)
	
	if bold and font_bold: l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular: l.add_theme_font_override("font", font_regular)
	
	return l

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
