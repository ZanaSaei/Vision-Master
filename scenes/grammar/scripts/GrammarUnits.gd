class_name GrammarUnits
extends "res://autoload/BackButtonHandler.gd"

const SCENE_MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"
const SCENE_GRAMMAR_HUB: String = "res://scenes/grammar/GrammarHub.tscn"
const SCENE_GRAMMAR_LESSON: String = "res://scenes/grammar/GrammarLesson.tscn"

var lesson_data: Dictionary = {}
var units: Array = []
var unlocked_units: int = 1
var _unit_buttons: Array[GrammarButton] = []
var _navigating: bool = false


func _ready() -> void:
	super._ready()
	_load_lesson()
	_build_ui()


func _load_lesson() -> void:
	lesson_data = GrammarData.load_lesson(Global.current_book, Global.current_lesson)
	units = lesson_data.get("units", [])
	unlocked_units = Global.get_grammar_unlocked_units(Global.current_book, Global.current_lesson, units.size())
	if unlocked_units < 1:
		unlocked_units = 1


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
	main.add_theme_constant_override("separation", 24)
	main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root_margin.add_child(main)

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

	var back_button: Button = GrammarTheme.make_header_icon_button(
		"res://ui/images/Back.png",
		Callable(self, "_on_previous_pressed")
	)
	header_row.add_child(back_button)

	var menu_button: Button = GrammarTheme.make_header_icon_button(
		"res://ui/images/Main_Menu.png",
		Callable(self, "_on_main_menu_pressed")
	)
	header_row.add_child(menu_button)

	var title_label: Label = Label.new()
	title_label.text = "بخش‌های گرامر"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font: Font = GrammarTheme.get_fa_bold()
	if title_font != null:
		title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(title_label)

	GrammarTheme.unify_header_row(header_row)

	var content_box: PanelContainer = PanelContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GrammarTheme.style_card(content_box)
	main.add_child(content_box)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_top", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_right", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", GrammarTheme.CONTENT_MARGIN)
	content_box.add_child(content_margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	content_margin.add_child(content)

	var lesson_title: Label = Label.new()
	GrammarTheme.set_bidi_text(lesson_title, str(lesson_data.get("title_fa", "")))
	if lesson_title.text.is_empty():
		lesson_title.text = str(lesson_data.get("title_en", ""))
	if lesson_title.text.is_empty():
		lesson_title.text = "Lesson %d" % Global.current_lesson
	lesson_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if title_font != null:
		lesson_title.add_theme_font_override("font", title_font)
	lesson_title.add_theme_font_size_override("font_size", 36)
	lesson_title.add_theme_color_override("font_color", GrammarTheme.text_color())
	content.add_child(lesson_title)

	var body_font: Font = GrammarTheme.get_fa_regular()

	if not units.is_empty():
		_build_mastery_banner(content)

	if units.is_empty():
		var empty_box: VBoxContainer = VBoxContainer.new()
		empty_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_box.add_theme_constant_override("separation", 16)
		content.add_child(empty_box)

		var empty_icon: Label = Label.new()
		empty_icon.text = "📭"
		empty_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_icon.add_theme_font_size_override("font_size", 72)
		empty_box.add_child(empty_icon)

		var empty_title: Label = Label.new()
		empty_title.text = "هنوز محتوایی نیست"
		empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if title_font != null:
			empty_title.add_theme_font_override("font", title_font)
		empty_title.add_theme_font_size_override("font_size", 32)
		empty_title.add_theme_color_override("font_color", GrammarTheme.text_color())
		empty_box.add_child(empty_title)

		var empty_desc: Label = Label.new()
		empty_desc.text = "محتوای گرامر برای این درس هنوز آماده نشده است."
		empty_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if body_font != null:
			empty_desc.add_theme_font_override("font", body_font)
		empty_desc.add_theme_font_size_override("font_size", 24)
		empty_desc.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
		empty_box.add_child(empty_desc)
	else:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)

		var grid_margin: MarginContainer = MarginContainer.new()
		grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_margin.add_theme_constant_override("margin_left", 36)
		grid_margin.add_theme_constant_override("margin_right", 36)
		grid_margin.add_theme_constant_override("margin_top", 24)
		grid_margin.add_theme_constant_override("margin_bottom", 36)
		scroll.add_child(grid_margin)

		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 20)
		grid_margin.add_child(grid)

		for i in range(units.size()):
			var unit: Dictionary = units[i]
			var button: GrammarButton = _make_unit_button(i, unit)
			grid.add_child(button)
			_unit_buttons.append(button)
			GrammarAnimation.appear(button, i * 0.05)


