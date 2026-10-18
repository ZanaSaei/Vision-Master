extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  VOCAB FLASHCARDS — handles both LESSON and SAVED modes.
#
#  LESSON mode (AppRouter arg `mode` == "lesson"):
#    - Loads words from the current lesson's JSON
#    - Header: back arrow + audio button
#    - Bottom nav: 📖 home | ☰ lesson list | ⚙ settings
#    - Heart: toggles save / unsave
#
#  SAVED mode (AppRouter arg `mode` == "saved"):
#    - Loads all words from Global.get_saved_words()
#    - Header: back arrow + audio button (dynamically loads lesson audio)
#    - Bottom nav: 📖 home | 🗑 Remove Word | 📝 Quiz
#    - Save button: Remove.png glyph — removes the card from the saved list
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
# Past this many words the dot strip scales down instead of rendering one dot
# per card, which would overflow the header on a large saved list.
const MAX_PROGRESS_DOTS := 50
var _num_dots: int = 0
const DOT_ACTIVE_COLOR    := DesignTokens.GOLD  # editorial gold marker
const DOT_INACTIVE_COLOR  := Color(0.45, 0.42, 0.36, 0.35)

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

@onready var save_inactive = preload("res://assets/images/ui/save_button.png")
@onready var save_active = preload("res://assets/images/ui/saved_button.png")
# SAVED mode shows a Remove glyph instead of the heart: on that screen the
# button means "take this card out of my saved list", not "bookmark it".
@onready var save_remove = preload("res://assets/images/ui/Remove.png")


@onready var bg_rect: ColorRect = $TextureRect

@onready var FONT_FARSI : FontFile = preload("res://assets/fonts/Vazirmatn-Regular.ttf")

const FLIP_DURATION := 0.18

# ---------- Book accent palette ----------
# One solid cover color per Vision book, so a lesson reads as one deck:
# Vision 1 = dark blue, Vision 2 = dark green, Vision 3 = dark orange.
# Saved cards carry their original book id, so they keep their book color.
const BOOK_ACCENT_VISION_1 := Color("#1E3A5F")
const BOOK_ACCENT_VISION_2 := Color("#0F5E5A")
const BOOK_ACCENT_VISION_3 := Color("#B4530A")
const BOOK_ACCENTS := {
	1: BOOK_ACCENT_VISION_1,
	2: BOOK_ACCENT_VISION_2,
	3: BOOK_ACCENT_VISION_3,
}


func _card_book() -> int:
	if not word_list.is_empty() and current_index >= 0 and current_index < word_list.size():
		var entry: Dictionary = word_list[current_index]
		if entry.has("book"):
			return int(entry.get("book", current_book))
	return current_book


func _current_accent() -> Color:
	var book := _card_book()
	if BOOK_ACCENTS.has(book):
		return BOOK_ACCENTS[book]
	if not word_list.is_empty() and current_book != 0 and BOOK_ACCENTS.has(current_book):
		return BOOK_ACCENTS[current_book]
	return BOOK_ACCENT_VISION_2


# Row panels on the back face: the WordRow is the solid accent header band,
# the rest are white checklist rows. Kept so _theme_walk still routes here.
const BACK_ROW_ACCENTS := {
	"WordRow":        Color("#0F5E5A"),
	"MeaningEnRow":   Color("#0F5E5A"),
	"MeaningFaRow":   Color("#0F5E5A"),
	"ExampleRow":     Color("#0F5E5A"),
	"SynonymsPanel":  Color("#0F5E5A"),
	"AntonymsPanel":  Color("#0F5E5A"),
}

# How much extra padding to add around every back-card label pill. This makes
# the label boxes a little bigger visually while leaving the actual text size
# untouched (the request: bigger labels, same-sized text).
const BACK_ROW_PAD_BOOST := 6.0

# Icon badges on the back face (small ink chips with gold text).
const BACK_ICON_ACCENTS := {
	"EnIcon":   DesignTokens.INK,
	"FaIcon":   DesignTokens.INK,
	"ExIcon":   DesignTokens.INK,
	"SynIcon":  DesignTokens.INK,
	"AntoIcon": DesignTokens.INK,
}

# Owned content labels on the back face (warm ink, not rainbow text).
const BACK_LABEL_ACCENTS := {
	"BackWordLabel":   DesignTokens.INK,
	"MeaningEnLabel":  DesignTokens.INK,
	"MeaningFaLabel":  DesignTokens.INK,
	"ExampleLabel":    DesignTokens.INK,
	"SynonymsLabel":   DesignTokens.INK,
	"AntonymsLabel":   DesignTokens.INK,
}

