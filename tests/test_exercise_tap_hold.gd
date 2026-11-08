extends Control
## ============================================================
##  EXERCISE TAP-HOLD TEST — the Exercise Engine's tap-vs-hold rule, run LIVE.
##
##  Issue: on the phone, tapping AND HOLDING an option of a question still
##  selected it. The rule the engine promises is: a quick tap selects, a
##  press-and-hold (and hold-and-scroll) never does.
##
##  This harness pushes real press / motion / release events through the
##  Viewport against a real multiple_choice engine, exactly like a finger:
##    1. a quick tap          -> the option must be selected,
##    2. a held press (300ms) -> the option must stay unselected,
##    3. a press-drag-release -> the option must stay unselected,
##    4. a tap AFTER a hold   -> the option must select again (the gesture
##       state must not poison the next interaction).
##
##  Run it with run_scene on res://tests/TestExerciseTapHold.tscn.
## ============================================================

var _failures := 0
var _engine: ExerciseEngine = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	_engine = ExerciseEngine.new()
	column.add_child(_engine)
	_engine.build({
		"type": "multiple_choice",
		"items": [
			{
				"question": "Pick one option",
				"options": ["Apple", "Banana", "Cherry"],
				"answer": 1,
			},
		],
	})

	# Wait for the engine to lay its option buttons out so the scripted finger
	# has real rects to press on.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var options := _option_buttons()
	_check(options.size() == 3, "the engine built three toggle options")

	await _run_gestures(options)
	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)


func _option_buttons() -> Array:
	var out: Array = []
	for node in _engine.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn != null and btn.toggle_mode and not btn.disabled:
			out.append(btn)
	return out


func _run_gestures(options: Array) -> void:
	var target: Button = options[0]
	var center := target.get_global_rect().get_center()

	# --- 1. a quick tap selects the option ----------------------------------
	await _press(center)
	await get_tree().process_frame
	await _release(center)
	await get_tree().process_frame
	_check(target.button_pressed, "a quick tap selects the option")

	# --- 2. a held press (past the 180 ms hold window) must NOT select ------
	target.button_pressed = false
	await _press(center)
	# Real hold: the press sits well past the engine's _HOLD_MAX_MSEC (180 ms)
	# before the finger lifts.
	await get_tree().create_timer(0.30).timeout
	await _release(center)
	await get_tree().process_frame
	_check(not target.button_pressed, "tap and hold does NOT select the option")

	# --- 3. press-hold-scroll-release must NOT select -----------------------
	target.button_pressed = false
	await _press(center)
	await get_tree().process_frame
	await _move(center, center + Vector2(40.0, 0.0))
	await get_tree().create_timer(0.10).timeout
	await _release(center + Vector2(40.0, 0.0))
	await get_tree().process_frame
	_check(not target.button_pressed, "tap-hold-scroll does NOT select the option")

	# --- 4. the next quick tap still selects (state fully re-armed) ---------
	target.button_pressed = false
	await _press(center)
	await get_tree().process_frame
	await get_tree().process_frame
	await _release(center)
	await get_tree().process_frame
	_check(target.button_pressed, "a tap after a hold still selects the option")


############################################################
# THE SCRIPTED FINGER
############################################################
func _press(point: Vector2) -> void:
	_send_button(point, true)
	await get_tree().process_frame


func _move(from: Vector2, to: Vector2) -> void:
	_send_motion(to, to - from)
	await get_tree().process_frame


func _release(point: Vector2) -> void:
	_send_button(point, false)
	await get_tree().process_frame


func _send_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	# `true`: the coordinates come from get_global_rect(), the Viewport's own
	# GUI hit-testing space.
	get_viewport().push_input(event, true)


func _send_motion(point: Vector2, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS  " if condition else "FAIL  ") + label)
