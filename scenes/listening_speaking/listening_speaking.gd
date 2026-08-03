extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# LISTENING & SPEAKING SCENE — two swipeable pages via PageView
#   Page 1 "Speaking"  → strategy, patterns, conversation PARTNER, drills
#   Page 2 "Listening" → listen-first audio cards + comprehension
# The app becomes the learner's conversation partner (via TTS).
# ============================================================

const SCENE_LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

var font_regular: FontFile
var font_bold: FontFile
var font_farsi: FontFile

# Page accents: warm = speaking (production), cool = listening (reception)
const SPEAK_ACCENT  := Color("#EA580C")
const LISTEN_ACCENT := Color("#2563EB")

@onready var back_button: Button = $HeaderBar/HeaderContent/BackButton
@onready var header_title: Label = $HeaderBar/HeaderContent/HeaderTitle
@onready var page_view: PageView = $MarginContainer/MainLayout/PageView

# ---------- Speaking (partner) state ----------
var _turns: Array = []
var _turn_cards: Array = []
var _current_turn: int = -1
var _partner_mode: bool = false        # false = hear full model, true = practice
var _status_label: Label
var _action_btn: Button
var _tts_done_cb: Callable
var _speaking_data: Dictionary = {}

# ---------- Listening state ----------
var _listening_players: Array = []     # {player, id}
var _listened: Dictionary = {}         # conv_id -> bool


func _ready() -> void:
	font_regular = load(FONT_REGULAR_PATH)
	font_bold    = load(FONT_BOLD_PATH)
	font_farsi   = load(FONT_VAZIRMATN)
	if font_bold: header_title.add_theme_font_override("font", font_bold)
	back_button.pressed.connect(_on_back_button_pressed)
	page_view.page_changed.connect(_on_page_changed)
	_apply_ambient(SPEAK_ACCENT)
	
	header_title.text = "Lesson %d\nListening & Speaking" % Global.current_lesson
	
	var data: Dictionary = Global.load_category("listening_speaking", Global.current_book, Global.current_lesson)
	if data.is_empty():
		return
	_speaking_data = data.get("speaking", {})
	
	page_view.add_page("speaking",  "Speaking",  "🗣", _build_speaking_page(_speaking_data))
	page_view.add_page("listening", "Listening", "🎧", _build_listening_page(data.get("listening", [])))


func _on_page_changed(_index: int, page_id: String) -> void:
	# Re-tint the room to match the skill being practiced
	_apply_ambient(SPEAK_ACCENT if page_id == "speaking" else LISTEN_ACCENT)
	# Stop talking / playing when the learner leaves the page
	DisplayServer.tts_stop()
	for entry in _listening_players:
		entry["player"].stop()


# ============================================================
# PAGE 1 — SPEAKING  (the app is your conversation partner)
# ============================================================
func _build_speaking_page(speaking: Dictionary) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	
	# --- Strategy banner ---
	page.add_child(_make_banner(str(speaking.get("icon", "🗣")),
		speaking.get("strategy_name", {}).get("en", "Speaking"),
		speaking.get("strategy_name", {}).get("fa", "گفتار"),
		speaking.get("intro", {}).get("en", ""),
		speaking.get("intro", {}).get("fa", ""),
		SPEAK_ACCENT))
	
	# --- Useful patterns ---
	var patterns: Array = speaking.get("patterns", [])
	if not patterns.is_empty():
		page.add_child(_make_section_title("Useful Patterns", SPEAK_ACCENT))
		for p in patterns:
			page.add_child(_make_pattern_card(p))
	
	# --- Model conversation + partner mode ---
	_turns = speaking.get("model_conversation", {}).get("turns", [])
	if not _turns.is_empty():
		page.add_child(_make_section_title(speaking.get("model_conversation", {}).get("title", {}).get("en", "Conversation"), SPEAK_ACCENT))
		_build_partner_controls(page)
		_build_turn_cards(page)
	
	# --- Practice prompts ---
	var practice: Dictionary = speaking.get("practice", {})
	if not practice.get("prompts", []).is_empty():
		page.add_child(_make_section_title("Your Turn to Answer", SPEAK_ACCENT))
		_build_practice(page, practice)
	
	return page


