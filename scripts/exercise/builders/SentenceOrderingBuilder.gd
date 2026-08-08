class_name SentenceOrderingBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	for item_dict in data.get_items():
		var item_vbox := create_item_container(parent)
		add_item_media(item_dict, item_vbox, data)

		var words: Array = item_dict.get("words", [])
		var word_texts: Array = []
		for w in words:
			word_texts.append(get_option_text(w))

		# Resolve answer words (may be indices or actual words)
		var answer_words_raw: Array = item_dict.get("answer", word_texts)
		var answer_words: Array = []
		var all_int := true
		for x in answer_words_raw:
			if not (x is int or x is float):
				all_int = false
				break
		if all_int and answer_words_raw.size() == word_texts.size():
			for x in answer_words_raw:
				var idx := int(x)
				if idx >= 0 and idx < word_texts.size():
					answer_words.append(word_texts[idx])
				else:
					answer_words.append(str(x))
		else:
			for w in answer_words_raw:
				answer_words.append(get_option_text(w))

		# Built row (where user places words)
		var built_row := HFlowContainer.new()
		built_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		built_row.add_theme_constant_override("h_separation", 8)
		built_row.add_theme_constant_override("v_separation", 8)
		built_row.custom_minimum_size = Vector2(0, 64)
		built_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(built_row)

		var sep := HSeparator.new()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_child(sep)

		# Bank row (available words)
		var bank_row := HFlowContainer.new()
		bank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bank_row.add_theme_constant_override("h_separation", 8)
		bank_row.add_theme_constant_override("v_separation", 8)
		bank_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(bank_row)

		var order: Array = []
		var word_btns: Array = []
		for i in word_texts.size():
			var wb := make_chip_button(str(word_texts[i]))
			word_btns.append(wb)
			bank_row.add_child(wb)

		for i in word_texts.size():
			word_btns[i].pressed.connect(
				_on_bank_word_pressed.bind(i, order, word_btns, built_row, word_texts)
			)

		var fb := make_feedback(item_vbox)
		var item_data := ExerciseData.Item.new(
			"sentence_ordering",
			func():
				var chosen: Array = []
				for idx in order:
					chosen.append(word_texts[idx])
				return _join_words(chosen),
			_join_words(answer_words),
			fb
		)
		items.append(item_data)

func _join_words(arr: Array) -> String:
	var parts: Array = []
	for a in arr:
		parts.append(str(a))
	return " ".join(parts)

func _on_bank_word_pressed(idx: int, order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	var btn: Button = word_btns[idx]
	if btn.disabled:
		return
	btn.disabled = true
	btn.modulate.a = 0.3
	order.append(idx)
	_rebuild_order_row(order, word_btns, built_row, words)

func _rebuild_order_row(order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	for c in built_row.get_children():
		built_row.remove_child(c)
		c.queue_free()

	for pos in order.size():
		var idx: int = order[pos]
		var chip := make_chip_button(str(words[idx]), true)
		chip.pressed.connect(_on_built_word_pressed.bind(pos, order, word_btns, built_row, words))
		built_row.add_child(chip)

func _on_built_word_pressed(pos: int, order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	var idx: int = order[pos]
	order.remove_at(pos)
	var btn: Button = word_btns[idx]
	btn.disabled = false
	btn.modulate.a = 1.0
	_rebuild_order_row(order, word_btns, built_row, words)
