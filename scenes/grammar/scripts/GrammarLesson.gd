extends "res://autoload/BackButtonHandler.gd"
# ============================================================
# GRAMMAR LESSON — main micro-learning controller
# ============================================================

const LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

var lesson_data: Dictionary = {}
var units: Array = []
var current_unit_index := 0
var xp := 0
var correct_answers := 0
var _last_award := 0
var _last_bonus := 0
var _unit_mistakes := 0

var title_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var xp_label: Label
var xp_pill: PanelContainer
var content_box: PanelContainer
var scroll: ScrollContainer
var scroll_padding: MarginContainer
var content_container: VBoxContainer
var feedback_popup: FeedbackPopup
var reward_popup: RewardPopup
var hint_bulb: GrammarHint

var _wrong_attempts := 0
var _activities: Array = []
var _activity_index := 0
var _accent := GrammarTheme.primary_color()
var _progress_tween: Tween


func _animate_progress() -> void:
	var total := maxi(_activities.size(), 1)
	var target := (float(_activity_index + 1) / float(total)) * 100.0
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_QUAD)
	_progress_tween.set_ease(Tween.EASE_OUT)
	_progress_tween.tween_property(progress_bar, "value", target, 0.4)


func _fill_progress_bar() -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_QUAD)
	_progress_tween.set_ease(Tween.EASE_OUT)
	_progress_tween.tween_property(progress_bar, "value", 100.0, 0.4)


func _ready() -> void:
	super._ready()
	_load_lesson()
	if units.is_empty():
		current_unit_index = 0
	else:
		current_unit_index = clampi(Global.grammar_start_unit_index, 0, units.size() - 1)
	Global.grammar_start_unit_index = 0
	_build_ui()

	xp = Global.get_grammar_xp(Global.current_book, Global.current_lesson)
	_update_xp_label()

	if units.is_empty():
		_show_no_content()
		return

	_show_unit.call_deferred()


func _show_no_content() -> void:
	var label: Label = Label.new()
	label.text = "📭 محتوای گرامر برای این درس هنوز آماده نشده است."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	var body_font: Font = GrammarTheme.get_fa_bold()
	if body_font != null:
		label.add_theme_font_override("font", body_font)
	content_container.add_child(label)


func _load_lesson() -> void:
	var data := GrammarData.load_lesson(Global.current_book, Global.current_lesson)
	lesson_data = data
	units = lesson_data.get("units", [])
	var accent_str: String = lesson_data.get("theme_color", "")
	if accent_str != "":
		_accent = Color(accent_str)


func _build_ui() -> void:
	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", GrammarTheme.SAFE_MARGIN)
	safe_area.add_theme_constant_override("margin_right", GrammarTheme.SAFE_MARGIN)
	safe_area.add_theme_constant_override("margin_top", GrammarTheme.SAFE_MARGIN)
	safe_area.add_theme_constant_override("margin_bottom", GrammarTheme.SAFE_MARGIN)
	add_child(safe_area)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	safe_area.add_child(main)

	# --- 1. HEADER CARD ---
	var header_box := PanelContainer.new()
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_theme_stylebox_override("panel", _make_card_style(30, 2))
	main.add_child(header_box)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 20)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_bottom", 16)
	header_box.add_child(header_margin)

	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_vbox.add_theme_constant_override("separation", 14)
	header_margin.add_child(header_vbox)

	_build_top_bar(header_vbox)
	_build_progress(header_vbox)

	# --- 2. CONTENT CARD ---
	content_box = PanelContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_stylebox_override("panel", _make_card_style(30, 2))
	main.add_child(content_box)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content_box.add_child(content_margin)

	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	content_margin.add_child(scroll)

	# Inner padding INSIDE the ScrollContainer so child borders/shadows never get clipped
	scroll_padding = MarginContainer.new()
	scroll_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_padding.add_theme_constant_override("margin_left", 16)
	scroll_padding.add_theme_constant_override("margin_right", 20)
	scroll_padding.add_theme_constant_override("margin_top", 8)
	scroll_padding.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(scroll_padding)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 18)
	scroll_padding.add_child(content_container)

	scroll.resized.connect(_constrain_scroll_content_width)

	feedback_popup = FeedbackPopup.new()
	add_child(feedback_popup)
	feedback_popup.continue_pressed.connect(_on_feedback_continue)
	feedback_popup.skip_pressed.connect(_on_skip_pressed)

	reward_popup = RewardPopup.new()
	add_child(reward_popup)
	reward_popup.next_requested.connect(_on_reward_next)
	reward_popup.back_requested.connect(_on_reward_back)

	hint_bulb = GrammarHint.new()
	hint_bulb.name = "HintBulb"
	hint_bulb.top_level = true
	hint_bulb.anchor_left = 0.0
	hint_bulb.anchor_right = 1.0
	hint_bulb.anchor_top = 1.0
	hint_bulb.anchor_bottom = 1.0
	hint_bulb.offset_left = 24
	hint_bulb.offset_right = -24
	hint_bulb.offset_top = -360
	hint_bulb.offset_bottom = -140
	hint_bulb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_bulb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hint_bulb)
	hint_bulb.hint_requested.connect(_on_hint_requested)