func _build_mastery_banner(parent: VBoxContainer) -> void:
	var mastery := GrammarData.get_mastery_status(Global.current_book, Global.current_lesson)
	var rank_color: Color = mastery["rank_color"]

	var banner := PanelContainer.new()
	var style := GrammarTheme.info_card_style()
	style.border_color = Color(rank_color.r, rank_color.g, rank_color.b, 0.55)
	style.set_border_width_all(2)
	banner.add_theme_stylebox_override("panel", style)
	parent.add_child(banner)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	banner.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top_row)

	var xp_badge := Label.new()
	xp_badge.text = "⭐ %d / %d XP" % [mastery["current_xp"], mastery["base_max_xp"]]
	xp_badge.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	xp_badge.add_theme_font_size_override("font_size", 28)
	xp_badge.add_theme_color_override("font_color", GrammarTheme.xp_color())
	top_row.add_child(xp_badge)

	var rank_lbl := Label.new()
	GrammarTheme.set_bidi_text(rank_lbl, "%s سطح: %s (%d/%d بخش)" % [
		mastery["rank_icon"],
		mastery["rank_title_fa"],
		mastery["completed_units"],
		mastery["total_units"]
	])
	rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_lbl.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	rank_lbl.add_theme_font_size_override("font_size", 28)
	rank_lbl.add_theme_color_override("font_color", rank_color)
	top_row.add_child(rank_lbl)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.add_theme_stylebox_override("background", GrammarTheme.rounded_box(GrammarTheme.disabled_color(), 8))
	bar.add_theme_stylebox_override("fill", GrammarTheme.rounded_box(rank_color, 8))
	bar.value = mastery["progress_ratio"] * 100.0
	vbox.add_child(bar)

	var sub_lbl := Label.new()
	if mastery["xp_to_next"] > 0:
		GrammarTheme.set_bidi_text(sub_lbl, "🎯 %d XP دیگر تا ارتقا به سطح بعدی! (پاسخ بدون اشتباه = +۵ XP پاداش)" % mastery["xp_to_next"])
	else:
		GrammarTheme.set_bidi_text(sub_lbl, "🏆 تبریک! شما به بالاترین سطح تسلط در این درس رسیده‌اید!")
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", GrammarTheme.get_fa_regular())
	sub_lbl.add_theme_font_size_override("font_size", 23)
	sub_lbl.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	vbox.add_child(sub_lbl)


