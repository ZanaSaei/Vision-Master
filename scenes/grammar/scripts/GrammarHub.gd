class_name GrammarHub
extends "res://autoload/BackButtonHandler.gd"

const SCENE_LESSON_MENU: String = "res://scenes/lesson_menu/LessonMenu.tscn"
const SCENE_UNITS: String = "res://scenes/grammar/GrammarUnits.tscn"
const SCENE_WORKBOOK: String = "res://scenes/workbook/Workbook.tscn"
const SCENE_BOOK_EXERCISES: String = "res://scenes/grammar/GrammarBookExercises.tscn"
const SCENE_GRAMMAR_EXAM: String = "res://scenes/grammar/GrammarExam.tscn"
const SCENE_MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"

var _navigating: bool = false


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	root_margin.add_theme_constant_override("margin_left", GrammarTheme.SAFE_MARGIN)
	root_margin.add_theme_constant_override("margin_top", GrammarTheme.SAFE_MARGIN)
	root_margin.add_theme_constant_override("margin_right", GrammarTheme.SAFE_MARGIN)
	root_margin.add_theme_constant_override("margin_bottom", GrammarTheme.SAFE_MARGIN)
	add_child(root_margin)

	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 18)
	root_margin.add_child(main)

	# --- Header Bar ---
	var header_box: PanelContainer = PanelContainer.new()
	header_box.add_theme_stylebox_override("panel", GrammarTheme.rounded_box(Color.WHITE, 35, Color.TRANSPARENT, 0))
	main.add_child(header_box)

	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 18)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_right", 18)
	header_margin.add_theme_constant_override("margin_bottom", 14)
	header_box.add_child(header_margin)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 16)
	header_margin.add_child(header_row)

	var back_button: Button = GrammarTheme.make_header_icon_button("res://ui/images/Back.png", Callable(self, "_on_back_pressed"))
	header_row.add_child(back_button)

	var home_button: Button = GrammarTheme.make_header_icon_button("res://ui/images/Main_Menu.png", Callable(self, "_on_main_menu_pressed"))
	header_row.add_child(home_button)

	var title_label: Label = Label.new()
	title_label.text = "یادگیری گرامر"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font: Font = GrammarTheme.get_fa_bold()
	if title_font != null:
		title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(title_label)

	GrammarTheme.unify_header_row(header_row)

	# --- Content ---
	var content_box: PanelContainer = PanelContainer.new()
	content_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_box)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_right", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", GrammarTheme.CONTENT_MARGIN)
	content_box.add_child(content_margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	content_margin.add_child(content)

	# XP & Mastery Overview Card
	_build_hub_mastery_card(content)

	var subtitle: Label = Label.new()
	subtitle.text = "✨ کدام بخش را می‌خواهید باز کنید؟"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle_font: Font = GrammarTheme.get_fa_bold()
	if subtitle_font != null:
		subtitle.add_theme_font_override("font", subtitle_font)
	subtitle.add_theme_font_size_override("font_size", 34)
	subtitle.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(subtitle)

	# 3 Large Cards filling the remaining screen
	var buttons_column: VBoxContainer = VBoxContainer.new()
	buttons_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons_column.add_theme_constant_override("separation", 18)
	content.add_child(buttons_column)

	var mastery := GrammarData.get_mastery_status(Global.current_book, Global.current_lesson)
	var completed_u: int = int(mastery.get("completed_units", 0))
	var total_u: int = int(mastery.get("total_units", 0))
	var unit_pct: int = int(round((float(completed_u) / float(max(total_u, 1))) * 100.0))

	var unit_badge := "📊 %s از %s بخش - ٪%s" % [
		_to_fa_digits(completed_u),
		_to_fa_digits(total_u),
		_to_fa_digits(unit_pct)
	]

	# ROW 1: Grammar Learning Units
	var learning_card := _make_row_card(
		"🧠",
		"درسنامه و آموزش گرامر",
		unit_badge,
		"📖 آموزش گام‌به‌گام فرمول‌ها، نکات کلیدی و مثال‌های ترجمه‌شده",
		"🎯 مرحله اول: یادگیری قواعد  -  ⚡ هر بخش ۱۰ امتیاز",
		Color("#7C3AED"),
		Callable(self, "_on_learning_pressed")
	)
	buttons_column.add_child(learning_card)
	GrammarAnimation.appear(learning_card, 0.05)

	var data_dir := "res://data/grammar/"
	var workbook_path := "%sv%d_l%d_book_exercises.json" % [data_dir, Global.current_book, Global.current_lesson]
	var exam_path := "%sv%d_l%d_grammar_exam.json" % [data_dir, Global.current_book, Global.current_lesson]

	# ROW 2: Book Exercises
	if FileAccess.file_exists(workbook_path):
		var wb_count: int = _count_json_questions(workbook_path)
		var wb_badge: String = "✏️ %s تمرین" % _to_fa_digits(wb_count) if wb_count > 0 else "✏️ تمرین‌های کتاب"
		var workbook_card := _make_row_card(
			"📘",
			"تمرینات کتاب درسی",
			wb_badge,
			"✍️ حل تمام تمرین‌های گرامر کتاب با بررسی هوشمند پاسخ‌ها",
			"🔥 مرحله دوم: تثبیت مطالب  -  💡 همراه با راهنمای آموزشی",
			Color("#0EA5A4"),
			Callable(self, "_on_workbook_pressed")
		)
		buttons_column.add_child(workbook_card)
		GrammarAnimation.appear(workbook_card, 0.12)

	# ROW 3: Grammar Exam
	if FileAccess.file_exists(exam_path):
		var exam_count: int = _count_json_questions(exam_path)
		var exam_meta: String = "⏱️ %s سؤال امتحانی  -  🏅 سنجش تسلط" % _to_fa_digits(exam_count) if exam_count > 0 else "⏱️ سؤالات استاندارد  -  🏅 سنجش تسلط"
		var exam_card := _make_row_card(
			"🎓",
			"آزمون جامع گرامر",
			"🏆 ۳۰ امتیاز",
			"✅ شبیه‌ساز سؤالات امتحان نهایی و سنجش کامل یادگیری درس",
			exam_meta,
			Color("#D97706"),
			Callable(self, "_on_exam_pressed")
		)
		buttons_column.add_child(exam_card)
		GrammarAnimation.appear(exam_card, 0.18)


func _build_hub_mastery_card(parent: VBoxContainer) -> void:
	var mastery := GrammarData.get_mastery_status(Global.current_book, Global.current_lesson)
	var rank_color: Color = mastery["rank_color"]

	var card := PanelContainer.new()
	var style := GrammarTheme.card_style()
	style.border_color = Color(rank_color.r, rank_color.g, rank_color.b, 0.6)
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	GrammarAnimation.appear(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var row := HBoxContainer.new()
	vbox.add_child(row)

	var xp_lbl := Label.new()
	xp_lbl.text = "⭐ %d XP" % mastery["current_xp"]
	xp_lbl.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	xp_lbl.add_theme_font_size_override("font_size", 30)
	xp_lbl.add_theme_color_override("font_color", GrammarTheme.xp_color())
	row.add_child(xp_lbl)

	var rank_lbl := Label.new()
	GrammarTheme.set_bidi_text(rank_lbl, "%s رتبه درس: %s" % [mastery["rank_icon"], mastery["rank_title_fa"]])
	rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_lbl.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	rank_lbl.add_theme_font_size_override("font_size", 28)
	rank_lbl.add_theme_color_override("font_color", rank_color)
	row.add_child(rank_lbl)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", GrammarTheme.rounded_box(GrammarTheme.disabled_color(), 8))
	bar.add_theme_stylebox_override("fill", GrammarTheme.rounded_box(rank_color, 8))
	bar.value = mastery["progress_ratio"] * 100.0
	vbox.add_child(bar)


func _make_row_card(
	emoji: String,
	title_text: String,
	badge_text: String,
	desc_text: String,
	footer_text: String,
	accent: Color,
	callback: Callable
) -> PanelContainer:
	# Outer PanelContainer handles the clean rounded border and card background
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 220.0)

	var normal_box := _build_card_stylebox(accent, 0.96, 0.25)
	var hover_box := _build_card_stylebox(accent.lightened(0.08), 1.0, 0.35)
	var pressed_box := _build_card_stylebox(accent.darkened(0.10), 0.90, 0.15)
	card.add_theme_stylebox_override("panel", normal_box)

	var bold_font: Font = GrammarTheme.get_fa_bold()
	var reg_font: Font = GrammarTheme.get_fa_regular()

	# Inner margin for content padding
	var inner_margin := MarginContainer.new()
	inner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_margin.add_theme_constant_override("margin_left", 28)
	inner_margin.add_theme_constant_override("margin_right", 28)
	inner_margin.add_theme_constant_override("margin_top", 18)
	inner_margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(inner_margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 10)
	inner_margin.add_child(card_vbox)

	# 1. Top Row: Badge Pill (Left) + Big Title & Emoji (Right)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	card_vbox.add_child(top_row)

	var badge_panel := PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_panel.add_theme_stylebox_override(
		"panel",
		GrammarTheme.rounded_box(Color(1.0, 1.0, 1.0, 0.22), 22, Color(1.0, 1.0, 1.0, 0.45), 1)
	)
	top_row.add_child(badge_panel)

	var badge_margin := MarginContainer.new()
	badge_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_margin.add_theme_constant_override("margin_left", 16)
	badge_margin.add_theme_constant_override("margin_right", 16)
	badge_margin.add_theme_constant_override("margin_top", 6)
	badge_margin.add_theme_constant_override("margin_bottom", 6)
	badge_panel.add_child(badge_margin)

	var badge_lbl := Label.new()
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GrammarTheme.set_bidi_text(badge_lbl, badge_text)
	if bold_font != null:
		badge_lbl.add_theme_font_override("font", bold_font)
	badge_lbl.add_theme_font_size_override("font_size", 30)
	badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	badge_margin.add_child(badge_lbl)

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GrammarTheme.set_bidi_text(title_lbl, "%s %s" % [title_text, emoji])
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold_font != null:
		title_lbl.add_theme_font_override("font", bold_font)
	title_lbl.add_theme_font_size_override("font_size", 46)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	top_row.add_child(title_lbl)

	# 2. Middle Row: Detailed Description
	var desc_lbl := Label.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GrammarTheme.set_bidi_text(desc_lbl, desc_text)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if reg_font != null:
		desc_lbl.add_theme_font_override("font", reg_font)
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	card_vbox.add_child(desc_lbl)

	# 3. Third Row: Meta Details & Steps
	var footer_lbl := Label.new()
	footer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GrammarTheme.set_bidi_text(footer_lbl, footer_text)
	footer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold_font != null:
		footer_lbl.add_theme_font_override("font", bold_font)
	footer_lbl.add_theme_font_size_override("font_size", 26)
	footer_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	card_vbox.add_child(footer_lbl)

	# Subtle divider line
	var divider := ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(1.0, 1.0, 1.0, 0.22)
	card_vbox.add_child(divider)

	# 4. Bottom Row: Big Centered Glossy "ورود 👈" Pill Box
	var cta_center_row := HBoxContainer.new()
	cta_center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_center_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cta_center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_child(cta_center_row)

	var glossy_cta_panel := PanelContainer.new()
	glossy_cta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glossy_cta_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glossy_cta_panel.add_theme_stylebox_override("panel", _make_glossy_stylebox())
	cta_center_row.add_child(glossy_cta_panel)

	var cta_margin := MarginContainer.new()
	cta_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_margin.add_theme_constant_override("margin_left", 36)
	cta_margin.add_theme_constant_override("margin_right", 36)
	cta_margin.add_theme_constant_override("margin_top", 10)
	cta_margin.add_theme_constant_override("margin_bottom", 10)
	glossy_cta_panel.add_child(cta_margin)

	var cta_lbl := Label.new()
	cta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GrammarTheme.set_bidi_text(cta_lbl, "ورود")
	cta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold_font != null:
		cta_lbl.add_theme_font_override("font", bold_font)
	cta_lbl.add_theme_font_size_override("font_size", 38)
	cta_lbl.add_theme_color_override("font_color", Color.WHITE)
	cta_margin.add_child(cta_lbl)

	# Invisible overlay button handling clicks and hover/pressed states cleanly
	var hit_button := Button.new()
	hit_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_button.flat = true
	hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var empty_style := StyleBoxEmpty.new()
	hit_button.add_theme_stylebox_override("normal", empty_style)
	hit_button.add_theme_stylebox_override("hover", empty_style)
	hit_button.add_theme_stylebox_override("pressed", empty_style)
	hit_button.add_theme_stylebox_override("focus", empty_style)
	hit_button.add_theme_stylebox_override("disabled", empty_style)

	hit_button.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover_box))
	hit_button.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal_box))
	hit_button.button_down.connect(func(): card.add_theme_stylebox_override("panel", pressed_box))
	hit_button.button_up.connect(func(): card.add_theme_stylebox_override("panel", hover_box if hit_button.is_hovered() else normal_box))
	hit_button.pressed.connect(callback)
	card.add_child(hit_button)

	return card


