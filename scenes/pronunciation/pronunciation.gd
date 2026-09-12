extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# PRONUNCIATION SCENE — 2 swipeable pages via PageView
#   Page 1 "Learn"    → Rule + Visual Stress/Intonation Cards + Audio
#   Page 2 "Practice" → ExerciseEngine quizzes
#
# CHANGES:
#   1) Stressed words are now bigger, bold, colored and underlined.
#   2) "Slow" button removed. Play toggles to Stop while playing.
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
const ACCENT := Color("#0891B2")

# ---------- Sentence typography ----------
const SENTENCE_FONT_SIZE := 42
# CHANGED: stressed words are rendered much bigger so they stand out.
const STRESS_FONT_SIZE := 54

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView
@onready var background: ColorRect = $Background

var _page_reveals: Dictionary = {}
var _page_revealed: Dictionary = {}
var _data: Dictionary = {}

var _audio_player: AudioStreamPlayer
# NEW: track which button is currently playing so Play <-> Stop can toggle.
var _playing_btn: Button = null
var _tts_active: bool = false
var _tts_generation: int = 0

func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold = load(FONT_BOLD_PATH)
	font_farsi = load(FONT_VAZIRMATN)
	
	if font_bold:
		header_title.add_theme_font_override("font", font_bold)
	# Keep header readable on the current theme.
	header_title.add_theme_color_override("font_color", _text_color())
	
	back_button.pressed.connect(_on_back_button_pressed)
	home_button.pressed.connect(_on_home_pressed)
	page_view.page_changed.connect(_on_page_changed)
	page_view.set_accent(ACCENT)
	# Restyle live when the app theme toggles.
	Global.on_theme_changed(_apply_theme)
	# Dark background behind PageView content.
	_add_page_view_background()
	
	_audio_player = AudioStreamPlayer.new()
	# NEW: reset the button when audio finishes naturally.
	_audio_player.finished.connect(_on_audio_finished)
	add_child(_audio_player)
	
	# NEW: reset the button when fallback TTS finishes (if the platform exposes it).
	if DisplayServer.has_signal("tts_ended"):
		DisplayServer.connect("tts_ended", _on_tts_ended)
	
	header_title.text = MenuStyle.persian_digits("درس %d\nتلفظ" % Global.current_lesson)
	_data = Global.load_category(
		"pronunciation",
		Global.current_book,
		Global.current_lesson
	)
	if _data.is_empty():
		return
	
	page_view.add_page("learn", "یادگیری", "👂", _build_learn_page())
	page_view.add_page("practice", "تمرین", "✏️", _build_practice_page())
	# Force dark backgrounds for PageView scroll areas.
	_apply_dark_scroll_background(page_view)
	_play_reveal(0)
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

func _text_color() -> Color:
	# Pure white in dark theme, pure black in light theme — maximum contrast.
	return Color.WHITE if Global.theme_is_dark() else Color.BLACK

func _apply_theme() -> void:
	if not is_inside_tree():
		return
	header_title.add_theme_color_override("font_color", _text_color())
	# Scene background (behind the header) — from the theme source.
	if background != null:
		background.color = Global.get_theme_color("bg_base")
	# PageView background behind the content.
	if page_view.has_meta("dark_bg"):
		var bg: ColorRect = page_view.get_meta("dark_bg")
		bg.color = Global.get_theme_color("bg_base")
	_apply_dark_scroll_background(page_view)

# ============================================================
# PAGE 1 — LEARN
# ============================================================
func _build_learn_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[0] = []
	
	# Topic banner.
	var topic_en := str(_data.get("topic", {}).get("en", "Pronunciation"))
	var topic_fa := str(_data.get("topic", {}).get("fa", "تلفظ"))
	var banner := _make_topic_banner("🗣️", topic_en, topic_fa)
	page.add_child(banner)
	_page_reveals[0].append(banner)
	
	# Rule card.
	var rule: Dictionary = _data.get("rule", {})
	if not rule.is_empty():
		var card := _make_text_card(
			str(rule.get("en", "")),
			str(rule.get("fa", "")),
			_dark_tint(ACCENT),
			ACCENT
		)
		page.add_child(card)
		_page_reveals[0].append(card)
	
	# Pronunciation items.
	for item in _data.get("items", []):
		var p_card := _make_pronunciation_card(item)
		page.add_child(p_card)
		_page_reveals[0].append(p_card)
	
	return page

