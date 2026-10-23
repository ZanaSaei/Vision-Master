# ============================================================
# ExerciseEngine - ChipButton widget (word-bank / built-sentence chips).
# Reusable scene for the engine's `_make_chip_button` factory. Styling comes
# from the ChipButton / ChipButtonFilled Theme variations.
# ============================================================
class_name ExerciseChipButton
extends Button

## Applies the per-instance content. `bidi_text` is bidi-fixed by the caller.
func setup(bidi_text: String, rtl: bool, filled: bool) -> void:
	text = bidi_text
	text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
	theme_type_variation = &"ChipButtonFilled" if filled else &"ChipButton"