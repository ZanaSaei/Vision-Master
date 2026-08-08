class_name ExerciseEngine
extends VBoxContainer

## Thin orchestrator. Delegates UI building to Builders, grading to ExerciseGrader,
## persistence to ExercisePersistence, and styling to ExerciseTheme.
## This file contains NO widget factories, NO grading logic, and NO builder logic.

signal exercise_checked(exercise_id: String, correct: int, total: int)

# ---------- Configuration ----------
@export var use_internal_scroll := false
var audio_panel_scene_path := "res://scenes/shared/AudioPanel.tscn"
var audio_types: Array = []
var audio_allow_any_type := false

# ---------- State ----------
var _data: ExerciseData
var _items: Array[ExerciseData.Item] = []
var _current_builder: ExerciseBuilder = null
var _active_vbox: VBoxContainer
var _scroll: ScrollContainer = null

# ---------- UI References ----------
var _score_banner: Label = null
var _check_btn: Button = null
var _reveal_btn: Button = null
var _done_btn: Button = null
var _note_label: Label = null

# ---------- Flags ----------
var _is_graded := false
var _is_open_ended := false
var _is_non_interactive := false

# ---------- Components ----------
var _gesture_handler: ExerciseGestureHandler
var _audio_controller: AudioController

static var _group_counter := 0

# ==========================================================
# LIFECYCLE
# ==========================================================

func _ready() -> void:
	add_theme_constant_override("separation", ExerciseTheme.SPACING.item)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_group("exercise_engines")

	_gesture_handler = ExerciseGestureHandler.new()
	add_child(_gesture_handler)

	_audio_controller = AudioController.new()
	_audio_controller.audio_panel_scene_path = audio_panel_scene_path
	add_child(_audio_controller)

	_ensure_components()

	_ensure_layout_target()

# ==========================================================
# MAIN BUILD ENTRY
# ==========================================================

func build(exercise: Dictionary, increment_group := true) -> void:
	_ensure_components()
	_data = ExerciseData.new(exercise)
	_items.clear()
	_is_graded = false

	var type := _data.get_type()
	_is_open_ended = type in ["open_ended", "pronunciation", "writing"]
	_is_non_interactive = type in ["passage", "reading"]

	# Reset UI references
	_note_label = null
	_score_banner = null
	_check_btn = null
	_reveal_btn = null
	_done_btn = null

	_ensure_layout_target()

	# Clear existing content
	for child in _active_vbox.get_children():
		_active_vbox.remove_child(child)
		child.queue_free()

	# Build the layout shell
	_add_badge()
	_create_master_panel()

	if type not in ["cloze", "text_highlight", "text_highlight_multi"]:
		_add_common_passage()

	_add_instruction()

	if type != "image_hotspot":
		_add_images()

	_add_audio_button()

	# Delegate exercise-specific UI to the appropriate builder
	_current_builder = ExerciseTypeRegistry.get_builder(type)
	if _current_builder:
		_current_builder.build(_active_vbox, _data, _items, _gesture_handler)

	# Restore saved answers for open-ended types
	_restore_saved_answers()

	# Connect text-change signals for open-ended TextEdits
	for item in _items:
		if item.text_edit != null:
			item.text_edit.text_changed.connect(_on_open_ended_text_changed)

	_add_note()
	_add_footer_buttons()

	if _scroll != null:
		_scroll.scroll_vertical = 0

	if increment_group:
		_group_counter += 1

# ==========================================================
# LAYOUT HELPERS
# ==========================================================

func _ensure_layout_target() -> void:
	if _active_vbox != null:
		return

	if not use_internal_scroll:
		_active_vbox = self
		return

	_scroll = ScrollContainer.new()
	_scroll.name = "ExerciseScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_active_vbox = VBoxContainer.new()
	_active_vbox.name = "ExerciseContent"
	_active_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_active_vbox.add_theme_constant_override("separation", ExerciseTheme.SPACING.item)
	_scroll.add_child(_active_vbox)

