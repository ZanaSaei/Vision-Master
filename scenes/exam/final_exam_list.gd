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

const CARD_ACCENT: Color = Color("#D97706")

var _navigating: bool = false
var _year_id: String = ""

@onready var _dynamic_content: VBoxContainer = $RootMargin/MainColumn/ContentMargin/ContentScroll/Content/DynamicContent
@onready var _empty_message: Label = $RootMargin/MainColumn/ContentMargin/ContentScroll/Content/EmptyMessage

func _ready() -> void:
	super._ready()
	_year_id = str(AppRouter.get_arg("year", "12"))
	wire_header_bar(_header_title())
	_build_ui()


## The bar reads "امتحانات نهایی · <پایه>" so the chosen grade stays visible.
func _header_title() -> String:
	var year: Dictionary = ExamData.year_by_id(_year_id)
	var year_title: String = str(year.get("title_fa", "")).strip_edges()
	if year_title.is_empty():
		return "امتحانات نهایی"
	return "امتحانات نهایی · " + year_title


func _build_ui() -> void:
	var _yellow_normal: StyleBoxFlat = load("res://ui/Styles/buttons/Yellow_Normal.tres")
	var _yellow_hovered: StyleBoxFlat = load("res://ui/Styles/buttons/Yellow_Hovered.tres")
	var _blue_normal: StyleBoxFlat = load("res://ui/Styles/buttons/Blue_Normal.tres")
	var _blue_hovered: StyleBoxFlat = load("res://ui/Styles/buttons/Blue_Hovered.tres")
	var title_blue_settings: LabelSettings = load("res://ui/fonts/Fa_Button_Title_Blue.tres")
	var info_blue_settings: LabelSettings = load("res://ui/fonts/Fa_Button_Info_Blue.tres")
	var exams: Array = ExamData.exams_for_year(_year_id)
	if exams.is_empty():
		_empty_message.visible = true
		return

	for exam in exams:
		var title: String = str(exam.get("title_fa", ""))
		var date_fa: String = str(exam.get("date_fa", ""))
		var exam_json: String = str(exam.get("json", ""))
		var card: Button = MenuStyle.make_card(title, "تاریخ آزمون · " + date_fa, "📄", CARD_ACCENT, 168)
		if _year_id == "11" or _year_id == "12":
			card.add_theme_stylebox_override("normal", _blue_normal)
			card.add_theme_stylebox_override("pressed", _blue_normal)
			card.add_theme_stylebox_override("hover", _blue_hovered)
			var title_lbl: Label = card.get_node_or_null("Margin/Row/TextColumn/TitleLabel") as Label
			if title_lbl != null:
				title_lbl.label_settings = title_blue_settings
			var sub_lbl: Label = card.get_node_or_null("Margin/Row/TextColumn/SubLabel") as Label
			if sub_lbl != null:
				sub_lbl.label_settings = info_blue_settings
		else:
			card.add_theme_stylebox_override("normal", _yellow_normal)
			card.add_theme_stylebox_override("pressed", _yellow_normal)
			card.add_theme_stylebox_override("hover", _yellow_hovered)
		card.pressed.connect(func() -> void: _open_exam(exam_json, title))
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


func _open_exam(exam_json: String, title: String) -> void:
	if _navigating:
		return
	_navigating = true
	Sfx.click()
	AppRouter.push("final_exam", {"exam_json": exam_json, "title_fa": title})


func _on_android_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	AppRouter.back("final_exams")
