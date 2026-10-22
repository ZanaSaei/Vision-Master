extends CanvasLayer

## Persistent, theme-aware flat fill behind every scene and persistent UI layer.

var _fill: ColorRect


func _ready() -> void:
	layer = -100
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = DesignTokens.PALETTE_LIGHT["bg_base"]
	add_child(_fill)

	get_tree().scene_changed.connect(_on_scene_changed)
	if is_instance_valid(Global):
		Global.on_theme_changed(_on_theme_changed)
		_on_theme_changed(0)
	call_deferred("_refresh_scene_backgrounds")


func set_background_color(color: Color) -> void:
	if is_instance_valid(_fill):
		_fill.color = color
	call_deferred("_refresh_scene_backgrounds")


func _on_theme_changed(_mode: int) -> void:
	if is_instance_valid(Global):
		set_background_color(Global.get_theme_color("bg_base"))


func _on_scene_changed() -> void:
	call_deferred("_refresh_scene_backgrounds")


func _refresh_scene_backgrounds() -> void:
	if not is_instance_valid(Global):
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_apply_to_background_rects(scene, Global.get_theme_color("bg_base"))


func _apply_to_background_rects(node: Node, color: Color) -> void:
	if node is ColorRect and node.name in ["Background", "Bg", "BackgroundColor", "TextureRect"]:
		var background: ColorRect = node as ColorRect
		background.color = color
		background.material = null
	for child: Node in node.get_children():
		_apply_to_background_rects(child, color)
