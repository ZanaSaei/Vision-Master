extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  READING SCENE
#  Loads from res://data/v_reading.json 
#  Shows: image, reading title, paragraphs, comprehension questions
#  Includes: Clickable words, dictionary slide-in popup, Persian translation toggle,
#  and Audio-Text Synchronization!
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"
const ExerciseSectionScene := preload("res://scenes/shared/ExerciseSection.tscn")

# Paragraph accent color
const PARA_BG_COLOR     := Color("#F8FAFC")
const PARA_BORDER_COLOR := Color("#2563EB")
const HIGHLIGHT_COLOR   := Color("#FEF08A") # Yellow highlight
const BACKGROUND_OPACITY := 0.15

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_VAZIRMATN            := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile
var font_farsi: FontFile

# Touch tracking variables for mobile scrolling
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_drag_scrolling: bool = false

# Existing Node References
@onready var back_button: Button              = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label              = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button             = $HeaderBar/HeaderContent/AudioButton
@onready var translation_toggle: Button       = $HeaderBar/HeaderContent/TranslationToggleButton
@onready var background_image: TextureRect    = $BackgroundImage
@onready var reading_image: TextureRect       = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ReadingImage
@onready var reading_title_label: Label       = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ReadingTitleLabel
@onready var paragraphs_container: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ParagraphsContainer
@onready var questions_section: VBoxContainer    = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection
@onready var questions_container: VBoxContainer  = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection/QuestionsContainer
@onready var audio_player: AudioStreamPlayer  = $AudioPlayer
@onready var content_layout: VBoxContainer    =  $MarginContainer/MainLayout/ScrollContainer/ContentLayout


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
var paragraph_rtls: Array = [] # Stores { "rtl": RichTextLabel, "text": String, "sentences": Array, "translation": String, "translation_label": Label }
var current_word_data: Dictionary = {}
var current_highlighted_word: String = ""

# Audio Sync Variables
var all_sentences_sync: Array = []
var _last_active_sentence: Dictionary = {}

var dict_popup: DictionaryPopup

# Translation toggle
var show_translation: bool = false

# Store current data
var current_book: int = 0
var current_lesson: int = 0

