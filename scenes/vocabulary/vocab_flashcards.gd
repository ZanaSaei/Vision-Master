extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  VOCAB FLASHCARDS — handles both LESSON and SAVED modes.
#
#  LESSON mode (Global.flashcard_mode == "lesson"):
#    - Loads words from the current lesson's JSON
#    - Header: back arrow + audio button
#    - Bottom nav: 📖 home | ☰ lesson list | ⚙ settings
#    - Heart: toggles save / unsave
#
#  SAVED mode (Global.flashcard_mode == "saved"):
#    - Loads all words from Global.get_saved_words()
#    - Header: back arrow + audio button (dynamically loads lesson audio)
#    - Bottom nav: 📖 home | 🗑 Remove Word | 📝 Quiz
#    - Heart: static filled indicator (word is saved)
# ============================================================

enum Mode { LESSON, SAVED }

var word_list: Array     = []
var current_index: int   = 0
var current_book: int    = 0
var current_lesson: int  = 0
var mode: Mode           = Mode.LESSON
var is_flipped: bool     = false
var is_animating: bool   = false

# ---------- Drag, Slide & Rotation state ----------
var is_sliding: bool       = false
var is_dragging: bool      = false
var initial_card_x: float  = 0.0
var total_drag_dist: float = 0.0
const DRAG_THRESHOLD       := 80.0  # How far to drag before it counts as a word change
const DRAG_FLIP_TOLERANCE  := 10.0  # If dragged less than this, treat as a tap (flip)
const DRAG_ROTATION_FACTOR := 0.02  # How much the card tilts while dragging
const SLIDE_DURATION       := 0.2
const SNAP_DURATION        := 0.15

# ---------- Dot constants ----------
const DOT_ACTIVE_W    := 24
const DOT_INACTIVE_W  := 14
const DOT_HEIGHT      := 6
const DOT_RADIUS      := 3
const DOT_ACTIVE_COLOR    := Color("#8B5CF6")  # matches the flashcard's violet
const DOT_INACTIVE_COLOR  := Color(0.55, 0.60, 0.85, 0.45)

# ---------- Scene paths ----------
const SCENE_MAIN_MENU      := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_LESSON_MENU    := "res://scenes/lesson_menu/LessonMenu.tscn"
const SCENE_SETTINGS       := "res://scenes/settings/Settings.tscn"
const SCENE_REVIEW           := "res://scenes/review/WordReview.tscn"
const SCENE_NO_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_FLASHCARDS     := "res://scenes/vocabulary/VocabFlashcards.tscn"

# ---------- Node references ----------
@onready var lesson_title: Label               = $HeaderBar/HeaderContent/HeaderSpacer/LessonTitle

@onready var progress_dots: HBoxContainer      = $MarginContainer/MainLayout/ProgressBackground/ProgressDotsContainer
@onready var card_panel: PanelContainer        = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel

@onready var front_face: CenterContainer       = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/FrontFace
@onready var front_word_label: Label           = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/FrontFace/WordLabel

@onready var back_face: VBoxContainer          = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace
@onready var back_word_label: Label            = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/WordRow/WordRowContent/BackWordLabel
@onready var meaning_en_label: Label           = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/MeaningEnRow/MeaningEnRowContent/MeaningEnLabel
@onready var meaning_fa_label: Label           = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/MeaningFaRow/MeaningFaRowContent/MeaningFaLabel
@onready var example_label: Label              = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/ExampleRow/ExampleRowContent/ExampleLabel
@onready var phonetics_label: Label             = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/WordRow/WordRowContent/PhoneticsLabel

# Synonyms and Antonyms nodes
@onready var synonyms_panel: PanelContainer    = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/SynonymsPanel
@onready var synonyms_label: Label             = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/SynonymsPanel/SynonymsContainer/SynonymsLabel
@onready var antonyms_panel: PanelContainer    = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/AntonymsPanel
@onready var antonyms_label: Label             = $MarginContainer/MainLayout/CardScrollContainer/CardMargin/CardPanel/CardContent/BackFace/AntonymsPanel/AntonymsContainer/AntonymsLabel

