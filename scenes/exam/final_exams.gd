class_name FinalExams
extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  FINAL EXAMS — امتحانات نهایی (year picker)
##
##  Entry screen reached from the main menu's card. It shows one card per grade read
##  from res://data/final_exams/manifest.json. Picking a grade pushes the exam list for that year.
## ============================================================

const SCENE_MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"
const CARD_ACCENTS: Array[Color] = [Color("#2563EB"), Color("#D97706")]

var _navigating: bool = false

@onready var _subtitle: Label = $RootMargin/MainColumn/ContentMargin/ContentScroll/Content/Subtitle
@onready var _dynamic_content: VBoxContainer = $RootMargin/MainColumn/ContentMargin/ContentScroll/Content/DynamicContent
@onready var _empty_message: Label = $RootMargin/MainColumn/ContentMargin/ContentScroll/Content/EmptyMessage


func _ready() -> void:
	super._ready()
	wire_header_bar()
	_build_ui()


func _build_ui() -> void:
	GrammarTheme.set_bidi_text(_subtitle, "پایه خود را انتخاب کنید")
	var _yellow_normal: StyleBoxFlat = load("res://ui/Styles/buttons/Yellow_Normal.tres")
	var _yellow_hovered: StyleBoxFlat = load("res://ui/Styles/buttons/Yellow_Hovered.tres")
	var _blue_normal: StyleBoxFlat = load("res://ui/Styles/buttons/Blue_Normal.tres")
	var _blue_hovered: StyleBoxFlat = load("res://ui/Styles/buttons/Blue_Hovered.tres")
	_subtitle.add_theme_font_size_override("font_size", 32)
	_subtitle.add_theme_color_override("font_color", GrammarTheme.text_muted_color())

	var years: Array = ExamData.years()
	if years.is_empty():
		_empty_message.visible = true
		return

	for i in years.size():
		var year: Dictionary = years[i]
		var accent: Color = CARD_ACCENTS[i % CARD_ACCENTS.size()]
		var exam_count: int = year.get("exams", []).size()
		var card: Button = MenuStyle.make_card(
			str(year.get("title_fa", "")),
			"%s · %d آزمون" % [str(year.get("subtitle_fa", "")), exam_count],
			"🎓",
			accent,
			190
		)
		var year_id: String = str(year.get("id", ""))
		if year_id == "11" or year_id == "12":
			card.add_theme_stylebox_override("normal", _blue_normal)
			card.add_theme_stylebox_override("pressed", _blue_normal)
			card.add_theme_stylebox_override("hover", _blue_hovered)
			var title_lbl: Label = card.get_node_or_null("Margin/Row/TextColumn/TitleLabel") as Label
			if title_lbl != null:
				title_lbl.label_settings = load("res://ui/fonts/Fa_Button_Title_Blue.tres")
			var sub_lbl: Label = card.get_node_or_null("Margin/Row/TextColumn/SubLabel") as Label
			if sub_lbl != null:
				sub_lbl.label_settings = load("res://ui/fonts/Fa_Button_Info_Blue.tres")
		else:
			card.add_theme_stylebox_override("normal", _yellow_normal)
			card.add_theme_stylebox_override("pressed", _yellow_normal)
			card.add_theme_stylebox_override("hover", _yellow_hovered)
		card.pressed.connect(func() -> void: _open_year(year_id))
		MenuStyle.wire_microinteractions(card)
		var card_inset: MarginContainer = MarginContainer.new()
		card_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_inset.add_theme_constant_override("margin_left", 14)
		card_inset.add_theme_constant_override("margin_right", 14)
		card_inset.add_theme_constant_override("margin_top", 4)
		card_inset.add_theme_constant_override("margin_bottom", 4)
		card_inset.add_child(card)
		_dynamic_content.add_child(card_inset)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	_dynamic_content.add_child(spacer)


func _open_year(year_id: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.push("final_exam_list", {"year": year_id})


func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.slide_change_scene(SCENE_MAIN_MENU, TransitionManager.Slide.BACK)
