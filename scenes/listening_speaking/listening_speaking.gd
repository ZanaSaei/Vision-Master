extends "res://autoload/BackButtonHandler.gd"

# ============================================================
# LISTENING & SPEAKING SCENE — two swipeable pages via PageView
# Page 1 "Speaking"  → strategy, patterns, conversation partner, drills
# Page 2 "Listening" → listen-first audio cards + comprehension
#
# Dark-theme harmonized version.
# Titles are kept on one line with wrapping disabled.
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

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

# Page accents: warm = speaking, cool = listening.
const SPEAK_ACCENT := Color("#EA580C")
const LISTEN_ACCENT := Color("#2563EB")

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

# ---------- Extra speaking state ----------
var _tts_fallback_tween: Tween
var _user_response_tween: Tween
const USER_RESPONSE_PAUSE := 4.0

# ---------- Extra listening state ----------
var _listening_tts_active_id := ""

# ---------- AudioPanel ----------
const AUDIO_PANEL_SCENE_PATH := "res://scenes/shared/AudioPanel.tscn"
var _audio_panel_instance: Node = null
var _audio_panel_active_id := ""

@onready var background: ColorRect = $Background
@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var home_button: Button = $HeaderBar/HeaderContent/HomeButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

# ---------- Speaking state ----------
var _turns: Array = []
var _turn_cards: Array = []
var _current_turn: int = -1
var _partner_mode: bool = false
var _status_label: Label
var _action_btn: Button
var _tts_done_cb: Callable
var _speaking_data: Dictionary = {}

# ---------- Listening state ----------
var _listening_players: Array = []
var _listened: Dictionary = {}

# ---------- Ambient dark background ----------
var _ambient_bg: ColorRect


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

	# Put a dark background behind the whole PageView.
	_ambient_bg = _add_page_view_background()
	_apply_ambient(SPEAK_ACCENT)

	# Theme-aware styling + live re-theme on toggle (runs for all data paths).
	Global.on_theme_changed(_apply_theme)
	_apply_theme()

	header_title.text = MenuStyle.persian_digits("درس %d\nشنیداری و گفتاری" % Global.current_lesson)

	var data: Dictionary = Global.load_category(
		"listening_speaking",
		Global.current_book,
		Global.current_lesson
	)

	if data.is_empty():
		return

	_speaking_data = data.get("speaking", {})

	page_view.add_page("speaking", "صحبت کردن", "🗣", _build_speaking_page(_speaking_data))
	page_view.add_page("listening", "شنیدن", "🎧", _build_listening_page(data.get("listening", [])))

	# Force themed backgrounds for PageView scroll areas.
	_apply_dark_scroll_background(page_view)


# ============================================================
# THEME-AWARE STYLING
# ============================================================

func _apply_theme() -> void:
	if not is_inside_tree():
		return

	if background != null:
		background.color = _navy_bg()

	HeaderBarStyler.style_title(header_title)

	if _ambient_bg != null:
		_ambient_bg.color = _app_bg()

	_apply_dark_scroll_background(page_view)
	_retheme_turn_cards()


func _retheme_turn_cards() -> void:
	for entry in _turn_cards:
		var accent: Color = SPEAK_ACCENT if entry["is_app"] else SUCCESS
		entry["base_bg"] = _dark_tint(accent, 0.12)
		entry["highlight_bg"] = _dark_tint(accent, 0.35)
		var st: StyleBoxFlat = entry["style"]
		st.bg_color = entry["base_bg"]


# ============================================================
# DARK THEME HELPERS
# ============================================================

func _add_page_view_background() -> ColorRect:
	if page_view.has_meta("dark_bg"):
		return page_view.get_meta("dark_bg")

	var bg := ColorRect.new()
	bg.color = _app_bg()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	page_view.add_child(bg)
	page_view.move_child(bg, 0)
	page_view.set_meta("dark_bg", bg)

	return bg


func _apply_dark_scroll_background(root: Control) -> void:
	for child in root.get_children():
		if child is ScrollContainer:
			var style := StyleBoxFlat.new()
			style.bg_color = _app_bg()
			child.add_theme_stylebox_override("panel", style)

		if child is Control:
			_apply_dark_scroll_background(child)


