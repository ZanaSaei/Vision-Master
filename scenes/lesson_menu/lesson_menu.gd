extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  LESSON MENU
#  Shows 5 section buttons for the current book + lesson.
#  Reads Global.current_book and Global.current_lesson.
# ============================================================

const SCENE_BOOK_MENU    := "res://scenes/book_menu/BookMenu.tscn"
const SCENE_VOCAB        := "res://scenes/vocabulary/VocabFlashcards.tscn"
const SCENE_CONVERSATION := "res://scenes/conversation/Conversation.tscn"
const SCENE_READING      := "res://scenes/reading/Reading.tscn"
const SCENE_GRAMMAR      := "res://scenes/grammar/Grammar.tscn"
const SCENE_SPEAKING     := "res://scenes/speaking_pronunciation/SpeakingPronunciation.tscn"

# ---------- Font configuration ----------
# Change these paths to your actual font files
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"

# Preload fonts for better performance
var font_regular: FontFile
var font_bold: FontFile

# Lesson titles — same data as BookMenu, kept here for the subtitle label
const LESSON_TITLES := {
	1: ["Saving Nature", "Wonders of Creation",
		"The Value of Knowledge", "Traveling the World"],
	2: ["Understanding People", "A Healthy Lifestyle", "Art and Culture"],
	3: ["Sense of Appreciation", "Look It Up!", "Renewable Energy"],
}

# Section definitions: [display label, emoji icon, scene constant name]
const SECTIONS := [
	["New Words",                "📚", "VOCAB"],
	["Conversation",             "💬", "CONVERSATION"],
	["Reading",                  "📖", "READING"],
	["Grammar",                  "✏️",  "GRAMMAR"],
	["Speaking & Pronunciation", "🎙️",  "SPEAKING"],
]

# Soft background colors cycling through sections
const SECTION_COLORS := [
	Color("#EFF6FF"),  # light blue   — New Words
	Color("#F0FDF4"),  # light green  — Conversation
	Color("#FFF7ED"),  # light orange — Reading
	Color("#FDF4FF"),  # light purple — Grammar
	Color("#F0FDFA"),  # light teal   — Speaking
]

const SECTION_ACCENT_COLORS := [
	Color("#2563EB"),  # blue
	Color("#16A34A"),  # green
	Color("#EA580C"),  # orange
	Color("#9333EA"),  # purple
	Color("#0D9488"),  # teal
]

@onready var back_button: Button              = $PanelContainer/TopBar/BackButton
@onready var top_bar_title: Label             = $PanelContainer/TopBar/TopBarTitle
@onready var lesson_subtitle: Label           = $MainLayout/InnerLayout/LessonSubtitle
@onready var sections_container: VBoxContainer = $MainLayout/InnerLayout/SectionsContainer


func _ready() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	# Load fonts
	_load_fonts()
	
	# Apply fonts to existing labels
	_apply_fonts_to_labels()
	
	back_button.pressed.connect(_on_back_button_pressed)

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson

	top_bar_title.text  = "Lesson %d" % [lesson]
	lesson_subtitle.text = _get_lesson_title(book, lesson)

	_build_section_buttons()

	# Tell Global we were here so Continue Learning works
	Global.set_last_scene(
		get_tree().current_scene.scene_file_path
	)


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
	
	# Apply regular font to lesson subtitle
	if font_regular != null:
		lesson_subtitle.add_theme_font_override("font", font_regular)


func _get_lesson_title(book: int, lesson: int) -> String:
	var titles: Array = LESSON_TITLES.get(book, [])
	if lesson - 1 < titles.size():
		return titles[lesson - 1]
	return ""


func _build_section_buttons() -> void:
	for i in SECTIONS.size():
		var section_info: Array = SECTIONS[i]
		var label: String       = section_info[0]
		var icon: String        = section_info[1]
		var scene_key: String   = section_info[2]

		var btn := Button.new()
		btn.text = "%s  %s" % [icon, label]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Normal style
		var style := StyleBoxFlat.new()
		style.bg_color = SECTION_COLORS[i]
		style.corner_radius_top_left     = 16
		style.corner_radius_top_right    = 16
		style.corner_radius_bottom_left  = 16
		style.corner_radius_bottom_right = 16
		style.border_width_left = 5
		style.border_color      = SECTION_ACCENT_COLORS[i]
		btn.add_theme_stylebox_override("normal", style)

		# Hover style
		var hover_style := style.duplicate()
		hover_style.bg_color = SECTION_ACCENT_COLORS[i].lightened(0.75)
		btn.add_theme_stylebox_override("hover", hover_style)

		# Apply font to button
		if font_regular != null:
			btn.add_theme_font_override("font", font_regular)
		
		# Set font size (adjust as needed)
		btn.add_theme_font_size_override("font_size", 60)
		btn.add_theme_color_override("font_color", Color("#1E293B"))

		btn.pressed.connect(_on_section_pressed.bind(scene_key))
		sections_container.add_child(btn)


func _on_section_pressed(scene_key: String) -> void:
	if scene_key == "VOCAB":
		Global.flashcard_mode = "lesson"
	
	var scene_map := {
		"VOCAB":        SCENE_VOCAB,
		"CONVERSATION": SCENE_CONVERSATION,
		"READING":      SCENE_READING,
		"GRAMMAR":      SCENE_GRAMMAR,
		"SPEAKING":     SCENE_SPEAKING,
	}
	var path: String = scene_map.get(scene_key, "")
	if path == "":
		push_error("No scene path for key: " + scene_key)
		return
	
	TransitionManager.change_scene(path)


func _on_back_button_pressed() -> void:
	TransitionManager.change_scene(SCENE_BOOK_MENU)
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
