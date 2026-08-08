class_name ExerciseBuilder
extends RefCounted

## Base class / Interface for all exercise builders.
## Provides common UI widget factories and helper methods used by specific builders.

# Virtual method to be overridden by specific builders (e.g., MultipleChoiceBuilder)
func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	push_error("ExerciseBuilder.build() must be overridden in subclass.")

# ==========================================
# TEXT & DATA HELPERS
# ==========================================

func get_en_text(val: Variant) -> String:
	return ExerciseData.get_en_text(val)

func get_fa_text(val: Variant) -> String:
	return ExerciseData.get_fa_text(val)

func get_item_main_text(item: Dictionary) -> String:
	for key in ["question", "prompt", "text", "statement", "sentence", "title", "word", "active"]:
		if item.has(key):
			var val := get_en_text(item.get(key))
			if val != "":
				return val
	return ""

func get_option_text(opt: Variant) -> String:
	if opt is Dictionary:
		if opt.has("en") or opt.has("fa"):
			return get_en_text(opt)
		for key in ["label", "text", "title", "name", "id"]:
			if opt.has(key):
				return get_en_text(opt.get(key))
		return ""
	return str(opt)

func find_option_index(options: Array, value: Variant) -> int:
	var s := str(value)
	for i in options.size():
		var opt = options[i]
		if opt is Dictionary and str(opt.get("id", "")) == s:
			return i
		if ExerciseData.normalize(get_option_text(opt)) == ExerciseData.normalize(s):
			return i
	return -1

func format_answer(answer: Variant) -> String:
	if answer is Array:
		var parts: Array = []
		for a in answer:
			parts.append(format_answer(a))
		return " / ".join(parts)
	if answer is bool:
		return "True" if answer else "False"
	if answer is Dictionary:
		return get_en_text(answer)
	if answer == null:
		return ""
	return str(answer)

# ==========================================
# LAYOUT & WIDGET FACTORIES
# ==========================================

func create_item_container(parent: VBoxContainer) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", ExerciseTheme.SPACING.tight)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(vbox)
	return vbox

func make_feedback(parent: Node) -> Label:
	var fb := Label.new()
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.autowrap_mode = TextServer.AUTOWRAP_WORD
	fb.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.hint)
	fb.visible = false
	if ExerciseTheme.font_bold:
		fb.add_theme_font_override("font", ExerciseTheme.font_bold)
	parent.add_child(fb)
	return fb

func make_line_edit(placeholder: String, gesture_handler: ExerciseGestureHandler) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.input)
	le.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	le.add_theme_color_override("font_placeholder_color", ExerciseTheme.COLORS.muted)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if ExerciseTheme.font_regular:
		le.add_theme_font_override("font", ExerciseTheme.font_regular)
		
	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color("#0f1b3d")
	le_style.set_corner_radius_all(10)
	le_style.border_width_bottom = 2
	le_style.border_color = ExerciseTheme.COLORS.primary.lightened(0.3)
	le_style.set_content_margin_all(ExerciseTheme.PADDING.input)
	le.add_theme_stylebox_override("normal", le_style)
	
	var le_hover: StyleBoxFlat = le_style.duplicate()
	le_hover.border_color = ExerciseTheme.COLORS.primary
	le.add_theme_stylebox_override("hover", le_hover)
	
	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = ExerciseTheme.COLORS.primary
	le.add_theme_stylebox_override("focus", le_focus)
	le.add_theme_color_override("caret_color", ExerciseTheme.COLORS.primary)
	
	# Register with gesture handler to prevent scroll/keyboard conflicts
	gesture_handler.register_control(le)
	return le

func make_option_dropdown(options: Array, gesture_handler: ExerciseGestureHandler, placeholder := "Choose") -> ExerciseDropdown:
	var dd := ExerciseDropdown.new()
	dd.mouse_filter = Control.MOUSE_FILTER_PASS
	dd.placeholder = placeholder
	dd.set_font(ExerciseTheme.font_regular)
	for opt in options:
		dd.add_item(str(opt))
	dd.selected = 0
	dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	gesture_handler.register_control(dd)
	return dd

func make_select_button(text: String, group: ButtonGroup, accent: Color, gesture_handler: ExerciseGestureHandler) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = "    " + text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.body)
	b.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#0f1b3d")
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(1)
	normal.border_color = Color("#3d4a7a")
	normal.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", normal)
	
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	hover.border_color = accent.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)
	
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	pressed.border_color = accent
	pressed.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", pressed)
	
	if ExerciseTheme.font_regular:
		b.add_theme_font_override("font", ExerciseTheme.font_regular)
		
	gesture_handler.register_control(b)
	return b

# ==========================================
# ADD THESE TO ExerciseBuilder.gd
# ==========================================

func add_item_media(item: Dictionary, parent: Control, data: ExerciseData) -> void:
	if item.has("images"):
		for img in item.get("images", []):
			parent.add_child(make_media_control(img, parent, data))
	elif item.has("image"):
		parent.add_child(make_media_control(item.get("image"), parent, data))

