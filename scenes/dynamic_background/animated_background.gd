class_name AnimatedBackground
extends Node2D

signal enter_finished
signal exit_finished

@export var base_color: Color = Color(0.02, 0.04, 0.13)

var _waves: Array[CornerWave] = []
var _is_animating: bool = false
var _shader_layer: ShaderQuad = null
var _shader_mat: ShaderMaterial = null

# Full-screen ambient shader used as the backdrop layer (behind the waves).
const BG_SHADER := preload("res://scenes/dynamic_background/dynamic_background.gdshader")

func _ready() -> void:
	_build_shader_layer()
	_build_waves()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _process(_delta: float) -> void:
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("u_time", Time.get_ticks_msec() * 0.001)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), base_color)

## Full-screen shader quad behind the corner waves. Provides the base
## gradient, breathing glow, drifting aurora bands and vignette. Starts
## transparent and fades in with play_enter().
func _build_shader_layer() -> void:
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = BG_SHADER
	# Dark-palette defaults; apply_theme() retints to the active theme.
	_set_shader_colors(
		Color(0.028, 0.036, 0.11),
		Color(0.32, 0.21, 0.66),
		Color(0.20, 0.24, 0.66),
		Color(0.09, 0.12, 0.42)
	)
	# Node2D-based quad (NOT a Control): Controls don't auto-size to the
	# viewport when their parent is a Node2D, so a full-screen shader layer
	# must size and redraw itself from the viewport rect.
	_shader_layer = ShaderQuad.new()
	_shader_layer.material = _shader_mat
	_shader_layer.set_quad_size(get_viewport_rect().size)
	_shader_layer.modulate.a = 0.0
	_shader_layer.name = "AmbientShaderLayer"
	add_child(_shader_layer)

## Derive the shader's color palette from the theme's bg + wave colors so the
## ambient layer follows Dark ("Midnight Nebula") and Light ("Morning
## Periwinkle") automatically.
func _set_shader_colors(bg: Color, wave_top: Color, wave_mid: Color, wave_bottom: Color) -> void:
	if _shader_mat == null:
		return
	var light: bool = bg.get_luminance() > 0.5
	var top: Color
	var bottom: Color
	if light:
		# Light theme: bright, airy top fading into a deeper periwinkle base.
		top = bg.lightened(0.08)
		bottom = bg.darkened(0.20)
	else:
		# Dark theme: indigo-tinted top, deep navy bottom.
		top = bg.lerp(wave_top, 0.55).lightened(0.30)
		bottom = bg.darkened(0.22)
	_shader_mat.set_shader_parameter("u_col_top", top)
	_shader_mat.set_shader_parameter("u_col_bottom", bottom)
	_shader_mat.set_shader_parameter("u_col_glow", wave_top)
	_shader_mat.set_shader_parameter("u_col_band_a", wave_mid)
	_shader_mat.set_shader_parameter("u_col_band_b", wave_bottom)
	_shader_mat.set_shader_parameter("u_glow_strength", 0.30 if light else 0.42)
	_shader_mat.set_shader_parameter("u_vignette", 0.40 if light else 0.60)

## A Node2D that draws a full-screen white quad so the ambient shader has
## geometry to shade. Sized manually from the viewport rect (Controls don't
## auto-stretch under a Node2D parent).
class ShaderQuad extends Node2D:
	var quad_size: Vector2 = Vector2.ZERO

	func set_quad_size(s: Vector2) -> void:
		quad_size = s
		queue_redraw()

	func _draw() -> void:
		if quad_size.x > 0.0 and quad_size.y > 0.0:
			draw_rect(Rect2(Vector2.ZERO, quad_size), Color.WHITE)