func _ready() -> void:
	word_regex.compile("\\b([a-zA-Z]+(?:[-'’][a-zA-Z]+)?)\\b")

	_load_fonts()
	_apply_fonts_to_existing_labels()

	dict_popup = DictionaryPopup.new()
	add_child(dict_popup)
	dict_popup.popup_closed.connect(_on_popup_closed)

	_configure_main_image()
	_configure_background_image()

	# Connections
	back_button.pressed.connect(_on_back_button_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	translation_toggle.pressed.connect(_on_translation_toggle_pressed)
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	close_audio_button.pressed.connect(_on_close_audio_pressed)
	audio_slider.drag_started.connect(_on_slider_drag_started)
	audio_slider.drag_ended.connect(_on_slider_drag_ended)
	
	audio_player.finished.connect(_on_audio_finished)

	current_book = Global.current_book
	current_lesson = Global.current_lesson
	header_title.text = "Lesson %d\nReading" % current_lesson

	var data: Dictionary = Global.load_reading(current_book, current_lesson)
	if data.is_empty():
		reading_title_label.text = "Reading not available yet."
		return
	
	_add_bottom_scroll_spacer()
	_build_reading(current_book, current_lesson, data)
	_update_toggle_button_text()

func _add_bottom_scroll_spacer() -> void:
	var spacer := Control.new()
	# Set this height equal to (or slightly larger than) your AudioControlPanel height
	spacer.custom_minimum_size = Vector2(0, 200) 
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_layout.add_child(spacer)

func _process(_delta: float) -> void:
	if (audio_player.playing or audio_player.stream_paused) and not is_dragging_slider:
		var current_time = audio_player.get_playback_position()
		audio_slider.value = current_time
		_update_audio_sync(current_time)

func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_touch_start_pos = event.position
			_is_drag_scrolling = false
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		if _touch_start_pos.distance_to(event.position) > 15.0:
			_is_drag_scrolling = true

func _configure_main_image() -> void:
	reading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reading_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reading_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading_image.custom_minimum_size = Vector2(0, 1000)

func _configure_background_image() -> void:
	background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_image.modulate = Color(1, 1, 1, BACKGROUND_OPACITY)
	background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_image.set_anchors_preset(Control.PRESET_FULL_RECT)

func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold    = load(FONT_JAKARTA_BOLD_PATH)
	font_italic  = load(FONT_JAKARTA_ITALIC_PATH)
	font_farsi   = load(FONT_VAZIRMATN)

func _apply_fonts_to_existing_labels() -> void:
	if font_bold != null:
		header_title.add_theme_font_override("font", font_bold)
		reading_title_label.add_theme_font_override("font", font_bold)

# ============================================================
# DATA LOADING & AUDIO SYNC LOGIC
# ============================================================

func _build_reading(book: int, lesson: int, data: Dictionary) -> void:
	all_sentences_sync.clear()
	
	var image_filename: String = data.get("image", "") as String
	if image_filename != "" and ResourceLoader.exists(image_filename):
		background_image.texture = load(image_filename)
		background_image.visible = true
		reading_image.texture = load(image_filename)
		reading_image.visible = true
	else:
		background_image.visible = false
		reading_image.visible = false
		reading_image.custom_minimum_size = Vector2(0, 0)

	var title: String = data.get("title", "") as String
	reading_title_label.text = title
	reading_title_label.visible = title != ""

	var paragraphs: Array = data.get("paragraphs", []) as Array
	_build_paragraphs(paragraphs)

	var questions: Array = data.get("questions", []) as Array
	questions_section.visible = not questions.is_empty()
	if not questions.is_empty():
		_build_questions(questions)

	var audio_path: String = data.get("audio", "") as String
	set_meta("audio_path", audio_path)

	var exercise_ui := ExerciseSectionScene.instantiate()
	content_layout.add_child(exercise_ui)
	exercise_ui.setup(data.get("exercises", []) as Array)

func _build_paragraphs(paragraphs: Array) -> void:
	for child in paragraphs_container.get_children():
		child.queue_free()

	paragraph_rtls.clear()

	for p_idx in range(paragraphs.size()):
		var para_obj: Dictionary = paragraphs[p_idx] as Dictionary
		if para_obj.is_empty(): continue
		
		var sentences: Array = para_obj.get("sentences", []) as Array
		var para_text: String = ""
		var para_fa: String = ""
		
		var block_idx = paragraph_rtls.size()
		
		for s_idx in range(sentences.size()):
			var sentence = sentences[s_idx]
			para_text += sentence.get("en", "") + " "
			para_fa += sentence.get("fa", "") + " "
			
			if sentence.has("start") and sentence.has("end"):
				all_sentences_sync.append({
					"block_idx": block_idx,
					"sentence_idx": s_idx,
					"start": sentence.get("start", 0.0),
					"end": sentence.get("end", 0.0)
				})

		para_text = para_text.strip_edges()
		para_fa = para_fa.strip_edges()
		
		if para_text != "":
			var card := _make_paragraph_card(para_text, para_fa, sentences)
			paragraphs_container.add_child(card)

func _make_paragraph_card(text: String, translation: String, sentences: Array) -> PanelContainer:
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
	card_style.bg_color.a                 = 0.85
	card.add_theme_stylebox_override("panel", card_style)

	var container := VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_theme_constant_override("separation", 8)

	var rtl := RichTextLabel.new()
	rtl.meta_underlined = false
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.scroll_active = false
	rtl.selection_enabled = false
	rtl.add_theme_font_size_override("normal_font_size", 55)
	rtl.add_theme_color_override("default_color", Color("#1E293B"))
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if font_regular != null:
		rtl.add_theme_font_override("normal_font", font_regular)
		rtl.add_theme_font_override("bold_font", font_bold)

	rtl.text = _format_clickable_text(text, "")
	rtl.meta_clicked.connect(func(meta): _on_word_clicked(meta, rtl, text))

	var translation_label := Label.new()
	translation_label.text = translation
	translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	translation_label.add_theme_font_size_override("font_size", 45)
	translation_label.add_theme_color_override("font_color", Color("#64748B"))
	translation_label.text_direction = Control.TEXT_DIRECTION_RTL
	translation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_farsi != null: translation_label.add_theme_font_override("font", font_farsi)
	translation_label.visible = show_translation

	container.add_child(rtl)
	container.add_child(translation_label)
	card.add_child(container)

	paragraph_rtls.append({
		"rtl": rtl, 
		"text": text, 
		"sentences": sentences,
		"translation": translation,
		"translation_label": translation_label
	})
	return card

func _update_audio_sync(current_time: float) -> void:
	var active_sentence: Dictionary = {}

	for s in all_sentences_sync:
		if current_time >= s["start"] and current_time <= s["end"]:
			active_sentence = s
			break

	if not _is_same_sentence(active_sentence, _last_active_sentence):
		_last_active_sentence = active_sentence
		_refresh_all_text()

func _is_same_sentence(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() and b.is_empty(): return true
	if a.is_empty() or b.is_empty(): return false
	return a["block_idx"] == b["block_idx"] and a["sentence_idx"] == b["sentence_idx"]

func _refresh_all_text() -> void:
	for block_idx in range(paragraph_rtls.size()):
		var block = paragraph_rtls[block_idx]
		var rtl: RichTextLabel = block["rtl"]
		var sentences: Array = block["sentences"]

		var new_bbcode = ""
		for s_idx in range(sentences.size()):
			var s = sentences[s_idx]
			var en_text = s.get("en", "")
			var clickable_sentence = _format_clickable_text(en_text, current_highlighted_word)

			if _last_active_sentence.has("block_idx") and _last_active_sentence["block_idx"] == block_idx and _last_active_sentence["sentence_idx"] == s_idx:
				new_bbcode += "[bgcolor=#bfdbfe]" + clickable_sentence + "[/bgcolor] "
			else:
				new_bbcode += clickable_sentence + " "

		rtl.text = new_bbcode.strip_edges()

# ============================================================
# DICTIONARY POPUP & TOGGLES
# ============================================================

func _format_clickable_text(base_text: String, highlight_word: String) -> String:
	var bbcode = word_regex.sub(base_text, "[url=\"$1\"]$1[/url]", true)
	if highlight_word != "":
		var h_regex := RegEx.new()
		h_regex.compile("\\[url=\"?(?i)" + highlight_word + "\"?\\](.*?)\\[/url\\]")
		bbcode = h_regex.sub(bbcode, "[bgcolor=#fef08a][color=#000000]$1[/color][/bgcolor]", true)
	return bbcode

func _on_word_clicked(meta: Variant, clicked_rtl: RichTextLabel, original_text: String) -> void:
	if _is_drag_scrolling: return
	
	var clicked_string := str(meta).to_lower()
	var def := Global.get_word_definition_from_current_lesson(clicked_string)

	if def.is_empty(): return

	current_word_data = def
	current_highlighted_word = str(meta)
	
	_refresh_all_text()
	dict_popup.show_word(def)

func _on_popup_closed() -> void:
	current_highlighted_word = ""
	_refresh_all_text()

func _update_toggle_button_text() -> void:
	if show_translation:
		translation_toggle.text = "🔽 Hide Translation"
	else:
		translation_toggle.text = "🔼 Show Translation"

func _on_translation_toggle_pressed() -> void:
	show_translation = !show_translation
	_update_toggle_button_text()
	for item in paragraph_rtls:
		if item.has("translation_label") and item["translation_label"] != null:
			item["translation_label"].visible = show_translation

# ============================================================
# QUESTIONS & AUDIO CONTROL
# ============================================================

func _build_questions(questions: Array) -> void:
	for child in questions_container.get_children():
		child.queue_free()

	for i in questions.size():
		var q: String = questions[i] as String
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

func _on_play_pause_pressed() -> void:
	if audio_player.stream == null:
		_on_audio_pressed()
		return
	if audio_player.stream_paused:
		audio_player.stream_paused = false
		play_pause_button.text = "Pause"
		if not audio_player.playing: audio_player.play(audio_slider.value)
	elif audio_player.playing:
		audio_player.stream_paused = true
		play_pause_button.text = "Play"
	else:
		_on_audio_pressed()

func _on_rewind_pressed() -> void:
	if audio_player.stream != null:
		audio_player.seek(max(0.0, audio_player.get_playback_position() - SEEK_STEP))
		audio_slider.value = audio_player.get_playback_position()

func _on_forward_pressed() -> void:
	if audio_player.stream != null:
		audio_player.seek(min(audio_player.stream.get_length(), audio_player.get_playback_position() + SEEK_STEP))
		audio_slider.value = audio_player.get_playback_position()

func _on_close_audio_pressed() -> void:
	audio_player.stop()
	audio_player.stream_paused = false
	audio_control_panel.hide()
	audio_slider.value = 0.0
	_last_active_sentence = {}
	_refresh_all_text()

func _on_audio_finished() -> void:
	_last_active_sentence = {}
	_refresh_all_text()
	play_pause_button.text = "Play"

func _on_slider_drag_started() -> void: is_dragging_slider = true

func _on_slider_drag_ended(value_changed: bool) -> void:
	is_dragging_slider = false
	if audio_player.stream != null: audio_player.seek(audio_slider.value)

func _on_back_button_pressed() -> void:
	_on_close_audio_pressed()
	TransitionManager.change_scene(SCENE_LESSON_MENU)
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

func _on_android_back_pressed() -> void:
	if dict_popup != null and dict_popup.is_open():
		dict_popup._hide_popup()
	else:
		_on_back_button_pressed()
