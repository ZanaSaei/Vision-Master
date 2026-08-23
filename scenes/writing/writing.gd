extends "res://autoload/BackButtonHandler.gd"

# ============================================================
# WRITING SCENE — three swipeable pages via PageView
# Page 1 "Concept"  → definition + category cards
# Page 2 "Forms"    → tables
# Page 3 "Practice" → interactive exercises
#
# Dark-theme harmonized version.
# Titles are kept on one line with wrapping disabled.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

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
const INFO := Color("#22D3EE")

# Distinct pink accent — writing = creative expression.
const ACCENT := Color("#DB2777")

# Color palette for category chips / table type badges.
const CATEGORY_COLORS := [
	Color("#2563EB"),
	Color("#16A34A"),
	Color("#9333EA"),
	Color("#EA580C"),
	Color("#0891B2"),
	Color("#CA8A04"),
]

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

@onready var background: ColorRect = $Background
@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}
var _data: Dictionary = {}


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_farsi = load(FONT_VAZIRMATN)

	if font_bold:
		header_title.add_theme_font_override("font", font_bold)

	# Keep header readable (theme-aware).
	header_title.add_theme_color_override("font_color", _text_color())

	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)

	# Put a dark background behind the whole PageView.
	_add_page_view_background()

	# Theme-aware styling + live re-theme on toggle (runs for all data paths).
	Global.on_theme_changed(_apply_theme)
	_apply_theme()

	header_title.text = "Lesson %d\nWriting" % Global.current_lesson

	_data = Global.load_category(
		"writing",
		Global.current_book,
		Global.current_lesson
	)

	if _data.is_empty():
		return

	page_view.add_page("concept", "Concept", "💡", _build_concept_page())
	page_view.add_page("forms", "Forms", "📋", _build_forms_page())
	page_view.add_page("practice", "Practice", "✏️", _build_practice_page())

	# Force themed backgrounds for PageView scroll areas.
	_apply_dark_scroll_background(page_view)

	_play_reveal(0)


# ============================================================
# DARK THEME HELPERS
# ============================================================

func _add_page_view_background() -> void:
	if page_view.has_meta("dark_bg"):
		return

	var bg := ColorRect.new()
	bg.color = _app_bg()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	page_view.add_child(bg)
	page_view.move_child(bg, 0)
	page_view.set_meta("dark_bg", bg)


func _apply_dark_scroll_background(root: Control) -> void:
	for child in root.get_children():
		if child is ScrollContainer:
			var style := StyleBoxFlat.new()
			style.bg_color = _app_bg()
			child.add_theme_stylebox_override("panel", style)

		if child is Control:
			_apply_dark_scroll_background(child)


func _apply_theme() -> void:
	if not is_inside_tree():
		return

	if background != null:
		background.color = _navy_bg()

	header_title.add_theme_color_override("font_color", _text_color())
	_apply_dark_scroll_background(page_view)


# ---------- Theme-aware color helpers ----------
# Dark mode matches today's hardcoded palette; Light mode uses the app palette.
func _navy_bg() -> Color:
	return Color("#2c387f") if Global.theme_is_dark() else Global.get_theme_color("bg_base")

func _app_bg() -> Color:
	return APP_BG if Global.theme_is_dark() else Global.get_theme_color("bg_base")

func _panel_bg() -> Color:
	return PANEL_BG if Global.theme_is_dark() else Global.get_theme_color("surface")

func _panel_border() -> Color:
	return PANEL_BORDER if Global.theme_is_dark() else Global.get_theme_color("border")

func _text_color() -> Color:
	return TEXT_LIGHT if Global.theme_is_dark() else Global.get_theme_color("text")

func _text_soft() -> Color:
	return TEXT_SOFT if Global.theme_is_dark() else Global.get_theme_color("text_dim")

func _text_muted() -> Color:
	return TEXT_MUTED if Global.theme_is_dark() else Global.get_theme_color("text_dim")


func _dark_tint(color: Color, amount := 0.16) -> Color:
	# Creates a dark panel color tinted by the given accent color.
	return _panel_bg().lerp(Color(color.r, color.g, color.b, 1.0), amount)


func _contrast_color(bg: Color) -> Color:
	# Chooses readable text color for colored banners/buttons.
	if bg.get_luminance() > 0.6:
		return Color("#0b1229")
	return Color.WHITE


func _get_en(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("en", ""))
	return str(val)


func _get_fa(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("fa", ""))
	return ""


# ============================================================
# PAGE 1 — CONCEPT
# ============================================================

func _build_concept_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	_page_reveals[0] = []

	# Topic banner.
	var topic_en := str(_data.get("topic", {}).get("en", "Writing"))
	var topic_fa := str(_data.get("topic", {}).get("fa", "نوشتن"))

	page.add_child(_make_topic_banner("✍️", topic_en, topic_fa))

	# Definition card.
	var concept: Dictionary = _data.get("concept", {})

	if not concept.is_empty():
		var def: Dictionary = concept.get("definition", {})

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
		var points: Array = concept.get("key_points", [])

		for point in points:
			page.add_child(_make_bullet(
				str(point.get("en", "")),
				str(point.get("fa", ""))
			))

		# Category cards.
		var categories: Array = concept.get("categories", [])

		if not categories.is_empty():
			page.add_child(_make_section_title("Types of Nouns"))

			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 14)
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			for i in categories.size():
				var cat: Dictionary = categories[i]
				var color: Color = CATEGORY_COLORS[i % CATEGORY_COLORS.size()]

				var card := _make_category_card(
					cat.get("name", {}),
					cat.get("examples", []),
					color
				)

				grid.add_child(card)
				_page_reveals[0].append(card)

			page.add_child(grid)

	return page