func _constrain_scroll_content_width() -> void:
	if scroll == null or scroll_padding == null:
		return
	var v_scroll := scroll.get_v_scroll_bar()
	var sb_width: float = v_scroll.size.x if (v_scroll != null and v_scroll.visible) else 0.0
	var target_w: float = maxf(scroll.size.x - sb_width, 100.0)
	scroll_padding.custom_minimum_size.x = target_w
	scroll_padding.size.x = target_w


func _fix_children_overflow(node: Node) -> void:
	if node is Label:
		var lbl := node as Label
		if lbl.name.contains("Counter") or lbl.name.contains("Badge") or lbl.name.contains("Pill") or lbl.name.contains("XP") or lbl.name.contains("progress"):
			lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			return
		# Enable word wrap on all multi-word labels inside the lesson card so they never push width out
		if lbl.text.length() > 12:
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif node is Control:
		var ctrl := node as Control
		if ctrl.custom_minimum_size.x > 300.0:
			ctrl.custom_minimum_size.x = 0.0

	for child in node.get_children():
		_fix_children_overflow(child)


func _build_top_bar(main_vbox: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.custom_minimum_size = Vector2(0, 56)
	top_bar.add_theme_constant_override("separation", 14)
	main_vbox.add_child(top_bar)

	var back_button: Button = GrammarTheme.make_header_icon_button(
		"res://ui/images/Back.png",
		Callable(self, "_on_back_pressed")
	)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(back_button)

	xp_pill = PanelContainer.new()
	xp_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_pill.add_theme_stylebox_override("panel", _make_xp_pill_style())
	top_bar.add_child(xp_pill)

	var xp_margin := MarginContainer.new()
	xp_margin.add_theme_constant_override("margin_left", 14)
	xp_margin.add_theme_constant_override("margin_right", 14)
	xp_margin.add_theme_constant_override("margin_top", 6)
	xp_margin.add_theme_constant_override("margin_bottom", 6)
	xp_pill.add_child(xp_margin)

	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "⭐ ۰ XP"
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 24)
	xp_label.add_theme_color_override("font_color", Color("#B45309"))
	xp_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	xp_margin.add_child(xp_label)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	top_bar.add_child(title_label)


func _build_progress(main_vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 32)
	main_vbox.add_child(row)

	var step_pill := PanelContainer.new()
	step_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	step_pill.add_theme_stylebox_override("panel", _make_step_pill_style())
	row.add_child(step_pill)

	var step_margin := MarginContainer.new()
	step_margin.add_theme_constant_override("margin_left", 14)
	step_margin.add_theme_constant_override("margin_right", 14)
	step_margin.add_theme_constant_override("margin_top", 4)
	step_margin.add_theme_constant_override("margin_bottom", 4)
	step_pill.add_child(step_margin)

	progress_label = Label.new()
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	progress_label.add_theme_font_size_override("font_size", 22)
	progress_label.add_theme_color_override("font_color", _accent.darkened(0.15))
	step_margin.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.add_theme_stylebox_override("background", _make_progress_track_style())
	progress_bar.add_theme_stylebox_override("fill", _make_progress_fill_style())
	row.add_child(progress_bar)


func _show_unit() -> void:
	if current_unit_index >= units.size():
		_finish_lesson()
		return
	var unit: Dictionary = units[current_unit_index]
	var type := str(unit.get("type", ""))
	if type == "group":
		_activities = unit.get("activities", [])
	else:
		_activities = [unit]
	_activity_index = 0
	_unit_mistakes = 0

	var raw_title := str(lesson_data.get("title_fa", "گرامر"))
	GrammarTheme.set_bidi_text(title_label, "%s  ✨" % raw_title)
	_show_current_activity()


