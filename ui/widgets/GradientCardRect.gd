extends ColorRect
class_name GradientCardRect
## ============================================================
##  GRADIENT CARD RECT — keeps the GradientCard shader's corners round.
##
##  The shader draws its rounded-rect SDF in pixel space, so it needs to know
##  the control's real size. This helper just re-syncs the `rect_size` uniform
##  whenever the card is resized (orientation change, layout pass, ...).
## ============================================================


func _ready() -> void:
	resized.connect(_sync_shader_size)
	_sync_shader_size()


func _sync_shader_size() -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("rect_size", size)
