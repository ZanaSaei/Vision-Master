class_name TableFillAdvancedBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var columns: Array = data.raw.get("columns", [])

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(columns.size(), 1)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	for col in columns:
		var h := ExerciseTheme.make_label(get_en_text(col), "body_small", "primary", true)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)

	for row in data.raw.get("rows", []):
		var cells: Array = []
		if row is Dictionary:
			cells = row.get("cells", [])
		elif row is Array:
			cells = row

		for cell in cells:
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 6)
			cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell_box)

			if not cell is Dictionary:
				var plain := ExerciseTheme.make_label(str(cell), "body_small", "text", false)
				plain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(plain)
				continue

			var ctype := str(cell.get("type", cell.get("editor", "label")))
			match ctype:
				"line", "fill_blank", "text":
					_build_line_cell(cell_box, cell, items, gesture_handler)
				"dropdown", "select":
					_build_dropdown_cell(cell_box, cell, items, gesture_handler)
				"true_false", "yes_no":
					_build_bool_cell(cell_box, cell, ctype, items, gesture_handler)
				"checkbox", "check":
					_build_checkbox_cell(cell_box, cell, items, gesture_handler)
				_:
					var lbl := ExerciseTheme.make_label(get_en_text(cell.get("text", "")), "body_small", "text", false)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cell_box.add_child(lbl)

func _build_line_cell(cell_box: VBoxContainer, cell: Dictionary, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var le := make_line_edit(str(cell.get("placeholder", "...")), gesture_handler)
	cell_box.add_child(le)
	var fb := make_feedback(cell_box)
	var item_data := ExerciseData.Item.new("fill_blank", _get_text_func(le), cell.get("answer", []), fb)
	item_data.explanation_en = get_en_text(cell.get("explanation", ""))
	item_data.explanation_fa = get_fa_text(cell.get("explanation", ""))
	item_data.compiled_patterns = compile_patterns(cell.get("answer_patterns", []))
	item_data.required_words = cell.get("required_words", [])
	item_data.forbidden_words = cell.get("forbidden_words", [])
	items.append(item_data)

func _build_dropdown_cell(cell_box: VBoxContainer, cell: Dictionary, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var options: Array = cell.get("options", [])
	var option_texts: Array = []
	for opt in options:
		option_texts.append(get_option_text(opt))
	var ob := make_option_dropdown(option_texts, gesture_handler, str(cell.get("placeholder", "Choose")))
	cell_box.add_child(ob)
	var ans: Variant = resolve_dropdown_answer(cell.get("answer", ""), options, option_texts)
	var fb := make_feedback(cell_box)
	var item_data := ExerciseData.Item.new("dropdown", get_dropdown_answer_func(ob), ans, fb)
	item_data.explanation_en = get_en_text(cell.get("explanation", ""))
	item_data.explanation_fa = get_fa_text(cell.get("explanation", ""))
	items.append(item_data)

func _build_bool_cell(cell_box: VBoxContainer, cell: Dictionary, ctype: String, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var group := ButtonGroup.new()
	var yes_text := "Yes" if ctype == "yes_no" else "True"
	var no_text := "No" if ctype == "yes_no" else "False"

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_box.add_child(hbox)

	var b_yes := make_select_button(yes_text, group, ExerciseTheme.COLORS.success, gesture_handler)
	var b_no := make_select_button(no_text, group, ExerciseTheme.COLORS.error, gesture_handler)
	hbox.add_child(b_yes)
	hbox.add_child(b_no)

	var ans_tf: Variant = cell.get("answer", true)
	if ans_tf is String:
		var s := ExerciseData.normalize(str(ans_tf))
		ans_tf = (s == "yes" or s == "true" or s == "y" or s == "t")

	var fb := make_feedback(cell_box)
	var item_data := ExerciseData.Item.new(ctype, _get_bool_func(b_yes, b_no), ans_tf, fb)
	item_data.explanation_en = get_en_text(cell.get("explanation", ""))
	item_data.explanation_fa = get_fa_text(cell.get("explanation", ""))
	items.append(item_data)

func _build_checkbox_cell(cell_box: VBoxContainer, cell: Dictionary, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var cb := make_checkbox(get_en_text(cell.get("text", "")), gesture_handler)
	cell_box.add_child(cb)
	var fb := make_feedback(cell_box)
	var item_data := ExerciseData.Item.new("checkbox", _get_check_func(cb), bool(cell.get("answer", false)), fb)
	item_data.explanation_en = get_en_text(cell.get("explanation", ""))
	item_data.explanation_fa = get_fa_text(cell.get("explanation", ""))
	items.append(item_data)

func _get_text_func(le: LineEdit) -> Callable:
	return func(): return le.text

func _get_bool_func(b_yes: Button, b_no: Button) -> Callable:
	return func():
		if b_yes.button_pressed:
			return true
		if b_no.button_pressed:
			return false
		return null

func _get_check_func(cb: CheckBox) -> Callable:
	return func(): return cb.button_pressed