@onready var prev_button: Button               = $MarginContainer/MainLayout/PanelContainer/BottomControls/PrevButton
@onready var save_button: Button               = $MarginContainer/MainLayout/PanelContainer/BottomControls/SaveButton
@onready var next_button: Button               = $MarginContainer/MainLayout/PanelContainer/BottomControls/NextButton

@onready var audio_button: Button              = $HeaderBar/HeaderContent/AudioButton
@onready var back_nav_button: Button           = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button               = $HeaderBar/HeaderContent/HomeButton
@onready var leitner_button: Button            = $HeaderBar/HeaderContent/LeitnerButton

@onready var save_inactive = preload("res://images/save_button.png")
@onready var save_active = preload("res://images/saved_button.png")


@onready var bg_rect: ColorRect = $TextureRect

@onready var FONT_FARSI : FontFile = preload("res://assets/fonts/Vazirmatn-Regular.ttf")

const FLIP_DURATION := 0.18

# ---------- Back-card palette (colorful rows, kept in both themes) ----------
# Row panels on the back face: each field keeps its own accent so the card
# reads as a set of colorful info pills instead of flat grey boxes.
const BACK_ROW_ACCENTS := {
	"WordRow":        Color("#10B981"),  # Emerald
	"MeaningEnRow":   Color("#3B82F6"),  # Blue
	"MeaningFaRow":   Color("#8B5CF6"),  # Violet
	"ExampleRow":     Color("#F59E0B"),  # Amber
	"SynonymsPanel":  Color("#14B8A6"),  # Teal
	"AntonymsPanel":  Color("#EF4444"),  # Red
}

# Icon badges on the back face (solid accent chips with white text).
const BACK_ICON_ACCENTS := {
	"EnIcon":   Color("#3B82F6"),
	"FaIcon":   Color("#8B5CF6"),
	"ExIcon":   Color("#F59E0B"),
	"SynIcon":  Color("#14B8A6"),
	"AntoIcon": Color("#EF4444"),
}

# Owned content labels on the back face (text color follows their row).
const BACK_LABEL_ACCENTS := {
	"BackWordLabel":   Color("#10B981"),
	"MeaningEnLabel":  Color("#3B82F6"),
	"MeaningFaLabel":  Color("#8B5CF6"),
	"ExampleLabel":    Color("#F59E0B"),
	"SynonymsLabel":   Color("#14B8A6"),
	"AntonymsLabel":   Color("#EF4444"),
}

# ---------- Happy flashcard gradient (the card's "main color") ----------
# A modern, energetic gradient (Indigo -> Purple -> Pink) for both themes.
# It makes the flashcards extremely vibrant and educational-friendly.
const FLASH_GRAD_LIGHT := [Color("#4F46E5"), Color("#9333EA"), Color("#DB2777")]
const FLASH_GRAD_DARK  := [Color("#3730A3"), Color("#6B21A8"), Color("#9D174D")]
const FLASH_PRIMARY    := Color("#6366F1")   # used for dots + accents

var _card_gradient_bg: ColorRect = null


func _ready() -> void:
	# Wire static buttons
	
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	save_button.pressed.connect(_on_save_pressed)
	# Tactile hit feedback: squash on press, spring-pop on release.
	prev_button.button_down.connect(_on_nav_press.bind(prev_button))
	prev_button.button_up.connect(_on_nav_release.bind(prev_button))
	next_button.button_down.connect(_on_nav_press.bind(next_button))
	next_button.button_up.connect(_on_nav_release.bind(next_button))
	save_button.button_down.connect(_on_nav_press.bind(save_button))
	save_button.button_up.connect(_on_nav_release.bind(save_button))
	audio_button.pressed.connect(_on_audio_pressed)
	back_nav_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	leitner_button.pressed.connect(_on_leitner_pressed)
	card_panel.gui_input.connect(_on_card_input)

	audio_button.pivot_offset = audio_button.size / 2.0
	back_nav_button.pivot_offset = back_nav_button.size / 2.0
	next_button.pivot_offset = next_button.size / 2.0
	prev_button.pivot_offset = prev_button.size / 2.0

	# Theme awareness: restyle for Dark / Light and follow live toggles.
	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	if Global.flashcard_mode == "saved":
		Global.word_review_return = "res://scenes/vocabulary/VocabFlashcards.tscn"
		_enter_saved_mode()
	else:
		_enter_lesson_mode()