func _make_pronunciation_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface")
	style.set_corner_radius_all(16)
	style.border_width_left = 5
	style.border_color = ACCENT
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	
	# ------------------------------------------------------------
	# Sentence with stress highlighting and intonation arrow.
	# ------------------------------------------------------------
	var intonation := str(item.get("intonation", "falling"))
	var arrow := "↘"
	if intonation == "rising":
		arrow = "↗"
	elif intonation == "mixed":
		arrow = "↗ ↘"
	
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", int(SENTENCE_FONT_SIZE * FONT_SCALE))
	rtl.add_theme_color_override("default_color", _text_color())
	if font_bold:
		rtl.add_theme_font_override("normal_font", font_bold)
		# CHANGED: make sure [b] tags resolve to the real bold font
		# instead of falling back to a thin/small variant.
		rtl.add_theme_font_override("bold_font", font_bold)
	
	var raw_text := str(item.get("text", ""))
	var marked_text := raw_text
	var stress_words: Array = item.get("stress", [])
	for word in stress_words:
		var regex := RegEx.new()
		regex.compile("(?i)\\b(" + str(word) + ")\\b")
		# CHANGED: bigger + bold + red + underlined so the stressed
		# word (e.g. "going" in "Where are you going to go?") is
		# impossible to miss.
		var replacement := "[font_size=%d][color=#F87171][b][u]$1[/u][/b][/color][/font_size]" % int(STRESS_FONT_SIZE * FONT_SCALE)
		marked_text = regex.sub(marked_text, replacement, true)
	
	rtl.text = marked_text + "  [color=#22D3EE][b]%s[/b][/color]" % arrow
	vb.add_child(rtl)
	
	# Persian translation.
	vb.add_child(_make_fa_label(str(item.get("fa", "")), 34, _text_color()))
	
	# CHANGED: single Play/Stop button (the "Slow" button was removed).
	vb.add_child(_make_play_btn(str(item.get("audio", "")), raw_text))
	
	card.add_child(vb)
	return card

