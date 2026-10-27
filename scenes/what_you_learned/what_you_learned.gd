extends "res://autoload/BackButtonHandler.gd"

# ============================================================
# WHAT YOU LEARNED SCENE — 3 swipeable pages via PageView
# Page 1 "Listen"  → Audio + Transcript + Fill-in-the-blanks
# Page 2 "Read"    → Reading passage + Comprehension
# Page 3 "Speak"   → Open-ended speaking prompts
#
# Dark-theme harmonized version.
# Titles are kept on one line with wrapping disabled.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

# Global scale applied to every text size so fonts render larger.
const FONT_SCALE := 1.25

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

# ---------- Dark theme ----------
const APP_BG := Color("#0b1229")
const PANEL_BG := Color("#0f1b3d")
const PANEL_BORDER := Color("#2d3a6a")

const TEXT_LIGHT := Color("#F1F5F9")
const TEXT_SOFT := Color("#CBD5E1")
const TEXT_MUTED := Color("#94A3B8")

const SUCCESS := Color("#34D399")

const ACCENT := Color("#059669")

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView
@onready var background: ColorRect = $Background

# ---------- Audio panel support ----------
# Path to your AudioPanel scene. Adjust if yours is elsewhere.
const AUDIO_PANEL_SCENE_PATH := "res://scenes/shared/AudioPanel.tscn"

var _audio_panel: Node = null
var _listen_audio_btn: Button = null
var _listen_audio_path: String = ""
var _audio_request_pending: bool = false
var _audio_play_requested: bool = false

var _transcript_label: PanelContainer
var _transcript_btn: Button
var _data: Dictionary = {}


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_farsi = load(FONT_VAZIRMATN)

	if font_bold:
		header_title.add_theme_font_override("font", font_bold)

	# The bar owns its title's type ramp; see HeaderBarStyler.
	HeaderBarStyler.style_title(header_title)

	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)
	# Restyle live when the app theme toggles.
	Global.on_theme_changed(_apply_theme)

	# Put a dark background behind the whole PageView.
	_add_page_view_background()

	header_title.text = MenuStyle.persian_digits("درس %d\nآنچه آموختید" % Global.current_lesson)

	_data = Global.load_category(
		"what_you_learned",
		Global.current_book,
		Global.current_lesson
	)

	if _data.is_empty():
		return

	page_view.add_page("listen", "گوش دادن", "🎧", _build_listen_page())
	page_view.add_page("read", "خواندن", "📖", _build_read_page())
	page_view.add_page("speak", "صحبت کردن", "🗣️", _build_speak_page())

	# Load/download media for every lesson, matching the other lesson screens.
	# The panel itself is created lazily on Play Audio, not during UI construction.
	if not Content.lesson_ready.is_connected(_on_content_lesson_ready):
		Content.lesson_ready.connect(_on_content_lesson_ready)
	if not Content.manifest_ready.is_connected(_on_content_manifest_ready):
		Content.manifest_ready.connect(_on_content_manifest_ready)
	if not Content.is_lesson_ready(Global.current_book, Global.current_lesson):
		_listen_audio_btn.disabled = false
		_update_listen_audio_availability()
		Content.ensure_lesson(Global.current_book, Global.current_lesson)
	else:
		_update_listen_audio_availability()

	# Force backgrounds for PageView scroll areas.
	_apply_dark_scroll_background(page_view)
	_apply_theme()


# ============================================================
# DARK THEME HELPERS
# ============================================================

func _add_page_view_background() -> void:
	if page_view.has_meta("dark_bg"):
		return

	var bg := ColorRect.new()
	bg.color = Global.get_theme_color("bg_base")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	page_view.add_child(bg)
	page_view.move_child(bg, 0)
	page_view.set_meta("dark_bg", bg)


func _apply_dark_scroll_background(root: Control) -> void:
	for child in root.get_children():
		if child is ScrollContainer:
			var style := StyleBoxFlat.new()
			style.bg_color = Global.get_theme_color("bg_base")
			child.add_theme_stylebox_override("panel", style)

		if child is Control:
			_apply_dark_scroll_background(child)


func _dark_tint(color: Color, amount := 0.16) -> Color:
	# Creates a panel color tinted by the given accent color (theme surface).
	return Global.get_theme_color("surface").lerp(Color(color.r, color.g, color.b, 1.0), amount)


func _contrast_color(bg: Color) -> Color:
	# Chooses readable text color for colored banners/buttons.
	if bg.get_luminance() > 0.6:
		return Color("#0b1229")
	return Color.WHITE


func _text_color() -> Color:
	# Pure white in dark theme, pure black in light theme — maximum contrast.
	return Color.WHITE if Global.theme_is_dark() else Color.BLACK


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	HeaderBarStyler.style_title(header_title)
	# Scene background (behind the header) — from the theme source.
	if background != null:
		background.color = Global.get_theme_color("bg_base")
	# PageView background behind the content.
	if page_view.has_meta("dark_bg"):
		var bg: ColorRect = page_view.get_meta("dark_bg")
		bg.color = Global.get_theme_color("bg_base")
	_apply_dark_scroll_background(page_view)