# ============================================================
# PAGE 2 — FORMS
# ============================================================

func _build_forms_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	_page_reveals[1] = []

	page.add_child(_make_topic_banner("📋", "Forms & Rules", "شکل‌ها و قواعد"))

	var forms: Array = _data.get("forms", [])

	if forms.is_empty():
		var empty := _make_label("No forms available yet.", 36, _text_muted(), false)
		page.add_child(empty)
		return page

	for form in forms:
		var card := _make_form_card(form)
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
		"Writing is a skill. The more you practice, the better you become!",
		"نوشتن یک مهارت است. هرچه بیشتر تمرین کنید، بهتر می‌شوید!",
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
	ic.add_theme_font_size_override("font_size", 72)
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
	vb.add_child(_make_fa_label(fa, 31, _text_muted()))

	card.add_child(vb)
	return card


func _make_bullet(en: String, fa: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	vb.add_child(_make_label("•  " + en, 34, _text_soft(), false))
	vb.add_child(_make_fa_label(fa, 29, _text_muted()))

	return vb


func _make_category_card(category_name: Dictionary, examples: Array, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = _panel_bg()
	style.set_corner_radius_all(14)
	style.border_width_top = 5
	style.border_color = color
	style.set_content_margin_all(16)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	# Category title: one line, no wrapping.
	var badge := Label.new()
	badge.text = str(category_name.get("en", ""))
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.clip_text = false
	badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	badge.add_theme_font_size_override("font_size", 34)
	badge.add_theme_color_override("font_color", color.lightened(0.25))

	if font_bold:
		badge.add_theme_font_override("font", font_bold)

	vb.add_child(badge)

	vb.add_child(_make_fa_label(str(category_name.get("fa", "")), 28, _text_muted(), false))

	# Examples stay wrapped.
	for ex in examples:
		var ex_label := _make_label("·  " + str(ex), 30, _text_soft(), false)
		vb.add_child(ex_label)

	card.add_child(vb)
	return card


func _make_form_card(form: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = _panel_bg()
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)

	# Form title: one line, no wrapping.
	vb.add_child(_make_label(_get_en(form.get("title", "")), 38, _text_color(), true, false))
	vb.add_child(_make_fa_label(_get_fa(form.get("title", "")), 30, _text_muted(), false))

	# Subtitle can wrap.
	vb.add_child(_make_label(_get_en(form.get("subtitle", "")), 32, _text_muted(), false))
	vb.add_child(_make_fa_label(_get_fa(form.get("subtitle", "")), 28, _text_muted()))

	# Table.
	var table: Array = form.get("table", [])

	if not table.is_empty():
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Header row.
		grid.add_child(_make_table_header("Type"))
		grid.add_child(_make_table_header("Singular"))
		grid.add_child(_make_table_header("Plural"))

		# Data rows.
		for row in table:
			var row_type := str(row.get("type", "")).to_lower()

			var type_color := INFO
			if row_type != "regular" and row_type != "common":
				type_color = ACCENT.lightened(0.25)

			grid.add_child(_make_table_cell(str(row.get("type", "")), type_color, true))
			grid.add_child(_make_table_cell(str(row.get("singular", "")), _text_color(), false))
			grid.add_child(_make_table_cell(str(row.get("plural", "")), _text_color(), false))

		vb.add_child(grid)

	card.add_child(vb)
	return card


func _make_table_header(text: String) -> Label:
	var l := Label.new()
	l.text = text

	# Table headers are titles, so keep them on one line.
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", _contrast_color(ACCENT))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)

	l.add_theme_stylebox_override("normal", style)

	if font_bold:
		l.add_theme_font_override("font", font_bold)

	return l


func _make_table_cell(text: String, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Cell content stays wrapped.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = _app_bg()
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = _panel_border()
	style.set_content_margin_all(8)

	l.add_theme_stylebox_override("normal", style)

	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)

	return l


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

	# Slightly shrink very long one-line titles so they fit better.
	var final_size := font_size
	if not do_wrap:
		if text.length() > 30:
			final_size = int(float(font_size) * 0.85)
		if text.length() > 55:
			final_size = int(float(font_size) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", color)

	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)

	return l


func _make_fa_label(text: String, font_size: int, color: Color = TEXT_MUTED, do_wrap := true) -> Label:
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

	# Slightly shrink very long one-line Persian titles.
	var final_size := font_size
	if not do_wrap:
		if text.length() > 34:
			final_size = int(float(font_size) * 0.85)
		if text.length() > 60:
			final_size = int(float(font_size) * 0.72)

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
