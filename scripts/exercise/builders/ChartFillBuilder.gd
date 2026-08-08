class_name ChartFillBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var columns: int = data.raw.get("columns", 2)
	var headers: Array = data.raw.get("headers", [])
	var rows: Array = data.raw.get("rows", [])
	var show_labels: bool = data.raw.get("show_labels", true)

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	if show_labels and not headers.is_empty():
		for header in headers:
			var h := ExerciseTheme.make_label(get_en_text(header), "body_small", "primary", true)
			h.set_meta("text_fa", get_fa_text(header))
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(h)

	for row in rows:
		var cells: Array = row.get("cells", [])
		for cell in cells:
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 4)
			cell_box.alignment = BoxContainer.ALIGNMENT_CENTER
			cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell_box)

			if cell.get("editable", false):
				var placeholder: String = get_en_text(cell.get("placeholder", "..."))
				var le := make_chart_input(placeholder, gesture_handler)
				cell_box.add_child(le)
				var fb := make_feedback(cell_box)
				var item_data := ExerciseData.Item.new("chart_fill", _get_text_func(le), cell.get("answer", []), fb)
				item_data.explanation_en = get_en_text(cell.get("explanation", {}))
				item_data.explanation_fa = get_fa_text(cell.get("explanation", {}))
				items.append(item_data)
			else:
				var text_val: Dictionary = cell.get("text", {})
				var lbl := ExerciseTheme.make_label(get_en_text(text_val), "body_small", "text", false)
				lbl.set_meta("text_fa", get_fa_text(text_val))
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(lbl)

func _get_text_func(le: LineEdit) -> Callable:
	return func(): return le.text
