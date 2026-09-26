class_name TilePreview
extends Control
## ============================================================
##  TILE PREVIEW — the carried copy of a letter (rule 2: every native
##  drag must hand the player something visible to hold).
##
##  STRUCTURE
##    TilePreview      (this node) — zero-sized anchor, no drawing
##      └── Visual     (TilePreviewVisual) — the candy block itself
##
##  WHY THE ROOT IS ZERO-SIZED: Godot places a drag preview somewhere
##  around the cursor, and the exact offset depends on how the engine
##  treats the preview's own rect. With a zero-sized root both readings
##  collapse to the same result, and the Visual — parked at -(size / 2)
##  inside the root — lands dead centre on the finger. Nothing has to
##  guess, and nothing shifts if the engine's placement changes.
## ============================================================

## The carried copy is inset a little, so the slot it will drop into
## stays readable under the finger.
const PREVIEW_SCALE := 0.92

@onready var _visual: TilePreviewVisual = $Visual


## Builds the carried copy for one letter. `tile_size` is the source
## tile's size.
func configure(letter_text: String, tile_color_index: int, tile_size: float) -> void:
	var visual := _resolve_visual()
	if visual == null:
		return
	visual.letter = letter_text
	visual.color_index = tile_color_index
	visual.set_tile_size(tile_size * PREVIEW_SCALE)


## The Visual may not be resolved yet while the caller is still inside
## the frame that built the preview, so fall back to a lookup instead of
## letting a null reference drop the letter out of the player's hand.
func _resolve_visual() -> TilePreviewVisual:
	if _visual != null and is_instance_valid(_visual):
		return _visual
	return get_node_or_null("Visual") as TilePreviewVisual
