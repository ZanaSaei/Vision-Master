extends "res://autoload/BackButtonHandler.gd"
############################################################
# LESSON MENU
# Shows the section buttons for the current book + lesson.
# Reads Global.current_book and Global.current_lesson.
# Navigation uses the SLIDE transition:
# section tap -> slide forward (content exits left)
# back tap    -> slide back    (content exits right)
# The animated background lives in the MenuBackground autoload.
############################################################

# Scene paths for all section types
const SCENE_BOOK_MENU         := "res://scenes/book_menu/BookMenu.tscn"
const SCENE_VOCAB             := "res://scenes/vocabulary/VocabFlashcards.tscn"
const SCENE_CONVERSATION      := "res://scenes/conversation/Conversation.tscn"
const SCENE_READING           := "res://scenes/reading/Reading.tscn"
const SCENE_GRAMMAR           := "res://scenes/grammar/GrammarHub.tscn"
const SCENE_VOCAB_DEVELOPMENT := "res://scenes/vocabulary_development/VocabularyDevelopment.tscn"
const SCENE_LISTENING_SPEAKING:= "res://scenes/listening_speaking/ListeningSpeaking.tscn"
const SCENE_PRONUNCIATION     := "res://scenes/pronunciation/Pronunciation.tscn"
const SCENE_WRITING           := "res://scenes/writing/Writing.tscn"
const SCENE_WHAT_YOU_LEARNED  := "res://scenes/what_you_learned/WhatYouLearned.tscn"
const SCENE_QUIZ              := "res://scenes/quiz/Quiz.tscn"
const SCENE_WORKBOOK          := "res://scenes/workbook/Workbook.tscn"

# Font paths for typography
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
var font_regular: FontFile
var font_bold: FontFile
var _navigating := false

# Lesson titles organized by book number
const LESSON_TITLES := {
	1: [ "Saving Nature ", "Wonders of Creation ",
		 "The Value of Knowledge ", "Traveling the World "],
	2: [ "Understanding People ", "A Healthy Lifestyle ", "Art and Culture "],
	3: [ "Sense of Appreciation ", "Look It Up! ", "Renewable Energy "],
}

# Section definitions for Vision 1 (no Vocabulary Development section)
const SECTIONS_VISION_1 := [
	[ "Get Ready and New Words ",  "📚 ", "VOCAB" ],
	[ "Conversation ",             "💬 ", "CONVERSATION" ],
	[ "Reading ",                  "📖 ", "READING" ],
	[ "Grammar ",                  "✏️ ", "GRAMMAR" ],
	[ "Listening and Speaking ",   "🎧 ", "LISTENING_SPEAKING" ],
	[ "Pronunciation ",            "🎙️ ", "PRONUNCIATION" ],
	[ "Writing ",                  "📝 ", "WRITING" ],
	[ "What You Learned ",         "🔄 ", "WHAT_YOU_LEARNED" ],
	[ "Workbook ",                 "📝 ", "WORKBOOK" ],
	[ "Quiz ",                     "❓ ", "QUIZ" ],
]

# Section definitions for Vision 2 and 3 (includes Vocabulary Development)
const SECTIONS_VISION_2_3 := [
	[ "Get Ready and New Words ",  "📚 ", "VOCAB" ],
	[ "Conversation ",             "💬 ", "CONVERSATION" ],
	[ "Reading ",                  "📖 ", "READING" ],
	[ "Vocabulary Development ",   "🧠 ", "VOCAB_DEVELOPMENT" ],
	[ "Grammar ",                  "✏️ ", "GRAMMAR" ],
	[ "Listening and Speaking ",   "🎧 ", "LISTENING_SPEAKING" ],
	[ "Pronunciation ",            "🎙️ ", "PRONUNCIATION" ],
	[ "Writing ",                  "📝 ", "WRITING" ],
	[ "What You Learned ",         "🔄 ", "WHAT_YOU_LEARNED" ],
	[ "Workbook ",                 "📝 ", "WORKBOOK" ],
	[ "Quiz ",                     "❓ ", "QUIZ" ],
]

# Background colors for section buttons (slightly tinted)
const SECTION_COLORS: Array[Color] = [
	Color("#EFF6FF"), Color("#F0FDF4"), Color("#FFF7ED"),
	Color("#FDF4FF"), Color("#F0FDFA"), Color("#FFF1F2"),
	Color("#F5F3FF"), Color("#FFFBEB"), Color("#F1F5F9"),
	Color("#ECFEFF"),
]

