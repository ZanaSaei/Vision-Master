class_name ScrambledTileBoard
extends Control
## ============================================================
##  SCRAMBLED TILE BOARD — the row of letters the player rearranges.
##
##  This is where the drag-and-drop lives. The gesture itself is the native
##  Control protocol — a tile hands the Viewport its payload and the carried
##  copy the player holds (see tile.gd) — while this node is the one that
##  DECIDES. It is deliberate about how that feels on a phone:
##    * the slot under the carried letter opens up the instant the pickup is
##      reported, and the neighbours slide out of the way (TRANS_BACK, so
##      they settle with a little bounce) around a pulsing outline,
##    * the drop snaps with TRANS_BACK/EASE_OUT, and a wrong arrangement is
##      never punished — if the word is one or two letters away the misplaced
##      tiles pulse amber, which nudges without revealing the answer,
##    * a drag that ends anywhere else puts the letter back, so a slipped
##      finger can never lose a letter off the row.
##
##  The board owns every position: tiles only REPORT the finger, and they do
##  that through signals, never by reaching back into this node. The child
##  order is re-synced after each settle so the next carried letter comes to
##  the front, and the layout is recomputed from the board's own size, so a
##  three letter word and a twelve letter word both fit and stay square.
## ============================================================

signal arrangement_settled(solved: bool)
signal tile_grabbed(tile: ScrambledTile)

const TILE_SCENE := preload("res://scenes/word_game/scrambled/Tile.tscn")

const MAX_TILE_SIZE := 200.0
const MIN_TILE_SIZE := 40.0
const MIN_GAP := 8.0
const MAX_GAP := 26.0
## The row sits a little below the centre, keeping the thumb off the letters.
const ROW_TOP_BIAS := 26.0
## How long a neighbour takes to slide out of the way when a slot opens up.
const SHIFT_TIME := 0.20
const SETTLE_TIME := 0.24
const DEAL_STAGGER := 0.06
const DEAL_TIME := 0.30

var _controller: ScrambledWordController = null
## slot_id -> ScrambledTile. A slot id is a tile's identity, not its place.
var _tiles: Array = []
## Slot ids left to right, as committed (what the word is judged against).
var _order: Array = []
## The committed order with the carried tile previewed in its slot.
var _display_order: Array = []
var _held: ScrambledTile = null
var _preview_index := -1
var _ghost_index := -1
var _solved := false
var _locked := false
var _tile_size := 120.0
var _gap := 18.0
var _row_y := 0.0
var _settle_waiter: Tween = null
var _ghost_seeker: Tween = null
## True while the row is flying in. A layout change during the deal restarts it
## whole, because the deal starts from alpha 0: cancelling it would leave the
## row invisible.
var _dealing := false
## Ends the deal and declares the row at rest.
var _deal_waiter: Tween = null
var _track_style := StyleBoxFlat.new()
var _ghost_style := StyleBoxFlat.new()
## "instance_property" -> the tween currently driving it, so a new move can
## replace an old one instead of fighting it.
var _moves: Dictionary = {}

## 0..1 pulse of the empty slot outline (looping while a tile is carried).
var _ghost_pulse := 0.0:
	set(value):
		_ghost_pulse = clampf(value, 0.0, 1.0)
		_update_ghost_style()
## ------------------------------------------------------------- building --
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	_refresh_styles()


## Deals a word: one tile per letter, in the controller's scrambled order.
func build(p_controller: ScrambledWordController, animate := true) -> void:
	clear()
	_controller = p_controller
	if _controller == null:
		return
	for i in _controller.letters.size():
		var tile := TILE_SCENE.instantiate() as ScrambledTile
		tile.letter = str(_controller.letters[i])
		tile.color_index = i
		tile.slot_id = i
		add_child(tile)
		# The drag protocol belongs to the tile (see tile.gd); the board only
		# listens, and decides where the letter lands.
		tile.drag_started.connect(_on_tile_drag_started)
		tile.drag_hovered.connect(_on_tile_drag_hovered)
		tile.drop_requested.connect(_on_tile_drop_requested)
		tile.drag_cancelled.connect(_on_tile_drag_cancelled)
		_tiles.append(tile)
		_order.append(i)
	_display_order = _order.duplicate()
	# The first word of a session is built in the same frame the screen lays
	# out, so the board may not know its size yet. Dealing with a guessed
	# geometry would drop the letters in the wrong place, so wait one frame
	# for the real layout first.
	if size.y < 40.0:
		await get_tree().process_frame
		if not is_inside_tree() or _controller != p_controller:
			return
	_recompute_layout()
	if animate:
		_deal_animation()
	else:
		for tile in _tiles:
			tile.play_pop(0.0, 1.0)


