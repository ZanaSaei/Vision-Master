extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# WHAT YOU LEARNED SCENE — 3 swipeable pages via PageView
#   Page 1 "Listen"  → Audio + Transcript + Fill-in-the-blanks
#   Page 2 "Read"    → Reading passage + Comprehension
#   Page 3 "Speak"   → Open-ended speaking prompts
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

# Emerald Green for Review/Mastery
const ACCENT := Color("#059669")
const SOFT   := Color("#ECFDF5")

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _audio_player: AudioStreamPlayer
var _transcript_label: PanelContainer
var _transcript_btn: Button
var _data: Dictionary = {}


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold    = load(FONT_BOLD_PATH)
	font_farsi   = load(FONT_VAZIRMATN)
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	back_button.pressed.connect(_on_back_button_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)
	
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_audio_player.finished.connect(func(): _transcript_btn.text = "📜 Show Transcript")
	
	header_title.text = "Lesson %d\nReview" % Global.current_lesson
	
	_data = Global.load_category("what_you_learned", Global.current_book, Global.current_lesson)
	if _data.is_empty():
		return
	
	page_view.add_page("listen", "Listen", "🎧", _build_listen_page())
	page_view.add_page("read",   "Read",   "📖", _build_read_page())
	page_view.add_page("speak",  "Speak",  "🗣️", _build_speak_page())


# ============================================================
# PAGE 1 — LISTEN (Audio + Transcript + Exercises)
# ============================================================
func _build_listen_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	
	page.add_child(_make_topic_banner("🎧", "Listen & Review", "گوش دهید و مرور کنید"))
	
	var listen_data: Dictionary = _data.get("listen", {})
	
	# Audio Controls
	var audio_box := HBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 14)
	
	var play_btn := _make_button("▶  Play Audio", ACCENT)
	play_btn.pressed.connect(func():
		var path: String = listen_data.get("audio", "")
		if path != "" and ResourceLoader.exists(path):
			_audio_player.stream = load(path)
			_audio_player.play()
			play_btn.text = "⏸  Pause"
		else:
			play_btn.text = "❌ No Audio"
	)
	audio_box.add_child(play_btn)
	
	_transcript_btn = _make_button("📜 Show Transcript", Color("#64748B"))
	_transcript_btn.pressed.connect(func():
		_transcript_label.visible = not _transcript_label.visible
		_transcript_btn.text = "🙈 Hide Transcript" if _transcript_label.visible else "📜 Show Transcript"
	)
	audio_box.add_child(_transcript_btn)
	page.add_child(audio_box)
	
	# Transcript
	var transcript: Dictionary = listen_data.get("transcript", {})
	_transcript_label = _make_text_card(transcript.get("en", ""), transcript.get("fa", ""), SOFT, ACCENT)
	_transcript_label.visible = false
	page.add_child(_transcript_label)
	
	# Exercises
	for exercise in listen_data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
	
	return page


# ============================================================
# PAGE 2 — READ (Passage + Comprehension)
# ============================================================
func _build_read_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	
	page.add_child(_make_topic_banner("📖", "Read & Understand", "بخوانید و درک کنید"))
	
	var read_data: Dictionary = _data.get("read", {})
	var text: Dictionary = read_data.get("text", {})
	
	if not text.is_empty():
		page.add_child(_make_text_card(text.get("en", ""), text.get("fa", ""), SOFT, ACCENT))
	
	for exercise in read_data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
	
	return page


# ============================================================
# PAGE 3 — SPEAK (Open-ended prompts)
# ============================================================
func _build_speak_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	
	page.add_child(_make_topic_banner("🗣️", "Speak & Practice", "صحبت کنید و تمرین کنید"))
	
	var intro := _make_text_card(
		"Work with a partner or say the answers out loud! Tap 'Show Sample Answer' to check.",
		"با یک شریک کار کنید یا جواب‌ها را بلند بگویید! روی «نمایش نمونه جواب» بزنید تا چک کنید.",
		Color("#F0FDF4"), Color("#16A34A"))
	page.add_child(intro)
	
	var speak_data: Dictionary = _data.get("speak", {})
	for exercise in speak_data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
	
	return page


# ============================================================
# SHARED WIDGETS
# ============================================================
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
	ic.add_theme_font_size_override("font_size", 72)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ic)
	var en_l := _make_label(en, 50, Color.WHITE, true)
	en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(en_l)
	var fa_l := _make_fa_label(fa, 36)
	fa_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
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
	vb.add_child(_make_label(en, 36, Color("#1E293B"), false))
	vb.add_child(_make_fa_label(fa, 31))
	card.add_child(vb)
	return card


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	if font_bold: btn.add_theme_font_override("font", font_bold)
	return btn


func _make_label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold: l.add_theme_font_override("font", font_bold)
	elif not bold and font_regular: l.add_theme_font_override("font", font_regular)
	return l


func _make_fa_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#64748B"))
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: l.add_theme_font_override("font", font_farsi)
	return l


# ============================================================
# NAVIGATION
# ============================================================
func _on_page_changed(_index: int, _page_id: String) -> void:
	pass

func _on_back_button_pressed() -> void:
	_audio_player.stop()
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
