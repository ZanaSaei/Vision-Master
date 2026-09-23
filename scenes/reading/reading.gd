extends "res://autoload/BackButtonHandler.gd" #[cite: 2]
# ============================================================
# READING SCENE — PageView Edition
# Three swipeable pages: Reading / Strategy / Practice
# Keeps: audio-text sync, dictionary popup, translation toggle,
#        clickable words, and the full Reading Strategy lesson.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn" #[cite: 2]

# Paragraph accent color — dark theme
const PARA_BG_COLOR     := Color("#1a2f5c")
const PARA_BORDER_COLOR := Color("#22D3EE")
const HIGHLIGHT_COLOR   := Color("#fbbf24")
const BACKGROUND_OPACITY := 0.08

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf" #[cite: 2]
const FONT_JAKARTA_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf" #[cite: 2]
const FONT_JAKARTA_ITALIC_PATH  := "res://assets/fonts/PlusJakartaSans-Italic.ttf" #[cite: 2]
const FONT_VAZIRMATN            := "res://assets/fonts/Vazirmatn-Regular.ttf" #[cite: 2]

var font_regular: FontFile #[cite: 2]
var font_bold: FontFile #[cite: 2]
var font_italic: FontFile #[cite: 2]
var font_farsi: FontFile #[cite: 2]

# ---------- Per-strategy visual theme (from Reading Strategy scene) ----------
const STRATEGY_THEMES := {
	"Scanning":                    { "accent": Color("#22D3EE"), "soft": Color("#1a2f5c"), "icon": "🔍"},
	"Skimming":                    { "accent": Color("#34D399"), "soft": Color("#1a2d2a"), "icon": "📖"},
	"Recognizing Reference Words": { "accent": Color("#EC4899"), "soft": Color("#2d1f4e"), "icon": "🔗"},
	"Question Generation":         { "accent": Color("#FBBF24"), "soft": Color("#2d2a1f"), "icon": "❓"},
	"Highlighting":                { "accent": Color("#A78BFA"), "soft": Color("#2d1f4e"), "icon": "🖍️"},
	"Note Taking":                 { "accent": Color("#34D399"), "soft": Color("#1a2d2a"), "icon": "📝"},
}
const DEFAULT_THEME := { "accent": Color("#22D3EE"), "soft": Color("#1a2f5c"), "icon": "🎯"}

# Touch tracking variables for mobile scrolling
var _touch_start_pos: Vector2 = Vector2.ZERO #[cite: 2]
var _is_drag_scrolling: bool = false #[cite: 2]

var _touch_start_time: float = 0.0 #[cite: 2]
var _touch_max_distance: float = 0.0 #[cite: 2]

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var header_bar: Control              = $HeaderBar
@onready var header_content: HBoxContainer    = $HeaderBar/HeaderContent
@onready var back_button: Button              = $HeaderBar/HeaderContent/BackButton #[cite: 2]
@onready var home_button: Button              = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label              = $HeaderBar/HeaderContent/HeaderTitle #[cite: 2]
@onready var audio_button: Button             = $HeaderBar/HeaderContent/AudioButton #[cite: 2]
@onready var translation_toggle: Button       = $HeaderBar/HeaderContent/TranslationToggleButton #[cite: 2]
@onready var background_image: TextureRect    = $BackgroundImage #[cite: 2]
@onready var page_view: PageView              = $MarginContainer/MainLayout/PageView #[cite: 2]

# --- NEW AUDIO PANEL REFERENCE ---
@onready var audio_panel: PanelContainer      = $AudioPanel

# These reading widgets are now created in code (inside the Reading page):
var reading_image: TextureRect #[cite: 2]
var reading_title_label: Label #[cite: 2]
var paragraphs_container: VBoxContainer #[cite: 2]

# The strategy builders all add widgets to `content_layout`.
var content_layout: VBoxContainer #[cite: 2]

# Replay the strategy entrance animation the first time it's opened
var _strategy_entrance_played := false #[cite: 2]
var _reveal_cards: Array = []   # collected for staggered entrance[cite: 2]
var strategy_fa_nodes: Array[Control] = [] #[cite: 2]

# Dictionary/Popup Variables
var word_regex := RegEx.new() #[cite: 2]
var paragraph_rtls: Array = [] #[cite: 2]
var current_word_data: Dictionary = {} #[cite: 2]
var current_highlighted_word: String = "" #[cite: 2]

# Audio Sync Variables
var all_sentences_sync: Array = [] #[cite: 2]
var _last_active_sentence: Dictionary = {} #[cite: 2]
var _sync_index: int = 0 #[cite: 2]
var dict_popup: DictionaryPopup #[cite: 2]

# Translation toggle
var show_translation: bool = false #[cite: 2]

# Store current data
var current_book: int = 0 #[cite: 2]
var current_lesson: int = 0 #[cite: 2]