func _build_partner_controls(page: VBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	
	var listen_btn := _make_button("▶  Hear the Model", Color("#64748B"))
	listen_btn.pressed.connect(_play_model)
	box.add_child(listen_btn)
	
	_action_btn = _make_button("🤝  Practice with the App", SPEAK_ACCENT)
	_action_btn.pressed.connect(_on_action_pressed)
	box.add_child(_action_btn)
	
	page.add_child(box)
	
	_status_label = Label.new()
	_status_label.text = "Tap “Practice with the App” — it speaks Sara’s lines, you speak yours."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.add_theme_font_size_override("font_size", 32)
	_status_label.add_theme_color_override("font_color", Color("#64748B"))
	if font_regular: _status_label.add_theme_font_override("font", font_regular)
	page.add_child(_status_label)


func _build_turn_cards(page: VBoxContainer) -> void:
	_turn_cards.clear()
	for i in _turns.size():
		var turn: Dictionary = _turns[i]
		var is_app: bool = turn.get("role", "app") == "app"
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#FFF7ED") if is_app else Color("#F0FDF4")
		style.set_corner_radius_all(14)
		style.border_width_left = 5
		style.border_color = SPEAK_ACCENT if is_app else Color("#16A34A")
		style.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", style)
		
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		var role := Label.new()
		role.text = ("🤖 " if is_app else "🎤 ") + str(turn.get("speaker", ""))
		role.add_theme_font_size_override("font_size", 28)
		role.add_theme_color_override("font_color", SPEAK_ACCENT if is_app else Color("#16A34A"))
		if font_bold: role.add_theme_font_override("font", font_bold)
		vb.add_child(role)
		vb.add_child(_make_label(str(turn.get("text", "")), 36, Color("#1E293B"), false))
		vb.add_child(_make_fa_label(str(turn.get("fa", "")), 30))
		card.add_child(vb)
		
		page.add_child(card)
		_turn_cards.append({"card": card, "style": style, "is_app": is_app})


func _on_action_pressed() -> void:
	if _current_turn >= 0 and _current_turn < _turns.size() - 1:
		# Mid-conversation: this is the "Next" button on the user's turn
		_advance_turn()
	else:
		_start_partner()


func _start_partner() -> void:
	_partner_mode = true
	_current_turn = -1
	_advance_turn()


func _play_model() -> void:
	_partner_mode = false
	_current_turn = -1
	_advance_turn()


func _advance_turn() -> void:
	_current_turn += 1
	_unhighlight_all()
	if _current_turn >= _turns.size():
		_finish_conversation()
		return
	
	var turn: Dictionary = _turns[_current_turn]
	var is_app: bool = turn.get("role", "app") == "app"
	_highlight(_current_turn)
	
	if is_app or not _partner_mode:
		# The app speaks this line (always in model mode; only app lines in partner mode)
		_set_status(("🤖 " if is_app else "🔊 ") + "Listen: “" + str(turn["text"]) + "”")
		_action_btn.disabled = true
		_speak(str(turn["text"]), _advance_turn)
	else:
		# User's turn in partner mode
		_set_status("🎤 Your turn! Say: “" + str(turn["text"]) + "”  —  then tap Next.")
		_action_btn.disabled = false
		_action_btn.text = "➡  Next"


func _finish_conversation() -> void:
	_unhighlight_all()
	_current_turn = -1
	_action_btn.disabled = false
	_action_btn.text = "🤝  Practice Again"
	if _partner_mode:
		_set_status("🎉 Great job! You just held a real English conversation. Swipe to Listening →")
	else:
		_set_status("That was the model. Now tap “Practice with the App” and take a role!")


func _highlight(index: int) -> void:
	if index < 0 or index >= _turn_cards.size(): return
	var entry: Dictionary = _turn_cards[index]
	var style: StyleBoxFlat = entry["style"]
	style.bg_color = Color("#FDE68A") if entry["is_app"] else Color("#BBF7D0")
	var card: Control = entry["card"]
	card.pivot_offset = card.size / 2.0
	var t := create_tween()
	t.tween_property(card, "scale", Vector2(1.02, 1.02), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhighlight_all() -> void:
	for i in _turns.size():
		var entry: Dictionary = _turn_cards[i]
		var style: StyleBoxFlat = entry["style"]
		style.bg_color = Color("#FFF7ED") if entry["is_app"] else Color("#F0FDF4")
		(entry["card"] as Control).scale = Vector2.ONE


func _set_status(text: String) -> void:
	if _status_label: _status_label.text = text


# ---------- TTS with a completion callback ----------
func _speak(text: String, on_done: Callable) -> void:
	if Global.english_voice_id == "":
		if on_done.is_valid():
			var tw := create_tween()
			tw.tween_callback(on_done).set_delay(1.2)
		return
	
	_tts_done_cb = on_done
	
	# Register the callback globally for utterance events
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_utterance_ended)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_tts_utterance_ended)
	
	# Call tts_speak with valid argument types (7th argument is bool)
	DisplayServer.tts_speak(text, Global.english_voice_id, 50, 1.0, 1.0, 0, false)

