extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  READING SCENE
#  Loads from res://data/v{book}_readings.json
#  Reads Global.current_book + Global.current_lesson
#  Shows: image, reading title, paragraphs, comprehension questions
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Paragraph accent color
const PARA_BG_COLOR     := Color("#F8FAFC")
const PARA_BORDER_COLOR := Color("#2563EB")

const BACKGROUND_OPACITY := 0.15

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile

# Existing Node References
@onready var back_button: Button              = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label              = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button             = $HeaderBar/HeaderContent/AudioButton
@onready var background_image: TextureRect    = $BackgroundImage
@onready var reading_image: TextureRect       = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ReadingImage
@onready var reading_title_label: Label       = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ReadingTitleLabel
@onready var paragraphs_container: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ParagraphsContainer
@onready var questions_section: VBoxContainer    = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection
@onready var questions_container: VBoxContainer  = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection/QuestionsContainer
@onready var audio_player: AudioStreamPlayer  = $AudioPlayer

# NEW Audio Control References
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
	_load_fonts()
	_apply_fonts_to_existing_labels()

	_configure_main_image()
	_configure_background_image()

	# Existing Connections
	back_button.pressed.connect(_on_back_button_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	
	# NEW Audio Connections
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	close_audio_button.pressed.connect(_on_close_audio_pressed)
	audio_slider.drag_started.connect(_on_slider_drag_started)
	audio_slider.drag_ended.connect(_on_slider_drag_ended)

	var book: int   = Global.current_book
	var lesson: int = Global.current_lesson

	header_title.text = "Lesson %d\nReading" % lesson

	var data: Dictionary = _load_reading(book, lesson)
	if data.is_empty():
		reading_title_label.text = "Reading not available yet."
		return

	_build_reading(book, lesson, data)


func _process(_delta: float) -> void:
	# Keep the slider synced with the audio playback, even if paused
	if (audio_player.playing or audio_player.stream_paused) and not is_dragging_slider:
		audio_slider.value = audio_player.get_playback_position()


func _configure_main_image() -> void:
	reading_image.expand = true
	reading_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reading_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading_image.custom_minimum_size = Vector2(0, 1000)


func _configure_background_image() -> void:
	background_image.expand = true
	background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_image.modulate = Color(1, 1, 1, BACKGROUND_OPACITY)
	background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	background_image.anchor_left = 0.0
	background_image.anchor_top = 0.0
	background_image.anchor_right = 1.0
	background_image.anchor_bottom = 1.0
	background_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background_image.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold    = load(FONT_JAKARTA_BOLD_PATH)
	font_italic  = load(FONT_JAKARTA_ITALIC_PATH)

	if font_regular == null: push_warning("Regular font not found")
	if font_bold == null: push_warning("Bold font not found")
	if font_italic == null: push_warning("Italic font not found")


func _apply_fonts_to_existing_labels() -> void:
	if font_bold != null:
		header_title.add_theme_font_override("font", font_bold)
		reading_title_label.add_theme_font_override("font", font_bold)


func _load_reading(book: int, lesson: int) -> Dictionary:
	var path := "res://data/v%d_readings.json" % book
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text  := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK: return {}

	return json.data.get("lessons", {}).get(str(lesson), {})


func _build_reading(book: int, lesson: int, data: Dictionary) -> void:
	var image_filename: String = data.get("image", "")
	
	if image_filename != "":
		var bg_path := "res://assets/images/%s" % image_filename
		if ResourceLoader.exists(bg_path):
			background_image.texture = load(bg_path)
			background_image.visible = true
		else:
			background_image.visible = false
			
		var main_path := "res://assets/images/%s" % image_filename
		if ResourceLoader.exists(main_path):
			reading_image.texture = load(main_path)
			reading_image.visible = true
		else:
			reading_image.visible = false

	reading_title_label.text = data.get("title", "")

	var paragraphs: Array = data.get("paragraphs", [])
	_build_paragraphs(paragraphs)

	var questions: Array = data.get("questions", [])
	if questions.is_empty():
		questions_section.visible = false
	else:
		questions_section.visible = true
		_build_questions(questions)

	var audio_filename: String = data.get("audio", "reading.mp3")
	set_meta("audio_path", Global.get_audio_path(book, lesson, audio_filename))


func _build_paragraphs(paragraphs: Array) -> void:
	for child in paragraphs_container.get_children():
		child.queue_free()

	for i in paragraphs.size():
		var para_text: String = paragraphs[i]
		var card := _make_paragraph_card(i + 1, para_text)
		paragraphs_container.add_child(card)


func _make_paragraph_card(_number: int, text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color                   = PARA_BG_COLOR
	card_style.corner_radius_top_left     = 12
	card_style.corner_radius_top_right    = 12
	card_style.corner_radius_bottom_left  = 12
	card_style.corner_radius_bottom_right = 12
	card_style.border_width_left          = 4
	card_style.border_color               = PARA_BORDER_COLOR
	card_style.content_margin_left        = 16
	card_style.content_margin_right       = 16
	card_style.content_margin_top         = 14
	card_style.content_margin_bottom      = 14
	card.add_theme_stylebox_override("panel", card_style)

	card_style.bg_color.a = 0.85  # 85% opacity

	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 55)
	text_label.add_theme_color_override("font_color", Color("#1E293B"))
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if font_regular != null:
		text_label.add_theme_font_override("font", font_regular)

	card.add_child(text_label)
	return card


func _build_questions(questions: Array) -> void:
	for child in questions_container.get_children():
		child.queue_free()

	for i in questions.size():
		var q: String = questions[i]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 35)

		var number := Label.new()
		number.text = "%d." % (i + 1)
		number.add_theme_font_size_override("font_size", 35)
		number.add_theme_color_override("font_color", Color("#2563EB"))
		number.custom_minimum_size = Vector2(28, 0)
		if font_bold != null: number.add_theme_font_override("font", font_bold)

		var q_label := Label.new()
		q_label.text = q
		q_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		q_label.add_theme_font_size_override("font_size", 55)
		q_label.add_theme_color_override("font_color", Color("#1E293B"))
		q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font_regular != null: q_label.add_theme_font_override("font", font_regular)

		row.add_child(number)
		row.add_child(q_label)
		questions_container.add_child(row)

