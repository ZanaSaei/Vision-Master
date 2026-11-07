extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# READING SCENE — PageView Edition (Single Box Reading Layout)
# Three swipeable pages: Reading / Strategy / Practice
# Keeps: audio-text sync, dictionary popup, translation toggle,
#        clickable words, and the full Reading Strategy lesson.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Reading box accent colors
const PARA_BG_COLOR      := Color("#1a2f5c")
const PARA_BORDER_COLOR  := Color("#22D3EE")
const HIGHLIGHT_COLOR    := Color("#fbbf24")
const BACKGROUND_OPACITY := 0.08

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH := "res://ui/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH    := "res://ui/fonts/PlusJakartaSans-Bold.ttf"
const FONT_JAKARTA_ITALIC_PATH  := "res://ui/fonts/PlusJakartaSans-Italic.ttf"
const FONT_VAZIRMATN            := "res://ui/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_italic: FontFile
var font_farsi: FontFile

# ---------- Per-strategy visual theme (from Reading Strategy scene) ----------
const STRATEGY_THEMES := {
	"Scanning":                    { "accent": Color("#22D3EE"), "soft": Color("#1a2f5c"), "icon": "🔍" },
	"Skimming":                    { "accent": Color("#34D399"), "soft": Color("#1a2d2a"), "icon": "📖" },
	"Recognizing Reference Words": { "accent": Color("#EC4899"), "soft": Color("#2d1f4e"), "icon": "🔗" },
	"Question Generation":         { "accent": Color("#FBBF24"), "soft": Color("#2d2a1f"), "icon": "❓" },
	"Highlighting":                { "accent": Color("#A78BFA"), "soft": Color("#2d1f4e"), "icon": "🖍️" },
	"Note Taking":                 { "accent": Color("#34D399"), "soft": Color("#1a2d2a"), "icon": "📝" },
}
const DEFAULT_THEME := { "accent": Color("#22D3EE"), "soft": Color("#1a2f5c"), "icon": "🎯" }

# Touch tracking variables for mobile scrolling & word tap detection
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_drag_scrolling: bool = false
var _touch_start_time: float = 0.0
var _touch_max_distance: float = 0.0

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var header_bar: Control              = $HeaderBar
@onready var header_content: HBoxContainer    = $HeaderBar/HeaderContent
@onready var back_button: Button              = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button              = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label              = $HeaderBar/HeaderContent/HeaderTitle
@onready var audio_button: Button             = $HeaderBar/HeaderContent/AudioButton
@onready var translation_toggle: Button       = $HeaderBar/HeaderContent/TranslationToggleButton
@onready var background_image: TextureRect    = $BackgroundImage
@onready var page_view: PageView              = $MarginContainer/MainLayout/PageView
@onready var audio_panel: PanelContainer      = $AudioPanel

# Reading page widgets (Single-box architecture)
var reading_image: TextureRect
var reading_title_label: Label
var author_label: Label
var hero_container: VBoxContainer
var reading_panel: PanelContainer
var reading_rtl: RichTextLabel
var reading_translation_label: Label
var raw_paragraphs_data: Array = []

# Collapsing cover state
const HERO_MAX_HEIGHT := 520.0
var _hero_collapse_progress: float = 0.0 # 0.0 = expanded, 1.0 = collapsed

# Strategy page widgets
var content_layout: VBoxContainer
var _strategy_entrance_played := false
var _reveal_cards: Array[Control] = []
var strategy_fa_nodes: Array[Control] = []

# Dictionary / Popup Variables
var word_regex := RegEx.new()
var current_word_data: Dictionary = {}
var current_highlighted_word: String = ""

# Audio Sync Variables
var all_sentences_sync: Array = []
var _last_active_sentence: Dictionary = {}
var _sync_index: int = 0
var dict_popup: DictionaryPopup

# Translation toggle
var show_translation: bool = false

# Store current lesson data
var current_book: int = 0
var current_lesson: int = 0


