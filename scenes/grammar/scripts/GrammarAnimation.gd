class_name GrammarAnimation
extends RefCounted


static func _kill_tweens(control: Control) -> void:
	if not control.has_meta("grammar_tween"):
		return
	var tween: Tween = control.get_meta("grammar_tween")
	if tween != null and tween is Tween and tween.is_valid():
		tween.kill()


static func _store_tween(control: Control, tween: Tween) -> void:
	control.set_meta("grammar_tween", tween)


static func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


# ============================================================
# BUTTON PRESS
# ============================================================
static func press(control: Control) -> void:
	_kill_tweens(control)
	control.modulate.a = 1.0
	_center_pivot(control)
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(0.94, 0.94), 0.07)
	tween.tween_property(control, "scale", Vector2(1.02, 1.02), 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.10)


# ============================================================
# BUTTON HOVER / ATTENTION
# ============================================================
static func small_pop(control: Control) -> void:
	_kill_tweens(control)
	control.modulate.a = 1.0
	_center_pivot(control)
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(1.04, 1.04), 0.12)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16)


# ============================================================
# CORRECT (+ Sparkle Burst)
# ============================================================
static func correct(control: Control) -> void:
	_kill_tweens(control)
	_center_pivot(control)
	var original_position := control.position
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2(1.06, 1.06), 0.12)
	tween.parallel().tween_property(control, "position", original_position + Vector2(0, -6), 0.12)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16)
	tween.tween_property(control, "position", original_position, 0.14)
	spawn_sparkle_burst(control)


# ============================================================
# WRONG
# ============================================================
static func wrong(control: Control) -> void:
	_kill_tweens(control)
	_center_pivot(control)
	var original_position := control.position
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var offsets := [-10.0, 10.0, -8.0, 8.0, -5.0, 5.0, 0.0]
	for offset in offsets:
		tween.tween_property(control, "position", original_position + Vector2(offset, 0), 0.045)


# ============================================================
# APPEAR
# ============================================================
static func appear(control: Control, delay: float = 0.0) -> void:
	_kill_tweens(control)
	_center_pivot(control)
	control.modulate.a = 0.0
	control.scale = Vector2(0.92, 0.92)
	var tween := control.create_tween()
	_store_tween(control, tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, 0.30)


# ============================================================
# DISAPPEAR
# ============================================================
static func disappear(control: Control, duration: float = 0.18) -> void:
	_kill_tweens(control)
	_center_pivot(control)
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(control, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(control, "scale", Vector2(0.94, 0.94), duration)


# ============================================================
# SLIDE UP
# ============================================================
static func slide_up(control: Control, distance: float = 30.0, delay: float = 0.0) -> void:
	_kill_tweens(control)
	var final_position := control.position
	control.position.y += distance
	control.modulate.a = 0.0
	var tween := control.create_tween()
	_store_tween(control, tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "position", final_position, 0.30)
	tween.parallel().tween_property(control, "modulate:a", 1.0, 0.22)


# ============================================================
# POP
# ============================================================
static func pop(control: Control) -> void:
	_kill_tweens(control)
	_center_pivot(control)
	control.scale = Vector2(0.65, 0.65)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(control, "modulate:a", 1.0, 0.22)


# ============================================================
# XP FLOAT & FLOATING XP TOAST
# ============================================================
static func float_up(control: Control) -> void:
	var final_position := control.position
	control.modulate.a = 1.0
	var tween := control.create_tween()
	_store_tween(control, tween)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "position", final_position + Vector2(0, -70), 0.65)
	tween.parallel().tween_property(control, "modulate:a", 0.0, 0.65)


