
extends Control

const BOOK_CARD_SCENE: PackedScene = preload(
    "res://scenes/book_menu/BookCard.tscn"
	
)
const BOOK_CONTENTS_SCENE: PackedScene = preload(
    "res://scenes/lesson_menu/LessonMenu.tscn"
	
)

const BOOK_NAMES: Array[String] = [
	"Vision 1",
	"Vision 2",
    "Vision 3"
]

const BOOK_COLORS: Array[Color] = [
	Color("#2769C5"),
	Color("#29965B"),
	Color("#E45A61")
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

const STACK_X_OFFSET: float = 12.0
const STACK_Y_OFFSET: float = 5.0
const TAB_X_OFFSET: float = 30.0

const SWIPE_DURATION: float = 0.28
const STACK_DURATION: float = 0.36
const BACKGROUND_DURATION: float = 0.50
const OPEN_DURATION: float = 0.30

@onready var background_a: TextureRect = $BackgroundA
@onready var background_b: TextureRect = $BackgroundB
@onready var background_tint: ColorRect = $BackgroundTint
@onready var card_stack: Control = $CardStack

var cards: Array[BookCard] = []
var book_order: Array[int] = [0, 1, 2]

var body_size: Vector2 = Vector2.ZERO
var tab_width: float = 40.0

var is_animating: bool = false
var is_opening: bool = false
var background_tween: Tween


func _ready() -> void:
	_configure_backgrounds()

	get_viewport().size_changed.connect(_layout_cards)

	_create_cards()
	_layout_cards()

	_update_card_input()
	_show_background(0, false)


func _configure_backgrounds() -> void:
	for bg in [background_a, background_b]:
		bg.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	background_tint.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_tint.color = Color(0.02, 0.04, 0.10, 0.20)

	background_a.modulate.a = 1.0
	background_b.modulate.a = 0.0


func _create_cards() -> void:
	for i in range(3):
		var card := BOOK_CARD_SCENE.instantiate() as BookCard
		card_stack.add_child(card)

		card.configure(
			i,
			BOOK_NAMES[i],
			BOOK_COVERS[i],
			BOOK_COLORS[i],
			Vector2(480.0, 760.0),
			tab_width
		)

		card.drag_started.connect(_on_drag_started)
		card.swipe_committed.connect(_on_swipe_committed)
		card.swipe_cancelled.connect(_on_swipe_cancelled)
		card.card_pressed.connect(_on_card_pressed)

		cards.append(card)


func _layout_cards() -> void:
	if cards.size() != 3:
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	# Reserve space for the bottom navigation and top safe area.
	var nav_height: float = 92.0
	var top_space: float = 100.0
	var available_height: float = maxf(
		300.0,
		viewport_size.y - nav_height - top_space
	)

	body_size.y = minf(
		available_height * 0.82,
		viewport_size.y * 0.68
	)

	body_size.x = minf(
		viewport_size.x * 0.70,
		body_size.y * 0.68
	)

	# Keep the body large enough to display a title.
	body_size.x = maxf(260.0, body_size.x)

	var max_stack_width: float = (
		body_size.x + tab_width + 2.0 * TAB_X_OFFSET
	)

	var base_x: float = (
		viewport_size.x - max_stack_width
	) * 0.5

	var usable_height: float = (
		viewport_size.y - nav_height - top_space
	)
	var base_y: float = top_space + (
		usable_height - body_size.y
	) * 0.5

	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]
		var card: BookCard = cards[book_id]

		card.body_size = body_size
		card.tab_width = tab_width
		card.set_tab_offset(float(depth) * TAB_X_OFFSET)
		card._layout_card()

		card.position = Vector2(
			base_x + float(depth) * STACK_X_OFFSET,
			base_y + float(depth) * STACK_Y_OFFSET
		)

		card.scale = Vector2.ONE * (
			1.0 - float(depth) * 0.035
		)
		card.rotation = 0.0

		# Front card is drawn above the two cards behind it.
		card.z_index = 10 - depth

	_update_card_input()


func _update_card_input() -> void:
	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]
		cards[book_id].set_input_enabled(
			depth == 0 and not is_animating and not is_opening
		)


