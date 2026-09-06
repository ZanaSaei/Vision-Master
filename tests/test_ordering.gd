extends Node

# Headless test for the "Put in Order" exercise UI (card list + drag handles).
# Builds an ExerciseEngine manually (the runner's node is not inside a scene
# tree, and the engine builds fine outside one) and verifies:
#   - card structure: [handle][chip][text][up][down] row
#   - position chips are 56x56 and renumber after moves
#   - arrows are 88x88, identical, never disabled, with hover/pressed styles
#   - the grab handle (≡) is a 56x56 PanelContainer on the left with grip
#     bars and a connected drag handler; only handle presses begin a drag
#   - drag: holding the handle then moving reorders live; a fast (pre-hold)
#     move does nothing; release drops in the new order
#   - grading contract (get() returns the live order array, reachable to the
#     answer via adjacent arrow swaps) stays intact
# NOTE: containers don't auto-layout outside a tree, so the drag test lays the
# cards out manually before driving the handle gesture.

var _engine: Node
var _list_vbox: VBoxContainer
var _exercise: Dictionary = {
	"type": "ordering",
	"instruction": {"en": "Rearrange the words.", "fa": "کلمات را مرتب کنید."},
	"items": [
		{"text": {"en": "borrowed / I / that book"}},
		{"text": {"en": "is going / she / the TV / to turn on"}},
		{"text": {"en": "can / learn / we / a new language"}},
		{"text": {"en": "sang / a song / my grandfather"}},
	],
	"answer_order": [1, 2, 0, 3],
}

func test_ordering_redesign() -> void:
	_build_fresh()
	_check_structure()
	_check_arrow_moves()
	_check_drag_behavior()
	# Fresh engine (identity order) for the grading + reachability phase.
	_build_fresh()
	_check_grading_and_reachability()
	print("ALL ORDERING TESTS PASSED")

# ---------- phases ----------

func _build_fresh() -> void:
	var EngineScript: GDScript = load("res://scenes/shared/exercise_engine/ExerciseEngine.gd")
	if _engine == null:
		_engine = EngineScript.new()
	_engine.build(_exercise)
	_list_vbox = _find_list_vbox(_engine)
	assert(_list_vbox != null, "ordering list VBoxContainer not found")

func _check_structure() -> void:
	var cards: Array = _list_vbox.get_children()
	assert(cards.size() == 4, "expected 4 order cards, got %d" % cards.size())
	for i in cards.size():
		var card: PanelContainer = cards[i]
		assert(card is PanelContainer, "card %d should be a PanelContainer" % i)
		assert(card.get_theme_stylebox("panel") != null, "card %d missing panel stylebox" % i)
		var row: HBoxContainer = card.get_child(0) as HBoxContainer
		assert(row != null and row.get_child_count() == 5, "card %d row must have 5 children (handle,chip,text,up,down)" % i)

		var handle: PanelContainer = row.get_child(0) as PanelContainer
		assert(handle != null, "card %d missing grab handle" % i)
		assert(handle.custom_minimum_size == Vector2(56, 56), "handle must be 56x56")
		assert(handle.mouse_filter == Control.MOUSE_FILTER_STOP, "handle must consume its own presses")
		assert(handle.get_child_count() >= 1, "handle missing grip bars")
		assert(handle.gui_input.get_connections().size() >= 1, "handle missing drag handler connection")

		var chip: PanelContainer = row.get_child(1) as PanelContainer
		var chip_lbl: Label = chip.get_child(0) as Label
		var txt: Label = row.get_child(2) as Label
		var up: Button = row.get_child(3) as Button
		var down: Button = row.get_child(4) as Button
		assert(chip.custom_minimum_size == Vector2(56, 56), "chip must be 56x56")
		assert(chip_lbl.text == str(i + 1), "chip %d must show slot %d, got %s" % [i, i + 1, chip_lbl.text])
		assert(txt != null and not txt.text.is_empty(), "card %d text missing" % i)
		assert(up != null and down != null, "card %d arrows missing" % i)
		assert(up.custom_minimum_size == Vector2(88, 88), "up arrow must be 88x88")
		assert(down.custom_minimum_size == Vector2(88, 88), "down arrow must be 88x88")
		assert(up.text == "↑" and down.text == "↓", "arrow glyphs wrong")
		assert(not up.disabled and not down.disabled, "arrows must never be disabled")
		assert(up.get_theme_stylebox("hover") != null and up.get_theme_stylebox("pressed") != null, "arrow hover/pressed styles missing")
	print("initial_structure_ok=true")

func _check_arrow_moves() -> void:
	var texts_before: Array = _card_texts()
	var down0: Button = _row(0).get_child(4)
	down0.pressed.emit()
	var texts_after: Array = _card_texts()
	assert(texts_before[0] == texts_after[1] and texts_before[1] == texts_after[0], "down-press must swap cards 0 and 1")
	var up1: Button = _row(1).get_child(3)
	up1.pressed.emit()
	assert(_card_texts() == texts_before, "up-press must swap cards back")
	assert((_engine._items[0]["get"].call() as Array) == [0, 1, 2, 3], "order must be restored after arrow moves")
	print("arrow_move_ok=true")

