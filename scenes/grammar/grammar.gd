extends "res://autoload/BackButtonHandler.gd"

# ============================================================
# GRAMMAR SCENE — three swipeable pages via PageView
# Page 1 "Book"     → textbook explanation + book exercises
# Page 2 "Master"   → deep explanations, mistakes, Persian tips
# Page 3 "Practice" → extra drills
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

# ---------- Dark theme ----------
const APP_BG := Color("#0b1229")
const PANEL_BG := Color("#0f1b3d")
const PANEL_BORDER := Color("#2d3a6a")

const TEXT_LIGHT := Color("#F1F5F9")
const TEXT_SOFT := Color("#CBD5E1")
const TEXT_MUTED := Color("#94A3B8")

const SUCCESS := Color("#34D399")
const ERROR := Color("#F87171")
const WARNING := Color("#FBBF24")

var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile
var font_farsi: FontFile

# ---------- Per-topic theme ----------
const GRAMMAR_THEMES := {
	"Future Tense (will)": {
		"accent": Color("#2563EB"),
		"icon": "🔮"
	},
	"Adjectives (Comparative & Superlative)": {
		"accent": Color("#0891B2"),
		"icon": "⚖️"
	},
	"Past Progressive": {
		"accent": Color("#7C3AED"),
		"icon": "⏳"
	},
	"Modals (can, may, must, should)": {
		"accent": Color("#EA580C"),
		"icon": "🚦"
	},
	"Countable and Uncountable Nouns": {
		"accent": Color("#059669"),
		"icon": "🧮"
	},
	"Present Perfect": {
		"accent": Color("#DB2777"),
		"icon": "✅"
	},
	"Conditional Type I": {
		"accent": Color("#CA8A04"),
		"icon": "🔀"
	},
	"Passive Voice": {
		"accent": Color("#0891B2"),
		"icon": "🔄"
	},
	"Relative Clauses": {
		"accent": Color("#7C3AED"),
		"icon": "🔗"
	},
	"Passive Voice with Modals": {
		"accent": Color("#059669"),
		"icon": "🔐"
	},
}

const DEFAULT_THEME := {
	"accent": Color("#2563EB"),
	"icon": "📐"
}

# ---------- Formula chip colors ----------
const ROLE_COLORS := {
	"subject": Color("#2563EB"),
	"aux": Color("#D97706"),
	"verb": Color("#16A34A"),
	"object": Color("#7C3AED"),
	"negative": Color("#DC2626"),
	"other": Color("#64748B"),
}

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _theme: Dictionary = DEFAULT_THEME
var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_italic = load(FONT_ITALIC_PATH)
	font_farsi = load(FONT_VAZIRMATN)

	if font_bold:
		header_title.add_theme_font_override("font", font_bold)

	# Keep header readable on dark theme.
	header_title.add_theme_color_override("font_color", TEXT_LIGHT)

	back_button.pressed.connect(_on_back_button_pressed)
	page_view.page_changed.connect(_on_page_changed)

	header_title.text = "Lesson %d\nGrammar" % Global.current_lesson

	# Put a dark background behind the whole PageView.
	_add_page_view_background()

	var data: Dictionary = Global.load_category(
		"grammar",
		Global.current_book,
		Global.current_lesson
	)

	if data.is_empty():
		return

	var topic_name := str(data.get("grammar_topic", {}).get("en", "")).strip_edges()
	_theme = GRAMMAR_THEMES.get(topic_name, DEFAULT_THEME)

	page_view.set_accent(_theme.get("accent", Color("#2563EB")))

	# ---- Build the three pages ----
	page_view.add_page("book", "Book", "📖", _build_book_page(data))
	page_view.add_page("master", "Master", "🎓", _build_master_page(data))
	page_view.add_page("practice", "Practice", "💪", _build_practice_page(data))

	# Force dark backgrounds for PageView scroll areas.
	_apply_dark_scroll_background(page_view)

	_play_reveal(0)


# ============================================================
# DARK THEME HELPERS
# ============================================================

func _add_page_view_background() -> void:
	var bg := ColorRect.new()
	bg.color = APP_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	page_view.add_child(bg)
	page_view.move_child(bg, 0)


func _apply_dark_scroll_background(root: Control) -> void:
	for child in root.get_children():
		if child is ScrollContainer:
			var style := StyleBoxFlat.new()
			style.bg_color = APP_BG
			child.add_theme_stylebox_override("panel", style)

		if child is Control:
			_apply_dark_scroll_background(child)