func _build_waves() -> void:
	# Each wave is authored in "canonical top-left corner space":
	# first point sits on the TOP edge (x, 0.0), last point sits on the
	# LEFT edge (0.0, y), wavy points bulge in between. CornerWave mirrors
	# these automatically for the other three corners.
	#
	# Values are FRACTIONS OF THE SCREEN — keep them small (<= ~0.55)
	# so the waves stay in the corners and the center stays clear.
	#
	# Draw order matters: earlier entries render BEHIND later ones.
	var configs: Array = [
		{
			# Top-left corner, single wave — drawn FIRST, behind everything
			"corner": CornerWave.CornerType.TOP_LEFT,
			"points": [
				Vector2(0.44, 0.0), Vector2(0.35, 0.07), Vector2(0.40, 0.14),
				Vector2(0.27, 0.22), Vector2(0.31, 0.30), Vector2(0.17, 0.38),
				Vector2(0.20, 0.46), Vector2(0.07, 0.53), Vector2(0.0, 0.58),
			],
			"top_color": Color(0.035, 0.055, 0.17),
			"bottom_color": Color(0.02, 0.035, 0.12),
			"enter_dir": Vector2(-1.3, -1.3),
		},
		{
			# Bottom-right corner, single wave — drawn second, behind the stacked pairs
			"corner": CornerWave.CornerType.BOTTOM_RIGHT,
			"points": [
				Vector2(0.40, 0.0), Vector2(0.32, 0.07), Vector2(0.36, 0.14),
				Vector2(0.23, 0.22), Vector2(0.27, 0.30), Vector2(0.13, 0.38),
				Vector2(0.15, 0.46), Vector2(0.0, 0.52),
			],
			"top_color": Color(0.08, 0.15, 0.5),
			"bottom_color": Color(0.05, 0.10, 0.36),
			"enter_dir": Vector2(1.3, 1.3),
		},
		{
			# Top-right corner, BIGGER of the two stacked waves
			"corner": CornerWave.CornerType.TOP_RIGHT,
			"points": [
				Vector2(0.36, 0.0), Vector2(0.28, 0.07), Vector2(0.32, 0.15),
				Vector2(0.19, 0.23), Vector2(0.23, 0.31), Vector2(0.10, 0.39),
				Vector2(0.13, 0.47), Vector2(0.0, 0.54),
			],
			"top_color": Color(0.11, 0.22, 0.62),
			"bottom_color": Color(0.07, 0.14, 0.46),
			"enter_dir": Vector2(1.3, -1.3),
		},
		{
			# Top-right corner, SMALLER wave sitting on top, slightly darker
			"corner": CornerWave.CornerType.TOP_RIGHT,
			"points": [
				Vector2(0.22, 0.0), Vector2(0.16, 0.05), Vector2(0.19, 0.11),
				Vector2(0.09, 0.17), Vector2(0.11, 0.24), Vector2(0.0, 0.30),
			],
			"top_color": Color(0.045, 0.07, 0.20),
			"bottom_color": Color(0.03, 0.05, 0.15),
			"enter_dir": Vector2(1.5, -1.5),
		},
		{
			# Bottom-left corner, BIGGER of the two stacked waves
			"corner": CornerWave.CornerType.BOTTOM_LEFT,
			"points": [
				Vector2(0.34, 0.0), Vector2(0.26, 0.07), Vector2(0.30, 0.15),
				Vector2(0.18, 0.23), Vector2(0.22, 0.31), Vector2(0.09, 0.39),
				Vector2(0.12, 0.47), Vector2(0.0, 0.54),
			],
			"top_color": Color(0.09, 0.18, 0.56),
			"bottom_color": Color(0.06, 0.12, 0.40),
			"enter_dir": Vector2(-1.3, 1.3),
		},
		{
			# Bottom-left corner, SMALLER wave sitting on top, slightly lighter
			"corner": CornerWave.CornerType.BOTTOM_LEFT,
			"points": [
				Vector2(0.20, 0.0), Vector2(0.14, 0.06), Vector2(0.17, 0.12),
				Vector2(0.07, 0.18), Vector2(0.09, 0.25), Vector2(0.0, 0.31),
			],
			"top_color": Color(0.12, 0.24, 0.68),
			"bottom_color": Color(0.08, 0.16, 0.50),
			"enter_dir": Vector2(-1.5, 1.5),
		},
	]

	var vp_size: Vector2 = get_viewport_rect().size
	for config in configs:
		var wave := CornerWave.new()
		add_child(wave)
		var pts: Array[Vector2] = []
		for p in config["points"]:
			pts.append(p)
		wave.setup(
			config["corner"],
			pts,
			config["top_color"],
			config["bottom_color"],
			config["enter_dir"] * vp_size
		)
		_waves.append(wave)

func _on_viewport_resized() -> void:
	queue_redraw()
	if _shader_layer != null:
		_shader_layer.set_quad_size(get_viewport_rect().size)
	for wave in _waves:
		wave.rebuild()


## Recolor the base fill and every corner wave for the active theme.
## Each wave gets a rich 3-stop gradient (top → mid → bottom).
func apply_theme(bg: Color, wave_top: Color, wave_mid: Color, wave_bottom: Color) -> void:
	base_color = bg
	_set_shader_colors(bg, wave_top, wave_mid, wave_bottom)
	for i in range(_waves.size()):
		var wave: CornerWave = _waves[i]
		wave.top_color = wave_top
		wave.mid_color = wave_mid
		wave.bottom_color = wave_bottom
		# Slight per-corner hue variation for a richer, more organic range.
		var offset := float(i % 3) * 0.06
		wave.top_color = wave_top.lerp(Color(0.0, 0.3, 0.9, 1.0), offset)
		wave.rebuild()
	queue_redraw()

func play_enter(stagger: float = 0.07, duration: float = 0.7) -> void:
	if _is_animating:
		return
	_is_animating = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if _shader_layer != null:
		tween.tween_property(_shader_layer, "modulate:a", 1.0, duration * 0.8)
	for i in range(_waves.size()):
		var wave: CornerWave = _waves[i]
		tween.tween_property(wave, "position", wave.rest_position, duration) \
			.set_delay(i * stagger) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	await tween.finished
	_is_animating = false
	enter_finished.emit()

func play_exit(stagger: float = 0.05, duration: float = 0.5) -> void:
	if _is_animating:
		return
	_is_animating = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if _shader_layer != null:
		tween.tween_property(_shader_layer, "modulate:a", 0.0, duration * 0.8)
	for i in range(_waves.size()):
		var wave: CornerWave = _waves[i]
		tween.tween_property(wave, "position", wave.enter_from, duration) \
			.set_delay(i * stagger) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	await tween.finished
	_is_animating = false
	exit_finished.emit()
