class_name FeedbackPopup
extends PanelContainer


signal continue_pressed


var title_label: Label
var explanation_label: Label
var continue_button: GrammarButton

var is_correct := false


func _ready() -> void:

	_build_ui()

	hide()


func _build_ui() -> void:

	GrammarTheme.style_card(
		self
	)

	custom_minimum_size = Vector2(
		0,
		190
	)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		20
	)

	margin.add_theme_constant_override(
		"margin_right",
		20
	)

	margin.add_theme_constant_override(
		"margin_top",
		16
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		16
	)

	add_child(
		margin
	)

	var layout := VBoxContainer.new()

	layout.add_theme_constant_override(
		"separation",
		8
	)

	margin.add_child(
		layout
	)

	title_label = Label.new()

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		25
	)

	layout.add_child(
		title_label
	)

	explanation_label = Label.new()

	explanation_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	explanation_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	explanation_label.add_theme_font_size_override(
		"font_size",
		17
	)

	explanation_label.add_theme_color_override(
		"font_color",
		GrammarTheme.TEXT_SECONDARY
	)

	layout.add_child(
		explanation_label
	)

	var spacer := Control.new()

	spacer.custom_minimum_size = Vector2(
		0,
		4
	)

	layout.add_child(
		spacer
	)

	continue_button = GrammarButton.new()

	continue_button.variant = (
		GrammarButton.ButtonVariant.PRIMARY
	)

	continue_button.text = "ادامه"

	continue_button.pressed.connect(
		_on_continue_pressed
	)

	layout.add_child(
		continue_button
	)


func show_correct(
	explanation: String
) -> void:

	is_correct = true

	title_label.text = "🎉 عالی بود!"

	title_label.add_theme_color_override(
		"font_color",
		GrammarTheme.SUCCESS
	)

	explanation_label.text = explanation

	continue_button.text = "ادامه"

	_show_popup()


func show_wrong(
	explanation: String
) -> void:

	is_correct = false

	title_label.text = "🌱 نزدیک بود!"

	title_label.add_theme_color_override(
		"font_color",
		GrammarTheme.ERROR
	)

	explanation_label.text = explanation

	continue_button.text = "دوباره ادامه می‌دیم"

	_show_popup()


func _show_popup() -> void:

	show()

	GrammarAnimation.pop(
		self
	)


func hide_popup() -> void:

	GrammarAnimation.disappear(
		self
	)

	await get_tree().create_timer(
		0.18
	).timeout

	hide()


func _on_continue_pressed() -> void:

	continue_pressed.emit()

	hide()