func _add_badge() -> void:
	var meta: Dictionary = ExerciseTheme.TYPE_META.get(_data.get_type(), ExerciseTheme.TYPE_META["open_ended"])
	var accent: Color = meta["color"]

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(meta["badge"])
	badge.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.badge)
	badge.add_theme_color_override("font_color", Color.WHITE)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = accent
	badge_style.set_corner_radius_all(20)
	badge_style.set_content_margin_all(ExerciseTheme.PADDING.badge)
	badge.add_theme_stylebox_override("normal", badge_style)

	if ExerciseTheme.font_bold:
		badge.add_theme_font_override("font", ExerciseTheme.font_bold)

	header.add_child(badge)
	_active_vbox.add_child(header)

func _create_master_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var meta: Dictionary = ExerciseTheme.TYPE_META.get(_data.get_type(), ExerciseTheme.TYPE_META["open_ended"])
	var style := StyleBoxFlat.new()
	style.bg_color = ExerciseTheme.COLORS.tint
	style.set_corner_radius_all(16)
	style.border_width_left = 8
	style.border_color = meta["color"]
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.set_content_margin_all(ExerciseTheme.PADDING.panel)
	panel.add_theme_stylebox_override("panel", style)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vbox.add_theme_constant_override("separation", ExerciseTheme.SPACING.section)
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(inner_vbox)

	_active_vbox.add_child(panel)

	# Redirect further additions into the panel's inner container
	_active_vbox = inner_vbox

func _add_common_passage() -> void:
	var passage_raw: Variant = _data.raw.get("passage", _data.raw.get("reading", ""))
	if passage_raw == null:
		return

	var text := ""
	if passage_raw is Array:
		var paras: Array = []
		for p in passage_raw:
			var s := ExerciseData.get_en_text(p)
			if s != "":
				paras.append(s)
		text = "\n\n".join(paras)
	else:
		text = ExerciseData.get_en_text(passage_raw)

	if text.strip_edges() == "":
		return

	var title := ExerciseData.get_en_text(_data.raw.get("passage_title", ""))
	if title != "":
		var title_label := ExerciseTheme.make_label(title, "title", "primary", true)
		_active_vbox.add_child(title_label)

	var rtl := RichTextLabel.new()
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(0, 120)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", ExerciseTheme.FONT_SIZES.body)
	rtl.add_theme_color_override("default_color", ExerciseTheme.COLORS.text)
	if ExerciseTheme.font_regular:
		rtl.add_theme_font_override("normal_font", ExerciseTheme.font_regular)
	rtl.text = text

	if passage_raw is Dictionary:
		rtl.set_meta("text_fa", ExerciseData.get_fa_text(passage_raw))

	_active_vbox.add_child(rtl)

func _add_instruction() -> void:
	var text_raw = _data.raw.get("instruction", "")
	var text_val := ExerciseData.get_en_text(text_raw)
	if text_val == "":
		return

	var show_letter := bool(_data.raw.get("show_letter", true))
	var final_text := text_val
	if show_letter:
		var letter_code := char(65 + (_group_counter % 26))
		final_text = letter_code + ". " + text_val

	var instruction := Label.new()
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction.text = final_text
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	instruction.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.title)
	instruction.add_theme_color_override("font_color", ExerciseTheme.COLORS.text)
	instruction.set_meta("text_fa", ExerciseData.get_fa_text(text_raw))
	if ExerciseTheme.font_bold:
		instruction.add_theme_font_override("font", ExerciseTheme.font_bold)
	_active_vbox.add_child(instruction)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style := StyleBoxLine.new()
	sep_style.color = ExerciseTheme.COLORS.muted.lightened(0.7)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	_active_vbox.add_child(sep)

func _add_note() -> void:
	var note_raw = _data.raw.get("note", "")
	var note := ExerciseData.get_en_text(note_raw)
	if note == "":
		return

	_note_label = ExerciseTheme.make_label("Info: " + note, "hint", "muted", false)
	_note_label.set_meta("text_fa", ExerciseData.get_fa_text(note_raw))
	_note_label.visible = false
	if _is_open_ended or _is_non_interactive:
		_note_label.visible = true
	_active_vbox.add_child(_note_label)

func _add_images() -> void:
	var images: Array = _data.raw.get("images", [])
	if images.is_empty():
		var single_img = _data.raw.get("image", "")
		if single_img != "":
			images = [single_img]

	for img_data in images:
		_active_vbox.add_child(_make_media_control(img_data))

