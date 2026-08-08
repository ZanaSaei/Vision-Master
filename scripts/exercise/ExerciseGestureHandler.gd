class_name ExerciseGestureHandler
extends Node

## State machine to differentiate between a quick tap (to open keyboard)
## and a drag/scroll gesture (to prevent keyboard from stealing focus).

signal tap_confirmed(ctrl: Control)

const DRAG_THRESHOLD := 28.0
const HOLD_MAX_MSEC := 350

var _drag_source: Control = null
var _drag_active := false
var _press_pos := Vector2.ZERO
var _press_time_msec := 0
var _hold_blocked := false

func register_control(ctrl: Control) -> void:
	if _is_editable(ctrl):
		ctrl.focus_mode = Control.FOCUS_NONE
		ctrl.focus_exited.connect(_on_focus_exited.bind(ctrl))
		ctrl.gui_input.connect(_on_gui_input.bind(ctrl))

func _process(_delta: float) -> void:
	if _drag_source == null or _drag_active or _hold_blocked:
		return
		
	if Time.get_ticks_msec() - _press_time_msec > HOLD_MAX_MSEC:
		_hold_blocked = true
		_drag_source.set_block_signals(true)
		_release_focus()
		KeyboardManager.hide()

func _on_gui_input(event: InputEvent, source: Control) -> void:
	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and _drag_source == source:
		var drag_pos : Vector2 = event.global_position if event is InputEventMouseMotion else event.position
		if not _drag_active and not _hold_blocked and (drag_pos - _press_pos).length() > DRAG_THRESHOLD:
			_drag_active = true
			source.set_block_signals(true)
			_release_focus()
			KeyboardManager.hide()
		return

	var is_press := false
	var is_release := false
	var press_pos := Vector2.ZERO
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
		press_pos = event.global_position
	elif event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
		press_pos = event.position

	if is_press:
		_drag_source = source
		_drag_active = false
		_hold_blocked = false
		_press_pos = press_pos
		_press_time_msec = Time.get_ticks_msec()
	elif is_release:
		if _drag_source == source and not _drag_active and not _hold_blocked:
			if _is_editable(source) and (Time.get_ticks_msec() - _press_time_msec) <= HOLD_MAX_MSEC:
				_confirm_tap(source)
		_drag_active = false
		_hold_blocked = false
		_drag_source = null

func _confirm_tap(ctrl: Control) -> void:
	ctrl.focus_mode = Control.FOCUS_ALL
	ctrl.grab_focus()
	KeyboardManager.show(ctrl)
	tap_confirmed.emit(ctrl)

func _release_focus() -> void:
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and _is_editable(focused):
			focused.release_focus()

func _on_focus_exited(ctrl: Control) -> void:
	if is_instance_valid(ctrl):
		ctrl.focus_mode = Control.FOCUS_NONE
		KeyboardManager.hide()

func _is_editable(ctrl: Control) -> bool:
	return ctrl is LineEdit or ctrl is TextEdit
