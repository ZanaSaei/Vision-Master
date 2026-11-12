class_name FinalExamList
extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  FINAL EXAM LIST — فهرست امتحانات یک پایه
##
##  Shows the exams of one grade (passed via AppRouter arg
##  "year", e.g. "12") as a chronological list of glossy cards
##  read from res://data/final_exams/manifest.json. Picking an
##  exam pushes the exam runner with the exam's JSON path.
## ============================================================

const GlossSheenScript := preload("res://ui/widgets/gloss_sheen.gd")

const COLOR_BLUE := Color("#2F6FD8")
const COLOR_BLUE_BRIGHT := Color("#4C8DF6")
const COLOR_BLUE_DEEP := Color("#22539F")
const COLOR_GOLD := Color("#A87C24")
const COLOR_INK := Color("#2F2C26")
const COLOR_DIM := Color("#6E6A61")

var _navigating: bool = false
var _year_id: String = ""
var _button_tweens: Dictionary = {}

@onready var _main_col: VBoxContainer = $RootScroll/OuterMargin/MainColumn
@onready var _count_label: Label = $RootScroll/OuterMargin/MainColumn/GradeSummaryCard/Margin/Row/CountPill/CountLabel
@onready var _grade_title: Label = $RootScroll/OuterMargin/MainColumn/GradeSummaryCard/Margin/Row/TextCol/GradeTitle
@onready var _grade_sub: Label = $RootScroll/OuterMargin/MainColumn/GradeSummaryCard/Margin/Row/TextCol/GradeSub
@onready var _grade_emoji: Label = $RootScroll/OuterMargin/MainColumn/GradeSummaryCard/Margin/Row/GradeChip/Emoji
@onready var _empty_card: PanelContainer = $RootScroll/OuterMargin/MainColumn/EmptyCard
@onready var _dynamic_content: VBoxContainer = $RootScroll/OuterMargin/MainColumn/DynamicContent


func _ready() -> void:
	super._ready()
	_year_id = str(AppRouter.get_arg("year", "12"))
	wire_header_bar(_header_title())
	_build_ui()
	_play_intro_animation()


func _exit_tree() -> void:
	for key: int in _button_tweens:
		var tw: Tween = _button_tweens[key] as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	_button_tweens.clear()


## The bar reads "امتحانات نهایی · <پایه>" so the chosen grade stays visible.
func _header_title() -> String:
	var year: Dictionary = ExamData.year_by_id(_year_id)
	var year_title: String = str(year.get("title_fa", "")).strip_edges()
	if year_title.is_empty():
		return "امتحانات نهایی"
	return "امتحانات نهایی · " + year_title


func _build_ui() -> void:
	var year: Dictionary = ExamData.year_by_id(_year_id)
	var year_title: String = str(year.get("title_fa", "")).strip_edges()
	var year_sub: String = str(year.get("subtitle_fa", "")).strip_edges()
	var year_emoji: String = str(year.get("emoji", "🎓"))

	if not year_title.is_empty():
		_grade_title.text = "آزمون‌های پایهٔ " + year_title
	if not year_sub.is_empty():
		_grade_sub.text = year_sub + " · مرتب‌شده از جدیدترین"
	_grade_emoji.text = year_emoji

	var exams: Array = ExamData.exams_for_year(_year_id)
	_count_label.text = "%s آزمون" % MenuStyle.persian_digits(str(exams.size()))

	if exams.is_empty():
		_empty_card.visible = true
		return

	_empty_card.visible = false
	for i: int in range(exams.size()):
		var raw: Variant = exams[i]
		if not raw is Dictionary:
			continue
		var exam: Dictionary = raw
		var title: String = str(exam.get("title_fa", ""))
		var exam_json: String = str(exam.get("json", ""))
		var is_latest: bool = (i == 0)
		var accent: Color = COLOR_BLUE if is_latest else COLOR_GOLD
		var card: Button = _build_exam_card(exam, accent, is_latest)
		card.pressed.connect(_open_exam.bind(exam_json, title))
		_wire_spring(card)
		_dynamic_content.add_child(card)


