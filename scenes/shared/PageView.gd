class_name PageView
extends Control
## ============================================================
## REUSABLE SWIPEABLE PAGE CONTAINER
## Drop into any scene, call add_page(), done.
## Features: sliding tab pill, swipe gestures (with edge damping),
##           animated dots, per-page scrolling, indicator follows drag.
## ============================================================

signal page_changed(index: int, page_id: String)

# ---------- Theme ----------
const TEXT_MUTED := Color("#94A3B8")      # Muted light for inactive tabs
const TAB_BAR_BG := Color("#0f1b3d")      # Dark tab bar
const DOT_OFF := Color("#3d4a7a")          # Darker inactive dots
const FONT_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
var _accent: Color = Color("#22D3EE")      # Default accent
var font_bold: FontFile

# ---------- State ----------
var _pages: Array = []          # {id, title, icon, scroll}
var _current: int = 0
var _page_width: float = 0.0
var _touch_active: bool = false

# ---------- Nodes ----------
var _vbox: VBoxContainer
var _tab_inner: Control
var _indicator: Panel
var _tabs_hbox: HBoxContainer
var _viewport: Control
var _slider: HBoxContainer
var _dots_row: HBoxContainer
var _tab_buttons: Array = []
var _dot_controls: Array = []

# ---------- Drag ----------
var _touch_start: Vector2 = Vector2.ZERO
var _axis: int = 0              # 0 undecided, 1 horizontal, 2 vertical
var _dragging: bool = false
var _drag_offset: float = 0.0


func _ready() -> void:
	font_bold = load(FONT_BOLD_PATH)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_skeleton()
	_viewport.resized.connect(_refresh_layout)
	
	# Reposition indicator whenever tab button rects are calculated/sorted
	_tabs_hbox.sort_children.connect(func(): _set_indicator_to(float(_current)))
	call_deferred("_refresh_layout")


func _build_skeleton() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 0)
	add_child(_vbox)
	
	var tab_bar := PanelContainer.new()
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = TAB_BAR_BG
	tab_style.set_content_margin_all(12)
	tab_style.border_width_bottom = 2
	tab_style.border_color = Color("#2d3a6a")  # Subtle dark border
	tab_bar.add_theme_stylebox_override("panel", tab_style)
	_vbox.add_child(tab_bar)
	
	_tab_inner = Control.new()
	_tab_inner.custom_minimum_size = Vector2(0, 64)
	tab_bar.add_child(_tab_inner)
	
	_indicator = Panel.new()
	var ind_style := StyleBoxFlat.new()
	ind_style.bg_color = _accent
	ind_style.set_corner_radius_all(16)
	_indicator.add_theme_stylebox_override("panel", ind_style)
	_tab_inner.add_child(_indicator)
	
	_tabs_hbox = HBoxContainer.new()
	_tabs_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tabs_hbox.add_theme_constant_override("separation", 6)
	_tab_inner.add_child(_tabs_hbox)
	
	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_viewport)
	
	_slider = HBoxContainer.new()
	_slider.add_theme_constant_override("separation", 0)
	_viewport.add_child(_slider)
	
	_dots_row = HBoxContainer.new()
	_dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_row.add_theme_constant_override("separation", 12)
	_dots_row.custom_minimum_size = Vector2(0, 40)
	_vbox.add_child(_dots_row)

# ============================================================
# PUBLIC API
# ============================================================
func add_page(id: String, title: String, icon: String, content: Control) -> void:
	# Wrap content in its own vertical scroller + padding
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	_slider.add_child(scroll)
	
	_pages.append({"id": id, "title": title, "icon": icon, "scroll": scroll})
	
	# Tab button (flat — the sliding pill provides the highlight)
	var btn := Button.new()
	btn.text = (icon + "  " + title) if icon != "" else title
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 31)
	btn.add_theme_color_override("font_color", TEXT_MUTED)
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if font_bold: btn.add_theme_font_override("font", font_bold)
	var page_index := _pages.size() - 1
	btn.pressed.connect(func(): go_to_page(page_index))
	_tabs_hbox.add_child(btn)
	_tab_buttons.append(btn)
	
	# Dot
	var dot := Panel.new()
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = DOT_OFF
	d_style.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", d_style)
	dot.custom_minimum_size = Vector2(12, 12)
	_dots_row.add_child(dot)
	_dot_controls.append(dot)
	
	_refresh_layout()
	if _pages.size() == 1:
		go_to_page(0, false)


