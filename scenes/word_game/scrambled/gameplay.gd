extends Control
## ============================================================
##  GAMEPLAY — the board screen of «بازی املا».
##
##  Hosted inside ScrambledWords.tscn (which owns the header bar and the back
##  navigation), so this screen is only the game itself: the chips, the timer,
##  the meaning card, the board and the win feedback.
##
##  It drives ScrambledGameManager rather than holding session state, which is
##  why the results screen can read the very same run and why leaving the
##  screen never loses a session.
##
##  Two rules shape every decision here: a wrong arrangement is never punished
##  (the tiles only nudge amber when the word is one or two letters away) and
##  the word is never solved *for* the player — the hint gives the meaning,
##  which is the whole point of a spelling game.
## ============================================================

signal session_finished()
signal quit_requested()

const BOARD_SCENE := preload("res://scenes/word_game/scrambled/TileBoard.tscn")

const PRAISE_LINES := ["آفرین!", "عالی بود!", "درسته!", "چه سریع!"]
const INSTRUCTION_TEXT := "حروف را با انگشت بکش و کلمه را بساز"
const INSTRUCTION_FADE_TIME := 7.0
const HINT_CAPTION := "معنی این کلمه چیست؟"
const HINT_FA_CAPTION := "معنی فارسی"
const HINT_READY_TEXT := "راهنما آماده است — معنی کلمه را ببین"
const CONFIRM_TITLE := "از بازی خارج می‌شوی؟"
const CONFIRM_BODY := "پیشرفت همین بازی از دست می‌رود."
const CONFIRM_BODY_SAVED := "امتیازهایی که گرفته‌ای ثبت می‌شود."
const CONFIRM_STAY := "ادامه می‌دهم"
const CONFIRM_LEAVE := "خارج می‌شوم"

var _board: ScrambledTileBoard = null
var _confetti: CPUParticles2D = null
var _layout: VBoxContainer = null
var _progress_label: Label = null
var _mode_label: Label = null
var _score_label: Label = null
var _worth_label: Label = null
var _timer_bar: ProgressBar = null
var _time_label: Label = null
var _instruction_label: Label = null
var _hint_card: PanelContainer = null
var _hint_english: Label = null
var _hint_persian: Label = null
var _hint_worth: Label = null
var _hint_button: Button = null
var _praise_label: Label = null
var _points_label: Label = null
var _confirm_layer: Control = null
var _confirm_body: Label = null

var _elapsed := 0.0
var _playing := false
var _solved := false
var _hint_shown := false
var _hint_ready := false
var _closing := false
var _bar_fill: StyleBoxFlat = null
var _bar_track: StyleBoxFlat = null
var _last_bar_color := Color(0, 0, 0, 0)
var _last_worth := -1


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	_start_word(true)


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_update_timer()
	if not _hint_ready and _elapsed >= ScrambledGameManager.hint_delay():
		_show_hint_button()


## Called by the host on the Android back button (and by its own header).
func handle_back() -> void:
	if _confirm_layer != null and _confirm_layer.visible:
		_close_confirm()
		return
	_open_confirm()


func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	var bg := get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = ScrambledTheme.page_tint()
	_bar_track.bg_color = ScrambledTheme.timer_track_color()
	_time_label.add_theme_color_override("font_color", MenuStyle.text())
	_instruction_label.add_theme_color_override("font_color", MenuStyle.subtitle_color())
	if _board != null:
		_board.queue_redraw()


## --------------------------------------------------------- leave the game --
func _open_confirm() -> void:
	var competition := ScrambledGameManager.is_competition()
	_confirm_body.text = CONFIRM_BODY_SAVED if competition else CONFIRM_BODY
	_confirm_layer.visible = true
	_confirm_layer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_confirm_layer, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.click()


func _close_confirm() -> void:
	_confirm_layer.visible = false


## Leaves the session: a competition keeps the points already earned, a lesson
## keeps the words already practised (both are written by the manager).
func _leave_game() -> void:
	_closing = true
	ScrambledGameManager.abandon()
	quit_requested.emit()