func _on_drag_started(_card: BookCard) -> void:
	if is_animating or is_opening:
		return


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
		direction * 0.24,
		SWIPE_DURATION
	)
	tween.tween_property(
		card,
		"scale",
		Vector2.ONE * 0.90,
		SWIPE_DURATION
	)

	await tween.finished

	if not is_inside_tree():
		return

	# Move the old front card to the end of the order.
	var previous_front: int = book_order.pop_front()
	book_order.append(previous_front)

	# Update the blurred background for the new front book.
	_show_background(book_order[0], true)

	# Re-stack the cards with a smooth animation.
	await _animate_stack()

	is_animating = false
	_update_card_input()


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
		card.press_position,
		0.25
	)
	tween.tween_property(
		card,
		"rotation",
		0.0,
		0.25
	)


func _animate_stack() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var nav_height: float = 92.0
	var top_space: float = 100.0

	var usable_height: float = (
		viewport_size.y - nav_height - top_space
	)
	var base_y: float = top_space + (
		usable_height - body_size.y
	) * 0.5

	var max_stack_width: float = (
		body_size.x + tab_width + 2.0 * TAB_X_OFFSET
	)
	var base_x: float = (
		viewport_size.x - max_stack_width
	) * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	for depth in range(book_order.size()):
		var book_id: int = book_order[depth]
		var card: BookCard = cards[book_id]

		card.z_index = 10 - depth
		card.set_tab_offset(float(depth) * TAB_X_OFFSET)

		var target_position := Vector2(
			base_x + float(depth) * STACK_X_OFFSET,
			base_y + float(depth) * STACK_Y_OFFSET
		)

		var target_scale := Vector2.ONE * (
			1.0 - float(depth) * 0.035
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


func _show_background(book_id: int, animate: bool) -> void:
	if background_tween and background_tween.is_running():
		background_tween.kill()

	background_b.texture = BOOK_BLURRED_BACKGROUNDS[book_id]

	# Keep the incoming image above the outgoing image,
	# but below the tint, cards, and navigation.
	move_child(
		background_b,
		background_tint.get_index()
	)

	var next_modulate: Color = background_b.modulate
	next_modulate.a = 0.0
	background_b.modulate = next_modulate

	if not animate:
		background_a.texture = BOOK_BLURRED_BACKGROUNDS[book_id]
		background_a.modulate.a = 1.0
		background_b.modulate.a = 0.0
		return

	background_tween = create_tween()
	background_tween.set_trans(Tween.TRANS_SINE)
	background_tween.set_ease(Tween.EASE_IN_OUT)

	background_tween.tween_property(
		background_b,
		"modulate:a",
		1.0,
		BACKGROUND_DURATION
	)

	await background_tween.finished

	if not is_inside_tree():
		return

	# Promote the incoming image to the active layer.
	var previous_background: TextureRect = background_a
	background_a = background_b
	background_b = previous_background

	background_b.modulate.a = 0.0


func _on_card_pressed(card: BookCard) -> void:
	if is_animating or is_opening:
		return

	if book_order[0] != card.book_id:
		return

	is_opening = true
	is_animating = true
	_update_card_input()

	BookSession.selected_book_id = card.book_id
	# Book IDs in this picker are zero-based; the rest of the app uses 1-based IDs.
	Global.current_book = card.book_id + 1
	Global.current_lesson = 1

	var viewport_size: Vector2 = get_viewport_rect().size
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

		tween.tween_property(
			current_card,
			"position:x",
			current_card.position.x
				+ direction * viewport_size.x * 1.2,
			OPEN_DURATION + float(depth) * 0.06
		)
		tween.tween_property(
			current_card,
			"modulate:a",
			0.0,
			OPEN_DURATION + float(depth) * 0.06
		)

	# Reveal the selected book's clear background.
	background_b.texture = BOOK_CLEAR_BACKGROUNDS[card.book_id]
	background_b.modulate.a = 0.0
	
	# Keep the incoming image above the outgoing image,
	# but below the tint, cards, and navigation.
	move_child(
		background_b,
		background_tint.get_index()
	)
	
	tween.tween_property(
		background_b,
		"modulate:a",
		1.0,
		0.48
	)

	await tween.finished

	if not is_inside_tree():
		return

	get_tree().change_scene_to_packed(BOOK_CONTENTS_SCENE)
