extends Control

# ============================================================
#  BACK BUTTON HANDLER
#  Base script for handling Android back button
#  Extend this script in all scenes that need back button support
# ============================================================

var back_pressed_time: float = 0.0
var double_back_timeout: float = 2.0  # seconds to wait for second back press


func _ready() -> void:
	# Make sure the scene can receive input
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		# Android's back button can surface as either keycode or
		# physical_keycode depending on the device/platform — check both.
		if event.pressed and (event.keycode == KEY_BACK or event.physical_keycode == KEY_BACK):
			_on_android_back_pressed()


func _on_android_back_pressed() -> void:
	# Override this in child scenes
	pass