# ============================================================
# READY — build the three pages
# ============================================================
func _ready() -> void:
	page_view.add_swipe_blocker(audio_panel)
	page_view.add_swipe_blocker(header_bar)
	
	var apostrophes := "'%s%s" % [char(0x2018), char(0x2019)]
	word_regex.compile("\\b([a-zA-Z]+(?:[%s-][a-zA-Z]+)*)\\b" % apostrophes)
	_load_fonts()
	if font_bold:
		header_title.add_theme_font_override("font", font_bold)
	
	dict_popup = DictionaryPopup.new()
	add_child(dict_popup)
	dict_popup.popup_closed.connect(_on_popup_closed)
	
	_configure_background_image()
	
	# General UI Connections
	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	translation_toggle.pressed.connect(_on_translation_toggle_pressed)
	page_view.page_changed.connect(_on_page_changed)
	
	# Audio Panel Connections
	audio_panel.playback_updated.connect(_update_audio_sync)
	audio_panel.audio_closed.connect(_on_audio_stopped)
	audio_panel.audio_finished.connect(_on_audio_stopped)
	
	current_book = Global.current_book
	current_lesson = Global.current_lesson
	
	header_title.text = MenuStyle.persian_digits("درس %d\nخواندن" % current_lesson)
	Content.ensure_lesson(current_book, current_lesson)
	
	var data: Dictionary          = Global.load_reading(current_book, current_lesson)
	var strategy_data: Dictionary = Global.load_category("reading_strategies", current_book, current_lesson)
	var comp_data: Dictionary     = Global.load_category("reading_comprehension", current_book, current_lesson)
	
	# Build the three pages
	_build_reading_page(data)
	_build_strategy_page(strategy_data) # adds a page only for Vision 2 & 3
	_build_comprehension_page(comp_data)
	
	_update_toggle_button_text()
	
	Global.on_theme_changed(_apply_theme)
	_apply_theme()


# ============================================================
# PAGE BUILDERS
# ============================================================
func _make_page_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 200) # clears the audio panel
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


# ---------- PAGE 1: READING (Single Box) ----------
func _build_reading_page(data: Dictionary) -> void:
	var page := VBoxContainer.new()
	page.name = "ReadingPage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 20)
	
	# 1. Collapsible Hero Section (Cover Image + Title + Metadata)
	hero_container = VBoxContainer.new()
	hero_container.name = "HeroContainer"
	hero_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_container.add_theme_constant_override("separation", 14)
	hero_container.clip_contents = true
	
	reading_image = TextureRect.new()
	reading_image.name = "SharpCover"
	_configure_main_image()
	hero_container.add_child(reading_image)
	
	var title_box := VBoxContainer.new()
	title_box.name = "TitleSection"
	title_box.add_theme_constant_override("separation", 6)
	
	reading_title_label = Label.new()
	reading_title_label.name = "ReadingTitleLabel"
	reading_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reading_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reading_title_label.add_theme_font_size_override("font_size", 54)
	reading_title_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	if font_bold:
		reading_title_label.add_theme_font_override("font", font_bold)
	title_box.add_child(reading_title_label)
	
	author_label = Label.new()
	author_label.name = "AuthorLabel"
	author_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	author_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author_label.add_theme_font_size_override("font_size", 30)
	author_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	if font_regular:
		author_label.add_theme_font_override("font", font_regular)
	author_label.visible = false
	title_box.add_child(author_label)
	
	hero_container.add_child(title_box)
	page.add_child(hero_container)
	
	# 2. Single Unified Reading Box
	reading_panel = PanelContainer.new()
	reading_panel.name = "ReadingPanel"
	reading_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	reading_panel.add_theme_stylebox_override("panel", _make_reading_panel_style())
	
	var box_vbox := VBoxContainer.new()
	box_vbox.name = "ReadingBoxContent"
	box_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	box_vbox.add_theme_constant_override("separation", 24)
	
	reading_rtl = RichTextLabel.new()
	reading_rtl.name = "ReadingRichText"
	reading_rtl.meta_underlined = false
	reading_rtl.bbcode_enabled = true
	reading_rtl.fit_content = true
	reading_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD
	reading_rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	reading_rtl.scroll_active = false
	reading_rtl.selection_enabled = false
	reading_rtl.add_theme_font_size_override("normal_font_size", 55)
	reading_rtl.add_theme_color_override("default_color", Global.get_theme_color("text"))
	reading_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_regular != null:
		reading_rtl.add_theme_font_override("normal_font", font_regular)
	if font_bold != null:
		reading_rtl.add_theme_font_override("bold_font", font_bold)
	reading_rtl.meta_clicked.connect(func(meta): _on_word_clicked(meta))
	
	reading_translation_label = Label.new()
	reading_translation_label.name = "ReadingTranslationLabel"
	reading_translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reading_translation_label.add_theme_font_size_override("font_size", 45)
	reading_translation_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	reading_translation_label.text_direction = Control.TEXT_DIRECTION_RTL
	reading_translation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reading_translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_farsi != null:
		reading_translation_label.add_theme_font_override("font", font_farsi)
	reading_translation_label.visible = show_translation
	
	box_vbox.add_child(reading_rtl)
	box_vbox.add_child(reading_translation_label)
	reading_panel.add_child(box_vbox)
	page.add_child(reading_panel)
	
	# 3. Bottom Spacer for Audio Panel
	page.add_child(_make_page_spacer())
	
	# 4. Populate Data
	if data.is_empty():
		reading_title_label.text = "Reading not available yet."
		reading_image.visible = false
		reading_panel.visible = false
	else:
		_build_reading(current_book, current_lesson, data)
	
	page_view.add_page("reading", "خواندن", "📖", page)


