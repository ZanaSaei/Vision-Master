extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# CONVERSATION SCENE — PageView Edition
# Two swipeable pages: Conversation / Oral Practice
# ============================================================
const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Vibrant accent colors for the left border & speaker labels
const SPEAKER_COLORS := [
	Color("#22D3EE"),  # Cyan
	Color("#EC4899"),  # Pink/Magenta
	Color("#FBBF24"),  # Amber/Gold
	Color("#34D399")   # Emerald
]

# Dark, harmonious card backgrounds (tinted to match the navy theme)
const SPEAKER_BG_COLORS := [
	Color("#1a2f5c"),  # Deep blue
	Color("#2d1f4e"),  # Deep purple
	Color("#2d2a1f"),  # Deep amber-brown
	Color("#1a2d2a")   # Deep teal
]

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf"
const FONT_JAKARTA_MEDIUM_PATH  := "res://assets/fonts/PlusJakartaSans-Medium.ttf"
const FONT_VAZIRMATN            := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile
var font_farsi: FontFile

# ---------- Node References ----------
@onready var header_bar: Control              = $HeaderBar
@onready var back_button: Button              = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label              = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button             = $HeaderBar/HeaderContent/AudioButton
@onready var translation_toggle: Button       = $HeaderBar/HeaderContent/TranslationToggleButton
@onready var audio_panel: PanelContainer      = $AudioPanel
@onready var page_view: PageView              = $MarginContainer/MainLayout/PageView

# ---------- Dynamically Created Nodes ----------
var conversation_image: TextureRect
var intro_label: RichTextLabel
var lines_container: VBoxContainer
var exercises_container: VBoxContainer
var intro_translation_label: Label = null

# ---------- State Variables ----------
const SEEK_STEP: float = 10.0
var is_dragging_slider: bool = false
var word_regex := RegEx.new()
var line_rtls: Array = []
var current_word_data: Dictionary = {}
var current_highlighted_word: String = ""
var all_sentences_sync: Array = []
var intro_sentences_data: Array = []
var _last_active_sentence: Dictionary = {}
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_drag_scrolling: bool = false
var dict_popup: DictionaryPopup
var show_translation: bool = false
var current_book: int = 0
var current_lesson: int = 0
var current_data: Dictionary = {}

# ============================================================
# READY — Build the two pages
# ============================================================
func _ready() -> void:
	page_view.add_swipe_blocker(audio_panel)
	page_view.add_swipe_blocker(header_bar)
	
	var apostrophes := "'%s%s" % [char(0x2018), char(0x2019)]
	word_regex.compile("\\b([a-zA-Z]+(?:[%s-][a-zA-Z]+)*)\\b" % apostrophes)
	dict_popup = DictionaryPopup.new()
	add_child(dict_popup)
	dict_popup.popup_closed.connect(_on_popup_closed)
	
	audio_button.pivot_offset = audio_button.size / 2.0
	back_button.pivot_offset = back_button.size / 2.0
	
	_load_fonts()
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	
	# General Connections
	back_button.pressed.connect(_on_back_button_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	translation_toggle.pressed.connect(_on_translation_toggle_pressed)
	
	# Audio Panel Connections
	audio_panel.playback_updated.connect(_update_audio_sync)
	audio_panel.audio_closed.connect(_on_audio_stopped)
	audio_panel.audio_finished.connect(_on_audio_stopped)
	
	current_book = Global.current_book
	current_lesson = Global.current_lesson
	header_title.text = "Lesson %d\nConversation" % [current_lesson]
	current_data = Global.load_conversation(current_book, current_lesson)
	
	# ---- Build the two pages ----
	_build_conversation_page()
	_build_oral_page()
	
	if current_data.is_empty():
		intro_label.text = "Conversation not available yet."
		return
		
	var lesson_data := Global.load_category("conversation_oral", Global.current_book, Global.current_lesson)
	for exercise in lesson_data.get("exercises", []):
		var engine := ExerciseEngine.new()
		exercises_container.add_child(engine)
		engine.build(exercise)
		engine.exercise_checked.connect(_on_exercise_checked)
		
	_build_conversation(current_book, current_lesson, current_data)
	_update_toggle_button_text()

# ============================================================
# PAGE BUILDERS
# ============================================================
func _build_conversation_page() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	
	# Tint the page background to match the dark navy theme
	var page_bg := StyleBoxFlat.new()
	page_bg.bg_color = Color("#2c387f")
	page.add_theme_stylebox_override("panel", page_bg)

	# Conversation Image
	conversation_image = TextureRect.new()
	conversation_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	conversation_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	conversation_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation_image.custom_minimum_size = Vector2(0, 800)
	page.add_child(conversation_image)

	# Intro Label
	intro_label = RichTextLabel.new()
	intro_label.bbcode_enabled = true
	intro_label.scroll_active = false
	intro_label.fit_content = true
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_label.add_theme_font_size_override("normal_font_size", 48)
	intro_label.add_theme_color_override("default_color", Color("#F1F5F9"))  # Light slate for visibility
	if font_regular:
		intro_label.add_theme_font_override("normal_font", font_regular)
	page.add_child(intro_label)

	# Lines Container
	lines_container = VBoxContainer.new()
	lines_container.add_theme_constant_override("separation", 20)
	page.add_child(lines_container)

	# Spacer for Audio Panel
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 200)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)

	page_view.add_page("conversation", "Conversation", "💬", page)

