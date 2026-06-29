extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  GRAMMAR SCENE
#  Loads from res://data/v{book}_grammar.json
#  Reads Global.current_book + Global.current_lesson
#  Teaches grammar points in Persian with English examples
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Colors cycling across grammar point cards
const CARD_ACCENT_COLORS := [
	Color("#2563EB"),  # blue
	Color("#16A34A"),  # green
	Color("#9333EA"),  # purple
	Color("#EA580C"),  # orange
	Color("#0D9488"),  # teal
]
const CARD_BG_COLORS := [
	Color("#EFF6FF"),
	Color("#F0FDF4"),
	Color("#FDF4FF"),
	Color("#FFF7ED"),
	Color("#F0FDFA"),
]

const STRUCTURE_BG  := Color("#1E293B")
const STRUCTURE_FG  := Color("#F1F5F9")
const TIP_BG        := Color("#FEF9C3")
const TIP_BORDER    := Color("#EAB308")
const EXAMPLE_EN_FG := Color("#1E40AF")
const EXAMPLE_FA_FG := Color("#64748B")

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN_PATH       := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_fa: FontFile

@onready var back_button: Button                 = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label                 = $HeaderBar/HeaderContent/HeaderTitle
@onready var points_container: VBoxContainer     = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/PointsContainer
@onready var audio_player: AudioStreamPlayer     = $AudioPlayer


func _ready() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	_load_fonts()

	back_button.pressed.connect(_on_back_button_pressed)

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson

	header_title.text = "Lesson %d Grammar" % lesson

	if font_bold != null:
		header_title.add_theme_font_override("font", font_bold)

	var data: Dictionary = _load_grammar(book, lesson)
	if data.is_empty():
		var empty := Label.new()
		empty.text = "Grammar content not available yet."
		empty.add_theme_font_size_override("font_size", 40)
		points_container.add_child(empty)
		return

	_build_grammar_points(data.get("points", []))


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold    = load(FONT_JAKARTA_BOLD_PATH)
	font_fa      = load(FONT_VAZIRMATN_PATH)

	if font_regular == null:
		push_warning("Regular font not found: " + FONT_JAKARTA_REGULAR_PATH)
	if font_bold == null:
		push_warning("Bold font not found: " + FONT_JAKARTA_BOLD_PATH)
	if font_fa == null:
		push_warning("Farsi font not found: " + FONT_VAZIRMATN_PATH)


func _load_grammar(book: int, lesson: int) -> Dictionary:
	var path := "res://data/v%d_grammar.json" % book

	if not FileAccess.file_exists(path):
		push_error("Grammar file not found: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text  := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Failed to parse: " + path)
		return {}

	var all_lessons: Dictionary = json.data.get("lessons", {})
	return all_lessons.get(str(lesson), {})


# ----------------------------------------------------------------
#  BUILD ALL GRAMMAR POINT CARDS
# ----------------------------------------------------------------
func _build_grammar_points(points: Array) -> void:
	for child in points_container.get_children():
		child.queue_free()

	for i in points.size():
		var point: Dictionary = points[i]
		var color_idx: int    = i % CARD_ACCENT_COLORS.size()
		var card              := _make_grammar_card(point, color_idx)
		points_container.add_child(card)

		# Spacing between cards
		if i < points.size() - 1:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 12)
			points_container.add_child(spacer)


func _make_grammar_card(point: Dictionary, color_idx: int) -> PanelContainer:
	var accent: Color = CARD_ACCENT_COLORS[color_idx]
	var bg: Color     = CARD_BG_COLORS[color_idx]

	# Outer card
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color                   = bg
	card_style.corner_radius_top_left     = 16
	card_style.corner_radius_top_right    = 16
	card_style.corner_radius_bottom_left  = 16
	card_style.corner_radius_bottom_right = 16
	card_style.border_width_left          = 5
	card_style.border_color               = accent
	card_style.content_margin_left        = 20
	card_style.content_margin_right       = 20
	card_style.content_margin_top         = 18
	card_style.content_margin_bottom      = 18
	card.add_theme_stylebox_override("panel", card_style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS

	# 1. Title
	_add_title(inner, point.get("title", ""), accent)

	# 2. Persian explanation
	_add_explanation(inner, point.get("explanation", ""))

	# 3. Structure box (dark code-like block)
	var structure: String = point.get("structure", "")
	if structure != "":
		_add_structure_box(inner, structure)

	# 4. Negative / Question forms (if present)
	var negative: String = point.get("negative", "")
	if negative != "":
		_add_structure_box(inner, negative)

	var question: String = point.get("question", "")
	if question != "":
		_add_structure_box(inner, question)

	# 5. Examples
	var examples: Array = point.get("examples", [])
	if not examples.is_empty():
		_add_examples_section(inner, examples, accent)

	# 6. Tip / نکته
	var tip: String = point.get("tip", "")
	if tip != "":
		_add_tip_box(inner, tip)

	card.add_child(inner)
	return card


# ----------------------------------------------------------------
#  CARD SECTION BUILDERS
# ----------------------------------------------------------------
func _add_title(parent: VBoxContainer, title: String, accent: Color) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 50)
	lbl.add_theme_color_override("font_color", accent)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_fa != null:
		lbl.add_theme_font_override("font", font_fa)
	parent.add_child(lbl)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = accent
	sep_style.content_margin_top    = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)