func make_media_control(img_data: Variant, parent: Control, data: ExerciseData) -> Control:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var path := ""
	var caption := ""
	var max_width := int(data.raw.get("image_max_width", 360))
	var min_height := int(data.raw.get("image_min_height", 180))

	if img_data is Dictionary:
		path = str(img_data.get("path", img_data.get("image", "")))
		caption = get_en_text(img_data.get("caption", ""))
		max_width = int(img_data.get("max_width", max_width))
		min_height = int(img_data.get("min_height", min_height))
	else:
		path = str(img_data)

	max_width = safe_media_width(max_width, parent)

	if path == "":
		vbox.add_child(ExerciseTheme.make_label("Image placeholder", "tiny", "muted", false))
		return vbox

	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			img.custom_minimum_size = Vector2(max_width, min_height)
			img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

			var center := HBoxContainer.new()
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.alignment = BoxContainer.ALIGNMENT_CENTER
			center.add_child(img)
			vbox.add_child(center)

			if caption != "":
				var cap := ExerciseTheme.make_label(caption, "tiny", "muted", false)
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(cap)
			return vbox

	vbox.add_child(ExerciseTheme.make_label("Image not found: " + path.get_file(), "tiny", "muted", false))
	return vbox

func get_viewport_width(parent: Control) -> float:
	if parent != null and parent.is_inside_tree():
		var vp := parent.get_viewport()
		if vp != null:
			var w := vp.get_visible_rect().size.x
			if w > 0.0:
				return w
	return 1280.0

func safe_media_width(requested: int, parent: Control) -> int:
	var max_allowed := int(get_viewport_width(parent)) - 80
	return clampi(requested, 120, maxi(max_allowed, 160))

func compile_patterns(patterns: Array) -> Array[RegEx]:
	var compiled: Array[RegEx] = []
	for pat in patterns:
		var rx := RegEx.new()
		if rx.compile(str(pat)) == OK:
			compiled.append(rx)
	return compiled

# Converts an int index or a string "id" into the display text used for grading.
func resolve_dropdown_answer(answer: Variant, options: Array, option_texts: Array) -> Variant:
	if answer is int and answer >= 0 and answer < option_texts.size():
		return option_texts[answer]
	elif answer is String:
		for opt in options:
			if opt is Dictionary and str(opt.get("id", "")) == str(answer):
				return get_option_text(opt)
	return answer

# Returns a Callable that reads the user's current dropdown selection at grading time.
func get_dropdown_answer_func(ob: ExerciseDropdown) -> Callable:
	return func():
		if ob.selected > 0:
			return ob.get_item_text(ob.selected)
		return ""

func make_chip_button(text: String, filled := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = text
	b.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.body_small)
	b.add_theme_color_override("font_color", Color("#000000") if filled else ExerciseTheme.COLORS.text)
	b.add_theme_color_override("font_hover_color", Color("#000000") if filled else ExerciseTheme.COLORS.primary)
	if ExerciseTheme.font_regular:
		b.add_theme_font_override("font", ExerciseTheme.font_regular)

	var style := StyleBoxFlat.new()
	style.bg_color = ExerciseTheme.COLORS.primary if filled else Color("#0f1b3d")
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = ExerciseTheme.COLORS.primary if filled else Color("#3d4a7a")
	style.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)

	var disabled: StyleBoxFlat = style.duplicate()
	disabled.bg_color = Color("#1a2540")
	disabled.border_color = Color("#2d3a6a")
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color("#4a5580"))
	return b

func make_chart_input(placeholder: String, gesture_handler: ExerciseGestureHandler) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.body_small)
	le.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	le.add_theme_color_override("font_placeholder_color", ExerciseTheme.COLORS.muted)
	le.add_theme_color_override("caret_color", ExerciseTheme.COLORS.primary)
	le.add_theme_color_override(
		"selection_color",
		Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.35)
	)
	le.add_theme_color_override("font_selected_color", Color.WHITE)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ExerciseTheme.font_regular:
		le.add_theme_font_override("font", ExerciseTheme.font_regular)

	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color("#0f1b3d")
	le_style.set_corner_radius_all(8)
	le_style.border_width_bottom = 2
	le_style.border_color = Color("#3d4a7a")
	le_style.set_content_margin_all(10)
	le.add_theme_stylebox_override("normal", le_style)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = ExerciseTheme.COLORS.primary
	le.add_theme_stylebox_override("focus", le_focus)

	gesture_handler.register_control(le)
	return le

func make_checkbox(text: String, gesture_handler: ExerciseGestureHandler) -> CheckBox:
	var cb := CheckBox.new()
	cb.mouse_filter = Control.MOUSE_FILTER_PASS
	cb.text = text
	cb.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.checkbox)
	if ExerciseTheme.font_regular:
		cb.add_theme_font_override("font", ExerciseTheme.font_regular)
	gesture_handler.register_control(cb)
	return cb


