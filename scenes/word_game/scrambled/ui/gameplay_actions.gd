class_name ScrambledGameplayActions
extends HBoxContainer
## ============================================================
##  GAMEPLAY ACTIONS — the two ways out of a word that will not come.
##
##  «راهنما» costs points and hands over the meaning; «یک حرف» puts one letter
##  of the answer into its slot. Both are only ever ASKED for: the buttons
##  announce the request and the screen decides whether it may be granted — a
##  component never reaches into the session (per the project's UI rules).
##
##  The buttons wear the game's `Scrambled*Button` theme variations, so their
##  candy look lives with the rest of the game's styling and this script owns
##  only the gesture. It has no apply_theme() for the same reason.
##
##  The hint button does not exist until the word has been going long enough.
##  Arriving on its own is the whole point of that delay, so the entrance is
##  animated here, with the button it belongs to.
## ============================================================

signal hint_requested()
signal reveal_requested()

## The hint button arrives from this scale, opening out with TRANS_BACK.
const HINT_ARRIVE_FROM := 0.6
const HINT_ARRIVE_TIME := 0.4
## A couple of soft wiggles, so the eye finds the button that just appeared.
const WIGGLE_GAP := 0.45
const WIGGLE_ANGLE := 0.035

@onready var _hint: Button = $Hint
@onready var _reveal: Button = $Reveal


func _ready() -> void:
	_hint.pressed.connect(func() -> void: hint_requested.emit())
	_reveal.pressed.connect(func() -> void: reveal_requested.emit())
	# Both are buttons: the same hover-lift / press-squash the rest of the app
	# wears. (The scale is a micro-interaction, not a look, so it stays code.)
	MenuStyle.wire_microinteractions(_hint)
	MenuStyle.wire_microinteractions(_reveal)


## The word has been going long enough: the hint button arrives on its own.
func reveal_hint() -> void:
	_hint.pivot_offset = _hint.size * 0.5
	_hint.scale = Vector2(HINT_ARRIVE_FROM, HINT_ARRIVE_FROM)
	_hint.visible = true
	var tw := create_tween()
	tw.tween_property(_hint, "scale", Vector2.ONE, HINT_ARRIVE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wiggle := create_tween().set_loops(2)
	wiggle.tween_interval(WIGGLE_GAP)
	wiggle.tween_property(_hint, "rotation", WIGGLE_ANGLE, 0.16).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(_hint, "rotation", -WIGGLE_ANGLE, 0.22).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(_hint, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	Sfx.reward()


## The hint has been taken: the button has done its job and steps aside.
func hide_hint() -> void:
	_hint.visible = false
	_hint.scale = Vector2(HINT_ARRIVE_FROM, HINT_ARRIVE_FROM)
	_hint.rotation = 0.0