func _build_oral_page() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	
	# Exercises Container
	exercises_container = VBoxContainer.new()
	exercises_container.add_theme_constant_override("separation", 24)
	page.add_child(exercises_container)
	
	# Spacer for Audio Panel
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 200)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)
	
	page_view.add_page("oral", "Oral Practice", "🗣️", page)

# ============================================================
# INPUT & SCROLL TRACKING
# ============================================================
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

# ============================================================
# DATA LOADING & AUDIO SYNC LOGIC
# ============================================================
func _build_conversation(book: int, lesson: int, data: Dictionary) -> void:
	all_sentences_sync.clear()
	var image_path := "res://assets/images/%s" % data.get("image", "")
	if ResourceLoader.exists(image_path):
		conversation_image.texture = load(image_path)
		conversation_image.visible = true
	else:
		conversation_image.visible = false
		conversation_image.custom_minimum_size = Vector2(0, 0) # Hide if no image
		
	# --- Intro with translation ---
	var intro_data: Dictionary = data.get("intro", {})
	intro_sentences_data = intro_data.get("sentences", [])
	var intro_text: String = ""
	var intro_fa: String = ""
	
	for i in range(intro_sentences_data.size()):
		var sentence = intro_sentences_data[i]
		intro_text += sentence.get("en", "") + " "
		intro_fa += sentence.get("fa", "") + " "
		if sentence.has("start") and sentence.has("end"):
			all_sentences_sync.append({
				"type": "intro", "block_idx": -1, "sentence_idx": i,
				"start": sentence.get("start", 0.0), "end": sentence.get("end", 0.0)
			})
	
	# --- FIX: Make intro text clickable ---
	intro_label.meta_underlined = false
	intro_label.text = _format_clickable_text(intro_text.strip_edges(), "")
	intro_label.meta_clicked.connect(func(meta): _on_word_clicked(meta, intro_label, intro_text.strip_edges()))
	intro_label.set_meta("translation", intro_fa.strip_edges())
	_create_intro_translation_label(intro_fa.strip_edges())
	
	_build_lines(data.get("lines", []))
	
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
		var block_idx = line_rtls.size()
		
		for i in range(sentences.size()):
			var sentence = sentences[i]
			text += sentence.get("en", "") + " "
			translation += sentence.get("fa", "") + " "
			if sentence.has("start") and sentence.has("end"):
				all_sentences_sync.append({
					"type": "line", "block_idx": block_idx, "sentence_idx": i,
					"start": sentence.get("start", 0.0), "end": sentence.get("end", 0.0)
				})
				
		text = text.strip_edges()
		translation = translation.strip_edges()
		var color_idx: int = speaker_map.get(speaker, 0)
		lines_container.add_child(_make_line_card(speaker, text, translation, color_idx, sentences))

