
extends Control
class_name BookCard

signal drag_started(card: BookCard)
signal drag_updated(card: BookCard, delta_x: float)
signal swipe_committed(card: BookCard, direction: int)
signal swipe_cancelled(card: BookCard)
signal card_pressed(card: BookCard)

@onready var cover: TextureRect = $Cover
@onready var shade: ColorRect = $Shade
@onready var book_title: Label = $BookTitle
@onready var book_number: Label = $BookNumber
@onready var swipe_hint: Label = $SwipeHint
@onready var book_tab: Panel = $BookTab
@onready var tab_label: Label = $BookTab/TabLabel

var book_id: int = 0
var book_name: String = ""
var accent_color: Color = Color("#2769C5")

var body_size: Vector2 = Vector2(480.0, 760.0)
var tab_width: float = 40.0
var tab_offset: float = 0.0

var input_enabled: bool = false
var is_dragging: bool = false
var press_position: Vector2 = Vector2.ZERO
var total_drag_x: float = 0.0
var moved_enough: bool = false


func _ready() -> void:
	# Cards are positioned and sized explicitly by BookSelection. The scene
	# template's full-rect anchors otherwise override those dimensions every frame.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2.ZERO
	_layout_card()


func configure(
	id: int,
	title: String,
	cover_texture: Texture2D,
	accent: Color,
	card_body_size: Vector2,
	new_tab_width: float
) -> void:
	book_id = id
	book_name = title
	accent_color = accent
	body_size = card_body_size
	tab_width = new_tab_width

	size = Vector2(
	body_size.x + tab_width + tab_offset,
	body_size.y
)

	_apply_content(cover_texture)
	_layout_card()


func set_tab_offset(offset: float) -> void:
	tab_offset = offset
	_layout_card()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)


func _apply_content(texture: Texture2D) -> void:
	cover.texture = texture
	book_title.text = book_name
	book_number.text = "BOOK %02d" % (book_id + 1)
	tab_label.text = book_name

	var style := StyleBoxFlat.new()
	style.bg_color = accent_color
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	book_tab.add_theme_stylebox_override("panel", style)


func _layout_card() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(
		body_size.x + tab_width + tab_offset,
		body_size.y
	)

	cover.position = Vector2.ZERO
	cover.size = body_size

	shade.position = Vector2.ZERO
	shade.size = body_size
	shade.color = Color(0.0, 0.0, 0.0, 0.30)

	book_title.position = Vector2(
		24.0,
		body_size.y * 0.25
	)
	book_title.size = Vector2(body_size.x - 48.0, 110.0)
	book_title.add_theme_font_size_override("font_size", 42)
	book_title.add_theme_color_override(
		"font_color", Color.WHITE
	)

	book_number.position = Vector2(
		24.0,
		body_size.y * 0.19
	)
	book_number.size = Vector2(body_size.x - 48.0, 36.0)
	book_number.add_theme_font_size_override("font_size", 18)
	book_number.add_theme_color_override(
		"font_color", Color(1.0, 1.0, 1.0, 0.85)
	)

	swipe_hint.position = Vector2(
		24.0,
		body_size.y * 0.82
	)
	swipe_hint.size = Vector2(body_size.x - 48.0, 40.0)
	swipe_hint.text = "SWIPE TO EXPLORE"
	swipe_hint.add_theme_font_size_override("font_size", 16)
	swipe_hint.add_theme_color_override(
		"font_color", Color(1.0, 1.0, 1.0, 0.85)
	)

	book_tab.position = Vector2(
		body_size.x + tab_offset,
		0.0
	)
	book_tab.size = Vector2(tab_width, body_size.y)

	# Rotation is around the label's center.
	tab_label.rotation = deg_to_rad(90.0)
	tab_label.size = Vector2(body_size.y, tab_width)
	tab_label.position = Vector2(
		(tab_width - body_size.y) * 0.5,
		(body_size.y - tab_width) * 0.5
	)
	tab_label.add_theme_font_size_override("font_size", 17)
	tab_label.add_theme_color_override(
		"font_color", Color.WHITE
	)
	tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag()
			else:
				_end_drag()
			accept_event()

	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag()
		else:
			_end_drag()
		accept_event()

	elif event is InputEventMouseMotion and is_dragging:
		_update_drag(event.relative.x)
		accept_event()

	elif event is InputEventScreenDrag and is_dragging:
		_update_drag(event.relative.x)
		accept_event()


func _begin_drag() -> void:
	if is_dragging:
		return

	is_dragging = true
	moved_enough = false
	total_drag_x = 0.0
	press_position = position
	drag_started.emit(self)


func _update_drag(delta_x: float) -> void:
	if not is_dragging:
		return

	total_drag_x += delta_x

	if absf(total_drag_x) > 8.0:
		moved_enough = true

	position.x = press_position.x + total_drag_x

	var drag_ratio := clampf(
		total_drag_x / maxf(body_size.x, 1.0),
		-1.0,
		1.0
	)
	rotation = drag_ratio * 0.10

	drag_updated.emit(self, total_drag_x)


func _end_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false

	if absf(total_drag_x) < 12.0 and not moved_enough:
		position = press_position
		rotation = 0.0
		card_pressed.emit(self)
		return

	var threshold := body_size.x * 0.15

	if absf(total_drag_x) >= threshold:
		swipe_committed.emit(
			self,
			1 if total_drag_x > 0.0 else -1
		)
	else:
		swipe_cancelled.emit(self)
