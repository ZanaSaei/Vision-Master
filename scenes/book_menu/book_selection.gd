extends Control


# ============================================================
# SCENES
# ============================================================

const BOOK_CARD_SCENE: PackedScene = preload(
	"res://scenes/book_menu/BookCard.tscn"
)

const BOOK_CONTENTS_SCENE: PackedScene = preload(
	"res://scenes/lesson_menu/LessonMenu.tscn"
)


# ============================================================
# BOOK DATA
# ============================================================

const BOOK_TITLES: Array[String] = [
	"ویژن ۱",
	"ویژن ۲",
	"ویژن ۳"
]

const BOOK_COVERS: Array[Texture2D] = [
	preload("res://assets/images/ui/book_scene/Vision1.png"),
	preload("res://assets/images/ui/book_scene/Vision2.png"),
	preload("res://assets/images/ui/book_scene/Vision3.png")
]

const BOOK_BLURRED_BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/images/ui/book_scene/Vision1_blur.png"),
	preload("res://assets/images/ui/book_scene/Vision2_blur.png"),
	preload("res://assets/images/ui/book_scene/Vision3_blur.png")
]

const BOOK_CLEAR_BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/images/ui/book_scene/Vision1.png"),
	preload("res://assets/images/ui/book_scene/Vision2.png"),
	preload("res://assets/images/ui/book_scene/Vision3.png")
]


# ============================================================
# ANIMATION SETTINGS
# ============================================================

const STACK_X_OFFSET: float = 60.0
const STACK_Y_OFFSET: float = 5.0

const SWIPE_DURATION: float = 0.28
const STACK_DURATION: float = 0.36
const BACKGROUND_DURATION: float = 0.50
const OPEN_DURATION: float = 0.30

const NAV_HEIGHT: float = 150.0
const TOP_SPACE: float = 80.0
const SCREEN_MARGIN: float = 16.0


# ============================================================
# SCENE REFERENCES
# ============================================================

@onready var background_a: TextureRect = $BackgroundA
@onready var background_b: TextureRect = $BackgroundB
@onready var card_stack: Control = $CardStack


# ============================================================
# STATE
# ============================================================

var cards: Array[BookCard] = []
var book_order: Array[int] = [0, 1, 2]

var is_animating: bool = false
var is_opening: bool = false

var background_tween: Tween

# Flickering drag hint (created at runtime, no scene edits needed).
var drag_hint_label: Label = null
var drag_hint_tween: Tween = null


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_configure_backgrounds()
	$SelectionPrompt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var selected_id: int = clampi(
		BookSession.selected_book_id,
		0,
		2
	)

	book_order = [
		selected_id,
		(selected_id + 1) % 3,
		(selected_id + 2) % 3
	]

	_create_cards()
	_create_drag_hint()

	if cards.size() != 3:
		push_error("BookSelection: Failed to create all three cards.")
		return

	get_viewport().size_changed.connect(_layout_cards)

	_layout_cards()
	_update_card_input()
	_update_drag_hint_visibility()

	_show_background(book_order[0], false)


# ============================================================
# BACKGROUND SETUP
# ============================================================

func _configure_backgrounds() -> void:
	for bg in [background_a, background_b]:
		bg.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	background_a.modulate.a = 1.0
	background_b.modulate.a = 0.0


# ============================================================
# CREATE THE MANUALLY DESIGNED CARDS
# ============================================================

func _create_cards() -> void:
	for book_id in range(3):
		var card := BOOK_CARD_SCENE.instantiate() as BookCard

		if card == null:
			push_error(
				"BookSelection: BookCard.tscn must use BookCard.gd."
			)
			return

		card.book_id = book_id

		card_stack.add_child(card)

		# Feed the per-book data so the labels reflect the book
		# that the card is currently showing.
		card.set_book_content(
			book_id,
			BOOK_TITLES[book_id],
			BOOK_COVERS[book_id]
		)

		card.swipe_committed.connect(_on_swipe_committed)
		card.swipe_cancelled.connect(_on_swipe_cancelled)
		card.card_pressed.connect(_on_card_pressed)

		cards.append(card)


# ============================================================
# DRAG HINT  ("کارت را بکشید")
# ============================================================

func _create_drag_hint() -> void:
	drag_hint_label = Label.new()
	drag_hint_label.text = "کارت را بکشید"

	drag_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drag_hint_label.text_direction = Control.TEXT_DIRECTION_RTL
	drag_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	drag_hint_label.add_theme_font_size_override("font_size", 22)
	drag_hint_label.add_theme_color_override(
		"font_color", Color(1, 1, 1, 0.92)
	)
	drag_hint_label.add_theme_color_override(
		"font_shadow_color", Color(0, 0, 0, 0.75)
	)
	drag_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	drag_hint_label.add_theme_constant_override("shadow_offset_y", 2)

	# Draw above the card stack so it is always readable.
	add_child(drag_hint_label)
	move_child(drag_hint_label, get_child_count() - 1)

	_start_drag_hint_flicker()