func _apply_ambient(accent: Color) -> void:
	if _ambient_bg == null:
		return

	# Skill identity is shown by page content, not by tinting the app background.
	_ambient_bg.color = _app_bg()


func _dark_tint(color: Color, amount := 0.16) -> Color:
	# Creates a panel color tinted by the given accent color.
	return _panel_bg().lerp(Color(color.r, color.g, color.b, 1.0), amount)


# ---------- Theme-aware color helpers ----------
# All colors resolve through Global (the single theme source).
func _navy_bg() -> Color:
	return Global.get_theme_color("bg_base")

func _app_bg() -> Color:
	return Global.get_theme_color("bg_base")

func _panel_bg() -> Color:
	return Global.get_theme_color("surface")

func _text_color() -> Color:
	return Global.get_theme_color("text")

func _text_soft() -> Color:
	return Global.get_theme_color("text_dim")

func _text_muted() -> Color:
	return Global.get_theme_color("text_dim")


func _get_en(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("en", ""))
	return str(val)


func _get_fa(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("fa", ""))
	return ""


# ============================================================
# PAGE 1 — SPEAKING
# ============================================================

func _build_speaking_page(speaking: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	# --- Strategy banner ---
	page.add_child(_make_banner(
		str(speaking.get("icon", "🗣")),
		_get_en(speaking.get("strategy_name", "")),
		_get_fa(speaking.get("strategy_name", "")),
		_get_en(speaking.get("intro", "")),
		_get_fa(speaking.get("intro", "")),
		SPEAK_ACCENT
	))

	# --- Useful patterns ---
	var patterns: Array = speaking.get("patterns", [])
	if not patterns.is_empty():
		page.add_child(_make_section_title("الگوهای مفید", SPEAK_ACCENT))

		for p in patterns:
			page.add_child(_make_pattern_card(p))

	# --- Model conversation + partner mode ---
	_turns = speaking.get("model_conversation", {}).get("turns", [])

	if not _turns.is_empty():
		var conversation_title := _get_fa(
			speaking.get("model_conversation", {}).get("title", "")
		)

		if conversation_title == "":
			conversation_title = "گفتگو"

		page.add_child(_make_section_title(conversation_title, SPEAK_ACCENT))
		_build_partner_controls(page)
		_build_turn_cards(page)

	# --- Practice prompts ---
	var practice: Dictionary = speaking.get("practice", {})
	if not practice.get("prompts", []).is_empty():
		page.add_child(_make_section_title("نوبت شما برای پاسخ", SPEAK_ACCENT))
		_build_practice(page, practice)

	return page


func _build_partner_controls(page: VBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_action_btn = _make_button("🤝  تمرین با برنامه", SPEAK_ACCENT)
	_action_btn.pressed.connect(_on_action_pressed)
	box.add_child(_action_btn)

	page.add_child(box)

	_status_label = Label.new()
	_status_label.text = "روی «تمرین با برنامه» بزنید — صدای سارا را اپ می‌گوید، شما جواب خود را می‌گویید."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.add_theme_font_size_override("font_size", 40)
	_status_label.add_theme_color_override("font_color", _text_color())

	if font_farsi:
		_status_label.add_theme_font_override("font", font_farsi)

	page.add_child(_status_label)

func _stop_tts() -> void:
	# Cancel an unfinished speaking pause whenever playback is stopped or replaced.
	if is_instance_valid(_user_response_tween):
		_user_response_tween.kill()
		_user_response_tween = null

	# If a fallback listening TTS is active, reset its UI.
	_reset_listening_tts_ui()

	_tts_done_cb = Callable()

	if is_instance_valid(_tts_fallback_tween):
		_tts_fallback_tween.kill()

	_listening_tts_active_id = ""

	if DisplayServer.has_method("tts_stop"):
		DisplayServer.tts_stop()

func _build_turn_cards(page: VBoxContainer) -> void:
	_turn_cards.clear()

	for i in _turns.size():
		var turn: Dictionary = _turns[i]
		var is_app: bool = str(turn.get("role", "app")) == "app"

		var accent := SPEAK_ACCENT if is_app else SUCCESS

		var base_bg := _dark_tint(accent, 0.12)
		var highlight_bg := _dark_tint(accent, 0.35)

		var card := PanelContainer.new()

		var style := StyleBoxFlat.new()
		style.bg_color = base_bg
		style.set_corner_radius_all(14)
		style.border_width_left = 5
		style.border_color = accent
		style.set_content_margin_all(16)

		card.add_theme_stylebox_override("panel", style)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)

		# Speaker label: one line.
		var role := Label.new()
		role.text = ("🤖 " if is_app else "🎤 ") + str(turn.get("speaker", ""))
		role.autowrap_mode = TextServer.AUTOWRAP_OFF
		role.add_theme_font_size_override("font_size", 36)
		role.add_theme_color_override("font_color", accent)

		if font_bold:
			role.add_theme_font_override("font", font_bold)

		vb.add_child(role)

		# Conversation text stays wrapped.
		vb.add_child(_make_label(str(turn.get("text", "")), 44, _text_color(), false))
		vb.add_child(_make_fa_label(str(turn.get("fa", "")), 40, _text_color()))

		card.add_child(vb)
		page.add_child(card)

		_turn_cards.append({
			"card": card,
			"style": style,
			"is_app": is_app,
			"base_bg": base_bg,
			"highlight_bg": highlight_bg,
		})


func _on_action_pressed() -> void:
	if _current_turn >= 0:
		# User may skip the remaining response pause with the button.
		if is_instance_valid(_user_response_tween):
			_user_response_tween.kill()
			_user_response_tween = null
		_advance_turn()
	else:
		_start_partner()


func _advance_turn() -> void:
	_current_turn += 1
	_unhighlight_all()

	if _current_turn >= _turns.size():
		_finish_conversation()
		return

	var turn: Dictionary = _turns[_current_turn]
	var is_app: bool = str(turn.get("role", "app")) == "app"

	_highlight(_current_turn)

	if is_app or not _partner_mode:
		# The app speaks this line.
		_set_status("🔊 گوش دهید: «" + str(turn.get("text", "")) + "»")

		if _action_btn:
			_action_btn.disabled = true
			_action_btn.text = "🤝  تمرین با برنامه"

		_speak(str(turn.get("text", "")), _advance_turn)
	else:
		# User's turn: leave time to repeat the line, then continue automatically.
		_set_status("🎤 نوبت شماست! بگویید: «" + str(turn.get("text", "")) + "» — خط بعدی پس از چند ثانیه پخش می‌شود.")

		if _action_btn:
			_action_btn.disabled = false
			_action_btn.text = "➡  بعدی"

		if is_instance_valid(_user_response_tween):
			_user_response_tween.kill()
		_user_response_tween = create_tween()
		_user_response_tween.tween_interval(USER_RESPONSE_PAUSE)
		_user_response_tween.tween_callback(_advance_turn)

func _start_partner() -> void:
	_stop_all_listening_players()
	_stop_tts()
	_unhighlight_all()

	_partner_mode = true
	_current_turn = -1

	_advance_turn()

func _on_page_changed(_index: int, page_id: String) -> void:
	# Re-tint the dark background to match the skill being practiced.
	_apply_ambient(SPEAK_ACCENT if page_id == "speaking" else LISTEN_ACCENT)

	# Stop speaking-page playback.
	_stop_tts()
	_unhighlight_all()

	_current_turn = -1

	if is_instance_valid(_user_response_tween):
		_user_response_tween.kill()
		_user_response_tween = null

	if _action_btn:
		_action_btn.disabled = false
		_action_btn.text = "🤝  تمرین با برنامه"

	# Stop listening playback too.
	_stop_all_listening_players()


func _finish_conversation() -> void:
	_unhighlight_all()

	_current_turn = -1
	if is_instance_valid(_user_response_tween):
		_user_response_tween.kill()
	_user_response_tween = null

	if _action_btn:
		_action_btn.disabled = false
		_action_btn.text = "🤝  تمرین با برنامه"

	_set_status("🎉 آفرین! گفتگو به پایان رسید.")

func _highlight(index: int) -> void:
	if index < 0 or index >= _turn_cards.size():
		return

	var entry: Dictionary = _turn_cards[index]
	var style: StyleBoxFlat = entry["style"]
	style.bg_color = entry["highlight_bg"]

	var card: Control = entry["card"]
	card.pivot_offset = card.size / 2.0

	var t := create_tween()
	t.tween_property(
		card,
		"scale",
		Vector2(1.02, 1.02),
		0.15
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhighlight_all() -> void:
	for entry in _turn_cards:
		var style: StyleBoxFlat = entry["style"]
		style.bg_color = entry["base_bg"]

		var card: Control = entry["card"]
		card.scale = Vector2.ONE


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


# ---------- TTS with completion callback ----------

func _speak(text: String, on_done: Callable) -> void:
	# Kill any previous fallback tween.
	if is_instance_valid(_tts_fallback_tween):
		_tts_fallback_tween.kill()

	# If TTS is unavailable, simulate a short speaking delay.
	if Global.english_voice_id == "" or not DisplayServer.has_method("tts_speak"):
		if on_done.is_valid():
			_tts_fallback_tween = create_tween()
			_tts_fallback_tween.tween_callback(on_done).set_delay(1.2)
		return

	_tts_done_cb = on_done

	if DisplayServer.has_method("tts_set_utterance_callback"):
		DisplayServer.tts_set_utterance_callback(
			DisplayServer.TTS_UTTERANCE_ENDED,
			_on_tts_utterance_ended
		)
		DisplayServer.tts_set_utterance_callback(
			DisplayServer.TTS_UTTERANCE_CANCELED,
			_on_tts_utterance_ended
		)

	DisplayServer.tts_speak(
		text,
		Global.english_voice_id,
		100,   # volume (0-100) — was accidentally 0 (mute)
		1.0,   # pitch
		1.0,   # rate
		100,   # utterance_id
		false  # interrupt
	)

func _on_tts_utterance_ended(_utterance_id: int) -> void:
	var cb := _tts_done_cb
	_tts_done_cb = Callable()

	if cb.is_valid():
		cb.call()


# ---------- Practice prompts ----------

func _build_practice(page: VBoxContainer, practice: Dictionary) -> void:
	page.add_child(_make_fa_label(_get_fa(practice.get("instruction", "")), 40, _text_color()))

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for prompt in practice.get("prompts", []):
		var chip := _make_button(str(prompt), SPEAK_ACCENT.lightened(0.1))
		chip.pressed.connect(func(): _ask_prompt(str(prompt), practice))
		flow.add_child(chip)

	page.add_child(flow)

	var sample := _make_label(
		"💡 " + str(practice.get("sample_yes", "")) + "   |   " + str(practice.get("sample_no", "")),
		38,
		SUCCESS,
		false
	)

	page.add_child(sample)


func _ask_prompt(prompt: String, practice: Dictionary) -> void:
	var question := str(practice.get("question_frame", "Are you going to ___?"))
	question = question.replace("___", prompt).replace("__", prompt)

	_set_status("🤖 " + question + "   (با صدای بلند جواب دهید!)")
	_speak(question, Callable())


# ============================================================
# PAGE 2 — LISTENING
# ============================================================

func _build_listening_page(conversations: Array) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 26)

	page.add_child(_make_banner(
		"🎧",
		"Listening",
		"شنیدار",
		"Listen all the way through before you look at the words. Your ears first, your eyes second.",
		"قبل از نگاه کردن به کلمات، تا انتها گوش دهید. اول گوش‌ها، بعد چشم‌ها.",
		LISTEN_ACCENT
	))

	for conv in conversations:
		page.add_child(_build_conversation_card(conv))

	return page


func _build_conversation_card(conv: Dictionary) -> PanelContainer:
	var conv_id := str(conv.get("id", ""))

	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = _panel_bg()
	style.set_corner_radius_all(18)
	style.border_width_left = 6
	style.border_color = LISTEN_ACCENT
	style.set_content_margin_all(22)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)

	# ------------------------------------------------------------
	# Title row.
	# ------------------------------------------------------------
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Conversation title: one line, no wrapping.
	var title := _make_label(_get_en(conv.get("title", "")), 50, _text_color(), true, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	vb.add_child(head)

	# Task instruction.
	vb.add_child(_make_label(_get_en(conv.get("task", "")), 42, _text_soft(), false))

	# ------------------------------------------------------------
	# AudioPanel reference (shared across all conversation cards).
	# ------------------------------------------------------------
	var audio_panel := _get_or_create_audio_panel()

	var play_btn := _make_button("پخش گفتگو", LISTEN_ACCENT)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ------------------------------------------------------------
	# Transcript — English (left-aligned) + Farsi (right-aligned).
	# ------------------------------------------------------------
	var transcript_box := VBoxContainer.new()
	transcript_box.add_theme_constant_override("separation", 14)
	transcript_box.visible = false

	var en_transcript := _make_label(_get_en(conv.get("transcript", "")), 40, _text_soft(), false)
	en_transcript.text_direction = Control.TEXT_DIRECTION_LTR
	en_transcript.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	transcript_box.add_child(en_transcript)

	var fa_transcript_text := _get_fa(conv.get("transcript", ""))
	if fa_transcript_text != "":
		var fa_transcript := _make_fa_label(fa_transcript_text, 40, _text_soft())
		transcript_box.add_child(fa_transcript)

	var transcript_btn := _make_button("📜  نمایش متن", LISTEN_ACCENT)
	transcript_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Store the button so other cards can reset this one.
	_listening_players.append({
		"audio_panel": audio_panel,
		"id": conv_id,
		"play_btn": play_btn,
		"transcript_btn": transcript_btn,
	})

	transcript_btn.pressed.connect(func():
		transcript_box.visible = not transcript_box.visible

		if transcript_box.visible:
			transcript_btn.text = "🙈  مخفی کردن متن"
		else:
			transcript_btn.text = "📜  نمایش متن"
	)

	play_btn.pressed.connect(func():
		_play_listening(conv, play_btn, transcript_btn)
	)

	vb.add_child(play_btn)
	vb.add_child(transcript_btn)
	vb.add_child(transcript_box)

	# ------------------------------------------------------------
	# Comprehension questions.
	# ------------------------------------------------------------
	for exercise in conv.get("exercises", []):
		var engine := ExerciseEngine.new()
		vb.add_child(engine)
		engine.build(exercise)

	card.add_child(vb)
	return card

func _stop_all_listening_players() -> void:
	_audio_panel_active_id = ""
	for entry in _listening_players:
		var audio_panel := entry.get("audio_panel", null) as Node

		if audio_panel == null:
			continue

		if audio_panel.is_playing():
			audio_panel.stop_and_close()
			_set_listening_entry_stopped(entry)


func _set_listening_entry_stopped(entry: Dictionary) -> void:
	var btn := entry.get("play_btn", null) as Button

	if btn:
		btn.text = "پخش گفتگو"


func _reset_listening_tts_ui() -> void:
	if _listening_tts_active_id == "":
		return

	for entry in _listening_players:
		if str(entry.get("id", "")) == _listening_tts_active_id:
			_set_listening_entry_stopped(entry)
			break


func _on_listening_tts_finished(
	conv_id: String,
	play_btn: Button,
	transcript_btn: Button
) -> void:
	if _listening_tts_active_id != conv_id:
		return

	_listening_tts_active_id = ""
	_listened[conv_id] = true

	play_btn.text = "پخش گفتگو"

	transcript_btn.disabled = false
	transcript_btn.text = "📜  نمایش متن"
	_unlock_transcript_button(transcript_btn)


func _get_or_create_audio_panel() -> Node:
	if _audio_panel_instance != null and is_instance_valid(_audio_panel_instance):
		return _audio_panel_instance

	if is_inside_tree() and ResourceLoader.exists(AUDIO_PANEL_SCENE_PATH):
		var scene := load(AUDIO_PANEL_SCENE_PATH) as PackedScene
		if scene != null:
			_audio_panel_instance = scene.instantiate()
			_audio_panel_instance.add_to_group("audio_panel")
			add_child(_audio_panel_instance)
			_audio_panel_instance.audio_finished.connect(_on_audio_panel_finished)
			_audio_panel_instance.audio_closed.connect(_on_audio_panel_closed)
			page_view.add_swipe_blocker(_audio_panel_instance)
			return _audio_panel_instance
	return null


func _on_audio_panel_finished() -> void:
	_audio_panel_active_id = ""
	for entry in _listening_players:
		var entry_id := str(entry.get("id", ""))
		if _listened.get(entry_id, false):
			continue
		var play_btn := entry.get("play_btn", null) as Button
		var transcript_btn := entry.get("transcript_btn", null) as Button
		if play_btn:
			play_btn.text = "پخش گفتگو"
		if transcript_btn:
			transcript_btn.disabled = false
			transcript_btn.text = "📜  نمایش متن"
			_unlock_transcript_button(transcript_btn)


func _on_audio_panel_closed() -> void:
	for entry in _listening_players:
		var play_btn := entry.get("play_btn", null) as Button
		if play_btn:
			play_btn.text = "پخش گفتگو"


func _unlock_transcript_button(btn: Button) -> void:
	var unlock_style := StyleBoxFlat.new()
	unlock_style.bg_color = LISTEN_ACCENT
	unlock_style.set_corner_radius_all(12)
	unlock_style.set_content_margin_all(14)

	var unlock_hover: StyleBoxFlat = unlock_style.duplicate()
	unlock_hover.bg_color = LISTEN_ACCENT.lightened(0.15)

	btn.add_theme_stylebox_override("normal", unlock_style)
	btn.add_theme_stylebox_override("hover", unlock_hover)
	btn.add_theme_stylebox_override("pressed", unlock_hover)


# Builds the logical res:// path for a conversation's audio clip. The JSON may
# store either a full path or a bare filename; either way it is resolved against
# assets/audio/v{book}/l{lesson}/. Lessons may ship more than one clip, so the
# conversation id (conv1, conv2, ...) is used as a sensible fallback filename.
func _resolve_listening_audio_path(conv: Dictionary) -> String:
	var audio_value := str(conv.get("audio", ""))
	var fallback := "listening_1.mp3"
	var conv_id := str(conv.get("id", ""))
	if conv_id.begins_with("conv"):
		var num := conv_id.substr(4).to_int()
		if num > 0:
			fallback = "listening_%d.mp3" % num
	return Global.resolve_audio_path(
		Global.current_book,
		Global.current_lesson,
		audio_value,
		fallback
	)


func _play_listening(
	conv: Dictionary,
	play_btn: Button,
	transcript_btn: Button
) -> void:
	var conv_id := str(conv.get("id", ""))
	var path := _resolve_listening_audio_path(conv)

	# A clip is only usable when it was bundled in the APK or already
	# downloaded — Content knows about both locations.
	var has_audio := path != "" and Content.has_asset(path)

	# True only if this same card is currently using fallback TTS.
	var same_tts_active := (_listening_tts_active_id == conv_id and not has_audio)

	# Stop any active conversation TTS and other conversation audio.
	_stop_all_listening_players()

	# Stop any TTS except the one we are about to toggle as "Stop".
	if not same_tts_active:
		_stop_tts()

	# ------------------------------------------------------------
	# No real audio file: fallback to TTS reading the transcript.
	# ------------------------------------------------------------
	if not has_audio:
		if _listening_tts_active_id == conv_id:
			# User hit Stop while fallback TTS was reading.
			_stop_tts()

			play_btn.text = "پخش گفتگو"
			return

		_listening_tts_active_id = conv_id

		play_btn.text = "در حال پخش..."

		_speak(
			_get_en(conv.get("transcript", "")),
			Callable(_on_listening_tts_finished).bind(conv_id, play_btn, transcript_btn)
		)
		return

	# ------------------------------------------------------------
	# Real audio file — play through AudioPanel.
	# ------------------------------------------------------------
	var audio_panel := _get_or_create_audio_panel()
	if audio_panel == null:
		push_warning("AudioPanel could not be created for: " + conv_id)
		return

	if audio_panel.is_playing():
		# User hit the button while audio was playing -> stop it.
		_audio_panel_active_id = ""
		audio_panel.stop_and_close()

		play_btn.text = "پخش گفتگو"
		return

	# Start the conversation audio through AudioPanel.
	_audio_panel_active_id = conv_id
	audio_panel.load_and_play(path)

	play_btn.text = "در حال پخش..."

# ============================================================
# SHARED WIDGETS
# ============================================================

func _make_banner(
	icon: String,
	en: String,
	fa: String,
	desc_en: String,
	desc_fa: String,
	accent: Color
) -> PanelContainer:
	var banner := PanelContainer.new()

	var b_style := StyleBoxFlat.new()
	b_style.bg_color = accent
	b_style.set_corner_radius_all(20)
	b_style.set_content_margin_all(26)

	banner.add_theme_stylebox_override("panel", b_style)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 84)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(ic)

	# Choose readable text color based on accent brightness.
	var text_color := Color.WHITE
	if accent.get_luminance() > 0.6:
		text_color = Color("#0b1229")

	var sub_color := Color(text_color.r, text_color.g, text_color.b, 0.85)

	# Banner title: wraps so long titles never inflate the page width.
	var en_l := _make_label(en, 62, text_color, true)
	en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(en_l)

	var fa_l := _make_fa_label(fa, 46, sub_color)
	fa_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(fa_l)

	# Description stays wrapped.
	if desc_en != "":
		bv.add_child(_make_label(
			desc_en,
			40,
			Color(text_color.r, text_color.g, text_color.b, 0.95),
			false
		))

	if desc_fa != "":
		bv.add_child(_make_fa_label(
			desc_fa,
			38,
			Color(text_color.r, text_color.g, text_color.b, 0.8)
		))

	banner.add_child(bv)
	return banner


