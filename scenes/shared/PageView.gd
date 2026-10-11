class_name PageView
extends Control

# ============================================================
# REUSABLE SWIPEABLE PAGE CONTAINER
# ------------------------------------------------------------
# Updated version includes:
# - Dark-theme harmony for PageView itself.
# - Smooth vertical finger scrolling for the current page.
# - Horizontal page swiping with edge damping.
# - Tab titles kept on one line and filled horizontally.
# ============================================================

signal page_changed(index: int, page_id: String)

# ---------- Theme ----------
# Colors are read from Global.get_theme_color(...) at build/rebuild time so
# the component follows the app-wide light/dark theme. No hardcoded fallback
# palette is kept here.
const FONT_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"

var _accent: Color = Color("#22D3EE")
var font_bold: FontFile

# Tab label typography. Adjustable per-instance so a scene (e.g. Workbook
# with many tabs) can fall back to smaller sizing and avoid clipping.
var tab_font_size := 40
var tab_font_min := 30
var tab_font_padding := 34.0

# ---------- State ----------
var _pages: Array = []
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

# ---------- Themeable styleboxes / nodes ----------
var _bg: Panel
var _tab_bar: PanelContainer
var _bg_style: StyleBoxFlat
var _tab_style: StyleBoxFlat
var _ind_style: StyleBoxFlat
var _dots_panel: PanelContainer
var _dots_panel_style: StyleBoxFlat

# ---------- Drag / Swipe ----------
var _touch_start: Vector2 = Vector2.ZERO
var _axis: int = 0              # 0 undecided, 1 horizontal, 2 vertical
var _dragging: bool = false
var _drag_offset: float = 0.0

# Gesture thresholds.
const _GESTURE_THRESHOLD := 24.0
const _HOLD_MAX_MSEC := 350

# Press timing for long-press prevention.
var _press_time_msec := 0
var _gesture_blocked := false

# ---------- Smooth vertical scrolling ----------
var _v_drag_active := false
var _v_last_y := 0.0
var _v_last_time_msec := 0
var _v_velocity := 0.0
var _scroll_tween: Tween

# ---------- Swipe blockers ----------
var _swipe_blockers: Array[Control] = []
var _audio_panel_clearance: float = 0.0
var _audio_panel_open: bool = false


func _ready() -> void:
	font_bold = load(FONT_BOLD_PATH)

	mouse_filter = Control.MOUSE_FILTER_PASS

	# Apply the app-wide base theme (correct for the current light/dark mode).
	_apply_page_theme()

	_build_skeleton()

	# Build the scene-specific styleboxes from the palette and follow theme changes.
	_apply_theme()
	Global.on_theme_changed(_apply_theme)

	_viewport.resized.connect(_refresh_layout)
	_tab_inner.resized.connect(_refresh_tab_fit)

	# Reposition indicator whenever tab button rects are calculated/sorted.
	_tabs_hbox.sort_children.connect(func(): _set_indicator_to(float(_current)))

	call_deferred("_refresh_layout")

func _cancel_exercise_gestures() -> void:
	# Tell ExerciseEngine instances to cancel any active button/text-field gesture.
	if _gesture_blocked:
		return

	_gesture_blocked = true
	get_tree().call_group("exercise_engines", "cancel_active_gesture")


func _reset_exercise_gestures() -> void:
	# Tell ExerciseEngine instances that the consumed gesture has finished.
	_gesture_blocked = false
	get_tree().call_group("exercise_engines", "reset_active_gesture")

func _apply_page_theme() -> void:
	# Follow the app-wide base theme (already correct for the current mode)
	# instead of a hardcoded dark fallback. The base theme styles all child
	# controls (text, panels, popups, input fields) automatically. Only the
	# scene-specific styleboxes below are rebuilt from the palette.
	theme = Global.get_base_theme()