# ============================================================
# AUDIO PLAYBACK — Play / Stop toggle
# ============================================================
func _make_play_btn(audio_path: String, fallback_text: String) -> Button:
	var btn := Button.new()
	btn.text = "▶  Play"
	btn.custom_minimum_size = Vector2(230, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.add_theme_font_size_override("font_size", int(30 * FONT_SCALE))
	
	var text_color := Color.WHITE
	if ACCENT.get_luminance() > 0.6:
		text_color = Color("#0b1229")
	btn.add_theme_color_override("font_color", text_color)
	
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = ACCENT.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	
	if font_bold:
		btn.add_theme_font_override("font", font_bold)
	
	btn.pressed.connect(_on_play_btn_pressed.bind(btn, audio_path, fallback_text))
	return btn

func _on_play_btn_pressed(btn: Button, audio_path: String, fallback_text: String) -> void:
	# Pressing the currently-playing button stops playback.
	if _playing_btn == btn:
		_stop_all_audio()
		return
	
	# Only one sound at a time: stop whatever else is playing.
	_stop_all_audio()
	
	_playing_btn = btn
	_apply_play_btn_state(btn, true)
	
	var stream: AudioStream = null
	if audio_path != "" and Content.has_asset(audio_path):
		stream = Content.load_audio(audio_path)
	if stream != null:
		_tts_active = false
		_audio_player.stream = stream
		_audio_player.pitch_scale = 1.0
		_audio_player.play()
	else:
		# Fallback to TTS if the audio file is missing.
		_tts_active = true
		_tts_generation += 1
		if Global.english_voice_id != "" and DisplayServer.has_method("tts_speak"):
			DisplayServer.tts_speak(
				fallback_text,
				Global.english_voice_id,
				100,              # volume (0-100) — was accidentally _tts_generation
				1.0,              # pitch
				1.0,              # rate
				_tts_generation,  # utterance_id — lets _on_tts_ended ignore stale callbacks
				true              # interrupt anything currently speaking
			)
			_watch_tts(_tts_generation)
		else:
			# No audio file and no TTS available: revert the button.
			_stop_all_audio()
	
	# Press feedback.
	btn.pivot_offset = btn.size / 2.0
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
	t.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _apply_play_btn_state(btn: Button, playing: bool) -> void:
	if not is_instance_valid(btn):
		return
	# Toggle label: Play <-> Stop.
	btn.text = "⏹  Stop" if playing else "▶  Play"
	# Recolor while playing so the state is obvious.
	var base_color: Color = Color("#DC2626") if playing else ACCENT
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = base_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _stop_all_audio() -> void:
	_audio_player.stop()
	if DisplayServer.has_method("tts_stop"):
		DisplayServer.tts_stop()
	_reset_play_button()

func _reset_play_button() -> void:
	_tts_active = false
	if _playing_btn != null and is_instance_valid(_playing_btn):
		_apply_play_btn_state(_playing_btn, false)
	_playing_btn = null

func _on_audio_finished() -> void:
	# Audio file finished naturally → back to "Play".
	_reset_play_button()

func _on_tts_ended(utterance_id = null) -> void:
	# Fallback TTS finished naturally → back to "Play".
	if not _tts_active:
		return
	# Ignore stale utterance callbacks.
	if utterance_id != null and int(utterance_id) != _tts_generation:
		return
	_reset_play_button()

func _watch_tts(gen: int) -> void:
	# Safety net for platforms without the tts_ended signal:
	# poll until TTS stops speaking.
	if DisplayServer.has_signal("tts_ended"):
		return
	if not DisplayServer.has_method("tts_is_speaking"):
		return
	# Give the engine a moment to actually start speaking.
	await get_tree().create_timer(0.6).timeout
	while is_inside_tree() and _tts_active and _tts_generation == gen and DisplayServer.tts_is_speaking():
		await get_tree().create_timer(0.25).timeout
	if is_inside_tree() and _tts_active and _tts_generation == gen:
		_reset_play_button()

# ============================================================
# PAGE 2 — PRACTICE
# ============================================================
func _build_practice_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	_page_reveals[1] = []
	
	var banner := _make_topic_banner("✏️", "Practice", "تمرین")
	page.add_child(banner)
	_page_reveals[1].append(banner)
	
	var intro := _make_text_card(
		"Test your ear! Can you identify the stress and intonation?",
		"گوش خود را بسنجید! آیا می‌توانید استرس و آهنگ را شناسایی کنید؟",
		_dark_tint(SUCCESS, 0.10),
		SUCCESS
	)
	page.add_child(intro)
	_page_reveals[1].append(intro)
	
	for exercise in _data.get("exercises", []):
		var engine := ExerciseEngine.new()
		page.add_child(engine)
		engine.build(exercise)
		_page_reveals[1].append(engine)
	
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
	ic.add_theme_font_size_override("font_size", int(72 * FONT_SCALE))
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ic)
	
	# Choose readable text color based on accent brightness.
	var text_color := Color.WHITE
	if ACCENT.get_luminance() > 0.6:
		text_color = Color("#0b1229")
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
# ENTRANCE ANIMATION
# ============================================================
func _on_page_changed(index: int, _page_id: String) -> void:
	_play_reveal(index)

func _play_reveal(index: int) -> void:
	if _page_revealed.get(index, false):
		return
	_page_revealed[index] = true
	var cards: Array = _page_reveals.get(index, [])
	for i in cards.size():
		var card: Control = cards[i]
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(
			card,
			"modulate:a",
			1.0,
			0.3
		).set_delay(0.07 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ============================================================
# NAVIGATION
# ============================================================
func _on_home_pressed() -> void:
	_stop_all_audio()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_back_button_pressed() -> void:
	# CHANGED: stops AudioStreamPlayer + TTS and resets any Play button.
	_stop_all_audio()
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