# ============================================================
# PAGE 1 — LISTEN
# ============================================================

func _build_listen_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	page.add_child(_make_topic_banner("🎧", "Listen & Review", "گوش دهید و مرور کنید"))

	var listen_data: Dictionary = _data.get("listen", {})

	# Audio controls.
	var audio_box := HBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 14)
	audio_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Play/Stop button that opens the AudioPanel.
	var play_btn := _make_button("▶  Play Audio", ACCENT)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_listen_audio_btn = play_btn
	_listen_audio_path = str(listen_data.get("audio", ""))
	play_btn.pressed.connect(_on_listen_audio_pressed)
	audio_box.add_child(play_btn)
	
	# AudioPanel is instantiated lazily when the play button is pressed.

	_transcript_btn = _make_button("📜 Show Transcript", Color("#64748B"))
	_transcript_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_transcript_btn.pressed.connect(func():
		_transcript_label.visible = not _transcript_label.visible

		if _transcript_label.visible:
			_transcript_btn.text = "🙈 Hide Transcript"
		else:
			_transcript_btn.text = "📜 Show Transcript"
	)

	audio_box.add_child(_transcript_btn)
	page.add_child(audio_box)

	# Transcript.
	var transcript: Dictionary = listen_data.get("transcript", {})

	_transcript_label = _make_text_card(
		str(transcript.get("en", "")),
		str(transcript.get("fa", "")),
		_dark_tint(ACCENT),
		ACCENT
	)

	_transcript_label.visible = false
	page.add_child(_transcript_label)

	# Exercises.
	for exercise in listen_data.get("exercises", []):
		var engine := _create_exercise_engine()
		page.add_child(engine)
		engine.build(exercise)

	return page


# ============================================================
# PAGE 2 — READ
# ============================================================

func _build_read_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	page.add_child(_make_topic_banner("📖", "Read & Understand", "بخوانید و درک کنید"))

	var read_data: Dictionary = _data.get("read", {})
	var text: Dictionary = read_data.get("text", {})

	if not text.is_empty():
		page.add_child(_make_text_card(
			str(text.get("en", "")),
			str(text.get("fa", "")),
			_dark_tint(ACCENT),
			ACCENT
		))

	for exercise in read_data.get("exercises", []):
		var engine := _create_exercise_engine()
		page.add_child(engine)
		engine.build(exercise)

	return page


# ============================================================
# PAGE 3 — SPEAK
# ============================================================

func _build_speak_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	page.add_child(_make_topic_banner("🗣️", "Speak & Practice", "صحبت کنید و تمرین کنید"))

	var intro := _make_text_card(
		"Work with a partner or say the answers out loud! Tap 'Show Sample Answer' to check.",
		"با یک شریک کار کنید یا جواب‌ها را بلند بگویید! روی «نمایش نمونه جواب» بزنید تا چک کنید.",
		_dark_tint(SUCCESS, 0.10),
		SUCCESS
	)

	page.add_child(intro)

	var speak_data: Dictionary = _data.get("speak", {})

	for exercise in speak_data.get("exercises", []):
		var engine := _create_exercise_engine()
		page.add_child(engine)
		engine.build(exercise)

	return page


# ============================================================
# SHARED WIDGETS
# ============================================================
# Creates an ExerciseEngine configured with the audio button.
func _create_exercise_engine() -> ExerciseEngine:
	var engine := ExerciseEngine.new()
	
	# Choose which exercise types show the audio button.
	engine.audio_types = [
		"multiple_choice",
		"fill_blank",
		"cloze",
	]
	
	engine.audio_panel_scene_path = "res://scenes/shared/AudioPanel.tscn"
	
	return engine


func _make_topic_banner(icon: String, en: String, fa: String) -> PanelContainer:
	var banner := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(20)
	style.set_content_margin_all(26)

	banner.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", int(72 * FONT_SCALE))
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ic)

	var text_color := _contrast_color(ACCENT)
	var sub_color := Color(text_color.r, text_color.g, text_color.b, 0.85)

	# Banner title: one line, no wrapping.
	var en_l := _make_label(en, 50, text_color, true)
	en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(en_l)

	var fa_l := _make_fa_label(fa, 36, sub_color)
	fa_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(fa_l)

	banner.add_child(vb)
	return banner


func _make_text_card(en: String, fa: String, bg: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_color = border
	style.set_content_margin_all(18)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	# Body text stays wrapped.
	vb.add_child(_make_label(en, 36, _text_color(), false))
	vb.add_child(_make_fa_label(fa, 31, _text_color()))

	card.add_child(vb)
	return card


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.add_theme_font_size_override("font_size", int(32 * FONT_SCALE))
	btn.add_theme_color_override("font_color", _contrast_color(color))

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)

	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = color.lightened(0.15)

	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	if font_bold:
		btn.add_theme_font_override("font", font_bold)

	return btn