func _make_unit_button(index: int, unit: Dictionary) -> GrammarButton:
	var unlocked: bool = index < unlocked_units
	var completed: bool = Global.is_unit_completed(
		Global.current_book, Global.current_lesson, index, str(unit.get("id", ""))
	)
	var xp_per_unit: int = int(lesson_data.get("xp_per_unit", 10))

	var button: GrammarButton = GrammarButton.new()
	button.no_clip = true
	button.variant = GrammarButton.ButtonVariant.SECONDARY
	button.custom_minimum_size = Vector2(0.0, 195.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", GrammarTheme.text_color())
	button.add_theme_color_override("font_hover_color", GrammarTheme.text_color())
	button.add_theme_color_override("font_pressed_color", GrammarTheme.text_color())
	button.add_theme_color_override("font_focus_color", GrammarTheme.text_color())
	button.add_theme_color_override("font_disabled_color", GrammarTheme.locked_text_color())

	var status_tag: String = "🔒 قفل"
	if completed:
		status_tag = "✅ کامل شد"
	elif unlocked:
		status_tag = "⭐ +%d XP" % xp_per_unit

	var label: String = GrammarData.unit_title(unit)
	GrammarTheme.set_bidi_text(
		button,
		"%s  |  %s\nبخش %d\n%s" % [GrammarData.unit_icon(unit), status_tag, index + 1, label]
	)

	if unlocked:
		button.pressed.connect(_on_unit_pressed.bind(index))

	button.ready.connect(func() -> void: _apply_unit_styles(button, unlocked, completed))
	return button


func _apply_unit_styles(button: GrammarButton, unlocked: bool, completed: bool) -> void:
	if completed:
		# Completed units shine with a rich emerald/gold mastery border
		var fill := GrammarTheme.success_soft_color()
		var border := GrammarTheme.success_color()
		var normal := _unit_style(fill, border, 1.0, 1.0, 3)
		normal.shadow_color = Color(border.r, border.g, border.b, 0.32)
		normal.shadow_size = 14
		normal.shadow_offset = Vector2(0, 5)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", _unit_style(fill.lightened(0.08), border, 1.0, 1.0, 3))
		button.add_theme_stylebox_override("pressed", _unit_style(fill.darkened(0.06), border, 1.0, 1.0, 3))
		button.add_theme_stylebox_override("focus", _unit_style(fill.lightened(0.08), border, 1.0, 1.0, 3))
	elif unlocked:
		# Active unlocked unit pops with accent glow
		var normal := _unit_style(GrammarTheme.primary_light_color(), GrammarTheme.primary_color(), 1.0, 1.0, 3)
		normal.shadow_color = Color(0.42, 0.47, 1.0, 0.45)
		normal.shadow_size = 18
		normal.shadow_offset = Vector2(0, 6)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", _unit_style(GrammarTheme.primary_light_color().lightened(0.09), GrammarTheme.primary_dark_color(), 1.0, 1.0, 3))
		button.add_theme_stylebox_override("pressed", _unit_style(GrammarTheme.primary_light_color().darkened(0.06), GrammarTheme.primary_color(), 1.0, 1.0, 3))
		button.add_theme_stylebox_override("focus", _unit_style(GrammarTheme.primary_light_color().lightened(0.11), GrammarTheme.primary_dark_color(), 1.0, 1.0, 3))
	else:
		button.disabled = true
		var locked_fill: Color = GrammarTheme.disabled_color().darkened(0.15)
		button.add_theme_stylebox_override("normal", _unit_style(locked_fill, GrammarTheme.locked_text_color(), 0.55, 0.18))
		button.add_theme_stylebox_override("hover", _unit_style(locked_fill, GrammarTheme.locked_text_color(), 0.55, 0.18))
		button.add_theme_stylebox_override("pressed", _unit_style(locked_fill, GrammarTheme.locked_text_color(), 0.55, 0.18))
		button.add_theme_stylebox_override("focus", _unit_style(locked_fill, GrammarTheme.locked_text_color(), 0.55, 0.18))


func _unit_style(color: Color, border_color: Color, alpha: float, border_alpha: float, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = GrammarTheme.rounded_box(
		Color(color.r, color.g, color.b, alpha),
		26,
		Color(border_color.r, border_color.g, border_color.b, border_alpha),
		border_width
	)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0.0, 5.0)
	return style


func _on_unit_pressed(index: int) -> void:
	if _navigating:
		return
	_navigating = true
	Global.set_last_scene(get_tree().current_scene.scene_file_path)
	Global.set_grammar_start_unit(index)
	TransitionManager.change_scene(SCENE_GRAMMAR_LESSON)


func _on_main_menu_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_previous_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_GRAMMAR_HUB)


func _on_android_back_pressed() -> void:
	_on_previous_pressed()