## ------------------------------------------------------------- the screen --
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_layout = VBoxContainer.new()
	_layout.name = "Layout"
	_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout.offset_left = 34.0
	_layout.offset_right = -34.0
	_layout.offset_top = 24.0
	_layout.offset_bottom = -24.0
	_layout.add_theme_constant_override("separation", 14)
	add_child(_layout)

	# Which word, which mode, what it is still worth, the score so far.
	var chip_row := HBoxContainer.new()
	chip_row.name = "ChipRow"
	chip_row.custom_minimum_size = Vector2(0, 74)
	chip_row.add_theme_constant_override("separation", 12)
	_layout.add_child(chip_row)
	_progress_label = _make_chip(DesignTokens.ACCENT, 30)
	chip_row.add_child(_progress_label)
	_mode_label = _make_chip(Color("#C77DFF"), 28)
	chip_row.add_child(_mode_label)
	var flex := Control.new()
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_row.add_child(flex)
	_worth_label = _make_chip(Color("#FFB703"), 28)
	chip_row.add_child(_worth_label)
	_score_label = _make_chip(Color("#31C463"), 30)
	chip_row.add_child(_score_label)

	# The timer: fills towards the hint (learning) or the last score band.
	var timer_row := HBoxContainer.new()
	timer_row.name = "TimerRow"
	timer_row.custom_minimum_size = Vector2(0, 64)
	timer_row.add_theme_constant_override("separation", 14)
	_layout.add_child(timer_row)
	_bar_track = StyleBoxFlat.new()
	_bar_track.set_corner_radius_all(12)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.set_corner_radius_all(12)
	_bar_fill.bg_color = ScrambledTheme.timer_color(0.0)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.max_value = 100.0
	_timer_bar.value = 0.0
	_timer_bar.custom_minimum_size = Vector2(0, 24)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_bar.add_theme_stylebox_override("background", _bar_track)
	_timer_bar.add_theme_stylebox_override("fill", _bar_fill)
	timer_row.add_child(_timer_bar)
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(150, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_override("font", MenuStyle.vazir())
	_time_label.add_theme_font_size_override("font_size", 34)
	timer_row.add_child(_time_label)

	# The message band: the how-to line, then the meaning card.
	var band := Control.new()
	band.name = "MessageBand"
	band.custom_minimum_size = Vector2(0, 320)
	band.mouse_filter = Control.MOUSE_FILTER_PASS
	_layout.add_child(band)
	_instruction_label = Label.new()
	_instruction_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_instruction_label.offset_left = 30.0
	_instruction_label.offset_right = -30.0
	_instruction_label.text = INSTRUCTION_TEXT
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_override("font", MenuStyle.vazir())
	_instruction_label.add_theme_font_size_override("font_size", 36)
	band.add_child(_instruction_label)
	_hint_card = _make_hint_card()
	band.add_child(_hint_card)

	# The board, then the hint button under the thumb.
	_board = BOARD_SCENE.instantiate() as ScrambledTileBoard
	_board.custom_minimum_size = Vector2(0, 400)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.arrangement_settled.connect(_on_arrangement_settled)
	_board.tile_grabbed.connect(_on_tile_grabbed)
	_layout.add_child(_board)

	var action := HBoxContainer.new()
	action.name = "ActionRow"
	action.custom_minimum_size = Vector2(0, 146)
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(action)
	_hint_button = Button.new()
	_hint_button.text = "💡  راهنما"
	_hint_button.visible = false
	_hint_button.custom_minimum_size = Vector2(430, 118)
	_hint_button.add_theme_font_override("font", MenuStyle.vazir())
	_hint_button.add_theme_font_size_override("font_size", 40)
	_hint_button.add_theme_color_override("font_color", MenuStyle.on_accent(Color("#FFB703")))
	_hint_button.add_theme_stylebox_override("normal", _hint_button_style(false))
	_hint_button.add_theme_stylebox_override("hover", _hint_button_style(true))
	_hint_button.add_theme_stylebox_override("pressed", _hint_button_style(true))
	_hint_button.add_theme_stylebox_override("focus", _hint_button_style(false))
	_hint_button.resized.connect(func() -> void: _hint_button.pivot_offset = _hint_button.size * 0.5)
	_hint_button.pressed.connect(_on_hint_pressed)
	MenuStyle.wire_microinteractions(_hint_button)
	action.add_child(_hint_button)

	# --- ADDING REVEAL LETTER BUTTON ---
	var _reveal_button := Button.new()
	_reveal_button.text = "🔍 یک حرف"
	_reveal_button.custom_minimum_size = Vector2(200, 118)
	_reveal_button.add_theme_font_override("font", MenuStyle.vazir())
	_reveal_button.add_theme_font_size_override("font_size", 30)
	_reveal_button.add_theme_stylebox_override("normal", _filled_button_style(DesignTokens.ACCENT_BRIGHT, false))
	_reveal_button.pressed.connect(_on_reveal_letter_pressed)
	action.add_child(_reveal_button)
	# ----------------------------------


	_build_overlays()
## The meaning card: a printed cream card with a green frame, so the moment
## the hint arrives reads like a card being dealt onto the board.
func _make_hint_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "HintCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 12.0
	card.offset_right = -12.0
	card.offset_top = 8.0
	card.offset_bottom = -8.0
	card.visible = false
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(_make_card_label(HINT_CAPTION, MenuStyle.vazir(), 32,
		ScrambledTheme.CARD_ACCENT))
	_hint_english = _make_card_label("", MenuStyle.jakarta_bold(), 40, ScrambledTheme.CARD_INK)
	_hint_english.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint_english)
	_hint_persian = _make_card_label("", MenuStyle.vazir(), 32, ScrambledTheme.CARD_INK_DIM)
	_hint_persian.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint_persian)
	_hint_worth = _make_card_label("", MenuStyle.vazir(), 28, ScrambledTheme.CARD_ACCENT)
	column.add_child(_hint_worth)
	return card