# Accent colors for the glossy shine and border comet effects
const SECTION_ACCENT_COLORS: Array[Color] = [
	Color("#2563EB"), Color("#16A34A"), Color("#EA580C"),
	Color("#9333EA"), Color("#0D9488"), Color("#E11D48"),
	Color("#7C3AED"), Color("#D97706"), Color("#475569"),
	Color("#0891B2"),
]

# UI element references
@onready var back_button: Button               = $PanelContainer/TopBar/BackButton
@onready var top_bar_title: Label              = $PanelContainer/TopBar/TopBarTitle
@onready var lesson_subtitle: Label            = $MainLayout/InnerLayout/LessonSubtitle
@onready var sections_container: VBoxContainer = $MainLayout/InnerLayout/SectionsContainer

# Glossy + border-comet state
const CORNER_RADIUS := 26.0
var _section_mats: Array[ShaderMaterial] = []
var _section_btns: Array[Button]         = []

func _ready() -> void:
	# Remove old AnimatedBackground if it exists in this scene
	var legacy_bg := get_node_or_null("AnimatedBackground")
	if legacy_bg:
		legacy_bg.visible = false
		legacy_bg.queue_free()

	# Set pivot for scale animations
	back_button.pivot_offset = back_button.size / 2.0

	# Load fonts and apply to UI
	_load_fonts()
	_apply_fonts_to_labels()
	back_button.pressed.connect(_on_back_button_pressed)

	# Set up lesson information from global state
	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson
	top_bar_title.text   = "Lesson %d" % [lesson]
	lesson_subtitle.text = _get_lesson_title(book, lesson)
	_build_section_buttons(book)

	# Save current scene for back navigation
	Global.set_last_scene(get_tree().current_scene.scene_file_path)

	# Allow layout to settle before setting shader sizes
	_finalize_shine_sizes()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	# Lesson subtitle: keep the current black text in dark mode, use the
	# palette text color in light mode.
	lesson_subtitle.add_theme_color_override(
		"font_color",
		Color(0, 0, 0, 1) if Global.theme_is_dark() else Global.get_theme_color("text")
	)


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()


func _load_fonts() -> void:
	# Load custom fonts from assets
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold    = load(FONT_JAKARTA_BOLD_PATH)
	if font_regular == null:
		push_warning("Regular font not found at: " + FONT_JAKARTA_REGULAR_PATH)
	if font_bold == null:
		push_warning("Bold font not found at: " + FONT_JAKARTA_BOLD_PATH)

func _apply_fonts_to_labels() -> void:
	# Apply loaded fonts to title and subtitle labels
	if font_bold != null:
		top_bar_title.add_theme_font_override("font", font_bold)
	if font_regular != null:
		lesson_subtitle.add_theme_font_override("font", font_regular)

func _get_lesson_title(book: int, lesson: int) -> String:
	# Get the title for a specific lesson in a book
	var titles: Array = LESSON_TITLES.get(book, [])
	if lesson - 1 < titles.size():
		return titles[lesson - 1]
	return ""

func _apply_glossy_style(btn: Button, accent: Color) -> void:
	# Apply a glossy glass-morphism style to the button
	if btn.pivot_offset == Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0

	# Calculate style colors based on accent
	var fill := Color(accent.r, accent.g, accent.b, 0.34)
	var rim: Color = accent.lerp(Color.WHITE, 0.55)
	rim.a = 0.75
	var glow := Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.55)

	# Normal state style
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(CORNER_RADIUS))
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color  = rim
	style.shadow_color  = glow
	style.shadow_size   = 16
	style.shadow_offset = Vector2(0, 6)
	btn.add_theme_stylebox_override("normal", style)

	# Hover state - brighter, larger shadow
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color    = Color(accent.r, accent.g, accent.b, 0.50)
	hover_style.shadow_size = 22
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed state - darker, smaller shadow
	var press_style := style.duplicate() as StyleBoxFlat
	press_style.bg_color      = Color(accent.r, accent.g, accent.b, 0.24)
	press_style.shadow_size   = 8
	press_style.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("pressed", press_style)

	# Focus state - bright border
	var focus_style := hover_style.duplicate() as StyleBoxFlat
	focus_style.border_color = accent.lerp(Color.WHITE, 0.8)
	focus_style.border_color.a = 0.9
	btn.add_theme_stylebox_override("focus", focus_style)


