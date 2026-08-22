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

var title_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var xp_label: Label

var content_container: VBoxContainer
var feedback_popup: FeedbackPopup
var reward_popup: RewardPopup

var _accent := GrammarTheme.PRIMARY

var _progress_tween: Tween


func _animate_progress() -> void:
	var target := (float(current_unit_index) / float(units.size())) * 100.0
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_QUAD)
	_progress_tween.set_ease(Tween.EASE_OUT)
	_progress_tween.tween_property(progress_bar, "value", target, 0.6)


func _ready() -> void:
	super._ready()
	_load_lesson()
	if units.is_empty():
		current_unit_index = 0
	else:
		current_unit_index = clampi(Global.grammar_start_unit_index, 0, units.size() - 1)
	Global.grammar_start_unit_index = 0
	_build_ui()
	_show_unit()


# ============================================================
# DATA
# ============================================================

func _load_lesson() -> void:
	var data := GrammarData.load_lesson(Global.current_book, Global.current_lesson)
	if data.is_empty():
		# Fall back to the bundled sample so the scene is never blank.
		data = GrammarData.load_lesson(1, 1)
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
	background.color = GrammarTheme.BACKGROUND
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

	# Full-screen reward overlay for completion.
	reward_popup = RewardPopup.new()
	add_child(reward_popup)
	reward_popup.finished.connect(_on_back_pressed)


func _build_top_bar(main: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 64)
	main.add_child(top_bar)

	var back_button := Button.new()
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(64, 64)
	back_button.add_theme_font_size_override("font_size", 40)
	back_button.add_theme_color_override("font_color", GrammarTheme.TEXT)
	back_button.add_theme_color_override("font_hover_color", GrammarTheme.PRIMARY_DARK)
	back_button.pressed.connect(_on_back_pressed)
	GrammarTheme.style_secondary_button(back_button)
	top_bar.add_child(back_button)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", GrammarTheme.SECTION_SIZE)
	title_label.add_theme_color_override("font_color", GrammarTheme.TEXT)
	title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	top_bar.add_child(title_label)

	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "⭐ 0"
	xp_label.custom_minimum_size = Vector2(80, 64)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", GrammarTheme.BODY_SIZE)
	xp_label.add_theme_color_override("font_color", GrammarTheme.XP)
	xp_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	top_bar.add_child(xp_label)


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
	progress_label.add_theme_color_override("font_color", GrammarTheme.TEXT_SECONDARY)
	row.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.custom_minimum_size = Vector2(0, 14)
	progress_bar.add_theme_stylebox_override("background", GrammarTheme.rounded_box(GrammarTheme.DISABLED, 8))
	progress_bar.add_theme_stylebox_override("fill", GrammarTheme.rounded_box(_accent, 8))
	row.add_child(progress_bar)


# ============================================================
# UNIT FLOW
# ============================================================

func _show_unit() -> void:
	if current_unit_index >= units.size():
		_finish_lesson()
		return

	for child in content_container.get_children():
		child.queue_free()

	var unit: Dictionary = units[current_unit_index]
	var type := str(unit.get("type", ""))

	title_label.text = str(lesson_data.get("title_fa", "گرامر"))
	progress_label.text = "%d / %d" % [current_unit_index + 1, units.size()]
	_animate_progress()

	match type:
		"learn":
			_show_learning_unit(unit)
		"multiple_choice", "fill_blank", "true_false", "matching", "unscramble":
			_show_exercise(unit)
		_:
			push_warning("Unknown grammar unit type: " + type)


func _show_learning_unit(unit: Dictionary) -> void:
	LearningUnitView.render(content_container, unit)

	var next_button := Button.new()
	next_button.text = "متوجه شدم ✓"
	next_button.custom_minimum_size = Vector2(0, GrammarTheme.BUTTON_HEIGHT)
	next_button.pressed.connect(_on_learning_continue)
	GrammarTheme.style_primary_button(next_button)
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
	if correct:
		xp += int(lesson_data.get("xp_per_correct", 10))
		correct_answers += 1
		_update_xp_label()
		feedback_popup.show_correct(explanation)
	else:
		feedback_popup.show_wrong(explanation)


func _update_xp_label() -> void:
	if xp_label != null:
		xp_label.text = "⭐ %d" % xp


func _on_feedback_continue() -> void:
	for child in content_container.get_children():
		if child is GrammarExercise:
			child.continue_to_next()
			return


func _on_learning_continue() -> void:
	current_unit_index += 1
	_sync_grammar_progress()
	_show_unit()


func _on_exercise_completed() -> void:
	current_unit_index += 1
	_sync_grammar_progress()
	_show_unit()


# ============================================================
# FINISH
# ============================================================

func _finish_lesson() -> void:
	for child in content_container.get_children():
		child.queue_free()

	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_QUAD)
	_progress_tween.set_ease(Tween.EASE_OUT)
	_progress_tween.tween_property(progress_bar, "value", 100.0, 0.6)

	_update_xp_label()

	reward_popup.show_reward("بخش کامل شد!", xp)
	Sfx.complete()


func _sync_grammar_progress() -> void:
	var unlocked: int = current_unit_index + 1
	if units.size() > 0:
		unlocked = min(unlocked, units.size())
	Global.set_grammar_unlocked_units(Global.current_book, Global.current_lesson, unlocked)


func _on_back_pressed() -> void:
	var last_scene: String = Global.get_last_scene()
	if last_scene.is_empty():
		last_scene = LESSON_MENU
	TransitionManager.slide_change_scene(last_scene, TransitionManager.Slide.BACK)


func _on_android_back_pressed() -> void:
	_on_back_pressed()
