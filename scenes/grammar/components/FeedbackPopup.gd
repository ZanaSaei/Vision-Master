class_name FeedbackPopup
extends Control


signal continue_pressed


var title_label: Label
var explanation_label: Label
var continue_button: GrammarButton

var is_correct := false

var _card: PanelContainer


func _ready() -> void:

	_build_ui()

	hide()


func _build_ui() -> void:

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dim the screen behind the feedback card.
	var dim := ColorRect.new()

	dim.color = Color(
		0.04,
		0.05,
		0.08,
		0.62
	)

	dim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(dim)

	# Center the card on the whole screen.
	var center := CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(center)

	_card = PanelContainer.new()

	# Wide enough that the explanation text fits at least ~7 words per
	# line (minus the card's inner margins) instead of wrapping into a
	# tall, narrow strip.
	_card.custom_minimum_size = Vector2(
		900,
		0
	)

	GrammarTheme.style_card(
		_card
	)

	center.add_child(
		_card
	)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		26
	)

	margin.add_theme_constant_override(
		"margin_right",
		26
	)

	margin.add_theme_constant_override(
		"margin_top",
		22
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		22
	)

	_card.add_child(
		margin
	)

	var layout := VBoxContainer.new()

	layout.add_theme_constant_override(
		"separation",
		14
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
		32
	)

	title_label.add_theme_font_override(
		"font",
		GrammarTheme.get_fa_bold()
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
		GrammarTheme.BODY_SIZE
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
		6
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

	Sfx.correct()

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

	continue_button.text = "دوباره امتحان کن"

	Sfx.wrong()

	_show_popup()


func _show_popup() -> void:

	show()

	GrammarAnimation.pop(
		_card
	)


func hide_popup() -> void:

	GrammarAnimation.disappear(
		_card
	)

	await get_tree().create_timer(
		0.18
	).timeout

	hide()


func _on_continue_pressed() -> void:

	continue_pressed.emit()

	hide()