func _start_drag_hint_flicker() -> void:
	if drag_hint_label == null:
		return

	if drag_hint_tween != null and drag_hint_tween.is_valid():
		drag_hint_tween.kill()

	drag_hint_label.modulate.a = 1.0

	drag_hint_tween = create_tween().set_loops()
	drag_hint_tween.set_trans(Tween.TRANS_SINE)
	drag_hint_tween.set_ease(Tween.EASE_IN_OUT)

	drag_hint_tween.tween_property(
		drag_hint_label, "modulate:a", 0.15, 0.75
	)
	drag_hint_tween.tween_property(
		drag_hint_label, "modulate:a", 1.0, 0.75
	)


func _update_drag_hint_position() -> void:
	if drag_hint_label == null or cards.is_empty():
		return

	var top_card: BookCard = cards[book_order[0]]

	# Account for the scale/pivot so the label sits visually
	# just below the top card.
	var visual_pos: Vector2 = (
		top_card.position
		+ top_card.pivot_offset
		- top_card.pivot_offset * top_card.scale
	)
	var visual_size: Vector2 = top_card.size * top_card.scale

	drag_hint_label.position = Vector2(
		visual_pos.x,
		visual_pos.y + visual_size.y + 12.0
	)
	drag_hint_label.size = Vector2(visual_size.x, 40.0)


func _update_drag_hint_visibility() -> void:
	if drag_hint_label == null:
		return

	var should_show: bool = not is_animating and not is_opening

	drag_hint_label.visible = should_show

	if should_show:
		if drag_hint_tween == null or not drag_hint_tween.is_valid():
			_start_drag_hint_flicker()
		elif not drag_hint_tween.is_running():
			_start_drag_hint_flicker()


# ============================================================
# RESPONSIVE CARD POSITIONING
# ============================================================

func _get_card_base_scale() -> float:
	if cards.is_empty():
		return 1.0

	var viewport_size: Vector2 = get_viewport_rect().size
	var card_size: Vector2 = cards[0].size

	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return 1.0

	var available_width: float = maxf(
		1.0,
		viewport_size.x
			- SCREEN_MARGIN * 2.0
			- STACK_X_OFFSET * 2.0
	)

	var available_height: float = maxf(
		1.0,
		viewport_size.y - NAV_HEIGHT - TOP_SPACE
	)

	var width_scale: float = available_width / card_size.x
	var height_scale: float = available_height / card_size.y

	return minf(1.0, minf(width_scale, height_scale))


func _get_stack_base_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var card_size: Vector2 = cards[0].size

	var base_x: float = (
		viewport_size.x - card_size.x
	) * 0.5 - STACK_X_OFFSET

	var available_height: float = (
		viewport_size.y - NAV_HEIGHT - TOP_SPACE
	)

	var base_y: float = TOP_SPACE + (
		available_height - card_size.y
	) * 0.5 - STACK_Y_OFFSET

	return Vector2(base_x, base_y)


func _layout_cards() -> void:
	if cards.size() != 3:
		return

	var card_size: Vector2 = cards[0].size

	if card_size.x <= 0.0 or card_size.y <= 0.0:
		push_error(
			"Set the BookCard root's actual Size in the Inspector."
		)
		return

	var base_position: Vector2 = _get_stack_base_position()
	var base_scale: float = _get_card_base_scale()

	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]
		var card: BookCard = cards[book_id]

		card.pivot_offset = card.size * 0.5

		card.position = base_position + Vector2(
			depth * STACK_X_OFFSET,
			depth * STACK_Y_OFFSET
		)

		card.scale = Vector2.ONE * (
			base_scale * (1.0 - depth * 0.035)
		)

		card.rotation = 0.0
		card.z_index = 10 - depth

	_update_card_input()
	_update_drag_hint_position()


# ============================================================
# INPUT MANAGEMENT
# ============================================================

func _update_card_input() -> void:
	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]

		cards[book_id].set_input_enabled(
			depth == 0
			and not is_animating
			and not is_opening
		)


# ============================================================
# SWIPE A CARD AWAY
# ============================================================