func _make_pattern_card(p: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = _panel_bg()
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_color = SPEAK_ACCENT.lightened(0.2)
	style.set_content_margin_all(16)

	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	var q_text := _get_en(p.get("q", ""))
	var a_text := _get_en(p.get("a", ""))

	vb.add_child(_make_label("❓  " + q_text, 42, _text_color(), true))
	vb.add_child(_make_label("💬  " + a_text, 42, SUCCESS, false))

	card.add_child(vb)
	return card


func _make_section_title(en: String, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Section title: wraps so it always fits the screen width.
	# Now displayed in Persian (RTL/right-aligned), so the accent bar
	# goes on the RIGHT side of the row.
	var title := _make_fa_label(en, 50, _text_color(), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(6, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	return row


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)

	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = color.lightened(0.15)

	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	# Buttons now display Persian labels, so use the Persian font.
	if font_farsi:
		btn.add_theme_font_override("font", font_farsi)

	btn.pressed.connect(func():
		btn.pivot_offset = btn.size / 2.0

		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
		t.tween_property(btn, "scale", Vector2.ONE, 0.1)
	)

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

	# Slightly shrink very long one-line titles so they fit better.
	var final_size := font_size
	if not do_wrap:
		if text.length() > 30:
			final_size = int(float(font_size) * 0.85)
		if text.length() > 55:
			final_size = int(float(font_size) * 0.72)

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

	# Slightly shrink very long one-line Persian titles.
	var final_size := font_size
	if not do_wrap:
		if text.length() > 34:
			final_size = int(float(font_size) * 0.85)
		if text.length() > 60:
			final_size = int(float(font_size) * 0.72)

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
func _on_home_pressed() -> void:
	_stop_tts()
	_stop_all_listening_players()
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_back_button_pressed() -> void:
	_stop_tts()
	_stop_all_listening_players()

	back_button.pivot_offset = back_button.size / 2.0

	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)

	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
