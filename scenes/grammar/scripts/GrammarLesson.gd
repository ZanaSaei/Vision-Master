extends "res://autoload/BackButtonHandler.gd"
# ============================================================
#  GRAMMAR LESSON — main micro-learning controller
# ------------------------------------------------------------
#  Responsibilities (kept small on purpose):
#    * build the shell UI (top bar, progress, XP, content, popups)
#    * load the lesson data generically for the current book/lesson
#    * drive the unit flow (teach -> exercise -> ... -> finish)
#    * track XP / correct answers
#  All rendering is delegated:
#    * teaching screens  -> LearningUnitView
#    * exercises         -> ExerciseFactory + exercise scripts
#    * feedback / reward -> FeedbackPopup / RewardPopup
#    * theme / animation -> GrammarTheme / GrammarAnimation
#    * sounds            -> Sfx
# ============================================================

const LESSON_MENU := "res://scenes/lesson_menu/LessonMenu.tscn"

var lesson_data: Dictionary = {}
var units: Array = []
var current_unit_index := 0

var xp := 0
var correct_answers := 0
var _last_award := 0

var title_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var xp_label: Label

var content_container: VBoxContainer
var feedback_popup: FeedbackPopup
var reward_popup: RewardPopup
var hint_bulb: GrammarHint
# Wrong attempts on the current question; used to reveal the skip button
# after the learner has failed twice.
var _wrong_attempts := 0

# Multi-activity "group" units: the lesson plays each activity inside the
# group in sequence, then awards XP / advances to the next unit.
var _activities: Array = []
var _activity_index := 0

var _accent := GrammarTheme.primary_color()

var _progress_tween: Tween


func _animate_progress() -> void:
	# Progress reflects only the activities inside the CURRENT unit (a group
	# may hold many activities; a plain unit holds one).
	var total := maxi(_activities.size(), 1)
	var target := (float(_activity_index) / float(total)) * 100.0
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_QUAD)
	_progress_tween.set_ease(Tween.EASE_OUT)
	_progress_tween.tween_property(progress_bar, "value", target, 0.6)


# Fills the unit progress bar completely. Called when every activity in the
# current unit has been finished, so the bar reaches 100% (instead of being
# left at the last activity's partial position). Matches _animate_progress's
# easing so the final stretch glides the same way the rest does.
func _fill_progress_bar() -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_QUAD)
	_progress_tween.set_ease(Tween.EASE_OUT)
	_progress_tween.tween_property(progress_bar, "value", 100.0, 0.6)


func _ready() -> void:
	super._ready()
	_load_lesson()
	if units.is_empty():
		current_unit_index = 0
	else:
		current_unit_index = clampi(Global.grammar_start_unit_index, 0, units.size() - 1)
	Global.grammar_start_unit_index = 0
	_build_ui()
	# XP carries over across sessions from saved progress, then grows as
	# بخش‌ها are completed in this run.
	xp = Global.get_grammar_xp(Global.current_book, Global.current_lesson)
	_update_xp_label()
	if units.is_empty():
		_show_no_content()
		return
	# Build the first activity on the NEXT frame (after Global's one-time
	# scene_changed style walk). If we build it synchronously here, the walker
	# re-styles our theme-aware cards/labels to flat white + navy text right
	# after _ready — the "dull first page" bug. Building deferred matches how
	# every subsequent activity page is created (after the walk), so the first
	# page now renders identically to the rest.
	_show_unit.call_deferred()


func _show_no_content() -> void:
	# No grammar JSON exists for this book/lesson: never fall back to the
	# bundled Vision 1 / Lesson 1 sample. Show a friendly message instead.
	var label: Label = Label.new()
	label.text = "📭\nهنوز محتوایی نیست\n\nمحتوای گرامر برای این درس هنوز آماده نشده است."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", GrammarTheme.text_muted_color())
	var body_font: Font = GrammarTheme.get_fa_regular()
	if body_font != null:
		label.add_theme_font_override("font", body_font)
	content_container.add_child(label)


# ============================================================
# DATA
# ============================================================

func _load_lesson() -> void:
	var data := GrammarData.load_lesson(Global.current_book, Global.current_lesson)
	lesson_data = data
	units = lesson_data.get("units", [])

	var accent_str: String = lesson_data.get("theme_color", "")
	if accent_str != "":
		_accent = Color(accent_str)


