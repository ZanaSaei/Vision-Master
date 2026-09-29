class_name UiMotion
extends RefCounted
## ============================================================
##  UI MOTION — the app's shared interaction choreography.
##
##  Split out of the old MenuStyle god-module. Every duration, easing, scale and
##  offset now comes from a UiMotionProfile resource in
##  res://resources/motion/ instead of being written into the code, so the whole
##  app's feel is retunable in the Inspector and two screens that should move
##  alike share literally the same resource.
##
##  All helpers are fire-and-forget: they create their own tween on the target
##  node and return it, so a caller may await or chain it.
## ============================================================

const MOTION_DIR := "res://resources/motion/"

## Explicit preload rather than the global class name, so this module resolves
## its resource type regardless of when the editor's class cache is refreshed.
const MotionProfile := preload("res://scripts/resources/ui_motion_profile.gd")

static var _profiles: Dictionary = {}


## Loads and caches a motion profile by file name (without .tres).
static func profile(name: String) -> MotionProfile:
	if not _profiles.has(name):
		_profiles[name] = load("%s%s.tres" % [MOTION_DIR, name]) as MotionProfile
	return _profiles[name]


## Tween scaling needs a centre pivot or the node appears to swing from its
## top-left corner. Set once per node, and kept in sync on resize.
static func center_pivot(node: Control) -> void:
	if node.pivot_offset == Vector2.ZERO:
		node.pivot_offset = node.size / 2.0


# ══════════════════════════════════════════════════════════════
#  ENTRANCE / FEEDBACK
# ══════════════════════════════════════════════════════════════

## Scales a control up from nothing — the "pop in" for cards, tiles and popups.
static func pop_in(node: Control, delay: float = 0.0) -> Tween:
	var p := profile("pop_in")
	center_pivot(node)
	node.scale = Vector2(p.from_scale, p.from_scale)
	node.modulate.a = p.from_alpha
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, p.duration).set_delay(delay) \
		.set_trans(p.transition).set_ease(p.easing)
	tw.tween_property(node, "modulate:a", 1.0, p.settle_duration).set_delay(delay)
	return tw


## Horizontal shake for a wrong answer. Rotates nothing, so it is safe on any
## layout container.
static func shake(node: Control) -> Tween:
	var p := profile("shake")
	center_pivot(node)
	var home := node.position
	var offsets := p.shake_offsets
	var step := p.duration / maxf(float(offsets.size()), 1.0)
	var tw := node.create_tween()
	# Diminishing offsets: the classic "no" head-shake.
	for offset in offsets:
		tw.tween_property(node, "position:x", home.x + offset, step) \
			.set_trans(p.transition).set_ease(p.easing)
	return tw


## A short scale bump for a correct answer / successful drop.
## `strength` overrides the profile's peak scale when a caller needs more punch.
static func pop(node: Control, strength: float = 0.0) -> Tween:
	var p := profile("pop")
	center_pivot(node)
	var peak := strength if strength > 0.0 else p.peak_scale
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(peak, peak), p.duration) \
		.set_trans(p.transition).set_ease(p.easing)
	tw.tween_property(node, "scale", Vector2.ONE, p.settle_duration) \
		.set_trans(p.settle_transition).set_ease(p.settle_easing)
	return tw


## Gentle infinite breathing loop, for "tap me" affordances.
## `amount` overrides the profile's peak scale.
static func pulse_loop(node: Control, amount: float = 0.0) -> Tween:
	var p := profile("pulse")
	center_pivot(node)
	var peak := amount if amount > 0.0 else p.peak_scale
	var tw := node.create_tween()
	if p.loops_forever:
		tw.set_loops()
	else:
		tw.set_loops(p.loop_count)
	tw.tween_property(node, "scale", Vector2(peak, peak), p.duration) \
		.set_trans(p.transition).set_ease(p.easing)
	tw.tween_property(node, "scale", Vector2.ONE, p.settle_duration) \
		.set_trans(p.settle_transition).set_ease(p.settle_easing)
	return tw


## Cinematic entrance: slides in from the right while fading up. `delay` lets a
## caller stagger a list into a cascade; `distance` overrides the profile travel.
static func slide_in(node: Control, delay: float = 0.0, distance: float = 0.0) -> Tween:
	var p := profile("slide_in")
	var travel := distance if distance > 0.0 else p.distance
	var home := node.position
	node.position = Vector2(home.x + travel, home.y)
	node.modulate.a = p.from_alpha
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position", home, p.duration).set_delay(delay) \
		.set_trans(p.transition).set_ease(p.easing)
	tw.tween_property(node, "modulate:a", 1.0, p.settle_duration).set_delay(delay)
	return tw


## Staggered cascade over a list — the menu entrance used across the app.
static func stagger_in(nodes: Array, step: float = 0.07, distance: float = 70.0) -> void:
	for i in nodes.size():
		var node := nodes[i] as Control
		if node != null:
			slide_in(node, float(i) * step, distance)


# ══════════════════════════════════════════════════════════════
#  MICRO-INTERACTIONS
# ══════════════════════════════════════════════════════════════

## Friendly hover-lift / press-squash micro-interactions on a button.
## Wiring is idempotent — calling it twice on the same button is a no-op.
static func wire_microinteractions(btn: Button) -> void:
	if btn.has_meta("ui_motion_wired"):
		return
	btn.set_meta("ui_motion_wired", true)
	center_pivot(btn)
	# Keep the hover card inside its layout slot: scaling clips the outer edges
	# against the parent ScrollContainer and hides the outline. The profile
	# therefore targets scale 1.0 for hover; a component that wants a real lift
	# changes the resource, not this function.
	btn.resized.connect(func() -> void: center_pivot(btn))
	btn.mouse_entered.connect(func() -> void: _scale_to_profile(btn, "hover_lift"))
	btn.mouse_exited.connect(func() -> void: _scale_to_profile(btn, "hover_lift"))
	btn.button_down.connect(func() -> void: _scale_to_profile(btn, "press_squash"))
	btn.button_up.connect(func() -> void: _scale_to_profile(btn, "press_release"))


static func _scale_to_profile(node: Control, profile_name: String) -> void:
	var p := profile(profile_name)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(p.peak_scale, p.peak_scale), p.duration) \
		.set_trans(p.transition).set_ease(p.easing)
