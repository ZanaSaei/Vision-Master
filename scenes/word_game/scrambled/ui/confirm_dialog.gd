class_name ScrambledConfirmDialog
extends Control
## ============================================================
##  CONFIRM DIALOG — "از بازی خارج می‌شوی؟"
##
##  Leaving mid-session asks first. Quitting is forgiving — the points already
##  earned are written by the session manager — but it still ends the run, so
##  the player gets one deliberate question rather than a back tap that steals
##  their word.
##
##  It is laid out with containers rather than the fixed offsets the screen
##  used to compute by hand: a CenterContainer keeps the card centred at any
##  window size, and the card's own MarginContainer keeps its text off the
##  frame. Every look comes from a theme variation (`ScrambledDialogCard`,
##  `ScrambledDialog*` labels, `ScrambledDialogButton` / `ScrambledDangerButton`),
##  so nothing here needs re-applying on a theme toggle.
##
##  Nothing is written here. The dialog only reports which answer it was given.
## ============================================================

signal confirmed()
signal cancelled()

const OPEN_FADE_TIME := 0.18

@onready var _title: Label = $Center/Card/Margin/Column/Title
@onready var _body: Label = $Center/Card/Margin/Column/Body
@onready var _stay: Button = $Center/Card/Margin/Column/Choices/Stay
@onready var _leave: Button = $Center/Card/Margin/Column/Choices/Leave


func _ready() -> void:
	visible = false
	_stay.pressed.connect(_on_stay_pressed)
	_leave.pressed.connect(_on_leave_pressed)
	MenuStyle.wire_microinteractions(_stay)
	MenuStyle.wire_microinteractions(_leave)


func is_open() -> bool:
	return visible


## Asks the question. `body` differs by mode, because what is at stake does:
## a lesson loses its practice, the day keeps its points.
func open(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, OPEN_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.click()


func close() -> void:
	visible = false


func _on_stay_pressed() -> void:
	close()
	cancelled.emit()


## Leaving is the screen's to carry out: it has a session to end and a host to
## tell, so the dialog only reports the answer.
func _on_leave_pressed() -> void:
	confirmed.emit()