func _set_btn_border_size(mat: ShaderMaterial, btn: Button) -> void:
	# Update shader with current button size
	var rs := btn.size
	if rs.x < 1.0 or rs.y < 1.0:
		rs = Vector2(600.0, 150.0)
	mat.set_shader_parameter("rect_size", rs)

func _finalize_shine_sizes() -> void:
	# Wait for layout to complete, then update all shader sizes
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(_section_mats.size()):
		_set_btn_border_size(_section_mats[i], _section_btns[i])

func _build_section_buttons(book: int) -> void:
	# Build section buttons based on the current book version
	var sections: Array
	if book == 1:
		sections = SECTIONS_VISION_1
	else:
		sections = SECTIONS_VISION_2_3

	for i in sections.size():
		# Extract section data
		var section_info: Array = sections[i]
		var label: String    = section_info[0]
		var icon: String     = section_info[1]
		var scene_key: String = section_info[2]
		var accent: Color    = SECTION_ACCENT_COLORS[i % SECTION_ACCENT_COLORS.size()]

		# Create and configure the button
		var btn := Button.new()
		btn.text = "%s  %s" % [icon, label]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Apply glossy glass fill style
		_apply_glossy_style(btn, accent)

		# Configure typography
		if font_regular != null:
			btn.add_theme_font_override("font", font_regular)
		btn.add_theme_font_size_override("font_size", 60)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		btn.add_theme_constant_override("outline_size", 2)

		# Connect button signals
		btn.pressed.connect(_on_section_pressed.bind(scene_key))
		sections_container.add_child(btn)

		# Connect hover/press micro-interaction signals
		btn.mouse_entered.connect(_on_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_hover.bind(btn, false))
		btn.button_down.connect(_on_press.bind(btn))
		btn.button_up.connect(_on_release.bind(btn))

func _on_hover(btn: Button, hovering: bool) -> void:
	# Scale button slightly on hover for visual feedback
	var s := 1.03 if hovering else 1.0
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(s, s), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_press(btn: Button) -> void:
	# Scale button down when pressed
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_release(btn: Button) -> void:
	# Scale button back to normal when released
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_section_pressed(scene_key: String) -> void:
	# Navigate to the appropriate scene when a section is pressed
	if _navigating:
		return
	_navigating = true
	Global.set_last_scene(get_tree().current_scene.scene_file_path)
	
	# Set flashcard mode for vocabulary sections
	if scene_key == "VOCAB":
		Global.flashcard_mode = "lesson"
	
	# Map section keys to scene paths
	var scene_map := {
		"VOCAB": SCENE_VOCAB,
		"CONVERSATION": SCENE_CONVERSATION,
		"READING": SCENE_READING,
		"VOCAB_DEVELOPMENT": SCENE_VOCAB_DEVELOPMENT,
		"GRAMMAR": SCENE_GRAMMAR,
		"LISTENING_SPEAKING": SCENE_LISTENING_SPEAKING,
		"PRONUNCIATION": SCENE_PRONUNCIATION,
		"WRITING": SCENE_WRITING,
		"WHAT_YOU_LEARNED": SCENE_WHAT_YOU_LEARNED,
		"WORKBOOK": SCENE_WORKBOOK,
		"QUIZ": SCENE_QUIZ,
	}
	
	var path: String = scene_map.get(scene_key, "")
	if path == "":
		push_error("No scene path for key: " + scene_key)
		_navigating = false
		return

	# Grammar is part of the main menu flow (book -> lesson -> grammar), so
	# it slides FORWARD exactly like book-menu -> lesson-menu does. The other
	# drill-downs keep the fade transition.
	if scene_key == "GRAMMAR":
		TransitionManager.slide_change_scene(path, TransitionManager.Slide.FORWARD)
	else:
		TransitionManager.change_scene(path)

func _on_back_button_pressed() -> void:
	# Navigate back to book menu with slide animation
	if _navigating:
		return
	_navigating = true
	var tween := create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	await tween.finished
	TransitionManager.slide_change_scene(SCENE_BOOK_MENU, TransitionManager.Slide.BACK)

func _on_android_back_pressed() -> void:
	# Handle Android back button press
	_on_back_button_pressed()
