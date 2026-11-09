extends Control
class_name BookCard

const ROUNDED_CORNER_SHADER: Shader = preload(
	"res://scenes/book_menu/book_card_rounded.gdshader"
)

const BOOK_ACCENTS: Array[Color] = [
	Color("#3B82F6"), # Vision 1: cosmic blue
	Color("#22C55E"), # Vision 2: lush green
	Color("#EF4444")  # Vision 3: sunset red
]

const BOOK_GRADE_NAMES: Array[String] = ["پایه دهم", "پایه یازدهم", "پایه دوازدهم"]

@export var book_id: int = 0
@export var corner_radius: float = 26.0

@onready var card_background: TextureRect = $CardBackground
@onready var grade_badge: Label = $TopBadge/Margin/GradeLabel
@onready var book_title: Label = $CenterContainer/TitleLabel
@onready var shadow_rect: Panel = $ShadowPanel

var _shader_mat: ShaderMaterial = null
var _pending_title: String = ""
var _pending_texture: Texture2D = null


func set_book_content(
	id: int,
	title: String,
	background_texture: Texture2D
) -> void:
	book_id = id
	_pending_title = title
	_pending_texture = background_texture
	_apply_content()


func _ready() -> void:
	custom_minimum_size = Vector2(640, 960)
	size = Vector2(640, 960)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in find_children("*", "Control", true, false):
		var ctrl: Control = child as Control
		if ctrl:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_shader()
	_apply_content()


func _setup_shader() -> void:
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = ROUNDED_CORNER_SHADER
	_shader_mat.set_shader_parameter("corner_radius", corner_radius)
	_shader_mat.set_shader_parameter("rect_size", size)
	card_background.material = _shader_mat
	resized.connect(_on_resized)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	if _shader_mat:
		_shader_mat.set_shader_parameter("rect_size", size)


func _apply_content() -> void:
	if not is_node_ready():
		return

	var idx: int = clampi(book_id, 0, BOOK_GRADE_NAMES.size() - 1)
	if book_title:
		book_title.text = _pending_title
	if grade_badge:
		grade_badge.text = BOOK_GRADE_NAMES[idx]
	if card_background and _pending_texture:
		card_background.texture = _pending_texture

	var accent: Color = BOOK_ACCENTS[idx]
	var badge_panel := get_node_or_null("TopBadge") as PanelContainer
	if badge_panel:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
		style.set_corner_radius_all(int(corner_radius * 0.65))
		style.set_border_width_all(1)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.75)
		badge_panel.add_theme_stylebox_override("panel", style)