func _apply_theme() -> void:
	# Restyle hook: rebuild the scene-specific styleboxes from the palette and
	# re-apply the base theme. Connected to Global.on_theme_changed for live
	# toggling, and called once after the skeleton is built in _ready().
	if not is_inside_tree():
		return

	theme = Global.get_base_theme()

	# Background panel.
	if _bg_style != null:
		_bg_style.bg_color = Global.get_theme_color("bg_base")
	if _bg != null:
		_bg.add_theme_stylebox_override("panel", _bg_style)

	# Tab bar.
	if _tab_style != null:
		_tab_style.bg_color = Global.get_theme_color("surface")
		_tab_style.border_color = Global.get_theme_color("border")
	if _tab_bar != null:
		_tab_bar.add_theme_stylebox_override("panel", _tab_style)

	# Indicator pill.
	if _ind_style != null:
		_ind_style.bg_color = _accent
	if _indicator != null:
		_indicator.add_theme_stylebox_override("panel", _ind_style)

	# Dots panel.
	if _dots_panel_style != null:
		_dots_panel_style.bg_color = Global.get_theme_color("surface")
	if _dots_panel != null:
		_dots_panel.add_theme_stylebox_override("panel", _dots_panel_style)

	# Page scrollbars / backgrounds.
	for page in _pages:
		var scroll := page.get("scroll") as ScrollContainer
		if is_instance_valid(scroll):
			_style_page_scroll(scroll)

	# Tab text + dots.
	_update_tabs(_current)
	_update_dots(_current)


func _build_skeleton() -> void:
	# ------------------------------------------------------------
	# Full dark background.
	# This prevents white underlying surfaces from showing through.
	# ------------------------------------------------------------
	_bg = Panel.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Global.get_theme_color("bg_base")
	_bg_style.set_corner_radius_all(32)

	_bg.add_theme_stylebox_override("panel", _bg_style)
	add_child(_bg)

	# ------------------------------------------------------------
	# Main vertical layout.
	# ------------------------------------------------------------
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_top = 16.0   # gap between header bar and PageView content
	_vbox.add_theme_constant_override("separation", 0)
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_vbox)

	# ------------------------------------------------------------
	# Tab bar.
	# ------------------------------------------------------------
	_tab_bar = PanelContainer.new()

	_tab_style = StyleBoxFlat.new()
	_tab_style.bg_color = Global.get_theme_color("surface")
	_tab_style.set_content_margin_all(16)
	_tab_style.corner_radius_top_left = 32
	_tab_style.corner_radius_top_right = 32
	# No bottom border — the accent indicator pill is the visual anchor.

	_tab_bar.add_theme_stylebox_override("panel", _tab_style)
	_vbox.add_child(_tab_bar)

	_tab_inner = Control.new()
	_tab_inner.custom_minimum_size = Vector2(0, 76)
	_tab_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	_tab_bar.add_child(_tab_inner)

	_indicator = Panel.new()
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ind_style = StyleBoxFlat.new()
	_ind_style.bg_color = _accent
	_ind_style.set_corner_radius_all(28)

	_indicator.add_theme_stylebox_override("panel", _ind_style)
	_tab_inner.add_child(_indicator)

	_tabs_hbox = HBoxContainer.new()
	_tabs_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tabs_hbox.add_theme_constant_override("separation", 6)
	_tabs_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_tab_inner.add_child(_tabs_hbox)

	# ------------------------------------------------------------
	# Page viewport / slider.
	# ------------------------------------------------------------
	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_viewport)

	_slider = HBoxContainer.new()
	_slider.add_theme_constant_override("separation", 0)
	_slider.mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport.add_child(_slider)

	# ------------------------------------------------------------
	# Dots (wrapped in a bottom-rounded panel).
	# ------------------------------------------------------------
	_dots_panel = PanelContainer.new()
	_dots_panel_style = StyleBoxFlat.new()
	_dots_panel_style.bg_color = Global.get_theme_color("surface")
	_dots_panel_style.corner_radius_bottom_left = 32
	_dots_panel_style.corner_radius_bottom_right = 32
	_dots_panel.add_theme_stylebox_override("panel", _dots_panel_style)
	_vbox.add_child(_dots_panel)

	_dots_row = HBoxContainer.new()
	_dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_row.add_theme_constant_override("separation", 16)
	_dots_row.custom_minimum_size = Vector2(0, 52)
	_dots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots_panel.add_child(_dots_row)


# ============================================================
# PUBLIC API
# ============================================================

