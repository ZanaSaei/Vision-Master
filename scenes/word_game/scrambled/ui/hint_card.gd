class_name ScrambledHintCard
extends PanelContainer
## ============================================================
##  HINT CARD — the meaning of the word, dealt like a printed card.
##
##  The English meaning is the hint (that is what a spelling game may give
##  away); the Persian meaning sits underneath as a second hand, and in the
##  day's competition a line says what the word is now worth.
##
##  Its whole look — the cream paper, the green frame, and the four label
##  voices on it — is declared in the theme as `ScrambledHintCard` and the
##  `ScrambledHint*` label variations, so this script owns only the meaning it
##  shows and the animation that deals it in. The card is deliberately painted
##  from fixed colours rather than the palette: it must read the same in both
##  themes, like a card dealt onto the board.
##
##  The entrance lives here with the thing it animates (per the project's UI
##  rules) — it is the one moment on this screen that should feel like
##  something being dealt.
## ============================================================

## The card lands slightly small and opens out, TRANS_BACK.
const ENTER_FROM := 0.86
const ENTER_TIME := 0.34
const ENTER_FADE_TIME := 0.22

@onready var _meaning: Label = $Column/Meaning
@onready var _persian: Label = $Column/Persian
@onready var _worth: Label = $Column/Worth


func _ready() -> void:
	visible = false
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func is_shown() -> bool:
	return visible


## Deals the card in: the meaning first, the Persian one under it, and — in the
## competition — a line about what reading it costs.
func show_hint(meaning: String, meaning_fa: String, worth_text: String) -> void:
	_meaning.text = meaning if not meaning.is_empty() else "—"
	_persian.text = meaning_fa
	_persian.visible = not meaning_fa.is_empty()
	_worth.text = worth_text
	_worth.visible = not worth_text.is_empty()

	pivot_offset = size * 0.5
	scale = Vector2(ENTER_FROM, ENTER_FROM)
	modulate.a = 0.0
	visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, ENTER_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, ENTER_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Takes the card away with no animation: used when a new word is dealt, where
## the board is already moving and a second animation would fight it.
func hide_hint() -> void:
	visible = false
	scale = Vector2.ONE
	modulate.a = 1.0
