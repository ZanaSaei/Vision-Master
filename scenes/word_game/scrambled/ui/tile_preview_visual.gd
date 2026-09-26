class_name TilePreviewVisual
extends Control
## ============================================================
##  TILE PREVIEW VISUAL — the drawn half of the drag preview.
##
##  Lives as the "Visual" child of TilePreview.tscn. It sits at
##  -(size/2) inside its zero-sized parent, so the block is centred on
##  the cursor no matter which offset convention Godot's drag layer
##  uses for the preview root.
##
##  Why it is a separate node from ScrambledTile: a preview is a
##  *snapshot* of a letter, not a live tile. It must never join the
##  board's slot bookkeeping or answer input, so it carries no drag
##  state — it only knows how to draw one candy block.
## ============================================================

## Same proportions as ScrambledTile, so the carried copy reads as the
## very same object the player picked up.
const CORNER_RATIO := 0.34
const OUTLINE_RATIO := 0.085
const SIDE_RATIO := 0.16
const LETTER_RATIO := 0.62
const MIN_LETTER_SIZE := 18

## The preview floats: a stronger shadow than any resting tile, so it
## reads as "held above the board" rather than "dropped on it".
const PREVIEW_SHADOW_ALPHA := 0.35
const PREVIEW_SHADOW_SIZE := 28
const PREVIEW_SHADOW_OFFSET := Vector2(0.0, 22.0)
const PREVIEW_GLOSS_ALPHA := 0.25

var letter := ""
var color_index := 0
## Slightly transparent so the slot the letter will land in stays visible
## underneath the carried copy.
var _tint := Color(1.0, 1.0, 1.0, 0.94)

var _style := StyleBoxFlat.new()


func _ready() -> void:
	# The preview must never eat the mouse: the Viewport needs the pointer
	# to keep resolving the real drop target underneath it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


## Sizes the block and centres it on the parent's origin.
func set_tile_size(px: float) -> void:
	var side_px := maxf(px, 32.0)
	size = Vector2(side_px, side_px)
	position = -size * 0.5
	modulate = _tint
	_refresh()


func _refresh() -> void:
	if size.x <= 0.0:
		return
	_style.set_corner_radius_all(int(maxf(8.0, size.x * CORNER_RATIO)))
	_style.set_border_width_all(0)
	_style.bg_color = ScrambledTheme.TILE_OUTLINE
	_style.shadow_color = Color(0.10, 0.06, 0.20, PREVIEW_SHADOW_ALPHA)
	_style.shadow_size = PREVIEW_SHADOW_SIZE
	_style.shadow_offset = PREVIEW_SHADOW_OFFSET
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var body := ScrambledTheme.tile_color(color_index)
	var radius := maxf(8.0, size.x * CORNER_RATIO)
	var outline := maxf(2.0, size.x * OUTLINE_RATIO)
	var side := maxf(4.0, size.x * SIDE_RATIO)
	var inner := size - Vector2(outline * 2.0, outline * 2.0)
	if inner.x <= 0.0 or inner.y - side <= 0.0:
		return

	# 1. Dark outline, 2. extruded bottom edge, 3. candy face, 4. gloss —
	#    the exact stack ScrambledTile draws.
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	draw_style_box(_slab_style(ScrambledTheme.tile_side(body), radius),
		Rect2(Vector2(outline, outline), inner))
	draw_style_box(_slab_style(body, radius),
		Rect2(Vector2(outline, outline), Vector2(inner.x, inner.y - side)))
	var gloss_height := maxf(4.0, (inner.y - side) * 0.30)
	draw_style_box(_slab_style(Color(1, 1, 1, PREVIEW_GLOSS_ALPHA), int(radius * 0.7)),
		Rect2(Vector2(outline + radius * 0.28, outline + radius * 0.20),
			Vector2(inner.x - radius * 0.56, gloss_height)))

	if letter.is_empty():
		return
	var font := MenuStyle.nunito()
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	var letter_size := int(maxf(float(MIN_LETTER_SIZE), size.x * LETTER_RATIO))
	var face_center := outline + (inner.y - side) * 0.5
	var ascent := font.get_ascent(letter_size)
	var descent := font.get_descent(letter_size)
	var baseline := face_center + (ascent - descent) * 0.5
	draw_string(font, Vector2(0.0, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, letter_size, ScrambledTheme.tile_letter(body))


func _slab_style(color: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(radius))
	style.set_border_width_all(0)
	style.bg_color = color
	return style