func _show_current_activity() -> void:
	for child in content_container.get_children():
		child.queue_free()
	if _activity_index >= _activities.size():
		_on_activity_group_finished()
		return

	var step_str := "🎯 گام %s از %s" % [
		_to_fa_digits(_activity_index + 1),
		_to_fa_digits(_activities.size())
	]
	GrammarTheme.set_bidi_text(progress_label, step_str)
	_animate_progress()
	_wrong_attempts = 0
	hint_bulb.visible = false
	hint_bulb.stop_flash()
	hint_bulb.hide_bubble()

	var activity: Dictionary = _activities[_activity_index]
	var type := str(activity.get("type", ""))
	match type:
		"learn":
			_show_learning_unit(activity)
		"multiple_choice", "fill_blank", "true_false", "matching", "unscramble":
			_show_exercise(activity)
		_:
			push_warning("Unknown grammar activity type: %s (skipped)" % type)
			_advance_activity()
			return

	_fix_children_overflow(content_container)
	_constrain_scroll_content_width.call_deferred()
	_animate_activity_card_in()


func _animate_activity_card_in() -> void:
	if content_container == null:
		return
	content_container.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(content_container, "modulate:a", 1.0, 0.25)


func _advance_activity() -> void:
	_activity_index += 1
	if _activity_index < _activities.size():
		_show_current_activity()
	else:
		_on_activity_group_finished()


func _on_activity_group_finished() -> void:
	_sync_grammar_progress()
	_award_unit_xp()
	_fill_progress_bar()
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	_show_unit_completed_reward()


func _show_learning_unit(unit: Dictionary) -> void:
	LearningUnitView.render(content_container, unit)

	var next_button := Button.new()
	GrammarTheme.set_bidi_text(next_button, "متوجه شدم، بریم تمرین  🚀")
	next_button.custom_minimum_size = Vector2(0, 104)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_button.pressed.connect(_on_learning_continue)
	_style_modern_cta_button(next_button)
	content_container.add_child(next_button)
	GrammarAnimation.appear(next_button, 0.20)


func _show_exercise(unit: Dictionary) -> void:
	var exercise := ExerciseFactory.create_exercise(str(unit.get("type", "")))
	if exercise == null:
		return
	exercise.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exercise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exercise.setup(unit)
	content_container.add_child(exercise)
	exercise.answer_selected.connect(_on_answer_selected)
	exercise.exercise_completed.connect(_on_exercise_completed)


func _on_answer_selected(correct: bool, explanation: String) -> void:
	if correct:
		correct_answers += 1
		_wrong_attempts = 0
		hint_bulb.visible = false
		hint_bulb.stop_flash()
		hint_bulb.hide_bubble()
		feedback_popup.show_correct(explanation)
	else:
		_wrong_attempts += 1
		_unit_mistakes += 1
		hint_bulb.visible = true
		hint_bulb.flash()
		feedback_popup.show_wrong(explanation)
		if _wrong_attempts >= 2:
			feedback_popup.show_skip_button()


func _update_xp_label() -> void:
	if xp_label != null:
		GrammarTheme.set_bidi_text(xp_label, "⭐ %s XP" % _to_fa_digits(xp))
		if xp_pill != null:
			GrammarAnimation.small_pop(xp_pill)


func _current_exercise() -> GrammarExercise:
	for child in content_container.get_children():
		if child is GrammarExercise:
			return child
	return null


func _on_hint_requested() -> void:
	var exercise: GrammarExercise = _current_exercise()
	if exercise == null:
		return
	hint_bulb.set_hint(exercise.get_current_hint())
	hint_bulb.show_bubble()


func _on_feedback_continue() -> void:
	var exercise: GrammarExercise = _current_exercise()
	if exercise == null:
		return
	if feedback_popup.is_correct:
		exercise.continue_to_next()
	else:
		exercise.retry_current()


func _on_skip_pressed() -> void:
	_wrong_attempts = 0
	hint_bulb.visible = false
	hint_bulb.stop_flash()
	hint_bulb.hide_bubble()
	var exercise: GrammarExercise = _current_exercise()
	if exercise == null:
		return
	exercise.continue_to_next()


func _on_learning_continue() -> void:
	_advance_activity()


func _on_exercise_completed() -> void:
	_advance_activity()


