class_name OrderingBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var raw_items: Array = data.get_items()
	var item_texts: Array = []
	for it in raw_items:
		item_texts.append(get_option_text(it))

	# Resolve the correct answer order
	var answer_order: Array = data.raw.get("answer_order", [])
	if answer_order.is_empty():
		var ans: Array = data.raw.get("answer", [])
		if ans.size() == raw_items.size():
			var pairs: Array = []
			for i in ans.size():
				pairs.append({"pos": int(ans[i]), "idx": i})
			pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a["pos"] < b["pos"]
			)
			for p in pairs:
				answer_order.append(p["idx"])
	if answer_order.is_empty():
		for i in raw_items.size():
			answer_order.append(i)

	# Current (user-modifiable) order starts as 0, 1, 2, ...
	var current_order: Array = []
	for i in raw_items.size():
		current_order.append(i)

	var container := VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", ExerciseTheme.SPACING.tight)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(container)

	var list_vbox := VBoxContainer.new()
	list_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_vbox.add_theme_constant_override("separation", 10)
	container.add_child(list_vbox)

	var fb := make_feedback(container)
	_rebuild_ordering_list(list_vbox, current_order, item_texts)

	# Build the display text for the correct answer
	var ordered_texts: Array = []
	for idx in answer_order:
		var i := int(idx)
		if i >= 0 and i < item_texts.size():
			ordered_texts.append(str(item_texts[i]))

	var item_data := ExerciseData.Item.new(
		"ordering",
		func(): return current_order.duplicate(),
		answer_order.duplicate(),
		fb
	)
	item_data.answer_display = " → ".join(ordered_texts)
	items.append(item_data)

func _rebuild_ordering_list(list_vbox: VBoxContainer, current_order: Array, item_texts: Array) -> void:
	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	for pos in current_order.size():
		var idx := int(current_order[pos])
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_vbox.add_child(row)

		var num := ExerciseTheme.make_label("%d." % (pos + 1), "body_small", "muted", true)
		num.custom_minimum_size.x = 60
		row.add_child(num)

		var txt := ExerciseTheme.make_label(str(item_texts[idx]), "body", "text", false)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)

		var up := ExerciseTheme.make_button("↑", "muted")
		up.custom_minimum_size = Vector2(70, 60)
		up.disabled = (pos == 0)
		up.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, -1))
		row.add_child(up)

		var down := ExerciseTheme.make_button("↓", "muted")
		down.custom_minimum_size = Vector2(70, 60)
		down.disabled = (pos == current_order.size() - 1)
		down.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, 1))
		row.add_child(down)

func _on_order_move(list_vbox: VBoxContainer, current_order: Array, item_texts: Array, pos: int, delta: int) -> void:
	var new_pos := pos + delta
	if new_pos < 0 or new_pos >= current_order.size():
		return
	var tmp: int = int(current_order[pos])
	current_order[pos] = current_order[new_pos]
	current_order[new_pos] = tmp
	_rebuild_ordering_list(list_vbox, current_order, item_texts)
