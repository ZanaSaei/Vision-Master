extends Node
class_name SafeAreaInsetTests

const SAFE_AREA_SCRIPT: Script = preload("res://autoload/SafeAreaInset.gd")


func test_full_screen_scene_gets_72px_top_inset_without_background_gap() -> void:
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
	_check(is_zero_approx(scene_root.offset_top), "The scene root remains full-screen")
	_check(is_equal_approx(content.offset_top, 72.0), "Full-screen scene content receives the 72 px top inset")
	_check(is_equal_approx(content.offset_bottom, -72.0), "Full-screen content keeps its original bottom edge")
	_check(is_equal_approx(background.offset_top, -72.0), "Full-rect background extends behind the inset")

	var centered_scene: Control = Control.new()
	centered_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	var centered_content: Control = Control.new()
	centered_content.anchor_left = 0.0
	centered_content.anchor_right = 1.0
	centered_content.anchor_top = 0.25
	centered_content.anchor_bottom = 0.75
	centered_scene.add_child(centered_content)
	add_child(centered_scene)
	await get_tree().process_frame
	SAFE_AREA_SCRIPT.apply_to_scene(centered_scene)
	_check(is_equal_approx(centered_content.offset_top, 72.0), "Center-anchored content receives the safe-area offset")
	_check(is_equal_approx(centered_content.offset_bottom, 72.0), "Center-anchored content keeps its original lower edge")

	var bottom_scene: Control = Control.new()
	bottom_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bottom_bar: Control = Control.new()
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_scene.add_child(bottom_bar)
	add_child(bottom_scene)
	await get_tree().process_frame
	SAFE_AREA_SCRIPT.apply_to_scene(bottom_scene)
	_check(is_zero_approx(bottom_bar.offset_top), "Bottom-pinned navigation does not move")

	SAFE_AREA_SCRIPT.apply_to_scene(scene_root)
	_check(is_equal_approx(content.offset_top, 72.0), "Repeated scene notifications do not stack the inset")

	scene_root.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)