func _add_explanation(parent: VBoxContainer, explanation: String) -> void:
	if explanation == "":
		return
	var lbl := Label.new()
	lbl.text = explanation
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color("#1E293B"))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_fa != null:
		lbl.add_theme_font_override("font", font_fa)
	parent.add_child(lbl)


func _add_structure_box(parent: VBoxContainer, structure: String) -> void:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var box_style := StyleBoxFlat.new()
	box_style.bg_color                   = STRUCTURE_BG
	box_style.corner_radius_top_left     = 8
	box_style.corner_radius_top_right    = 8
	box_style.corner_radius_bottom_left  = 8
	box_style.corner_radius_bottom_right = 8
	box_style.content_margin_left        = 16
	box_style.content_margin_right       = 16
	box_style.content_margin_top         = 12
	box_style.content_margin_bottom      = 12
	box.add_theme_stylebox_override("panel", box_style)

	var lbl := Label.new()
	lbl.text = structure
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", STRUCTURE_FG)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_regular != null:
		lbl.add_theme_font_override("font", font_regular)

	box.add_child(lbl)
	parent.add_child(box)


func _add_examples_section(parent: VBoxContainer, examples: Array, accent: Color) -> void:
	# Section header
	var header := Label.new()
	header.text = "مثال‌ها:"
	header.add_theme_font_size_override("font_size", 38)
	header.add_theme_color_override("font_color", accent)
	header.text_direction = Control.TEXT_DIRECTION_RTL
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_fa != null:
		header.add_theme_font_override("font", font_fa)
	parent.add_child(header)

	# Each example
	for ex in examples:
		var ex_container := VBoxContainer.new()
		ex_container.mouse_filter = Control.MOUSE_FILTER_PASS
		ex_container.add_theme_constant_override("separation", 4)

		# English line
		var en_lbl := Label.new()
		en_lbl.text = "▸  " + ex.get("en", "")
		en_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		en_lbl.add_theme_font_size_override("font_size", 42)
		en_lbl.add_theme_color_override("font_color", EXAMPLE_EN_FG)
		en_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font_regular != null:
			en_lbl.add_theme_font_override("font", font_regular)

		# Farsi translation line
		var fa_lbl := Label.new()
		fa_lbl.text = ex.get("fa", "")
		fa_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		fa_lbl.add_theme_font_size_override("font_size", 38)
		fa_lbl.add_theme_color_override("font_color", EXAMPLE_FA_FG)
		fa_lbl.text_direction = Control.TEXT_DIRECTION_RTL
		fa_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fa_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font_fa != null:
			fa_lbl.add_theme_font_override("font", font_fa)

		ex_container.add_child(en_lbl)
		ex_container.add_child(fa_lbl)
		parent.add_child(ex_container)


func _add_tip_box(parent: VBoxContainer, tip: String) -> void:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var box_style := StyleBoxFlat.new()
	box_style.bg_color                   = TIP_BG
	box_style.corner_radius_top_left     = 8
	box_style.corner_radius_top_right    = 8
	box_style.corner_radius_bottom_left  = 8
	box_style.corner_radius_bottom_right = 8
	box_style.border_width_left          = 4
	box_style.border_color               = TIP_BORDER
	box_style.content_margin_left        = 14
	box_style.content_margin_right       = 14
	box_style.content_margin_top         = 10
	box_style.content_margin_bottom      = 10
	box.add_theme_stylebox_override("panel", box_style)

	var lbl := Label.new()
	lbl.text = "💡 " + tip
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color("#713F12"))
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_fa != null:
		lbl.add_theme_font_override("font", font_fa)

	box.add_child(lbl)
	parent.add_child(box)


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_LESSON_MENU)
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
