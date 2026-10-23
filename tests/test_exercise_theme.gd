extends Node
# ============================================================
# Phase B tests: the ExerciseEngine widgets get their appearance from Theme
# TYPE VARIATIONS on the app-wide Light theme, not from inline StyleBoxFlat
# construction in the factories.
# ============================================================

const VARIATIONS := {
	"ChoiceButton": "Button",
	"ChoiceButtonSuccess": "Button",
	"ChoiceButtonError": "Button",
	"ChoiceButtonWarning": "Button",
	"ChoiceButtonInfo": "Button",
	"ChoiceButtonPurple": "Button",
	"ImageChoiceButton": "Button",
	"ChipButton": "Button",
	"ChipButtonFilled": "Button",
	"WordToggle": "Button",
	"WordToggleCompact": "Button",
	"OrderArrow": "Button",
	"AnswerLineEdit": "LineEdit",
	"ChartInput": "LineEdit",
	"FeedbackLabel": "Label",
	"OrderCard": "PanelContainer",
	"OrderChip": "PanelContainer",
	"OrderHandle": "PanelContainer",
}

func _new_engine(exercise: Dictionary) -> ExerciseEngine:
	var e := ExerciseEngine.new()
	add_child(e)
	e.build(exercise)
	return e

func _collect(root: Node, predicate: Callable, out: Array) -> Array:
	if predicate.call(root):
		out.append(root)
	for c in root.get_children():
		_collect(c, predicate, out)
	return out


func test_variations_registered_on_base_theme() -> void:
	var t: Theme = Global.get_base_theme()
	assert(t != null, "base theme must load")
	for name in VARIATIONS:
		var base := String(t.get_type_variation_base(name))
		assert(base == str(VARIATIONS[name]),
			"variation %s must be registered as %s, got '%s'" % [name, VARIATIONS[name], base])
	assert(t.get_type_variation_base("ChoiceButton") == "Button", "ChoiceButton is a Button, not an OptionButton")


func test_choice_button_uses_theme_style() -> void:
	var ex := {
		"type": "multiple_choice",
		"exercise_id": "t_theme_mc",
		"items": [{"question": "Pick", "options": ["a", "b"], "answer": 0}],
	}
	var e := _new_engine(ex)
	var btns := _collect(e, func(n: Node) -> bool: return n is Button and (n as Button).toggle_mode, [])
	assert(btns.size() == 2, "expected two option buttons")
	var b: Button = btns[0]
	assert(String(b.theme_type_variation) == "ChoiceButton", "select button uses the ChoiceButton variation")
	var sb := b.get_theme_stylebox("normal")
	assert(sb is StyleBoxFlat, "ChoiceButton normal stylebox resolves through the theme")
	var f := sb as StyleBoxFlat
	assert(f.corner_radius_top_left == 16, "ChoiceButton corner radius comes from the theme")
	assert(f.bg_color.is_equal_approx(Global.get_theme_color("surface")), "ChoiceButton body is the theme surface")
	assert(b.get_theme_font_size("font_size") == 40, "ChoiceButton font size comes from the theme")


func test_answer_line_edit_uses_theme_style() -> void:
	var ex := {
		"type": "fill_blank",
		"exercise_id": "t_theme_fb",
		"items": [{"text": "I ___ home.", "answer": ["go"]}],
	}
	var e := _new_engine(ex)
	var edits := _collect(e, func(n: Node) -> bool: return n is LineEdit, [])
	assert(edits.size() == 1, "expected one LineEdit")
	var le: LineEdit = edits[0]
	assert(String(le.theme_type_variation) == "AnswerLineEdit", "answer input uses the AnswerLineEdit variation")
	assert(le.get_theme_stylebox("normal") is StyleBoxFlat, "AnswerLineEdit normal stylebox resolves")
	var ex_accent: Color = preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_PRIMARY
	assert(le.get_theme_color("caret_color").is_equal_approx(ex_accent), "caret uses the exercise accent")


func test_feedback_label_uses_theme_font() -> void:
	var ex := {
		"type": "multiple_choice",
		"exercise_id": "t_theme_fb2",
		"items": [{"question": "Pick", "options": ["a"], "answer": 0}],
	}
	var e := _new_engine(ex)
	var fb: Label = e._items[0]["feedback"]
	assert(String(fb.theme_type_variation) == "FeedbackLabel", "feedback uses the FeedbackLabel variation")
	assert(fb.get_theme_font_size("font_size") == 36, "FeedbackLabel font size comes from the theme")


func test_ordering_widgets_use_theme_variations() -> void:
	var ex := {
		"type": "ordering",
		"exercise_id": "t_theme_ord",
		"items": [{"text": "First"}, {"text": "Second"}],
		"answer_order": [0, 1],
	}
	var e := _new_engine(ex)
	var cards := _collect(e, func(n: Node) -> bool: return n is PanelContainer and String((n as Control).theme_type_variation) == "OrderCard", [])
	assert(cards.size() == 2, "expected two OrderCard panels")
	var arrows := _collect(e, func(n: Node) -> bool: return n is Button and String((n as Control).theme_type_variation) == "OrderArrow", [])
	assert(arrows.size() == 4, "expected four OrderArrow buttons")
	assert((arrows[0] as Button).get_theme_stylebox("normal") is StyleBoxFlat, "OrderArrow normal stylebox resolves")