func go_to_page(index: int, animate := true) -> void:
	if _pages.is_empty(): return
	index = clampi(index, 0, _pages.size() - 1)
	_current = index
	_page_width = _viewport.size.x
	var target_x := -index * _page_width
	
	if animate and _page_width > 0.0:
		var t := create_tween()
		t.tween_property(_slider, "position:x", target_x, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_animate_indicator_to(float(index))
	else:
		_slider.position.x = target_x
		_set_indicator_to(float(index))
	
	_update_tabs(index)
	_update_dots(index)
	page_changed.emit(index, _pages[index]["id"])


func get_current_page() -> int:
	return _current


func set_accent(color: Color) -> void:
	_accent = color
	var ind_style := StyleBoxFlat.new()
	ind_style.bg_color = _accent
	ind_style.set_corner_radius_all(16)
	_indicator.add_theme_stylebox_override("panel", ind_style)
	_update_tabs(_current)
	_update_dots(_current)


# ============================================================
# LAYOUT
# ============================================================
func _refresh_layout() -> void:
	_page_width = _viewport.size.x
	if _page_width <= 0.0 or _pages.is_empty(): return
	_slider.size = Vector2(_page_width * _pages.size(), _viewport.size.y)
	for page in _pages:
		page["scroll"].custom_minimum_size = Vector2(_page_width, 0)
		page["scroll"].clip_contents = true
	_slider.position.x = -_current * _page_width
	_set_indicator_to(float(_current))


# ============================================================
# INDICATOR (sliding pill)
# ============================================================
func _indicator_rect_for(float_index: float) -> Rect2:
	if _tab_buttons.is_empty(): return Rect2()
	var i0 := clampi(floori(float_index), 0, _tab_buttons.size() - 1)
	var i1 := clampi(ceili(float_index), 0, _tab_buttons.size() - 1)
	var t : float = float_index - floor(float_index)
	var r0: Rect2 = _tab_buttons[i0].get_rect()
	var r1: Rect2 = _tab_buttons[i1].get_rect()
	var x := lerpf(r0.position.x, r1.position.x, t)
	var w := lerpf(r0.size.x, r1.size.x, t)
	var h := 48.0
	var y := (r0.position.y + r0.size.y / 2.0) - h / 2.0
	return Rect2(x, y, w, h)


func _set_indicator_to(float_index: float) -> void:
	var r := _indicator_rect_for(float_index)
	_indicator.position = r.position
	_indicator.size = r.size


func _animate_indicator_to(float_index: float) -> void:
	var r := _indicator_rect_for(float_index)
	var t : Tween = create_tween().set_parallel(true)
	t.tween_property(_indicator, "position", r.position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_indicator, "size", r.size, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# TABS & DOTS
# ============================================================
func _update_tabs(active: int) -> void:
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var target: Color = Color.WHITE if i == active else TEXT_MUTED
		var t := create_tween()
		t.tween_property(btn, "theme_override_colors/font_color", target, 0.25)

func _update_dots(active: int) -> void:
	for i in _dot_controls.size():
		var dot: Panel = _dot_controls[i]
		var is_active := i == active
		var style := StyleBoxFlat.new()
		style.bg_color = _accent if is_active else DOT_OFF
		style.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", style)
		var target_size := Vector2(30, 12) if is_active else Vector2(12, 12)
		var t := create_tween()
		t.tween_property(dot, "custom_minimum_size", target_size, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# SWIPE GESTURES
# ============================================================
func _input(event: InputEvent) -> void:
	if _pages.size() <= 1 or _page_width <= 0.0: return
	var vp_rect := _viewport.get_global_rect()

	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			if vp_rect.has_point(event.position) and not _is_touch_blocked(event.position):
				_touch_start = event.position
				_axis = 0
				_dragging = false
				_drag_offset = 0.0
				_touch_active = true
			else:
				# Press landed on a blocker (HeaderBar, AudioPanel…) or outside:
				# disown this gesture so its drag events are ignored.
				_touch_active = false
				_dragging = false
				_axis = 2
		else:
			if _dragging and _axis == 1:
				_finish_drag()
			_dragging = false
			_axis = 0
			_touch_active = false

	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		if not _touch_active or _axis == 2: return   # not our gesture → ignore entirely
		if _axis == 0:
			var delta : Vector2 = event.position - _touch_start
			if abs(delta.x) > 14 or abs(delta.y) > 14:
				if abs(delta.x) > abs(delta.y) * 1.1:
					_axis = 1
					_dragging = true
				else:
					_axis = 2
					return
		if _dragging and _axis == 1:
			get_viewport().set_input_as_handled()
			var delta_x : float = event.position.x - _touch_start.x
			# Rubber-band at the edges
			var proposed := _current * _page_width - delta_x
			if proposed < 0.0 or proposed > (_pages.size() - 1) * _page_width:
				delta_x *= 0.35
			_slider.position.x = -_current * _page_width + delta_x
			_drag_offset = delta_x
			var float_index := clampf(-_slider.position.x / _page_width, 0.0, float(_pages.size() - 1))
			_set_indicator_to(float_index)

func _finish_drag() -> void:
	var threshold := _page_width * 0.25
	var target := _current
	if _drag_offset < -threshold:
		target = _current + 1
	elif _drag_offset > threshold:
		target = _current - 1
	go_to_page(target)

# ---------- Blocker Panels ----------
var _swipe_blockers: Array[Control] = []

func add_swipe_blocker(control: Control) -> void:
	if control and not _swipe_blockers.has(control):
		_swipe_blockers.append(control)

func _is_touch_blocked(global_pos: Vector2) -> bool:
	for blocker in _swipe_blockers:
		if is_instance_valid(blocker) and blocker.is_visible_in_tree():
			if blocker.get_global_rect().has_point(global_pos):
				return true
	return false
