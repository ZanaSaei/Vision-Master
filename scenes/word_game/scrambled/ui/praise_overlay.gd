class_name ScrambledPraiseOverlay
extends Control
## ============================================================
##  PRAISE OVERLAY — the "well done" the board never has to know about.
##
##  Two floating pieces of feedback live here: the big «آفرین!» that lands when
##  a word is spelled, and the "+۶۰" that rises off the board as the points are
##  banked. They deliberately sit ABOVE the layout in their own full-rect
##  overlay, because they are not part of the board's flow — nothing should
##  move when they appear, and they must not swallow a drag aimed at the row
##  (hence the overlay and its labels are all mouse-ignoring).
##
##  Both wear a theme variation (`ScrambledPraise`, `ScrambledPoints`), so the
##  only thing left in this script is the movement — and nothing to re-apply on
##  a theme toggle.
##
##  The lines are chosen here: which praise to say is a presentation decision,
##  not something the screen that awards a word should have to make.
## ============================================================

const LINES := ["آفرین!", "عالی بود!", "درسته!", "چه سریع!"]
## The praise lands from here and springs open, then breathes.
const PRAISE_FROM := 0.5
const PRAISE_LAND_TIME := 0.36
const PRAISE_BREATHE_TIME := 0.9
const PRAISE_BREATHE_TO := 0.97
## The points rise this far, in pixels, while they fade. The resting place is
## pinned by these two, so a burst after a burst rises from the same spot
## instead of drifting off the top of the screen.
const POINTS_RISE := 170.0
const POINTS_TIME := 1.1
const POINTS_REST_TOP := -140.0
const POINTS_REST_BOTTOM := -50.0

@onready var _praise: Label = $Praise
@onready var _points: Label = $Points


## Lands a random line of praise.
func celebrate() -> void:
	_praise.text = LINES[randi() % LINES.size()]
	_praise.visible = true
	_praise.scale = Vector2(PRAISE_FROM, PRAISE_FROM)
	var tw := create_tween()
	tw.tween_property(_praise, "scale", Vector2.ONE, PRAISE_LAND_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_praise, "scale", Vector2(PRAISE_BREATHE_TO, PRAISE_BREATHE_TO),
		PRAISE_BREATHE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## "+۶۰" rises off the board and fades — the classic score pop.
func float_points(points: int) -> void:
	_points.text = "+%s" % MenuStyle.persian_digits(str(points))
	_points.visible = true
	_points.modulate.a = 1.0
	_points.offset_top = POINTS_REST_TOP
	_points.offset_bottom = POINTS_REST_BOTTOM
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_points, "offset_top", POINTS_REST_TOP - POINTS_RISE, POINTS_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_points, "offset_bottom", POINTS_REST_BOTTOM - POINTS_RISE, POINTS_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_points, "modulate:a", 0.0, POINTS_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Wipes both pieces of feedback, ready for the next word.
func clear() -> void:
	_praise.visible = false
	_praise.scale = Vector2.ONE
	_points.visible = false
	_points.modulate.a = 1.0