# ============================================================
# READY — build the three pages
# ============================================================
func _ready() -> void:
	page_view.add_swipe_blocker(audio_panel) # Replaced audio_control_panel with audio_panel[cite: 2]
	page_view.add_swipe_blocker(header_bar)
	var apostrophes := "'%s%s" % [char(0x2018), char(0x2019)]
	word_regex.compile("\\b([a-zA-Z]+(?:[%s-][a-zA-Z]+)*)\\b" % apostrophes)
	_load_fonts() #[cite: 2]
	if font_bold: header_title.add_theme_font_override("font", font_bold) #[cite: 2]
	
	dict_popup = DictionaryPopup.new() #[cite: 2]
	add_child(dict_popup) #[cite: 2]
	dict_popup.popup_closed.connect(_on_popup_closed) #[cite: 2]
	
	_configure_background_image() #[cite: 2]
	
	# General Connections
	back_button.pressed.connect(_on_back_button_pressed) #[cite: 2]
	home_button.pressed.connect(_on_home_pressed)
	audio_button.pressed.connect(_on_audio_pressed) #[cite: 2]
	translation_toggle.pressed.connect(_on_translation_toggle_pressed) #[cite: 2]
	page_view.page_changed.connect(_on_page_changed) #[cite: 2]
	
	# --- NEW AUDIO PANEL CONNECTIONS ---
	audio_panel.playback_updated.connect(_update_audio_sync)
	audio_panel.audio_closed.connect(_on_audio_stopped)
	audio_panel.audio_finished.connect(_on_audio_stopped)
	
	current_book = Global.current_book #[cite: 2]
	current_lesson = Global.current_lesson #[cite: 2]
	header_title.text = MenuStyle.persian_digits("درس %d\nخواندن" % current_lesson) #[cite: 2]
	# Fetch this lesson's media (reading audio) if it hasn't been downloaded yet.
	Content.ensure_lesson(current_book, current_lesson)
	
	var data: Dictionary          = Global.load_reading(current_book, current_lesson) #[cite: 2]
	var strategy_data: Dictionary = Global.load_category("reading_strategies", current_book, current_lesson) #[cite: 2]
	var comp_data: Dictionary     = Global.load_category("reading_comprehension", current_book, current_lesson) #[cite: 2]
	
	# ---- Build the three pages ----
	_build_reading_page(data) #[cite: 2]
	_build_strategy_page(strategy_data)     # adds a page only for Vision 2 & 3[cite: 2]
	_build_comprehension_page(comp_data) #[cite: 2]
	
	_update_toggle_button_text() #[cite: 2]
	
	Global.on_theme_changed(_apply_theme) #[cite: 2]
	_apply_theme() #[cite: 2]

# ============================================================
# PAGE BUILDERS
# ============================================================
func _make_page_spacer() -> Control:
	var spacer := Control.new() #[cite: 2]
	spacer.custom_minimum_size = Vector2(0, 200)   # clears the audio panel[cite: 2]
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE #[cite: 2]
	return spacer #[cite: 2]


# ---------- PAGE 1: READING ----------
func _build_reading_page(data: Dictionary) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	
	reading_image = TextureRect.new()
	_configure_main_image()
	page.add_child(reading_image)
	
	reading_title_label = Label.new()
	reading_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reading_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reading_title_label.add_theme_font_size_override("font_size", 58)
	reading_title_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	if font_bold: reading_title_label.add_theme_font_override("font", font_bold)
	page.add_child(reading_title_label)
	
	paragraphs_container = VBoxContainer.new()
	paragraphs_container.add_theme_constant_override("separation", 20)
	page.add_child(paragraphs_container)
	
	page.add_child(_make_page_spacer())
	
	if data.is_empty():
		reading_title_label.text = "Reading not available yet."
	else:
		_build_reading(current_book, current_lesson, data)
	
	page_view.add_page("reading", "خواندن", "📖", page)

# ---------- PAGE 2: STRATEGY (Vision 2 & 3 only) ----------
func _build_strategy_page(data: Dictionary) -> void:
	if data.is_empty() or not data.has("strategy"): #[cite: 2]
		return #[cite: 2]
	
	strategy_fa_nodes.clear() # Clear tracked nodes on rebuild[cite: 2]
	
	var page := VBoxContainer.new() #[cite: 2]
	page.add_theme_constant_override("separation", 20) #[cite: 2]
	content_layout = page #[cite: 2]
	
	var strategy: Dictionary = data["strategy"] #[cite: 2]
	var strategy_theme: Dictionary = STRATEGY_THEMES.get(strategy["name"]["en"], DEFAULT_THEME) #[cite: 2]
	
	_build_banner(strategy, strategy_theme) #[cite: 2]
	_build_steps(strategy, strategy_theme) #[cite: 2]
	_build_reference_materials(strategy, strategy_theme) #[cite: 2]
	_build_persian_insights(strategy, strategy_theme) #[cite: 2]
	_build_practice(data.get("exercises", []), strategy_theme) #[cite: 2]
	page.add_child(_make_page_spacer()) #[cite: 2]
	
	page_view.add_page("strategy", "راهبرد", "🎯", page) #[cite: 2]

# ---------- PAGE 3: COMPREHENSION ----------
func _build_comprehension_page(data: Dictionary) -> void:
	if data.is_empty() or data.get("exercises", []).is_empty(): #[cite: 2]
		return #[cite: 2]
	
	var page := VBoxContainer.new() #[cite: 2]
	page.add_theme_constant_override("separation", 24) #[cite: 2]
	
	for exercise in data.get("exercises", []): #[cite: 2]
		var engine := ExerciseEngine.new() #[cite: 2]
		page.add_child(engine) #[cite: 2]
		engine.build(exercise) #[cite: 2]
		engine.exercise_checked.connect(_on_exercise_checked) #[cite: 2]
	
	page.add_child(_make_page_spacer()) #[cite: 2]
	page_view.add_page("practice", "تمرین", "✏️", page) #[cite: 2]


