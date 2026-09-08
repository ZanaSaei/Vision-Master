class_name AudioSliderDot
extends Control

const GRABBER_TEXTURE: Texture2D = preload("res://images/audio_grabber.png")
const SHOW_DURATION: float = 0.18
const HIDE_DURATION: float = 0.16

var _slider: Range = null
var _tween: Tween = null

var dot_scale: float = 0.0:
	set(value):
		dot_scale = value
		queue_redraw()


func setup(slider: Range) -> void:
	_slider = slider
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the overlay anchored to the slider's origin. Its own size is unused;
	# drawing positions are computed from the slider's rect instead.
	position = Vector2.ZERO
	clip_contents = false


func show_dot() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "dot_scale", 1.0, SHOW_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_dot() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "dot_scale", 0.0, HIDE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _process(_delta: float) -> void:
	# Keep tracking the slider value while the dot is shown.
	if dot_scale > 0.01 and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if _slider == null or dot_scale <= 0.01:
		return
	var span: float = _slider.max_value - _slider.min_value
	if span <= 0.0:
		return
	var ratio := clampf((_slider.value - _slider.min_value) / span, 0.0, 1.0)
	var tex_size: Vector2 = GRABBER_TEXTURE.get_size() * dot_scale
	var pos := Vector2(ratio * _slider.size.x - tex_size.x * 0.5, _slider.size.y * 0.5 - tex_size.y * 0.5)
	draw_texture_rect(GRABBER_TEXTURE, Rect2(pos, tex_size), false)