static func spawn_xp_toast(host: Control, text: String, target_control: Control = null) -> void:
	if host == null or not host.is_inside_tree():
		return
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 95
	var style := GrammarTheme.rounded_box(Color("#F59E0B"), 24, Color("#FDE68A"), 2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	badge.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(lbl)
	host.add_child(badge)

	var vp_size := host.get_viewport_rect().size
	var start_pos := Vector2(vp_size.x * 0.5 - 90.0, vp_size.y * 0.22)
	if target_control != null and is_instance_valid(target_control):
		start_pos = target_control.global_position + Vector2(-20, 40)
	badge.global_position = start_pos
	badge.scale = Vector2(0.6, 0.6)

	var t := badge.create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(badge, "scale", Vector2(1.1, 1.1), 0.2)
	t.tween_property(badge, "scale", Vector2.ONE, 0.12)
	t.parallel().tween_property(badge, "global_position", start_pos + Vector2(0, -90), 0.85).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(badge, "modulate:a", 0.0, 0.35)
	t.tween_callback(badge.queue_free)


# ============================================================
# SPARKLE BURST (On Correct Answer)
# ============================================================
static func spawn_sparkle_burst(target: Control) -> void:
	if target == null or not target.is_inside_tree():
		return
	var root := target.get_tree().current_scene
	if root == null:
		return
	var center := target.global_position + target.size * 0.5
	var colors := [Color("#FBBF24"), Color("#34D399"), Color("#22D3EE"), Color("#A78BFA")]
	for i in range(10):
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.z_index = 90
		dot.size = Vector2(12, 12)
		dot.pivot_offset = Vector2(6, 6)
		dot.color = colors[i % colors.size()]
		dot.global_position = center - Vector2(6, 6)
		dot.rotation = randf() * TAU
		root.add_child(dot)

		var angle := (TAU / 10.0) * float(i) + randf_range(-0.2, 0.2)
		var dist := randf_range(65.0, 135.0)
		var dest := center + Vector2(cos(angle), sin(angle)) * dist

		var t := dot.create_tween()
		t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(dot, "global_position", dest, 0.45)
		t.parallel().tween_property(dot, "scale", Vector2.ZERO, 0.45)
		t.parallel().tween_property(dot, "rotation", dot.rotation + 3.0, 0.45)
		t.tween_callback(dot.queue_free)


# ============================================================
# PROCEDURAL CONFETTI CANNON (Full-screen celebration)
# ============================================================
static func spawn_confetti(host: Node, count: int = 75) -> void:
	if host == null or not host.is_inside_tree():
		return
	var layer := _ConfettiOverlay.new(count)
	host.add_child(layer)


class _ConfettiOverlay extends Control:
	var _particles: Array[Dictionary] = []
	var _elapsed: float = 0.0
	const DURATION: float = 3.4
	const PALETTE := [
		Color("#22D3EE"), # Cyan
		Color("#EC4899"), # Pink
		Color("#FBBF24"), # Gold
		Color("#34D399"), # Emerald
		Color("#A78BFA"), # Violet
		Color("#F87171")  # Coral
	]

	func _init(count: int = 75) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 120
		var vp := Vector2(1080, 1920)
		for i in range(count):
			var from_left := (i % 2 == 0)
			var start_x := randf_range(40.0, vp.x - 40.0)
			var start_y := randf_range(-80.0, 180.0)
			var vx := randf_range(-280.0, 280.0) if not from_left else randf_range(-220.0, 220.0)
			var vy := randf_range(-750.0, -250.0)
			_particles.append({
				"pos": Vector2(start_x, start_y),
				"vel": Vector2(vx, vy),
				"size": Vector2(randf_range(12.0, 22.0), randf_range(8.0, 14.0)),
				"color": PALETTE[i % PALETTE.size()],
				"rot": randf() * TAU,
				"rot_speed": randf_range(-9.0, 9.0),
				"sway_phase": randf() * TAU,
				"sway_speed": randf_range(3.0, 7.0),
				"circle": (i % 4 == 0)
			})

	func _ready() -> void:
		var vp_size := get_viewport_rect().size
		if vp_size.x > 0:
			for p in _particles:
				p["pos"].x = randf_range(40.0, vp_size.x - 40.0)

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= DURATION:
			queue_free()
			return
		for p in _particles:
			p["vel"].y += 980.0 * delta # gravity
			p["pos"].x += (p["vel"].x + sin(_elapsed * p["sway_speed"] + p["sway_phase"]) * 90.0) * delta
			p["pos"].y += p["vel"].y * delta
			p["rot"] += p["rot_speed"] * delta
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(1.0 - maxf(0.0, (_elapsed - (DURATION - 0.8)) / 0.8), 0.0, 1.0)
		for p in _particles:
			var col: Color = p["color"]
			col.a = fade
			var pos: Vector2 = p["pos"]
			if p["circle"]:
				draw_circle(pos, p["size"].x * 0.45, col)
			else:
				var flip := cos(_elapsed * p["sway_speed"] + p["sway_phase"])
				var sz := Vector2(p["size"].x, maxf(3.0, p["size"].y * absf(flip)))
				draw_set_transform(pos, p["rot"], Vector2.ONE)
				draw_rect(Rect2(-sz * 0.5, sz), col, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