# ---------- Replay strategy entrance the first time it's opened ----------
func _on_page_changed(_index: int, page_id: String) -> void:
	# Close the dictionary popup if it's currently open
	if dict_popup != null and dict_popup.is_open(): #[cite: 2]
		dict_popup._hide_popup() #[cite: 2]
		
	if page_id == "strategy" and not _strategy_entrance_played: #[cite: 2]
		_strategy_entrance_played = true #[cite: 2]
		_play_entrance() #[cite: 2]


func _on_exercise_checked(exercise_id: String, correct: int, total: int) -> void:
	print("%s → %d/%d" % [exercise_id, correct, total]) #[cite: 2]


# ============================================================
# PROCESS / INPUT 
# (Note: _process is removed because audio_panel handles slider ticks)
# ============================================================

func _input(event: InputEvent) -> void:
	super._input(event) #[cite: 2]
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT): #[cite: 2]
		if event.pressed: #[cite: 2]
			_touch_start_pos = event.position #[cite: 2]
			_touch_start_time = Time.get_ticks_msec() / 1000.0 #[cite: 2]
			_touch_max_distance = 0.0 #[cite: 2]
			_is_drag_scrolling = false #[cite: 2]
		else: #[cite: 2]
			if _touch_start_pos.distance_to(event.position) > 15.0: #[cite: 2]
				_is_drag_scrolling = true #[cite: 2]
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)): #[cite: 2]
		var dist := _touch_start_pos.distance_to(event.position) #[cite: 2]
		if dist > _touch_max_distance: #[cite: 2]
			_touch_max_distance = dist #[cite: 2]
		if dist > 15.0: #[cite: 2]
			_is_drag_scrolling = true #[cite: 2]


# ============================================================
# IMAGE / FONT CONFIG
# ============================================================
func _configure_main_image() -> void:
	reading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE #[cite: 2]
	reading_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED #[cite: 2]
	reading_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL #[cite: 2]
	reading_image.size_flags_vertical = Control.SIZE_EXPAND_FILL #[cite: 2]
	reading_image.custom_minimum_size = Vector2(0, 1000) #[cite: 2]


func _configure_background_image() -> void:
	background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE #[cite: 2]
	background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED #[cite: 2]
	background_image.modulate = Color(1, 1, 1, BACKGROUND_OPACITY) #[cite: 2]
	background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE #[cite: 2]
	background_image.set_anchors_preset(Control.PRESET_FULL_RECT) #[cite: 2]


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH) #[cite: 2]
	font_bold    = load(FONT_JAKARTA_BOLD_PATH) #[cite: 2]
	font_italic  = load(FONT_JAKARTA_ITALIC_PATH) #[cite: 2]
	font_farsi   = load(FONT_VAZIRMATN) #[cite: 2]


# ============================================================
# DATA LOADING & AUDIO SYNC LOGIC
# ============================================================
func _build_reading(_book: int, _lesson: int, data: Dictionary) -> void:
	all_sentences_sync.clear() #[cite: 2]
	_sync_index = 0 #[cite: 2]
	
	var image_filename: String = data.get("image", "") as String #[cite: 2]
	if image_filename != "" and ResourceLoader.exists(image_filename): #[cite: 2]
		background_image.texture = load(image_filename) #[cite: 2]
		background_image.visible = true #[cite: 2]
		reading_image.texture = load(image_filename) #[cite: 2]
		reading_image.visible = true #[cite: 2]
	else:
		background_image.visible = false #[cite: 2]
		reading_image.visible = false #[cite: 2]
		reading_image.custom_minimum_size = Vector2(0, 0) #[cite: 2]
	
	var title: String = data.get("title", "") as String #[cite: 2]
	reading_title_label.text = title #[cite: 2]
	reading_title_label.visible = title != "" #[cite: 2]
	
	var paragraphs: Array = data.get("paragraphs", []) as Array #[cite: 2]
	_build_paragraphs(paragraphs) #[cite: 2]
	
	var audio_path: String = data.get("audio", "") as String #[cite: 2]
	set_meta("audio_path", audio_path) #[cite: 2]


func _build_paragraphs(paragraphs: Array) -> void:
	for child in paragraphs_container.get_children(): #[cite: 2]
		child.queue_free() #[cite: 2]
	paragraph_rtls.clear() #[cite: 2]
	
	for p_idx in range(paragraphs.size()): #[cite: 2]
		var para_obj: Dictionary = paragraphs[p_idx] as Dictionary #[cite: 2]
		if para_obj.is_empty(): continue #[cite: 2]
		var sentences: Array = para_obj.get("sentences", []) as Array #[cite: 2]
		var para_text: String = "" #[cite: 2]
		var para_fa: String = "" #[cite: 2]
		var block_idx = paragraph_rtls.size() #[cite: 2]
		for s_idx in range(sentences.size()): #[cite: 2]
			var sentence = sentences[s_idx] #[cite: 2]
			para_text += sentence.get("en", "") + " " #[cite: 2]
			para_fa += sentence.get("fa", "") + " " #[cite: 2]
			if sentence.has("start") and sentence.has("end"): #[cite: 2]
				all_sentences_sync.append({ #[cite: 2]
					"block_idx": block_idx, #[cite: 2]
					"sentence_idx": s_idx, #[cite: 2]
					"start": sentence.get("start", 0.0), #[cite: 2]
					"end": sentence.get("end", 0.0) #[cite: 2]
				}) #[cite: 2]
		para_text = para_text.strip_edges() #[cite: 2]
		para_fa = para_fa.strip_edges() #[cite: 2]
		if para_text != "": #[cite: 2]
			var card := _make_paragraph_card(para_text, para_fa, sentences) #[cite: 2]
			paragraphs_container.add_child(card) #[cite: 2]


