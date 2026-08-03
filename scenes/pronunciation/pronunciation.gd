extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# PRONUNCIATION SCENE — 2 swipeable pages via PageView
#   Page 1 "Learn"    → Rule + Visual Stress/Intonation Cards + Audio
#   Page 2 "Practice" → ExerciseEngine quizzes
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

const ACCENT := Color("#0891B2") # Teal for pronunciation (distinct from others)

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}
var _data: Dictionary = {}
var _audio_player: AudioStreamPlayer


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
	
	header_title.text = "Lesson %d\nPronunciation" % Global.current_lesson
	
	_data = Global.load_category("pronunciation", Global.current_book, Global.current_lesson)
	if _data.is_empty():
		return
	
	page_view.add_page("learn",    "Learn",    "👂", _build_learn_page())
	page_view.add_page("practice", "Practice", "✏️", _build_practice_page())
	
	_play_reveal(0)


# ============================================================
# PAGE 1 — LEARN (Rule + Interactive Cards)
# ============================================================
func _build_learn_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[0] = []
	
	# Topic banner
	var topic_en: String = _data.get("topic", {}).get("en", "Pronunciation")
	var topic_fa: String = _data.get("topic", {}).get("fa", "تلفظ")
	page.add_child(_make_topic_banner("🗣️", topic_en, topic_fa))
	
	# Rule card
	var rule: Dictionary = _data.get("rule", {})
	if not rule.is_empty():
		var card := _make_text_card(rule.get("en", ""), rule.get("fa", ""), Color("#ECFEFF"), ACCENT)
		page.add_child(card)
		_page_reveals[0].append(card)
	
	# Pronunciation items
	var items: Array = _data.get("items", [])
	for item in items:
		var p_card := _make_pronunciation_card(item)
		page.add_child(p_card)
		_page_reveals[0].append(p_card)
	
	return page


func _make_pronunciation_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	
	# --- Sentence with stress highlighting & intonation arrow ---
	var intonation: String = item.get("intonation", "falling")
	var arrow: String = "↗" if intonation == "rising" else ("↗ ↘" if intonation == "mixed" else "↘")
	
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_font_size_override("normal_font_size", 42)
	rtl.add_theme_color_override("default_color", Color("#1E293B"))
	
	var text: String = item.get("text", "")
	var stress_words: Array = item.get("stress", [])
	for word in stress_words:
		# Case-insensitive replace to wrap in bold red
		var regex := RegEx.new()
		regex.compile("(?i)\\b(" + word + ")\\b")
		text = regex.sub(text, "[color=#DC2626][b]$1[/b][/color]", true)
	
	rtl.text = text + "  [color=#0891B2][b]" + arrow + "[/b][/color]"
	if font_bold: rtl.add_theme_font_override("normal_font", font_bold)
	vb.add_child(rtl)
	
	# --- FA translation ---
	var fa := Label.new()
	fa.text = item.get("fa", "")
	fa.autowrap_mode = TextServer.AUTOWRAP_WORD
	fa.add_theme_font_size_override("font_size", 34)
	fa.add_theme_color_override("font_color", Color("#64748B"))
	fa.text_direction = Control.TEXT_DIRECTION_RTL
	fa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_farsi: fa.add_theme_font_override("font", font_farsi)
	vb.add_child(fa)
	
	# --- Audio Controls ---
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.add_child(_make_audio_btn("▶  Play", item.get("audio", ""), 1.0))
	btns.add_child(_make_audio_btn("🐢  Slow", item.get("audio", ""), 0.75))
	vb.add_child(btns)
	
	card.add_child(vb)
	return card


func _make_audio_btn(label: String, audio_path: String, speed: float) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = ACCENT.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	if font_bold: btn.add_theme_font_override("font", font_bold)
	
	btn.pressed.connect(func():
		if audio_path != "" and ResourceLoader.exists(audio_path):
			_audio_player.stream = load(audio_path)
			_audio_player.pitch_scale = speed
			_audio_player.play()
		else:
			# Fallback to TTS if audio file is missing
			if Global.english_voice_id != "":
				DisplayServer.tts_speak(_data.get("items", [])[0].get("text", ""), Global.english_voice_id, 50, speed, 1.0)
		btn.pivot_offset = btn.size / 2.0
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
		t.tween_property(btn, "scale", Vector2.ONE, 0.1)
	)
	return btn


# ============================================================
# PAGE 2 — PRACTICE (ExerciseEngine)
# ============================================================
func _build_practice_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[1] = []
	
	page.add_child(_make_topic_banner("✏️", "Practice", "تمرین"))
	
	var intro := _make_text_card(
		"Test your ear! Can you identify the stress and intonation?",
		"گوش خود را بسنجید! آیا می‌توانید استرس و آهنگ را شناسایی کنید؟",
		Color("#F0FDF4"), Color("#16A34A"))
	page.add_child(intro)
	_page_reveals[1].append(intro)
	
	for exercise in _data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
		_page_reveals[1].append(engine)
	
	return page


# ============================================================
# SHARED WIDGETS (Reused from Vocabulary/Grammar scenes)
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
# ENTRANCE ANIMATION
# ============================================================
func _on_page_changed(index: int, _page_id: String) -> void:
	_play_reveal(index)

func _play_reveal(index: int) -> void:
	if _page_revealed.get(index, false): return
	_page_revealed[index] = true
	var cards: Array = _page_reveals.get(index, [])
	for i in cards.size():
		var card: Control = cards[i]
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.07 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# NAVIGATION
# ============================================================
func _on_back_button_pressed() -> void:
	_audio_player.stop()
	DisplayServer.tts_stop()
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
