extends Control

# ============================================================
# SCENES
# ============================================================

const BOOK_CARD_SCENE: PackedScene = preload(
	"res://scenes/book_menu/BookCard.tscn"
)

const BOOK_CONTENTS_SCENE: PackedScene = preload(
	"res://scenes/book_menu/BookMenu.tscn"
)

const GlossSheenScript: GDScript = preload(
	"res://ui/widgets/gloss_sheen.gd"
)

# ============================================================
# BOOK DATA
# ============================================================

const BOOK_TITLES: Array[String] = [
	"ویژن ۱",
	"ویژن ۲",
	"ویژن ۳"
]

const BOOK_GRADES: Array[String] = [
	"پایه دهم",
	"پایه یازدهم",
	"پایه دوازدهم"
]

const BOOK_ACCENTS: Array[Color] = [
	Color("#3B82F6"), # Vision 1: cosmic blue
	Color("#22C55E"), # Vision 2: lush green
	Color("#EF4444")  # Vision 3: sunset red
]

const PERSIAN_DIGITS: Array[String] = ["۱", "۲", "۳"]

const BOOK_COVERS: Array[Texture2D] = [
	preload("res://ui/images/book_scene/Vision1.png"),
	preload("res://ui/images/book_scene/Vision2.png"),
	preload("res://ui/images/book_scene/Vision3.png")
]

const BOOK_BLURRED_BACKGROUNDS: Array[Texture2D] = [
	preload("res://ui/images/book_scene/Vision1_blur.png"),
	preload("res://ui/images/book_scene/Vision2_blur.png"),
	preload("res://ui/images/book_scene/Vision3_blur.png")
]

const CARD_BASE_WIDTH: float = 640.0
const CARD_BASE_HEIGHT: float = 960.0

# ============================================================
# SCENE REFERENCES
# ============================================================

@onready var background_a: TextureRect = $BackgroundA
@onready var background_b: TextureRect = $BackgroundB
@onready var stage: Control = $Stage
@onready var grade_switcher: HBoxContainer = $BottomControls/GradeSwitcher
@onready var action_button: Button = $BottomControls/ActionRow/ActionButton
@onready var hint_label: Label = $BottomControls/HintLabel

# ============================================================
# STATE
# ============================================================

var cards: Array[BookCard] = []
var selected_index: int = 0
var current_offset: float = 0.0

var is_animating: bool = false
var is_opening: bool = false
var is_dragging: bool = false

var drag_start_x: float = 0.0
var drag_last_x: float = 0.0
var drag_start_offset: float = 0.0
var drag_velocity_x: float = 0.0
var total_drag_distance: float = 0.0

var snap_tween: Tween = null
var background_tween: Tween = null
var capsule_buttons: Array[Button] = []


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_configure_backgrounds()

	selected_index = clampi(BookSession.selected_book_id, 0, 2)
	current_offset = float(selected_index)

	_create_cards()
	_create_grade_switcher()
	_setup_action_button()

	get_viewport().size_changed.connect(_on_viewport_resized)

	_show_background(selected_index, false)
	_layout_carousel(current_offset)
	_update_ui_for_selection()


func _configure_backgrounds() -> void:
	for bg: TextureRect in [background_a, background_b]:
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	background_a.modulate.a = 1.0
	background_b.modulate.a = 0.0


func _create_cards() -> void:
	for book_id in range(3):
		var card := BOOK_CARD_SCENE.instantiate() as BookCard
		if card == null:
			push_error("BookSelection: Failed to instantiate BookCard.")
			return

		stage.add_child(card)
		card.set_book_content(
			book_id,
			BOOK_TITLES[book_id],
			BOOK_COVERS[book_id]
		)
		cards.append(card)


func _create_grade_switcher() -> void:
	for i in range(3):
		var btn := Button.new()
		btn.name = "GradeBtn_%d" % i
		btn.text = BOOK_GRADES[i]
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", MenuStyle.vazir())
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_grade_capsule_pressed.bind(i))
		MenuStyle.wire_microinteractions(btn)
		grade_switcher.add_child(btn)
		capsule_buttons.append(btn)


func _setup_action_button() -> void:
	action_button.pressed.connect(_open_selected_book)
	MenuStyle.wire_microinteractions(action_button)


func _on_viewport_resized() -> void:
	_layout_carousel(current_offset)


# ============================================================
# CAROUSEL LAYOUT & INTERPOLATION
# ============================================================

func _get_card_base_scale() -> float:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return 1.0

	var avail_w: float = vp_size.x - 48.0
	var avail_h: float = vp_size.y - 480.0

	var sx: float = avail_w / CARD_BASE_WIDTH
	var sy: float = avail_h / CARD_BASE_HEIGHT

	return clampf(minf(sx, sy), 0.55, 1.05)