func _dark_tint(color: Color, amount := 0.16) -> Color:
	# Creates a dark panel color tinted by the given accent color.
	return PANEL_BG.lerp(Color(color.r, color.g, color.b, 1.0), amount)


# ============================================================
# PAGE 1 — BOOK
# ============================================================

func _build_book_page(data: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	var bg: Dictionary = data.get("book_grammar", {})
	_page_reveals[0] = []

	# --- Topic banner ---
	var topic_en: String = data.get("grammar_topic", {}).get("en", "Grammar")
	var topic_fa: String = data.get("grammar_topic", {}).get("fa", "دستور زبان")
	var banner := _make_topic_banner(str(_theme.get("icon", "📐")), topic_en, topic_fa)

	page.add_child(banner)
	_page_reveals[0].append(banner)

	# --- Intro ---
	for intro in bg.get("intro", []):
		var card := _make_text_card(
			intro["en"],
			intro["fa"],
			_dark_tint(_theme["accent"]),
			_theme["accent"]
		)
		page.add_child(card)
		_page_reveals[0].append(card)

	# --- Formula card ---
	if bg.has("structure"):
		page.add_child(_make_section_title("Structure", "ساختار"))

		var formula := _make_formula_card(bg["structure"])
		page.add_child(formula)
		_page_reveals[0].append(formula)

	# --- Examples ---
	if not bg.get("examples", []).is_empty():
		page.add_child(_make_section_title("Examples", "مثال‌ها"))

		for ex in bg["examples"]:
			var card := _make_text_card(
				ex["en"],
				ex["fa"],
				_dark_tint(_theme["accent"], 0.10),
				_theme["accent"].lightened(0.2)
			)
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
# PAGE 2 — MASTER
# ============================================================

func _build_master_page(data: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	var mastery: Dictionary = data.get("mastery", {})
	_page_reveals[1] = []

	# --- Page banner ---
	var banner := _make_topic_banner("🎓", "Master the Grammar", "تسلط بر دستور زبان")
	page.add_child(banner)
	_page_reveals[1].append(banner)

	# --- Explanation sections ---
	for section in mastery.get("sections", []):
		var card := PanelContainer.new()

		var c_style := StyleBoxFlat.new()
		c_style.bg_color = PANEL_BG
		c_style.set_corner_radius_all(16)
		c_style.border_width_left = 5
		c_style.border_color = _theme["accent"]
		c_style.set_content_margin_all(20)

		card.add_theme_stylebox_override("panel", c_style)

		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 12)

		# Section title: one line, no wrapping.
		sv.add_child(_make_label(section["title"]["en"], 40, TEXT_LIGHT, true, false))
		sv.add_child(_make_fa_label(section["title"]["fa"], 32, TEXT_MUTED, false))

		for point in section.get("points", []):
			sv.add_child(_make_bullet(point["en"], point["fa"]))

		for ex in section.get("examples", []):
			var ex_card := _make_text_card(
				ex["en"],
				ex["fa"],
				_dark_tint(_theme["accent"], 0.10),
				_theme["accent"].lightened(0.2)
			)
			sv.add_child(ex_card)

		card.add_child(sv)
		page.add_child(card)
		_page_reveals[1].append(card)

	# --- Common mistakes ---
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
			_dark_tint(WARNING, 0.10),
			WARNING
		)
		page.add_child(see)
		_page_reveals[1].append(see)

	return page


# ============================================================
# PAGE 3 — PRACTICE
# ============================================================

func _build_practice_page(data: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	_page_reveals[2] = []

	# --- Page banner ---
	var banner := _make_topic_banner("💪", "Extra Practice", "تمرین بیشتر")
	page.add_child(banner)
	_page_reveals[2].append(banner)

	# --- Encouragement intro ---
	var intro := _make_text_card(
		"The more you practice, the easier grammar becomes. Try these extra exercises!",
		"هرچه بیشتر تمرین کنید، دستور زبان آسان‌تر می‌شود. این تمرین‌های اضافی را امتحان کنید!",
		_dark_tint(SUCCESS, 0.10),
		SUCCESS
	)

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

	var accent: Color = _theme.get("accent", Color("#2563EB"))

	var b_style := StyleBoxFlat.new()
	b_style.bg_color = accent
	b_style.set_corner_radius_all(20)
	b_style.set_content_margin_all(26)

	banner.add_theme_stylebox_override("panel", b_style)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 72)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(ic)

	# Choose readable text color based on accent brightness.
	var text_color := Color.WHITE
	if accent.get_luminance() > 0.6:
		text_color = Color("#0b1229")

	var sub_color := Color(text_color.r, text_color.g, text_color.b, 0.85)

	# Banner title: one line, no wrapping.
	var en_label := _make_label(en, 50, text_color, true, false)
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(en_label)

	var fa_label := _make_fa_label(fa, 36, sub_color, false)
	fa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(fa_label)

	banner.add_child(bv)
	return banner


