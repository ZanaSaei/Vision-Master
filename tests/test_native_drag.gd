extends Control
## ============================================================
##  NATIVE DRAG INTEGRATION TEST — «بازی املا»'s drag, as the ENGINE runs it.
##
##  The unit suite (scenes/word_game/scrambled/test_scrambled_words.gd) calls
##  the drag methods directly. This one goes a level up and feeds real press,
##  motion and release events through the Viewport, so the parts of a drag that
##  only the engine can get wrong are exercised for real:
##    * deciding which Control may start a drag at all,
##    * asking it for its payload — and building the carried preview,
##    * resolving the drop target by walking the tree, which is exactly where a
##      MOUSE_FILTER_STOP tile that refused a drop would break the board,
##    * reporting NOTIFICATION_DRAG_END, so the letter can be picked up again.
##
##  WHAT IT DOES NOT ASSERT: where the letter lands. The engine resolves a drop
##  from the *real* pointer rather than from a synthesized event, so a harness
##  cannot steer the landing slot — `_can_drop_data`/`_drop_data` are handed the
##  live cursor's position whatever the events say. Which slot a drop opens and
##  lands in is covered by test_scrambled_words.gd, which passes those positions
##  in itself.
##
##  Run it with run_scene on res://tests/TestNativeDrag.tscn.
## ============================================================

const BOARD_SCENE := preload("res://scenes/word_game/scrambled/TileBoard.tscn")

## One motion step. The engine accumulates each event's `relative` and only
## agrees a gesture is a drag — rather than a click — once it has travelled
## far enough, so a single frame-jump motion would not do.
const STEP := 24.0
## How far right the letter is carried: past two slots, as in the unit test.
const CARRY := 700.0

var _failures := 0
var _board: ScrambledTileBoard = null
var _settled: Array = []


func _ready() -> void:
	# The harness must never answer for the board: with IGNORE the drop search
	# walks straight past it to whatever the crosshair is really over.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	await _run()


func _run() -> void:
	var controller := ScrambledWordController.new()
	controller.setup({"word": "sun"}, 987654)
	_board = BOARD_SCENE.instantiate() as ScrambledTileBoard
	# Placed by hand so the scripted finger has known ground to work on. The
	# board measures its own row, so nothing here depends on the window size —
	# but its scene ships stretched, and a stretched Control has its size
	# re-imposed by every layout pass, so the anchors go back to top-left first.
	_board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_board.position = Vector2(200.0, 400.0)
	_board.size = Vector2(1000.0, 400.0)
	_board.arrangement_settled.connect(func(solved: bool) -> void: _settled.append(solved))
	add_child(_board)
	await get_tree().process_frame
	await get_tree().process_frame
	_board.build(controller, false)
	# The letters fly to their slots; a player drags after they have landed, so
	# the scripted finger waits for the row to be at rest too.
	await get_tree().create_timer(0.4).timeout

	_check(_board.tile_count() == 3, "the board dealt three letters")

	var first: ScrambledTile = _board.get_child(0)
	var from := first.get_global_rect().get_center()
	var to := from + Vector2(CARRY, 0.0)

	# --- a real press-and-travel, straight into the Viewport -----------------
	await _drag_start(from)
	_check(first.state == ScrambledTile.State.DRAGGING,
		"the engine started a native drag on the pressed letter")
	_check(_board.is_busy(), "the board opened a slot for the letter")
	# Rule 2's preview: the player must be handed something to carry. It lives
	# in the Viewport's own drag layer, so it is looked for there.
	_check(_drag_preview() != null, "the engine is holding a carried copy for the finger")

	await _drag_move_to(from, to)
	await _release(to)
	await get_tree().create_timer(0.6).timeout

	_check(not _board.is_busy(), "the drag ends with nothing carried")
	_check(not _settled.is_empty(), "the row settled and was judged")
	_check(is_equal_approx(first.modulate.a, 1.0),
		"the carried copy is solid again (alpha %.2f)" % first.modulate.a)

	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)


############################################################
# THE SCRIPTED GESTURE
############################################################
## Press, then enough travel for the engine to call it a drag.
func _drag_start(from: Vector2) -> void:
	_send_button(from, true)
	await get_tree().process_frame
	for i in 2:
		var to := from + Vector2(STEP * float(i + 1), 0.0)
		_send_motion(to, Vector2(STEP, 0.0))
		await get_tree().process_frame


## The rest of the travel: this is where the engine re-resolves the drop target
## under the finger and tells it the letter is hovering over it.
func _drag_move_to(from: Vector2, to: Vector2) -> void:
	var here := from + Vector2(STEP * 2.0, 0.0)
	_send_motion(to, to - here)
	await get_tree().process_frame


## The finger lifting: the engine resolves the target one last time and
## delivers the drop to it.
func _release(to: Vector2) -> void:
	_send_button(to, false)
	await get_tree().process_frame


func _send_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	# The drag machinery reads the button mask, so a held button has to say so.
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	# `true`: the coordinates this harness builds come from get_global_rect(),
	# which is the Viewport's own space — the space the GUI is hit-tested in.
	get_viewport().push_input(event, true)


## `relative` carries the delta: the engine accumulates it to tell a drag from
## a click, so a motion with a zero delta would keep the drag from starting.
func _send_motion(point: Vector2, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


## The carried copy the engine holds during a drag lives in the Viewport's own
## internal drag layer, so the only honest way to check that the player really
## was handed something is to look for it there.
func _drag_preview() -> TilePreview:
	for child in get_viewport().get_children(true):
		for grandchild in child.get_children(true):
			if grandchild is TilePreview:
				return grandchild as TilePreview
	return null


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS  " if condition else "FAIL  ") + label)
