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
##  DRAG & DROP — the native Control protocol, per the project's UI rules:
##    _get_drag_data()  hands the Viewport a payload AND the preview the
##                      player carries (TilePreview),
##    _can_drop_data()  lets the pointer be followed across the row,
##    _drop_data()      reports where the letter was let go.
##
##  WHY A TILE ACCEPTS A DROP IT DOES NOT PLACE ITSELF: the Viewport's drop
##  search stops at the first MOUSE_FILTER_STOP control that refuses a drop
##  and will not walk on to the board underneath. A tile returning false
##  would make the row itself undroppable. Accepting costs nothing, and the
##  placement stays the board's business — this node only reports the finger
##  through signals and never touches the row (see the project's UI rules).
## ============================================================

## The finger picked a letter up: the board opens a slot for it.
signal drag_started(tile: ScrambledTile)
## The carried letter is over `pointer_canvas`: the board previews the slot.
signal drag_hovered(tile: ScrambledTile, pointer_canvas: Vector2)
## The letter was let go over `pointer_canvas`: the board decides where.
signal drop_requested(tile: ScrambledTile, pointer_canvas: Vector2)
## The drag ended without a drop (finger off the row, gesture cancelled).
## The board puts the letter back where it came from.
signal drag_cancelled(tile: ScrambledTile)

enum State { IDLE, DRAGGING, SOLVED, LOCKED }

## Every payload this scene's drags carry is tagged, so a drag started on
## another screen is rejected outright instead of half-read.
const PAYLOAD_KIND := "scrambled_tile"
const PREVIEW_SCENE := preload("res://scenes/word_game/scrambled/ui/TilePreview.tscn")

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
## How solid a tile stays while it is carried. The copy in the player's hand
## (the drag preview) is the live one; this is the ghost it left behind, and
## dimming it is what makes the pulsing empty slot read as "the letter is
## in flight".
const DRAG_GHOST_ALPHA := 0.28
## Fade back up once the finger lets go — on a drop and a cancellation alike.
const DRAG_FADE_TIME := 0.18

var letter := ""
var color_index := 0
var slot_id := 0

var state: State = State.IDLE:
	set(value):
		state = value
		_apply_drag_tint()
		_refresh()

## 0..1 cartoon elevation, kept for the board's settle tween.
var lift := 0.0:
	set(value):
		lift = clampf(value, 0.0, 1.0)
		_refresh()

## 0..1 amber pulse of the "not quite right yet" nudge.
var nudge := 0.0:
	set(value):
		nudge = clampf(value, 0.0, 1.0)
		_refresh()

var _hovered := false
var _style := StyleBoxFlat.new()
## Set when the board actually takes the letter. NOTIFICATION_DRAG_END fires
## for a completed drop too, and must not report it as a cancellation.
var _drop_accepted := false


func _ready() -> void:
	# STOP: the tile has to catch the press that starts a drag, and has to
	# stay reachable as a drop target (see the class docs).
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
## is finished. A tile the finger is still carrying is never locked — the
## gesture owns it until it is let go.
func set_locked(value: bool) -> void:
	if value:
		if state == State.DRAGGING:
			return
		state = State.LOCKED
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


## Resizes a pointer position into the shared canvas space: the positions the
## drag protocol hands us are local to whichever node received the event, and
## the tile may be scaled or mid-tween at that moment.
func global_pointer(local: Vector2) -> Vector2:
	return get_global_transform() * local


## ------------------------------------------------- drag & drop (rule 2) --
## The Viewport calls this once the finger has travelled far enough with the
## button down. Returning a non-empty payload is what starts a native drag;
## returning null leaves the tile inert (the solved and locked states).
func _get_drag_data(at_position: Vector2) -> Variant:
	if state == State.LOCKED or state == State.SOLVED:
		return null
	_drop_accepted = false
	_attach_preview()
	state = State.DRAGGING
	drag_started.emit(self)
	# Report the very first position too, so the row opens up under the letter
	# immediately instead of waiting for the first motion event.
	drag_hovered.emit(self, global_pointer(at_position))
	return {
		"kind": PAYLOAD_KIND,
		"tile": self,
		"slot_id": slot_id,
		"letter": letter,
	}


## Rule 2's visual preview: the player must always see what they hold. Handing
## one over is only legal while the Viewport is really running a drag, and the
## engine refuses it otherwise — so the check also keeps a direct call (a unit
## test driving this method) from tripping that guard.
func _attach_preview() -> void:
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_dragging():
		return
	var preview := PREVIEW_SCENE.instantiate() as TilePreview
	if preview == null:
		return
	preview.configure(letter, color_index, size.x)
	set_drag_preview(preview)


## A tile takes a carried letter so the row stays droppable (see the class
## docs). It only relays the position; the board does the placing.
##
## The hover is reported even when the finger is back over the carried letter's
## own slot: the board has to hear about that position like any other, or its
## open slot would stay wherever the finger last left it.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var carried := payload_tile(data)
	if carried == null:
		return false
	carried.report_hover(global_pointer(at_position))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var carried := payload_tile(data)
	if carried == null:
		return
	carried.report_drop(global_pointer(at_position))


## The tile a payload belongs to, or null when the payload is not one of ours.
static func payload_tile(data: Variant) -> ScrambledTile:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var payload := data as Dictionary
	if str(payload.get("kind", "")) != PAYLOAD_KIND:
		return null
	return payload.get("tile") as ScrambledTile


## Called by the drop target under the finger. Kept as a method rather than a
## flag written from outside, so the drag state stays this node's own.
func report_hover(pointer_canvas: Vector2) -> void:
	if state == State.DRAGGING:
		drag_hovered.emit(self, pointer_canvas)


func report_drop(pointer_canvas: Vector2) -> void:
	if state != State.DRAGGING:
		return
	_drop_accepted = true
	drop_requested.emit(self, pointer_canvas)


## Called by the board once it has taken the letter: the drag is consumed, so
## the tile stops being a ghost and becomes an ordinary member of the row.
func accept_drop() -> void:
	_drop_accepted = true
	state = State.IDLE


## The drag is over either way. A drop has already been handed to the board;
## anything else is a cancellation and the letter goes back to its slot.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	var accepted := _drop_accepted
	_drop_accepted = false
	if state != State.DRAGGING:
		return
	state = State.IDLE
	if not accepted:
		drag_cancelled.emit(self)


func _on_mouse_entered() -> void:
	_hovered = true
	if state != State.IDLE:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	_hovered = false
	if state != State.IDLE:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Dims the tile while the finger carries it and fades it back the moment it
## is let go — on a drop, a cancellation or a lock alike, so the ghost can
## never outlive the gesture. Every other writer of this alpha (the deal
## animation) only ever runs while the tile is IDLE, so nothing fights
## over it.
func _apply_drag_tint() -> void:
	var target := DRAG_GHOST_ALPHA if state == State.DRAGGING else 1.0
	if is_equal_approx(modulate.a, target):
		return
	if state == State.DRAGGING or not is_inside_tree():
		# Entering the drag must be instant — a fade-in would look like lag.
		modulate.a = target
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", target, DRAG_FADE_TIME) \
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
	# Cartoon elevation while lifted: a soft drop shadow behind the whole
	# block, on top of the solid extruded edge it always has.
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
	# 4. A subtle gloss across the top of the face.
	var gloss_height := maxf(4.0, (inner.y - side) * 0.30)
	draw_style_box(_slab_style(Color(1, 1, 1, 0.20), int(radius * 0.7)),
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
