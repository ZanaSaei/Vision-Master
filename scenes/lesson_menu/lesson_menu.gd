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
const SCENE_VOCAB_DEVELOPMENT := "res://scenes/vocabulary_development/VocabularyDevelopment.tscn"
const SCENE_LISTENING_SPEAKING := "res://scenes/listening_speaking/ListeningSpeaking.tscn"
const SCENE_PRONUNCIATION := "res://scenes/pronunciation/Pronunciation.tscn"
const SCENE_WRITING := "res://scenes/writing/Writing.tscn"
const SCENE_REVIEW := "res://scenes/review/Review.tscn"
const SCENE_QUIZ := "res://scenes/quiz/Quiz.tscn"


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
const SECTIONS_VISION_1 := [
	["Get Ready and New Words", "📚", "VOCAB"],
	["Conversation",             "💬", "CONVERSATION"],
	["Reading",                  "📖", "READING"],
	["Grammar",                  "✏️", "GRAMMAR"],
	["Listening and Speaking",   "🎧", "LISTENING_SPEAKING"],
	["Pronunciation",            "🎙️", "PRONUNCIATION"],
	["Writing",                  "📝", "WRITING"],
	["Review",                   "🔄", "REVIEW"],
	["Quiz",                     "❓", "QUIZ"],
]

const SECTIONS_VISION_2_3 := [
	["Get Ready and New Words", "📚", "VOCAB"],
	["Conversation",             "💬", "CONVERSATION"],
	["Reading",                  "📖", "READING"],
	["Vocabulary Development",   "🧠", "VOCAB_DEVELOPMENT"],
	["Grammar",                  "✏️", "GRAMMAR"],
	["Listening and Speaking",   "🎧", "LISTENING_SPEAKING"],
	["Pronunciation",            "🎙️", "PRONUNCIATION"],
	["Writing",                  "📝", "WRITING"],
	["Review",                   "🔄", "REVIEW"],
	["Quiz",                     "❓", "QUIZ"],
]

# Soft background colors cycling through sections
const SECTION_COLORS: Array[Color] = [
	Color("#EFF6FF"),
	Color("#F0FDF4"),
	Color("#FFF7ED"),
	Color("#FDF4FF"),
	Color("#F0FDFA"),
	Color("#FFF1F2"),
	Color("#F5F3FF"),
	Color("#FFFBEB"),
	Color("#F1F5F9"),
	Color("#ECFEFF"),
]

const SECTION_ACCENT_COLORS: Array[Color] = [
	Color("#2563EB"),
	Color("#16A34A"),
	Color("#EA580C"),
	Color("#9333EA"),
	Color("#0D9488"),
	Color("#E11D48"),
	Color("#7C3AED"),
	Color("#D97706"),
	Color("#475569"),
	Color("#0891B2"),
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

	_build_section_buttons(book)

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


func _build_section_buttons(book: int) -> void:
	var sections: Array

	if book == 1:
		sections = SECTIONS_VISION_1
	else:
		sections = SECTIONS_VISION_2_3

	for i in sections.size():
		# Fix: Access the specific section at index i, not the entire array
		var section_info: Array = sections[i]  # Changed from 'sections' to 'sections[i]'
		var label: String = section_info[0]
		var icon: String = section_info[1]
		var scene_key: String = section_info[2]

		var btn := Button.new()
		btn.text = "%s  %s" % [icon, label]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var style := StyleBoxFlat.new()
		style.bg_color = SECTION_COLORS[i % SECTION_COLORS.size()]
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		style.border_width_left = 5
		style.border_color = SECTION_ACCENT_COLORS[i % SECTION_ACCENT_COLORS.size()]

		btn.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate()
		hover_style.bg_color = SECTION_ACCENT_COLORS[i % SECTION_ACCENT_COLORS.size()].lightened(0.75)
		btn.add_theme_stylebox_override("hover", hover_style)

		if font_regular != null:
			btn.add_theme_font_override("font", font_regular)

		btn.add_theme_font_size_override("font_size", 60)
		btn.add_theme_color_override("font_color", Color("#1E293B"))

		btn.pressed.connect(_on_section_pressed.bind(scene_key))
		sections_container.add_child(btn)

func _on_section_pressed(scene_key: String) -> void:
	if scene_key == "VOCAB":
		Global.flashcard_mode = "lesson"

	var scene_map := {
		"VOCAB": SCENE_VOCAB,
		"CONVERSATION": SCENE_CONVERSATION,
		"READING": SCENE_READING,
		"VOCAB_DEVELOPMENT": SCENE_VOCAB_DEVELOPMENT,
		"GRAMMAR": SCENE_GRAMMAR,
		"LISTENING_SPEAKING": SCENE_LISTENING_SPEAKING,
		"PRONUNCIATION": SCENE_PRONUNCIATION,
		"WRITING": SCENE_WRITING,
		"REVIEW": SCENE_REVIEW,
		"QUIZ": SCENE_QUIZ,
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