func _make_formula_card(structure: Array) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0F172A")
	style.set_corner_radius_all(18)
	style.border_width_left = 4
	style.border_color = PANEL_BORDER
	style.set_content_margin_all(22)

	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	for form in structure:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label_text := str(form["label"]["en"]) + "  ·  " + str(form["label"]["fa"])

		# Formula title: one line, no wrapping.
		var lbl := _make_label(label_text, 28, TEXT_MUTED, true, false)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
				plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	lbl.text = str(part.get("text", ""))
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if font_bold:
		lbl.add_theme_font_override("font", font_bold)

	chip.add_child(lbl)
	return chip


func _make_mistake_card(mistake: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(16)
	style.border_width_left = 4
	style.border_color = PANEL_BORDER
	style.set_content_margin_all(18)

	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var wrong := Label.new()
	wrong.text = "✗  " + str(mistake.get("wrong", ""))
	wrong.autowrap_mode = TextServer.AUTOWRAP_WORD
	wrong.add_theme_font_size_override("font_size", 36)
	wrong.add_theme_color_override("font_color", ERROR)
	wrong.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if font_regular:
		wrong.add_theme_font_override("font", font_regular)

	vbox.add_child(wrong)

	var right := Label.new()
	right.text = "✓  " + str(mistake.get("right", ""))
	right.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_theme_font_size_override("font_size", 36)
	right.add_theme_color_override("font_color", SUCCESS)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if font_bold:
		right.add_theme_font_override("font", font_bold)

	vbox.add_child(right)

	if str(mistake.get("note_fa", "")) != "":
		vbox.add_child(_make_fa_label(mistake["note_fa"], 30, TEXT_MUTED))

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

	# Body text stays wrapped.
	vbox.add_child(_make_label(en, 36, TEXT_LIGHT, false))
	vbox.add_child(_make_fa_label(fa, 31, TEXT_MUTED))

	card.add_child(vbox)
	_add_hover_lift(card)

	return card


func _make_bullet(en: String, fa: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	vb.add_child(_make_label("•  " + en, 34, TEXT_SOFT, false))
	vb.add_child(_make_fa_label(fa, 29, TEXT_MUTED))

	return vb


func _make_insight_card(text: String) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(14)
	style.border_width_right = 5
	style.border_color = _theme["accent"]
	style.set_content_margin_all(18)

	card.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", TEXT_LIGHT)
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if font_farsi:
		lbl.add_theme_font_override("font", font_farsi)

	card.add_child(lbl)
	_add_hover_lift(card)

	return card


func _make_section_title(en: String, _fa: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar := ColorRect.new()
	bar.color = _theme["accent"]
	bar.custom_minimum_size = Vector2(6, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	# Section title: one line, no wrapping, fills horizontally.
	var title := _make_label(en, 40, TEXT_LIGHT, true, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	return row


func _make_label(text: String, size: int, color: Color, bold: bool, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable wrapping for titles when requested.
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Slightly shrink very long one-line titles so they fit better.
	var final_size := size
	if not wrap:
		if text.length() > 30:
			final_size = int(float(size) * 0.85)
		if text.length() > 55:
			final_size = int(float(size) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", color)

	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)

	return l


func _make_fa_label(text: String, size: int, color: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Slightly shrink very long one-line Persian titles.
	var final_size := size
	if not wrap:
		if text.length() > 34:
			final_size = int(float(size) * 0.85)
		if text.length() > 60:
			final_size = int(float(size) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", color)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if font_farsi:
		l.add_theme_font_override("font", font_farsi)

	return l


func _add_hover_lift(control: Control) -> void:
	control.mouse_entered.connect(func():
		control.pivot_offset = control.size / 2.0

		var t := create_tween()
		t.tween_property(
			control,
			"scale",
			Vector2(1.015, 1.015),
			0.12
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	control.mouse_exited.connect(func():
		control.pivot_offset = control.size / 2.0

		var t := create_tween()
		t.tween_property(
			control,
			"scale",
			Vector2.ONE,
			0.12
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)


# ============================================================
# ENTRANCE — staggered reveal per page, on first visit
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


func _on_back_button_pressed() -> void:
	back_button.pivot_offset = back_button.size / 2.0

	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