func _make_paragraph_card(text: String, translation: String, sentences: Array) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var card_style := _make_paragraph_style()
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
	rtl.add_theme_color_override("default_color", Global.get_theme_color("text"))
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
	translation_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
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
		"translation_label": translation_label,
		"card": card
	})
	return card

# ---------- Theme helpers ----------
func _card_bg() -> Color:
	# Card background resolves through Global (theme surface).
	return Global.get_theme_color("surface")

func _make_paragraph_style() -> StyleBoxFlat:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color                   = _card_bg()
	card_style.corner_radius_top_left     = 20
	card_style.corner_radius_top_right    = 20
	card_style.corner_radius_bottom_left  = 20
	card_style.corner_radius_bottom_right = 20
	card_style.border_width_left          = 5
	card_style.border_color               = PARA_BORDER_COLOR
	card_style.content_margin_left        = 28
	card_style.content_margin_right       = 28
	card_style.content_margin_top         = 22
	card_style.content_margin_bottom      = 22
	card_style.shadow_color               = Color(0, 0, 0, 0.45)
	card_style.shadow_size                = 10
	card_style.shadow_offset              = Vector2(0, 6)
	return card_style

# Restyle the reading widgets on theme toggle (and once at startup).
func _apply_theme() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(reading_title_label):
		reading_title_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	for item in paragraph_rtls:
		var rtl: RichTextLabel = item.get("rtl")
		if is_instance_valid(rtl):
			rtl.add_theme_color_override("default_color", Global.get_theme_color("text"))
		var tl: Label = item.get("translation_label")
		if is_instance_valid(tl):
			tl.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
		var card: PanelContainer = item.get("card")
		if is_instance_valid(card):
			card.add_theme_stylebox_override("panel", _make_paragraph_style())

func _update_audio_sync(current_time: float) -> void:
	var active_sentence: Dictionary = _find_active_sentence(current_time) #[cite: 2]
	if not _is_same_sentence(active_sentence, _last_active_sentence): #[cite: 2]
		_last_active_sentence = active_sentence #[cite: 2]
		_refresh_all_text() #[cite: 2]


## Time-ordered sentence lookup with a forward-advancing cursor (O(1) per
## frame on forward playback) instead of scanning the whole array every frame.
func _find_active_sentence(current_time: float) -> Dictionary: #[cite: 2]
	var arr: Array = all_sentences_sync #[cite: 2]
	if arr.is_empty(): #[cite: 2]
		_sync_index = 0 #[cite: 2]
		return {} #[cite: 2]
	if _sync_index >= arr.size(): #[cite: 2]
		_sync_index = arr.size() - 1 #[cite: 2]
	if current_time < float(arr[_sync_index].get("start", 0.0)): #[cite: 2]
		_sync_index = 0 # backward seek — restart the scan #[cite: 2]
	while _sync_index < arr.size() \
			and current_time > float(arr[_sync_index].get("end", 0.0)): #[cite: 2]
		_sync_index += 1 #[cite: 2]
	if _sync_index >= arr.size(): #[cite: 2]
		_sync_index = arr.size() - 1 #[cite: 2]
		return {} #[cite: 2]
	var s: Dictionary = arr[_sync_index] #[cite: 2]
	if current_time >= float(s.get("start", 0.0)) \
			and current_time <= float(s.get("end", 0.0)): #[cite: 2]
		return s #[cite: 2]
	return {} #[cite: 2]


