extends Control

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
const SCENE_SPEAKING     := "res://scenes/speaking/Speaking.tscn"

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

@onready var back_button: Button              = $MainLayout/InnerLayout/TopBar/BackButton
@onready var top_bar_title: Label             = $MainLayout/InnerLayout/TopBar/TopBarTitle
@onready var lesson_subtitle: Label           = $MainLayout/InnerLayout/LessonSubtitle
@onready var sections_container: VBoxContainer = $MainLayout/InnerLayout/SectionsContainer


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson

	top_bar_title.text  = "Vision %d  —  Lesson %d" % [book, lesson]
	lesson_subtitle.text = _get_lesson_title(book, lesson)

	_build_section_buttons()

	# Tell Global we were here so Continue Learning works
	Global.set_last_scene(
		get_tree().current_scene.scene_file_path
	)


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

		btn.add_theme_font_size_override("font_size", 20)
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
	get_tree().change_scene_to_file(path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(SCENE_BOOK_MENU)