func _on_tts_event(event: int, _utterance_id: int) -> void:
	if event == DisplayServer.TTS_UTTERANCE_ENDED or event == DisplayServer.TTS_UTTERANCE_CANCELED:
		var cb := _tts_done_cb
		_tts_done_cb = Callable()
		if cb.is_valid():
			cb.call()

func _on_tts_utterance_ended(_utterance_id: int) -> void:
	var cb := _tts_done_cb
	_tts_done_cb = Callable()
	if cb.is_valid():
		cb.call()

# ---------- Practice prompts ----------
func _build_practice(page: VBoxContainer, practice: Dictionary) -> void:
	page.add_child(_make_label(str(practice.get("instruction", {}).get("en", "")), 33, Color("#64748B"), false))
	
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("separation", 12)
	for prompt in practice.get("prompts", []):
		var chip := _make_button(str(prompt), SPEAK_ACCENT.lightened(0.2))
		chip.pressed.connect(func(): _ask_prompt(str(prompt), practice))
		flow.add_child(chip)
	page.add_child(flow)
	
	var sample := _make_label(
		"💡 " + str(practice.get("sample_yes", "")) + "   |   " + str(practice.get("sample_no", "")),
		30, Color("#16A34A"), false)
	page.add_child(sample)


func _ask_prompt(prompt: String, practice: Dictionary) -> void:
	var question: String = str(practice.get("question_frame", "Are you going to ___?")).replace("___", prompt)
	_set_status("🤖 " + question + "   (answer aloud!)")
	_speak(question, Callable())


# ============================================================
# PAGE 2 — LISTENING  (listen first, transcript unlocks after)
# ============================================================
func _build_listening_page(conversations: Array) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 26)
	
	page.add_child(_make_banner("🎧", "Listening", "شنیدار",
		"Listen all the way through before you look at the words. Your ears first, your eyes second.",
		"قبل از نگاه کردن به کلمات، تا انتها گوش دهید. اول گوش‌ها، بعد چشم‌ها.",
		LISTEN_ACCENT))
	
	for conv in conversations:
		page.add_child(_build_conversation_card(conv))
	
	return page


func _build_conversation_card(conv: Dictionary) -> PanelContainer:
	var conv_id: String = str(conv.get("id", ""))
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(18)
	style.border_width_left = 6
	style.border_color = LISTEN_ACCENT
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	
	# Title row + listened badge
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_make_label(str(conv.get("title", {}).get("en", "Conversation")), 40, Color("#1E293B"), true))
	var badge := Label.new()
	badge.text = "🔒 Not listened yet"
	badge.add_theme_font_size_override("font_size", 26)
	badge.add_theme_color_override("font_color", Color("#94A3B8"))
	if font_bold: badge.add_theme_font_override("font", font_bold)
	head.add_child(badge)
	vb.add_child(head)
	
	# Task instruction
	vb.add_child(_make_label(str(conv.get("task", {}).get("en", "")), 34, Color("#334155"), false))
	
	# Big play button + player
	var player := AudioStreamPlayer.new()
	add_child(player)
	_listening_players.append({"player": player, "id": conv_id})
	
	var play_btn := _make_button("▶  Play the Conversation", LISTEN_ACCENT)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(func(): _play_listening(conv, player, play_btn, badge))
	vb.add_child(play_btn)
	
	# Transcript — locked until first full listen
	var transcript_label := Label.new()
	transcript_label.text = str(conv.get("transcript", {}).get("en", ""))
	transcript_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	transcript_label.add_theme_font_size_override("font_size", 32)
	transcript_label.add_theme_color_override("font_color", Color("#475569"))
	if font_regular: transcript_label.add_theme_font_override("font", font_regular)
	transcript_label.visible = false
	
	var transcript_btn := _make_button("🔒  Listen first to unlock the transcript", Color("#94A3B8"))
	transcript_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_btn.disabled = true
	transcript_btn.pressed.connect(func():
		transcript_label.visible = not transcript_label.visible
		transcript_btn.text = "🙈  Hide Transcript" if transcript_label.visible else "📜  Show Transcript"
	)
	vb.add_child(transcript_btn)
	vb.add_child(transcript_label)
	
	player.finished.connect(func():
		_listened[conv_id] = true
		play_btn.text = "🔁  Play Again"
		badge.text = "✅ Listened"
		badge.add_theme_color_override("font_color", Color("#16A34A"))
		transcript_btn.disabled = false
		transcript_btn.text = "📜  Show Transcript"
		var t_style: StyleBoxFlat = transcript_btn.get_theme_stylebox("normal").duplicate()
		t_style.bg_color = LISTEN_ACCENT.lightened(0.3)
		transcript_btn.add_theme_stylebox_override("normal", t_style)
	)
	
	# Comprehension questions (visible — they tell the learner what to listen for)
	for exercise in conv.get("exercises", []):
		var engine := ExerciseEngine.new()
		vb.add_child(engine)
		engine.build(exercise)
	
	card.add_child(vb)
	return card


