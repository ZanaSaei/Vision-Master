extends Control

# ============================================================
#  BOOK MENU
#  Reads Global.current_book to build lesson buttons dynamically.
#  Works for Vision 1 (4 lessons), Vision 2 & 3 (3 lessons each).
# ============================================================

const SCENE_MAIN_MENU   := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# ---------- Font configuration ----------
# Change these paths to your actual font files
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"

# Preload fonts for better performance
var font_regular: FontFile
var font_bold: FontFile

# Lesson titles per book, matching the real textbooks
const LESSON_DATA := {
	1: [
		"Lesson 1 — Saving Nature",
		"Lesson 2 — Wonders of Creation",
		"Lesson 3 — The Value of Knowledge",
		"Lesson 4 — Traveling the World",
	],
	2: [
		"Lesson 1 — Understanding People",
		"Lesson 2 — A Healthy Lifestyle",
		"Lesson 3 — Art and Culture",
	],
	3: [
		"Lesson 1 — Sense of Appreciation",
		"Lesson 2 — Look It Up!",
		"Lesson 3 — Renewable Energy",
	],
}

# One accent color per book — matches the main menu book button colors
const BOOK_COLORS := {
	1: Color("#2563EB"),  # Blue   — Vision 1
	2: Color("#16A34A"),  # Green  — Vision 2
	3: Color("#EA580C"),  # Orange — Vision 3
}

const BOOK_BG_COLORS := {
	1: Color("#EFF6FF"),
	2: Color("#F0FDF4"),
	3: Color("#FFF7ED"),
}

@onready var back_button: Button          = $PanelContainer/TopBar/BackButton
@onready var top_bar_title: Label         = $PanelContainer/TopBar/TopBarTitle
@onready var lessons_container: VBoxContainer = $MainLayout/InnerLayout/LessonsContainer


func _ready() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	# Load fonts
	_load_fonts()
	
	# Apply fonts to existing labels
	_apply_fonts_to_labels()
	
	back_button.button_up.connect(_on_back_button_pressed)
	
	var book: int = Global.current_book
	top_bar_title.text = "Vision %d" % book

	_build_lesson_buttons(book)


func _load_fonts() -> void:
	# Load fonts with error handling
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold = load(FONT_JAKARTA_BOLD_PATH)
	
	if font_regular == null:
		push_warning("Regular font not found at: " + FONT_JAKARTA_REGULAR_PATH)
		
	if font_bold == null:
		push_warning("Bold font not found at: " + FONT_JAKARTA_BOLD_PATH)


func _apply_fonts_to_labels() -> void:
	# Apply bold font to top bar title
	if font_bold != null:
		top_bar_title.add_theme_font_override("font", font_bold)


func _build_lesson_buttons(book: int) -> void:
	var lessons: Array = LESSON_DATA.get(book, [])
	var accent_color: Color = BOOK_COLORS.get(book, Color("#2563EB"))
	var bg_color: Color = BOOK_BG_COLORS.get(book, Color("#EFF6FF"))

	for i in lessons.size():
		var btn := Button.new()
		btn.text = lessons[i]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Style
		var style := StyleBoxFlat.new()
		style.bg_color = bg_color
		style.corner_radius_top_left     = 16
		style.corner_radius_top_right    = 16
		style.corner_radius_bottom_left  = 16
		style.corner_radius_bottom_right = 16
		style.border_width_left   = 4
		style.border_color        = accent_color
		btn.add_theme_stylebox_override("normal", style)

		# Hover style — slightly darker bg
		var hover_style := style.duplicate()
		hover_style.bg_color = accent_color.lightened(0.7)
		btn.add_theme_stylebox_override("hover", hover_style)

		# Apply font to button
		if font_regular != null:
			btn.add_theme_font_override("font", font_regular)
		
		btn.add_theme_font_size_override("font_size", 55)
		btn.add_theme_color_override("font_color", Color("#1E293B"))

		# bind(i + 1) so lesson number starts at 1
		btn.pressed.connect(_on_lesson_pressed.bind(i + 1))

		lessons_container.add_child(btn)


func _on_lesson_pressed(lesson_number: int) -> void:
	Global.current_lesson = lesson_number
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_back_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_MAIN_MENU)