func clear() -> void:
	_kill_tweens()
	_held = null
	_preview_index = -1
	_ghost_index = -1
	_solved = false
	_locked = false
	for tile in _tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles = []
	_order = []
	_display_order = []
	_controller = null
	queue_redraw()


## Fades the row in: each tile flies up from below with a small pop, which
## reads as the letters being "dealt" rather than appearing. The tweens go
## through _tween(), so a second call (a layout change mid-deal) replaces them
## instead of stacking, and grabbing a letter mid-deal takes it over cleanly.
func _deal_animation() -> void:
	_dealing = true
	for i in _tiles.size():
		var tile := _tiles[i] as ScrambledTile
		var slot := _slot_position(i)
		var delay := DEAL_STAGGER * float(i)
		tile.position = slot + Vector2(0.0, 90.0)
		tile.modulate.a = 0.0
		tile.scale = Vector2(0.75, 0.75)
		_tween(tile, "position", slot, DEAL_TIME, Tween.TRANS_BACK, Tween.EASE_OUT, delay)
		_tween(tile, "scale", Vector2.ONE, DEAL_TIME, Tween.TRANS_BACK, Tween.EASE_OUT, delay)
		_tween(tile, "modulate:a", 1.0, DEAL_TIME * 0.7, Tween.TRANS_QUAD, Tween.EASE_OUT, delay)
	# The row counts as settled only once the last tile has landed: whatever the
	# layout does underneath it, the deal ends with a fully visible row.
	if _deal_waiter != null and _deal_waiter.is_valid():
		_deal_waiter.kill()
	var total := DEAL_TIME + DEAL_STAGGER * float(maxi(_tiles.size() - 1, 0))
	_deal_waiter = create_tween()
	_deal_waiter.tween_interval(total + 0.05)
	_deal_waiter.tween_callback(_finish_deal)


func _finish_deal() -> void:
	_deal_waiter = null
	_dealing = false
	# Safety net: the deal is the only move that fades a tile, so a tile that
	# reached the end of it is visible, exactly where it was aimed.
	for tile in _tiles:
		if is_instance_valid(tile):
			(tile as ScrambledTile).modulate.a = 1.0
	queue_redraw()


## ------------------------------------------------------------- geometry --
func _on_resized() -> void:
	_recompute_layout()


func _recompute_layout() -> void:
	if _order.is_empty():
		return
	var width := size.x if size.x > 60.0 else 980.0
	var gap := clampf(width * 0.013, MIN_GAP, MAX_GAP)
	var count := _order.size()
	var tile_px := (width - gap * float(count - 1)) / float(count)
	_tile_size = clampf(tile_px, MIN_TILE_SIZE, MAX_TILE_SIZE)
	_gap = gap
	_row_y = (size.y - _tile_size) * 0.5 + ROW_TOP_BIAS
	for i in count:
		var tile := _tiles[_order[i]] as ScrambledTile
		tile.set_tile_size(_tile_size)
	_refresh_styles()
	queue_redraw()
	# A layout change moves the slots, so every move in flight is re-issued
	# against the new ones instead of being left to run to a stale target —
	# and nothing is simply killed: the deal fades in from alpha 0, so an
	# abandoned deal would leave the row invisible.
	if _dealing and _held == null:
		_deal_animation()
		return
	if _held != null:
		# The finger owns the carried tile; only the tiles making room for it
		# are re-slotted.
		_set_preview(_preview_index)
		return
	var was_settling := _settle_waiter != null and _settle_waiter.is_valid()
	for i in count:
		var tile := _tiles[_order[i]] as ScrambledTile
		tile.modulate.a = 1.0
		_tween(tile, "position", _slot_position(i), SHIFT_TIME,
			Tween.TRANS_QUAD, Tween.EASE_OUT)
	if was_settling:
		_schedule_settle()


