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
	# Use the shared animated background (MenuBackground autoload) exactly
	# like the book menu and lesson menu do.
	MenuBackground.enter_background()
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
	main.add_theme_constant_override("separation", 24)
	main.alignment = BoxContainer.ALIGNMENT_CENTER
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

	var back_button: Button = GrammarTheme.make_header_icon_button("res://assets/images/ui/Back.png", Callable(self, "_on_back_pressed"))
	header_row.add_child(back_button)

	var home_button: Button = GrammarTheme.make_header_icon_button("res://assets/images/ui/Main_Menu.png", Callable(self, "_on_main_menu_pressed"))
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

	# Same item grid as every other header in the app.
	GrammarTheme.unify_header_row(header_row)

	var content_box: PanelContainer = PanelContainer.new()
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

	var subtitle: Label = Label.new()
	subtitle.text = "کدام بخش را می‌خواهید باز کنید؟"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle_font: Font = GrammarTheme.get_fa_regular()
	if subtitle_font != null:
		subtitle.add_theme_font_override("font", subtitle_font)
	subtitle.add_theme_font_size_override("font_size", 36)
	subtitle.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(subtitle)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 18)
	content.add_child(button_row)

	var learning_button: GrammarButton = _make_feature_button(
		"🧠\nیادگیری گرامر",
		Color("#7C3AED"),
		56,
		Callable(self, "_on_learning_pressed")
	)
	button_row.add_child(learning_button)

	var data_dir := "res://data/grammar/"
	# Only surface the workbook / exam buttons when their per-book/lesson JSON
	# files exist, so a lesson that has no exam or workbook content does not
	# show a button that just opens an "هنوز چیزی نیست" dead end.
	var workbook_path := "%sv%d_l%d_book_exercises.json" % [data_dir, Global.current_book, Global.current_lesson]
	var exam_path := "%sv%d_l%d_grammar_exam.json" % [data_dir, Global.current_book, Global.current_lesson]

	if FileAccess.file_exists(workbook_path):
		var workbook_button: GrammarButton = _make_feature_button(
			"📘\nتمرینات کتاب",
			Color("#0EA5A4"),
			56,
			Callable(self, "_on_workbook_pressed")
		)
		button_row.add_child(workbook_button)

	if FileAccess.file_exists(exam_path):
		var exam_button: GrammarButton = _make_full_button(
			"🎓\nامتحان گرامر",
			Color("#D97706"),
			52,
			Callable(self, "_on_exam_pressed")
		)
		content.add_child(exam_button)


func _make_header_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	GrammarTheme.set_bidi_text(button, text)
	button.custom_minimum_size = Vector2(160.0, 64.0)
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GrammarTheme.style_secondary_button(button)
	var font: Font = GrammarTheme.get_fa_bold()
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	return button


func _make_feature_button(text: String, accent: Color, font_size: int, callback: Callable) -> GrammarButton:
	var button: GrammarButton = GrammarButton.new()
	button.variant = GrammarButton.ButtonVariant.PRIMARY
	button.no_clip = true
	GrammarTheme.set_bidi_text(button, text)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0.0, 260.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.enable_press_animation = true
	button.play_click_sound = true
	button.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#D1D5DB"))
	# Apply accent styleboxes on `ready` so GrammarButton._apply_theme()
	# (which runs during _ready) cannot overwrite them.
	button.ready.connect(func() -> void: _apply_feature_styles(button, accent))
	button.pressed.connect(callback)
	return button


func _make_full_button(text: String, accent: Color, font_size: int, callback: Callable) -> GrammarButton:
	# A single full-width, horizontally-filled big button (used below the
	# two-column feature row, e.g. the "امتحان گرامر" entry).
	var button: GrammarButton = GrammarButton.new()
	button.variant = GrammarButton.ButtonVariant.PRIMARY
	button.no_clip = true
	GrammarTheme.set_bidi_text(button, text)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0.0, 150.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.enable_press_animation = true
	button.play_click_sound = true
	button.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#D1D5DB"))
	# Apply accent styleboxes on `ready` so GrammarButton._apply_theme()
	# (which runs during _ready) cannot overwrite them.
	button.ready.connect(func() -> void: _apply_feature_styles(button, accent))
	button.pressed.connect(callback)
	return button


func _apply_feature_styles(button: GrammarButton, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _feature_style(accent, 0.94, 0.18))
	button.add_theme_stylebox_override("hover", _feature_style(accent.lightened(0.10), 1.0, 0.24))
	button.add_theme_stylebox_override("pressed", _feature_style(accent.darkened(0.10), 0.88, 0.12))
	button.add_theme_stylebox_override("focus", _feature_style(accent.lightened(0.12), 1.0, 0.22))


func _feature_style(color: Color, alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = GrammarTheme.rounded_box(Color(color.r, color.g, color.b, alpha), 30, Color(color.r, color.g, color.b, border_alpha), 2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


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
	# Match the lesson-menu -> book-menu "back" transition (slide BACK).
	TransitionManager.slide_change_scene(SCENE_LESSON_MENU, TransitionManager.Slide.BACK)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
