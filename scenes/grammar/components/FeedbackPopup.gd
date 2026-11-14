class_name FeedbackPopup
extends Control
# ============================================================
#  FEEDBACK POPUP — Modern Non-Blocking Bottom Sheet
# ============================================================
#  Slides up gracefully from the bottom of the screen upon answering,
#  leaving the question and answer choices visible above it so the
#  learner can review their answer in context.
# ============================================================

signal continue_pressed
signal skip_pressed

var title_label: Label
var explanation_label: Label
var continue_button: GrammarButton
var skip_button: GrammarButton
var is_correct := false

var _dim: ColorRect
var _sheet: PanelContainer
var _sheet_height: float = 380.0
var _tween: Tween


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	hide()


func _exit_tree() -> void:
	if is_instance_valid(Global) and Global.theme_changed.is_connected(_on_theme_changed):
		Global.theme_changed.disconnect(_on_theme_changed)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Gentle translucent scrim so the exercise above remains completely legible
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.05, 0.28)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# Bottom Sheet Container anchored to the bottom edge of the screen
	_sheet = PanelContainer.new()
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 0
	_sheet.offset_right = 0
	_sheet.offset_top = -_sheet_height
	_sheet.offset_bottom = 0
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 36)
	_sheet.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	# Top Header Row: Icon + Title
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 10)
	layout.add_child(header_row)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	header_row.add_child(title_label)

	# Explanation Label
	explanation_label = Label.new()
	explanation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SIZE)
	explanation_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	explanation_label.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	layout.add_child(explanation_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	# Action Buttons Row
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 14)
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(button_row)

	skip_button = GrammarButton.new()
	skip_button.variant = GrammarButton.ButtonVariant.SECONDARY
	skip_button.text = "رد شدن  ➜"
	skip_button.min_height = 104
	skip_button.font_size = 36
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_pressed)
	button_row.add_child(skip_button)

	continue_button = GrammarButton.new()
	continue_button.variant = GrammarButton.ButtonVariant.PRIMARY
	continue_button.text = "ادامه  ➜"
	continue_button.min_height = 104
	continue_button.font_size = 42
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)


func show_correct(explanation: String) -> void:
	is_correct = true
	skip_button.visible = false

	# Success visual theme
	title_label.text = "✨ فوق‌العاده بود!"
	title_label.add_theme_color_override("font_color", GrammarTheme.success_color())

	var style := GrammarTheme.bottom_sheet_style(GrammarTheme.success_color())
	style.bg_color = Global.get_theme_color("surface")
	_sheet.add_theme_stylebox_override("panel", style)

	var explanation_text := explanation.strip_edges()
	if explanation_text.is_empty():
		explanation_text = "آفرین! پاسخ شما کاملاً درست است."
	GrammarTheme.set_bidi_text(explanation_label, explanation_text)

	continue_button.text = "ادامه  ➜"
	_style_success_button(continue_button)

	Sfx.correct()
	_slide_in()


func show_wrong(explanation: String) -> void:
	is_correct = false
	skip_button.visible = false

	# Warning / Retry visual theme
	title_label.text = "💡 نیاز به دقت بیشتر"
	title_label.add_theme_color_override("font_color", GrammarTheme.warning_color())

	var style := GrammarTheme.bottom_sheet_style(GrammarTheme.warning_color())
	style.bg_color = Global.get_theme_color("surface")
	_sheet.add_theme_stylebox_override("panel", style)

	var explanation_text := explanation.strip_edges()
	if explanation_text.is_empty():
		explanation_text = "اشکالی نداره، دوباره امتحان کن!\nمی‌تونی از چراغ راهنما هم کمک بگیری."
	GrammarTheme.set_bidi_text(explanation_label, explanation_text)

	continue_button.text = "دوباره امتحان کن  ↺"
	_style_retry_button(continue_button)

	Sfx.wrong()
	_slide_in()


func show_skip_button() -> void:
	skip_button.visible = true


func _style_success_button(btn: GrammarButton) -> void:
	var success_style := GrammarTheme.rounded_box(GrammarTheme.success_color(), 20)
	var hover_style := GrammarTheme.rounded_box(GrammarTheme.success_color().lightened(0.12), 20)
	btn.add_theme_stylebox_override("normal", success_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _style_retry_button(btn: GrammarButton) -> void:
	var warn_color: Color = GrammarTheme.accent_color()
	var warn_style := GrammarTheme.rounded_box(warn_color, 20)
	var hover_style := GrammarTheme.rounded_box(warn_color.lightened(0.12), 20)
	btn.add_theme_stylebox_override("normal", warn_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _slide_in() -> void:
	show()
	_dim.modulate.a = 0.0

	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Start off-screen below the bottom edge
	_sheet.offset_top = 0.0
	_sheet.offset_bottom = _sheet_height

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.parallel().tween_property(_dim, "modulate:a", 1.0, 0.22)
	_tween.parallel().tween_property(_sheet, "offset_top", -_sheet_height, 0.28)
	_tween.parallel().tween_property(_sheet, "offset_bottom", 0.0, 0.28)


func hide_popup() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_IN)

	_tween.parallel().tween_property(_dim, "modulate:a", 0.0, 0.16)
	_tween.parallel().tween_property(_sheet, "offset_top", 0.0, 0.18)
	_tween.parallel().tween_property(_sheet, "offset_bottom", _sheet_height, 0.18)
	await _tween.finished
	hide()


func _on_continue_pressed() -> void:
	await hide_popup()
	continue_pressed.emit()


func _on_skip_pressed() -> void:
	await hide_popup()
	skip_pressed.emit()


func _apply_theme() -> void:
	if _sheet != null:
		_sheet.add_theme_stylebox_override("panel", GrammarTheme.bottom_sheet_style())
	if explanation_label != null:
		explanation_label.add_theme_color_override("font_color", GrammarTheme.text_color())


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()