# ============================================================
# SHELL UI
# ============================================================

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = GrammarTheme.background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Clear a generous margin around the whole screen (phone notch safe).
	safe_area.add_theme_constant_override("margin_left", GrammarTheme.SAFE_MARGIN)
	safe_area.add_theme_constant_override("margin_right", GrammarTheme.SAFE_MARGIN)
	safe_area.add_theme_constant_override("margin_top", GrammarTheme.SAFE_MARGIN)
	safe_area.add_theme_constant_override("margin_bottom", GrammarTheme.SAFE_MARGIN)
	add_child(safe_area)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", GrammarTheme.SPACING_MD)
	safe_area.add_child(main)

	# Invisible breathing room above the header bar.
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 50)
	main.add_child(top_gap)

	# ---- Header box: raised bar (distinct color + shadow) with the
	#      back/title/XP top bar and the progress row inside it.
	var header_box := PanelContainer.new()
	GrammarTheme.style_header_box(header_box)
	main.add_child(header_box)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 16)
	header_margin.add_theme_constant_override("margin_right", 16)
	header_margin.add_theme_constant_override("margin_top", 12)
	header_margin.add_theme_constant_override("margin_bottom", 12)
	header_box.add_child(header_margin)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 8)
	header_margin.add_child(header_vbox)

	_build_top_bar(header_vbox)
	_build_progress(header_vbox)

	# ---- Content box: a centered card wrapping everything the student
	#      actually reads / interacts with.
	var content_box := PanelContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GrammarTheme.style_card(content_box)
	main.add_child(content_box)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_right", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_top", GrammarTheme.CONTENT_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", GrammarTheme.CONTENT_MARGIN)
	content_box.add_child(content_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", GrammarTheme.SPACING_LG)
	scroll.add_child(content_container)

	# Feedback popup is a full-screen centered overlay (on the root so it
	# floats above everything and centers on the whole screen).
	feedback_popup = FeedbackPopup.new()
	add_child(feedback_popup)
	feedback_popup.continue_pressed.connect(_on_feedback_continue)
	feedback_popup.skip_pressed.connect(_on_skip_pressed)

	# Full-screen reward overlay shown after each completed بخش.
	reward_popup = RewardPopup.new()
	add_child(reward_popup)
	reward_popup.next_requested.connect(_on_reward_next)
	reward_popup.back_requested.connect(_on_reward_back)

	# The hint light-bulb floats near the bottom-centre of the big content
	# card. It flashes after a wrong answer and reveals a friendly hint when
	# tapped.
	hint_bulb = GrammarHint.new()
	hint_bulb.name = "HintBulb"
	hint_bulb.anchor_left = 0.0
	hint_bulb.anchor_right = 1.0
	hint_bulb.anchor_top = 1.0
	hint_bulb.anchor_bottom = 1.0
	hint_bulb.offset_left = 20
	hint_bulb.offset_right = -20
	hint_bulb.offset_top = -230
	hint_bulb.offset_bottom = -6
	hint_bulb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_bulb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	content_box.add_child(hint_bulb)
	hint_bulb.hint_requested.connect(_on_hint_requested)


func _build_top_bar(main: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 64)
	main.add_child(top_bar)

	var back_button: Button = GrammarTheme.make_header_icon_button("res://images/Back.png", Callable(self, "_on_back_pressed"))
	top_bar.add_child(back_button)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", GrammarTheme.SECTION_SIZE)
	title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	top_bar.add_child(title_label)

	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "⭐ 0"
	xp_label.custom_minimum_size = Vector2(80, 64)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SIZE)
	xp_label.add_theme_color_override("font_color", GrammarTheme.xp_color())
	xp_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	top_bar.add_child(xp_label)

	# Same item grid as every other header in the app: back left, title
	# centred, the XP badge on the right.
	GrammarTheme.unify_header_row(top_bar)


func _build_progress(main: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 32)
	main.add_child(row)

	# Caption pinned to the LEFT of the bar, fixed width, centered with it.
	progress_label = Label.new()
	progress_label.custom_minimum_size = Vector2(90, 32)
	progress_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress_label.add_theme_font_size_override("font_size", GrammarTheme.CAPTION_SIZE)
	progress_label.add_theme_color_override("font_color", GrammarTheme.text_secondary_color())
	row.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.custom_minimum_size = Vector2(0, 14)
	progress_bar.add_theme_stylebox_override("background", GrammarTheme.rounded_box(GrammarTheme.disabled_color(), 8))
	progress_bar.add_theme_stylebox_override("fill", GrammarTheme.rounded_box(_accent, 8))
	row.add_child(progress_bar)


# ============================================================
# UNIT FLOW
# ============================================================

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

	GrammarTheme.set_bidi_text(
		title_label,
		str(lesson_data.get("title_fa", "گرامر"))
	)
	_show_current_activity()


