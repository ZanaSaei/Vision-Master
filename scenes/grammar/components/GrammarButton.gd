class_name GrammarButton
extends Button


enum ButtonVariant {
	PRIMARY,
	SECONDARY
}


@export var variant: ButtonVariant = ButtonVariant.SECONDARY
@export var enable_press_animation := true


func _ready() -> void:

	custom_minimum_size = Vector2(
		0,
		60
	)

	_apply_theme()

	button_down.connect(
		_on_button_down
	)

	focus_entered.connect(
		_on_focus_entered
	)

	mouse_entered.connect(
		_on_mouse_entered
	)


func _apply_theme() -> void:

	if variant == ButtonVariant.PRIMARY:

		GrammarTheme.style_primary_button(
			self
		)

	else:

		GrammarTheme.style_secondary_button(
			self
		)

	text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)

	clip_text = true


func _on_button_down() -> void:

	if enable_press_animation:
		GrammarAnimation.press(
			self
		)


func _on_focus_entered() -> void:

	GrammarAnimation.small_pop(
		self
	)


func _on_mouse_entered() -> void:

	if not disabled:
		GrammarAnimation.small_pop(
			self
		)


func set_correct_state() -> void:

	disabled = true

	add_theme_stylebox_override(
		"disabled",
		GrammarTheme.success_button()
	)

	add_theme_color_override(
		"font_disabled_color",
		GrammarTheme.SUCCESS
	)

	GrammarAnimation.correct(
		self
	)


func set_wrong_state() -> void:

	add_theme_stylebox_override(
		"normal",
		GrammarTheme.error_button()
	)

	add_theme_stylebox_override(
		"hover",
		GrammarTheme.error_button()
	)

	add_theme_color_override(
		"font_color",
		GrammarTheme.ERROR
	)

	GrammarAnimation.wrong(
		self
	)


func reset_state() -> void:

	_apply_theme()

	disabled = false