func _build_exam_card(exam: Dictionary, accent: Color, is_latest: bool) -> Button:
	var exam_id: String = str(exam.get("id", "exam"))
	var title_fa: String = str(exam.get("title_fa", ""))
	var date_fa: String = str(exam.get("date_fa", ""))

	var btn := Button.new()
	btn.name = "ExamCard_%s" % exam_id
	btn.custom_minimum_size = Vector2(0, 206 if is_latest else 178)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "شروع آزمون %s" % title_fa

	var radius: int = 28 if is_latest else 24
	if is_latest:
		btn.add_theme_stylebox_override("normal", _hero_style("normal"))
		btn.add_theme_stylebox_override("hover", _hero_style("hover"))
		btn.add_theme_stylebox_override("pressed", _hero_style("pressed"))
		btn.add_theme_stylebox_override("focus", _hero_style("hover"))
	else:
		btn.add_theme_stylebox_override("normal", _surface_card_style(accent, "normal", radius))
		btn.add_theme_stylebox_override("hover", _surface_card_style(accent, "hover", radius))
		btn.add_theme_stylebox_override("pressed", _surface_card_style(accent, "pressed", radius))
		btn.add_theme_stylebox_override("focus", _surface_card_style(accent, "hover", radius))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# Forward chevron on left (RTL forward flow)
	var chevron := Label.new()
	chevron.text = "❮"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.add_theme_font_size_override("font_size", 46)
	chevron.add_theme_color_override("font_color", Color(1, 1, 1, 0.88) if is_latest else Color(accent.r, accent.g, accent.b, 0.92))
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(chevron)

	# Middle text column (right-aligned)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_theme_constant_override("separation", 6)
	row.add_child(text_col)

	var tag_row := HBoxContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.alignment = BoxContainer.ALIGNMENT_END
	text_col.add_child(tag_row)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _badge_style(accent, is_latest))
	tag_row.add_child(badge)

	var badge_lbl := Label.new()
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_lbl.text = "جدیدترین آزمون ✨" if is_latest else "۴۰ نمره · شنیداری 🎧"
	badge_lbl.add_theme_font_override("font", MenuStyle.font(MenuStyle.FONT_VAZIR_BOLD))
	badge_lbl.add_theme_font_size_override("font_size", 22)
	badge_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.96) if is_latest else accent)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_lbl)

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = title_fa
	title_lbl.add_theme_font_override("font", MenuStyle.vazir_bold())
	title_lbl.add_theme_font_size_override("font_size", 40 if is_latest else 36)
	title_lbl.add_theme_color_override("font_color", Color.WHITE if is_latest else COLOR_INK)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.text = "تاریخ برگزاری · %s" % MenuStyle.persian_digits(date_fa)
	sub_lbl.add_theme_font_override("font", MenuStyle.vazir())
	sub_lbl.add_theme_font_size_override("font_size", 25)
	sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.90) if is_latest else COLOR_DIM)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(sub_lbl)

	# Icon chip on right
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(114, 114) if is_latest else Vector2(102, 102)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _icon_chip_style(accent, is_latest))
	row.add_child(chip)

	var emoji_lbl := Label.new()
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_lbl.text = "📝" if is_latest else "📄"
	emoji_lbl.add_theme_font_size_override("font_size", 52 if is_latest else 46)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(emoji_lbl)

	GlossSheenScript.attach(btn, accent, float(radius))
	return btn


func _hero_style(state: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(28)
	s.set_border_width_all(2)
	match state:
		"hover":
			s.bg_color = Color("#3D7FEA")
			s.border_color = Color("#7DB8FF")
			s.shadow_color = Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.44)
			s.shadow_size = 28
			s.shadow_offset = Vector2(0, 12)
		"pressed":
			s.bg_color = COLOR_BLUE_DEEP
			s.border_color = COLOR_BLUE_BRIGHT
			s.shadow_color = Color(COLOR_BLUE_DEEP.r, COLOR_BLUE_DEEP.g, COLOR_BLUE_DEEP.b, 0.30)
			s.shadow_size = 10
			s.shadow_offset = Vector2(0, 4)
		_:
			s.bg_color = COLOR_BLUE
			s.border_color = Color("#5C9EFA")
			s.shadow_color = Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.32)
			s.shadow_size = 22
			s.shadow_offset = Vector2(0, 10)
	return s


