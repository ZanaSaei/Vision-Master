extends Control
# Live preview for the ordering drag-handle feature. Hosts an ExerciseEngine
# inside a real PageView (like the workbook) and then runs an AUTOMATED drag
# on the real layout, printing:
#   HANDLE_RECT        - on-screen rect of card 0's handle
#   PAGEVIEW_BLOCKED   - whether PageView would ignore a press on the handle
#   ORDER_CHANGED=...  - every time the live order changes
#   MID_DRAG_ORDER     - order + drag-active state mid-drag
#   DRAG_RESULT=...    - final order after the automated drag
# The drag is driven by emitting touch events on the handle (the harness
# cannot deliver raw mouse events into Godot's GUI picking, so the real-input
# path is covered by the headless test instead; this verifies the layout math
# and PageView integration in a live tree).

var _engine: Node
var _last_order: Array = []
var _page_view: PageView

func _ready() -> void:
	var pv := PageView.new()
	pv.name = "PageView"
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pv)
	_page_view = pv
	pv.set_accent(Color("#6366F1"))

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)

	_engine = ExerciseEngine.new()
	page.add_child(_engine)
	_engine.build({
		"type": "ordering",
		"instruction": {"en": "Rearrange the words.", "fa": "کلمات را مرتب کنید."},
		"items": [
			{"text": {"en": "borrowed / I / that book"}},
			{"text": {"en": "is going / she / the TV / to turn on"}},
			{"text": {"en": "can / learn / we / a new language"}},
			{"text": {"en": "sang / a song / my grandfather"}},
		],
		"answer_order": [1, 2, 0, 3],
	})
	_last_order = _engine._items[0]["get"].call()

	for i in 3:
		var filler := PanelContainer.new()
		filler.custom_minimum_size = Vector2(0, 220)
		page.add_child(filler)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 160)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)

	pv.add_page("p1", "Ordering", "📄", page)

	call_deferred("_run_drag_test")

func _process(_delta: float) -> void:
	if _engine == null or _engine._items.is_empty():
		return
	var o: Array = _engine._items[0]["get"].call()
	if o != _last_order:
		_last_order = o
		print("ORDER_CHANGED=", o)

func _run_drag_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var list := _find_list(_engine)
	if list == null or list.get_child_count() == 0:
		print("NO_LIST")
		return
	var card0 := list.get_child(0) as Control
	var handle := (card0.get_child(0) as HBoxContainer).get_child(0) as Control
	print("HANDLE_RECT=", handle.get_global_rect())

	# PageView integration: pressing the handle must be a swipe blocker.
	var center: Vector2 = handle.get_global_rect().get_center()
	print("PAGEVIEW_BLOCKED=", _page_view._is_touch_blocked(center))

	# --- Automated drag: card 0 -> slot 2 then slot 3 ---
	var grab: Vector2 = handle.get_global_rect().get_center()
	_press_handle(handle, grab)
	_engine._order_drag_press_msec = Time.get_ticks_msec() - 600  # simulate hold
	var c2 := list.get_child(2) as Control
	var target_pos: Vector2 = Vector2(grab.x, c2.get_global_rect().get_center().y)
	_move_handle(handle, target_pos)
	var mid_order: Array = _engine._items[0]["get"].call()
	print("MID_DRAG_ORDER=", mid_order, " ACTIVE=", _engine._order_drag_active)
	var c3 := list.get_child(3) as Control
	var target_pos2: Vector2 = Vector2(grab.x, c3.get_global_rect().get_center().y)
	_move_handle(handle, target_pos2)
	_release_handle(handle)
	print("DRAG_RESULT=", _engine._items[0]["get"].call())

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

func _find_list(n: Node) -> VBoxContainer:
	if n is VBoxContainer and n.get_child_count() > 0 and n.get_child(0) is PanelContainer:
		return n
	for c in n.get_children():
		var found := _find_list(c)
		if found != null:
			return found
	return null