func _is_same_sentence(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() and b.is_empty(): return true #[cite: 2]
	if a.is_empty() or b.is_empty(): return false #[cite: 2]
	return a["block_idx"] == b["block_idx"] and a["sentence_idx"] == b["sentence_idx"] #[cite: 2]


func _refresh_all_text() -> void:
	for block_idx in range(paragraph_rtls.size()): #[cite: 2]
		var block = paragraph_rtls[block_idx] #[cite: 2]
		var rtl: RichTextLabel = block["rtl"] #[cite: 2]
		var sentences: Array = block["sentences"] #[cite: 2]
		var new_bbcode = "" #[cite: 2]
		for s_idx in range(sentences.size()): #[cite: 2]
			var s = sentences[s_idx] #[cite: 2]
			var en_text = s.get("en", "") #[cite: 2]
			var clickable_sentence = _format_clickable_text(en_text, current_highlighted_word) #[cite: 2]
			if _last_active_sentence.has("block_idx") and _last_active_sentence["block_idx"] == block_idx and _last_active_sentence["sentence_idx"] == s_idx: #[cite: 2]
				# Read-along sentence highlight: opaque bright amber + dark text in
				# dark theme so it stands out; light theme keeps the soft light-blue
				# tint, which already reads well.
				if Global.theme_is_dark():
					new_bbcode += "[bgcolor=#fbbf24][color=#111111]" + clickable_sentence + "[/color][/bgcolor] " #[cite: 2]
				else:
					new_bbcode += "[bgcolor=#bfdbfe]" + clickable_sentence + "[/bgcolor] " #[cite: 2]
			else: #[cite: 2]
				new_bbcode += clickable_sentence + " " #[cite: 2]
		rtl.text = new_bbcode.strip_edges() #[cite: 2]


# ============================================================
# DICTIONARY POPUP & TOGGLES
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

		# Make the meta safe for BBCode attributes.
		var safe_meta := _encode_word_meta(word)

		if normalized_highlight != "" and _normalize_word(word) == normalized_highlight:
			# Reading highlight color from your existing HIGHLIGHT_COLOR.
			out += "[bgcolor=#fef08a][color=#000000][url=%s]%s[/url][/color][/bgcolor]" % [
				safe_meta, word
			]
		else:
			out += "[url=%s]%s[/url]" % [
				safe_meta, word
			]

		last_end = end

	# Add anything after the last matched word.
	out += base_text.substr(last_end, base_text.length() - last_end)

	return out

func _normalize_word(word: String) -> String:
	var normalized := word

	# Convert common apostrophe-like characters to ASCII apostrophe.
	normalized = normalized.replace(char(0x2018), "'")  # ‘
	normalized = normalized.replace(char(0x2019), "'")  # ’
	normalized = normalized.replace(char(0x00B4), "'")  # ´
	normalized = normalized.replace("`", "'")

	return normalized.to_lower()


func _encode_word_meta(word: String) -> String:
	# Safe meta for RichTextLabel BBCode.
	# Do not put raw apostrophes inside [url=...].
	return _normalize_word(word).replace("'", "%27")

func _on_word_clicked(meta: Variant, _clicked_rtl: RichTextLabel, _original_text: String) -> void:
	var press_duration := (Time.get_ticks_msec() / 1000.0) - _touch_start_time

	if _is_drag_scrolling or _touch_max_distance > 15.0 or press_duration > 0.35:
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
	current_highlighted_word = "" #[cite: 2]
	_refresh_all_text() #[cite: 2]


func _update_toggle_button_text() -> void:
	Global.set_translation_toggle_state(translation_toggle, show_translation)


func _on_translation_toggle_pressed() -> void:
	show_translation = !show_translation #[cite: 2]
	_update_toggle_button_text() #[cite: 2]
	
	for item in paragraph_rtls: #[cite: 2]
		if item.has("translation_label") and item["translation_label"] != null: #[cite: 2]
			item["translation_label"].visible = show_translation #[cite: 2]
			
	for node in strategy_fa_nodes: #[cite: 2]
		if is_instance_valid(node): #[cite: 2]
			node.visible = show_translation #[cite: 2]


# ============================================================
# READING STRATEGY BUILDERS
# ============================================================
func _build_banner(strategy: Dictionary, th: Dictionary) -> void:
	var accent: Color = th["accent"] #[cite: 2]
	var banner := PanelContainer.new() #[cite: 2]
	var style := StyleBoxFlat.new() #[cite: 2]
	style.bg_color = accent #[cite: 2]
	style.set_corner_radius_all(20) #[cite: 2]
	style.set_content_margin_all(28) #[cite: 2]
	banner.add_theme_stylebox_override("panel", style) #[cite: 2]
	
	var vbox := VBoxContainer.new() #[cite: 2]
	vbox.add_theme_constant_override("separation", 12) #[cite: 2]
	
	var icon := Label.new() #[cite: 2]
	icon.name = "BannerIcon" #[cite: 2]
	icon.text = str(th["icon"]) #[cite: 2]
	icon.add_theme_font_size_override("font_size", 84) #[cite: 2]
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER #[cite: 2]
	vbox.add_child(icon) #[cite: 2]
	
	var name_en := Label.new() #[cite: 2]
	name_en.text = strategy["name"]["en"] #[cite: 2]
	name_en.autowrap_mode = TextServer.AUTOWRAP_WORD #[cite: 2]
	name_en.add_theme_font_size_override("font_size", 56) #[cite: 2]
	name_en.add_theme_color_override("font_color", Color.WHITE) #[cite: 2]
	name_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER #[cite: 2]
	if font_bold: name_en.add_theme_font_override("font", font_bold) #[cite: 2]
	vbox.add_child(name_en) #[cite: 2]
	
	if strategy["name"].has("fa"): #[cite: 2]
		var name_fa := Label.new() #[cite: 2]
		name_fa.text = strategy["name"]["fa"] #[cite: 2]
		name_fa.add_theme_font_size_override("font_size", 40) #[cite: 2]
		name_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.85)) #[cite: 2]
		name_fa.text_direction = Control.TEXT_DIRECTION_RTL #[cite: 2]
		name_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER #[cite: 2]
		if font_farsi: name_fa.add_theme_font_override("font", font_farsi) #[cite: 2]
		name_fa.visible = show_translation #[cite: 2]
		strategy_fa_nodes.append(name_fa) #[cite: 2]
		vbox.add_child(name_fa) #[cite: 2]
	
	var desc_en := Label.new() #[cite: 2]
	desc_en.text = strategy["description"]["en"] #[cite: 2]
	desc_en.autowrap_mode = TextServer.AUTOWRAP_WORD #[cite: 2]
	desc_en.add_theme_font_size_override("font_size", 36) #[cite: 2]
	desc_en.add_theme_color_override("font_color", Color(1, 1, 1, 0.95)) #[cite: 2]
	if font_regular: desc_en.add_theme_font_override("font", font_regular) #[cite: 2]
	vbox.add_child(desc_en) #[cite: 2]
	
	if strategy["description"].has("fa"): #[cite: 2]
		var desc_fa := Label.new() #[cite: 2]
		desc_fa.text = strategy["description"]["fa"] #[cite: 2]
		desc_fa.autowrap_mode = TextServer.AUTOWRAP_WORD #[cite: 2]
		desc_fa.add_theme_font_size_override("font_size", 34) #[cite: 2]
		desc_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.8)) #[cite: 2]
		desc_fa.text_direction = Control.TEXT_DIRECTION_RTL #[cite: 2]
		desc_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT #[cite: 2]
		if font_farsi: desc_fa.add_theme_font_override("font", font_farsi) #[cite: 2]
		desc_fa.visible = show_translation #[cite: 2]
		strategy_fa_nodes.append(desc_fa) #[cite: 2]
		vbox.add_child(desc_fa) #[cite: 2]
	
	banner.add_child(vbox) #[cite: 2]
	content_layout.add_child(banner) #[cite: 2]
	_reveal_cards.append(banner) #[cite: 2]