# ---------- PAGE 2: STRATEGY (Vision 2 & 3 only) ----------
func _build_strategy_page(data: Dictionary) -> void:
	if data.is_empty() or not data.has("strategy"):
		return
	
	strategy_fa_nodes.clear()
	_reveal_cards.clear()
	
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	content_layout = page
	
	var strategy: Dictionary = data["strategy"]
	var strategy_name: String = strategy.get("name", {}).get("en", "")
	var strategy_theme: Dictionary = STRATEGY_THEMES.get(strategy_name, DEFAULT_THEME)
	
	_build_banner(strategy, strategy_theme)
	_build_steps(strategy, strategy_theme)
	_build_reference_materials(strategy, strategy_theme)
	_build_persian_insights(strategy, strategy_theme)
	_build_practice(data.get("exercises", []), strategy_theme)
	page.add_child(_make_page_spacer())
	
	page_view.add_page("strategy", "راهبرد", "🎯", page)


# ---------- PAGE 3: COMPREHENSION ----------
func _build_comprehension_page(data: Dictionary) -> void:
	if data.is_empty() or data.get("exercises", []).is_empty():
		return
	
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	
	for exercise in data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
		engine.exercise_checked.connect(_on_exercise_checked)
	
	page.add_child(_make_page_spacer())
	page_view.add_page("practice", "تمرین", "✏️", page)


# ---------- Replay strategy entrance the first time it's opened ----------
func _on_page_changed(_index: int, page_id: String) -> void:
	if dict_popup != null and dict_popup.is_open():
		dict_popup._hide_popup()
		
	if page_id == "strategy" and not _strategy_entrance_played:
		_strategy_entrance_played = true
		_play_entrance()


func _on_exercise_checked(exercise_id: String, correct: int, total: int) -> void:
	print("%s → %d/%d" % [exercise_id, correct, total])


