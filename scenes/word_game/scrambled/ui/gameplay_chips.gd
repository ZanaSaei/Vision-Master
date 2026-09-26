class_name ScrambledGameplayChips
extends HBoxContainer
## ============================================================
##  GAMEPLAY CHIPS — where the run stands, in four pills.
##
##  Which word of the day is in play, which mode is being played, what the
##  current word is still worth, and the points banked so far. It is a
##  component scene of its own (per the project's UI rules) because it is the
##  one part of the screen the board never has to know about: the screen hands
##  it the numbers and it decides the words.
##
##  Each pill wears a `ScrambledChip*` THEME VARIATION, so its look lives with
##  the rest of the game's styling in ScrambledTheme.build_theme() — this
##  component owns only what the chips SAY, never how they look. That is also
##  why it has no apply_theme(): a theme swap repaints it like every other
##  themed node.
##
##  A practice lesson keeps its score chips hidden — a lesson awards nothing,
##  so an «امتیاز» pill there would be a promise the game does not keep.
## ============================================================

@onready var _progress: Label = $Progress
@onready var _mode: Label = $Mode
@onready var _worth: Label = $Worth
@onready var _score: Label = $Score


## "کلمه ۳ از ۵" — a practice lesson reads the very same line, which is why the
## wording is not decided here.
func set_progress(current_index: int, total: int) -> void:
	_progress.text = "کلمه %s از %s" % [
		MenuStyle.persian_digits(str(current_index)),
		MenuStyle.persian_digits(str(total)),
	]


func set_mode(text: String) -> void:
	_mode.text = text


func set_points(points: int) -> void:
	_score.text = "امتیاز: %s" % MenuStyle.persian_digits(str(points))


## `hinted` changes the caption rather than the number: the same word is worth
## less once its meaning has been read, and saying so is the point.
func set_worth(worth: int, hinted: bool) -> void:
	_worth.text = "%s %s" % [
		"با راهنما:" if hinted else "ارزش:",
		MenuStyle.persian_digits(str(worth)),
	]


## The two score chips belong to the day's competition only.
func set_competition(on: bool) -> void:
	_score.visible = on
	_worth.visible = on