func _play_listening(conv: Dictionary, player: AudioStreamPlayer, play_btn: Button, _badge: Label) -> void:
	# Only one conversation at a time
	for entry in _listening_players:
		if entry["player"] != player:
			entry["player"].stop()
	DisplayServer.tts_stop()
	
	var path: String = str(conv.get("audio", ""))
	if path == "" or not ResourceLoader.exists(path):
		# No audio file yet — fall back to reading the transcript aloud
		_speak(str(conv.get("transcript", {}).get("en", "")), Callable())
		play_btn.text = "🔁  Play Again"
		return
	
	if player.playing:
		player.stop()
		play_btn.text = "▶  Play the Conversation"
		return
	player.stream = load(path)
	player.play()
	play_btn.text = "⏸  Pause"


# ============================================================
# SHARED WIDGETS
# ============================================================
func _make_banner(icon: String, en: String, fa: String, desc_en: String, desc_fa: String, accent: Color) -> PanelContainer:
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
	ic.add_theme_font_size_override("font_size", 72)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(ic)
	var en_l := _make_label(en, 50, Color.WHITE, true)
	en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(en_l)
	var fa_l := _make_fa_label(fa, 36)
	fa_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	fa_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(fa_l)
	if desc_en != "":
		bv.add_child(_make_label(desc_en, 32, Color(1, 1, 1, 0.95), false))
	if desc_fa != "":
		var dfa := _make_fa_label(desc_fa, 30)
		dfa.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		bv.add_child(dfa)
	banner.add_child(bv)
	return banner


func _make_pattern_card(p: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFF7ED")
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_color = SPEAK_ACCENT.lightened(0.3)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(_make_label("❓ " + str(p.get("q", {}).get("en", "")), 34, Color("#1E293B"), true))
	vb.add_child(_make_label("💬 " + str(p.get("a", {}).get("en", "")), 34, Color("#16A34A"), false))
	card.add_child(vb)
	return card


func _make_section_title(en: String, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(6, 44)
	row.add_child(bar)
	row.add_child(_make_label(en, 40, Color("#1E293B"), true))
	return row


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
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	if font_bold: btn.add_theme_font_override("font", font_bold)
	btn.pressed.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
		t.tween_property(btn, "scale", Vector2.ONE, 0.1)
	)
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


func _apply_ambient(accent: Color) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.97, 0.98, 1.0, 1.0);
uniform vec4 bottom : source_color = vec4(0.92, 0.94, 0.98, 1.0);
uniform vec4 accent : source_color = vec4(0.9, 0.4, 0.1, 1.0);
void fragment() {
	vec4 grad = mix(top, bottom, UV.y);
	float d = distance(UV, vec2(0.5, -0.1));
	float glow = clamp(1.0 - d * 1.4, 0.0, 1.0);
	COLOR = mix(grad, accent, glow * 0.10);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("accent", accent)


# ============================================================
# NAVIGATION
# ============================================================
func _on_back_button_pressed() -> void:
	DisplayServer.tts_stop()
	for entry in _listening_players:
		entry["player"].stop()
	back_button.pivot_offset = back_button.size / 2.0
	var t := create_tween()
	t.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	TransitionManager.change_scene(SCENE_LESSON_MENU)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
