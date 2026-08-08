class_name ExerciseDropdown
extends Button

## Custom dropdown widget extracted from ExerciseEngine.
## Uses ExerciseTheme for centralized styling and handles its own popup lifecycle.

signal item_selected(index: int)

var selected: int = 0
var placeholder := "Choose"

var _options: Array = []
var _font: Font
var _popup: PopupPanel
var _scroll: ScrollContainer
var _list: VBoxContainer

const _MAX_W := 900
const _MIN_W := 360
const _MAX_H := 560
const _PAD_L := 16
const _PAD_R := 14
const _PAD_V := 10

func set_font(f: Font) -> void:
	_font = f

func add_item(label: String) -> void:
	_options.append(label)

func get_item_text(index: int) -> String:
	if index <= 0 or index > _options.size():
		return "— " + placeholder + " —"
	return str(_options[index - 1])

func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	
	add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.input)
	add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	add_theme_color_override("font_hover_color", ExerciseTheme.COLORS.primary)
	
	if _font:
		add_theme_font_override("font", _font)
		
	# Base Button Styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f1b3d")
	style.set_corner_radius_all(10)
	style.border_width_bottom = 2
	style.border_color = ExerciseTheme.COLORS.primary.lightened(0.3)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("normal", style)
	
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = ExerciseTheme.COLORS.primary
	add_theme_stylebox_override("hover", hover)
	
	var pressed_style: StyleBoxFlat = hover.duplicate()
	pressed_style.bg_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.1)
	add_theme_stylebox_override("pressed", pressed_style)
	
	_build_popup()
	_refresh_face()
	
	pressed.connect(_open_popup)

func _build_popup() -> void:
	_popup = PopupPanel.new()
	
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#0f1b3d")
	panel.set_corner_radius_all(14)
	panel.set_border_width_all(1)
	panel.border_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.4)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 16
	panel.shadow_offset = Vector2(0, 8)
	panel.set_content_margin_all(8)
	_popup.add_theme_stylebox_override("panel", panel)
	
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_popup.add_child(_scroll)
	
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	
	add_child(_popup)
	_popup.about_to_popup.connect(_on_about_to_popup)

func _open_popup() -> void:
	var btn_rect := get_global_rect()
	var f: Font = _font if _font else ThemeDB.fallback_font
	var item_font_size: int = ExerciseTheme.FONT_SIZES.input
	
	# Calculate required width based on longest text
	var longest := 0.0
	for opt in _options:
		longest = maxf(longest, f.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, item_font_size).x)
		
	var vp_w := 1280.0
	var vp := get_viewport()
	if vp != null:
		vp_w = vp.get_visible_rect().size.x
		
	var max_w := minf(float(_MAX_W), vp_w - 24.0)
	var w := clampi(int(maxf(btn_rect.size.x, longest + 70.0)), _MIN_W, int(max_w))
	var wrap_w := float(w - 16 - 10 - _PAD_L - _PAD_R)
	
	_populate(wrap_w)
	
	var content_h := int(_list.get_combined_minimum_size().y) + 16
	var h := mini(content_h, _MAX_H)
	_scroll.custom_minimum_size = Vector2(w - 16, h - 16)
	
	var x := clampi(int(btn_rect.position.x), 8, int(vp_w - w - 8))
	_popup.popup(Rect2i(
		Vector2i(x, int(btn_rect.end.y + 8)),
		Vector2i(w, h)
	))

func _populate(wrap_w: float) -> void:
	# Clear existing items safely
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
		
	var f: Font = _font if _font else ThemeDB.fallback_font
	var item_font_size: int = ExerciseTheme.FONT_SIZES.input
	
	var labels := ["— " + placeholder + " —"]
	labels.append_array(_options)
	
	for i in labels.size():
		var is_sel := (i == selected)
		var is_placeholder := (i == 0)
		var display: String = ("✓  " + str(labels[i])) if is_sel else str(labels[i])
		
		var row := Button.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = f.get_multiline_string_size(
			display,
			HORIZONTAL_ALIGNMENT_LEFT,
			wrap_w,
			item_font_size
		).y + _PAD_V * 2
		
		var normal := StyleBoxFlat.new()
		if is_sel:
			normal.bg_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.2)
		else:
			normal.bg_color = Color(0, 0, 0, 0)
		normal.set_corner_radius_all(8)
		
		if is_sel:
			normal.border_width_left = 3
			normal.border_color = ExerciseTheme.COLORS.primary
		row.add_theme_stylebox_override("normal", normal)
		
		var hover_style: StyleBoxFlat = normal.duplicate()
		if is_sel:
			hover_style.bg_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.16)
		else:
			hover_style.bg_color = Color(ExerciseTheme.COLORS.primary.r, ExerciseTheme.COLORS.primary.g, ExerciseTheme.COLORS.primary.b, 0.08)
		row.add_theme_stylebox_override("hover", hover_style)
		row.add_theme_stylebox_override("pressed", hover_style)
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		var lbl := Label.new()
		lbl.text = display
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", item_font_size)
		
		var base_color: Color = ExerciseTheme.COLORS.muted if is_placeholder else ExerciseTheme.COLORS.text
		lbl.add_theme_color_override("font_color", base_color)
		
		if _font:
			lbl.add_theme_font_override("font", _font)
			
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.offset_left = _PAD_L
		lbl.offset_right = -_PAD_R
		lbl.offset_top = _PAD_V
		lbl.offset_bottom = -_PAD_V
		
		row.add_child(lbl)
		row.pressed.connect(_on_row_pressed.bind(i))
		
		# Hover effects for text color
		row.mouse_entered.connect(func():
			lbl.add_theme_color_override("font_color", ExerciseTheme.COLORS.primary)
		)
		row.mouse_exited.connect(func():
			lbl.add_theme_color_override("font_color", base_color)
		)
		
		_list.add_child(row)

func _on_about_to_popup() -> void:
	# Staggered fade-in animation for dropdown items
	var tw := create_tween().set_parallel(true)
	var rows := _list.get_children()
	for i in rows.size():
		var r: Control = rows[i]
		r.modulate.a = 0.0
		tw.tween_property(r, "modulate:a", 1.0, 0.12).set_delay(i * 0.02)

func _on_row_pressed(index: int) -> void:
	selected = index
	_refresh_face()
	_popup.hide()
	item_selected.emit(index)

func _refresh_face() -> void:
	text = get_item_text(selected) + "   ▾"
