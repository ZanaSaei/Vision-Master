class_name ScrambledGameplayTimer
extends HBoxContainer
## ============================================================
##  GAMEPLAY TIMER — the word's clock, as a bar and a readout.
##
##  The bar fills towards a limit the SCREEN chooses, because the two modes
##  count towards different things: a lesson counts towards its hint, the day's
##  competition towards the slowest score band. The colour arrives the same way
##  — the bar only draws what it is told.
##
##  Its SHAPE is the theme's (`ScrambledTimerBar`); only its COLOUR is the
##  clock's own reading, because the colour IS the information: green while the
##  word is worth the top band, amber and red as the bands fall away. So the
##  theme's fill is copied once — corners and all — and the copy is what gets
##  recoloured, which is the smallest override that can express a live reading.
##  The readout needs nothing at all: the app's default label font and colour
##  are already right.
## ============================================================

@onready var _bar: ProgressBar = $Bar
@onready var _time: Label = $Time

## A copy of the theme's fill, kept so the clock can repaint it in place.
var _fill: StyleBoxFlat = null
## Last colour handed to the fill, so an unchanged colour is not rewritten on
## every frame of the timer.
var _last_color := Color(0, 0, 0, 0)


func _ready() -> void:
	# The bar's SHAPE is the theme's (`ScrambledTimerBar`) and only its COLOUR
	# is the clock's own reading, because the colour IS the information. So the
	# theme's fill is copied once — corners and all — and the copy is what gets
	# recoloured, which is the smallest override that can express a live reading.
	#
	# Nothing re-reads the shape on a theme toggle: the shape is the same in
	# both themes, and re-registering the override from inside the notification
	# it fires would recurse forever. The track behind the fill is theme-drawn
	# with no override at all, so it does follow the toggle.
	_fill = (get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("fill", _fill)


## Fills towards `limit` and paints the fill `color`. Called every frame, so it
## writes nothing that has not changed.
func set_elapsed(elapsed: float, limit: float, color: Color) -> void:
	_bar.value = clampf(elapsed / maxf(limit, 1.0) * 100.0, 0.0, 100.0)
	_time.text = format_clock(elapsed)
	if color == _last_color:
		return
	_last_color = color
	if _fill != null:
		_fill.bg_color = color


## «۱:۰۵» — Persian digits, minutes:seconds. Public because a session's average
## time is read out with the same shape.
static func format_clock(seconds: float) -> String:
	var total := int(floor(seconds))
	return "%s:%s" % [
		MenuStyle.persian_digits(str(int(floor(float(total) / 60.0)))),
		MenuStyle.persian_digits("%02d" % (total % 60)),
	]