func _layout_carousel(offset: float) -> void:
	if cards.size() != 3:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	var base_scale: float = _get_card_base_scale()

	var center_x: float = vp_size.x * 0.5
	var center_y: float = vp_size.y * 0.43
	var card_size: Vector2 = Vector2(CARD_BASE_WIDTH, CARD_BASE_HEIGHT)
	var spacing: float = card_size.x * base_scale * 0.88

	for i in range(3):
		var card: BookCard = cards[i]
		var diff: float = float(i) - offset
		var abs_diff: float = absf(diff)

		card.pivot_offset = card_size * 0.5

		var target_x: float = center_x + diff * spacing - card_size.x * 0.5
		var target_y: float = center_y - card_size.y * 0.5 + abs_diff * 22.0 * base_scale

		card.position = Vector2(target_x, target_y)

		var scale_factor: float = lerpf(1.0, 0.78, clampf(abs_diff, 0.0, 1.0))
		card.scale = Vector2.ONE * (base_scale * scale_factor)

		# 3D perspective tilt
		card.rotation = clampf(diff * -0.045, -0.15, 0.15)

		# Alpha: active card is bright, peeking cards are slightly muted
		card.modulate.a = lerpf(1.0, 0.50, clampf(abs_diff, 0.0, 1.0))

		# Center card has priority
		card.z_index = int(20.0 - abs_diff * 6.0)


func _set_carousel_offset(val: float) -> void:
	current_offset = val
	_layout_carousel(current_offset)


# ============================================================
# INPUT & GESTURE HANDLING
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if is_opening:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_drag(mouse_event.position.x)
			else:
				_end_drag(mouse_event.position)
			accept_event()

	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if is_dragging:
			_update_drag(motion_event.position.x)
			accept_event()

	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_start_drag(touch_event.position.x)
		else:
			_end_drag(touch_event.position)
		accept_event()

	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if is_dragging:
			_update_drag(drag_event.position.x)
			accept_event()


func _start_drag(x_pos: float) -> void:
	is_dragging = true
	drag_start_x = x_pos
	drag_last_x = x_pos
	drag_start_offset = current_offset
	drag_velocity_x = 0.0
	total_drag_distance = 0.0

	if snap_tween and snap_tween.is_valid():
		snap_tween.kill()


func _update_drag(x_pos: float) -> void:
	var delta: float = x_pos - drag_last_x
	drag_velocity_x = delta
	drag_last_x = x_pos
	total_drag_distance += absf(delta)

	var vp_w: float = get_viewport_rect().size.x
	var swipe_unit: float = maxf(1.0, vp_w * 0.55)
	var offset_delta: float = (x_pos - drag_start_x) / swipe_unit

	current_offset = clampf(drag_start_offset - offset_delta, -0.25, 2.25)
	_layout_carousel(current_offset)


func _end_drag(end_pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false

	# Tap detection
	if total_drag_distance < 18.0:
		var tapped_idx: int = _find_tapped_card_index(end_pos)
		if tapped_idx != -1:
			if tapped_idx == selected_index:
				_open_selected_book()
			else:
				_animate_to_index(tapped_idx)
			return

	# Swipe detection with velocity momentum
	var target_idx: int = selected_index
	if absf(drag_velocity_x) > 10.0:
		if drag_velocity_x > 0.0:
			target_idx = clampi(int(floor(current_offset)), 0, 2)
		else:
			target_idx = clampi(int(ceil(current_offset)), 0, 2)
	else:
		target_idx = clampi(int(round(current_offset)), 0, 2)

	_animate_to_index(target_idx)


func _find_tapped_card_index(tap_pos: Vector2) -> int:
	var order: Array[int] = [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool:
		return cards[a].z_index > cards[b].z_index
	)
	for idx: int in order:
		var card: BookCard = cards[idx]
		if card.get_global_rect().has_point(tap_pos):
			return idx
	return -1


func _on_grade_capsule_pressed(idx: int) -> void:
	if is_opening or idx == selected_index:
		return
	_animate_to_index(idx)


func _animate_to_index(target_idx: int) -> void:
	if is_opening:
		return
	target_idx = clampi(target_idx, 0, 2)
	var changed: bool = (target_idx != selected_index)
	selected_index = target_idx

	if snap_tween and snap_tween.is_valid():
		snap_tween.kill()

	snap_tween = create_tween()
	snap_tween.set_trans(Tween.TRANS_SPRING)
	snap_tween.set_ease(Tween.EASE_OUT)
	snap_tween.tween_method(
		_set_carousel_offset,
		current_offset,
		float(target_idx),
		0.42
	)

	if changed:
		Sfx.click()
		_show_background(selected_index, true)

	_update_ui_for_selection()


# ============================================================
# UI UPDATES (GRADE CAPSULES & ACTION BUTTON)
# ============================================================

func _update_ui_for_selection() -> void:
	_update_grade_switcher()
	_update_action_button()


func _update_grade_switcher() -> void:
	var accent: Color = BOOK_ACCENTS[selected_index]
	for i in range(capsule_buttons.size()):
		var btn: Button = capsule_buttons[i]
		var is_active: bool = (i == selected_index)

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(22)

		if is_active:
			style.bg_color = accent
			style.set_border_width_all(1)
			style.border_color = Color(1, 1, 1, 0.45)
			style.shadow_size = 8
			style.shadow_color = Color(0, 0, 0, 0.28)
			style.shadow_offset = Vector2(0, 3)
			btn.custom_minimum_size = Vector2(175, 54)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0.10, 0.12, 0.16, 0.70)
			style.set_border_width_all(1)
			style.border_color = Color(1, 1, 1, 0.18)
			btn.custom_minimum_size = Vector2(140, 54)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))

		btn.add_theme_stylebox_override("normal", style)
		var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
		hover_style.bg_color = style.bg_color.lightened(0.10)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", hover_style)