func _make_card_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## The win banner, the floating points and the confetti.
func _build_overlays() -> void:
	_praise_label = Label.new()
	_praise_label.name = "PraiseLabel"
	_praise_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_praise_label.anchor_top = 0.5
	_praise_label.anchor_bottom = 0.5
	_praise_label.offset_top = -330.0
	_praise_label.offset_bottom = -190.0
	_praise_label.visible = false
	_praise_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_praise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_praise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_praise_label.add_theme_font_override("font", MenuStyle.vazir())
	_praise_label.add_theme_font_size_override("font_size", 84)
	_praise_label.add_theme_color_override("font_color", ScrambledTheme.SOLVED_COLOR)
	_praise_label.add_theme_constant_override("outline_size", 10)
	add_child(_praise_label)

	_points_label = Label.new()
	_points_label.name = "PointsLabel"
	_points_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_points_label.anchor_top = 0.5
	_points_label.anchor_bottom = 0.5
	_points_label.offset_top = -140.0
	_points_label.offset_bottom = -50.0
	_points_label.visible = false
	_points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_override("font", MenuStyle.vazir())
	_points_label.add_theme_font_size_override("font_size", 62)
	_points_label.add_theme_color_override("font_color", ScrambledTheme.NUDGE_COLOR)
	add_child(_points_label)

	_confetti = CPUParticles2D.new()
	_confetti.name = "Confetti"
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = 30
	_confetti.lifetime = 1.5
	_confetti.explosiveness = 1.0
	_confetti.randomness = 0.6
	_confetti.direction = Vector2(0, -1)
	_confetti.spread = 78.0
	_confetti.gravity = Vector2(0, 720)
	_confetti.initial_velocity_min = 240.0
	_confetti.initial_velocity_max = 620.0
	_confetti.angular_velocity_min = -300.0
	_confetti.angular_velocity_max = 300.0
	_confetti.scale_amount_min = 0.5
	_confetti.scale_amount_max = 1.1
	_confetti.texture = _make_confetti_texture()
	_confetti.color_initial_ramp = _confetti_ramp()
	_confetti.color_ramp = _confetti_fade()
	_layout.add_child(_confetti)

	_build_confirm()