func _build_steps(strategy: Dictionary, th: Dictionary) -> void:
	var steps: Array = strategy.get("steps", []) #[cite: 2]
	if steps.is_empty(): return #[cite: 2]
	var accent: Color = th["accent"] #[cite: 2]
	var soft: Color = th["soft"] #[cite: 2]
	
	content_layout.add_child(_make_section_title("How to do it", "چگونه انجام دهیم", accent)) #[cite: 2]
	
	var timeline := VBoxContainer.new() #[cite: 2]
	timeline.add_theme_constant_override("separation", 0) #[cite: 2]
	
	for i in steps.size(): #[cite: 2]
		var row := HBoxContainer.new() #[cite: 2]
		row.add_theme_constant_override("separation", 18) #[cite: 2]
		
		var rail := VBoxContainer.new() #[cite: 2]
		rail.add_theme_constant_override("separation", 0) #[cite: 2]
		rail.custom_minimum_size = Vector2(56, 0) #[cite: 2]
		
		var circle := Label.new() #[cite: 2]
		circle.text = str(i + 1) #[cite: 2]
		circle.add_theme_font_size_override("font_size", 32) #[cite: 2]
		circle.add_theme_color_override("font_color", Color.WHITE) #[cite: 2]
		circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER #[cite: 2]
		circle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER #[cite: 2]
		var c_style := StyleBoxFlat.new() #[cite: 2]
		c_style.bg_color = accent #[cite: 2]
		c_style.set_corner_radius_all(28) #[cite: 2]
		c_style.set_content_margin_all(12) #[cite: 2]
		circle.add_theme_stylebox_override("normal", c_style) #[cite: 2]
		if font_bold: circle.add_theme_font_override("font", font_bold) #[cite: 2]
		rail.add_child(circle) #[cite: 2]
		
		if i < steps.size() - 1: #[cite: 2]
			var connector := ColorRect.new() #[cite: 2]
			connector.color = accent.lightened(0.6) #[cite: 2]
			connector.custom_minimum_size = Vector2(3, 0) #[cite: 2]
			connector.size_flags_vertical = Control.SIZE_EXPAND_FILL #[cite: 2]
			connector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER #[cite: 2]
			rail.add_child(connector) #[cite: 2]
		
		var card := _make_soft_card(soft, accent) #[cite: 2]
		var step_vbox := VBoxContainer.new() #[cite: 2]
		step_vbox.add_theme_constant_override("separation", 6) #[cite: 2]
		
		var en := Label.new() #[cite: 2]
		en.text = steps[i]["en"] #[cite: 2]
		en.autowrap_mode = TextServer.AUTOWRAP_WORD #[cite: 2]
		en.add_theme_font_size_override("font_size", 38) #[cite: 2]
		en.add_theme_color_override("font_color", Global.get_theme_color("text")) #[cite: 2]
		if font_regular: en.add_theme_font_override("font", font_regular) #[cite: 2]
		step_vbox.add_child(en) #[cite: 2]
		
		var fa := Label.new() #[cite: 2]
		fa.text = steps[i]["fa"] #[cite: 2]
		fa.autowrap_mode = TextServer.AUTOWRAP_WORD #[cite: 2]
		fa.add_theme_font_size_override("font_size", 34) #[cite: 2]
		fa.add_theme_color_override("font_color", Global.get_theme_color("text_dim")) #[cite: 2]
		fa.text_direction = Control.TEXT_DIRECTION_RTL #[cite: 2]
		fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT #[cite: 2]
		if font_farsi: fa.add_theme_font_override("font", font_farsi) #[cite: 2]
		fa.visible = show_translation #[cite: 2]
		strategy_fa_nodes.append(fa) #[cite: 2]
		step_vbox.add_child(fa) #[cite: 2]
		
		card.add_child(step_vbox) #[cite: 2]
		_add_hover_lift(card) #[cite: 2]
		
		row.add_child(rail) #[cite: 2]
		row.add_child(card) #[cite: 2]
		timeline.add_child(row) #[cite: 2]
		_reveal_cards.append(row) #[cite: 2]
	
	content_layout.add_child(timeline) #[cite: 2]