func add_page(id: String, title: String, icon: String, content: Control) -> void:
	# ------------------------------------------------------------
	# Wrap content in its own vertical scroller + padding.
	# ------------------------------------------------------------
	# ------------------------------------------------------------
	# Wrap content in its own vertical scroller + padding.
	# Each page sits inside a fixed-width slot (a plain Control). A plain
	# Control never auto-grows to its child's width, so the page width stays
	# locked to one viewport no matter how wide the content is — oversized
	# content can never push a page into the neighbouring page.
	# ------------------------------------------------------------
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.clip_contents = true
	_slider.add_child(slot)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.scroll_deadzone = 24
	scroll.focus_mode = Control.FOCUS_ALL
	# Clip page content so it can never spill over the page edges.
	scroll.clip_contents = true
	slot.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Lock the page's content to the viewport width so wrapped text never
	# inflates the ScrollContainer's minimum size (which would push the whole
	# page slot wider than one viewport and spill past the right edge).
	content.custom_minimum_size = Vector2(_page_content_width(), 0)
	margin.add_child(content)

	_style_page_scroll(scroll)

	_pages.append({
		"id": id,
		"title": title,
		"icon": icon,
		"scroll": scroll,
		"slot": slot,
		"content": content,
		"margin": margin,
	})
	if _audio_panel_open:
		_apply_audio_panel_clearance()

	# ------------------------------------------------------------
	# Tab button.
	# ------------------------------------------------------------
	var btn := Button.new()
	btn.text = (icon + "  " + title) if icon != "" else title
	btn.flat = true

	# Fill horizontally and give longer titles more space.
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_stretch_ratio = maxf(1.0, float(btn.text.length()))

	# Allow shrinking so the tab bar can fit horizontally.
	btn.custom_minimum_size = Vector2(0, 72)

	# Keep tab titles on one line.
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	btn.add_theme_font_size_override("font_size", tab_font_size)
	btn.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))

	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Compact horizontal padding so long/many tab labels fit without clipping.
	var btn_normal := StyleBoxFlat.new()
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", btn_normal)

	if font_bold:
		btn.add_theme_font_override("font", font_bold)

	var page_index := _pages.size() - 1
	btn.pressed.connect(func(): go_to_page(page_index))

	_tabs_hbox.add_child(btn)
	_tab_buttons.append(btn)

	# ------------------------------------------------------------
	# Dot.
	# ------------------------------------------------------------
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Global.get_theme_color("text_dim")
	d_style.set_corner_radius_all(7)

	dot.add_theme_stylebox_override("panel", d_style)
	dot.custom_minimum_size = Vector2(14, 14)

	_dots_row.add_child(dot)
	_dot_controls.append(dot)

	_refresh_layout()
	_refresh_tab_fit()

	if _pages.size() == 1:
		go_to_page(0, false)


