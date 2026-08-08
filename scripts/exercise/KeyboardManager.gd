class_name KeyboardManager
extends RefCounted

## Abstraction over OS virtual keyboards and focus management.

static func show(ctrl: Control) -> void:
	if OS.get_name() in ["Android", "iOS"] and DisplayServer.has_method("virtual_keyboard_show"):
		var text := ""
		if ctrl is LineEdit:
			text = ctrl.text
		elif ctrl is TextEdit:
			text = ctrl.text
		DisplayServer.virtual_keyboard_show(text)

static func hide() -> void:
	if OS.get_name() in ["Android", "iOS"] and DisplayServer.has_method("virtual_keyboard_hide"):
		DisplayServer.virtual_keyboard_hide()