func _make_line_card(speaker: String, text: String, translation: String, color_idx: int, sentences: Array) -> PanelContainer:
	var accent_color: Color = SPEAKER_COLORS[color_idx]
	var bg_color: Color     = SPEAKER_BG_COLORS[color_idx]

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	# --- Modern card style with shadow & rounded corners ---
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = bg_color
	card_style.set_corner_radius_all(20)
	card_style.border_width_left = 5
	card_style.border_color = accent_color
	card_style.shadow_color = Color(0, 0, 0, 0.45)
	card_style.shadow_size = 10
	card_style.shadow_offset = Vector2(0, 6)
	card_style.content_margin_left   = 28
	card_style.content_margin_right  = 28
	card_style.content_margin_top    = 22
	card_style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", card_style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS

	# --- Speaker label (vibrant accent color) ---
	var speaker_label := Label.new()
	speaker_label.text = speaker.to_upper()
	speaker_label.add_theme_font_size_override("font_size", 42)
	speaker_label.add_theme_color_override("font_color", accent_color)
	if font_bold:
		speaker_label.add_theme_font_override("font", font_bold)

	# --- Main text (light color for visibility on dark card) ---
	var text_label := RichTextLabel.new()
	text_label.meta_underlined = false
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	text_label.scroll_active = false
	text_label.selection_enabled = false
	text_label.add_theme_font_size_override("normal_font_size", 48)
	text_label.add_theme_color_override("default_color", Color("#F1F5F9"))  # Light slate
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_regular:
		text_label.add_theme_font_override("normal_font", font_regular)
	if font_bold:
		text_label.add_theme_font_override("bold_font", font_bold)
	
	text_label.text = _format_clickable_text(text, "")
	text_label.meta_clicked.connect(func(meta): _on_word_clicked(meta, text_label, text))

	# --- Translation label (muted light for hierarchy) ---
	var translation_label := Label.new()
	translation_label.text = translation
	translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	translation_label.add_theme_font_size_override("font_size", 40)
	translation_label.add_theme_color_override("font_color", Color("#94A3B8"))  # Muted light
	translation_label.text_direction = Control.TEXT_DIRECTION_RTL
	translation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_farsi:
		translation_label.add_theme_font_override("font", font_farsi)
	translation_label.visible = show_translation

	inner.add_child(speaker_label)
	inner.add_child(text_label)
	inner.add_child(translation_label)
	card.add_child(inner)

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
	# 1. Update Intro with clickable words and highlight
	var new_intro_bbcode := ""
	for i in range(intro_sentences_data.size()):
		var s = intro_sentences_data[i]
		var en_text = s.get("en", "")
		var clickable_sentence = _format_clickable_text(en_text, current_highlighted_word)
		
		if _last_active_sentence.has("type") and _last_active_sentence["type"] == "intro" and _last_active_sentence["sentence_idx"] == i:
			new_intro_bbcode += "[bgcolor=#fbbf2480][color=#ffffff]" + clickable_sentence + "[/color][/bgcolor] "
		else:
			new_intro_bbcode += clickable_sentence + " "
			
	if intro_label != null:
		intro_label.text = new_intro_bbcode.strip_edges()

	# 2. Update Lines
	for block_idx in range(line_rtls.size()):
		var block = line_rtls[block_idx]
		var rtl: RichTextLabel = block["rtl"]
		var sentences: Array = block["sentences"]
		var new_bbcode := ""
		
		for s_idx in range(sentences.size()):
			var s = sentences[s_idx]
			var en_text = s.get("en", "")
			var clickable_sentence = _format_clickable_text(en_text, current_highlighted_word)
			
			if _last_active_sentence.has("type") and _last_active_sentence["type"] == "line" and _last_active_sentence["block_idx"] == block_idx and _last_active_sentence["sentence_idx"] == s_idx:
				new_bbcode += "[bgcolor=#fbbf2480][color=#ffffff]" + clickable_sentence + "[/color][/bgcolor] "
			else:
				new_bbcode += clickable_sentence + " "
				
		rtl.text = new_bbcode.strip_edges()

