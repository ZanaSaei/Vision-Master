extends Node
class_name SafeAreaInsetTests

const SAFE_AREA_SCRIPT: Script = preload("res://autoload/SafeAreaInset.gd")


func test_scene_content_keeps_its_configured_top_layout() -> void:
	var scene_root: Control = Control.new()
	scene_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var content: Control = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene_root.add_child(background)
	scene_root.add_child(content)
	add_child(scene_root)
	await get_tree().process_frame

	SAFE_AREA_SCRIPT.apply_to_scene(scene_root)
	_check(is_zero_approx(content.offset_top), "Full-screen scene content keeps its configured top edge")
	_check(is_zero_approx(content.offset_bottom), "Full-screen scene content keeps its configured bottom edge")
	_check(is_zero_approx(background.offset_top), "Background remains full-screen without an added top adjustment")

	scene_root.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)
