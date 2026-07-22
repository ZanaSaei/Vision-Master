extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  CONVERSATION SCENE
#  Loads from res://data/v_conversation.json 
#  Shows: image, intro, dialogue lines, discussion questions
#  Includes: Clickable words, dictionary slide-in popup, Persian translation toggle,
#  and Audio-Text Synchronization!
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
@onready var translation_toggle: Button      = $HeaderBar/HeaderContent/TranslationToggleButton
@onready var conversation_image: TextureRect = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/ConversationImage
@onready var intro_label: RichTextLabel      = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/IntroLabel # Now a RichTextLabel
@onready var lines_container: VBoxContainer  = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/LinesContainer
@onready var questions_section: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection
@onready var questions_container: VBoxContainer = $MarginContainer/MainLayout/ScrollContainer/ContentLayout/QuestionsSection/QuestionsContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var content_layout: VBoxContainer   = $MarginContainer/MainLayout/ScrollContainer/ContentLayout

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
var line_rtls: Array = [] # Stores { "rtl": RichTextLabel, "text": String, "sentences": Array, "translation": String, "translation_label": Label }
var current_word_data: Dictionary = {}
var current_highlighted_word: String = ""

# Audio Sync Variables
var all_sentences_sync: Array = []
var intro_sentences_data: Array = []
var _last_active_sentence: Dictionary = {}

# Touch tracking variables for mobile scrolling
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_drag_scrolling: bool = false

var dict_popup: DictionaryPopup

# Translation toggle
var show_translation: bool = false

# Store current data for rebuilding
var current_book: int = 0
var current_lesson: int = 0
var current_data: Dictionary = {}
var intro_translation_label: Label = null  # Store reference to intro translation label

func _ready() -> void:
	# Compile regex to match words (including those with apostrophes or hyphens)
	word_regex.compile("\\b([a-zA-Z]+(?:[-'’][a-zA-Z]+)?)\\b")

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
	translation_toggle.pressed.connect(_on_translation_toggle_pressed)

	# Connect audio control buttons
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	close_audio_button.pressed.connect(_on_close_audio_pressed)
	
	audio_player.finished.connect(_on_audio_finished)

	# Connect slider signals
	audio_slider.drag_started.connect(_on_slider_drag_started)
	audio_slider.drag_ended.connect(_on_slider_drag_ended)

	current_book = Global.current_book
	current_lesson = Global.current_lesson

	header_title.text = "Lesson %d\nConversation" % [current_lesson]

	current_data = Global.load_conversation(current_book, current_lesson)
	if current_data.is_empty():
		intro_label.text = "Conversation not available yet."
		return

	_build_conversation(current_book, current_lesson, current_data)
	_add_bottom_scroll_spacer()
	# Set initial toggle button text
	_update_toggle_button_text()

# Call this at the end of _ready() or after loading data
func _add_bottom_scroll_spacer() -> void:
	var spacer := Control.new()
	# Set this height equal to (or slightly larger than) your AudioControlPanel height
	spacer.custom_minimum_size = Vector2(0, 200) 
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_layout.add_child(spacer)

func _process(_delta: float) -> void:
	# Keep the slider and text synced with the audio playback, even if paused
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


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold = load(FONT_JAKARTA_BOLD_PATH)
	font_italic = load(FONT_JAKARTA_ITALIC_PATH)
	font_farsi = load(FONT_VAZIRMATN)

func _apply_fonts_to_existing_labels() -> void:
	if font_regular != null: intro_label.add_theme_font_override("normal_font", font_regular) # Changed to normal_font for RichTextLabel
	if font_bold != null: header_title.add_theme_font_override("font", font_bold)

# ============================================================
# DATA LOADING & AUDIO SYNC LOGIC
# ============================================================

func _load_conversation(book: int, lesson: int) -> Dictionary:
	return Global.load_conversation(book, lesson)

