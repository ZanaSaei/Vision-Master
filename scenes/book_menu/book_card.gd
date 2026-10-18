extends Control
class_name BookCard

signal swipe_committed(card: BookCard, direction: int)
signal swipe_cancelled(card: BookCard)
signal card_pressed(card: BookCard)

const ROUNDED_CORNER_SHADER: Shader = preload(
	"res://scenes/book_menu/book_card_rounded.gdshader"
)

const BOOK_TAB_COLORS: Array[Color] = [
	Color("#174982"), # Vision 1: deep cosmic blue
	Color("#08745c"), # Vision 2: lush green
	Color("#a84427")  # Vision 3: warm sunset orange
]
const BOOK_TAB_TEXT_COLOR: Color = Color("#fff4dc")
const BOOK_GRADE_NAMES: Array[String] = ["دهم", "یازدهم", "دوازدهم"]

@export var book_id: int = 0
@export var corner_radius: float = 25.0

@onready var card_background: TextureRect = $Content/ContentPanel/CardBackground
@onready var book_title: Label = $Content/ContentPanel/MarginContainer/BookTitle
@onready var book_number: Label = $Content/ContentPanel/MarginContainer/BookNumber
@onready var book_tab: PanelContainer = $BookTab
@onready var tab_label: Label = $BookTab/TabLabel

var input_enabled: bool = false
var is_dragging: bool = false
var start_position: Vector2 = Vector2.ZERO
var drag_distance_x: float = 0.0
var has_dragged: bool = false

# Buffered content – applied on _ready or on set_book_content().
var _pending_title: String = ""
var _pending_background: Texture2D = null
var _background_shader_mat: ShaderMaterial = null


# ============================================================
# CONTENT
# ============================================================

func set_book_content(
	id: int,
	title: String,
	background_texture: Texture2D
) -> void:
	book_id = id
	_pending_title = title
	_pending_background = background_texture
	_apply_content()


func set_card_background(texture: Texture2D) -> void:
	_pending_background = texture
	if is_node_ready():
		card_background.texture = texture


func _apply_content() -> void:
	if not is_node_ready():
		return

	book_title.text = _pending_title
	tab_label.text = _pending_title
	var grade_index: int = clampi(book_id, 0, BOOK_GRADE_NAMES.size() - 1)
	book_number.text = BOOK_GRADE_NAMES[grade_index]
	_apply_book_tab_theme()

	if _pending_background != null:
		card_background.texture = _pending_background


func _apply_book_tab_theme() -> void:
	var color_index: int = clampi(book_id, 0, BOOK_TAB_COLORS.size() - 1)
	var tab_style: StyleBoxFlat = StyleBoxFlat.new()
	tab_style.bg_color = BOOK_TAB_COLORS[color_index]
	tab_style.corner_radius_top_right = 25
	tab_style.corner_radius_bottom_right = 25
	book_tab.add_theme_stylebox_override("panel", tab_style)
	tab_label.add_theme_color_override("font_color", BOOK_TAB_TEXT_COLOR)


# ============================================================
# INPUT
# ============================================================

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)


func _ready() -> void:
	# The card itself owns pointer input. Visual descendants (labels, panels,
	# and texture rects) must not stop GUI events before they bubble to it.
	for child_node: Node in find_children("*", "Control", true, false):
		var child_control: Control = child_node as Control
		child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_background_shader()
	_apply_content()


# ============================================================
# ROUNDED BACKGROUND (top-left + bottom-left only)
# ============================================================

func _setup_background_shader() -> void:
	_background_shader_mat = ShaderMaterial.new()
	_background_shader_mat.shader = ROUNDED_CORNER_SHADER
	_background_shader_mat.set_shader_parameter(
		"corner_radius", corner_radius
	)
	card_background.material = _background_shader_mat

	_update_shader_size()
	card_background.resized.connect(_update_shader_size)


func _update_shader_size() -> void:
	if _background_shader_mat == null:
		return
	_background_shader_mat.set_shader_parameter(
		"rect_size", card_background.size
	)


# ============================================================
# INPUT HANDLING
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_drag()
			accept_event()

	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag()
		accept_event()


func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_update_drag(motion_event.relative.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		_update_drag(drag_event.relative.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()


func _begin_drag() -> void:
	if is_dragging:
		return

	is_dragging = true
	has_dragged = false
	drag_distance_x = 0.0
	start_position = position


func _update_drag(delta_x: float) -> void:
	drag_distance_x += delta_x

	if absf(drag_distance_x) > 8.0:
		has_dragged = true

	position.x = start_position.x + drag_distance_x


func _finish_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false

	if not has_dragged:
		position = start_position
		card_pressed.emit(self)
		return

	var threshold: float = size.x * 0.15

	if absf(drag_distance_x) >= threshold:
		swipe_committed.emit(
			self,
			1 if drag_distance_x > 0.0 else -1
		)
	else:
		swipe_cancelled.emit(self)