# ---------- Warm paper flashcard ----------
const FLASH_SOLID_COLOR := DesignTokens.PAPER  # Cream paper - calm editorial card


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

	if str(AppRouter.get_arg("mode", "lesson")) == "saved":
		AppRouter.set_args({"return_route": SCENE_FLASHCARDS})
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
	_style_card_face(node, is_flipped)


func _style_card_face(node: PanelContainer, show_back: bool) -> void:
	var dark := Global.theme_is_dark()
	# Clover method card, face-aware like the reference:
	# FRONT = solid accent cover (orange Ideation card), BACK = white body
	# with a thick accent top band (Clover Design checklist card).
	if node == card_panel:
		var accent := _current_accent()
		var frame := StyleBoxFlat.new()
		frame.set_corner_radius_all(DesignTokens.RADIUS_LG)
		if show_back:
			frame.bg_color = Color("#FFFFFF") if not dark else Color("#2A2D33")
			frame.border_width_top = 28
			frame.border_width_left = 2
			frame.border_width_right = 2
			frame.border_width_bottom = 2
		else:
			frame.bg_color = accent
			frame.set_border_width_all(0)
		frame.border_color = accent
		frame.shadow_color = Color(accent.r, accent.g, accent.b, 0.30 if not dark else 0.45)
		frame.shadow_size = 22
		frame.shadow_offset = Vector2(0, 10)
		node.add_theme_stylebox_override("panel", frame)
		return
	# Progress dots bar sits in a quiet editorial strip above the paper.
	if node.name == "ProgressBackground":
		var pst := StyleBoxFlat.new()
		pst.set_corner_radius_all(DesignTokens.RADIUS_PILL)
		pst.set_border_width_all(0)
		pst.bg_color = Color(0, 0, 0, 0)
		node.add_theme_stylebox_override("panel", pst)
		return
	# Any other themed panel falls back to a clean surface card.
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(28)
	style.set_border_width_all(1)
	style.bg_color = Global.get_theme_color("surface")
	style.border_color = Color(0, 0, 0, 0.10) if not dark else Color(1, 1, 1, 0.10)
	node.add_theme_stylebox_override("panel", style)


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
	# Clover checklist rows: white, borderless, slim accent left marker.
	var dark := Global.theme_is_dark()
	var accent := _current_accent()
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(14)
	st.bg_color = Color("#FFFFFF") if not dark else Color("#2A2D33")
	st.border_width_left = 8
	st.border_width_top = 0
	st.border_width_right = 0
	st.border_width_bottom = 0
	st.border_color = accent
	st.shadow_color = Color(0, 0, 0, 0)
	st.shadow_size = 0
	st.shadow_offset = Vector2.ZERO

	# Make the label boxes a little bigger (more padding) while leaving the text
	# size untouched. The base (scene) margins are cached once, so re-theming
	# never doubles the boost.
	var ml := 20.0
	var mr := 20.0
	var mt := 16.0
	var mb := 16.0
	if panel.has_meta("back_row_margins"):
		var base_m: Array = panel.get_meta("back_row_margins") as Array
		ml = base_m[0]
		mr = base_m[1]
		mt = base_m[2]
		mb = base_m[3]
	else:
		var old: StyleBox = panel.get_theme_stylebox("panel")
		if old is StyleBoxFlat:
			var of := old as StyleBoxFlat
			ml = of.content_margin_left
			mr = of.content_margin_right
			mt = of.content_margin_top
			mb = of.content_margin_bottom
		panel.set_meta("back_row_margins", [ml, mr, mt, mb])

	st.content_margin_left = ml + BACK_ROW_PAD_BOOST
	st.content_margin_right = mr + BACK_ROW_PAD_BOOST
	st.content_margin_top = mt + BACK_ROW_PAD_BOOST
	st.content_margin_bottom = mb + BACK_ROW_PAD_BOOST
	panel.add_theme_stylebox_override("panel", st)


func _theme_back_icon(icon: Label) -> void:
	# Clover marker chip: soft accent tint with solid accent text.
	var accent := _current_accent()
	var dark := Global.theme_is_dark()
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(10)
	st.bg_color = Color(accent.r, accent.g, accent.b, 0.22 if not dark else 0.30)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	icon.add_theme_stylebox_override("normal", st)
	icon.add_theme_color_override("font_color", accent)
	if icon.label_settings != null:
		icon.label_settings.font_color = accent
		icon.label_settings.outline_size = 0


