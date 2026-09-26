class_name FinalExamList
extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  FINAL EXAM LIST — فهرست امتحانات یک پایه
##
##  Shows the exams of one grade (passed via AppRouter arg
##  "year", e.g. "12") as a chronological list of cards, read
##  from res://data/final_exams/manifest.json. Picking an exam
##  pushes the exam runner with the exam's JSON path.
## ============================================================

const BACK_ICON: String = "res://images/Back.png"
const HOME_ICON: String = "res://images/Main_Menu.png"
const CARD_ACCENT: Color = Color("#D97706")

var _navigating: bool = false
var _year_id: String = ""


func _ready() -> void:
	super._ready()
	MenuBackground.enter_background()
	_year_id = str(AppRouter.get_arg("year", "12"))
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
	root_margin.add_child(main)

	_build_header(main)

	var content_box: PanelContainer = PanelContainer.new()
	GrammarTheme.style_card(content_box)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_box)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_top", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_right", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", GrammarTheme.CONTENT_MARGIN)
	content_box.add_child(content_margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	scroll.add_child(content)

	var exams: Array = ExamData.exams_for_year(_year_id)
	if exams.is_empty():
		var empty: Label = Label.new()
		empty.text = "برای این پایه هنوز امتحانی اضافه نشده است."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 32)
		content.add_child(empty)
		return

	for exam in exams:
		var title: String = str(exam.get("title_fa", ""))
		var date_fa: String = str(exam.get("date_fa", ""))
		var exam_json: String = str(exam.get("json", ""))
		var card: Button = MenuStyle.make_card(title, "تاریخ آزمون · " + date_fa, "📄", CARD_ACCENT, 168)
		card.pressed.connect(func() -> void: _open_exam(exam_json, title))
		MenuStyle.wire_microinteractions(card)
		content.add_child(card)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	content.add_child(spacer)


func _build_header(main: VBoxContainer) -> void:
	var year: Dictionary = ExamData.year_by_id(_year_id)

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

	var back_button: Button = GrammarTheme.make_header_icon_button(BACK_ICON, Callable(self, "_on_back_pressed"))
	header_row.add_child(back_button)

	var home_button: Button = GrammarTheme.make_header_icon_button(HOME_ICON, Callable(self, "_on_main_menu_pressed"))
	header_row.add_child(home_button)

	var title_label: Label = Label.new()
	var year_title: String = str(year.get("title_fa", "امتحانات نهایی"))
	GrammarTheme.set_bidi_text(title_label, "امتحانات " + year_title)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font: Font = GrammarTheme.get_fa_bold()
	if title_font != null:
		title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	header_row.add_child(title_label)

	GrammarTheme.unify_header_row(header_row)


func _open_exam(exam_json: String, title: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.push("final_exam", {"exam_json": exam_json, "title_fa": title})


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	AppRouter.back("final_exams")


func _on_main_menu_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene("res://scenes/main_menu/MainMenu.tscn")


func _on_android_back_pressed() -> void:
	_on_back_pressed()