## Total width of the row, and the x of its left edge (the row is centred).
func _row_width() -> float:
	var count := _order.size()
	return _tile_size * float(count) + _gap * float(maxi(count - 1, 0))


func _origin_x() -> float:
	return (size.x - _row_width()) * 0.5


func _slot_position(index: int) -> Vector2:
	return Vector2(_origin_x() + float(index) * (_tile_size + _gap), _row_y)


## The slot a carried letter is hovering over, from the pointer's x. The
## pointer stands in for the letter's centre: the drag preview is centred on
## the finger, so the two agree.
func _index_for_center(center_x: float) -> int:
	var step := _tile_size + _gap
	var raw := (center_x - _origin_x() - _tile_size * 0.5) / step
	return clampi(int(round(raw)), 0, maxi(_order.size() - 1, 0))


## Pointer positions arrive in the shared canvas space; the board thinks and
## works in its own local space (Control has no to_local()).
func _to_board(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


## -------------------------------------------------------- drop target --
## The board accepts a carried letter in its own right, so a drop that lands
## between two slots — or on the track's padding — still goes to the nearest
## one instead of bouncing home. At any other time the board stays inert,
## which is what lets the Viewport keep walking up to its parent.
##
## It reports the hover too: when no letter is under the finger the board is
## the control that answers, and the open slot still has to follow.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var carried := ScrambledTile.payload_tile(data)
	if carried == null or _held != carried:
		return false
	_on_tile_drag_hovered(carried, get_global_transform() * at_position)
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var carried := ScrambledTile.payload_tile(data)
	if carried == null or _held != carried:
		return
	# at_position is handed over in this board's own space already.
	_commit_drop(carried, _index_for_center(at_position.x))


## ----------------------------------------------------------- drag & drop --
## The board listens to the tiles' drag protocol (tile.gd) and owns every
## decision: which slot opens up while a letter is carried, and where it lands
## when it is let go. A tile never moves itself or its neighbours.
func _on_tile_drag_started(tile: ScrambledTile) -> void:
	if _locked or _solved or _held != null:
		return
	# A settle still in flight is committed right away: picking a letter up
	# must never have to wait for an animation.
	_finish_settle_now()
	# The deal stops being a unit the moment a letter is picked up out of it:
	# the tiles still flying finish their own moves, but a layout change from
	# here on must not restart the whole row — that would yank the slot out
	# from under the letter the player is holding.
	_dealing = false
	_held = tile
	_preview_index = _order.find(tile.slot_id)
	_display_order = _order.duplicate()
	_ghost_index = _preview_index
	tile.move_to_front()
	_start_ghost_seeker()
	queue_redraw()
	tile_grabbed.emit(tile)


## Follows the finger: the slot under the carried letter opens up and the
## neighbours slide out of the way to make room for it.
func _on_tile_drag_hovered(tile: ScrambledTile, pointer_canvas: Vector2) -> void:
	if _held != tile:
		return
	var index := _index_for_center(_to_board(pointer_canvas).x)
	if index != _preview_index:
		_set_preview(index)


## Opens the slot at `index`: every other tile slides to where it will sit
## once the carried tile is dropped there.
func _set_preview(index: int) -> void:
	_preview_index = index
	_ghost_index = index
	_display_order = _order.duplicate()
	_display_order.erase(_held.slot_id)
	_display_order.insert(index, _held.slot_id)
	for i in _display_order.size():
		var tile := _tiles[_display_order[i]] as ScrambledTile
		if tile == _held:
			continue
		_tween(tile, "position", _slot_position(i), SHIFT_TIME, Tween.TRANS_BACK, Tween.EASE_OUT)
	queue_redraw()


func _on_tile_drop_requested(tile: ScrambledTile, pointer_canvas: Vector2) -> void:
	if _held != tile:
		return
	_commit_drop(tile, _index_for_center(_to_board(pointer_canvas).x))


## The finger never let go over the row (or the gesture was cancelled): the
## letters simply settle back into the order they were carried out of, so a
## slipped finger can never lose a letter.
func _on_tile_drag_cancelled(tile: ScrambledTile) -> void:
	if _held != tile:
		return
	_held = null
	_ghost_index = -1
	_preview_index = -1
	_stop_ghost_seeker()
	_display_order = _order.duplicate()
	_settle_row(tile)


## The letter is taken: the order previewed while it was carried becomes the
## real one, and the row settles around it.
func _commit_drop(tile: ScrambledTile, index: int) -> void:
	_set_preview(index)
	tile.accept_drop()
	_held = null
	_ghost_index = -1
	_stop_ghost_seeker()
	_order = _display_order.duplicate()
	_settle_row(tile)


## Commits the row: every letter slides into its slot with the settle pop, and
## the arrangement is judged once they have all landed. Shared by a drop and a
## cancelled drag, so both end exactly the same way.
func _settle_row(source: ScrambledTile) -> void:
	for i in _order.size():
		var tile := _tiles[_order[i]] as ScrambledTile
		tile.set_locked(true)
		_tween(tile, "position", _slot_position(i), SETTLE_TIME, Tween.TRANS_BACK, Tween.EASE_OUT)
	# The carried letter flies home rather than snapping: the preview vanishes
	# the instant the finger lifts, so this is what makes the drop read as the
	# letter landing in its new slot.
	_tween(source, "scale", Vector2.ONE, SETTLE_TIME, Tween.TRANS_BACK, Tween.EASE_OUT)
	_tween(source, "lift", 0.0, SETTLE_TIME, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_schedule_settle()


func _schedule_settle() -> void:
	if _settle_waiter != null and _settle_waiter.is_valid():
		_settle_waiter.kill()
	_settle_waiter = create_tween()
	_settle_waiter.tween_interval(SETTLE_TIME + 0.05)
	_settle_waiter.tween_callback(_finish_settle)


## Called by a new grab: everything still moving is snapped home first.
func _finish_settle_now() -> void:
	if _settle_waiter != null and _settle_waiter.is_valid():
		_settle_waiter.kill()
	_settle_waiter = null
	_finish_settle()


func _finish_settle() -> void:
	_settle_waiter = null
	if _tiles.is_empty():
		return
	var solved := is_solved()
	if solved:
		_solved = true
	# Positions are pinned exactly and the child order goes back to the board
	# order: the carried tile was drawn on top (move_to_front) and that must
	# not outlive the move, or the next lifted letter would hide behind it.
	for i in _order.size():
		var tile := _tiles[_order[i]] as ScrambledTile
		tile.position = _slot_position(i)
		tile.rotation = 0.0
		move_child(tile, i)
		if not solved:
			tile.set_locked(false)
	queue_redraw()
	arrangement_settled.emit(solved)


## -------------------------------------------------------------- readings --
## The letters as they currently stand, left to right.
func tiles_letters() -> Array:
	var out: Array = []
	for slot in _order:
		out.append((_tiles[slot] as ScrambledTile).letter)
	return out


func current_text() -> String:
	return ScrambledWordController.letters_to_text(tiles_letters())


func is_solved() -> bool:
	if _controller == null:
		return false
	return _controller.is_solved(tiles_letters())


func is_busy() -> bool:
	return _held != null


func tile_count() -> int:
	return _order.size()


## Freezes the board: while a word is being dealt, while it is solved, and for
## the beat before the next word arrives.
func set_board_locked(value: bool) -> void:
	_locked = value
	for tile in _tiles:
		(tile as ScrambledTile).set_locked(value or _solved)
## ------------------------------------------------------------ flourishes --
## The win: a green wave that runs left to right, then every tile stays green.
func play_solved_flourish() -> void:
	_solved = true
	for i in _order.size():
		var tile := _tiles[_order[i]] as ScrambledTile
		tile.play_pop(0.07 * float(i), 1.22)
		var tw := create_tween()
		tw.tween_interval(0.10 + 0.07 * float(i))
		tw.tween_callback(func() -> void: tile.set_solved(true))
	queue_redraw()


## Reveals a letter at the given index.
func reveal_letter_at(index: int) -> void:
	if index < 0 or index >= _tiles.size():
		return
	var tile := _tiles[_order[index]] as ScrambledTile
	if tile != null:
		# Optionally animate the reveal
		tile.play_pop(0.0, 1.1)
		# Perhaps lock it too?
		tile.set_locked(true)


## Ambers the tiles that sit in the wrong place. Only ever used when the word
## is one or two letters away, so it nudges without spoiling the answer.
func play_near_miss_nudge() -> void:
	if _controller == null:
		return
	for index in _controller.misplaced(tiles_letters()):
		var tile := _tiles[_order[index]] as ScrambledTile
		if tile != null:
			tile.play_nudge()


## --------------------------------------------------------------- drawing --
func _update_ghost_style() -> void:
	_ghost_style.bg_color = ScrambledTheme.ghost_color(_ghost_pulse)
	_ghost_style.border_color = ScrambledTheme.ghost_border_color(_ghost_pulse)
	queue_redraw()


func _refresh_styles() -> void:
	_track_style.bg_color = ScrambledTheme.track_color()
	_track_style.set_corner_radius_all(int(_tile_size * 0.30) + 10)
	_track_style.set_border_width_all(0)
	_ghost_style.set_corner_radius_all(int(_tile_size * 0.26))
	_ghost_style.set_border_width_all(4)
	_update_ghost_style()


## The board paints what lives between the tiles: the soft track that shows
## where the row is, and the pulsing slot the carried tile would drop into.
func _draw() -> void:
	if _order.is_empty():
		return
	var pad := maxf(18.0, _tile_size * 0.16)
	draw_style_box(_track_style, Rect2(
		Vector2(_origin_x() - pad, _row_y - pad * 0.6),
		Vector2(_row_width() + pad * 2.0, _tile_size + pad * 1.2)))
	if _ghost_index >= 0 and _held != null:
		draw_style_box(_ghost_style, Rect2(_slot_position(_ghost_index),
			Vector2(_tile_size, _tile_size)))


## ---------------------------------------------------------- tween helpers --
## One tween per tile and property: a fresh move (a new preview slot, a grab
## during the settle) replaces the old one instead of fighting it.
func _tween(target: Object, property: String, value: Variant, time: float,
		trans: Tween.TransitionType, ease_type: Tween.EaseType, delay := 0.0) -> void:
	var key := "%d_%s" % [target.get_instance_id(), property]
	var previous: Tween = _moves.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	var tw := create_tween()
	var tweener := tw.tween_property(target, property, value, time)
	tweener.set_trans(trans).set_ease(ease_type)
	if delay > 0.0:
		tweener.set_delay(delay)
	_moves[key] = tw


func _start_ghost_seeker() -> void:
	_stop_ghost_seeker()
	_ghost_seeker = create_tween().set_loops()
	_ghost_seeker.tween_property(self, "_ghost_pulse", 1.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ghost_seeker.tween_property(self, "_ghost_pulse", 0.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_ghost_seeker() -> void:
	if _ghost_seeker != null and _ghost_seeker.is_valid():
		_ghost_seeker.kill()
	_ghost_seeker = null
	_ghost_pulse = 0.0


func _kill_tweens() -> void:
	if _settle_waiter != null and _settle_waiter.is_valid():
		_settle_waiter.kill()
	_settle_waiter = null
	if _deal_waiter != null and _deal_waiter.is_valid():
		_deal_waiter.kill()
	_deal_waiter = null
	_dealing = false
	_stop_ghost_seeker()
	for tween in _moves.values():
		if tween != null and (tween as Tween).is_valid():
			(tween as Tween).kill()
	_moves = {}