func _update_action_button() -> void:
	var accent: Color = BOOK_ACCENTS[selected_index]
	var grade: String = BOOK_GRADES[selected_index]
	action_button.text = "ورود به کتاب %s (%s)  ←" % [BOOK_TITLES[selected_index], grade]
	action_button.add_theme_font_override("font", MenuStyle.vazir())
	action_button.add_theme_font_size_override("font_size", 30)
	action_button.add_theme_color_override("font_color", Color.WHITE)
	action_button.add_theme_color_override("font_hover_color", Color.WHITE)
	action_button.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.92, 1.0))
	action_button.add_theme_color_override("font_focus_color", Color.WHITE)

	var radius: int = 26
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.35)
	style.shadow_size = 14
	style.shadow_color = Color(accent.r * 0.3, accent.g * 0.3, accent.b * 0.3, 0.50)
	style.shadow_offset = Vector2(0, 6)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lightened(0.08)
	hover.shadow_size = 18

	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.08)
	pressed.shadow_size = 6

	action_button.add_theme_stylebox_override("normal", style)
	action_button.add_theme_stylebox_override("hover", hover)
	action_button.add_theme_stylebox_override("pressed", pressed)
	action_button.add_theme_stylebox_override("focus", hover)

	GlossSheenScript.attach(action_button, accent, float(radius))


# ============================================================
# BACKGROUND CROSSFADE
# ============================================================

func _show_background(book_id: int, animate: bool) -> void:
	if background_tween != null and background_tween.is_running():
		background_tween.kill()

	book_id = clampi(book_id, 0, 2)

	background_b.texture = BOOK_BLURRED_BACKGROUNDS[book_id]
	background_b.modulate.a = 0.0

	if not animate:
		background_a.texture = BOOK_BLURRED_BACKGROUNDS[book_id]
		background_a.modulate.a = 1.0
		background_b.modulate.a = 0.0
		return

	background_tween = create_tween()
	background_tween.set_parallel(true)
	background_tween.set_trans(Tween.TRANS_SINE)
	background_tween.set_ease(Tween.EASE_IN_OUT)

	background_tween.tween_property(background_b, "modulate:a", 1.0, 0.38)
	background_tween.tween_property(background_a, "modulate:a", 0.0, 0.38)

	await background_tween.finished

	if not is_inside_tree():
		return

	var prev: TextureRect = background_a
	background_a = background_b
	background_b = prev
	background_a.modulate.a = 1.0
	background_b.modulate.a = 0.0


# ============================================================
# OPEN THE SELECTED BOOK
# ============================================================

func _open_selected_book() -> void:
	if is_opening:
		return
	is_opening = true
	Sfx.click()

	BookSession.selected_book_id = selected_index
	Global.current_book = selected_index + 1

	var target_card: BookCard = cards[selected_index]

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SPRING)
	tween.set_ease(Tween.EASE_OUT)

	# Grand entrance: Center book expands smoothly
	tween.tween_property(target_card, "scale", target_card.scale * 1.15, 0.35)
	tween.tween_property(target_card, "modulate:a", 0.0, 0.35)

	# Side cards and UI fade out rapidly
	for i in range(3):
		if i != selected_index:
			tween.tween_property(cards[i], "modulate:a", 0.0, 0.20)

	var header_area := get_node_or_null("HeaderArea") as Control
	if header_area:
		tween.tween_property(header_area, "modulate:a", 0.0, 0.20)
	var bottom_controls := get_node_or_null("BottomControls") as Control
	if bottom_controls:
		tween.tween_property(bottom_controls, "modulate:a", 0.0, 0.20)

	await tween.finished

	if not is_inside_tree():
		return

	TransitionManager.handover_scene(
		BOOK_CONTENTS_SCENE, BOOK_BLURRED_BACKGROUNDS[selected_index]
	)
