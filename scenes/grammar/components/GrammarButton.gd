class_name GrammarButton
extends Button


enum ButtonVariant {
	PRIMARY,
	SECONDARY
}


@export var variant: ButtonVariant = ButtonVariant.SECONDARY
# Minimum button height. Defaults to the theme button height; compact
# chip buttons (e.g. unscramble word slots) set a smaller value.
@export var min_height: int = GrammarTheme.BUTTON_HEIGHT
@export var enable_press_animation := true
# When false, no click sound plays on press. Used for answer-choice
# buttons so the ONLY sound after answering is the feedback sound.
@export var play_click_sound := true
# When true, the hover and pressed styles are the same as the normal
# style. Used on answer-choice buttons so neither a cursor parked over
# an option nor a stuck "pressed" state (e.g. the option under the
# cursor when the continue button closes the feedback popup) makes it
# look like it was already selected/blacked-out.
@export var neutral_states := false
# When true, the button never clips or trims its text (used by compact
# word chips so no letter is ever removed). Applied in _apply_theme so
# it is not overwritten by the default clipping.
@export var no_clip := false


func _ready() -> void:

	# Enforce a minimum button height, but never clobber an explicit
	# width already set by the caller (e.g. exercise options that
	# want a shared fixed width and SHRINK_CENTER alignment).
	if custom_minimum_size.y < min_height:
		custom_minimum_size.y = min_height

	_apply_theme()

	# Keep the scale pivot at the center so press/hover animations
	# grow from the button's middle instead of its top-left corner.
	pivot_offset = size * 0.5

	Global.on_theme_changed(
		_on_theme_changed
	)

	pressed.connect(
		func() -> void:
			if play_click_sound:
				Sfx.click()
	)

	button_down.connect(
		_on_button_down
	)

	focus_entered.connect(
		_on_focus_entered
	)

	mouse_entered.connect(
		_on_mouse_entered
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _apply_theme() -> void:

	if variant == ButtonVariant.PRIMARY:

		GrammarTheme.style_primary_button(
			self
		)

	else:

		GrammarTheme.style_secondary_button(
			self
		)

	if neutral_states:
		add_theme_stylebox_override(
			"hover",
			get_theme_stylebox("normal")
		)

		add_theme_stylebox_override(
			"pressed",
			get_theme_stylebox("normal")
		)

	if no_clip:
		text_overrun_behavior = (
			TextServer.OVERRUN_NO_TRIMMING
		)

		clip_text = false
	else:
		text_overrun_behavior = (
			TextServer.OVERRUN_TRIM_ELLIPSIS
		)

		clip_text = true


func _on_theme_changed(_mode: int) -> void:

	if not is_inside_tree():
		return

	# Re-apply the base theme styling for the current mode. Transient
	# correct/wrong/selected overrides are re-applied by their callers
	# the next time they are triggered.
	_apply_theme()


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
		GrammarTheme.success_color()
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
		GrammarTheme.error_color()
	)

	GrammarAnimation.wrong(
		self
	)


func reset_state() -> void:

	_apply_theme()

	disabled = false


# Highlights a button as currently picked (used by Matching so the
# player can see which part has been chosen).
func set_selected_state() -> void:

	var style := GrammarTheme.selected_button()

	add_theme_stylebox_override(
		"normal",
		style
	)

	add_theme_stylebox_override(
		"hover",
		style
	)

	add_theme_stylebox_override(
		"pressed",
		style
	)

	add_theme_color_override(
		"font_color",
		GrammarTheme.accent_font_color()
	)

	add_theme_color_override(
		"font_hover_color",
		GrammarTheme.accent_font_color()
	)


func clear_selected_state() -> void:

	remove_theme_stylebox_override(
		"normal"
	)

	remove_theme_stylebox_override(
		"hover"
	)

	remove_theme_stylebox_override(
		"pressed"
	)

	remove_theme_color_override(
		"font_color"
	)

	remove_theme_color_override(
		"font_hover_color"
	)

	_apply_theme()