func go_to_page(index: int, animate := true) -> void:
	if _pages.is_empty():
		return

	_stop_scroll_tween()

	index = clampi(index, 0, _pages.size() - 1)
	_current = index
	_page_width = _viewport.size.x

	var target_x := -index * _page_width

	if animate and _page_width > 0.0:
		var t := create_tween()
		t.tween_property(
			_slider,
			"position:x",
			target_x,
			0.35
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		_animate_indicator_to(float(index))
	else:
		_slider.position.x = target_x
		_set_indicator_to(float(index))

	_update_tabs(index)
	_update_dots(index)

	page_changed.emit(index, _pages[index]["id"])


func get_current_page() -> int:
	return _current


func scroll_current_to_top() -> void:
	var scroll := _get_current_scroll()
	if scroll == null:
		return

	_stop_scroll_tween()
	scroll.scroll_vertical = 0


func set_accent(color: Color) -> void:
	_accent = color

	_ind_style = StyleBoxFlat.new()
	_ind_style.bg_color = _accent
	_ind_style.set_corner_radius_all(28)
	_indicator.add_theme_stylebox_override("panel", _ind_style)

	# Update page scrollbars to match the new accent.
	for page in _pages:
		var scroll := page.get("scroll") as ScrollContainer
		if is_instance_valid(scroll):
			_style_page_scroll(scroll)

	_update_tabs(_current)
	_update_dots(_current)


# ============================================================
# LAYOUT
# ============================================================

func _page_content_width() -> float:
	# Width available to a page's content: one full viewport minus the
	# horizontal margins applied in add_page() (28 left + 28 right).
	return maxf(0.0, _page_width - 56.0)


func _refresh_layout() -> void:
	_page_width = _viewport.size.x

	if _page_width <= 0.0 or _pages.is_empty():
		return

	_slider.size = Vector2(_page_width * _pages.size(), _viewport.size.y)
	_slider.alignment = BoxContainer.ALIGNMENT_BEGIN

	for page in _pages:
		var slot := page.get("slot") as Control
		if is_instance_valid(slot):
			slot.custom_minimum_size = Vector2(_page_width, 0)

		var scroll := page.get("scroll") as ScrollContainer
		if is_instance_valid(scroll):
			scroll.clip_contents = true
			scroll.custom_minimum_size = Vector2(_page_width, 0)

		var content := page.get("content") as Control
		if is_instance_valid(content):
			content.custom_minimum_size = Vector2(_page_content_width(), 0)

	_slider.position.x = -_current * _page_width
	_set_indicator_to(float(_current))

	_refresh_tab_fit()

	# Post-layout safety: force every page to exactly the viewport width &
	# height so oversized content can never push a page past its boundary.
	call_deferred("_clamp_page_size")


func _clamp_page_size() -> void:
	if _page_width <= 0.0 or _pages.is_empty():
		return

	var vh := _viewport.size.y

	for page in _pages:
		var slot := page.get("slot") as Control
		if is_instance_valid(slot):
			slot.custom_minimum_size = Vector2(_page_width, 0)
			slot.size = Vector2(_page_width, vh)

		var scroll := page.get("scroll") as ScrollContainer
		if is_instance_valid(scroll):
			scroll.clip_contents = true
			scroll.custom_minimum_size = Vector2(_page_width, 0)
			scroll.size = Vector2(_page_width, vh)

		var content := page.get("content") as Control
		if is_instance_valid(content):
			content.custom_minimum_size = Vector2(_page_content_width(), 0)


func _style_page_scroll(scroll: ScrollContainer) -> void:
	# Page background.
	var scroll_style := StyleBoxFlat.new()
	scroll_style.bg_color = Global.get_theme_color("bg_base")
	scroll.add_theme_stylebox_override("panel", scroll_style)

	# Dark vertical scrollbar.
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null:
		return

	vbar.custom_minimum_size.x = 10

	# Hide scrollbar arrow buttons for a cleaner mobile look.
	var empty := StyleBoxEmpty.new()
	vbar.add_theme_stylebox_override("decrement", empty)
	vbar.add_theme_stylebox_override("decrement_highlight", empty)
	vbar.add_theme_stylebox_override("increment", empty)
	vbar.add_theme_stylebox_override("increment_highlight", empty)

	var track := StyleBoxFlat.new()
	track.bg_color = Global.get_theme_color("surface_alt")
	track.set_corner_radius_all(5)
	vbar.add_theme_stylebox_override("scroll", track)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Global.get_theme_color("text_dim")
	grabber.set_corner_radius_all(5)
	vbar.add_theme_stylebox_override("grabber", grabber)

	var grabber_highlight := grabber.duplicate()
	grabber_highlight.bg_color = _accent
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)


func _refresh_tab_fit() -> void:
	if _tab_buttons.is_empty():
		return

	var available := _tab_inner.size.x
	if available <= 0.0:
		return

	var sep := _tabs_hbox.get_theme_constant("separation")
	available -= sep * float(_tab_buttons.size() - 1)

	var font: Font = _tab_buttons[0].get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font

	var base_size := tab_font_size
	var min_size := tab_font_min
	var padding := tab_font_padding
	var chosen := base_size

	# Reduce the tab font size until all tabs roughly fit.
	while chosen > min_size:
		var total := 0.0

		for btn in _tab_buttons:
			var b: Button = btn
			total += font.get_string_size(
				b.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				chosen
			).x + padding

		if total <= available:
			break

		chosen -= 1

	for btn in _tab_buttons:
		var b: Button = btn
		b.add_theme_font_size_override("font_size", chosen)


# ============================================================
# INDICATOR (sliding pill)
# ============================================================

func _indicator_rect_for(float_index: float) -> Rect2:
	if _tab_buttons.is_empty():
		return Rect2()

	var i0 := clampi(floori(float_index), 0, _tab_buttons.size() - 1)
	var i1 := clampi(ceili(float_index), 0, _tab_buttons.size() - 1)
	var t: float = float_index - floor(float_index)

	var r0: Rect2 = _tab_buttons[i0].get_rect()
	var r1: Rect2 = _tab_buttons[i1].get_rect()

	var x := lerpf(r0.position.x, r1.position.x, t)
	var w := lerpf(r0.size.x, r1.size.x, t)
	var h := 58.0
	var y := (r0.position.y + r0.size.y / 2.0) - h / 2.0

	return Rect2(x, y, w, h)


func _set_indicator_to(float_index: float) -> void:
	var r := _indicator_rect_for(float_index)
	_indicator.position = r.position
	_indicator.size = r.size