func _has_exercise_in_unit() -> bool:
	for act in _activities:
		if act is Dictionary and str(act.get("type", "")) != "learn":
			return true
	return false


func _award_unit_xp() -> void:
	var unit: Dictionary = units[current_unit_index] if current_unit_index < units.size() else {}
	var unit_id := str(unit.get("id", ""))
	var already_done: bool = Global.is_unit_completed(
		Global.current_book, Global.current_lesson, current_unit_index, unit_id
	)

	if already_done:
		_last_award = 0
		_last_bonus = 0
	else:
		Global.mark_unit_completed(
			Global.current_book, Global.current_lesson, current_unit_index, unit_id
		)
		var base_xp := int(lesson_data.get("xp_per_unit", 10))
		_last_bonus = 5 if (_has_exercise_in_unit() and _unit_mistakes == 0) else 0
		_last_award = base_xp + _last_bonus
		xp += _last_award
		Global.add_grammar_xp(Global.current_book, Global.current_lesson, _last_award)
		_update_xp_label()
		GrammarAnimation.spawn_xp_toast(self, "+%d XP ⭐" % _last_award, xp_label)


func _show_unit_completed_reward() -> void:
	if current_unit_index >= units.size() - 1:
		_finish_lesson()
		return
	var n: int = current_unit_index + 1
	reward_popup.show_reward(
		"بخش %d کامل شد!" % n,
		_last_award,
		"رفتن به بخش بعدی",
		true,
		_last_bonus
	)


func _on_reward_next() -> void:
	if current_unit_index >= units.size() - 1:
		_go_back_to_units()
		return
	current_unit_index += 1
	_show_unit()


func _on_reward_back() -> void:
	_go_back_to_units()


func _finish_lesson() -> void:
	for child in content_container.get_children():
		child.queue_free()
	if hint_bulb != null:
		hint_bulb.visible = false
		hint_bulb.stop_flash()
		hint_bulb.hide_bubble()
	_fill_progress_bar()
	_update_xp_label()
	reward_popup.show_reward(
		"🎉 تمام بخش‌های این درس کامل شد!",
		_last_award,
		"بازگشت به بخش‌ها",
		false,
		_last_bonus
	)
	Sfx.complete()


func _sync_grammar_progress() -> void:
	var unlocked: int = current_unit_index + 2
	if units.size() > 0:
		unlocked = min(unlocked, units.size())
	Global.set_grammar_unlocked_units(Global.current_book, Global.current_lesson, unlocked)


func _go_back_to_units() -> void:
	var last_scene: String = Global.get_last_scene()
	if last_scene.is_empty():
		last_scene = LESSON_MENU
	TransitionManager.change_scene(last_scene)


func _on_back_pressed() -> void:
	_go_back_to_units()


func _on_android_back_pressed() -> void:
	_on_back_pressed()


# ============================================================
# STYLING HELPERS
# ============================================================

func _make_card_style(radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface")
	style.set_corner_radius_all(radius)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width + 1
	style.border_color = Global.get_theme_color("border")
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_xp_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface_alt")
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = GrammarTheme.xp_color()
	return style


func _make_step_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(_accent.r, _accent.g, _accent.b, 0.12)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(_accent.r, _accent.g, _accent.b, 0.35)
	return style


func _make_progress_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Global.get_theme_color("surface_sunken")
	style.set_corner_radius_all(10)
	return style


func _make_progress_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _accent
	style.set_corner_radius_all(10)
	return style


func _style_modern_cta_button(btn: Button) -> void:
	var bold_font: Font = GrammarTheme.get_fa_bold()
	if bold_font != null:
		btn.add_theme_font_override("font", bold_font)
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = _accent
	normal.set_corner_radius_all(24)
	normal.border_width_top = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 5
	normal.border_color = _accent.darkened(0.25)
	normal.shadow_color = Color(_accent.r, _accent.g, _accent.b, 0.28)
	normal.shadow_size = 12
	normal.shadow_offset = Vector2(0, 4)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = _accent.lightened(0.08)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = _accent.darkened(0.08)
	pressed.border_width_bottom = 2
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)


func _to_fa_digits(value: int) -> String:
	var s := str(value)
	var fa_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for i in range(s.length()):
		var code := s.unicode_at(i) - 48
		if code >= 0 and code <= 9:
			out += fa_digits[code]
		else:
			out += s[i]
	return out