## A solid little square stands in for a sprite: no image asset needed.
func _make_confetti_texture() -> Texture2D:
	var dot := 10
	var image: Image = null
	if ClassDB.class_has_method("Image", "create_empty"):
		image = Image.create_empty(dot, dot, false, Image.FORMAT_RGBA8)
	else:
		image = Image.create(dot, dot, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)


## Confetti colours are picked per particle, so the burst looks mixed...
func _confetti_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		ScrambledTheme.tile_color(0), ScrambledTheme.tile_color(1),
		ScrambledTheme.tile_color(2), ScrambledTheme.tile_color(3),
		ScrambledTheme.tile_color(7),
	])
	return ramp


## ...and they fade away as they fall.
func _confetti_fade() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
	])
	return ramp
## Leaving mid-session asks first: quitting is forgiving (the points already
## earned are saved) but it still ends the run.
func _build_confirm() -> void:
	_confirm_layer = Control.new()
	_confirm_layer.name = "ConfirmLayer"
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.visible = false
	add_child(_confirm_layer)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.07, 0.55)
	_confirm_layer.add_child(scrim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -430.0
	card.offset_right = 430.0
	card.offset_top = -270.0
	card.offset_bottom = 270.0
	card.add_theme_stylebox_override("panel",
		MenuStyle.card_style(MenuStyle.accent(), 34, true))
	_confirm_layer.add_child(card)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	card.add_child(column)
	column.add_child(_make_card_label(CONFIRM_TITLE, MenuStyle.vazir(), 46, MenuStyle.text()))
	_confirm_body = _make_card_label(CONFIRM_BODY, MenuStyle.vazir(), 32, MenuStyle.subtitle_color())
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_confirm_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)

	var stay := Button.new()
	stay.text = CONFIRM_STAY
	stay.custom_minimum_size = Vector2(320, 112)
	stay.add_theme_font_override("font", MenuStyle.vazir())
	stay.add_theme_font_size_override("font_size", 36)
	stay.pressed.connect(_close_confirm)
	MenuStyle.wire_microinteractions(stay)
	row.add_child(stay)

	var leave := Button.new()
	leave.text = CONFIRM_LEAVE
	leave.custom_minimum_size = Vector2(320, 112)
	leave.add_theme_font_override("font", MenuStyle.vazir())
	leave.add_theme_font_size_override("font_size", 36)
	leave.add_theme_color_override("font_color", MenuStyle.on_accent(Color("#FF6B6B")))
	leave.add_theme_stylebox_override("normal", _filled_button_style(Color("#FF6B6B"), false))
	leave.add_theme_stylebox_override("hover", _filled_button_style(Color("#FF6B6B"), true))
	leave.add_theme_stylebox_override("pressed", _filled_button_style(Color("#FF6B6B"), true))
	leave.pressed.connect(_leave_game)
	MenuStyle.wire_microinteractions(leave)
	row.add_child(leave)
## ------------------------------------------------------------- word flow --
func _start_word(animate: bool) -> void:
	var controller := ScrambledGameManager.controller
	if controller == null:
		_finish_session()
		return
	_solved = false
	_playing = true
	_hint_shown = false
	_hint_ready = false
	_elapsed = 0.0
	_hint_card.visible = false
	_hint_button.visible = false
	_hint_button.scale = Vector2(0.6, 0.6)
	_praise_label.visible = false
	_points_label.visible = false
	_instruction_label.visible = true
	_instruction_label.modulate.a = 1.0
	_instruction_label.text = INSTRUCTION_TEXT
	_board.set_board_locked(false)
	_board.build(controller, animate)
	_update_chips()
	_update_timer()
	if animate:
		_fade_instruction()


## The how-to line steps aside after a few seconds — and the moment the player
## starts playing, which is sooner.
func _fade_instruction() -> void:
	await get_tree().create_timer(INSTRUCTION_FADE_TIME).timeout
	if not is_instance_valid(self) or not is_inside_tree() or _closing or _hint_card.visible:
		return
	_dismiss_instruction()


