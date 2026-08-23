class_name RewardPopup
extends Control


signal next_requested
signal back_requested


var title_label: Label
var reward_label: Label
var next_button: GrammarButton
var back_button: GrammarButton


func _ready() -> void:
	_build_ui()
	hide()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dim the screen behind the reward card.
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.08, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	GrammarTheme.style_card(card)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var emoji := Label.new()
	emoji.text = "🏆"
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.add_theme_font_size_override("font_size", 54)
	layout.add_child(emoji)

	title_label = Label.new()
	title_label.text = "بخش کامل شد!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	title_label.add_theme_font_size_override("font_size", 30)
	layout.add_child(title_label)

	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", GrammarTheme.XP)
	reward_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(reward_label)

	# Spacer before the buttons.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	layout.add_child(spacer)

	next_button = GrammarButton.new()
	next_button.variant = GrammarButton.ButtonVariant.PRIMARY
	next_button.text = "ادامه"
	next_button.custom_minimum_size = Vector2(0, GrammarTheme.BUTTON_HEIGHT)
	next_button.pressed.connect(_on_next)
	layout.add_child(next_button)

	back_button = GrammarButton.new()
	back_button.variant = GrammarButton.ButtonVariant.SECONDARY
	back_button.text = "بازگشت به بخش‌ها"
	back_button.custom_minimum_size = Vector2(0, GrammarTheme.BUTTON_HEIGHT)
	back_button.pressed.connect(_on_back)
	back_button.visible = false
	layout.add_child(back_button)


func show_reward(title: String, awarded_xp: int, next_text: String = "ادامه", show_back: bool = false) -> void:
	title_label.text = title
	reward_label.text = "⭐ +%d XP" % awarded_xp
	next_button.text = next_text
	back_button.visible = show_back
	Sfx.reward()
	show()
	GrammarAnimation.pop(get_child(1).get_child(0))


func _on_next() -> void:
	hide()
	next_requested.emit()


func _on_back() -> void:
	hide()
	back_requested.emit()
