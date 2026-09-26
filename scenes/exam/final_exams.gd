class_name FinalExams
extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  FINAL EXAMS — امتحانات نهایی (year picker)
##
##  Entry screen reached from the main menu's "امتحانات نهایی"
##  card. It shows one card per grade (یازدهم / دوازدهم) read
##  from res://data/final_exams/manifest.json. Picking a grade
##  pushes the exam list for that year.
## ============================================================

const SCENE_MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"
const BACK_ICON: String = "res://images/Back.png"
const HOME_ICON: String = "res://images/Main_Menu.png"
const CARD_ACCENTS: Array[Color] = [Color("#2563EB"), Color("#D97706")]

var _navigating: bool = false


func _ready() -> void:
	super._ready()
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
	content.add_theme_constant_override("separation", 26)
	scroll.add_child(content)

	var subtitle: Label = Label.new()
	GrammarTheme.set_bidi_text(subtitle, "پایهٔ خود را انتخاب کنید")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_font: Font = GrammarTheme.get_fa_regular()
	if body_font != null:
		subtitle.add_theme_font_override("font", body_font)
	subtitle.add_theme_font_size_override("font_size", 32)
	subtitle.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	content.add_child(subtitle)

	var years: Array = ExamData.years()
	if years.is_empty():
		var empty: Label = Label.new()
		empty.text = "هنوز آزمونی اضافه نشده است."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 32)
		content.add_child(empty)
		return

	for i in years.size():
		var year: Dictionary = years[i]
		var accent: Color = CARD_ACCENTS[i % CARD_ACCENTS.size()]
		var exam_count: int = year.get("exams", []).size()
		var card: Button = MenuStyle.make_card(
			str(year.get("title_fa", "")),
			"%s · %d آزمون" % [str(year.get("subtitle_fa", "")), exam_count],
			str(year.get("emoji", "🎓")),
			accent,
			190
		)
		var year_id: String = str(year.get("id", ""))
		card.pressed.connect(func() -> void: _open_year(year_id))
		MenuStyle.wire_microinteractions(card)
		content.add_child(card)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	content.add_child(spacer)


func _build_header(main: VBoxContainer) -> void:
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
	GrammarTheme.set_bidi_text(title_label, "امتحانات نهایی")
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


func _open_year(year_id: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.push("final_exam_list", {"year": year_id})


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.slide_change_scene(SCENE_MAIN_MENU, TransitionManager.Slide.BACK)


func _on_main_menu_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_MAIN_MENU)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