func _dismiss_instruction() -> void:
	if not _instruction_label.visible or _hint_card.visible or _instruction_label.modulate.a <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(_instruction_label, "modulate:a", 0.0, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_tile_grabbed(_tile: ScrambledTile) -> void:
	_dismiss_instruction()


func _on_arrangement_settled(solved: bool) -> void:
	if _solved or _closing:
		return
	if solved:
		_on_word_solved()
		return
	Sfx.click()
	# Never punished, never given away: when the word is only one or two
	# letters away the wrong tiles pulse amber.
	var controller := ScrambledGameManager.controller
	if controller != null and controller.is_near_miss(_board.tiles_letters()):
		_board.play_near_miss_nudge()


func _on_word_solved() -> void:
	_solved = true
	_playing = false
	_board.play_solved_flourish()
	_board.set_board_locked(true)
	Sfx.correct()
	var entry := ScrambledGameManager.solve_current_word()
	_show_praise()
	if ScrambledGameManager.is_competition():
		_float_points(int(entry.get("points", 0)))
	_update_chips()
	_burst_confetti()
	_await_next_word()


func _await_next_word() -> void:
	await get_tree().create_timer(ScrambledGameManager.NEXT_WORD_DELAY).timeout
	if not is_instance_valid(self) or not is_inside_tree() or _closing:
		return
	if ScrambledGameManager.advance():
		_start_word(true)
	else:
		_finish_session()


func _finish_session() -> void:
	_playing = false
	Sfx.complete()
	session_finished.emit()


## ------------------------------------------------------------------ juice --
func _show_praise() -> void:
	_praise_label.text = PRAISE_LINES[randi() % PRAISE_LINES.size()]
	_praise_label.visible = true
	_praise_label.pivot_offset = Vector2(_praise_label.size.x * 0.5, _praise_label.size.y * 0.5)
	_praise_label.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(_praise_label, "scale", Vector2.ONE, 0.36) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_praise_label, "scale", Vector2(0.97, 0.97), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## "+۶۰" rises off the board and fades, the classic score pop.
func _float_points(points: int) -> void:
	_points_label.text = "+%s" % MenuStyle.persian_digits(str(points))
	_points_label.visible = true
	_points_label.modulate.a = 1.0
	_points_label.offset_top = -140.0
	_points_label.offset_bottom = -50.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_points_label, "offset_top", -310.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_points_label, "offset_bottom", -220.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_points_label, "modulate:a", 0.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _burst_confetti() -> void:
	_confetti.position = _board.position + Vector2(_board.size.x * 0.5, _board.size.y * 0.45)
	_confetti.emitting = true
## ---------------------------------------------------------------- the hint --
func _show_hint_button() -> void:
	_hint_ready = true
	_hint_button.visible = true
	_hint_button.pivot_offset = _hint_button.size * 0.5
	_hint_button.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_hint_button, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A couple of soft wiggles, so the eye finds the new button.
	var wiggle := create_tween().set_loops(2)
	wiggle.tween_interval(0.45)
	wiggle.tween_property(_hint_button, "rotation", 0.035, 0.16).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(_hint_button, "rotation", -0.035, 0.22).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(_hint_button, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	Sfx.reward()
	_flash_hint_ready()


## Turns the how-to line into a "the hint is ready" note for a few seconds.
func _flash_hint_ready() -> void:
	_instruction_label.text = HINT_READY_TEXT
	_instruction_label.visible = true
	_instruction_label.modulate.a = 1.0
	await get_tree().create_timer(3.2).timeout
	if not is_instance_valid(self) or not is_inside_tree() or _hint_card.visible:
		return
	_dismiss_instruction()


func _on_hint_pressed() -> void:
	if _hint_shown or _solved:
		return
	_hint_shown = true
	_hint_ready = true
	ScrambledGameManager.mark_hint_used()
	_hint_button.visible = false
	Sfx.click()

func _on_reveal_letter_pressed() -> void:
	if _hint_shown or _solved:
		return
		
	var idx := ScrambledGameManager.reveal_letter(_board.tiles_letters())
	if idx >= 0:
		_board.reveal_letter_at(idx)
		Sfx.click()

	_show_hint_card()
	_update_chips()


## The meaning card takes the place of the how-to line: the English meaning
## first (that is the hint), the Persian one underneath as a second hand.
func _show_hint_card() -> void:
	var controller := ScrambledGameManager.controller
	if controller == null:
		return
	_hint_english.text = controller.meaning if not controller.meaning.is_empty() else "—"
	_hint_persian.text = controller.meaning_fa
	_hint_persian.visible = not controller.meaning_fa.is_empty()
	if ScrambledGameManager.is_competition():
		_hint_worth.text = "با راهنما این کلمه %s امتیاز دارد" % MenuStyle.persian_digits(
			str(ScrambledGameManager.current_word_potential_points()))
		_hint_worth.visible = true
	else:
		_hint_worth.visible = false
	_instruction_label.visible = false
	_hint_card.visible = true
	_hint_card.pivot_offset = _hint_card.size * 0.5
	_hint_card.scale = Vector2(0.86, 0.86)
	_hint_card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_hint_card, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hint_card, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## ------------------------------------------------------------- the chips --
func _update_timer() -> void:
	_time_label.text = _format_time(_elapsed)
	var limit := 60.0 if ScrambledGameManager.is_competition() else ScrambledGameManager.hint_delay()
	_timer_bar.value = clampf(_elapsed / maxf(limit, 1.0) * 100.0, 0.0, 100.0)
	var color := ScrambledTheme.timer_color(_elapsed) if ScrambledGameManager.is_competition() \
		else MenuStyle.accent_bright()
	if color != _last_bar_color:
		_last_bar_color = color
		_bar_fill.bg_color = color
	# The word is worth less every second: watching that number fall is the
	# whole point of the competition.
	if ScrambledGameManager.is_competition() and not _solved:
		var worth := ScrambledGameManager.current_word_potential_points()
		if worth != _last_worth:
			_last_worth = worth
			_update_chips()


func _update_chips() -> void:
	_progress_label.text = "کلمه %s از %s" % [
		MenuStyle.persian_digits(str(ScrambledGameManager.word_position())),
		MenuStyle.persian_digits(str(ScrambledGameManager.word_count())),
	]
	_mode_label.text = ScrambledGameManager.mode_label()
	var competition := ScrambledGameManager.is_competition()
	_score_label.visible = competition
	_worth_label.visible = competition
	if not competition:
		return
	_score_label.text = "امتیاز: %s" % MenuStyle.persian_digits(str(ScrambledGameManager.total_score()))
	var worth := ScrambledGameManager.current_word_potential_points()
	if _hint_shown:
		_worth_label.text = "با راهنما: %s" % MenuStyle.persian_digits(str(worth))
	else:
		_worth_label.text = "ارزش: %s" % MenuStyle.persian_digits(str(worth))


func _format_time(seconds: float) -> String:
	var total := int(floor(seconds))
	var minutes := int(floor(float(total) / 60.0))
	return "%s:%s" % [MenuStyle.persian_digits(str(minutes)),
		MenuStyle.persian_digits("%02d" % (total % 60))]


## ---------------------------------------------------------------- styling --
func _make_chip(accent: Color, font_size: int) -> Label:
	var chip: Label = MenuStyle.pill_label("", accent, font_size)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


## A filled, chunky, candy-style button — the game's own look, not the menu's.
func _filled_button_style(color: Color, hover: bool) -> StyleBoxFlat:
	var fill := color.lightened(0.10) if hover else color
	var style := ScrambledTheme.chip_style(fill, 30, ScrambledTheme.tile_edge(color), 3)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0.06, 0.09, 0.18, 0.30 if hover else 0.22)
	style.shadow_size = 26 if hover else 18
	style.shadow_offset = Vector2(0.0, 12.0 if hover else 8.0)
	return style


func _hint_button_style(hover: bool) -> StyleBoxFlat:
	return _filled_button_style(Color("#FFB703"), hover)
