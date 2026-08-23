class_name GrammarHint
extends Control
# ============================================================
#  GRAMMAR HINT — a big, friendly light-bulb hint affordance.
# ------------------------------------------------------------
#  * A large 💡 button that sits near the bottom-centre of the
#    lesson's content card.
#  * When the learner gets an answer wrong, GrammarLesson calls
#    flash() to draw attention with expanding rings (heartbeat
#    pulse) radiating from behind the bulb.
#  * Tapping the bulb emits hint_requested; the caller fills the
#    hint text and calls show_bubble() to reveal a bright,
#    friendly bubble (a different message system from the modal
#    FeedbackPopup).
# ============================================================

signal hint_requested

const PULSE_PERIOD := 1.2
const RING_COLOR := Color(1.0, 0.82, 0.3, 0.5)

var _bulb: Button
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_margin: MarginContainer

var _pulse := 0.0
var _time := 0.0
var _pulsing := false


func _ready() -> void:
	# The overlay spans the bottom of the card, right over the answer
	# buttons. Keep it fully click-through (IGNORE on every container)
	# so it never blocks the exercise buttons underneath; only the bulb
	# Button itself captures presses.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# Push the bubble + bulb down to the bottom so they sit near the
	# bottom edge of the card.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", GrammarTheme.rounded_box(GrammarTheme.WARNING, 20, Color(1.0, 0.92, 0.6, 0.6), 2))
	vbox.add_child(_bubble)

	_bubble_margin = MarginContainer.new()
	_bubble_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_margin.add_theme_constant_override("margin_left", 20)
	_bubble_margin.add_theme_constant_override("margin_right", 20)
	_bubble_margin.add_theme_constant_override("margin_top", 14)
	_bubble_margin.add_theme_constant_override("margin_bottom", 14)
	_bubble.add_child(_bubble_margin)

	_bubble_label = Label.new()
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(320, 0)
	_bubble_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SMALL_SIZE)
	_bubble_label.add_theme_color_override("font_color", Color(0.09, 0.09, 0.12))
	_bubble_label.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	_bubble_margin.add_child(_bubble_label)

	# The bulb itself: a big transparent emoji button. STOP so its own
	# presses are captured (it is the only interactive part of the hint).
	_bulb = Button.new()
	_bulb.text = "💡"
	_bulb.custom_minimum_size = Vector2(96, 96)
	_bulb.focus_mode = Control.FOCUS_NONE
	_bulb.mouse_filter = Control.MOUSE_FILTER_STOP
	_bulb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bulb.add_theme_font_size_override("font_size", 58)
	var flat := StyleBoxEmpty.new()
	_bulb.add_theme_stylebox_override("normal", flat)
	_bulb.add_theme_stylebox_override("hover", flat)
	_bulb.add_theme_stylebox_override("pressed", flat)
	_bulb.add_theme_stylebox_override("focus", flat)
	_bulb.add_theme_stylebox_override("disabled", flat)
	_bulb.pressed.connect(func() -> void: hint_requested.emit())
	vbox.add_child(_bulb)


# Public API ---------------------------------------------------

func set_hint(text: String) -> void:
	if _bubble_label != null:
		_bubble_label.text = text


func show_bubble() -> void:
	if _bubble == null:
		return
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_bubble.pivot_offset = _bubble.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(_bubble, "scale", Vector2.ONE, 0.3)


func hide_bubble() -> void:
	if _bubble != null:
		_bubble.visible = false
		_bubble.scale = Vector2.ONE
		_bubble.modulate.a = 1.0


func toggle_bubble() -> void:
	if _bubble != null and _bubble.visible:
		hide_bubble()
	else:
		show_bubble()


# Start / stop the expanding-ring pulse used to attract attention
# after a wrong answer.
func flash() -> void:
	_pulsing = true
	_time = 0.0
	queue_redraw()


func stop_flash() -> void:
	_pulsing = false
	queue_redraw()


func _process(delta: float) -> void:
	if _pulsing:
		_time += delta
		_pulse = fmod(_time / PULSE_PERIOD, 1.0)
		queue_redraw()


func _draw() -> void:
	if not _pulsing or _bulb == null:
		return

	var center: Vector2 = _bulb.position + _bulb.size * 0.5
	var max_radius := 78.0
	var rings := 3

	for i in rings:
		var t := fmod(_pulse + float(i) / float(rings), 1.0)
		var radius := 14.0 + t * (max_radius - 14.0)
		var alpha := (1.0 - t) * 0.45
		draw_arc(center, radius, 0.0, TAU, 48, Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, alpha), 4.0)
