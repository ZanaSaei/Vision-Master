extends Node
class_name SafeAreaInsetManager

## Adds a fixed top inset to each active full-screen Control scene so content
## clears Android camera/notch cutouts. Full-rect ColorRect/TextureRect
## backgrounds are extended upward to keep filling behind the inset.
const TOP_INSET: float = 72.0
const INSET_META: StringName = &"safe_area_top_inset_applied"


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_apply_to_current_scene")


func _on_scene_changed() -> void:
	_apply_to_current_scene()


func _apply_to_current_scene() -> void:
	apply_to_scene(get_tree().current_scene)


static func apply_to_scene(scene_root: Node) -> void:
	if scene_root == null or not (scene_root is Control):
		return
	if scene_root.has_meta(INSET_META):
		return

	var root_control: Control = scene_root as Control
	root_control.set_meta(INSET_META, true)

	for child: Node in root_control.get_children():
		if not (child is Control):
			continue
		var control: Control = child as Control
		if _is_full_rect_background(control):
			control.offset_top -= TOP_INSET
			continue
		if control.anchor_top >= 0.8:
			continue

		# Move top- or center-anchored content while leaving bottom-pinned UI
		# alone. If its bottom anchor is the screen bottom, reduce bottom offset
		# so the content's lower edge remains fixed and its viewport shortens.
		control.offset_top += TOP_INSET
		if is_equal_approx(control.anchor_top, control.anchor_bottom):
			control.offset_bottom += TOP_INSET
		elif is_equal_approx(control.anchor_bottom, 1.0):
			control.offset_bottom -= TOP_INSET
		else:
			control.offset_bottom += TOP_INSET


static func _is_full_rect_background(control: Control) -> bool:
	if not (control is ColorRect or control is TextureRect):
		return false
	return (
		is_zero_approx(control.anchor_top)
		and is_equal_approx(control.anchor_bottom, 1.0)
		and is_zero_approx(control.anchor_left)
		and is_equal_approx(control.anchor_right, 1.0)
	)