# ============================================================
# INPUT & COLLAPSING COVER ANIMATION
# ============================================================
func _input(event: InputEvent) -> void:
	super._input(event)
	
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
			_touch_max_distance = 0.0
			_is_drag_scrolling = false
		else:
			if _touch_start_pos.distance_to(event.position) > 15.0:
				_is_drag_scrolling = true
				
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_update_hero_collapse(-60.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_update_hero_collapse(60.0)
			
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var dist := _touch_start_pos.distance_to(event.position)
		if dist > _touch_max_distance:
			_touch_max_distance = dist
		if dist > 15.0:
			_is_drag_scrolling = true
			_update_hero_collapse(event.relative.y)


func _update_hero_collapse(scroll_delta: float) -> void:
	if not is_instance_valid(reading_image) or not reading_image.visible:
		return
	
	var delta_progress := -scroll_delta / HERO_MAX_HEIGHT
	_hero_collapse_progress = clampf(_hero_collapse_progress + delta_progress, 0.0, 1.0)
	
	var current_h := lerpf(HERO_MAX_HEIGHT, 0.0, _hero_collapse_progress)
	reading_image.custom_minimum_size.y = current_h
	reading_image.modulate.a = 1.0 - (_hero_collapse_progress * 0.85)


# ============================================================
# IMAGE / FONT CONFIG
# ============================================================
func _configure_main_image() -> void:
	reading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reading_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reading_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_image.custom_minimum_size = Vector2(0, HERO_MAX_HEIGHT)
	reading_image.mouse_filter = Control.MOUSE_FILTER_IGNORE


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


# ============================================================
# DATA LOADING & SINGLE-BOX TEXT BUILDING
# ============================================================
func _build_reading(_book: int, _lesson: int, data: Dictionary) -> void:
	all_sentences_sync.clear()
	_sync_index = 0
	_hero_collapse_progress = 0.0
	
	var image_filename: String = data.get("image", "") as String
	if image_filename != "" and ResourceLoader.exists(image_filename):
		var tex: Texture2D = load(image_filename)
		background_image.texture = tex
		background_image.visible = true
		reading_image.texture = tex
		reading_image.visible = true
		reading_image.custom_minimum_size = Vector2(0, HERO_MAX_HEIGHT)
		reading_image.modulate.a = 1.0
	else:
		background_image.visible = false
		reading_image.visible = false
		reading_image.custom_minimum_size = Vector2.ZERO
	
	var title: String = data.get("title", "") as String
	reading_title_label.text = title
	reading_title_label.visible = title != ""
	
	var author: String = data.get("author", "") as String
	if is_instance_valid(author_label):
		author_label.text = author
		author_label.visible = author != ""
	
	var paragraphs: Array = data.get("paragraphs", []) as Array
	_build_single_reading_box(paragraphs)
	
	var audio_path: String = data.get("audio", "") as String
	set_meta("audio_path", audio_path)


func _build_single_reading_box(paragraphs: Array) -> void:
	raw_paragraphs_data.clear()
	var fa_blocks: PackedStringArray = []
	
	for p_idx in range(paragraphs.size()):
		var para_obj: Dictionary = paragraphs[p_idx] as Dictionary
		if para_obj.is_empty():
			continue
		var sentences: Array = para_obj.get("sentences", []) as Array
		if sentences.is_empty():
			continue
			
		var block_idx: int = raw_paragraphs_data.size()
		raw_paragraphs_data.append(sentences)
		
		var para_fa := ""
		for s_idx in range(sentences.size()):
			var sentence: Dictionary = sentences[s_idx]
			var fa_str: String = sentence.get("fa", "").strip_edges()
			if fa_str != "":
				para_fa += fa_str + " "
			if sentence.has("start") and sentence.has("end"):
				all_sentences_sync.append({
					"block_idx": block_idx,
					"sentence_idx": s_idx,
					"start": sentence.get("start", 0.0),
					"end": sentence.get("end", 0.0)
				})
		para_fa = para_fa.strip_edges()
		if para_fa != "":
			fa_blocks.append(para_fa)
			
	if is_instance_valid(reading_translation_label):
		reading_translation_label.text = "\n\n".join(fa_blocks)
		
	_refresh_all_text()


# ---------- Theme helpers ----------
func _card_bg() -> Color:
	return Global.get_theme_color("surface")


func _make_reading_panel_style() -> StyleBoxFlat:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color                   = _card_bg()
	card_style.corner_radius_top_left     = 28
	card_style.corner_radius_top_right    = 28
	card_style.corner_radius_bottom_left  = 24
	card_style.corner_radius_bottom_right = 24
	card_style.border_width_left          = 5
	card_style.border_color               = PARA_BORDER_COLOR
	card_style.content_margin_left        = 28
	card_style.content_margin_right       = 28
	card_style.content_margin_top         = 26
	card_style.content_margin_bottom      = 26
	card_style.shadow_color               = Color(0, 0, 0, 0.45)
	card_style.shadow_size                = 10
	card_style.shadow_offset              = Vector2(0, 6)
	return card_style


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(reading_title_label):
		reading_title_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	if is_instance_valid(author_label):
		author_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	if is_instance_valid(reading_panel):
		reading_panel.add_theme_stylebox_override("panel", _make_reading_panel_style())
	if is_instance_valid(reading_rtl):
		reading_rtl.add_theme_color_override("default_color", Global.get_theme_color("text"))
	if is_instance_valid(reading_translation_label):
		reading_translation_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	
	_refresh_all_text()


func _update_audio_sync(current_time: float) -> void:
	var active_sentence: Dictionary = _find_active_sentence(current_time)
	if not _is_same_sentence(active_sentence, _last_active_sentence):
		_last_active_sentence = active_sentence
		_refresh_all_text()


## Time-ordered sentence lookup with a forward-advancing cursor (O(1) per
## frame on forward playback) instead of scanning the whole array every frame.
func _find_active_sentence(current_time: float) -> Dictionary:
	var arr: Array = all_sentences_sync
	if arr.is_empty():
		_sync_index = 0
		return {}
	if _sync_index >= arr.size():
		_sync_index = arr.size() - 1
	if current_time < float(arr[_sync_index].get("start", 0.0)):
		_sync_index = 0 # backward seek — restart the scan
	while _sync_index < arr.size() \
			and current_time > float(arr[_sync_index].get("end", 0.0)):
		_sync_index += 1
	if _sync_index >= arr.size():
		_sync_index = arr.size() - 1
		return {}
	var s: Dictionary = arr[_sync_index]
	if current_time >= float(s.get("start", 0.0)) \
			and current_time <= float(s.get("end", 0.0)):
		return s
	return {}


func _is_same_sentence(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() and b.is_empty():
		return true
	if a.is_empty() or b.is_empty():
		return false
	return a["block_idx"] == b["block_idx"] and a["sentence_idx"] == b["sentence_idx"]


func _refresh_all_text() -> void:
	if not is_instance_valid(reading_rtl):
		return
		
	var paragraph_bbcodes: PackedStringArray = []
	for block_idx in range(raw_paragraphs_data.size()):
		var sentences: Array = raw_paragraphs_data[block_idx]
		var para_bbcode := ""
		for s_idx in range(sentences.size()):
			var s: Dictionary = sentences[s_idx]
			var en_text: String = s.get("en", "").strip_edges()
			if en_text == "":
				continue
			var clickable_sentence := _format_clickable_text(en_text, current_highlighted_word)
			if _last_active_sentence.has("block_idx") and _last_active_sentence["block_idx"] == block_idx and _last_active_sentence["sentence_idx"] == s_idx:
				if Global.theme_is_dark():
					para_bbcode += "[bgcolor=#fbbf24][color=#111111]" + clickable_sentence + "[/color][/bgcolor] "
				else:
					para_bbcode += "[bgcolor=#bfdbfe]" + clickable_sentence + "[/bgcolor] "
			else:
				para_bbcode += clickable_sentence + " "
		para_bbcode = para_bbcode.strip_edges()
		if para_bbcode != "":
			paragraph_bbcodes.append(para_bbcode)
			
	reading_rtl.text = "\n\n".join(paragraph_bbcodes)


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

		out += base_text.substr(last_end, start - last_end)
		var safe_meta := _encode_word_meta(word)

		if normalized_highlight != "" and _normalize_word(word) == normalized_highlight:
			out += "[bgcolor=#fef08a][color=#000000][url=%s]%s[/url][/color][/bgcolor]" % [
				safe_meta, word
			]
		else:
			out += "[url=%s]%s[/url]" % [
				safe_meta, word
			]

		last_end = end

	out += base_text.substr(last_end, base_text.length() - last_end)
	return out


func _normalize_word(word: String) -> String:
	var normalized := word
	normalized = normalized.replace(char(0x2018), "'") # ‘
	normalized = normalized.replace(char(0x2019), "'") # ’
	normalized = normalized.replace(char(0x00B4), "'") # ´
	normalized = normalized.replace("`", "'")
	return normalized.to_lower()


func _encode_word_meta(word: String) -> String:
	return _normalize_word(word).replace("'", "%27")


func _on_word_clicked(meta: Variant) -> void:
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
	current_highlighted_word = ""
	_refresh_all_text()


func _update_toggle_button_text() -> void:
	Global.set_translation_toggle_state(translation_toggle, show_translation)


func _on_translation_toggle_pressed() -> void:
	show_translation = !show_translation
	_update_toggle_button_text()
	
	if is_instance_valid(reading_translation_label):
		reading_translation_label.visible = show_translation
			
	for node in strategy_fa_nodes:
		if is_instance_valid(node):
			node.visible = show_translation


# ============================================================
# READING STRATEGY BUILDERS
# ============================================================
func _build_banner(strategy: Dictionary, th: Dictionary) -> void:
	var accent: Color = th["accent"]
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	banner.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var icon := Label.new()
	icon.name = "BannerIcon"
	icon.text = str(th["icon"])
	icon.add_theme_font_size_override("font_size", 84)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)
	
	var name_en := Label.new()
	name_en.text = strategy["name"]["en"]
	name_en.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_en.add_theme_font_size_override("font_size", 56)
	name_en.add_theme_color_override("font_color", Color.WHITE)
	name_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold:
		name_en.add_theme_font_override("font", font_bold)
	vbox.add_child(name_en)
	
	if strategy["name"].has("fa"):
		var name_fa := Label.new()
		name_fa.text = strategy["name"]["fa"]
		name_fa.add_theme_font_size_override("font_size", 40)
		name_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		name_fa.text_direction = Control.TEXT_DIRECTION_RTL
		name_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font_farsi:
			name_fa.add_theme_font_override("font", font_farsi)
		name_fa.visible = show_translation
		strategy_fa_nodes.append(name_fa)
		vbox.add_child(name_fa)
	
	var desc_en := Label.new()
	desc_en.text = strategy["description"]["en"]
	desc_en.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_en.add_theme_font_size_override("font_size", 36)
	desc_en.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	if font_regular:
		desc_en.add_theme_font_override("font", font_regular)
	vbox.add_child(desc_en)
	
	if strategy["description"].has("fa"):
		var desc_fa := Label.new()
		desc_fa.text = strategy["description"]["fa"]
		desc_fa.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_fa.add_theme_font_size_override("font_size", 34)
		desc_fa.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		desc_fa.text_direction = Control.TEXT_DIRECTION_RTL
		desc_fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if font_farsi:
			desc_fa.add_theme_font_override("font", font_farsi)
		desc_fa.visible = show_translation
		strategy_fa_nodes.append(desc_fa)
		vbox.add_child(desc_fa)
	
	banner.add_child(vbox)
	content_layout.add_child(banner)
	_reveal_cards.append(banner)


func _build_steps(strategy: Dictionary, th: Dictionary) -> void:
	var steps: Array = strategy.get("steps", [])
	if steps.is_empty():
		return
	var accent: Color = th["accent"]
	var soft: Color = th["soft"]
	
	content_layout.add_child(_make_section_title("How to do it", "چگونه انجام دهیم", accent))
	
	var timeline := VBoxContainer.new()
	timeline.add_theme_constant_override("separation", 12)
	
	for i in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		
		var rail := VBoxContainer.new()
		rail.add_theme_constant_override("separation", 0)
		rail.custom_minimum_size = Vector2(56, 0)
		
		var circle := Label.new()
		circle.text = str(i + 1)
		circle.add_theme_font_size_override("font_size", 32)
		circle.add_theme_color_override("font_color", Color.WHITE)
		circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		circle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var c_style := StyleBoxFlat.new()
		c_style.bg_color = accent
		c_style.set_corner_radius_all(28)
		c_style.set_content_margin_all(12)
		circle.add_theme_stylebox_override("normal", c_style)
		if font_bold:
			circle.add_theme_font_override("font", font_bold)
		rail.add_child(circle)
		
		if i < steps.size() - 1:
			var connector := ColorRect.new()
			connector.color = accent.lightened(0.6)
			connector.custom_minimum_size = Vector2(3, 0)
			connector.size_flags_vertical = Control.SIZE_EXPAND_FILL
			connector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rail.add_child(connector)
		
		var card := _make_soft_card(soft, accent)
		var step_vbox := VBoxContainer.new()
		step_vbox.add_theme_constant_override("separation", 6)
		
		var en := Label.new()
		en.text = steps[i]["en"]
		en.autowrap_mode = TextServer.AUTOWRAP_WORD
		en.add_theme_font_size_override("font_size", 38)
		en.add_theme_color_override("font_color", Global.get_theme_color("text"))
		if font_regular:
			en.add_theme_font_override("font", font_regular)
		step_vbox.add_child(en)
		
		var fa := Label.new()
		fa.text = steps[i]["fa"]
		fa.autowrap_mode = TextServer.AUTOWRAP_WORD
		fa.add_theme_font_size_override("font_size", 34)
		fa.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
		fa.text_direction = Control.TEXT_DIRECTION_RTL
		fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if font_farsi:
			fa.add_theme_font_override("font", font_farsi)
		fa.visible = show_translation
		strategy_fa_nodes.append(fa)
		step_vbox.add_child(fa)
		
		card.add_child(step_vbox)
		_add_hover_lift(card)
		
		row.add_child(rail)
		row.add_child(card)
		timeline.add_child(row)
		_reveal_cards.append(row)
	
	content_layout.add_child(timeline)


func _build_reference_materials(strategy: Dictionary, th: Dictionary) -> void:
	var accent: Color = th["accent"]
	var soft: Color = th["soft"]
	
	if strategy.has("question_starters"):
		content_layout.add_child(_make_section_title("Question Starters", "کلمات پرسشی", accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 12)
		for qs in strategy["question_starters"]:
			flow.add_child(_make_chip(
				qs["starter"] + "  →  " + qs["answer_type"]["en"],
				qs["fa"] + "  →  " + qs["answer_type"]["fa"],
				accent, soft))
		content_layout.add_child(flow)
		_reveal_cards.append(flow)
	
	if strategy.has("common_reference_words"):
		content_layout.add_child(_make_section_title("Common Reference Words", "کلمات ارجاعی رایج", accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 12)
		for rw in strategy["common_reference_words"]:
			flow.add_child(_make_chip(rw["en"], rw["fa"], accent, soft))
		content_layout.add_child(flow)
		_reveal_cards.append(flow)
	
	if strategy.has("useful_symbols"):
		content_layout.add_child(_make_section_title("Useful Symbols & Abbreviations", "نمادها و اختصارات", accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 12)
		for sym in strategy["useful_symbols"]:
			flow.add_child(_make_chip(sym["symbol"] + "  =  " + sym["meaning"]["en"], sym["meaning"]["fa"], accent, soft))
		content_layout.add_child(flow)
		_reveal_cards.append(flow)
	
	if strategy.has("key_questions"):
		content_layout.add_child(_make_section_title("Ask Yourself", "از خود بپرسید", accent))
		for kq in strategy["key_questions"]:
			var card := _make_soft_card(soft, accent)
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 6)
			var en := _make_label(kq["en"], 36, Global.get_theme_color("text"), false)
			var fa := _make_label(kq["fa"], 33, Global.get_theme_color("text_dim"), false)
			fa.text_direction = Control.TEXT_DIRECTION_RTL
			fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if font_farsi:
				fa.add_theme_font_override("font", font_farsi)
			fa.visible = show_translation
			strategy_fa_nodes.append(fa)
			vb.add_child(en)
			vb.add_child(fa)
			card.add_child(vb)
			content_layout.add_child(card)
			_reveal_cards.append(card)


func _build_persian_insights(strategy: Dictionary, th: Dictionary) -> void:
	var accent: Color = th["accent"]
	
	var extra: Array = strategy.get("extra_fa", [])
	if not extra.is_empty():
		content_layout.add_child(_make_section_title("بیشتر بدانید", "More to Know", accent, true))
		for tip in extra:
			var card := _make_insight_card(str(tip), accent)
			content_layout.add_child(card)
			_reveal_cards.append(card)
	
	var tips: Array = strategy.get("tips_fa", [])
	if not tips.is_empty():
		content_layout.add_child(_make_section_title("نکات کاربردی", "Practical Tips", accent, true))
		for t in tips:
			var card := _make_insight_card("✅ " + str(t), accent)
			content_layout.add_child(card)
			_reveal_cards.append(card)


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
	if font_farsi:
		label.add_theme_font_override("font", font_farsi)
	card.add_child(label)
	_add_hover_lift(card)
	return card


func _build_practice(exercises: Array, th: Dictionary) -> void:
	if exercises.is_empty():
		return
	content_layout.add_child(_make_section_title("Practice", "تمرین", th["accent"]))
	for exercise in exercises:
		var engine := ExerciseEngine.new()
		content_layout.add_child(engine)
		engine.build(exercise)
		_reveal_cards.append(engine)


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
		if font_farsi:
			title.add_theme_font_override("font", font_farsi)
	else:
		if font_bold:
			title.add_theme_font_override("font", font_bold)
	row.add_child(title)
	
	var sub := Label.new()
	sub.text = fa if not rtl_primary else en
	sub.add_theme_font_size_override("font_size", 32)
	sub.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	if not rtl_primary and font_farsi:
		sub.add_theme_font_override("font", font_farsi)
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
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = accent.lightened(0.2)
	style.set_content_margin_all(14)
	chip.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	
	var m := Label.new()
	m.text = main
	m.add_theme_font_size_override("font_size", 32)
	m.add_theme_color_override("font_color", accent)
	if font_bold:
		m.add_theme_font_override("font", font_bold)
	
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 28)
	s.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	s.text_direction = Control.TEXT_DIRECTION_RTL
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi:
		s.add_theme_font_override("font", font_farsi)
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
	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)
	return l


func _add_hover_lift(control: Control) -> void:
	control.mouse_entered.connect(func():
		control.pivot_offset = control.size / 2.0
		var t := create_tween()
		t.tween_property(control, "scale", Vector2(1.015, 1.015), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	control.mouse_exited.connect(func():
		control.pivot_offset = control.size / 2.0
		var t := create_tween()
		t.tween_property(control, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)


# ============================================================
# ENTRANCE ANIMATION — staggered reveal (strategy page)
# ============================================================
func _play_entrance() -> void:
	var icon := content_layout.find_child("BannerIcon", true, false) as Control
	if icon:
		icon.pivot_offset = icon.size / 2.0
		icon.scale = Vector2(0.5, 0.5)
		var pop := create_tween()
		pop.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	for i in _reveal_cards.size():
		var card: Control = _reveal_cards[i]
		if not is_instance_valid(card):
			continue
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(0.08 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# AUDIO CONTROL
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
	_sync_index = 0
	_refresh_all_text()


# ============================================================
# NAVIGATION
# ============================================================
func _on_home_pressed() -> void:
	audio_panel.stop_and_close()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")


func _on_back_button_pressed() -> void:
	audio_panel.stop_and_close()
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	if dict_popup != null and dict_popup.is_open():
		dict_popup._hide_popup()
	else:
		_on_back_button_pressed()