func _make_media_control(img_data: Variant) -> Control:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var path := ""
	var caption := ""
	var max_width := int(_data.raw.get("image_max_width", 360))
	var min_height := int(_data.raw.get("image_min_height", 180))

	if img_data is Dictionary:
		path = str(img_data.get("path", img_data.get("image", "")))
		caption = ExerciseData.get_en_text(img_data.get("caption", ""))
		max_width = int(img_data.get("max_width", max_width))
		min_height = int(img_data.get("min_height", min_height))
	else:
		path = str(img_data)

	max_width = _safe_media_width(max_width)

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

func _safe_media_width(requested: int) -> int:
	var vp := get_viewport()
	var vp_width := 1280.0
	if vp != null:
		var w := vp.get_visible_rect().size.x
		if w > 0.0:
			vp_width = w
	var max_allowed := int(vp_width) - 80
	return clampi(requested, 120, maxi(max_allowed, 160))

func _add_audio_button() -> void:
	var type := _data.get_type()
	if not _should_show_audio_button(type):
		return

	var audio_path := _get_audio_path()
	if audio_path == "":
		return

	var audio_btn := ExerciseTheme.make_button("Play the Audio", "purple")
	_active_vbox.add_child(audio_btn)
	_audio_controller.setup_audio_button(audio_btn, audio_path)

func _should_show_audio_button(type: String) -> bool:
	if _data.raw.has("show_audio"):
		return bool(_data.raw.get("show_audio"))
	if audio_allow_any_type:
		return true
	return audio_types.has(type)

func _get_audio_path() -> String:
	var raw: Variant = _data.raw.get("audio", "")
	if raw is Dictionary:
		return str(raw.get("path", ""))
	return str(raw)

func _add_footer_buttons() -> void:
	if _is_non_interactive:
		return

	var graded_count := 0
	var has_sample := false
	for item in _items:
		if item.get_func != null:
			graded_count += 1
		if item.sample_label != null:
			has_sample = true

	if graded_count > 0:
		_score_banner = Label.new()
		_score_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_score_banner.autowrap_mode = TextServer.AUTOWRAP_WORD
		_score_banner.add_theme_font_size_override("font_size", ExerciseTheme.FONT_SIZES.body)
		_score_banner.visible = false
		if ExerciseTheme.font_bold:
			_score_banner.add_theme_font_override("font", ExerciseTheme.font_bold)
		_active_vbox.add_child(_score_banner)

	var btn_row := HBoxContainer.new()
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_theme_constant_override("separation", ExerciseTheme.SPACING.button_row)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _is_open_ended:
		if has_sample:
			_reveal_btn = ExerciseTheme.make_button("Show Sample Answer", "orange")
			_reveal_btn.pressed.connect(_on_reveal_sample)
			btn_row.add_child(_reveal_btn)
		_done_btn = ExerciseTheme.make_button("Save", "success")
		_done_btn.pressed.connect(_on_open_ended_done)
		btn_row.add_child(_done_btn)
	elif graded_count > 0:
		_check_btn = ExerciseTheme.make_button("Check Answer", "primary")
		_check_btn.pressed.connect(_on_check_pressed)
		btn_row.add_child(_check_btn)

	if btn_row.get_child_count() > 0:
		_active_vbox.add_child(btn_row)

# ==========================================================
# GRADING
# ==========================================================

func _on_check_pressed() -> void:
	if _is_graded:
		_reset_for_retry()
		return

	# Delegate to builders that handle their own grading (e.g., word_search)
	if _current_builder != null and _current_builder.handles_custom_grading():
		var result := _current_builder.grade_custom(_items)
		if result != null:
			_apply_grade_result(result)
		return

	_grade_standard()