func _build_conversation(book: int, lesson: int, data: Dictionary) -> void:
	all_sentences_sync.clear()
	var image_path := "res://assets/images/%s" % data.get("image", "")
	if ResourceLoader.exists(image_path):
		conversation_image.texture = load(image_path)
		conversation_image.visible = true
	else:
		conversation_image.visible = false

	# --- Intro with translation ---
	var intro_data: Dictionary = data.get("intro", {})
	intro_sentences_data = intro_data.get("sentences", [])
	
	var intro_text: String = ""
	var intro_fa: String = ""
	
	for i in range(intro_sentences_data.size()):
		var sentence = intro_sentences_data[i]
		intro_text += sentence.get("en", "") + " "
		intro_fa += sentence.get("fa", "") + " "
		
		# Register intro sentences for audio syncing
		if sentence.has("start") and sentence.has("end"):
			all_sentences_sync.append({
				"type": "intro",
				"block_idx": -1,
				"sentence_idx": i,
				"start": sentence.get("start", 0.0),
				"end": sentence.get("end", 0.0)
			})

	# Configure RichTextLabel intro properties
	intro_label.bbcode_enabled = true
	intro_label.scroll_active = false
	intro_label.fit_content = true
	intro_label.text = intro_text.strip_edges()
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_regular != null: intro_label.add_theme_font_override("normal_font", font_regular)
	
	intro_label.set_meta("translation", intro_fa.strip_edges())
	_create_intro_translation_label(intro_fa.strip_edges())

	_build_lines(data.get("lines", []))

	var questions: Array = data.get("questions", [])
	if questions.is_empty():
		questions_section.visible = false
	else:
		questions_section.visible = true
		_build_questions(questions)

	var audio_value: String = data.get("audio", "")
	var audio_path: String = Global.resolve_audio_path(book, lesson, audio_value, "reading.mp3")
	set_meta("audio_path", audio_path)


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
		var sentences: Array = line.get("sentences", [])
		var text: String = ""
		var translation: String = ""
		
		var block_idx = line_rtls.size() # Index of the line card
		
		for i in range(sentences.size()):
			var sentence = sentences[i]
			text += sentence.get("en", "") + " "
			translation += sentence.get("fa", "") + " "
			
			# Register dialogue sentences for audio syncing
			if sentence.has("start") and sentence.has("end"):
				all_sentences_sync.append({
					"type": "line",
					"block_idx": block_idx,
					"sentence_idx": i,
					"start": sentence.get("start", 0.0),
					"end": sentence.get("end", 0.0)
				})

		text = text.strip_edges()
		translation = translation.strip_edges()
		
		var color_idx: int  = speaker_map.get(speaker, 0)
		lines_container.add_child(_make_line_card(speaker, text, translation, color_idx, sentences))


func _make_line_card(speaker: String, text: String, translation: String, color_idx: int, sentences: Array) -> PanelContainer:
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

	var text_label := RichTextLabel.new()
	text_label.meta_underlined = false
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

	text_label.text = _format_clickable_text(text, "")
	text_label.meta_clicked.connect(func(meta): _on_word_clicked(meta, text_label, text))
	
	var translation_label := Label.new()
	translation_label.text = translation
	translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	translation_label.add_theme_font_size_override("font_size", 38)
	translation_label.add_theme_color_override("font_color", Color("#64748B"))
	translation_label.text_direction = Control.TEXT_DIRECTION_RTL
	translation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_farsi != null: translation_label.add_theme_font_override("font", font_farsi)
	translation_label.visible = show_translation

	inner.add_child(speaker_label)
	inner.add_child(text_label)
	inner.add_child(translation_label)
	card.add_child(inner)

	# Store the sentences array along with everything else
	line_rtls.append({
		"rtl": text_label, 
		"text": text, 
		"sentences": sentences,
		"translation": translation,
		"translation_label": translation_label
	})

	return card


func _update_audio_sync(current_time: float) -> void:
	var active_sentence: Dictionary = {}

	# Find which sentence is currently playing
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
	return a["type"] == b["type"] and a["block_idx"] == b["block_idx"] and a["sentence_idx"] == b["sentence_idx"]


