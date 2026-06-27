extends Control

# ============================================================
#  CONVERSATION SCENE
#  Loads from res://data/v{book}_conversations.json
#  Reads Global.current_book + Global.current_lesson
#  Shows: image, intro, dialogue lines, discussion questions
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Speaker colors — first speaker gets color A, second gets color B,
# any third speaker gets color C. Assigned dynamically per conversation.
const SPEAKER_COLORS := [
	Color("#2563EB"),  # blue
	Color("#16A34A"),  # green
	Color("#9333EA"),  # purple
	Color("#EA580C"),  # orange
]
const SPEAKER_BG_COLORS := [
	Color("#EFF6FF"),
	Color("#F0FDF4"),
	Color("#FDF4FF"),
	Color("#FFF7ED"),
]

# ---------- Font configuration ----------
# Change these paths to your actual font files
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_JAKARTA_MEDIUM_PATH := "res://assets/fonts/PlusJakartaSans-Medium.ttf" 

# Preload fonts for better performance
var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile

@onready var back_button: Button           = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label           = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button          = $HeaderBar/HeaderContent/AudioButton
@onready var conversation_image: TextureRect = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ConversationImage
@onready var intro_label: Label            = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/IntroLabel
@onready var lines_container: VBoxContainer  = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/LinesContainer
@onready var questions_section: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection
@onready var questions_container: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection/QuestionsContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer


func _ready() -> void:
	# Load fonts
	_load_fonts()
	
	# Apply fonts to existing labels
	_apply_fonts_to_existing_labels()
	
	back_button.pressed.connect(_on_back_pressed)
	audio_button.pressed.connect(_on_audio_pressed)

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson

	header_title.text = "Lesson %d\nConversation" % [lesson]

	var data: Dictionary = _load_conversation(book, lesson)
	if data.is_empty():
		intro_label.text = "Conversation not available yet."
		return

	_build_conversation(book, lesson, data)


func _load_fonts() -> void:
	# Load fonts with error handling
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold = load(FONT_JAKARTA_BOLD_PATH)
	font_italic = load(FONT_JAKARTA_ITALIC_PATH)
	
	if font_regular == null:
		push_warning("Regular font not found at: " + FONT_JAKARTA_REGULAR_PATH)
		# Fallback to default system font - we'll use a default size instead
		
	if font_bold == null:
		push_warning("Bold font not found at: " + FONT_JAKARTA_BOLD_PATH)
		
	if font_italic == null:
		push_warning("Italic font not found at: " + FONT_JAKARTA_ITALIC_PATH)


func _apply_fonts_to_existing_labels() -> void:
	# Apply to intro label
	if font_regular != null:
		intro_label.add_theme_font_override("font", font_regular)
	
	# Apply to header title
	if font_bold != null:
		header_title.add_theme_font_override("font", font_bold)


func _load_conversation(book: int, lesson: int) -> Dictionary:
	var path := "res://data/v%d_conversations.json" % book

	if not FileAccess.file_exists(path):
		push_error("Conversation file not found: " + path)
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


func _build_conversation(book: int, lesson: int, data: Dictionary) -> void:
	# --- Image ---
	var image_path := "res://assets/images/%s" % data.get("image", "")
	if ResourceLoader.exists(image_path):
		conversation_image.texture = load(image_path)
		conversation_image.visible = true
	else:
		# No image yet — hide the slot cleanly
		conversation_image.visible = false

	# --- Intro ---
	intro_label.text = data.get("intro", "")
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Apply font to intro (in case it was reset)
	if font_regular != null:
		intro_label.add_theme_font_override("font", font_regular)

	# --- Dialogue lines ---
	var lines: Array = data.get("lines", [])
	_build_lines(lines)

	# --- Discussion questions ---
	var questions: Array = data.get("questions", [])
	if questions.is_empty():
		questions_section.visible = false
	else:
		questions_section.visible = true
		_build_questions(questions)

	# --- Store audio path for play button ---
	# We keep this as a variable so _on_audio_pressed can use it
	var audio_filename: String = data.get("audio", "conversation.mp3")
	set_meta("audio_path", Global.get_audio_path(book, lesson, audio_filename))


func _build_lines(lines: Array) -> void:
	# Clear any previous content
	for child in lines_container.get_children():
		child.queue_free()

	# Build a speaker → color index map so each speaker
	# consistently gets the same color throughout the conversation
	var speaker_map: Dictionary = {}
	var color_counter: int = 0
	for line in lines:
		var speaker: String = line.get("speaker", "")
		if speaker != "" and not speaker_map.has(speaker):
			speaker_map[speaker] = color_counter % SPEAKER_COLORS.size()
			color_counter += 1

	# Build each line as a styled card
	for line in lines:
		var speaker: String = line.get("speaker", "")
		var text: String    = line.get("text", "")
		var color_idx: int  = speaker_map.get(speaker, 0)

		var card := _make_line_card(speaker, text, color_idx)
		lines_container.add_child(card)


func _make_line_card(speaker: String, text: String, color_idx: int) -> PanelContainer:
	var accent_color: Color = SPEAKER_COLORS[color_idx]
	var bg_color: Color     = SPEAKER_BG_COLORS[color_idx]

	# Outer card
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color                  = bg_color
	card_style.corner_radius_top_left    = 12
	card_style.corner_radius_top_right   = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.border_width_left         = 4
	card_style.border_color              = accent_color
	card.add_theme_stylebox_override("panel", card_style)

	# Inner layout
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	# Speaker name label
	var speaker_label := Label.new()
	speaker_label.text = speaker
	speaker_label.add_theme_font_size_override("font_size", 40)
	speaker_label.add_theme_color_override("font_color", accent_color)
	
	# Apply bold font to speaker name
	if font_bold != null:
		speaker_label.add_theme_font_override("font", font_bold)

	# Dialogue text label
	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 45)
	text_label.add_theme_color_override("font_color", Color("#1E293B"))
	
	# Apply regular font to dialogue text
	if font_regular != null:
		text_label.add_theme_font_override("font", font_regular)

	inner.add_child(speaker_label)
	inner.add_child(text_label)
	card.add_child(inner)

	return card


func _build_questions(questions: Array) -> void:
	for child in questions_container.get_children():
		child.queue_free()

	for i in questions.size():
		var q: String = questions[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 35)

		var number := Label.new()
		number.text = "%d." % (i + 1)
		number.add_theme_font_size_override("font_size", 35)
		number.add_theme_color_override("font_color", Color("#2563EB"))
		number.custom_minimum_size = Vector2(28, 0)
		
		# Apply bold font to question number
		if font_bold != null:
			number.add_theme_font_override("font", font_bold)

		var q_label := Label.new()
		q_label.text = q
		q_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		q_label.add_theme_font_size_override("font_size", 45)
		q_label.add_theme_color_override("font_color", Color("#1E293B"))
		q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Apply regular font to question text
		if font_regular != null:
			q_label.add_theme_font_override("font", font_regular)

		row.add_child(number)
		row.add_child(q_label)
		questions_container.add_child(row)


func _on_audio_pressed() -> void:
	var path: String = get_meta("audio_path", "")
	if path == "":
		return
	if ResourceLoader.exists(path):
		audio_player.stream = load(path)
		audio_player.play()
	else:
		push_warning("Conversation audio not found: " + path)


func _on_back_pressed() -> void:
	TransitionManager.change_scene(SCENE_LESSON_MENU)
