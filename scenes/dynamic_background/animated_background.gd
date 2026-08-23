class_name AnimatedBackground
extends Node2D

signal enter_finished
signal exit_finished

@export var base_color: Color = Color(0.02, 0.04, 0.13)

var _waves: Array[CornerWave] = []
var _is_animating: bool = false

func _ready() -> void:
	_build_waves()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), base_color)

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
	for wave in _waves:
		wave.rebuild()


## Recolor the base fill and every corner wave for the active theme.
## Each wave gets a rich 3-stop gradient (top → mid → bottom).
func apply_theme(bg: Color, wave_top: Color, wave_mid: Color, wave_bottom: Color) -> void:
	base_color = bg
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
	for i in range(_waves.size()):
		var wave: CornerWave = _waves[i]
		tween.tween_property(wave, "position", wave.enter_from, duration) \
			.set_delay(i * stagger) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	await tween.finished
	_is_animating = false
	exit_finished.emit()
