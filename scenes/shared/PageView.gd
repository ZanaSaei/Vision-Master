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
const TEXT_MUTED := Color("#94A3B8")
const TEXT_LIGHT := Color("#F1F5F9")

const APP_BG := Color("#0b1229")
const PANEL_BG := Color("#0f1b3d")
const PANEL_BORDER := Color("#2d3a6a")

const DOT_OFF := Color("#3d4a7a")
const SCROLL_GRABBER := Color("#3d4a7a")
const SCROLL_TRACK := Color("#16224a")

const FONT_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"

var _accent: Color = Color("#22D3EE")
var font_bold: FontFile

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


func _ready() -> void:
	font_bold = load(FONT_BOLD_PATH)

	mouse_filter = Control.MOUSE_FILTER_PASS

	# Applies a dark fallback theme to content that does not style itself.
	_apply_page_theme()

	_build_skeleton()

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
	# If a theme was already assigned locally, do not override it.
	if theme != null:
		return

	var t := Theme.new()

	# ------------------------------------------------------------
	# Fallback text colors for common controls.
	# This fixes content that would otherwise render black on dark.
	# ------------------------------------------------------------
	t.set_color("font_color", "Label", TEXT_LIGHT)
	t.set_color("font_color", "Button", TEXT_LIGHT)
	t.set_color("font_color", "CheckBox", TEXT_LIGHT)
	t.set_color("font_color", "OptionButton", TEXT_LIGHT)
	t.set_color("font_color", "LineEdit", TEXT_LIGHT)
	t.set_color("font_color", "TextEdit", TEXT_LIGHT)
	t.set_color("font_color", "ItemList", TEXT_LIGHT)
	t.set_color("font_color", "Tree", TEXT_LIGHT)
	t.set_color("font_color", "PopupMenu", TEXT_LIGHT)

	t.set_color("default_color", "RichTextLabel", TEXT_LIGHT)

	# Placeholder / caret colors.
	t.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	t.set_color("font_placeholder_color", "TextEdit", TEXT_MUTED)
	t.set_color("caret_color", "LineEdit", _accent)
	t.set_color("caret_color", "TextEdit", _accent)

	# ------------------------------------------------------------
	# Dark panels.
	# ------------------------------------------------------------
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.set_corner_radius_all(14)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = PANEL_BORDER
	panel_style.set_content_margin_all(16)

	t.set_stylebox("panel", "Panel", panel_style)
	t.set_stylebox("panel", "PanelContainer", panel_style)

	# Let PageView's own background show through generic scroll containers.
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# ------------------------------------------------------------
	# Dark popups.
	# ------------------------------------------------------------
	var popup_style: StyleBoxFlat = panel_style.duplicate()
	popup_style.bg_color = PANEL_BG

	t.set_stylebox("panel", "PopupPanel", popup_style)
	t.set_stylebox("panel", "PopupMenu", popup_style)

	# ------------------------------------------------------------
	# Dark input fields.
	# ------------------------------------------------------------
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("#0f1b3d")
	input_style.set_corner_radius_all(10)
	input_style.border_width_bottom = 2
	input_style.border_color = Color("#3d4a7a")
	input_style.set_content_margin_all(12)

	var input_focus: StyleBoxFlat = input_style.duplicate()
	input_focus.border_color = _accent

	t.set_stylebox("normal", "LineEdit", input_style)
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_stylebox("normal", "TextEdit", input_style)
	t.set_stylebox("focus", "TextEdit", input_focus)

	theme = t


func _build_skeleton() -> void:
	# ------------------------------------------------------------
	# Full dark background.
	# This prevents white underlying surfaces from showing through.
	# ------------------------------------------------------------
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = APP_BG

	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# ------------------------------------------------------------
	# Main vertical layout.
	# ------------------------------------------------------------
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 0)
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_vbox)

	# ------------------------------------------------------------
	# Tab bar.
	# ------------------------------------------------------------
	var tab_bar := PanelContainer.new()

	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = PANEL_BG
	tab_style.set_content_margin_all(12)
	tab_style.border_width_bottom = 2
	tab_style.border_color = PANEL_BORDER

	tab_bar.add_theme_stylebox_override("panel", tab_style)
	_vbox.add_child(tab_bar)

	_tab_inner = Control.new()
	_tab_inner.custom_minimum_size = Vector2(0, 64)
	_tab_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	tab_bar.add_child(_tab_inner)

	_indicator = Panel.new()
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ind_style := StyleBoxFlat.new()
	ind_style.bg_color = _accent
	ind_style.set_corner_radius_all(16)

	_indicator.add_theme_stylebox_override("panel", ind_style)
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
	# Dots.
	# ------------------------------------------------------------
	_dots_row = HBoxContainer.new()
	_dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_row.add_theme_constant_override("separation", 12)
	_dots_row.custom_minimum_size = Vector2(0, 40)
	_dots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_dots_row)


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
	})

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
	btn.custom_minimum_size = Vector2(0, 64)

	# Keep tab titles on one line.
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	btn.add_theme_font_size_override("font_size", 31)
	btn.add_theme_color_override("font_color", TEXT_MUTED)

	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

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
	d_style.bg_color = DOT_OFF
	d_style.set_corner_radius_all(6)

	dot.add_theme_stylebox_override("panel", d_style)
	dot.custom_minimum_size = Vector2(12, 12)

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

	var ind_style := StyleBoxFlat.new()
	ind_style.bg_color = _accent
	ind_style.set_corner_radius_all(16)
	_indicator.add_theme_stylebox_override("panel", ind_style)

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
	# Dark page background.
	var scroll_style := StyleBoxFlat.new()
	scroll_style.bg_color = APP_BG
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
	track.bg_color = SCROLL_TRACK
	track.set_corner_radius_all(5)
	vbar.add_theme_stylebox_override("scroll", track)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = SCROLL_GRABBER
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

	var base_size := 31
	var min_size := 20
	var padding := 26.0
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
	var h := 48.0
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
		var target: Color = TEXT_LIGHT if i == active else TEXT_MUTED

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
		style.bg_color = _accent if is_active else DOT_OFF
		style.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", style)

		var target_size := Vector2(30, 12) if is_active else Vector2(12, 12)

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


func _is_touch_blocked(global_pos: Vector2) -> bool:
	for blocker in _swipe_blockers:
		if is_instance_valid(blocker) and blocker.is_visible_in_tree():
			if blocker.get_global_rect().has_point(global_pos):
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