func _build_reference_materials(strategy: Dictionary, th: Dictionary) -> void:
	var accent: Color = th["accent"] #[cite: 2]
	var soft: Color = th["soft"] #[cite: 2]
	
	if strategy.has("question_starters"): #[cite: 2]
		content_layout.add_child(_make_section_title("Question Starters", "کلمات پرسشی", accent)) #[cite: 2]
		var flow := HFlowContainer.new() #[cite: 2]
		flow.add_theme_constant_override("separation", 12) #[cite: 2]
		for qs in strategy["question_starters"]: #[cite: 2]
			flow.add_child(_make_chip( #[cite: 2]
				qs["starter"] + "  →  " + qs["answer_type"]["en"], #[cite: 2]
				qs["fa"] + "  →  " + qs["answer_type"]["fa"], #[cite: 2]
				accent, soft)) #[cite: 2]
		content_layout.add_child(flow) #[cite: 2]
		_reveal_cards.append(flow) #[cite: 2]
	
	if strategy.has("common_reference_words"): #[cite: 2]
		content_layout.add_child(_make_section_title("Common Reference Words", "کلمات ارجاعی رایج", accent)) #[cite: 2]
		var flow := HFlowContainer.new() #[cite: 2]
		flow.add_theme_constant_override("separation", 12) #[cite: 2]
		for rw in strategy["common_reference_words"]: #[cite: 2]
			flow.add_child(_make_chip(rw["en"], rw["fa"], accent, soft)) #[cite: 2]
		content_layout.add_child(flow) #[cite: 2]
		_reveal_cards.append(flow) #[cite: 2]
	
	if strategy.has("useful_symbols"): #[cite: 2]
		content_layout.add_child(_make_section_title("Useful Symbols & Abbreviations", "نمادها و اختصارات", accent)) #[cite: 2]
		var flow := HFlowContainer.new() #[cite: 2]
		flow.add_theme_constant_override("separation", 12) #[cite: 2]
		for sym in strategy["useful_symbols"]: #[cite: 2]
			flow.add_child(_make_chip(sym["symbol"] + "  =  " + sym["meaning"]["en"], sym["meaning"]["fa"], accent, soft)) #[cite: 2]
		content_layout.add_child(flow) #[cite: 2]
		_reveal_cards.append(flow) #[cite: 2]
	
	if strategy.has("key_questions"): #[cite: 2]
		content_layout.add_child(_make_section_title("Ask Yourself", "از خود بپرسید", accent)) #[cite: 2]
		for kq in strategy["key_questions"]: #[cite: 2]
			var card := _make_soft_card(soft, accent) #[cite: 2]
			var vb := VBoxContainer.new() #[cite: 2]
			vb.add_theme_constant_override("separation", 6) #[cite: 2]
			var en := _make_label(kq["en"], 36, DesignTokens.INK, false) #[cite: 2]
			var fa := _make_label(kq["fa"], 33, Color("#64748B"), false) #[cite: 2]
			fa.text_direction = Control.TEXT_DIRECTION_RTL #[cite: 2]
			fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT #[cite: 2]
			if font_farsi: fa.add_theme_font_override("font", font_farsi) #[cite: 2]
			vb.add_child(en) #[cite: 2]
			vb.add_child(fa) #[cite: 2]
			card.add_child(vb) #[cite: 2]
			content_layout.add_child(card) #[cite: 2]
			_reveal_cards.append(card) #[cite: 2]


func _build_persian_insights(strategy: Dictionary, th: Dictionary) -> void:
	var accent: Color = th["accent"] #[cite: 2]
	
	var extra: Array = strategy.get("extra_fa", []) #[cite: 2]
	if not extra.is_empty(): #[cite: 2]
		content_layout.add_child(_make_section_title("بیشتر بدانید", "More to Know", accent, true)) #[cite: 2]
		for tip in extra: #[cite: 2]
			var card := _make_insight_card(str(tip), accent) #[cite: 2]
			content_layout.add_child(card) #[cite: 2]
			_reveal_cards.append(card) #[cite: 2]
	
	var tips: Array = strategy.get("tips_fa", []) #[cite: 2]
	if not tips.is_empty(): #[cite: 2]
		content_layout.add_child(_make_section_title("نکات کاربردی", "Practical Tips", accent, true)) #[cite: 2]
		for t in tips: #[cite: 2]
			var card := _make_insight_card("✅ " + str(t), accent) #[cite: 2]
			content_layout.add_child(card) #[cite: 2]
			_reveal_cards.append(card) #[cite: 2]