func _make_glossy_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Translucent glassy body
	style.bg_color = Color(1.0, 1.0, 1.0, 0.28)
	# Full pill rounding
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	# Glass rim highlights: brighter top edge for glossy reflection
	style.border_width_left = 2
	style.border_width_top = 3
	style.border_width_right = 2
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.65)
	# Soft ambient shadow underneath the pill
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style

func _build_card_stylebox(color: Color, alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_left = 32
	style.corner_radius_bottom_right = 32
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 1.0, 1.0, border_alpha)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _to_fa_digits(value: int) -> String:
	var s := str(value)
	var fa_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for i in range(s.length()):
		var code := s.unicode_at(i) - 48
		if code >= 0 and code <= 9:
			out += fa_digits[code]
		else:
			out += s[i]
	return out


func _count_json_questions(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed.size()
	if parsed is Dictionary:
		for key in ["questions", "exercises", "items", "tasks", "units"]:
			if parsed.has(key) and parsed[key] is Array:
				return parsed[key].size()
	return 0


func _on_learning_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Global.set_last_scene(get_tree().current_scene.scene_file_path)
	TransitionManager.change_scene(SCENE_UNITS)


func _on_workbook_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Global.set_last_scene(get_tree().current_scene.scene_file_path)
	TransitionManager.change_scene(SCENE_BOOK_EXERCISES)


func _on_exam_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Global.set_last_scene(get_tree().current_scene.scene_file_path)
	TransitionManager.change_scene(SCENE_GRAMMAR_EXAM)


func _on_main_menu_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.slide_change_scene(SCENE_LESSON_MENU, TransitionManager.Slide.BACK)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
