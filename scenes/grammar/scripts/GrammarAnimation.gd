class_name GrammarAnimation
extends RefCounted


static func _kill_tweens(
	control: Control
) -> void:

	if not control.has_meta("grammar_tween"):
		return

	var tween: Tween = control.get_meta(
		"grammar_tween"
	)

	if tween != null:
		if tween is Tween and tween.is_valid():
			tween.kill()


static func _store_tween(
	control: Control,
	tween: Tween
) -> void:

	control.set_meta(
		"grammar_tween",
		tween
	)


# ============================================================
# BUTTON PRESS
# ============================================================

static func press(
	control: Control
) -> void:

	_kill_tweens(control)

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		control,
		"scale",
		Vector2(0.94, 0.94),
		0.07
	)

	tween.tween_property(
		control,
		"scale",
		Vector2(1.02, 1.02),
		0.08
	)

	tween.tween_property(
		control,
		"scale",
		Vector2.ONE,
		0.10
	)


# ============================================================
# BUTTON HOVER / ATTENTION
# ============================================================

static func small_pop(
	control: Control
) -> void:

	_kill_tweens(control)

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		control,
		"scale",
		Vector2(1.04, 1.04),
		0.12
	)

	tween.tween_property(
		control,
		"scale",
		Vector2.ONE,
		0.16
	)


# ============================================================
# CORRECT
# ============================================================

static func correct(
	control: Control
) -> void:

	_kill_tweens(control)

	var original_position := control.position

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		control,
		"scale",
		Vector2(1.06, 1.06),
		0.12
	)

	tween.parallel().tween_property(
		control,
		"position",
		original_position + Vector2(0, -6),
		0.12
	)

	tween.tween_property(
		control,
		"scale",
		Vector2.ONE,
		0.16
	)

	tween.tween_property(
		control,
		"position",
		original_position,
		0.14
	)


# ============================================================
# WRONG
# ============================================================

static func wrong(
	control: Control
) -> void:

	_kill_tweens(control)

	var original_position := control.position

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_SINE
	)

	tween.set_ease(
		Tween.EASE_IN_OUT
	)

	var offsets := [
		-10.0,
		10.0,
		-8.0,
		8.0,
		-5.0,
		5.0,
		0.0
	]

	for offset in offsets:

		tween.tween_property(
			control,
			"position",
			original_position + Vector2(
				offset,
				0
			),
			0.045
		)


# ============================================================
# APPEAR
# ============================================================

static func appear(
	control: Control,
	delay: float = 0.0
) -> void:

	_kill_tweens(control)

	control.modulate.a = 0.0
	control.scale = Vector2(
		0.92,
		0.92
	)

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	if delay > 0.0:
		tween.tween_interval(delay)

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		control,
		"modulate:a",
		1.0,
		0.22
	)

	tween.parallel().tween_property(
		control,
		"scale",
		Vector2.ONE,
		0.30
	)


# ============================================================
# DISAPPEAR
# ============================================================

static func disappear(
	control: Control,
	duration: float = 0.18
) -> void:

	_kill_tweens(control)

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_QUAD
	)

	tween.set_ease(
		Tween.EASE_IN
	)

	tween.parallel().tween_property(
		control,
		"modulate:a",
		0.0,
		duration
	)

	tween.parallel().tween_property(
		control,
		"scale",
		Vector2(0.94, 0.94),
		duration
	)


# ============================================================
# SLIDE UP
# ============================================================

static func slide_up(
	control: Control,
	distance: float = 30.0,
	delay: float = 0.0
) -> void:

	_kill_tweens(control)

	var final_position := control.position

	control.position.y += distance
	control.modulate.a = 0.0

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	if delay > 0.0:
		tween.tween_interval(delay)

	tween.set_trans(
		Tween.TRANS_CUBIC
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		control,
		"position",
		final_position,
		0.30
	)

	tween.parallel().tween_property(
		control,
		"modulate:a",
		1.0,
		0.22
	)


# ============================================================
# POP
# ============================================================

static func pop(
	control: Control
) -> void:

	_kill_tweens(control)

	control.scale = Vector2(
		0.65,
		0.65
	)

	control.modulate.a = 0.0

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		control,
		"scale",
		Vector2(1.0, 1.0),
		0.35
	)

	tween.parallel().tween_property(
		control,
		"modulate:a",
		1.0,
		0.22
	)


# ============================================================
# XP FLOAT
# ============================================================

static func float_up(
	control: Control
) -> void:

	var final_position := control.position

	control.modulate.a = 1.0

	var tween := control.create_tween()

	_store_tween(
		control,
		tween
	)

	tween.set_trans(
		Tween.TRANS_CUBIC
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		control,
		"position",
		final_position + Vector2(0, -70),
		0.65
	)

	tween.parallel().tween_property(
		control,
		"modulate:a",
		0.0,
		0.65
	)