func _animate_indicator_to(float_index: float) -> void:
	var r := _indicator_rect_for(float_index)

	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(
		_indicator,
		"position",
		r.position,
		0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	t.tween_property(
		_indicator,
		"size",
		r.size,
		0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# TABS & DOTS
# ============================================================

func _update_tabs(active: int) -> void:
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var target: Color = Global.get_theme_color("text") if i == active else Global.get_theme_color("text_dim")

		var t := create_tween()
		t.tween_property(
			btn,
			"theme_override_colors/font_color",
			target,
			0.25
		)


func _update_dots(active: int) -> void:
	for i in _dot_controls.size():
		var dot: Panel = _dot_controls[i]
		var is_active := i == active

		var style := StyleBoxFlat.new()
		style.bg_color = _accent if is_active else Global.get_theme_color("text_dim")
		style.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", style)

		var target_size := Vector2(36, 14) if is_active else Vector2(14, 14)

		var t := create_tween()
		t.tween_property(
			dot,
			"custom_minimum_size",
			target_size,
			0.25
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# SWIPE + SMOOTH SCROLL GESTURES
# ============================================================

func _input(event: InputEvent) -> void:
	if _pages.is_empty() or _page_width <= 0.0:
		return

	var vp := get_viewport()
	if vp == null:
		return

	var can_swipe := _pages.size() > 1
	var vp_rect := _viewport.get_global_rect()

	# ------------------------------------------------------------
	# Press / release.
	# ------------------------------------------------------------
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			if vp_rect.has_point(event.position) and not _is_touch_blocked(event.position):
				# If a previous gesture was still blocked, clean it up.
				if _gesture_blocked:
					_reset_exercise_gestures()

				_touch_start = event.position
				_axis = 0
				_dragging = false
				_drag_offset = 0.0
				_touch_active = true
				_press_time_msec = Time.get_ticks_msec()
				_gesture_blocked = false

				# Reset vertical scroll tracking.
				_v_drag_active = false
				_v_last_y = event.position.y
				_v_last_time_msec = Time.get_ticks_msec()
				_v_velocity = 0.0
				_stop_scroll_tween()
			else:
				# Press landed on a blocker or outside the page viewport.
				_touch_active = false
				_dragging = false
				_v_drag_active = false
				_axis = 2
		else:
			# A long press with no drag should not trigger buttons or typing fields.
			if _touch_active and not _dragging and not _v_drag_active:
				var hold_duration := Time.get_ticks_msec() - _press_time_msec
				if hold_duration > _HOLD_MAX_MSEC:
					_cancel_exercise_gestures()
					_reset_exercise_gestures()
					vp.set_input_as_handled()

			# If the user paused before releasing, do not apply stale inertia.
			if Time.get_ticks_msec() - _v_last_time_msec > 120:
				_v_velocity = 0.0

			if _dragging and _axis == 1:
				_finish_drag()
				_reset_exercise_gestures()
				vp.set_input_as_handled()
			elif _v_drag_active and _axis == 2:
				_finish_vertical_drag()
				_reset_exercise_gestures()
				vp.set_input_as_handled()

			_dragging = false
			_v_drag_active = false
			_axis = 0
			_touch_active = false

	# ------------------------------------------------------------
	# Drag / motion.
	# ------------------------------------------------------------
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		if not _touch_active:
			return

		# Decide gesture axis.
		if _axis == 0:
			var delta: Vector2 = event.position - _touch_start
			var abs_dx := absf(delta.x)
			var abs_dy := absf(delta.y)
			var can_scroll_vertical := _can_current_scroll_vertically()

			if abs_dx > _GESTURE_THRESHOLD or abs_dy > _GESTURE_THRESHOLD:
				# Horizontal page swipe.
				if can_swipe and abs_dx > abs_dy * 1.1:
					_axis = 1
					_dragging = true
					_cancel_exercise_gestures()

				# Vertical page scroll.
				elif can_scroll_vertical and abs_dy > abs_dx * 1.1:
					_axis = 2
					_v_drag_active = true
					_v_last_y = event.position.y
					_v_last_time_msec = Time.get_ticks_msec()
					_v_velocity = 0.0
					_cancel_exercise_gestures()

				# Fallback rules.
				elif can_swipe and not can_scroll_vertical and abs_dx > _GESTURE_THRESHOLD:
					_axis = 1
					_dragging = true
					_cancel_exercise_gestures()
				elif can_scroll_vertical:
					_axis = 2
					_v_drag_active = true
					_v_last_y = event.position.y
					_v_last_time_msec = Time.get_ticks_msec()
					_v_velocity = 0.0
					_cancel_exercise_gestures()
				elif can_swipe:
					_axis = 1
					_dragging = true
					_cancel_exercise_gestures()

		# ------------------------------------------------------------
		# Horizontal page swipe.
		# ------------------------------------------------------------
		if _dragging and _axis == 1:
			_cancel_exercise_gestures()
			vp.set_input_as_handled()

			var delta_x: float = event.position.x - _touch_start.x

			# Rubber-band at the edges.
			var proposed := _current * _page_width - delta_x
			if proposed < 0.0 or proposed > (_pages.size() - 1) * _page_width:
				delta_x *= 0.35

			_slider.position.x = -_current * _page_width + delta_x
			_drag_offset = delta_x

			var float_index := clampf(
				-_slider.position.x / _page_width,
				0.0,
				float(_pages.size() - 1)
			)
			_set_indicator_to(float_index)

		# ------------------------------------------------------------
		# Vertical smooth scrolling.
		# ------------------------------------------------------------
		elif _v_drag_active and _axis == 2:
			var scroll := _get_current_scroll()
			if scroll == null:
				return

			var max_v := _get_max_scroll(scroll)
			if max_v <= 0:
				# Nothing to scroll. Do not reset the gesture here,
				# because dragging should still not trigger buttons.
				_v_drag_active = false
				return

			_cancel_exercise_gestures()
			vp.set_input_as_handled()

			var now := Time.get_ticks_msec()
			var dt := maxf(float(now - _v_last_time_msec) / 1000.0, 0.001)
			var drag_dy: float = event.position.y - _v_last_y

			_v_last_y = event.position.y
			_v_last_time_msec = now

			# Positive velocity means scrolling downward.
			var instant_velocity := -drag_dy / dt
			_v_velocity = lerpf(_v_velocity, instant_velocity, 0.35)

			var new_scroll := int(scroll.scroll_vertical - drag_dy)
			scroll.scroll_vertical = clampi(new_scroll, 0, max_v)

func _finish_drag() -> void:
	var threshold := _page_width * 0.25
	var target := _current

	if _drag_offset < -threshold:
		target = _current + 1
	elif _drag_offset > threshold:
		target = _current - 1

	go_to_page(target)


func _finish_vertical_drag() -> void:
	var scroll := _get_current_scroll()
	if scroll == null:
		return

	var max_v := _get_max_scroll(scroll)
	if max_v <= 0:
		return

	# Too slow: no fling.
	if absf(_v_velocity) < 140.0:
		return

	# Inertia distance.
	var distance := _v_velocity * 0.42
	var target := clampi(int(scroll.scroll_vertical + distance), 0, max_v)

	if target == scroll.scroll_vertical:
		return

	_stop_scroll_tween()

	var duration := clampf(
		absf(float(target - scroll.scroll_vertical)) / maxf(absf(_v_velocity), 1.0),
		0.18,
		0.75
	)

	_scroll_tween = create_tween()
	_scroll_tween.tween_property(
		scroll,
		"scroll_vertical",
		target,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _get_current_scroll() -> ScrollContainer:
	if _pages.is_empty():
		return null

	var idx := clampi(_current, 0, _pages.size() - 1)
	var scroll := _pages[idx].get("scroll") as ScrollContainer

	if is_instance_valid(scroll):
		return scroll

	return null


func _get_max_scroll(scroll: ScrollContainer) -> int:
	if scroll == null:
		return 0

	var vbar := scroll.get_v_scroll_bar()
	if vbar == null:
		return 0

	return int(maxf(vbar.max_value - vbar.page, 0.0))


func _can_current_scroll_vertically() -> bool:
	return _get_max_scroll(_get_current_scroll()) > 0


func _stop_scroll_tween() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()

	_scroll_tween = null


# ============================================================
# SWIPE BLOCKERS
# ============================================================

func add_swipe_blocker(control: Control) -> void:
	if control and not _swipe_blockers.has(control):
		_swipe_blockers.append(control)
		if control.has_signal("visibility_changed_state"):
			var callback: Callable = _on_audio_panel_visibility_changed.bind(control)
			if not control.visibility_changed_state.is_connected(callback):
				control.visibility_changed_state.connect(callback)
			if control.visible:
				_on_audio_panel_visibility_changed(true, control)


func _on_audio_panel_visibility_changed(is_open: bool, panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	_audio_panel_open = is_open
	_audio_panel_clearance = panel.size.y if is_open else 0.0
	if _audio_panel_open:
		var panel_top: float = panel.get_global_rect().position.y
		var covered_height: float = maxf(0.0, get_global_rect().end.y - panel_top)
		_audio_panel_clearance = covered_height
	_apply_audio_panel_clearance()


func _apply_audio_panel_clearance() -> void:
	for page_data: Dictionary in _pages:
		var scroll: ScrollContainer = page_data.get("scroll") as ScrollContainer
		var margin: MarginContainer = page_data.get("margin") as MarginContainer
		if not is_instance_valid(scroll) or not is_instance_valid(margin):
			continue
		var bottom_padding: int = 60 + int(ceil(_audio_panel_clearance))
		margin.add_theme_constant_override("margin_bottom", bottom_padding)
		margin.reset_size()
		margin.queue_sort()
		scroll.queue_sort()
		if _audio_panel_open:
			if not page_data.has("audio_saved_scroll"):
				page_data["audio_saved_scroll"] = scroll.scroll_vertical
			call_deferred("_apply_audio_scroll_after_layout", page_data)
		else:
			if page_data.has("audio_saved_scroll"):
				scroll.set_deferred("scroll_vertical", int(page_data["audio_saved_scroll"]))
				page_data.erase("audio_saved_scroll")
			margin.add_theme_constant_override("margin_bottom", 60)


func _apply_audio_scroll_after_layout(page_data: Dictionary) -> void:
	if not _audio_panel_open:
		return
	var scroll: ScrollContainer = page_data.get("scroll") as ScrollContainer
	var margin: MarginContainer = page_data.get("margin") as MarginContainer
	if not is_instance_valid(scroll) or not is_instance_valid(margin):
		return
	var max_scroll: float = maxf(0.0, margin.get_combined_minimum_size().y - scroll.size.y)
	var required_scroll: int = int(ceil(_audio_panel_clearance))
	var applied_scroll: float = minf(max_scroll, float(required_scroll))
	var target_scroll: float = maxf(float(page_data.get("audio_saved_scroll", 0)), applied_scroll)
	scroll.scroll_vertical = int(ceil(target_scroll))


func _is_touch_blocked(global_pos: Vector2) -> bool:
	for blocker in _swipe_blockers:
		if is_instance_valid(blocker) and blocker.is_visible_in_tree():
			if blocker.get_global_rect().has_point(global_pos):
				return true

	# Ordering drag handles (≡): presses on a grab handle must never start a
	# page scroll/swipe — the exercise engine owns the gesture there. Handles
	# are added to this group by the engine (timing-independent, rebuilt
	# handles re-join automatically).
	var handles := get_tree().get_nodes_in_group("order_drag_handles")
	for h in handles:
		var handle_ctrl := h as Control
		if handle_ctrl != null and handle_ctrl.is_visible_in_tree():
			if handle_ctrl.get_global_rect().has_point(global_pos):
				return true

	return false

func _exercise_request_keyboard_visibility() -> void:
	var focused := get_viewport().gui_get_focus_owner()

	if focused == null:
		return

	if not (focused is LineEdit or focused is TextEdit):
		return

	# Give Android a moment to display the keyboard and report
	# its actual height.
	await get_tree().create_timer(0.15).timeout

	if not is_instance_valid(focused):
		return

	var scroll := _get_current_scroll()

	if scroll == null:
		return

	# First let Godot's built-in focus-follow behavior do its job.
	scroll.ensure_control_visible(focused)

	# Android keyboard height.
	var keyboard_height := DisplayServer.virtual_keyboard_get_height()

	if keyboard_height <= 0:
		return

	# Give the field a comfortable gap above the keyboard.
	var safe_gap := 32.0

	var field_rect := focused.get_global_rect()

	var keyboard_top := get_viewport().get_visible_rect().size.y - keyboard_height

	var field_bottom := field_rect.position.y + field_rect.size.y
	var allowed_bottom := keyboard_top - safe_gap

	if field_bottom > allowed_bottom:
		var amount := field_bottom - allowed_bottom

		scroll.scroll_vertical = clampi(
			int(scroll.scroll_vertical + amount),
			0,
			_get_max_scroll(scroll)
		)
