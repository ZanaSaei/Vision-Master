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
	# Use the shared animated background (MenuBackground autoload) exactly
	# like the book menu and lesson menu do.
	MenuBackground.enter_background()
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
	root_margin.add_child(main)

	var header_box: PanelContainer = PanelContainer.new()
	GrammarTheme.style_header_box(header_box)
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

	var menu_button: Button = _make_header_button("🏠 منوی اصلی", Callable(self, "_on_main_menu_pressed"))
	header_row.add_child(menu_button)

	var title_label: Label = Label.new()
	title_label.text = "بخش‌های گرامر"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font: Font = GrammarTheme.get_fa_bold()
	if title_font != null:
		title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", GrammarTheme.TEXT)
	header_row.add_child(title_label)

	var back_button: Button = _make_header_button("↩ قبلی", Callable(self, "_on_previous_pressed"))
	header_row.add_child(back_button)

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
	lesson_title.text = str(lesson_data.get("title_fa", ""))
	if lesson_title.text.is_empty():
		lesson_title.text = str(lesson_data.get("title_en", ""))
	if lesson_title.text.is_empty():
		lesson_title.text = "Lesson %d" % Global.current_lesson
	lesson_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if title_font != null:
		lesson_title.add_theme_font_override("font", title_font)
	lesson_title.add_theme_font_size_override("font_size", 30)
	lesson_title.add_theme_color_override("font_color", GrammarTheme.TEXT)
	content.add_child(lesson_title)

	var body_font: Font = GrammarTheme.get_fa_regular()

	if not units.is_empty():
		var xp_label: Label = Label.new()
		xp_label.text = "⭐ %d XP" % Global.get_grammar_xp(Global.current_book, Global.current_lesson)
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if body_font != null:
			xp_label.add_theme_font_override("font", body_font)
		xp_label.add_theme_font_size_override("font_size", 26)
		xp_label.add_theme_color_override("font_color", GrammarTheme.XP)
		content.add_child(xp_label)

		var hint: Label = Label.new()
		hint.text = "فقط بخش‌های بازشده قابل انتخاب هستند."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if body_font != null:
			hint.add_theme_font_override("font", body_font)
		hint.add_theme_font_size_override("font_size", 24)
		hint.add_theme_color_override("font_color", GrammarTheme.TEXT_MUTED)
		content.add_child(hint)

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
		empty_title.add_theme_color_override("font_color", GrammarTheme.TEXT)
		empty_box.add_child(empty_title)

		var empty_desc: Label = Label.new()
		empty_desc.text = "محتوای گرامر برای این درس هنوز آماده نشده است.\nفقط برای کتاب ۱ درس ۱ در دسترس است."
		empty_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if body_font != null:
			empty_desc.add_theme_font_override("font", body_font)
		empty_desc.add_theme_font_size_override("font_size", 24)
		empty_desc.add_theme_color_override("font_color", GrammarTheme.TEXT_MUTED)
		empty_box.add_child(empty_desc)
	else:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(scroll)

		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 18)
		scroll.add_child(grid)

		for i in range(units.size()):
			var unit: Dictionary = units[i]
			var button: GrammarButton = _make_unit_button(i, unit)
			grid.add_child(button)
			_unit_buttons.append(button)


func _make_header_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140.0, 64.0)
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GrammarTheme.style_secondary_button(button)
	var font: Font = GrammarTheme.get_fa_bold()
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	return button


func _make_unit_button(index: int, unit: Dictionary) -> GrammarButton:
	var unlocked: bool = index < unlocked_units
	var completed: bool = index < unlocked_units - 1
	var button: GrammarButton = GrammarButton.new()
	button.no_clip = true
	button.variant = GrammarButton.ButtonVariant.SECONDARY
	button.custom_minimum_size = Vector2(0.0, 180.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", GrammarTheme.TEXT)
	button.add_theme_color_override("font_hover_color", GrammarTheme.TEXT)
	button.add_theme_color_override("font_pressed_color", GrammarTheme.TEXT)
	button.add_theme_color_override("font_focus_color", GrammarTheme.TEXT)
	button.add_theme_color_override("font_disabled_color", GrammarTheme.TEXT_MUTED)

	var status: String = "🔒"
	if completed:
		status = "✅"
	elif unlocked:
		status = "▶"

	var label: String = GrammarData.unit_title(unit)
	button.text = "%s %s\nبخش %d\n%s" % [status, GrammarData.unit_icon(unit), index + 1, label]

	if unlocked:
		button.pressed.connect(_on_unit_pressed.bind(index))

	# Apply the per-status styleboxes on the `ready` signal so they are not
	# clobbered by GrammarButton._apply_theme() (which runs during _ready).
	button.ready.connect(func() -> void: _apply_unit_styles(button, unlocked))

	return button


func _apply_unit_styles(button: GrammarButton, unlocked: bool) -> void:
	if unlocked:
		button.add_theme_stylebox_override("normal", _unit_style(GrammarTheme.PRIMARY_LIGHT, GrammarTheme.PRIMARY, 0.92, 0.22))
		button.add_theme_stylebox_override("hover", _unit_style(GrammarTheme.PRIMARY_LIGHT.lightened(0.06), GrammarTheme.PRIMARY_DARK, 1.0, 0.28))
		button.add_theme_stylebox_override("pressed", _unit_style(GrammarTheme.PRIMARY_LIGHT.darkened(0.06), GrammarTheme.PRIMARY, 0.84, 0.16))
		button.add_theme_stylebox_override("focus", _unit_style(GrammarTheme.PRIMARY_LIGHT.lightened(0.08), GrammarTheme.PRIMARY_DARK, 1.0, 0.28))
	else:
		button.disabled = true
		button.add_theme_stylebox_override("normal", _unit_style(GrammarTheme.DISABLED, GrammarTheme.TEXT_MUTED, 0.88, 0.14))
		button.add_theme_stylebox_override("hover", _unit_style(GrammarTheme.DISABLED, GrammarTheme.TEXT_MUTED, 0.88, 0.14))
		button.add_theme_stylebox_override("pressed", _unit_style(GrammarTheme.DISABLED, GrammarTheme.TEXT_MUTED, 0.88, 0.14))
		button.add_theme_stylebox_override("focus", _unit_style(GrammarTheme.DISABLED, GrammarTheme.TEXT_MUTED, 0.88, 0.14))


func _unit_style(color: Color, border_color: Color, alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = GrammarTheme.rounded_box(Color(color.r, color.g, color.b, alpha), 26, Color(border_color.r, border_color.g, border_color.b, border_alpha), 2)
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
