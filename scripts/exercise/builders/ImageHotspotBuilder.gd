class_name ImageHotspotBuilder
extends ExerciseBuilder

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	var img_path := get_first_image_path(data.raw)
	if img_path == "" or not ResourceLoader.exists(img_path):
		parent.add_child(ExerciseTheme.make_label("Image not found: " + img_path, "hint", "error", false))
		return

	var tex := load(img_path) as Texture2D
	if tex == null:
		parent.add_child(ExerciseTheme.make_label("Could not load image: " + img_path, "hint", "error", false))
		return

	var base_size: Vector2 = tex.get_size()
	if base_size.x <= 0:
		base_size.x = 900
	if base_size.y <= 0:
		base_size.y = 600

	# Compute a safe display width that fits the viewport
	var max_width := minf(float(data.raw.get("max_width", 900)), get_viewport_width(parent) - 72.0)
	max_width = maxf(max_width, 200.0)
	var ratio := max_width / base_size.x

	# Container that holds both the image and the hotspot overlay
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(max_width, base_size.y * ratio)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ctrl)

	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.anchor_left = 0.0
	img.anchor_top = 0.0
	img.anchor_right = 1.0
	img.anchor_bottom = 1.0
	img.offset_left = 0.0
	img.offset_top = 0.0
	img.offset_right = 0.0
	img.offset_bottom = 0.0
	ctrl.add_child(img)

	var overlay := HotspotOverlay.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.base_size = base_size
	overlay.hotspots = data.raw.get("hotspots", [])

	# Resolve answer ids (single value or array)
	var answer_ids: Array = []
	var ans_raw: Variant = data.raw.get("answer", [])
	if ans_raw is Array:
		for a in ans_raw:
			answer_ids.append(str(a))
	else:
		answer_ids.append(str(ans_raw))

	overlay.multi = bool(data.raw.get("multi", answer_ids.size() != 1))
	ctrl.add_child(overlay)

	var fb := make_feedback(parent)
	var item_data := ExerciseData.Item.new(
		"image_hotspot",
		func(): return overlay.selected.duplicate(),
		answer_ids,
		fb
	)
	item_data.answer_display = ", ".join(answer_ids)
	item_data.explanation_en = get_en_text(data.raw.get("explanation", ""))
	item_data.explanation_fa = get_fa_text(data.raw.get("explanation", ""))
	items.append(item_data)
