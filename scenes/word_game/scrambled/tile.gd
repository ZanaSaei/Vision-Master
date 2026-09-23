class_name ScrambledTile
extends Control
## ============================================================
##  SCRAMBLED TILE — one draggable letter of «بازی املا».
##
##  WHY IT DRAWS ITSELF instead of being a Panel + Label: the app-wide theme
##  walk (ThemeService) restyles every Panel/PanelContainer/Label it finds.
##  Running over a board mid-puzzle it would erase the candy colours, the
##  solved green and the amber nudge, and repaint every letter in the theme
##  colour. A self-drawing Control is invisible to that walk, so a board
##  keeps its state and survives a live theme toggle. WordleTile solved the
##  same problem the same way.
##
##  A tile owns its look and reports what the finger does; the board owns
##  every position and every move animation.
## ============================================================

signal grabbed(tile: ScrambledTile, pointer_global: Vector2)
signal dragged(tile: ScrambledTile, pointer_global: Vector2)
signal released(tile: ScrambledTile)

enum State { IDLE, HELD, SOLVED, LOCKED }

## The look is copied from the reference tiles the game is styled after:
## a flat candy face, a darker extruded bottom edge (a chunky 3D block), a
## dark outline around the whole block and one big, very round white letter.
const CORNER_RATIO := 0.34
const OUTLINE_RATIO := 0.085
const SIDE_RATIO := 0.16          # extruded bottom edge, as a fraction of size
const LETTER_RATIO := 0.62
const MIN_LETTER_SIZE := 18
## Desktop hover feedback (touch never sees it).
const HOVER_SCALE := 1.05

var letter := ""
var color_index := 0
var slot_id := 0

var state: State = State.IDLE:
	set(value):
		state = value
		_refresh()

## 0..1 cartoon elevation. The board raises it while the tile is carried.
var lift := 0.0:
	set(value):
		lift = clampf(value, 0.0, 1.0)
		_refresh()

## 0..1 amber pulse of the "not quite right yet" nudge.
var nudge := 0.0:
	set(value):
		nudge = clampf(value, 0.0, 1.0)
		_refresh()

var _dragging := false
var _hovered := false
var _style := StyleBoxFlat.new()


func _ready() -> void:
	# The tile is a live control: it must catch the press that starts a drag.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	_refresh()


## Sizes the tile. Called by the board for every tile of the row.
func set_tile_size(px: float) -> void:
	var wanted := Vector2(maxf(px, 32.0), maxf(px, 32.0))
	if size == wanted:
		return
	size = wanted
	pivot_offset = size * 0.5
	_refresh()


## Paints the tile as a solved (green) letter, or takes the green away again.
func set_solved(value: bool) -> void:
	state = State.SOLVED if value else State.IDLE


func is_solved() -> bool:
	return state == State.SOLVED


## A locked tile takes no input: used while the row settles and when the word
## is finished.
func set_locked(value: bool) -> void:
	if value:
		state = State.LOCKED
		_dragging = false
	elif state == State.LOCKED:
		state = State.IDLE
## Pops the tile: the win wave, and the moment a word is dealt.
func play_pop(delay: float = 0.0, strength: float = 1.16) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_interval(maxf(delay, 0.0))
	tw.tween_property(self, "scale", Vector2(strength, strength), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A short, friendly wobble with an amber flash: "that letter sits wrong",
## never "you failed" — and it never reveals the answer.
func play_nudge() -> void:
	var tw := create_tween()
	tw.tween_property(self, "nudge", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "nudge", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var wobble := create_tween()
	wobble.tween_property(self, "rotation", 0.05, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wobble.tween_property(self, "rotation", -0.05, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(self, "rotation", 0.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Resizes a pointer position into the shared canvas space: `_gui_input`
## positions arrive in this tile's local space, whatever scale the tile wears
## at that moment.
func global_pointer(local: Vector2) -> Vector2:
	return get_global_transform() * local


## ---------------------------------------------------------------- input --
func _gui_input(event: InputEvent) -> void:
	if state == State.LOCKED or state == State.SOLVED:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_drag(mb.position)
		elif _dragging:
			_end_drag()
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_drag(touch.position)
		elif _dragging:
			_end_drag()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		dragged.emit(self, global_pointer((event as InputEventMouseMotion).position))
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		dragged.emit(self, global_pointer((event as InputEventScreenDrag).position))
		accept_event()


func _begin_drag(local: Vector2) -> void:
	if _dragging:
		return
	_dragging = true
	grabbed.emit(self, global_pointer(local))


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	released.emit(self)


func _on_mouse_entered() -> void:
	_hovered = true
	if state != State.IDLE or _dragging:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	_hovered = false
	if state != State.IDLE or _dragging:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
## --------------------------------------------------------------- drawing --
func _body_color() -> Color:
	if state == State.SOLVED:
		return ScrambledTheme.SOLVED_COLOR
	var base := ScrambledTheme.tile_color(color_index)
	if nudge > 0.0:
		return base.lerp(ScrambledTheme.NUDGE_COLOR, nudge * 0.5)
	return base


## The single source of truth for the tile's look.
func _refresh() -> void:
	if size.x <= 0.0:
		return
	var radius := int(maxf(8.0, size.x * CORNER_RATIO))
	# The dark outline is the back-most block; the candy face and its extruded
	# edge are drawn on top of it, inset by the outline's thickness.
	_style.set_corner_radius_all(radius)
	_style.set_border_width_all(0)
	_style.bg_color = ScrambledTheme.TILE_OUTLINE
	# Cartoon elevation while the tile is carried: a soft drop shadow behind
	# the whole block, on top of the solid extruded edge it always has.
	_style.shadow_color = Color(0.10, 0.06, 0.20, 0.18 + 0.26 * lift)
	_style.shadow_size = int(round(4.0 + 16.0 * lift))
	_style.shadow_offset = Vector2(0.0, 6.0 + 10.0 * lift)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var body := _body_color()
	var radius := maxf(8.0, size.x * CORNER_RATIO)
	var outline := maxf(2.0, size.x * OUTLINE_RATIO)
	var side := maxf(4.0, size.x * SIDE_RATIO)
	var inner := size - Vector2(outline * 2.0, outline * 2.0)
	if inner.x <= 0.0 or inner.y - side <= 0.0:
		return

	# 1. The dark outline: a solid block behind everything.
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	# 2. The extruded bottom edge: a darker slab of the same colour, drawn
	#    over the outline and covered by the face, so only its bottom lip
	#    shows — that lip is what makes the tile a chunky 3D block.
	draw_style_box(_slab_style(ScrambledTheme.tile_side(body), radius),
		Rect2(Vector2(outline, outline), inner))
	# 3. The face: the flat candy colour, lifted by the extrusion.
	draw_style_box(_slab_style(body, radius),
		Rect2(Vector2(outline, outline), Vector2(inner.x, inner.y - side)))
	# 4. A subtle gloss across the top of the face (weaker while carried).
	var gloss_height := maxf(4.0, (inner.y - side) * 0.30)
	draw_style_box(_slab_style(Color(1, 1, 1, 0.20 - 0.09 * lift), int(radius * 0.7)),
		Rect2(Vector2(outline + radius * 0.28, outline + radius * 0.20),
			Vector2(inner.x - radius * 0.56, gloss_height)))

	if letter.is_empty():
		return
	var font := MenuStyle.nunito()
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	# One big, very round white letter, centred on the face (slightly above
	# the middle so the extrusion does not make it read as sitting low).
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