func _make_label(text: String, font_size: int, color: Color, bold: bool, do_wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable wrapping for titles when requested.
	if do_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Apply global scale, then slightly shrink very long one-line titles.
	var base := int(float(font_size) * FONT_SCALE)
	var final_size := base
	if not do_wrap:
		if text.length() > 30:
			final_size = int(float(base) * 0.85)
		if text.length() > 55:
			final_size = int(float(base) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", color)

	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular:
		l.add_theme_font_override("font", font_regular)

	return l


func _make_fa_label(text: String, font_size: int, color: Color = Color.WHITE, do_wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if do_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Apply global scale, then slightly shrink very long one-line Persian titles.
	var base := int(float(font_size) * FONT_SCALE)
	var final_size := base
	if not do_wrap:
		if text.length() > 34:
			final_size = int(float(base) * 0.85)
		if text.length() > 60:
			final_size = int(float(base) * 0.72)

	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", color)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if font_farsi:
		l.add_theme_font_override("font", font_farsi)

	return l


# ============================================================
# NAVIGATION
# ============================================================

func _on_page_changed(_index: int, page_id: String) -> void:
	# Stop audio when leaving the Listen page.
	if page_id != "listen":
		_stop_audio_panel()


func _on_home_pressed() -> void:
	_stop_audio_panel()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_back_button_pressed() -> void:
	_stop_audio_panel()

	back_button.pivot_offset = back_button.size / 2.0

	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()

# ============================================================
# AUDIO PANEL HELPERS
# ============================================================
func _get_or_create_audio_panel() -> Node:
	if _audio_panel != null and is_instance_valid(_audio_panel):
		return _audio_panel

	# Do not accidentally adopt an unrelated panel owned by another screen.
	if not ResourceLoader.exists(AUDIO_PANEL_SCENE_PATH):
		push_warning("WhatYouLearned: AudioPanel scene not found: " + AUDIO_PANEL_SCENE_PATH)
		return null

	var scene: PackedScene = load(AUDIO_PANEL_SCENE_PATH) as PackedScene
	if scene == null:
		return null

	var panel: Node = scene.instantiate()
	get_tree().root.add_child(panel)
	if panel is Control:
		(panel as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_to_group("audio_panel")
	_audio_panel = panel
	page_view.add_swipe_blocker(panel as Control)
	panel.audio_closed.connect(_on_listen_audio_closed)
	panel.audio_finished.connect(_on_listen_audio_closed)
	return panel


func _update_listen_audio_availability() -> void:
	if _listen_audio_btn == null or not is_instance_valid(_listen_audio_btn):
		return
	if _listen_audio_path != "" and Content.has_asset(_listen_audio_path):
		_listen_audio_btn.disabled = false
		_set_listen_button_idle()
	else:
		_listen_audio_btn.disabled = false
		_listen_audio_btn.text = "▶  Play Audio"


func _on_content_manifest_ready() -> void:
	if not is_inside_tree():
		return
	Content.ensure_lesson(Global.current_book, Global.current_lesson)


func _on_content_lesson_ready(book: int, lesson: int) -> void:
	if book != Global.current_book or lesson != Global.current_lesson:
		return
	_audio_request_pending = false
	_update_listen_audio_availability()
	if _audio_play_requested and Content.has_asset(_listen_audio_path):
		_audio_play_requested = false
		_on_listen_audio_pressed()


func _on_listen_audio_pressed() -> void:
	if _listen_audio_path == "":
		_set_listen_button_no_audio()
		return
	if not Content.has_asset(_listen_audio_path):
		_audio_play_requested = true
		_audio_request_pending = true
		_listen_audio_btn.text = "⏳ Downloading Audio..."
		_listen_audio_btn.disabled = true
		Content.ensure_lesson(Global.current_book, Global.current_lesson)
		return

	var panel: Node = _get_or_create_audio_panel()
	if panel == null:
		return
	if panel.is_playing():
		panel.stop_and_close()
		_set_listen_button_idle()
	else:
		panel.load_and_play(_listen_audio_path)
		_set_listen_button_playing()

func _set_listen_button_playing() -> void:
	if _listen_audio_btn != null and is_instance_valid(_listen_audio_btn):
		_listen_audio_btn.text = "⏹  Stop Audio"

func _set_listen_button_no_audio() -> void:
	if _listen_audio_btn != null and is_instance_valid(_listen_audio_btn):
		_listen_audio_btn.text = "❌ No Audio"
		# Disable it so the user cannot press a button with no audio.
		_listen_audio_btn.disabled = true
		# Dim the text so it clearly looks inactive.
		_listen_audio_btn.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
		_listen_audio_btn.add_theme_color_override("font_disabled_color", Global.get_theme_color("text_dim"))

func _set_listen_button_idle() -> void:
	if _listen_audio_btn != null and is_instance_valid(_listen_audio_btn):
		_listen_audio_btn.text = "▶  Play Audio"


func _on_listen_audio_closed() -> void:
	# The panel was closed OR the track finished -> reset the button.
	_audio_play_requested = false
	_set_listen_button_idle()


func _stop_audio_panel() -> void:
	if _audio_panel != null and is_instance_valid(_audio_panel):
		if _audio_panel.is_playing():
			_audio_panel.stop_and_close()
