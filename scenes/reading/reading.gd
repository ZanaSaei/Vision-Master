extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  READING SCENE
#  Loads from res://data/v{book}_readings.json
#  Shows: image, reading title, paragraphs, comprehension questions
#  Now includes: Clickable words, dictionary slide-in popup, and highlighting
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Paragraph accent color
const PARA_BG_COLOR     := Color("#F8FAFC")
const PARA_BORDER_COLOR := Color("#2563EB")
const HIGHLIGHT_COLOR   := Color("#FEF08A") # Yellow highlight
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
var paragraph_rtls: Array = [] # Stores { "rtl": RichTextLabel, "text": String }
var current_word_data: Dictionary = {}

# Popup UI nodes
var popup_layer: CanvasLayer
var popup_panel: PanelContainer
var popup_title: Label
var popup_type: Label
var popup_meaning: Label
var popup_extra: Label
var btn_save_word: Button
var btn_close_popup: Button


func _ready() -> void:
	# Compile regex to match words (including those with apostrophes or hyphens)
	word_regex.compile("\\b([a-zA-Z]+(?:[-'][a-zA-Z]+)?)\\b")
	
	_load_fonts()
	_apply_fonts_to_existing_labels()
	_setup_word_popup() # Create the popup UI programmatically

	_configure_main_image()
	_configure_background_image()

	# Connections
	back_button.pressed.connect(_on_back_button_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
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
	if (audio_player.playing or audio_player.stream_paused) and not is_dragging_slider:
		audio_slider.value = audio_player.get_playback_position()


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
			
		var main_path := "res://assets/images/%s" % image_filename
		if ResourceLoader.exists(main_path):
			reading_image.texture = load(main_path)
			reading_image.visible = true

	reading_title_label.text = data.get("title", "")

	var paragraphs: Array = data.get("paragraphs", [])
	_build_paragraphs(paragraphs)

	var questions: Array = data.get("questions", [])
	questions_section.visible = not questions.is_empty()
	if not questions.is_empty():
		_build_questions(questions)

	var audio_filename: String = data.get("audio", "reading.mp3")
	set_meta("audio_path", Global.get_audio_path(book, lesson, audio_filename))


# ============================================================
# PARAGRAPH & CLICKABLE TEXT LOGIC
# ============================================================

func _build_paragraphs(paragraphs: Array) -> void:
	for child in paragraphs_container.get_children():
		child.queue_free()
	
	paragraph_rtls.clear()

	for i in paragraphs.size():
		var para_text: String = paragraphs[i]
		var card := _make_paragraph_card(para_text)
		paragraphs_container.add_child(card)


func _make_paragraph_card(text: String) -> PanelContainer:
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

	# Use RichTextLabel to allow clickable words
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD
	rtl.add_theme_font_size_override("normal_font_size", 55)
	rtl.add_theme_color_override("default_color", Color("#1E293B"))
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if font_regular != null:
		rtl.add_theme_font_override("normal_font", font_regular)
		rtl.add_theme_font_override("bold_font", font_bold)

	# Format text to wrap words in URLs
	rtl.text = _format_clickable_text(text, "")
	
	# Connect click signal
	rtl.meta_clicked.connect(func(meta): _on_word_clicked(meta, rtl, text))
	
	paragraph_rtls.append({"rtl": rtl, "text": text})
	card.add_child(rtl)
	return card


func _format_clickable_text(base_text: String, highlight_word: String) -> String:
	# Wrap every word in a [url] tag
	var bbcode = word_regex.sub(base_text, "[url=$1]$1[/url]", true)
	
	# If we have a word to highlight, replace its specific URL tag with a colored background
	if highlight_word != "":
		# We must escape the highlight word in case it has special characters, but words usually don't.
		var h_regex := RegEx.new()
		h_regex.compile("\\[url=(?i)" + highlight_word + "\\](.*?)\\[/url\\]")
		bbcode = h_regex.sub(bbcode, "[bgcolor=#fef08a][color=#000000]$1[/color][/bgcolor]", true)
		
	return bbcode


func _on_word_clicked(meta: Variant, clicked_rtl: RichTextLabel, original_text: String) -> void:
	var clicked_string := str(meta).to_lower()
	var def := Global.get_word_definition_from_current_lesson(clicked_string)
	
	if def.is_empty():
		return # Word not in dictionary

	current_word_data = def
	
	# Reset all paragraphs to remove old highlights
	for item in paragraph_rtls:
		item["rtl"].text = _format_clickable_text(item["text"], "")
		
	# Highlight the specific clicked word in the specific paragraph
	clicked_rtl.text = _format_clickable_text(original_text, str(meta))
	
	_populate_and_show_popup(def)


# ============================================================
# DICTIONARY POPUP LOGIC
# ============================================================

func _setup_word_popup() -> void:
	popup_layer = CanvasLayer.new()
	popup_layer.layer = 100
	add_child(popup_layer)
	
	popup_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#FFFFFF")
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0,0,0,0.2)
	style.shadow_size = 10
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 40
	style.content_margin_bottom = 30
	popup_panel.add_theme_stylebox_override("panel", style)
	
	popup_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	popup_panel.position.y = -600 # Start offscreen
	popup_layer.add_child(popup_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	popup_panel.add_child(vbox)
	
	popup_title = Label.new()
	popup_title.add_theme_font_size_override("font_size", 70)
	popup_title.add_theme_color_override("font_color", Color("#0F172A"))
	if font_bold != null: popup_title.add_theme_font_override("font", font_bold)
	vbox.add_child(popup_title)
	
	popup_type = Label.new()
	popup_type.add_theme_font_size_override("font_size", 40)
	popup_type.add_theme_color_override("font_color", Color("#64748B"))
	if font_italic != null: popup_type.add_theme_font_override("font", font_italic)
	vbox.add_child(popup_type)
	
	popup_meaning = Label.new()
	popup_meaning.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_meaning.add_theme_font_size_override("font_size", 50)
	popup_meaning.add_theme_color_override("font_color", Color("#334155"))
	if font_regular != null: popup_meaning.add_theme_font_override("font", font_regular)
	vbox.add_child(popup_meaning)
	
	popup_extra = Label.new()
	popup_extra.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_extra.add_theme_font_size_override("font_size", 40)
	popup_extra.add_theme_color_override("font_color", Color("#0284C7"))
	if font_regular != null: popup_extra.add_theme_font_override("font", font_regular)
	vbox.add_child(popup_extra)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	btn_save_word = Button.new()
	btn_save_word.text = "Save to Flashcards"
	btn_save_word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_word.add_theme_font_size_override("font_size", 45)
	btn_save_word.pressed.connect(_on_save_word_pressed)
	hbox.add_child(btn_save_word)
	
	btn_close_popup = Button.new()
	btn_close_popup.text = "Close"
	btn_close_popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_close_popup.add_theme_font_size_override("font_size", 45)
	btn_close_popup.pressed.connect(_hide_word_popup)
	hbox.add_child(btn_close_popup)


func _populate_and_show_popup(def: Dictionary) -> void:
	# Base word title
	popup_title.text = str(def.get("word", "")).capitalize()
	
	# Determine Type & Countability
	var type_str := str(def.get("word_type", "Unknown")).capitalize()
	if type_str.to_lower() == "noun" and def.get("countable") != null:
		type_str += " (Countable)" if def.get("countable") else " (Uncountable)"
	popup_type.text = type_str
	
	# Meaning
	var en_meaning = def.get("meaning_en", "")
	var fa_meaning = def.get("meaning_fa", "")
	popup_meaning.text = en_meaning + ("\n" + fa_meaning if fa_meaning != "" else "")
	
	# Extra Info (Verb Forms)
	popup_extra.text = ""
	if type_str.to_lower().begins_with("verb") and def.has("verb_forms"):
		var forms = def["verb_forms"]
		var form_strings := []
		if forms.has("past"): form_strings.append("Past: " + forms["past"])
		if forms.has("past_participle"): form_strings.append("PP: " + forms["past_participle"])
		if forms.has("present_participle"): form_strings.append("ING: " + forms["present_participle"])
		popup_extra.text = " • ".join(form_strings)
	
	popup_extra.visible = popup_extra.text != ""
	
	# Check if already saved to update button text
	if Global.is_word_saved(def.get("word"), def.get("book"), def.get("lesson")):
		btn_save_word.text = "Saved ✓"
		btn_save_word.disabled = true
	else:
		btn_save_word.text = "Save to Flashcards"
		btn_save_word.disabled = false

	# Slide In Animation
	var tween = create_tween()
	tween.tween_property(popup_panel, "position:y", 0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _hide_word_popup() -> void:
	var tween = create_tween()
	tween.tween_property(popup_panel, "position:y", -popup_panel.size.y - 50, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Remove highlights from all paragraphs
	for item in paragraph_rtls:
		item["rtl"].text = _format_clickable_text(item["text"], "")


func _on_save_word_pressed() -> void:
	if not current_word_data.is_empty():
		Global.save_word(current_word_data)
		btn_save_word.text = "Saved ✓"
		btn_save_word.disabled = true
		Global.button_bounce(btn_save_word)


# ============================================================
# REMAINING FUNCTIONS (Questions, Audio, Navigation)
# ============================================================

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
	if popup_panel.position.y >= 0:
		_hide_word_popup()
	else:
		_on_back_button_pressed()