func _check_drag_behavior() -> void:
	# --- fast move before hold does nothing ---
	_layout_manually()
	var handle0: PanelContainer = _row(0).get_child(0)
	_press_handle(handle0, Vector2(28, 56))
	_move_handle(handle0, Vector2(28, 56 + 124))
	assert(not _engine._order_drag_active, "drag must NOT start before the hold threshold")
	assert((_engine._items[0]["get"].call() as Array) == [0, 1, 2, 3], "no reorder before hold")
	_release_handle(handle0)
	assert((_engine._items[0]["get"].call() as Array) == [0, 1, 2, 3], "quick press+move+release must not reorder")
	print("fast_move_noop_ok=true")

	# --- hold then move reorders live, release drops ---
	_press_handle(handle0, Vector2(28, 56))
	_engine._order_drag_press_msec = Time.get_ticks_msec() - 500  # simulate hold
	_move_handle(handle0, Vector2(28, 330))           # inside card 2's span [248, 360)
	assert(_engine._order_drag_active, "drag must start after hold + move")
	assert((_engine._items[0]["get"].call() as Array) == [1, 2, 0, 3], "dragging card 0 into slot 2 must reorder live")
	assert(_chip_lbl(0).text == "1" and _chip_lbl(2).text == "3", "chips must renumber during drag")
	assert(_order_card_of(2).z_index == 50, "dragged card must be lifted above siblings")
	_release_handle(handle0)
	assert((_engine._items[0]["get"].call() as Array) == [1, 2, 0, 3], "release must keep the reordered arrangement")
	assert(not _engine._order_drag_active, "drag state must clear after release")
	print("hold_drag_reorder_ok=true")

	# --- gesture cancel settles without corrupting ---
	_layout_manually()
	_press_handle(handle0, Vector2(28, 56))
	_engine._order_drag_press_msec = Time.get_ticks_msec() - 500
	_move_handle(handle0, Vector2(28, 330))
	var before_cancel: Array = _engine._items[0]["get"].call().duplicate()
	_engine._on_gesture_cancelled_by_page()  # e.g. a page swipe steals the gesture
	assert((_engine._items[0]["get"].call() as Array) == before_cancel, "cancel must settle without corrupting the order")
	assert(not _engine._order_drag_active, "cancel must clear drag state")
	print("gesture_cancel_ok=true")

	# --- hold then release without moving does not reorder ---
	_build_fresh()
	_layout_manually()
	handle0 = _row(0).get_child(0)
	_press_handle(handle0, Vector2(28, 56))
	_engine._order_drag_press_msec = Time.get_ticks_msec() - 500
	_release_handle(handle0)  # never moved
	assert((_engine._items[0]["get"].call() as Array) == [0, 1, 2, 3], "hold+release without motion must not reorder")
	assert(not _engine._order_drag_active, "drag must not be active after hold+release")
	print("hold_no_move_ok=true")

	# --- drag upward: card 3 -> slot 1 ---
	_build_fresh()
	_layout_manually()
	var handle3: PanelContainer = _row(3).get_child(0)
	_press_handle(handle3, Vector2(28, 3 * 124 + 56))
	_engine._order_drag_press_msec = Time.get_ticks_msec() - 500
	_move_handle(handle3, Vector2(28, 1 * 124 + 56))  # card 1's centre
	assert((_engine._items[0]["get"].call() as Array) == [0, 3, 1, 2], "dragging card 3 up to slot 1 must reorder")
	_release_handle(handle3)
	assert((_engine._items[0]["get"].call() as Array) == [0, 3, 1, 2], "upward drag must settle on release")
	print("upward_drag_ok=true")

func _check_grading_and_reachability() -> void:
	var item: Dictionary = _engine._items[0]
	var got: Variant = item["get"].call()
	var ans: Variant = item["answer"]
	assert(got is Array and (got as Array).size() == 4, "get() must return an order array")
	assert(ans is Array and (ans as Array).size() == 4, "answer must be an order array")
	print("got=", got, " answer=", ans)

	# Reach the answer from identity [0,1,2,3] via adjacent arrow swaps
	# (bubble the correct item up to each slot).
	var ans_arr: Array = ans as Array
	var guard := 0
	while (_engine._items[0]["get"].call() as Array) != ans_arr and guard < 200:
		guard += 1
		var order: Array = _engine._items[0]["get"].call()
		var i := -1
		for k in order.size():
			if int(order[k]) != int(ans_arr[k]):
				i = k
				break
		if i < 0:
			break
		var j: int = order.find(int(ans_arr[i]))
		while j > i:
			(_row(j).get_child(3) as Button).pressed.emit()  # UP moves the card at j up one
			j -= 1
	assert((_engine._items[0]["get"].call() as Array) == ans_arr, "ordering to the answer must be reachable via arrows")
	print("reachable_correct_order=true grading_contract_ok=true")

# ---------- helpers ----------

func _find_list_vbox(n: Node) -> VBoxContainer:
	if n is VBoxContainer and n.get_child_count() > 0 and n.get_child(0) is PanelContainer:
		return n
	for c in n.get_children():
		var found: VBoxContainer = _find_list_vbox(c)
		if found != null:
			return found
	return null

func _card_texts() -> Array:
	var out: Array = []
	for c in _list_vbox.get_children():
		out.append((((c as PanelContainer).get_child(0)).get_child(2) as Label).text)
	return out

func _row(i: int) -> HBoxContainer:
	return ((_list_vbox.get_child(i) as PanelContainer).get_child(0)) as HBoxContainer

func _chip_lbl(i: int) -> Label:
	return (_row(i).get_child(1).get_child(0)) as Label

func _order_card_of(i: int) -> PanelContainer:
	return _list_vbox.get_child(i) as PanelContainer

# Manually position the cards so get_global_rect() is meaningful outside a tree.
func _layout_manually() -> void:
	for i in _list_vbox.get_child_count():
		var c := _list_vbox.get_child(i) as Control
		c.position = Vector2(0, i * 124)

func _press_handle(handle: Control, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = pos
	handle.gui_input.emit(ev)

func _move_handle(handle: Control, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	handle.gui_input.emit(ev)

func _release_handle(handle: Control, pos := Vector2.ZERO) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = false
	ev.position = pos
	handle.gui_input.emit(ev)
