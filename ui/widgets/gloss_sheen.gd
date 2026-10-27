class_name GlossSheen
extends Control
## ============================================================
##  GLOSS SHEEN — the shiny coating of a glossy menu button.
##
##  A mouse-transparent overlay that lives INSIDE a card button: the button
##  keeps painting its own normal / hover / pressed styleboxes (and their
##  shadows) and this node adds the shine on top of the face — a tinted glass
##  wash, a specular band, a diagonal streak and an inner rim light, all drawn
##  by gloss_sheen.gdshader.
##
##  The shader measures the card in pixels, so the node keeps `rect_size` in
##  sync on every resize, exactly like GradientCardRect does for GradientCard.
##
##  `attach()` is the whole public entry point: it puts the coating on a card
##  button and teaches that button's hover / press to answer with it. Calling it
##  again (a theme change, a restyle) reuses the existing overlay instead of
##  stacking a second one.
## ============================================================

const SHADER := preload("res://ui/widgets/gloss_sheen.gdshader")

## Node name of the overlay inside a card, so a caller can find it again.
const NODE_NAME := "Gloss"

## Interaction states for the shine: brighter on hover, flattened while pressed.
const SHEEN_REST := 0.0
const SHEEN_HOVER := 1.0
const SHEEN_PRESSED := -0.85
## How quickly the shine answers a hover / press.
const SHEEN_TIME := 0.16

## Current gloss state; setting it pushes the value into the shader, so a tween
## on this property animates the shine.
var sheen: float = SHEEN_REST:
	set(value):
		sheen = value
		if _mat != null:
			_mat.set_shader_parameter("sheen", value)
		queue_redraw()

var _mat: ShaderMaterial = null


func _init() -> void:
	name = NODE_NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat


func _ready() -> void:
	resized.connect(_sync_size)
	_sync_size()


## Colours the whole sheen with the card's section accent.
func set_tint(colour: Color) -> void:
	_mat.set_shader_parameter("tint", colour)


## Matches the shine's rounded mask to the card's corner radius.
func set_radius(px: float) -> void:
	_mat.set_shader_parameter("corner_radius", px)


## Tweens the shine to one of SHEEN_REST / SHEEN_HOVER / SHEEN_PRESSED.
func animate_sheen(state: float) -> void:
	if not is_inside_tree():
		sheen = state
		return
	create_tween().tween_property(self, "sheen", state, SHEEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Adds (or refreshes) the glossy coating on a card button and returns it.
## `radius` must be the card's own corner radius so the shine stops exactly at
## the rounded edge.
static func attach(card: Button, accent_col: Color, radius: float = 26.0) -> GlossSheen:
	var gloss := card.get_node_or_null(NODE_NAME) as GlossSheen
	if gloss == null:
		gloss = GlossSheen.new()
		card.add_child(gloss)
		# Draw the shine over the card's face but under its content (the card's
		# icon chip, title and arrow).
		card.move_child(gloss, 0)
		_wire(card, gloss)
	gloss.set_tint(accent_col)
	gloss.set_radius(radius)
	return gloss


## Hover brightens the shine, a press flattens it, releasing the press returns
## to hover (mouse still over the card) or to rest.
static func _wire(card: Button, gloss: GlossSheen) -> void:
	if card.has_meta("gloss_sheen_wired"):
		return
	card.set_meta("gloss_sheen_wired", true)
	card.mouse_entered.connect(func() -> void: gloss.animate_sheen(SHEEN_HOVER))
	card.mouse_exited.connect(func() -> void: gloss.animate_sheen(SHEEN_REST))
	card.button_down.connect(func() -> void: gloss.animate_sheen(SHEEN_PRESSED))
	card.button_up.connect(func() -> void:
		gloss.animate_sheen(SHEEN_HOVER if card.is_hovered() else SHEEN_REST))


## A material only runs over DRAW COMMANDS, and a bare Control issues none — so
## this white rect is the canvas the sheen shader paints on. Its colour is
## irrelevant: the shader replaces COLOR entirely.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


func _sync_size() -> void:
	_mat.set_shader_parameter("rect_size", size)
	queue_redraw()
