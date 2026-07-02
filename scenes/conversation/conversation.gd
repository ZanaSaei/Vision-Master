extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  CONVERSATION SCENE
#  Loads from res://data/v{book}_conversations.json
#  Reads Global.current_book + Global.current_lesson
#  Shows: image, intro, dialogue lines, discussion questions
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Speaker colors
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
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_JAKARTA_MEDIUM_PATH := "res://assets/fonts/PlusJakartaSans-Medium.ttf" 

# Preload fonts for better performance
var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile

# Existing Node References
@onready var back_button: Button           = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label           = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button          = $HeaderBar/HeaderContent/AudioButton
@onready var conversation_image: TextureRect = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ConversationImage
@onready var intro_label: Label            = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/IntroLabel
@onready var lines_container: VBoxContainer  = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/LinesContainer
@onready var questions_section: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection
@onready var questions_container: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection/QuestionsContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Audio Control References
@onready var audio_control_panel: PanelContainer = $AudioControlPanel
@onready var audio_slider: HSlider = $AudioControlPanel/MarginContainer/AudioUILayout/AudioSlider
@onready var rewind_button: Button = $AudioControlPanel/MarginContainer/AudioUILayout/ControlsLayout/RewindButton
@onready var play_pause_button: Button = $AudioControlPanel/MarginContainer/AudioUILayout/ControlsLayout/PlayPauseButton
@onready var forward_button: Button = $AudioControlPanel/MarginContainer/AudioUILayout/ControlsLayout/ForwardButton
@onready var close_audio_button: Button = $AudioControlPanel/MarginContainer/AudioUILayout/ControlsLayout/CloseAudioButton

# Audio state variables
const SEEK_STEP: float = 10.0 
var is_dragging_slider: bool = false

