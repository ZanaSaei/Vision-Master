class_name ScrambledConfettiBurst
extends CPUParticles2D
## ============================================================
##  CONFETTI BURST — the celebration thrown when a word is spelled.
##
##  Every numeric setting of the fountain lives in the scene, so the shape of
##  the burst can be tuned without touching code. What CANNOT live in a scene
##  is built here: the particle is a white square drawn at runtime (no image
##  asset needed) and the two colour ramps are read from the palette, so a
##  burst thrown after a live theme toggle still matches the tiles it is
##  celebrating.
## ============================================================

const DOT_PX := 10

var _dot: Texture2D = null


func _ready() -> void:
	_dot = _make_dot()
	texture = _dot
	apply_theme()


## Fires one burst centred on `at`, in this node's parent space.
func burst(at: Vector2) -> void:
	position = at
	emitting = true


func apply_theme() -> void:
	color_initial_ramp = _tile_ramp()
	color_ramp = _fade_ramp()


## A solid little square stands in for a sprite: no image asset needed.
func _make_dot() -> Texture2D:
	var image: Image = null
	if ClassDB.class_has_method("Image", "create_empty"):
		image = Image.create_empty(DOT_PX, DOT_PX, false, Image.FORMAT_RGBA8)
	else:
		image = Image.create(DOT_PX, DOT_PX, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)


## Colours are picked per particle, so one burst reads as a mix of tile colours.
func _tile_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		ScrambledTheme.tile_color(0), ScrambledTheme.tile_color(1),
		ScrambledTheme.tile_color(2), ScrambledTheme.tile_color(3),
		ScrambledTheme.tile_color(7),
	])
	return ramp


## ...and they fade away as they fall.
func _fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
	])
	return ramp