# ============================================================
# DICTIONARY POPUP & TRANSLATION TOGGLES
# ============================================================
func _format_clickable_text(base_text: String, highlight_word: String) -> String:
	var out := ""
	var last_end := 0

	var normalized_highlight := ""
	if highlight_word != "":
		normalized_highlight = _normalize_word(highlight_word)

	for m in word_regex.search_all(base_text):
		var start: int = m.get_start()
		var end: int = m.get_end()
		var word: String = base_text.substr(start, end - start)

		# Add any spaces/punctuation before this word.
		out += base_text.substr(last_end, start - last_end)

		# Meta must be safe for BBCode attributes.
		var safe_meta := _encode_word_meta(word)

		if normalized_highlight != "" and _normalize_word(word) == normalized_highlight:
			out += "[bgcolor=#fbbf24][color=#000000][url=%s]%s[/url][/color][/bgcolor]" % [
				safe_meta, word
			]
		else:
			out += "[url=%s]%s[/url]" % [
				safe_meta, word
			]

		last_end = end

	# Add anything after the last matched word.
	out += base_text.substr(last_end)

	return out

func _normalize_word(word: String) -> String:
	var normalized := word

	# Convert common apostrophe-like characters to a normal ASCII apostrophe.
	normalized = normalized.replace(char(0x2018), "'")  # ‘
	normalized = normalized.replace(char(0x2019), "'")  # ’
	normalized = normalized.replace(char(0x00B4), "'")  # ´
	normalized = normalized.replace("`", "'")

	return normalized.to_lower()


func _encode_word_meta(word: String) -> String:
	# Make the meta safe for RichTextLabel BBCode.
	# Do not put raw apostrophes inside [url=...].
	return _normalize_word(word).replace("'", "%27")

func _on_word_clicked(meta: Variant, clicked_rtl: RichTextLabel, original_text: String) -> void:
	if _is_drag_scrolling:
		return

	var clicked_string := str(meta).replace("%27", "'")
	clicked_string = _normalize_word(clicked_string)

	var def := Global.get_word_definition_from_current_lesson(clicked_string)
	if def.is_empty():
		return

	current_word_data = def
	current_highlighted_word = clicked_string

	_refresh_all_text()
	dict_popup.show_word(def)

func _on_popup_closed() -> void:
	current_highlighted_word = ""
	_refresh_all_text()

func _update_toggle_button_text() -> void:
	translation_toggle.text = "🔽 Hide Translation" if show_translation else "🔼 Show Translation"

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
	if font_farsi: intro_translation_label.add_theme_font_override("font", font_farsi)
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
# AUDIO & NAVIGATION
# ============================================================
func _on_audio_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(audio_button, "scale", Vector2(0.93, 0.93), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not audio_panel.is_playing():
		var path: String = get_meta("audio_path", "")
		audio_panel.load_and_play(path)

func _on_audio_stopped() -> void:
	_last_active_sentence = {}
	_refresh_all_text()

func _on_exercise_checked(exercise_id: String, correct: int, total: int) -> void:
	print("%s → %d/%d" % [exercise_id, correct, total])

func _on_back_button_pressed() -> void:
	audio_panel.stop_and_close()
	_remove_intro_translation_label()
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	if dict_popup != null and dict_popup.is_open():
		dict_popup._hide_popup()
	else:
		_on_back_button_pressed()
