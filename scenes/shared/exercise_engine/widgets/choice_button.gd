# ============================================================
# ExerciseEngine - ChoiceButton widget (selectable answer option).
# A reusable scene for the engine's `_make_select_button` factory.
# Static appearance comes from the ChoiceButton Theme type variation (or one
# of its accent variants); this script only applies per-instance content and
# behaviour. Keep visual styling in the Theme, not here.
# ============================================================
class_name ExerciseChoiceButton
extends Button

## Applies the per-instance content. `bidi_text` is already bidi-fixed by the
## caller so the engine's exact RTL rule is preserved, and `variation` selects
## the accent-specific Theme variation.
func setup(bidi_text: String, rtl: bool, group: ButtonGroup, variation: StringName) -> void:
	text = "   " + bidi_text
	text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
	button_group = group
	theme_type_variation = variation

## Clears the pressed state for an in-place "Try Again" reset.
func clear_selection() -> void:
	button_pressed = false