func _make_insight_card(text: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _card_bg()
	style.set_corner_radius_all(14)
	style.border_width_right = 5
	style.border_color = accent
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: label.add_theme_font_override("font", font_farsi)
	card.add_child(label)
	_add_hover_lift(card)
	return card

func _build_practice(exercises: Array, th: Dictionary) -> void:
	if exercises.is_empty(): return #[cite: 2]
	content_layout.add_child(_make_section_title("Practice", "تمرین", th["accent"])) #[cite: 2]
	for exercise in exercises: #[cite: 2]
		var engine := ExerciseEngine.new() #[cite: 2]
		content_layout.add_child(engine) #[cite: 2]
		engine.build(exercise) #[cite: 2]
		_reveal_cards.append(engine) #[cite: 2]


# ============================================================
# STRATEGY WIDGET HELPERS
# ============================================================
func _make_section_title(en: String, fa: String, accent: Color, rtl_primary := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(6, 44)
	row.add_child(bar)
	
	var title := Label.new()
	title.text = en if not rtl_primary else fa
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Global.get_theme_color("text"))
	if rtl_primary:
		title.text_direction = Control.TEXT_DIRECTION_RTL
		if font_farsi: title.add_theme_font_override("font", font_farsi)
	else:
		if font_bold: title.add_theme_font_override("font", font_bold)
	row.add_child(title)
	
	var sub := Label.new()
	sub.text = fa if not rtl_primary else en
	sub.add_theme_font_size_override("font_size", 32)
	sub.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	if not rtl_primary:
		if font_farsi: sub.add_theme_font_override("font", font_farsi)
	sub.visible = show_translation
	strategy_fa_nodes.append(sub)
	row.add_child(sub)
	
	return row

func _make_soft_card(_soft: Color, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface")
	style.set_corner_radius_all(14)
	style.border_width_left = 5
	style.border_color = accent
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)
	return card

func _make_chip(main: String, sub: String, accent: Color, _soft: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _card_bg()
	style.set_corner_radius_all(22)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = accent.lightened(0.2)
	style.set_content_margin_all(14)
	chip.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	
	var m := Label.new()
	m.text = main
	m.add_theme_font_size_override("font_size", 32)
	m.add_theme_color_override("font_color", accent)  # Vibrant accent
	if font_bold: m.add_theme_font_override("font", font_bold)
	
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 28)
	s.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	s.text_direction = Control.TEXT_DIRECTION_RTL
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: s.add_theme_font_override("font", font_farsi)
	s.visible = show_translation
	strategy_fa_nodes.append(s)
	
	vb.add_child(m)
	vb.add_child(s)
	chip.add_child(vb)
	_add_hover_lift(chip)
	return chip

func _make_label(text: String, font_size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold: l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular: l.add_theme_font_override("font", font_regular)
	return l

func _add_hover_lift(control: Control) -> void:
	control.mouse_entered.connect(func(): #[cite: 2]
		control.pivot_offset = control.size / 2.0 #[cite: 2]
		var t := create_tween() #[cite: 2]
		t.tween_property(control, "scale", Vector2(1.015, 1.015), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) #[cite: 2]
	) #[cite: 2]
	control.mouse_exited.connect(func(): #[cite: 2]
		control.pivot_offset = control.size / 2.0 #[cite: 2]
		var t := create_tween() #[cite: 2]
		t.tween_property(control, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) #[cite: 2]
	) #[cite: 2]


# ============================================================
# ENTRANCE ANIMATION — staggered reveal (strategy page)
# ============================================================
func _play_entrance() -> void:
	var icon := content_layout.find_child("BannerIcon", true, false) #[cite: 2]
	if icon: #[cite: 2]
		icon.pivot_offset = icon.size / 2.0 #[cite: 2]
		icon.scale = Vector2(0.5, 0.5) #[cite: 2]
		var pop := create_tween() #[cite: 2]
		pop.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) #[cite: 2]
	
	for i in _reveal_cards.size(): #[cite: 2]
		var card: Control = _reveal_cards[i] #[cite: 2]
		card.modulate.a = 0.0 #[cite: 2]
		var t := create_tween() #[cite: 2]
		t.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(0.08 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) #[cite: 2]


# ============================================================
# NEW REFACTORED AUDIO CONTROL
# ============================================================
func _on_audio_pressed() -> void:
	# Keep the bounce animation for the header button[cite: 2]
	var tween := create_tween() #[cite: 2]
	tween.tween_property(audio_button, "scale", Vector2(0.93, 0.93), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) #[cite: 2]
	tween.tween_property(audio_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) #[cite: 2]
	
	if not audio_panel.is_playing():
		var path: String = get_meta("audio_path", "")
		audio_panel.load_and_play(path)

func _on_audio_stopped() -> void:
	# Called when audio finishes OR user hits close[cite: 2]
	_last_active_sentence = {} #[cite: 2]
	_sync_index = 0 #[cite: 2]
	_refresh_all_text() #[cite: 2]


# ============================================================
# NAVIGATION
# ============================================================
func _on_home_pressed() -> void:
	audio_panel.stop_and_close()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_back_button_pressed() -> void:
	audio_panel.stop_and_close()
	TransitionManager.change_scene(SCENE_LESSON_MENU) #[cite: 2]


func _on_android_back_pressed() -> void:
	if dict_popup != null and dict_popup.is_open(): #[cite: 2]
		dict_popup._hide_popup() #[cite: 2]
	else:
		_on_back_button_pressed() #[cite: 2]