func _surface_card_style(accent: Color, state: String, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(radius)
	match state:
		"hover":
			s.bg_color = Color("#FFFEF9")
			s.set_border_width_all(2)
			s.border_color = Color(accent.r, accent.g, accent.b, 0.45)
			s.shadow_color = Color(accent.r, accent.g, accent.b, 0.16)
			s.shadow_size = 22
			s.shadow_offset = Vector2(0, 8)
		"pressed":
			s.bg_color = Color("#F5F1E8")
			s.set_border_width_all(1)
			s.border_color = Color(accent.r, accent.g, accent.b, 0.52)
			s.shadow_color = Color(0, 0, 0, 0.05)
			s.shadow_size = 6
			s.shadow_offset = Vector2(0, 2)
		_:
			s.bg_color = Color.WHITE
			s.set_border_width_all(1)
			s.border_color = Color(0.235, 0.196, 0.118, 0.12)
			s.shadow_color = Color(0, 0, 0, 0.07)
			s.shadow_size = 16
			s.shadow_offset = Vector2(0, 6)
	return s


func _badge_style(accent: Color, is_latest: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(999)
	s.set_border_width_all(1)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	if is_latest:
		s.bg_color = Color(1, 1, 1, 0.18)
		s.border_color = Color(1, 1, 1, 0.30)
	else:
		s.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
		s.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	return s


func _icon_chip_style(accent: Color, is_latest: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(24 if is_latest else 20)
	s.set_border_width_all(2 if is_latest else 1)
	if is_latest:
		s.bg_color = Color(1, 1, 1, 0.20)
		s.border_color = Color(1, 1, 1, 0.36)
	else:
		s.bg_color = Color(accent.r, accent.g, accent.b, 0.13)
		s.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	return s


############################################################
# MOTION POLISH
############################################################
func _wire_spring(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(_on_btn_resized.bind(btn))
	btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))
	btn.button_down.connect(_animate_btn_scale.bind(btn, Vector2(0.96, 0.96), 0.07, Tween.TRANS_QUAD))
	btn.button_up.connect(_on_btn_released.bind(btn))


func _on_btn_resized(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0


func _on_btn_hover(btn: Button, entered: bool) -> void:
	if btn.disabled or btn.button_pressed:
		return
	var target: Vector2 = Vector2(1.02, 1.02) if entered else Vector2.ONE
	var duration: float = 0.16 if entered else 0.20
	_animate_btn_scale(btn, target, duration, Tween.TRANS_BACK)


func _on_btn_released(btn: Button) -> void:
	var target: Vector2 = Vector2(1.02, 1.02) if btn.is_hovered() and not btn.disabled else Vector2.ONE
	_animate_btn_scale(btn, target, 0.20, Tween.TRANS_BACK)


func _animate_btn_scale(btn: Button, target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	var key: int = btn.get_instance_id()
	var prev: Tween = _button_tweens.get(key) as Tween
	if prev != null and prev.is_valid():
		prev.kill()
	var tw: Tween = btn.create_tween()
	tw.set_trans(trans)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", target, duration)
	_button_tweens[key] = tw


func _play_intro_animation() -> void:
	var targets: Array[Control] = []
	for child: Node in _main_col.get_children():
		if child == _dynamic_content:
			for card: Node in _dynamic_content.get_children():
				if card is Control and card.visible and not card.is_queued_for_deletion():
					targets.append(card as Control)
		elif child is Control and child.visible and not child.is_queued_for_deletion():
			targets.append(child as Control)

	for ctrl: Control in targets:
		ctrl.modulate.a = 0.0
		ctrl.pivot_offset = ctrl.size / 2.0
		ctrl.scale = Vector2(0.96, 0.96)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for i: int in range(targets.size()):
		var target: Control = targets[i]
		target.pivot_offset = target.size / 2.0
		var delay: float = 0.04 * float(i)
		tw.tween_property(target, "modulate:a", 1.0, 0.26).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(target, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


############################################################
# NAVIGATION
############################################################
func _open_exam(exam_json: String, title: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	AppRouter.push("final_exam", {"exam_json": exam_json, "title_fa": title})


func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.back("final_exams")
