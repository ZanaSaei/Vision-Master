class_name UiMotionProfile
extends Resource
## ============================================================
##  UI MOTION PROFILE — one reusable, Inspector-editable motion recipe.
##
##  Every interaction animation in the app (pop-in, shake, pop, pulse,
##  slide-in, page fade, page slide, wordle reveal) reads its timing and
##  geometry from a profile resource instead of hardcoding numbers inside a
##  script. A designer can retune the whole app's feel from
##  res://resources/motion/ without touching GDScript, and two screens that
##  should move the same way share literally the same resource.
##
##  The profiles are consumed by UiMotion (res://ui/motion/ui_motion.gd) and
##  by TransitionManager. See res://resources/motion/ for the shipped set.
## ============================================================

## Length of the animation's main leg, in seconds.
@export_range(0.01, 3.0, 0.01) var duration: float = 0.34

## Seconds to wait before the animation starts. Used to stagger a list.
@export_range(0.0, 2.0, 0.01) var delay: float = 0.0

## Tween interpolation curve.
@export var transition: Tween.TransitionType = Tween.TRANS_CUBIC

## Tween easing at the ends of the curve.
@export var easing: Tween.EaseType = Tween.EASE_OUT

## Second leg of a two-part animation (settle / return). 0 disables it.
@export_range(0.0, 3.0, 0.01) var settle_duration: float = 0.0

## Curve + easing for the settle leg.
@export var settle_transition: Tween.TransitionType = Tween.TRANS_ELASTIC
@export var settle_easing: Tween.EaseType = Tween.EASE_OUT

## Scale the node starts at (pop-in) or overshoots to (pop).
@export var from_scale: float = 0.86
@export var peak_scale: float = 1.12

## Alpha the node starts at.
@export_range(0.0, 1.0, 0.01) var from_alpha: float = 0.0

## Horizontal travel distance in pixels, for slide-style motions.
@export var distance: float = 90.0

## Diminishing offsets for a shake, in pixels. A trailing 0.0 returns the
## node home; the step time is `duration / offsets.size()`.
@export var shake_offsets: PackedFloat32Array = PackedFloat32Array(
	[14.0, -12.0, 9.0, -6.0, 3.0, 0.0]
)

## How many times a looping motion repeats. 0 = forever.
@export_range(0, 20, 1) var loop_count: int = 0

## True when the animation repeats until stopped (pulse loops).
@export var loops_forever: bool = false