func _refresh_all_text() -> void:
	# 1. Update Intro
	var new_intro = ""
	for i in range(intro_sentences_data.size()):
		var s = intro_sentences_data[i]
		var en_text = s.get("en", "")

		if _last_active_sentence.has("type") and _last_active_sentence["type"] == "intro" and _last_active_sentence["sentence_idx"] == i:
			# Wrap the active sentence in a blue highlight
			new_intro += "[bgcolor=#bfdbfe]" + en_text + "[/bgcolor] "
		else:
			new_intro += en_text + " "
	
	if intro_label != null:
		intro_label.text = new_intro.strip_edges()

	# 2. Update Lines
	for block_idx in range(line_rtls.size()):
		var block = line_rtls[block_idx]
		var rtl: RichTextLabel = block["rtl"]
		var sentences: Array = block["sentences"]

		var new_bbcode = ""
		for s_idx in range(sentences.size()):
			var s = sentences[s_idx]
			var en_text = s.get("en", "")
			var clickable_sentence = _format_clickable_text(en_text, current_highlighted_word)

			if _last_active_sentence.has("type") and _last_active_sentence["type"] == "line" and _last_active_sentence["block_idx"] == block_idx and _last_active_sentence["sentence_idx"] == s_idx:
				new_bbcode += "[bgcolor=#bfdbfe]" + clickable_sentence + "[/bgcolor] "
			else:
				new_bbcode += clickable_sentence + " "

		rtl.text = new_bbcode.strip_edges()


# ============================================================
# DICTIONARY POPUP & HIGHLIGHT LOGIC
# ============================================================

func _format_clickable_text(base_text: String, highlight_word: String) -> String:
	var bbcode = word_regex.sub(base_text, "[url=\"$1\"]$1[/url]", true)
	if highlight_word != "":
		var h_regex := RegEx.new()
		h_regex.compile("\\[url=\"?(?i)" + highlight_word + "\"?\\](.*?)\\[/url\\]")
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
	current_highlighted_word = str(meta)
	
	# Regenerate everything so audio highlights and dictionary highlights can stack safely
	_refresh_all_text() 
	dict_popup.show_word(def)

func _on_popup_closed() -> void:
	current_highlighted_word = ""
	_refresh_all_text()


# ============================================================
# TRANSLATION TOGGLES
# ============================================================

func _update_toggle_button_text() -> void:
	if show_translation:
		translation_toggle.text = "🔽 Hide Translation"
	else:
		translation_toggle.text = "🔼 Show Translation"

func _on_translation_toggle_pressed() -> void:
	show_translation = !show_translation
	_update_toggle_button_text()
	
	for item in line_rtls:
		if item.has("translation_label") and item["translation_label"] != null:
			item["translation_label"].visible = show_translation
	
	var intro_translation = intro_label.get_meta("translation", "")
	if intro_translation != "":
		_toggle_intro_translation(intro_translation)

func _create_intro_translation_label(translation: String) -> void:
	_remove_intro_translation_label()
	if translation == "": return
	
	intro_translation_label = Label.new()
	intro_translation_label.text = translation
	intro_translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_translation_label.add_theme_font_size_override("font_size", 38)
	intro_translation_label.add_theme_color_override("font_color", Color("#64748B"))
	intro_translation_label.text_direction = Control.TEXT_DIRECTION_RTL
	intro_translation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	intro_translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_farsi != null: intro_translation_label.add_theme_font_override("font", font_farsi)
	intro_translation_label.visible = show_translation
	
	var parent = intro_label.get_parent()
	if parent == null: return
	
	var index = 0
	for i in range(parent.get_child_count()):
		if parent.get_child(i) == intro_label:
			index = i + 1
			break
	
	parent.add_child(intro_translation_label)
	parent.move_child(intro_translation_label, index)

func _toggle_intro_translation(translation: String) -> void:
	if intro_translation_label == null or not is_instance_valid(intro_translation_label):
		_create_intro_translation_label(translation)
		return
	intro_translation_label.visible = show_translation

func _remove_intro_translation_label() -> void:
	if intro_translation_label != null and is_instance_valid(intro_translation_label):
		intro_translation_label.queue_free()
		intro_translation_label = null


# ============================================================
# QUESTIONS & AUDIO CONTROL
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
	_last_active_sentence = {}
	_refresh_all_text()

func _on_audio_finished() -> void:
	_last_active_sentence = {}
	_refresh_all_text()
	play_pause_button.text = "Play"

func _on_slider_drag_started() -> void:
	is_dragging_slider = true

func _on_slider_drag_ended(value_changed: bool) -> void:
	is_dragging_slider = false
	if audio_player.stream != null:
		audio_player.seek(audio_slider.value)

func _on_back_button_pressed() -> void:
	_on_close_audio_pressed()
	_remove_intro_translation_label()
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	if dict_popup != null and dict_popup.is_open():
		dict_popup._hide_popup()
	else:
		_on_back_button_pressed()