# ----------------------------------------------------------------
#  THEME AWARENESS — restyle this screen for Dark / Light
# ----------------------------------------------------------------
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	# Background ColorRect resolves through Global.
	bg_rect.color = Global.get_theme_color("bg_base")
	# Header bar, cards, labels, buttons walk the whole scene.
	_theme_walk(self)
	# Unified header bar styling last, so it wins over the generic walk.
	if has_node("HeaderBar"):
		Global.style_header($HeaderBar)
	# Redesigned bottom controls last, so they win over the generic walk.
	_style_bottom_controls()


func _theme_walk(node: Node) -> void:
	if node is ColorRect and node.name in ["BackgroundColor", "Bg", "TextureRect"]:
		bg_rect.color = Global.get_theme_color("bg_base")
	elif node is PanelContainer:
		if BACK_ROW_ACCENTS.has(node.name):
			# Back-face info pills keep their colorful accent styling.
			_theme_back_row(node)
		else:
			_theme_card(node)
	elif node is Label:
		if BACK_ICON_ACCENTS.has(node.name):
			# Back-face icon badges become solid accent chips.
			_theme_back_icon(node)
		else:
			_theme_label(node)
	elif node is Button:
		_theme_button(node)
	for child in node.get_children():
		_theme_walk(child)


func _theme_card(node: PanelContainer) -> void:
	var dark := Global.theme_is_dark()
	# The flashcard itself gets a happy gradient + border/shadow frame.
	if node == card_panel:
		var frame := StyleBoxFlat.new()
		frame.set_corner_radius_all(28)
		frame.set_border_width_all(1)
		frame.border_color = Color(0, 0, 0, 0.12) if not dark else Color(1, 1, 1, 0.16)
		frame.shadow_color = Color(0.25, 0.15, 0.55, 0.22 if dark else 0.18)
		frame.shadow_size = 20
		frame.shadow_offset = Vector2(0, 10)
		node.add_theme_stylebox_override("panel", frame)
		_ensure_card_gradient(dark)
		return
	# Progress dots bar sits in a soft pill so it belongs to the card.
	if node.name == "ProgressBackground":
		var pst := StyleBoxFlat.new()
		pst.set_corner_radius_all(30)
		pst.set_border_width_all(1)
		pst.border_color = Color(0.45, 0.42, 0.8, 0.18) if not dark else Color(1, 1, 1, 0.08)
		pst.bg_color = Color(1, 1, 1, 0.65) if not dark else Color(0.12, 0.11, 0.26, 0.5)
		node.add_theme_stylebox_override("panel", pst)
		return
	# Any other themed panel falls back to a clean surface card.
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(28)
	style.set_border_width_all(1)
	style.bg_color = Global.get_theme_color("surface")
	style.border_color = Color(0, 0, 0, 0.10) if not dark else Color(1, 1, 1, 0.10)
	node.add_theme_stylebox_override("panel", style)


func _ensure_card_gradient(_dark: bool) -> void:
	if _card_gradient_bg == null:
		_card_gradient_bg = ColorRect.new()
		_card_gradient_bg.name = "CardGradientBg"
		_card_gradient_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 bot_color : source_color;
uniform vec4 corner_color : source_color;
uniform float corner_radius = 28.0;
uniform vec2 rect_size;