func _ready() -> void:
	audio_button.pivot_offset = audio_button.size / 2.0
	back_button.pivot_offset = back_button.size / 2.0
	_load_fonts()
	_apply_fonts_to_existing_labels()
	
	# Connect existing buttons
	back_button.pressed.connect(_on_back_button_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	
	# Connect audio control buttons
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	close_audio_button.pressed.connect(_on_close_audio_pressed)
	
	# Connect slider signals
	audio_slider.drag_started.connect(_on_slider_drag_started)
	audio_slider.drag_ended.connect(_on_slider_drag_ended)

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson

	header_title.text = "Lesson %d\nConversation" % [lesson]

	var data: Dictionary = _load_conversation(book, lesson)
	if data.is_empty():
		intro_label.text = "Conversation not available yet."
		return

	_build_conversation(book, lesson, data)


func _process(_delta: float) -> void:
	# Keep the slider synced with the audio playback, even if paused
	if (audio_player.playing or audio_player.stream_paused) and not is_dragging_slider:
		audio_slider.value = audio_player.get_playback_position()


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold = load(FONT_JAKARTA_BOLD_PATH)
	font_italic = load(FONT_JAKARTA_ITALIC_PATH)
	
	if font_regular == null: push_warning("Regular font not found")
	if font_bold == null: push_warning("Bold font not found")
	if font_italic == null: push_warning("Italic font not found")


func _apply_fonts_to_existing_labels() -> void:
	if font_regular != null: intro_label.add_theme_font_override("font", font_regular)
	if font_bold != null: header_title.add_theme_font_override("font", font_bold)


func _load_conversation(book: int, lesson: int) -> Dictionary:
	var path := "res://data/v%d_conversations.json" % book
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text  := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK: return {}
	return json.data.get("lessons", {}).get(str(lesson), {})


func _build_conversation(book: int, lesson: int, data: Dictionary) -> void:
	var image_path := "res://assets/images/%s" % data.get("image", "")
	if ResourceLoader.exists(image_path):
		conversation_image.texture = load(image_path)
		conversation_image.visible = true
	else:
		conversation_image.visible = false

	intro_label.text = data.get("intro", "")
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_regular != null: intro_label.add_theme_font_override("font", font_regular)

	_build_lines(data.get("lines", []))

	var questions: Array = data.get("questions", [])
	if questions.is_empty():
		questions_section.visible = false
	else:
		questions_section.visible = true
		_build_questions(questions)

	var audio_filename: String = data.get("audio", "conversation.mp3")
	set_meta("audio_path", Global.get_audio_path(book, lesson, audio_filename))


func _build_lines(lines: Array) -> void:
	for child in lines_container.get_children():
		child.queue_free()

	var speaker_map: Dictionary = {}
	var color_counter: int = 0
	for line in lines:
		var speaker: String = line.get("speaker", "")
		if speaker != "" and not speaker_map.has(speaker):
			speaker_map[speaker] = color_counter % SPEAKER_COLORS.size()
			color_counter += 1

	for line in lines:
		var speaker: String = line.get("speaker", "")
		var text: String    = line.get("text", "")
		var color_idx: int  = speaker_map.get(speaker, 0)
		lines_container.add_child(_make_line_card(speaker, text, color_idx))


func _make_line_card(speaker: String, text: String, color_idx: int) -> PanelContainer:
	var accent_color: Color = SPEAKER_COLORS[color_idx]
	var bg_color: Color     = SPEAKER_BG_COLORS[color_idx]

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color                  = bg_color
	card_style.corner_radius_top_left    = 12
	card_style.corner_radius_top_right   = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.border_width_left         = 4
	card_style.border_color              = accent_color
	card.add_theme_stylebox_override("panel", card_style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS

	var speaker_label := Label.new()
	speaker_label.mouse_filter = Control.MOUSE_FILTER_PASS
	speaker_label.text = speaker
	speaker_label.add_theme_font_size_override("font_size", 40)
	speaker_label.add_theme_color_override("font_color", accent_color)
	if font_bold != null: speaker_label.add_theme_font_override("font", font_bold)

	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 45)
	text_label.add_theme_color_override("font_color", Color("#1E293B"))
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if font_regular != null: text_label.add_theme_font_override("font", font_regular)

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
		row.mouse_filter = Control.MOUSE_FILTER_PASS

		var number := Label.new()
		number.text = "%d." % (i + 1)
		number.add_theme_font_size_override("font_size", 35)
		number.add_theme_color_override("font_color", Color("#2563EB"))
		number.custom_minimum_size = Vector2(28, 0)
		number.mouse_filter = Control.MOUSE_FILTER_PASS
		if font_bold != null: number.add_theme_font_override("font", font_bold)

		var q_label := Label.new()
		q_label.text = q
		q_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		q_label.add_theme_font_size_override("font_size", 45)
		q_label.add_theme_color_override("font_color", Color("#1E293B"))
		q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q_label.mouse_filter = Control.MOUSE_FILTER_PASS
		if font_regular != null: q_label.add_theme_font_override("font", font_regular)

		row.add_child(number)
		row.add_child(q_label)
		questions_container.add_child(row)

# ============================================================
# AUDIO CONTROL FUNCTIONS
# ============================================================

func _on_audio_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(audio_button, "scale", Vector2(0.93, 0.93), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	audio_control_panel.show()
	
	# Only initialize and start playing if completely stopped (not playing AND not paused)
	if not audio_player.playing and not audio_player.stream_paused:
		var path: String = get_meta("audio_path", "")
		if path == "": return
		
		if ResourceLoader.exists(path):
			audio_player.stream = load(path)
			audio_player.play()
			audio_player.stream_paused = false
			play_pause_button.text = "Pause"
			
			# Setup slider constraints
			audio_slider.max_value = audio_player.stream.get_length()
			audio_slider.value = 0.0
		else:
			push_warning("Conversation audio not found: " + path)


func _on_play_pause_pressed() -> void:
	if audio_player.stream == null:
		_on_audio_pressed()
		return

	if audio_player.stream_paused:
		# It was paused, so resume
		audio_player.stream_paused = false
		play_pause_button.text = "Pause"
		
		# Fallback: if 'playing' dropped to false internally, force it to play from the slider's current position
		if not audio_player.playing:
			audio_player.play(audio_slider.value)
			
	elif audio_player.playing:
		# It is currently playing, so pause
		audio_player.stream_paused = true
		play_pause_button.text = "Play"
		
	else:
		# Audio fully finished or was completely stopped; restart it
		_on_audio_pressed()


func _on_rewind_pressed() -> void:
	if audio_player.stream != null:
		var current_pos = audio_player.get_playback_position()
		audio_player.seek(max(0.0, current_pos - SEEK_STEP))
		audio_slider.value = audio_player.get_playback_position()


func _on_forward_pressed() -> void:
	if audio_player.stream != null:
		var current_pos = audio_player.get_playback_position()
		var max_length = audio_player.stream.get_length()
		audio_player.seek(min(max_length, current_pos + SEEK_STEP))
		audio_slider.value = audio_player.get_playback_position()


func _on_close_audio_pressed() -> void:
	audio_player.stop()
	audio_player.stream_paused = false
	audio_control_panel.hide()
	audio_slider.value = 0.0

# --- Slider Draggable Signals ---

func _on_slider_drag_started() -> void:
	is_dragging_slider = true

func _on_slider_drag_ended(value_changed: bool) -> void:
	is_dragging_slider = false
	if audio_player.stream != null:
		audio_player.seek(audio_slider.value)

# ============================================================

func _on_back_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