func _theme_label(label: Label) -> void:
	var n: String = label.name
	var fill: Color
	var dark := Global.theme_is_dark()
	
	if n == "BackWordLabel":
		# Sits on the solid accent header band — always white.
		fill = Color("#FFFFFF")
	elif n == "WordLabel":
		# FRONT sits on the SOLID accent cover — always white like Ideation.
		fill = Color("#FFFFFF")
	elif BACK_LABEL_ACCENTS.has(n):
		fill = Color("#2B2B2B") if not dark else Color("#E8E6E1")
		if n in ["MeaningEnLabel", "MeaningFaLabel"]:
			# Checklist prompt titles carry the card accent like the reference.
			fill = _current_accent()
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
	# White on solid accent needs a soft shadow for the Ideation-cover read.
	if n == "WordLabel":
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
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
	# Nav washes follow the current card accent (Clover deck feel).

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
	prev_button.icon = _optimize_icon(load("res://assets/images/ui/prev.png"))
	next_button.icon = _optimize_icon(load("res://assets/images/ui/next.png"))

	_style_nav_button(prev_button, _current_accent())
	_style_nav_button(next_button, _current_accent())
	_style_save_button(save_button, _current_accent())


func _style_nav_button(btn: Button, gold: Color) -> void:
	# Flat icon button — no persistent panel. A warm gold wash only
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
	hover.bg_color = Color(gold.r, gold.g, gold.b, 0.16)
	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(80)
	pressed.bg_color = Color(gold.r, gold.g, gold.b, 0.28)
	btn.add_theme_stylebox_override("normal", clear)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


func _style_save_button(btn: Button, gold: Color) -> void:
	# Flat heart/remove toggle — warm gold wash on hover/press.
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
	hover.bg_color = Color(gold.r, gold.g, gold.b, 0.16)
	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(100)
	pressed.bg_color = Color(gold.r, gold.g, gold.b, 0.28)
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
	# Keep the heart meaningful in this mode: it is a save toggle, so show the
	# saved/unset state rather than a permanent trash icon.
	save_button.disabled = false

	# get_saved_words() already returns a deep copy, so the scene can safely
	# remove entries from it (as _on_remove_pressed does) without touching the
	# Global's live list. The extra duplicate() here was a no-op copy.
	setup(Global.get_saved_words(), 0, 0, "", Mode.SAVED)


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
func _dot_colors() -> Array:
	var accent := _current_accent()
	return [accent, Color(accent.r, accent.g, accent.b, 0.25)]
func _build_progress_dots() -> void:
	for child in progress_dots.get_children():
		child.queue_free()

	var total: int = word_list.size()
	_num_dots = mini(maxi(total, 0), MAX_PROGRESS_DOTS)

	for i in _num_dots:
		var dot := Panel.new()
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(DOT_RADIUS)
		var cols := _dot_colors()
		style.bg_color = cols[0] if i == _active_dot() else cols[1]
		dot.add_theme_stylebox_override("panel", style)
		dot.custom_minimum_size = Vector2(
			DOT_ACTIVE_W if i == _active_dot() else DOT_INACTIVE_W,
			DOT_HEIGHT
		)
		progress_dots.add_child(dot)


## Which dot represents the current card. With more words than dots the strip
## is scaled down, so the index has to be mapped into the visible window —
## otherwise the active dot simply never lights up on a large saved list.
func _active_dot() -> int:
	if _num_dots <= 0 or word_list.is_empty():
		return -1
	if _num_dots >= word_list.size():
		return clampi(current_index, 0, _num_dots - 1)
	return clampi(int(float(current_index) * _num_dots / word_list.size()), 0, _num_dots - 1)