func _on_swipe_committed(
	card: BookCard,
	direction: int
) -> void:
	if is_animating or is_opening:
		return

	if book_order[0] != card.book_id:
		return

	is_animating = true
	_update_card_input()
	_update_drag_hint_visibility()

	# Start the background crossfade as the swipe begins, not after the
	# outgoing card has left the screen. This keeps both transitions in sync.
	var next_book_id: int = book_order[1]
	_show_background(next_book_id, true)

	var viewport_width: float = get_viewport_rect().size.x

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		card,
		"position:x",
		card.position.x + direction * viewport_width * 1.25,
		SWIPE_DURATION
	)

	tween.tween_property(
		card,
		"rotation",
		direction * 0.18,
		SWIPE_DURATION
	)

	tween.tween_property(
		card,
		"scale",
		card.scale * 0.90,
		SWIPE_DURATION
	)

	await tween.finished

	if not is_inside_tree():
		return

	var previous_front: int = book_order.pop_front()
	book_order.append(previous_front)

	await _animate_stack()

	if background_tween != null and background_tween.is_running():
		await background_tween.finished

	if not is_inside_tree():
		return

	is_animating = false
	_update_card_input()
	_update_drag_hint_position()
	_update_drag_hint_visibility()


# ============================================================
# CANCEL A SHORT DRAG
# ============================================================

func _on_swipe_cancelled(card: BookCard) -> void:
	if is_animating or is_opening:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		card,
		"position",
		card.start_position,
		0.25
	)

	tween.tween_property(
		card,
		"rotation",
		0.0,
		0.25
	)


# ============================================================
# RESTACK CARDS SMOOTHLY
# ============================================================

func _animate_stack() -> void:
	var base_position: Vector2 = _get_stack_base_position()
	var base_scale: float = _get_card_base_scale()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]
		var card: BookCard = cards[book_id]

		card.z_index = 10 - depth

		var target_position: Vector2 = base_position + Vector2(
			depth * STACK_X_OFFSET,
			depth * STACK_Y_OFFSET
		)

		var target_scale: Vector2 = Vector2.ONE * (
			base_scale * (1.0 - depth * 0.035)
		)

		tween.tween_property(
			card,
			"position",
			target_position,
			STACK_DURATION
		)

		tween.tween_property(
			card,
			"scale",
			target_scale,
			STACK_DURATION
		)

		tween.tween_property(
			card,
			"rotation",
			0.0,
			STACK_DURATION
		)

	await tween.finished


# ============================================================
# SMOOTH FULL-SCREEN BACKGROUND CROSSFADE
# ============================================================

func _show_background(
	book_id: int,
	animate: bool
) -> void:
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

	# Crossfade both layers together. Fading only the incoming layer over the
	# old one makes the change feel abrupt when the covers differ strongly.
	background_tween.tween_property(
		background_b,
		"modulate:a",
		1.0,
		BACKGROUND_DURATION
	)
	background_tween.tween_property(
		background_a,
		"modulate:a",
		0.0,
		BACKGROUND_DURATION
	)

	await background_tween.finished

	if not is_inside_tree():
		return

	var previous_background: TextureRect = background_a
	background_a = background_b
	background_b = previous_background

	background_a.modulate.a = 1.0
	background_b.modulate.a = 0.0


# ============================================================
# OPEN THE SELECTED BOOK
# ============================================================

func _on_card_pressed(card: BookCard) -> void:
	if is_animating or is_opening:
		return

	if book_order[0] != card.book_id:
		return

	is_opening = true
	is_animating = true
	_update_card_input()
	_update_drag_hint_visibility()

	BookSession.selected_book_id = card.book_id

	Global.current_book = card.book_id + 1
	Global.current_lesson = 1

	var viewport_width: float = get_viewport_rect().size.x

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]
		var current_card: BookCard = cards[book_id]

		var direction: float = (
			-1.0 if depth % 2 == 0 else 1.0
		)

		var duration: float = (
			OPEN_DURATION + float(depth) * 0.06
		)

		tween.tween_property(
			current_card,
			"position:x",
			current_card.position.x
				+ direction * viewport_width * 1.2,
			duration
		)

		tween.tween_property(
			current_card,
			"modulate:a",
			0.0,
			duration
		)

	background_b.texture = BOOK_CLEAR_BACKGROUNDS[card.book_id]
	background_b.modulate.a = 0.0

	# The clear background replaces the blurred one; fade the blurred layer
	# away at the same time to avoid a sudden brightness/contrast shift.
	tween.tween_property(
		background_b,
		"modulate:a",
		1.0,
		0.48
	)
	tween.tween_property(
		background_a,
		"modulate:a",
		0.0,
		0.48
	)

	await tween.finished

	if not is_inside_tree():
		return

	get_tree().change_scene_to_packed(BOOK_CONTENTS_SCENE)