float sdRoundedBox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 col;
	if (UV.y < 0.5) {
		col = mix(top_color, mid_color, UV.y * 2.0);
	} else {
		col = mix(mid_color, bot_color, (UV.y - 0.5) * 2.0);
	}
	
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 b = rect_size * 0.5;
	float d = sdRoundedBox(p, b, corner_radius);
	
	float blend = clamp(0.5 - d, 0.0, 1.0);
	COLOR = mix(corner_color, col, blend);
}
"""
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_card_gradient_bg.material = mat
		
		card_panel.add_child(_card_gradient_bg)
		card_panel.move_child(_card_gradient_bg, 0)  # behind the card content
		card_panel.resized.connect(_refresh_card_gradient)
	_refresh_card_gradient()


func _refresh_card_gradient() -> void:
	var sz: Vector2 = card_panel.size
	if sz.x <= 2.0 or sz.y <= 2.0 or not is_instance_valid(_card_gradient_bg):
		return
	var dark := Global.theme_is_dark()
	var palette: Array = FLASH_GRAD_DARK if dark else FLASH_GRAD_LIGHT
	var mat = _card_gradient_bg.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", sz)
		mat.set_shader_parameter("top_color", palette[0])
		mat.set_shader_parameter("mid_color", palette[1])
		mat.set_shader_parameter("bot_color", palette[2])
		mat.set_shader_parameter("corner_color", Global.get_theme_color("bg_base"))
		mat.set_shader_parameter("corner_radius", 28.0)


func _optimize_icon(tex: Texture2D, max_edge: int = 256) -> Texture2D:
	# Downscales oversized icon sources with high-quality interpolation and
	# adds mipmaps so the icon renders with SMOOTH edges at display size
	# instead of jagged/aliased ones (the heart is a 2500px source shown
	# at ~120px). Falls back to the original if it can't be processed.
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w > max_edge or h > max_edge:
		var s: float = float(max_edge) / float(maxf(w, h))
		img.resize(roundi(w * s), roundi(h * s), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _theme_back_row(panel: PanelContainer) -> void:
	# A clean content "pill" on the colorful gradient card.
	var dark := Global.theme_is_dark()
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(18)
	st.set_border_width_all(1)
	if dark:
		# A deep slate pill to contrast against the vibrant dark gradient
		st.bg_color = Color("#1E293B")
		st.bg_color.a = 0.95
		st.border_color = Color(1, 1, 1, 0.15)
	else:
		st.bg_color = Color(1, 1, 1, 0.95)
		st.border_color = Color(0, 0, 0, 0.08)
	st.shadow_color = Color(0, 0, 0, 0.2 if dark else 0.08)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 4)
	var old: StyleBox = panel.get_theme_stylebox("panel")
	if old is StyleBoxFlat:
		var of := old as StyleBoxFlat
		st.content_margin_left = of.content_margin_left
		st.content_margin_top = of.content_margin_top
		st.content_margin_right = of.content_margin_right
		st.content_margin_bottom = of.content_margin_bottom
	else:
		st.content_margin_left = 20
		st.content_margin_right = 20
		st.content_margin_top = 16
		st.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", st)


func _theme_back_icon(icon: Label) -> void:
	# A solid accent chip (white text) that never washes out in either
	# theme — replaces the old pale badge with a flat colored tile.
	var accent: Color = BACK_ICON_ACCENTS.get(icon.name, Global.get_theme_color("accent"))
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(14)
	st.bg_color = accent
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	icon.add_theme_stylebox_override("normal", st)
	icon.add_theme_color_override("font_color", Color(1, 1, 1))
	if icon.label_settings != null:
		icon.label_settings.font_color = Color(1, 1, 1)
		icon.label_settings.outline_size = 0


func _theme_label(label: Label) -> void:
	var n: String = label.name
	var fill: Color
	var dark := Global.theme_is_dark()
	
	if n == "WordLabel":
		# The FRONT word sits directly on the colorful gradient — white so it
		# pops, with a soft shadow for contrast on the bright card.
		fill = Color(1, 1, 1)
	elif BACK_LABEL_ACCENTS.has(n):
		fill = BACK_LABEL_ACCENTS[n]
		if dark:
			# Lighten and desaturate slightly for better contrast on dark pill
			fill = fill.lerp(Color(1, 1, 1), 0.2)
	elif n.ends_with("Title"):
		fill = Global.get_theme_color("accent_bright")
	elif n in ["PhoneticsLabel"]:
		fill = Global.get_theme_color("text_dim")
	else:
		fill = Global.get_theme_color("text")
		
	label.add_theme_color_override("font_color", fill)
	# Drive LabelSettings explicitly so these labels follow the theme too.
	if label.label_settings != null:
		label.label_settings.font_color = fill
		label.label_settings.outline_size = 0
		label.label_settings.shadow_color = Color(0, 0, 0, 0)
		label.label_settings.shadow_offset = Vector2(0, 0)
	# Drop any glow outlines/shadows — they read as hollow/halo text.
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	# Front word on the colorful gradient benefits from a soft drop shadow.
	if n == "WordLabel":
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 4)


func _theme_button(btn: Button) -> void:
	var colored := _button_has_colored_bg(btn)
	var fc: Color = Color(1, 1, 1) if colored else Global.get_theme_color("text")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, fc)


func _button_has_colored_bg(btn: Button) -> bool:
	var st: StyleBox = btn.get_theme_stylebox("normal")
	if st is StyleBoxFlat:
		var c: Color = (st as StyleBoxFlat).bg_color
		var mx := maxf(maxf(c.r, c.g), c.b)
		var mn := minf(minf(c.r, c.g), c.b)
		# Saturated accents AND dark backgrounds both need light text.
		return c.a > 0.4 and ((mx - mn) > 0.25 or c.get_luminance() < 0.45)
	return false


# ----------------------------------------------------------------
#  BOTTOM CONTROLS — redesigned prev / save / next bar (theme-aware)
# ----------------------------------------------------------------
func _style_bottom_controls() -> void:
	var accent: Color = Global.get_theme_color("accent")

	# The control dock itself is invisible — the flat icon buttons float.
	var panel: PanelContainer = $MarginContainer/MainLayout/PanelContainer
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0, 0, 0, 0)
	pst.set_border_width_all(0)
	pst.shadow_color = Color(0, 0, 0, 0)
	pst.shadow_size = 0
	panel.add_theme_stylebox_override("panel", pst)
	panel.offset_transform_scale = Vector2.ONE

	var controls: HBoxContainer = $MarginContainer/MainLayout/PanelContainer/BottomControls
	controls.add_theme_constant_override("separation", 68)

	# Optimize the arrow icons so their edges render smoothly.
	prev_button.icon = _optimize_icon(load("res://images/prev.png"))
	next_button.icon = _optimize_icon(load("res://images/next.png"))

	_style_nav_button(prev_button, accent)
	_style_nav_button(next_button, accent)
	_style_save_button(save_button, accent)


func _style_nav_button(btn: Button, accent: Color) -> void:
	# Flat icon button — no persistent panel. A soft circular highlight only
	# appears on hover/press for affordance, keeping the icons clean.
	btn.flat = true
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn.add_theme_constant_override("icon_max_width", 200)
	btn.add_theme_constant_override("icon_max_height", 200)
	btn.custom_minimum_size = Vector2(180, 180)

	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.set_border_width_all(0)
	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(80)
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(80)
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
	btn.add_theme_stylebox_override("normal", clear)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


func _style_save_button(btn: Button, accent: Color) -> void:
	# Flat heart/remove toggle — no persistent panel, soft highlight on hover/press.
	btn.flat = true
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn.add_theme_constant_override("icon_max_width", 200)
	btn.add_theme_constant_override("icon_max_height", 200)
	btn.custom_minimum_size = Vector2(200, 200)

	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.set_border_width_all(0)
	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(100)
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(100)
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
	btn.add_theme_stylebox_override("normal", clear)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


# ----------------------------------------------------------------
#  MODE ENTRY POINTS
# ----------------------------------------------------------------
func _enter_lesson_mode() -> void:
	mode = Mode.LESSON
	audio_button.visible = true
	leitner_button.visible = false

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson
	var lesson_data := Global.load_vocabulary(book, lesson)
	
	lesson_title.text = MenuStyle.persian_digits("ویژن %d\nدرس %s" % [book, lesson])
	
	if lesson_data.is_empty():
		push_error("Failed to load lesson %d from book %d" % [lesson, book])
		get_tree().change_scene_to_file(SCENE_LESSON_MENU)
		return
	
	var vocab_section: Dictionary = lesson_data.get("vocabulary", {})
	setup(
		vocab_section.get("words", []),
		book, lesson,
		"",
		Mode.LESSON
	)


func _enter_saved_mode() -> void:
	mode = Mode.SAVED
	audio_button.visible = true # Brought this back for saved mode

	lesson_title.text = "فلش کارت"
	# Smaller title so it fits the header without overlapping the buttons.
	lesson_title.add_theme_font_size_override("font_size", 44)
	if FONT_FARSI != null:
		lesson_title.add_theme_font_override("font", FONT_FARSI)

	leitner_button.visible = true
	save_button.icon = _optimize_icon(load("res://images/Remove.png"))
	save_button.modulate = Color(1, 1, 1, 1)
	save_button.disabled = false

	var saved_copy = Global.get_saved_words().duplicate()
	setup(saved_copy, 0, 0, "", Mode.SAVED)


# ----------------------------------------------------------------
#  PUBLIC SETUP
# ----------------------------------------------------------------
func setup(words: Array, book: int, lesson: int, _audio_filename: String, screen_mode: Mode = Mode.LESSON) -> void:
	word_list            = words
	current_book         = book
	current_lesson       = lesson
	mode                 = screen_mode
	current_index        = 0
	is_flipped           = false

	_build_progress_dots()
	_update_card(false)


# ----------------------------------------------------------------
#  PROGRESS DOTS
# ----------------------------------------------------------------
func _build_progress_dots() -> void:
	for child in progress_dots.get_children():
		child.queue_free()

	var total: int = word_list.size()
	var num_dots: int = min(total, 50)

	for i in num_dots:
		var dot := Panel.new()
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left     = DOT_RADIUS
		style.corner_radius_top_right    = DOT_RADIUS
		style.corner_radius_bottom_left  = DOT_RADIUS
		style.corner_radius_bottom_right = DOT_RADIUS
		style.bg_color = DOT_ACTIVE_COLOR if i == current_index else DOT_INACTIVE_COLOR
		dot.add_theme_stylebox_override("panel", style)
		dot.custom_minimum_size = Vector2(
			DOT_ACTIVE_W if i == current_index else DOT_INACTIVE_W,
			DOT_HEIGHT
		)
		progress_dots.add_child(dot)


func _update_progress_dots() -> void:
	var dots := progress_dots.get_children()
	for i in dots.size():
		var dot: Panel = dots[i]
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left     = DOT_RADIUS
		style.corner_radius_top_right    = DOT_RADIUS
		style.corner_radius_bottom_left  = DOT_RADIUS
		style.corner_radius_bottom_right = DOT_RADIUS
		style.bg_color = DOT_ACTIVE_COLOR if i == current_index else DOT_INACTIVE_COLOR
		dot.add_theme_stylebox_override("panel", style)
		dot.custom_minimum_size = Vector2(
			DOT_ACTIVE_W if i == current_index else DOT_INACTIVE_W,
			DOT_HEIGHT
		)


# ----------------------------------------------------------------
#  CARD DISPLAY
# ----------------------------------------------------------------
func _update_card(animate: bool = false) -> void:
	if word_list.is_empty():
		_handle_empty_list()
		return

	var entry: Dictionary = word_list[current_index]

	# Dynamically update audio details in Saved Mode
	if mode == Mode.SAVED:
		current_book = entry.get("book", 0)
		current_lesson = entry.get("lesson", 0)

	front_word_label.text = entry.get("word", "")
	back_word_label.text  = entry.get("word", "")
	meaning_en_label.text = entry.get("meaning_en", "")
	meaning_fa_label.text = entry.get("meaning_fa", "")
	example_label.text    = entry.get("example", "")
	
	var phonetics_text: String = entry.get("phonetics", "")
	if phonetics_text != "":
		phonetics_label.text = phonetics_text
		phonetics_label.visible = true
	else:
		phonetics_label.text = ""
		phonetics_label.visible = false
	
	# --- Update Synonyms ---
	_update_synonyms(entry)
	
	# --- Update Antonyms ---
	_update_antonyms(entry)

	is_flipped = false

	if animate:
		_play_flip(false)
	else:
		_show_face(false)

	_update_progress_dots()

	if mode == Mode.LESSON:
		_refresh_save_button(entry)


func _update_synonyms(entry: Dictionary) -> void:
	var synonyms_data = entry.get("synonyms", {})
	var en_synonyms: Array = synonyms_data.get("en", [])
	var fa_synonyms: Array = synonyms_data.get("fa", [])
	
	# Combine synonyms: English ones first, then Farsi ones
	var all_synonyms: Array = []
	all_synonyms.append_array(en_synonyms)
	all_synonyms.append_array(fa_synonyms)
	
	if all_synonyms.is_empty():
		synonyms_panel.visible = false
		return
	
	synonyms_panel.visible = true
	synonyms_label.text = ", ".join(all_synonyms)


func _update_antonyms(entry: Dictionary) -> void:
	var antonyms_data = entry.get("antonyms", {})
	var en_antonyms: Array = antonyms_data.get("en", [])
	var fa_antonyms: Array = antonyms_data.get("fa", [])
	
	# Combine antonyms: English ones first, then Farsi ones
	var all_antonyms: Array = []
	all_antonyms.append_array(en_antonyms)
	all_antonyms.append_array(fa_antonyms)
	
	if all_antonyms.is_empty():
		antonyms_panel.visible = false
		return
	
	antonyms_panel.visible = true
	antonyms_label.text = ", ".join(all_antonyms)


func _handle_empty_list() -> void:
	if mode == Mode.SAVED:
		get_tree().change_scene_to_file(SCENE_NO_SAVED_WORDS)
	else:
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _refresh_save_button(entry: Dictionary) -> void:
	if mode != Mode.LESSON:
		return
	var saved := Global.is_word_saved(entry.get("word", ""), current_book, current_lesson)
	save_button.icon     = _optimize_icon(save_active if saved else save_inactive)
	save_button.disabled = false


func _show_face(show_back: bool) -> void:
	front_face.visible = not show_back
	back_face.visible  = show_back


# ----------------------------------------------------------------
#  FLIP ANIMATION
# ----------------------------------------------------------------
func _play_flip(landing_on_back: bool) -> void:
	if is_animating or is_sliding:
		return
	is_animating = true
	card_panel.pivot_offset = Vector2(card_panel.size.x / 2.0, card_panel.size.y / 2.0)

	var tween := create_tween()
	tween.tween_property(card_panel, "scale:x", 0.0, FLIP_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _show_face(landing_on_back))
	tween.tween_property(card_panel, "scale:x", 1.0, FLIP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): is_animating = false)


# ----------------------------------------------------------------
#  DRAG, SLIDE & ROTATE LOGIC
# ----------------------------------------------------------------
func _on_card_input(event: InputEvent) -> void:
	# 1. Handle Dragging (Mouse move or Touch drag)
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_dragging:
			total_drag_dist += event.relative.x
			
			# Move and Rotate
			card_panel.position.x = initial_card_x + total_drag_dist
			card_panel.rotation_degrees = total_drag_dist * DRAG_ROTATION_FACTOR
			
	# 2. Handle Press and Release
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch:
		if event.pressed:
			if is_animating or is_sliding or word_list.is_empty():
				return
			# Start drag - Set pivot so it rotates from the center
			card_panel.pivot_offset = Vector2(card_panel.size.x / 2.0, card_panel.size.y / 2.0)
			is_dragging = true
			initial_card_x = card_panel.position.x
			total_drag_dist = 0.0
		else:
			# End drag
			if is_dragging:
				is_dragging = false
				
				# Evaluate the drag distance
				if abs(total_drag_dist) > DRAG_THRESHOLD:
					var direction = 1 if total_drag_dist < 0 else -1
					_finish_slide_animation(direction, initial_card_x)
				elif abs(total_drag_dist) > DRAG_FLIP_TOLERANCE:
					# Didn't drag far enough to change word, snap back
					_snap_back_animation(initial_card_x)
				else:
					# Barely moved at all, treat as a tap/flip
					card_panel.position.x = initial_card_x
					card_panel.rotation_degrees = 0.0
					_flip()


func _finish_slide_animation(direction: int, start_x: float) -> void:
	# direction: 1 (sliding left to next), -1 (sliding right to prev)
	is_sliding = true
	var slide_distance = get_viewport_rect().size.x
	var target_x = start_x - (direction * slide_distance)
	
	# Calculate how much it should be rotated when it reaches the edge
	var target_rotation = (-direction * slide_distance) * DRAG_ROTATION_FACTOR 

	var tween = create_tween()
	
	# Finish sliding out (Position AND Rotation at the same time using parallel)
	tween.tween_property(card_panel, "position:x", target_x, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(card_panel, "rotation_degrees", target_rotation, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(func():
		if direction == 1:
			current_index = (current_index + 1) % word_list.size()
		else:
			current_index = (current_index - 1 + word_list.size()) % word_list.size()
			
		_update_card(false)
		
		# Move to opposite side off-screen instantly, and reset rotation to 0
		card_panel.position.x = start_x + (direction * slide_distance)
		card_panel.rotation_degrees = 0.0
	)

	# Slide back in
	tween.tween_property(card_panel, "position:x", start_x, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): is_sliding = false)


func _snap_back_animation(target_x: float) -> void:
	is_sliding = true
	var tween = create_tween()
	
	# Snap back position and rotate back to 0 at the same time
	tween.tween_property(card_panel, "position:x", target_x, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(card_panel, "rotation_degrees", 0.0, SNAP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	tween.tween_callback(func(): is_sliding = false)


# Re-use the slide logic for the UI buttons
func _button_slide(direction: int) -> void:
	if is_sliding or is_animating or is_dragging or word_list.is_empty():
		return
		
	# Ensure pivot is centered for rotation
	card_panel.pivot_offset = Vector2(card_panel.size.x / 2.0, card_panel.size.y / 2.0)
	
	# Start a slide from the center
	_finish_slide_animation(direction, card_panel.position.x)


func _flip() -> void:
	if is_animating or is_sliding or word_list.is_empty():
		return
	is_flipped = not is_flipped
	_play_flip(is_flipped)


func _on_nav_press(btn: Button) -> void:
	# Keep the scale centered on the button regardless of layout timing.
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.86, 0.86), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _on_nav_release(btn: Button) -> void:
	# Spring back with a slight overshoot so the tap feels snappy.
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_prev_pressed() -> void:
	_button_slide(-1)


func _on_next_pressed() -> void:
	_button_slide(1)


# ----------------------------------------------------------------
#  SAVE / REMOVE (heart button)
# ----------------------------------------------------------------
func _on_save_pressed() -> void:
	# In SAVED mode the centre button removes the current word.
	if mode == Mode.SAVED:
		_on_remove_pressed()
		return
	if mode != Mode.LESSON or word_list.is_empty():
		return
	var entry: Dictionary = word_list[current_index]
	if Global.is_word_saved(entry.get("word", ""), current_book, current_lesson):
		Global.remove_word(entry.get("word", ""), current_book, current_lesson)
	else:
		var data := entry.duplicate()
		data["book"]   = current_book
		data["lesson"] = current_lesson
		Global.save_word(data)
	_refresh_save_button(entry)


func _on_remove_pressed() -> void:
	# Remove the current word from saved words (SAVED mode only).
	if mode != Mode.SAVED or word_list.is_empty():
		return
	var entry: Dictionary = word_list[current_index]
	Global.remove_word(entry.get("word", ""), entry.get("book", 0), entry.get("lesson", 0))
	word_list.remove_at(current_index)
	if current_index > 0 and current_index >= word_list.size():
		current_index = word_list.size() - 1
	_update_card(false)


# ----------------------------------------------------------------
#  AUDIO
# ----------------------------------------------------------------
func _on_audio_pressed() -> void:
	if word_list.is_empty():
		return
		
	var entry: Dictionary = word_list[current_index]
	var audio_filename: String = entry.get("audio", "")
	var word_text: String = entry.get("word", "")

	# Keep your existing button bounce animation
	var tween := create_tween()
	tween.tween_property(audio_button, "scale", Vector2(0.93, 0.93), 0.08) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Trigger unified audio playback (with built-in TTS fallback)
	Global.play_word_audio(audio_filename, word_text)

# ----------------------------------------------------------------
#  NAVIGATION
# ----------------------------------------------------------------
func _on_home_pressed() -> void:
	Global.flashcard_mode = "lesson"
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_leitner_pressed() -> void:
	# Record where the review session came from so WordReview's back button
	# returns here (saved-words flashcards).
	Global.word_review_return = SCENE_FLASHCARDS
	TransitionManager.change_scene(SCENE_REVIEW)

func _on_back_button_pressed() -> void:
	Global.flashcard_mode = "lesson"
	if mode == Mode.SAVED:
		TransitionManager.change_scene(SCENE_MAIN_MENU)
	else:
		TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