func _grade_standard() -> void:
	var correct := 0
	var total := 0

	for item in _items:
		if item.get_func == null:
			continue
		total += 1

		var user_answer = item.get_func.call()
		var fb: Label = item.feedback_label
		if fb == null:
			continue

		fb.visible = true
		var user_str := str(user_answer).strip_edges()
		var item_type := str(item.type)

		# Special case: empty text input
		var text_input_types := ["fill_blank", "chart_fill", "transformation", "letter_scramble", "error_correction", "passive_transformation", "question_formation"]
		if user_str == "" and item_type in text_input_types:
			fb.text = "Empty"
			fb.add_theme_color_override("font_color", ExerciseTheme.COLORS.warning)
			continue

		var result := ExerciseGrader.grade_item(user_answer, item)

		if result.is_correct:
			correct += 1
			if item_type in ["text_highlight", "text_highlight_multi"]:
				fb.text = "✓"
			else:
				fb.text = "Correct!"
			fb.add_theme_color_override("font_color", ExerciseTheme.COLORS.success)
		else:
			if item_type in ["text_highlight", "text_highlight_multi"]:
				fb.text = "✗"
			else:
				var answer_text: String = item.answer_display if item.answer_display != "" else ExerciseGrader.format_answer(item.answer)
				fb.text = "Correct answer: " + answer_text
				if item.explanation_en != "":
					fb.text += "\n" + item.explanation_en
			fb.add_theme_color_override("font_color", ExerciseTheme.COLORS.error)

	_is_graded = true

	if _score_banner:
		_score_banner.visible = true
		if total > 0 and correct == total:
			_score_banner.text = "Excellent! %d/%d correct!" % [correct, total]
			_score_banner.add_theme_color_override("font_color", ExerciseTheme.COLORS.success)
		else:
			_score_banner.text = "You got %d/%d." % [correct, total]
			_score_banner.add_theme_color_override("font_color", ExerciseTheme.COLORS.primary)

	if _note_label:
		_note_label.visible = true
	if _check_btn:
		_check_btn.text = "Try Again"

	exercise_checked.emit(_data.get_id(), correct, total)

func _apply_grade_result(result: ExerciseGrader.Result) -> void:
	_is_graded = true

	if _score_banner:
		_score_banner.visible = true
		_score_banner.text = result.feedback_text
		_score_banner.add_theme_color_override("font_color", result.feedback_color)

	if _note_label:
		_note_label.visible = true
	if _check_btn:
		_check_btn.text = "Try Again"

	exercise_checked.emit(_data.get_id(), result.correct_count, result.total_count)

func _reset_for_retry() -> void:
	_is_graded = false
	if _score_banner:
		_score_banner.visible = false
	if _check_btn:
		_check_btn.text = "Check Answer"
	build(_data.raw, false)

# ==========================================================
# OPEN-ENDED HANDLERS
# ==========================================================

func _restore_saved_answers() -> void:
	if _data.get_type() in ["open_ended", "pronunciation", "writing"]:
		ExercisePersistence.load_open_ended(_data.get_id(), _items)

func _on_reveal_sample() -> void:
	var is_showing := false
	for item in _items:
		if item.sample_label != null and is_instance_valid(item.sample_label):
			item.sample_label.visible = not item.sample_label.visible
			if item.sample_label.visible:
				is_showing = true

	if _reveal_btn:
		if is_showing:
			_reveal_btn.text = "Hide Sample Answer"
			ExerciseTheme.set_button_color(_reveal_btn, ExerciseTheme.COLORS.muted)
		else:
			_reveal_btn.text = "Show Sample Answer"
			ExerciseTheme.set_button_color(_reveal_btn, ExerciseTheme.COLORS.orange)

func _on_open_ended_done() -> void:
	ExercisePersistence.save_open_ended(_data.get_id(), _items)

	if _note_label:
		_note_label.visible = true
	if _done_btn:
		_done_btn.text = "Saved"
		ExerciseTheme.set_button_color(_done_btn, ExerciseTheme.COLORS.muted)

	exercise_checked.emit(_data.get_id(), 1, 1)

func _on_open_ended_text_changed() -> void:
	if _done_btn != null and _done_btn.text == "Saved":
		_done_btn.text = "Save"
		ExerciseTheme.set_button_color(_done_btn, ExerciseTheme.COLORS.success)

func _ensure_components() -> void:
	if _gesture_handler == null:
		_gesture_handler = ExerciseGestureHandler.new()
		add_child(_gesture_handler)
	if _audio_controller == null:
		_audio_controller = AudioController.new()
		_audio_controller.audio_panel_scene_path = audio_panel_scene_path
		add_child(_audio_controller)