func _update_progress_dots() -> void:
	# The list can shrink while SAVED (a word is removed), leaving a stale dot
	# strip behind. Rebuild it so the dots keep matching the word count.
	if progress_dots.get_child_count() != _num_dots:
		_build_progress_dots()
		return
	var active := _active_dot()
	var dots := progress_dots.get_children()
	for i in dots.size():
		var dot: Panel = dots[i]
		var is_active := i == active
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(DOT_RADIUS)
		var cols := _dot_colors()
		style.bg_color = cols[0] if is_active else cols[1]
		dot.add_theme_stylebox_override("panel", style)
		dot.custom_minimum_size = Vector2(
			DOT_ACTIVE_W if is_active else DOT_INACTIVE_W,
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

	_refresh_card_style()

	if animate:
		_play_flip(false)
	else:
		_show_face(false)

	_update_progress_dots()
	# Keep the heart in sync with the card now on screen, otherwise it shows
	# the previous word's saved state after every swipe/tap navigation.
	_refresh_save_button(entry)

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
	if word_list.is_empty():
		return
	# In SAVED mode the entry carries its own book/lesson, so the lookup has
	# to use those instead of current_book/current_lesson (which are 0 here).
	var book: int   = int(entry.get("book", current_book)) if mode == Mode.SAVED else current_book
	var lesson: int = int(entry.get("lesson", current_lesson)) if mode == Mode.SAVED else current_lesson
	var saved := Global.is_word_saved(str(entry.get("word", "")), book, lesson)
	# SAVED mode is a removal screen: every card shown is already saved, so
	# the button carries the Remove glyph instead of the heart. LESSON mode
	# keeps the heart as the save/unsave toggle.
	if mode == Mode.SAVED:
		save_button.icon = _optimize_icon(save_remove)
	else:
		save_button.icon = _optimize_icon(save_active if saved else save_inactive)
	save_button.modulate = Color(1, 1, 1, 1)
	save_button.disabled = false


func _refresh_card_style() -> void:
	_style_card_face(card_panel, is_flipped)
	_theme_walk(card_panel)
	_update_progress_dots()


func _show_face(show_back: bool) -> void:
	front_face.visible = not show_back
	back_face.visible = show_back
	_style_card_face(card_panel, show_back)


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
	# The heart is a save toggle in BOTH modes. In SAVED mode it used to be
	# hard-wired to _on_remove_pressed(), so tapping the heart there could
	# never save anything — it only ever deleted the word, which is what
	# "nothing happens when I press the heart" looked like.
	if word_list.is_empty():
		return

	var entry: Dictionary = word_list[current_index]
	var word: String = str(entry.get("word", ""))

	# In SAVED mode the cards come from saved_words, so a card's identity lives
	# on the entry itself; in LESSON mode it comes from the current lesson.
	var book: int   = int(entry.get("book", 0))     if mode == Mode.SAVED else current_book
	var lesson: int = int(entry.get("lesson", 0))   if mode == Mode.SAVED else current_lesson
	if mode != Mode.LESSON and mode != Mode.SAVED:
		return

	if Global.is_word_saved(word, book, lesson):
		# Unheart only removes the flashcard bookmark. The Leitner entry remains.
		Global.remove_word(word, book, lesson)
		if mode == Mode.SAVED:
			_refresh_from_global()
			return
	else:
		# Not saved yet → the heart saves it. Enrichment inside save_word()
		# fills in the meaning/example so the review card is never blank.
		var data: Dictionary = entry.duplicate(true)
		data["book"]   = book
		data["lesson"] = lesson
		Global.save_word(data)
		if mode == Mode.SAVED:
			_refresh_from_global()
			return

	_refresh_save_button(entry)


## Re-reads the saved list from Global after the heart toggled a word, so the
## cards on screen always match what is actually stored.
func _refresh_from_global() -> void:
	word_list = Global.get_saved_words()
	if current_index >= word_list.size():
		current_index = maxi(0, word_list.size() - 1)
	_build_progress_dots()
	_update_card(false)


func _on_remove_pressed() -> void:
	# Remove the current word from saved words (SAVED mode only).
	if mode != Mode.SAVED or word_list.is_empty():
		return
	var entry: Dictionary = word_list[current_index]
	Global.remove_word(entry.get("word", ""), entry.get("book", 0), entry.get("lesson", 0))
	word_list.remove_at(current_index)
	# Removing the last remaining card leaves index 0 with an empty list;
	# _update_card() routes that to the "no saved words" screen.
	if current_index > 0 and current_index >= word_list.size():
		current_index = word_list.size() - 1
	# The list just shrank, so the dot strip must be rebuilt (a stale strip
	# left one extra dot behind after every removal).
	_build_progress_dots()
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
	AppRouter.set_args({"mode": "lesson"})
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_leitner_pressed() -> void:
	# Record where the review session came from so WordReview's back button
	# returns here (saved-words flashcards).
	AppRouter.set_args({"return_route": SCENE_FLASHCARDS})
	TransitionManager.change_scene(SCENE_REVIEW)

func _on_back_button_pressed() -> void:
	AppRouter.set_args({"mode": "lesson"})
	if mode == Mode.SAVED:
		# Return to whichever screen opened the saved flashcards (the flashcard
		# hub), falling back to the main menu when none was recorded.
		var back_route: String = str(AppRouter.get_arg("saved_back_route", SCENE_MAIN_MENU))
		TransitionManager.change_scene(back_route)
	else:
		TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