func make_word_toggle(word: String, gesture_handler: ExerciseGestureHandler, compact := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = word
	b.toggle_mode = true
	if compact:
		b.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.hint)
		b.custom_minimum_size = Vector2(36, 44)
	else:
		b.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.body)
	b.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	b.add_theme_color_override("font_pressed_color", Color("#000000"))
	b.add_theme_color_override("font_hover_color", ExerciseTheme.COLORS.primary)
	if ExerciseTheme.font_regular:
		b.add_theme_font_override("font", ExerciseTheme.font_regular)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(3 if compact else 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal.duplicate())

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = ExerciseTheme.COLORS.warning
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(3 if compact else 6)
	b.add_theme_stylebox_override("pressed", pressed)

	gesture_handler.register_control(b)
	return b

func normalize_categories(raw: Array) -> Array:
	var out: Array = []
	var default_colors := [
		Color("#2563EB"), Color("#16A34A"), Color("#DC2626"),
		Color("#F59E0B"), Color("#7C3AED"), Color("#0891B2"),
	]
	for i in raw.size():
		var c = raw[i]
		var id := ""
		var label := ""
		var color: Color = default_colors[i % default_colors.size()]
		if c is Dictionary:
			id = str(c.get("id", c.get("label", "cat%d" % i)))
			label = get_en_text(c.get("label", id))
			if c.has("color"):
				color = Color(str(c.get("color")))
		else:
			id = str(c)
			label = str(c)
		if label == "":
			label = id
		out.append({"id": id, "label": label, "color": color})
	return out

func category_id_from_value(val: Variant, categories: Array) -> String:
	var s := str(val)
	if s == "":
		return ""
	for c in categories:
		if s == str(c["id"]) or ExerciseData.normalize(s) == ExerciseData.normalize(str(c["label"])):
			return str(c["id"])
	return s

func get_category_color(cat_id: String, categories: Array) -> Color:
	for c in categories:
		if str(c["id"]) == cat_id:
			return c["color"]
	return ExerciseTheme.COLORS.primary

# ==========================================
# ADD THESE TO ExerciseBuilder.gd
# ==========================================

func make_text_edit(gesture_handler: ExerciseGestureHandler) -> TextEdit:
	var te := TextEdit.new()
	te.mouse_filter = Control.MOUSE_FILTER_PASS
	te.placeholder_text = "Write your answer here..."
	te.custom_minimum_size = Vector2(0, 180)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.input)
	te.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	te.add_theme_color_override("font_placeholder_color", ExerciseTheme.COLORS.muted)
	te.add_theme_color_override("caret_color", ExerciseTheme.COLORS.primary)
	te.add_theme_color_override(
		"selection_color",
		Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.35)
	)
	te.add_theme_color_override("font_selected_color", Color.WHITE)
	if ExerciseTheme.font_regular:
		te.add_theme_font_override("font", ExerciseTheme.font_regular)

	var te_style := StyleBoxFlat.new()
	te_style.bg_color = Color("#0f1b3d")
	te_style.set_corner_radius_all(10)
	te_style.border_width_bottom = 2
	te_style.border_color = Color("#3d4a7a")
	te_style.set_content_margin_all(ExerciseTheme.PADDING.input)
	te.add_theme_stylebox_override("normal", te_style)

	var te_focus: StyleBoxFlat = te_style.duplicate()
	te_focus.border_color = ExerciseTheme.COLORS.primary
	te.add_theme_stylebox_override("focus", te_focus)

	gesture_handler.register_control(te)
	return te

# Shared answer-getters for text inputs (used by many builders)
func get_line_answer_func(le: LineEdit) -> Callable:
	return func(): return le.text

func get_text_edit_answer_func(te: TextEdit) -> Callable:
	return func(): return te.text

# Override in builders that need non-standard grading (e.g., word_search).
func handles_custom_grading() -> bool:
	return false

# Override to perform custom grading and return a result.
# Called by the Engine only when handles_custom_grading() returns true.
func grade_custom(items: Array[ExerciseData.Item]) -> ExerciseGrader.Result:
	return null

# ==========================================
# ADD THESE TO ExerciseBuilder.gd
# ==========================================

func make_image_option_button(opt: Variant, group: ButtonGroup, gesture_handler: ExerciseGestureHandler) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(190, 160)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = get_option_text(opt)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.hint)
	b.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	b.add_theme_color_override("font_hover_color", ExerciseTheme.COLORS.primary)
	b.add_theme_color_override("font_pressed_color", ExerciseTheme.COLORS.primary)

	if opt is Dictionary:
		var path := str(opt.get("image", opt.get("path", "")))
		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				b.icon = tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#0f1b3d")
	normal.set_corner_radius_all(12)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#3d4a7a")
	normal.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.07)
	hover.border_color = ExerciseTheme.COLORS.primary.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.14)
	pressed.border_color = ExerciseTheme.COLORS.primary
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pressed)

	if ExerciseTheme.font_regular:
		b.add_theme_font_override("font", ExerciseTheme.font_regular)

	gesture_handler.register_control(b)
	return b

func get_first_image_path(raw: Dictionary) -> String:
	if raw.has("image"):
		var img = raw["image"]
		if img is Dictionary:
			return str(img.get("path", img.get("image", "")))
		return str(img)
	var imgs: Array = raw.get("images", [])
	if imgs.size() > 0:
		var img = imgs[0]
		if img is Dictionary:
			return str(img.get("path", img.get("image", "")))
		return str(img)
	return ""
