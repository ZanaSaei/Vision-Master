extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  CONVERSATION SCENE
#  Loads from res://data/v{book}_conversations.json
#  Reads Global.current_book + Global.current_lesson
#  Shows: image, intro, dialogue lines, discussion questions
#  Now includes: Clickable words and dictionary slide-in popup!
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
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_JAKARTA_MEDIUM_PATH  := "res://assets/fonts/PlusJakartaSans-Medium.ttf" 
const FONT_VAZIRMATN            := "res://assets/fonts/Vazirmatn-Regular.ttf"

# Preload fonts for better performance
var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile
var font_farsi: FontFile

# Existing Node References
@onready var back_button: Button             = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label             = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button            = $HeaderBar/HeaderContent/AudioButton
@onready var conversation_image: TextureRect = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ConversationImage
@onready var intro_label: Label              = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/IntroLabel
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

# Dictionary/Popup Variables
var word_regex := RegEx.new()
var line_rtls: Array = [] # Stores { "rtl": RichTextLabel, "text": String }
var current_word_data: Dictionary = {}

# Touch tracking variables for mobile scrolling
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_drag_scrolling: bool = false

var dict_popup: DictionaryPopup

func _ready() -> void:
	# Compile regex to match words (including those with apostrophes or hyphens)
	word_regex.compile("\\b([a-zA-Z]+(?:[-'][a-zA-Z]+)?)\\b")
	
	dict_popup = DictionaryPopup.new()
	add_child(dict_popup)
	dict_popup.popup_closed.connect(_on_popup_closed)

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


func _input(event: InputEvent) -> void:
	# When finger touches the screen (or left mouse clicks)
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_touch_start_pos = event.position
			_is_drag_scrolling = false # Reset the scroll flag
			
	# When finger drags across the screen
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		# If the finger moved more than 15 pixels, we consider it a scroll
		if _touch_start_pos.distance_to(event.position) > 15.0:
			_is_drag_scrolling = true


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold = load(FONT_JAKARTA_BOLD_PATH)
	font_italic = load(FONT_JAKARTA_ITALIC_PATH)
	font_farsi = load(FONT_VAZIRMATN)
	if font_regular == null: push_warning("Regular font not found")
	if font_bold == null: push_warning("Bold font not found")
	if font_italic == null: push_warning("Italic font not found")
	if font_farsi == null: push_warning("farsi font not found")

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
		
	line_rtls.clear()

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

	# Replacing standard Label with RichTextLabel for dictionary functionality
	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS 
	text_label.scroll_active = false                    
	text_label.selection_enabled = false                
	
	text_label.add_theme_font_size_override("normal_font_size", 45)
	text_label.add_theme_color_override("default_color", Color("#1E293B"))
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if font_regular != null: text_label.add_theme_font_override("normal_font", font_regular)
	if font_bold != null: text_label.add_theme_font_override("bold_font", font_bold)

	# Format text and connect signals
	text_label.text = _format_clickable_text(text, "")
	text_label.meta_clicked.connect(func(meta): _on_word_clicked(meta, text_label, text))
	
	line_rtls.append({"rtl": text_label, "text": text})

	inner.add_child(speaker_label)
	inner.add_child(text_label)
	card.add_child(inner)

	return card


# ============================================================
# DICTIONARY POPUP & HIGHLIGHT LOGIC
# ============================================================

func _format_clickable_text(base_text: String, highlight_word: String) -> String:
	var bbcode = word_regex.sub(base_text, "[url=$1]$1[/url]", true)
	if highlight_word != "":
		var h_regex := RegEx.new()
		h_regex.compile("\\[url=(?i)" + highlight_word + "\\](.*?)\\[/url\\]")
		bbcode = h_regex.sub(bbcode, "[bgcolor=#fef08a][color=#000000]$1[/color][/bgcolor]", true)
	return bbcode


func _on_word_clicked(meta: Variant, clicked_rtl: RichTextLabel, original_text: String) -> void:
	if _is_drag_scrolling:
		return 

	var clicked_string := str(meta).to_lower()
	var def := Global.get_word_definition_from_current_lesson(clicked_string)
	
	if def.is_empty():
		return 

	current_word_data = def
	
	for item in line_rtls:
		item["rtl"].text = _format_clickable_text(item["text"], "")
		
	# Highlight the specific clicked word
	clicked_rtl.text = _format_clickable_text(original_text, str(meta))
	
	# Let our new reusable component handle showing the word
	dict_popup.show_word(def)

# ============================================================
# QUESTIONS & OTHER FUNCTIONS
# ============================================================

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
			push_warning("Conversation audio not found: " + path)


func _on_play_pause_pressed() -> void:
	if audio_player.stream == null:
		_on_audio_pressed()
		return

	if audio_player.stream_paused:
		audio_player.stream_paused = false
		play_pause_button.text = "Pause"
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
	_on_close_audio_pressed()
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	if dict_popup.is_open():
		dict_popup._hide_popup()
	else:
		_on_back_button_pressed()

func _on_popup_closed() -> void:
	# Remove highlights from all paragraphs when popup closes
	for item in line_rtls:
		item["rtl"].text = _format_clickable_text(item["text"], "")