# Renders the activity at _activity_index inside the current unit (a group
# may hold several activities; a plain unit is treated as a single-activity
# group so both flows share one path).
func _show_current_activity() -> void:
	for child in content_container.get_children():
		child.queue_free()

	if _activity_index >= _activities.size():
		_on_activity_group_finished()
		return

	# Caption shows ONLY the activities progress inside the current unit.
	progress_label.text = "%d / %d" % [_activity_index + 1, _activities.size()]
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
			# Unknown activity type: never award XP / progress for it. Skip to
			# the next activity (or finish the unit if this was the last one)
			# and warn loudly so authoring mistakes are visible in logs.
			push_warning("Unknown grammar activity type: %s (skipped)" % type)
			_advance_activity()
			return


# Advances to the next activity inside the current unit/group. When the
# group is exhausted, XP is awarded once and the unit is complete.
func _advance_activity() -> void:
	_activity_index += 1
	if _activity_index < _activities.size():
		_show_current_activity()
	else:
		_on_activity_group_finished()


func _on_activity_group_finished() -> void:
	_sync_grammar_progress()
	_award_unit_xp()
	# Every activity in the unit is done: fill the progress bar all the way
	# and give it a beat to visibly complete before the reward popup covers
	# the screen.
	_fill_progress_bar()
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree():
		return
	_show_unit_completed_reward()


func _show_learning_unit(unit: Dictionary) -> void:
	LearningUnitView.render(content_container, unit)

	var next_button := Button.new()
	next_button.text = "متوجه شدم ✓"
	next_button.custom_minimum_size = Vector2(0, 112)
	next_button.pressed.connect(_on_learning_continue)
	GrammarTheme.style_primary_button(next_button)
	next_button.add_theme_font_size_override("font_size", 46)
	content_container.add_child(next_button)
	GrammarAnimation.appear(next_button, 0.2)


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


# ============================================================
# FEEDBACK / XP
# ============================================================

func _on_answer_selected(correct: bool, explanation: String) -> void:
	# XP is only earned when a whole بخش is completed (_award_unit_xp),
	# never per individual answer.
	if correct:
		correct_answers += 1
		_wrong_attempts = 0
		# Correct answer: hide the bulb again (no hint needed anymore).
		hint_bulb.visible = false
		hint_bulb.stop_flash()
		hint_bulb.hide_bubble()
		feedback_popup.show_correct(explanation)
	else:
		_wrong_attempts += 1
		# Wrong answer: stay on the question and reveal the hint bulb
		# with a heartbeat pulse so the learner can ask for help.
		hint_bulb.visible = true
		hint_bulb.flash()
		feedback_popup.show_wrong(explanation)
		# After two failed attempts, offer a skip so the learner can move
		# on to the next question.
		if _wrong_attempts >= 2:
			feedback_popup.show_skip_button()


func _update_xp_label() -> void:
	if xp_label != null:
		xp_label.text = "⭐ %d" % xp


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
	# A correct answer advances to the next item; a wrong one stays on the
	# same item so the learner retries it (the hint bulb can help).
	if feedback_popup.is_correct:
		exercise.continue_to_next()
	else:
		exercise.retry_current()


func _on_skip_pressed() -> void:
	# The learner has failed twice and chose to skip; move on to the next
	# question and reset the wrong-attempt counter + hide the hint bulb.
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


# Awards XP for finishing the current بخش and persists it. Uses the
# lesson's xp_per_unit value (default 10). XP is only granted the FIRST
# time a بخش is completed — replaying it grants nothing.
func _award_unit_xp() -> void:
	var unit: Dictionary = units[current_unit_index] if current_unit_index < units.size() else {}
	var unit_id := str(unit.get("id", ""))
	var already_done: bool = Global.is_unit_completed(
		Global.current_book, Global.current_lesson, current_unit_index, unit_id
	)
	Global.mark_unit_completed(
		Global.current_book, Global.current_lesson, current_unit_index, unit_id
	)
	if already_done:
		_last_award = 0
	else:
		_last_award = int(lesson_data.get("xp_per_unit", 10))
		xp += _last_award
		Global.add_grammar_xp(Global.current_book, Global.current_lesson, _last_award)
	_update_xp_label()


# ============================================================
# UNIT REWARD / FINISH
# ============================================================

# After a بخش finishes, show the reward popup with a "next بخش" button
# (and a "back to بخش‌ها" button). The very last بخش triggers the end.
func _show_unit_completed_reward() -> void:
	if current_unit_index >= units.size() - 1:
		_finish_lesson()
		return
	var n: int = current_unit_index + 1
	reward_popup.show_reward("بخش %d کامل شد!" % n, _last_award, "رفتن به بخش بعدی", true)


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

	reward_popup.show_reward("بخش کامل شد!", _last_award, "بازگشت به بخش‌ها", false)
	Sfx.complete()


# Called once a بخش finishes. current_unit_index still points at the just
# completed بخش, so unlocking the next one means recording index + 2 (capped
# at the lesson size).
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
