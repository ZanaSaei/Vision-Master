class_name RewardPopup
extends Control


signal finished


var title_label: Label
var reward_label: Label
var continue_button: GrammarButton


func _ready() -> void:

	_build_ui()

	hide()


func _build_ui() -> void:

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(
		center
	)

	var card := PanelContainer.new()

	card.custom_minimum_size = Vector2(
		310,
		260
	)

	GrammarTheme.style_card(
		card
	)

	center.add_child(
		card
	)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		24
	)

	margin.add_theme_constant_override(
		"margin_right",
		24
	)

	margin.add_theme_constant_override(
		"margin_top",
		24
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		24
	)

	card.add_child(
		margin
	)

	var layout := VBoxContainer.new()

	layout.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	layout.add_theme_constant_override(
		"separation",
		12
	)

	margin.add_child(
		layout
	)

	var emoji := Label.new()

	emoji.text = "🏆"

	emoji.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	emoji.add_theme_font_size_override(
		"font_size",
		54
	)

	layout.add_child(
		emoji
	)

	title_label = Label.new()

	title_label.text = "بخش کامل شد!"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		26
	)

	layout.add_child(
		title_label
	)

	reward_label = Label.new()

	reward_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	reward_label.add_theme_color_override(
		"font_color",
		GrammarTheme.XP
	)

	reward_label.add_theme_font_size_override(
		"font_size",
		28
	)

	layout.add_child(
		reward_label
	)

	continue_button = GrammarButton.new()

	continue_button.variant = (
		GrammarButton.ButtonVariant.PRIMARY
	)

	continue_button.text = "ادامه"

	continue_button.pressed.connect(
		_on_continue
	)

	layout.add_child(
		continue_button
	)


func show_reward(
	title: String,
	xp: int
) -> void:

	title_label.text = title

	reward_label.text = "⭐ +%d XP" % xp

	show()

	GrammarAnimation.pop(
		get_child(0).get_child(0)
	)


func _on_continue() -> void:

	hide()

	finished.emit()