# ============================================================
# NEW AUDIO CONTROL FUNCTIONS
# ============================================================

func _on_audio_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(audio_button, "scale", Vector2(0.93, 0.93), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	audio_control_panel.show()
	
	# Only initialize and start playing if completely stopped
	if not audio_player.playing and not audio_player.stream_paused:
		var path: String = get_meta("audio_path", "")
		if path == "": return
		
		if ResourceLoader.exists(path):
			audio_player.stream = load(path)
			audio_player.play()
			audio_player.stream_paused = false
			play_pause_button.text = "Pause"
			
			audio_slider.max_value = audio_player.stream.get_length()
			audio_slider.value = 0.0
		else:
			push_warning("Reading audio not found: " + path)


func _on_play_pause_pressed() -> void:
	if audio_player.stream == null:
		_on_audio_pressed()
		return

	if audio_player.stream_paused:
		audio_player.stream_paused = false
		play_pause_button.text = "Pause"
		
		# Fallback: force it to play from the slider's current position if needed
		if not audio_player.playing:
			audio_player.play(audio_slider.value)
			
	elif audio_player.playing:
		audio_player.stream_paused = true
		play_pause_button.text = "Play"
	else:
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


func _on_slider_drag_started() -> void:
	is_dragging_slider = true


func _on_slider_drag_ended(value_changed: bool) -> void:
	is_dragging_slider = false
	if audio_player.stream != null:
		audio_player.seek(audio_slider.value)

# ============================================================

func _on_back_button_pressed() -> void:
	# Stop audio and hide/reset the popup before leaving the scene
	_on_close_audio_pressed()
	TransitionManager.change_scene(SCENE_LESSON_MENU)
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
