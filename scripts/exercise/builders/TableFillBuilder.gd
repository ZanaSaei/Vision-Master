class_name TableFillBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var columns: Array = data.raw.get("columns", [])

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(columns.size(), 1)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	for col in columns:
		var h := ExerciseTheme.make_label(get_en_text(col), "body_small", "muted", true)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)

	for row in data.raw.get("rows", []):
		for cell in row.get("cells", []):
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 6)
			cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell_box)

			if cell.get("editable", false):
				var le := make_line_edit("...", gesture_handler)
				cell_box.add_child(le)
				var fb := make_feedback(cell_box)
				var item_data := ExerciseData.Item.new("fill_blank", _get_text_func(le), cell.get("answer", []), fb)
				items.append(item_data)
			else:
				var lbl := ExerciseTheme.make_label(get_en_text(cell.get("text", "")), "body", "text", false)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(lbl)

func _get_text_func(le: LineEdit) -> Callable:
	return func(): return le.text
