# ============================================================
# ExerciseEngine - BUILDERS layer.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# Holds: build() dispatcher, badge/instructions/passage/common
# blocks and every _build_* exercise-type method.
# ============================================================
class_name ExerciseEngineBuilders
extends "res://scenes/shared/exercise_engine/exercise_engine_widgets.gd"
const HotspotOverlayScript := preload("res://scenes/shared/exercise_engine/HotspotOverlay.gd")

# ---------- Virtual dispatch stubs (overridden by the grading layer) ----------
# The UI-building code in this layer wires these callbacks up. The grading
# layer (ExerciseEngineGrading, a descendant) provides the real implementations;
# GDScript virtual dispatch routes every call/connection to the override.
func _on_check_pressed() -> void:
	pass

func _on_reveal_sample() -> void:
	pass

func _on_open_ended_done() -> void:
	pass

# Default (non-graded) implementation; overridden by grading. Params are
# intentionally unused here — they are used by the override.
@warning_ignore("unused_parameter")
func _is_item_correct(item: Dictionary, user_answer: Variant) -> bool:
	return false

# ---------- build() dispatcher ----------
func build(exercise: Dictionary, _increment_group := true) -> void:
	_exercise = exercise
	_items.clear()
	_is_graded = false
	_note_label = null
	_score_banner = null
	_check_btn = null
	_reveal_btn = null
	_done_btn = null
	_is_saved = false
	# Reset audio state for the new exercise.
	_audio_btn = null
	_audio_path = ""
	_drag_source = null
	_drag_active = false
	_clear_order_drag_state()

	var type := str(exercise.get("type", "open_ended"))
	_is_open_ended = type == "open_ended" or type == "pronunciation" or type == "writing"
	_is_non_interactive = type == "passage" or type == "reading"

	_ensure_layout_target()
	for child in _target.get_children():
		_target.remove_child(child)
		child.queue_free()
		# If the old spacer belonged to this engine's content, it was just freed.
	if _keyboard_spacer != null:
		if not is_instance_valid(_keyboard_spacer) or _keyboard_spacer.get_parent() == null:
			_keyboard_spacer = null

	_add_badge()
	_create_master_panel()

	# Types that render their own passage should not duplicate it.
	if type != "cloze" and type != "text_highlight" and type != "text_highlight_multi":
		_add_common_passage()

	_add_instruction()

	# image_hotspot renders its own interactive image.
	if type != "image_hotspot":
		_add_images()

# Add the Play/Stop audio button if this exercise has audio.
	_add_audio_button()

	match type:
		"multiple_choice":
			_build_multiple_choice()
		"true_false":
			_build_true_false()
		"matching":
			_build_matching()
		"fill_blank":
			_build_fill_blank()
		"cloze":
			_build_cloze()
		"ordering":
			_build_ordering()
		"categorize":
			_build_categorize()
		"open_ended", "pronunciation", "writing":
			_build_open_ended()
		"passage", "reading":
			pass
		"word_bank":
			_build_word_bank()
		"sentence_ordering", "sentence_unscramble":
			_build_sentence_ordering()
		"letter_scramble":
			_build_letter_scramble()
		"table_fill":
			_build_table_fill()
		"table_fill_advanced":
			_build_table_fill_advanced()
		"text_highlight":
			_build_text_highlight()
		"text_highlight_multi":
			_build_text_highlight_multi()
		"transformation":
			_build_transformation()
		"error_correction":
			_build_error_correction()
		"word_building":
			_build_word_building()
		"word_search", "word_find":
			_build_word_search()
		"chart_fill":
			_build_chart_fill()
		"odd_one_out":
			_build_odd_one_out()
		"grammar_choice":
			_build_grammar_choice()
		"passive_transformation":
			_build_passive_transformation()
		"grammar_identification":
			_build_grammar_identification()
		"question_formation":
			_build_question_formation()
		"token_label":
			_build_token_label()
		"image_choice":
			_build_image_choice()
		"image_match":
			_build_image_match()
		"image_hotspot":
			_build_image_hotspot()
		_:
			_build_open_ended()

	_add_note()
	_add_footer_buttons()

	if _scroll != null:
		_scroll.scroll_vertical = 0

# ---------- badge, instructions, passages & all exercise-type builders ----------
func _add_badge() -> void:
	var type := str(_exercise.get("type", "open_ended"))
	var meta: Dictionary = TYPE_META.get(type, TYPE_META["open_ended"])
	var accent: Color = meta["color"]

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = "  " + str(meta["badge"]) + "  "
	badge.add_theme_font_size_override("font_size", 30)
	badge.add_theme_color_override("font_color", Color.WHITE)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = accent
	badge_style.set_corner_radius_all(40)
	badge_style.set_content_margin_all(10)
	badge_style.content_margin_left = 20
	badge_style.content_margin_right = 20
	badge_style.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	badge_style.shadow_size = 8
	badge_style.shadow_offset = Vector2(0, 3)
	badge.add_theme_stylebox_override("normal", badge_style)

	if _font_bold:
		badge.add_theme_font_override("font", _font_bold)

	header.add_child(badge)
	_target.add_child(header)


func _create_master_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = _c_surface()
	style.set_corner_radius_all(24)
	_master_panel_style = style

	var type := str(_exercise.get("type", "open_ended"))
	var meta: Dictionary = TYPE_META.get(type, TYPE_META["open_ended"])
	# Left accent stripe is thicker (10px) for a stronger visual anchor.
	style.border_width_left = 10
	style.border_color = meta["color"]
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28

	panel.add_theme_stylebox_override("panel", style)

	_active_vbox = VBoxContainer.new()
	_active_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_vbox.add_theme_constant_override("separation", 28)
	_active_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	panel.add_child(_active_vbox)
	_target.add_child(panel)


func _add_common_passage() -> void:
	var passage_raw: Variant = _exercise.get("passage", _exercise.get("reading", ""))
	if passage_raw == null:
		return
	var text := ""
	if passage_raw is Array:
		var paras: Array = []
		for p in passage_raw:
			var s := _get_en_text(p)
			if s != "":
				paras.append(s)
		text = "\n\n".join(paras)
	else:
		text = _get_en_text(passage_raw)
	if text.strip_edges() == "":
		return

	var title := _get_en_text(_exercise.get("passage_title", ""))
	if title != "":
		var title_label := _make_label(title, 36, C_PRIMARY, true)
		_active_vbox.add_child(title_label)

	var rtl := RichTextLabel.new()
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(0, 120)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 40)
	rtl.add_theme_font_size_override("bold_font_size", 40)
	rtl.add_theme_font_size_override("italics_font_size", 40)
	rtl.add_theme_font_size_override("bold_italics_font_size", 40)
	rtl.add_theme_color_override("default_color", _c_text())
	if _font_regular:
		rtl.add_theme_font_override("normal_font", _font_regular)
	rtl.text = text
	if passage_raw is Dictionary:
		rtl.set_meta("text_fa", _get_fa_text(passage_raw))
	_active_vbox.add_child(rtl)
	_add_fa_label(_get_fa_text(passage_raw), 32)


# ------------------------------------------------------------
# Returns this engine's 0-based position among its ExerciseEngine
# siblings under the same parent (e.g. the lesson page's VBox).
# This replaces the previous approach of a global static counter,
# which never reset between lessons and could drift (Lesson 5's
# first exercise showing "F." because of exercises the student did
# earlier in the same app session). Because this is recomputed from
# the live scene tree on every build(), it is always correct for
# whatever page currently has this engine as a child, with no
# manual reset required anywhere else in the app.
# ------------------------------------------------------------
func _compute_letter_index() -> int:
	var parent := get_parent()
	if parent == null:
		return 0
	var idx := 0
	# Count how many sibling ExerciseEngine instances precede this one.
	# We check the type directly instead of group membership because the
	# engine's _ready() (which registers the "exercise_engines" group) only
	# fires once the node is inside the scene tree — but build() is typically
	# called while the parent page is still detached, so the group would be
	# empty and every engine would incorrectly report index 0 (i.e. "A").
	for child in parent.get_children():
		if child == self:
			return idx
		if child is ExerciseEngineBuilders:
			idx += 1
	return idx


func _add_instruction() -> void:
	var text_raw = _exercise.get("instruction", "")
	var text_val := _get_en_text(text_raw)
	if text_val == "":
		return
	var show_letter := bool(_exercise.get("show_letter", true))
	var final_text := text_val
	if show_letter:
		var letter_code := char(65 + (_compute_letter_index() % 26))
		final_text = letter_code + ". " + text_val

	var instruction := Label.new()
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction.text = GrammarTheme.bidi_fix(final_text)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	instruction.add_theme_font_size_override("font_size", 44)
	instruction.add_theme_color_override("font_color", _c_text())
	instruction.set_meta("text_fa", _get_fa_text(text_raw))
	var fa_dominant := _is_fa_dominant(final_text)
	instruction.text_direction = Control.TEXT_DIRECTION_RTL if fa_dominant else Control.TEXT_DIRECTION_LTR
	if fa_dominant and _font_farsi:
		instruction.add_theme_font_override("font", _font_farsi)
	elif _font_bold:
		instruction.add_theme_font_override("font", _font_bold)
	_active_vbox.add_child(instruction)
	_add_fa_label(_get_fa_text(text_raw), 34)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style := StyleBoxLine.new()
	sep_style.color = _c_text_dim().lightened(0.7)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	_active_vbox.add_child(sep)


func _add_note() -> void:
	var note_raw = _exercise.get("note", "")
	var note := _get_en_text(note_raw)
	if note == "":
		return
	_note_label = _make_label(_t("info_prefix") + note, 32, _c_text_dim(), false)
	_note_label.set_meta("text_fa", _get_fa_text(note_raw))
	_note_label.visible = false
	if _is_open_ended or _is_non_interactive:
		_note_label.visible = true
	_active_vbox.add_child(_note_label)
	_add_fa_label(_get_fa_text(note_raw), 30)


# ============================================================
# IMAGE / MEDIA HELPERS
# ============================================================
func _add_images() -> void:
	var images: Array = _exercise.get("images", [])
	if images.is_empty():
		var single_img = _exercise.get("image", "")
		if single_img != "":
			images = [single_img]
	for img_data in images:
		_active_vbox.add_child(_make_media_control(img_data))


# ------------------------------------------------------------
# Shared per-item container. Every _build_* function used to repeat
# this same 5-7 lines by hand; centralizing it here means new
# exercise types get the same behavior for free and any future
# tweak (spacing, media placement) only has to change in one place.
# ------------------------------------------------------------
func _start_item_block(item: Dictionary, separation: int = 12, add_media: bool = true) -> VBoxContainer:
	var item_vbox := VBoxContainer.new()
	item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_vbox.add_theme_constant_override("separation", separation)
	item_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(item_vbox)
	if add_media:
		_add_item_media(item, item_vbox)
	return item_vbox


func _add_item_media(item: Dictionary, parent: Control) -> void:
	if item.has("images"):
		for img in item.get("images", []):
			parent.add_child(_make_media_control(img))
	elif item.has("image"):
		parent.add_child(_make_media_control(item.get("image")))


func _get_first_image_path(data: Dictionary) -> String:
	if data.has("image"):
		var img = data["image"]
		if img is Dictionary:
			return str(img.get("path", img.get("image", "")))
		return str(img)
	var imgs: Array = data.get("images", [])
	if imgs.size() > 0:
		var img = imgs[0]
		if img is Dictionary:
			return str(img.get("path", img.get("image", "")))
		return str(img)
	return ""


func _make_media_control(img_data: Variant) -> Control:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var path := ""
	var caption := ""
	var max_width := int(_exercise.get("image_max_width", 360))
	var min_height := int(_exercise.get("image_min_height", 180))

	if img_data is Dictionary:
		path = str(img_data.get("path", img_data.get("image", "")))
		caption = _get_en_text(img_data.get("caption", ""))
		max_width = int(img_data.get("max_width", max_width))
		min_height = int(img_data.get("min_height", min_height))
	else:
		path = str(img_data)

	# Never let media become wider than the visible screen.
	max_width = _safe_media_width(max_width)

	if path == "":
		var ph := _make_label(_t("image_placeholder"), 28, _c_text_dim(), false)
		_apply_fa_meta(ph, "image_placeholder")
		vbox.add_child(ph)
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
				var cap := _make_label(caption, 28, _c_text_dim(), false)
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(cap)
			return vbox

	var missing := _make_label(_t("image_not_found_prefix") + path.get_file(), 28, _c_text_dim(), false)
	missing.set_meta("text_fa", str(UI_STRINGS["image_not_found_prefix"]["fa"]) + path.get_file())
	vbox.add_child(missing)
	return vbox


# ============================================================
# FOOTER BUTTONS
# ============================================================
func _add_footer_buttons() -> void:
	if _is_non_interactive:
		return
	if hide_footer_buttons:
		return

	var graded_count := 0
	var has_sample := false
	for it in _items:
		if it.has("get"):
			graded_count += 1
		if it.get("sample_label", null) != null:
			has_sample = true

	if graded_count > 0:
		_score_banner = Label.new()
		_score_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_score_banner.autowrap_mode = TextServer.AUTOWRAP_WORD
		_score_banner.add_theme_font_size_override("font_size", 40)
		_score_banner.visible = false
		if _font_bold:
			_score_banner.add_theme_font_override("font", _font_bold)
		_target.add_child(_score_banner)

	var btn_row := HBoxContainer.new()
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _is_open_ended:
		if has_sample:
			# Orange color for Show Sample Answer
			_reveal_btn = _make_button(_t("show_sample_answer"), C_ORANGE)
			_apply_fa_meta(_reveal_btn, "show_sample_answer")
			_reveal_btn.pressed.connect(_on_reveal_sample)
			btn_row.add_child(_reveal_btn)
		# Green "Save" button
		_done_btn = _make_button(_t("save"), _c_success())
		_apply_fa_meta(_done_btn, "save")
		_done_btn.pressed.connect(_on_open_ended_done)
		btn_row.add_child(_done_btn)
	elif graded_count > 0:
		_check_btn = _make_button(_t("check_answer"), C_PRIMARY)
		# Bigger check button, consistent with the grammar "بررسی" buttons.
		_check_btn.custom_minimum_size = Vector2(0, 112)
		_check_btn.add_theme_font_size_override("font_size", 46)
		_apply_fa_meta(_check_btn, "check_answer")
		_check_btn.pressed.connect(_on_check_pressed)
		btn_row.add_child(_check_btn)

	if btn_row.get_child_count() > 0:
		_target.add_child(btn_row)


# ------------------------------------------------------------
# MULTIPLE CHOICE
# ------------------------------------------------------------
func _build_multiple_choice() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var q_label := _make_label(_get_item_main_text(item), 40, _c_text(), true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var options: Array = item.get("options", [])
		for opt in options:
			var b := _make_option_button(_get_option_text(opt), group)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = _normalize_answer_index(item.get("answer", -1))
		if answer is String:
			answer = _find_option_index(options, answer)
		# Build answer_display with the actual word/text instead of index.
		var answer_display := ""
		if answer is int and answer >= 0 and answer < options.size():
			answer_display = _get_option_text(options[answer])

		_items.append({
			"type": "multiple_choice",
			"get": func():
				for idx in option_btns.size():
					if option_btns[idx].button_pressed:
						return idx
				return -1,
			"answer": answer,
			"answer_display": answer_display,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# TRUE / FALSE
# ------------------------------------------------------------
func _build_true_false() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var statement := _make_label(_get_item_main_text(item), 40, _c_text(), false)
		item_vbox.add_child(statement)

		var group := ButtonGroup.new()
		var t_btn := _make_option_button("True", group)
		var f_btn := _make_option_button("False", group)
		item_vbox.add_child(t_btn)
		item_vbox.add_child(f_btn)

		var ans: Variant = item.get("answer", true)
		if ans is String:
			var s := _normalize(str(ans))
			ans = (s == "true" or s == "t" or s == "yes" or s == "y")

		var corr_raw = item.get("correction", item.get("explanation", ""))
		_items.append({
			"type": "true_false",
			"get": func():
				if t_btn.button_pressed:
					return true
				if f_btn.button_pressed:
					return false
				return null,
			"answer": ans,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(corr_raw),
			"explanation_fa": _get_fa_text(corr_raw),
		})


# ------------------------------------------------------------
# MATCHING
# ------------------------------------------------------------
func _build_matching() -> void:
	var exercise_options: Array = _exercise.get("options", [])
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var text := _make_label(_get_item_main_text(item), 38, _c_text(), false)
		item_vbox.add_child(text)

		var options: Array = item.get("options", exercise_options)
		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var ob := _make_option_dropdown(option_texts)
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")
		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = _get_option_text(opt)
					break

		_items.append({
			"type": "matching",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# FILL IN THE BLANK
# ------------------------------------------------------------
func _build_fill_blank() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var text := _make_label(_get_item_main_text(item), 38, _c_text(), false)
		item_vbox.add_child(text)

		var hint := _get_en_text(item.get("hint", ""))
		if hint != "":
			item_vbox.add_child(_make_label("Hint: " + hint, 30, _c_text_dim(), false))

		# Completed example rows (editable=false) render the sentence as-is
		# with no input box and are excluded from grading entirely.
		if not bool(item.get("editable", true)):
			continue

		var le := _make_line_edit(_t("type_your_answer"))
		item_vbox.add_child(le)

		_items.append({
			"type": "fill_blank",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# CLOZE
# ------------------------------------------------------------
func _build_cloze() -> void:
	var blanks: Array = _exercise.get("blanks", [])
	if blanks.is_empty():
		_active_vbox.add_child(_make_label(_t("no_correct_words"), 32, _c_text_dim(), false))
		return

	# ---- Reset inline state ----
	_cloze_rtl = null
	_cloze_popup = null
	_cloze_choices.clear()
	_cloze_correct.clear()
	_cloze_options.clear()
	_cloze_graded.clear()
	_cloze_graded_all = false
	_cloze_active = -1

	# ---- Resolve per-blank option texts + correct answer ----
	for b in blanks:
		var option_texts: Array = []
		for opt in b.get("options", []):
			option_texts.append(_get_option_text(opt))
		_cloze_options.append(option_texts)
		var ans: Variant = b.get("answer", "")
		if ans is float and ans == floor(ans):
			ans = int(ans)
		var correct_text := ""
		if ans is int and ans >= 0 and ans < option_texts.size():
			correct_text = str(option_texts[ans])
		elif ans is String:
			var raw_opts: Array = b.get("options", [])
			for oi in raw_opts.size():
				var opt: Variant = raw_opts[oi]
				if opt is Dictionary and str(opt.get("id", "")) == str(ans):
					correct_text = str(option_texts[oi])
					break
		_cloze_correct.append(correct_text)
		_cloze_choices.append("")
		_cloze_graded.append(false)

	# ---- Split the (English) passage into prose + blanks ----
	_cloze_segments = _split_cloze_passage(
		_get_en_text(_exercise.get("passage", "")),
		_cloze_choices.size()
	)

	# ---- RichTextLabel: prose flows naturally, blanks are inline tappable ----
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 42)
	rtl.add_theme_font_size_override("bold_font_size", 42)
	rtl.add_theme_font_size_override("italics_font_size", 42)
	rtl.add_theme_font_size_override("bold_italics_font_size", 42)
	rtl.add_theme_color_override("default_color", _c_text())
	if _font_regular:
		rtl.add_theme_font_override("normal_font", _font_regular)
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.meta_underlined = false
	rtl.meta_clicked.connect(_on_cloze_meta_clicked)
	rtl.gui_input.connect(_on_cloze_gui_input)
	_active_vbox.add_child(rtl)
	_register_scroll_control(rtl)
	_cloze_rtl = rtl
	# Plain Farsi translation line under the cloze passage (toggled by the
	# header show-translation switch).
	_add_fa_label(_get_fa_text(_exercise.get("passage", "")), 32)
	# Farsi mirror stays interactive (same ids), options remain English.
	rtl.set_meta("text_fa", _render_cloze_bbcode(_get_fa_text(_exercise.get("passage", ""))))
	_refresh_cloze_bbcode()

	# ---- Shared option dropdown (one per engine, recreated each build).
	# A custom PopupPanel with large, roomy Button rows so the choices are
	# easy to read and tap on a phone (matches the app's other dropdowns). ----
	var popup := PopupPanel.new()

	var panel := StyleBoxFlat.new()
	panel.bg_color = _c_surface()
	panel.set_corner_radius_all(16)
	panel.border_width_left = 1
	panel.border_width_right = 1
	panel.border_width_top = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.45)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 20
	panel.shadow_offset = Vector2(0, 10)
	panel.set_content_margin_all(12)
	popup.add_theme_stylebox_override("panel", panel)

	var popup_scroll := ScrollContainer.new()
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup.add_child(popup_scroll)

	var popup_list := VBoxContainer.new()
	popup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_list.add_theme_constant_override("separation", 12)
	popup_scroll.add_child(popup_list)

	_active_vbox.add_child(popup)
	_cloze_popup = popup
	_cloze_popup_list = popup_list

	# ---- Grading items (one per blank). No per-item label is needed: the
	# inline slots themselves are recolored by _apply_cloze_feedback(). ----
	for i in _cloze_choices.size():
		var idx := i
		_items.append({
			"type": "cloze",
			"blank_idx": idx,
			"get": func():
				if _cloze_choices.size() > idx:
					return _cloze_choices[idx]
				return "",
			"answer": _cloze_correct[idx],
		})


# ------------------------------------------------------------
# INLINE CLOZE HELPERS
# ------------------------------------------------------------
# Splits a passage at its numbered blank markers "(1) ______" into a list of
# prose strings and {"index": int} placeholders, in order.
func _split_cloze_passage(text: String, blank_count: int) -> Array:
	var segments: Array = []
	if text == "":
		return segments
	var regex := RegEx.new()
	if regex.compile(r"\(\d+\)\s*_{2,}") != OK:
		segments.append(text)
		return segments
	var pos := 0
	var blank_idx := 0
	for m in regex.search_all(text):
		var start: int = m.get_start()
		var end: int = m.get_end()
		if start > pos:
			segments.append(text.substr(pos, start - pos))
		if blank_idx < blank_count:
			segments.append({"index": blank_idx})
		blank_idx += 1
		pos = end
	if pos < text.length():
		segments.append(text.substr(pos))
	return segments


# Builds the full BBCode for a passage (used for both EN text and the FA meta).
func _render_cloze_bbcode(text: String) -> String:
	var segments: Array = _split_cloze_passage(text, _cloze_choices.size())
	var out := ""
	for seg in segments:
		if seg is Dictionary:
			out += _cloze_blank_bbcode(int(seg["index"]))
		else:
			out += _cloze_escape(str(seg))
	return out


func _refresh_cloze_bbcode() -> void:
	if _cloze_rtl == null:
		return
	_cloze_rtl.text = _render_cloze_bbcode(_get_en_text(_exercise.get("passage", "")))


func _cloze_placeholder(idx: int) -> String:
	return "(%d) ______" % (idx + 1)


# The inline slot: highlights it, shows the current choice (or the numbered
# placeholder), and — after grading — recolors it and reveals the correct form.
func _cloze_blank_bbcode(idx: int) -> String:
	var display := ""
	if not _cloze_graded_all:
		display = _cloze_choices[idx] if _cloze_choices[idx] != "" else _cloze_placeholder(idx)
	elif _cloze_graded[idx]:
		display = _cloze_choices[idx] if _cloze_choices[idx] != "" else _cloze_correct[idx]
	else:
		var chosen: String = str(_cloze_choices[idx])
		display = (chosen if chosen != "" else _cloze_placeholder(idx)) + "  →  " + _cloze_correct[idx]
	var color := "#22D3EE"
	if _cloze_graded_all:
		color = "#34D399" if _cloze_graded[idx] else "#F87171"
	# Replace inner spaces with non-breaking spaces so the whole slot is kept
	# together on one line instead of the RichTextLabel wrapping mid-blank.
	var inline := _cloze_escape(display).replace(" ", "\u00A0")
	return "[url=clz:%d][bgcolor=#22D3EE26][color=%s]%s[/color][/bgcolor][/url]" % [
		idx,
		color,
		inline,
	]


func _cloze_escape(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


func _on_cloze_meta_clicked(meta: Variant) -> void:
	if _cloze_graded_all:
		return
	var s := String(meta)
	if not s.begins_with("clz:"):
		return
	var idx := int(s.substr(4))
	if idx < 0 or idx >= _cloze_options.size():
		return
	_show_cloze_popup(idx)


# Captures the exact tap position on the cloze label so the dropdown can open
# precisely below the blank that was tapped (not below a stale mouse position).
func _on_cloze_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _cloze_rtl != null:
			_cloze_click_global = _cloze_rtl.get_global_rect().position + (event as InputEventMouseButton).position


func _show_cloze_popup(idx: int) -> void:
	_cloze_active = idx
	if _cloze_popup == null or _cloze_popup_list == null:
		return
	# Drop any rows from a previous open.
	for c in _cloze_popup_list.get_children():
		_cloze_popup_list.remove_child(c)
		c.queue_free()

	var opts: Array = _cloze_options[idx]
	var cur: String = _cloze_choices[idx]

	var f: Font = _font_regular if _font_regular else ThemeDB.fallback_font
	var longest := 0.0
	for o in opts:
		longest = maxf(longest, f.get_string_size(str(o), HORIZONTAL_ALIGNMENT_LEFT, -1, CLOZE_OPT_FONT).x)

	var vp := get_viewport()
	var vp_size := Vector2(1280.0, 720.0)
	var anchor := _cloze_click_global
	if vp != null:
		vp_size = vp.get_visible_rect().size
		if anchor == Vector2.ZERO:
			anchor = vp.get_mouse_position()
	var w := clampi(int(maxf(longest + 110.0, 400.0)), 320, int(vp_size.x) - 24)

	for oi in opts.size():
		var is_sel := (str(opts[oi]) == cur)
		var row := Button.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = CLOZE_OPT_FONT + 54
		row.text = ("✓  " if is_sel else "") + str(opts[oi])
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", CLOZE_OPT_FONT)
		if _font_regular:
			row.add_theme_font_override("font", _font_regular)
		row.add_theme_color_override("font_color", _c_text())
		row.add_theme_color_override("font_hover_color", C_PRIMARY)

		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.18) if is_sel else _c_surface_alt()
		normal.set_corner_radius_all(10)
		if is_sel:
			normal.border_width_left = 5
			normal.border_color = C_PRIMARY
		row.add_theme_stylebox_override("normal", normal)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.14)
		hover.set_corner_radius_all(10)
		row.add_theme_stylebox_override("hover", hover)
		row.add_theme_stylebox_override("pressed", hover)
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		row.pressed.connect(_on_cloze_popup_selected.bind(oi))
		_cloze_popup_list.add_child(row)

	_cloze_popup_list.custom_minimum_size.x = w
	var content_h: int = int(_cloze_popup_list.get_combined_minimum_size().y) + 24
	var h := mini(content_h, int(vp_size.y) - 48)
	var scroll: ScrollContainer = _cloze_popup_list.get_parent() as ScrollContainer
	if scroll:
		scroll.custom_minimum_size = Vector2(w, h)
	var x := clampi(int(anchor.x - w / 2.0), 8, int(vp_size.x) - w - 8)
	var y := clampi(int(anchor.y + 24), 8, int(vp_size.y) - h - 8)
	_cloze_popup.popup(Rect2i(x, y, w, h))


func _on_cloze_popup_selected(id: int) -> void:
	var idx := _cloze_active
	_cloze_active = -1
	if _cloze_popup != null:
		_cloze_popup.hide()
	if idx < 0 or idx >= _cloze_options.size():
		return
	var opts: Array = _cloze_options[idx]
	if id < 0 or id >= opts.size():
		return
	_cloze_choices[idx] = str(opts[id])
	_refresh_cloze_bbcode()


# Recolors each inline blank green/red after "Check Answer".
func _apply_cloze_feedback() -> void:
	_cloze_graded_all = true
	for item in _items:
		if str(item.get("type", "")) != "cloze":
			continue
		var idx: int = int(item.get("blank_idx", -1))
		if idx < 0 or idx >= _cloze_graded.size():
			continue
		_cloze_graded[idx] = _is_item_correct(item, item["get"].call())
	_refresh_cloze_bbcode()


# ------------------------------------------------------------
# ORDERING — CARD LIST WITH DRAG HANDLES + UP/DOWN ARROWS
# ------------------------------------------------------------

# ---------- Ordering drag-and-drop state ----------
# Each card has a grab handle (≡) on its left. Reordering by finger is
# enabled ONLY after the finger is held still on the handle for
# _ORDER_DRAG_HOLD_MSEC; a quick tap or quick swipe on the handle does
# nothing (and PageView is told to ignore the handle, so it never turns a
# handle press into a page scroll). Once the hold is recognised the grabbed
# card lifts, follows the finger, and the list reorders live as it passes
# the other cards; releasing drops it. The up/down arrows remain for
# precise single-step moves.
var _order_drag_active := false
var _order_drag_hold_armed := false
var _order_drag_handle: Control = null
var _order_drag_card: PanelContainer = null
var _order_drag_list: VBoxContainer = null
var _order_drag_current_order: Array = []
var _order_drag_original_order: Array = []
var _order_drag_item_texts: Array = []
var _order_drag_pos := 0
var _order_drag_press_msec := 0
var _order_drag_grab_offset := 0.0
# Last finger/cursor position seen during a drag. InputEventMouseMotion from
# some synthetic pipelines carries only a relative delta, so the cursor
# position is accumulated from it when no absolute position is reported.
var _order_drag_last_pos := Vector2.ZERO
const _ORDER_DRAG_HOLD_MSEC := 300

func _build_ordering() -> void:
	var raw_items: Array = _exercise.get("items", [])
	var item_texts: Array = []
	for it in raw_items:
		item_texts.append(_get_option_text(it))

	var answer_order: Array = _exercise.get("answer_order", [])
	if answer_order.is_empty():
		var ans: Array = _exercise.get("answer", [])
		if ans.size() == raw_items.size():
			var pairs: Array = []
			for i in ans.size():
				pairs.append({
					"pos": int(ans[i]),
					"idx": i,
				})
			pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a["pos"] < b["pos"]
			)
			for p in pairs:
				answer_order.append(p["idx"])
	if answer_order.is_empty():
		for i in raw_items.size():
			answer_order.append(i)

	var current_order: Array = []
	for i in raw_items.size():
		current_order.append(i)

	var container := VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 12)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(container)

	var list_vbox := VBoxContainer.new()
	list_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_vbox.add_theme_constant_override("separation", 12)
	container.add_child(list_vbox)

	var fb := _make_feedback(container)
	_rebuild_ordering_list(list_vbox, current_order, item_texts, true)

	var ordered_texts: Array = []
	for idx in answer_order:
		var i := int(idx)
		if i >= 0 and i < item_texts.size():
			ordered_texts.append(str(item_texts[i]))

	_items.append({
		"type": "ordering",
		"get": func(): return current_order.duplicate(),
		"answer": answer_order.duplicate(),
		"feedback": fb,
		"answer_display": _join_string_array(ordered_texts, " → "),
		"explanation_en": "",
		"explanation_fa": "",
	})


# ============================================================
# ORDERING ("Put in Order") — modern card list.
# Each item is a card: [position chip][item text][↑][↓].
# - Position chips update live so the learner always sees which
#   slot each item occupies.
# - All arrows are identical big ghost buttons (no disabled/greyed
#   states); out-of-range taps are ignored by _on_order_move.
# - Micro-interactions: the moved card flashes amber briefly and
#   cards fade in with a stagger when the list first appears.
# ============================================================
func _rebuild_ordering_list(list_vbox: VBoxContainer, current_order: Array, item_texts: Array, with_entrance := false) -> void:
	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	for pos in current_order.size():
		var idx := int(current_order[pos])
		var card := _make_order_card(pos, idx, item_texts, list_vbox, current_order)
		list_vbox.add_child(card)

		if with_entrance:
			# Gentle staggered fade-in, once, when the list first appears.
			card.modulate = Color(1, 1, 1, 0)
			var tw := card.create_tween()
			tw.tween_interval(0.05 * pos)
			tw.tween_property(card, "modulate:a", 1.0, 0.22)


func _make_order_card(pos: int, idx: int, item_texts: Array, list_vbox: VBoxContainer, current_order: Array) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_order_card_style())
	_register_scroll_control(card)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	# Grab handle (≡) — hold it to drag this card into a new position.
	row.add_child(_make_order_handle(list_vbox, current_order, item_texts, pos, idx))

	# Position chip: shows the slot this item currently occupies.
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(56, 56)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _make_order_chip_style())
	var chip_lbl := _make_label(str(pos + 1), 32, C_PRIMARY, true)
	chip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(chip_lbl)
	row.add_child(chip)

	# Item text.
	var txt := _make_label(str(item_texts[idx]), 36, _c_text(), false)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(txt)

	# Reorder controls. All arrows share the same big size and enabled
	# look — tapping an out-of-range arrow is simply ignored by
	# _on_order_move's guard.
	var up := _make_order_arrow_button("↑")
	up.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, -1))
	row.add_child(up)

	var down := _make_order_arrow_button("↓")
	down.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, 1))
	row.add_child(down)

	return card


func _on_order_move(list_vbox: VBoxContainer, current_order: Array, item_texts: Array, pos: int, delta: int) -> void:
	var new_pos := pos + delta
	if new_pos < 0 or new_pos >= current_order.size():
		return
	var moved: int = int(current_order[pos])
	current_order[pos] = current_order[new_pos]
	current_order[new_pos] = moved
	_rebuild_ordering_list(list_vbox, current_order, item_texts)
	_flash_order_row(list_vbox, new_pos)


# Brief amber highlight on the card that just moved, fading back to normal.
func _flash_order_row(list_vbox: VBoxContainer, pos: int) -> void:
	if pos < 0 or pos >= list_vbox.get_child_count():
		return
	var card := list_vbox.get_child(pos) as Control
	if card == null:
		return
	card.modulate = Color(1.0, 0.93, 0.62, 1.0)
	var tw := card.create_tween()
	tw.tween_property(card, "modulate", Color.WHITE, 0.4)


# ---------- ordering card / chip / arrow / handle styling ----------
func _make_order_card_style(dragging := false) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = _c_surface_alt()
	st.set_corner_radius_all(18)
	st.set_border_width_all(2)
	var border := _c_border()
	st.border_color = C_PRIMARY if dragging else Color(border.r, border.g, border.b, 0.45)
	st.content_margin_left = 18
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	if dragging:
		st.shadow_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35)
		st.shadow_size = 14
		st.shadow_offset = Vector2(0, 6)
	else:
		st.shadow_color = Color(0, 0, 0, 0.12)
		st.shadow_size = 6
		st.shadow_offset = Vector2(0, 3)
	return st


func _make_order_chip_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.16)
	st.set_corner_radius_all(16)
	st.set_border_width_all(2)
	st.border_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.55)
	st.set_content_margin_all(4)
	return st


func _make_order_arrow_button(glyph: String) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = glyph
	b.custom_minimum_size = Vector2(88, 88)
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", _c_text_dim())
	b.add_theme_color_override("font_hover_color", C_PRIMARY)
	b.add_theme_color_override("font_pressed_color", C_PRIMARY)
	b.add_theme_color_override("font_focus_color", _c_text_dim())
	b.add_theme_color_override("font_hover_pressed_color", C_PRIMARY)
	if _font_bold:
		b.add_theme_font_override("font", _font_bold)

	var accent := C_PRIMARY
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.05)
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(2)
	normal.border_color = Color(_c_border().r, _c_border().g, _c_border().b, 0.5)
	normal.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	hover.set_corner_radius_all(18)
	hover.set_border_width_all(2)
	hover.border_color = accent
	hover.set_content_margin_all(8)
	b.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
	pressed.set_corner_radius_all(18)
	pressed.set_border_width_all(2)
	pressed.border_color = accent
	pressed.set_content_margin_all(8)
	b.add_theme_stylebox_override("pressed", pressed)

	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_register_scroll_control(b)
	return b


# ---------- ordering grab handle + drag-and-drop ----------

# The grab handle is the ONLY place a reorder-drag can start. It is a
# dedicated gesture zone: a press on it is reported to PageView as a swipe
# blocker, so PageView never turns a handle touch into a page scroll. The
# handle itself only begins a drag after the finger has been held still on
# it for _ORDER_DRAG_HOLD_MSEC (see _on_order_handle_input).
func _make_order_handle(list_vbox: VBoxContainer, current_order: Array, item_texts: Array, pos: int, idx: int) -> PanelContainer:
	var handle := PanelContainer.new()
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.custom_minimum_size = Vector2(56, 56)
	handle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	handle.add_theme_stylebox_override("panel", _make_order_handle_style())
	handle.add_child(_make_order_grip_bars())
	handle.gui_input.connect(_on_order_handle_input.bind(handle, list_vbox, current_order, item_texts, pos, idx))
	# PageView must never turn a handle press into a page scroll/swipe. Handles
	# live in a dedicated group (they can be created before the engine is under
	# the PageView, so the group is checked by PageView at press time instead of
	# relying on registration order). Rebuilt handles re-join the group.
	handle.add_to_group("order_drag_handles")
	return handle


func _make_order_handle_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	var accent := C_PRIMARY
	st.bg_color = Color(accent.r, accent.g, accent.b, 0.05)
	st.set_corner_radius_all(16)
	st.set_border_width_all(2)
	var border := _c_border()
	st.border_color = Color(border.r, border.g, border.b, 0.5)
	return st


# The "≡" grip: three short horizontal bars, drawn as ColorRects so the
# glyph renders identically regardless of font coverage.
func _make_order_grip_bars() -> Control:
	var bars := VBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 5)
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color := _c_text_dim()
	for i in 3:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = color
		bar.custom_minimum_size = Vector2(30, 4)
		bars.add_child(bar)
	return bars


func _on_order_handle_input(event: InputEvent, handle: Control, list_vbox: VBoxContainer, current_order: Array, item_texts: Array, pos: int, _idx: int) -> void:
	var is_press := false
	var is_release := false
	var event_pos := Vector2.ZERO

	if event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
		event_pos = event.position
	elif event is InputEventScreenDrag:
		event_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
		event_pos = event.global_position
	elif event is InputEventMouseMotion:
		if event.global_position != Vector2.ZERO:
			_order_drag_last_pos = event.global_position
		else:
			_order_drag_last_pos += event.relative
		event_pos = _order_drag_last_pos

	if is_press:
		# Safety net: drop any stale drag before starting a fresh one.
		_cancel_order_drag()
		var card := list_vbox.get_child(pos) as PanelContainer
		if card == null:
			return
		_order_drag_handle = handle
		_order_drag_card = card
		_order_drag_list = list_vbox
		_order_drag_current_order = current_order
		_order_drag_original_order = current_order.duplicate()
		_order_drag_item_texts = item_texts
		_order_drag_pos = pos
		_order_drag_press_msec = Time.get_ticks_msec()
		_order_drag_grab_offset = event_pos.y - card.get_global_rect().position.y
		_order_drag_last_pos = event_pos
		_order_drag_hold_armed = true
		_order_drag_active = false
		return

	if _order_drag_handle == null or not is_instance_valid(_order_drag_handle) or _order_drag_handle != handle:
		return

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _order_drag_hold_armed:
			return
		if not _order_drag_active:
			if Time.get_ticks_msec() - _order_drag_press_msec < _ORDER_DRAG_HOLD_MSEC:
				return  # finger is moving too soon — not a reorder yet.
			_begin_order_drag()
		_update_order_drag(event_pos)
		return

	if is_release:
		if _order_drag_active:
			_finish_order_drag()
		else:
			_cancel_order_drag()


# Visually "grabs" the card: lift it above its siblings, tint its border,
# dim the rest. Called the first time the finger moves after the hold.
func _begin_order_drag() -> void:
	_order_drag_active = true
	if _order_drag_card == null or not is_instance_valid(_order_drag_card):
		return
	_order_drag_card.z_index = 50
	_order_drag_card.add_theme_stylebox_override("panel", _make_order_card_style(true))
	_order_drag_card.modulate = Color.WHITE
	_order_drag_card.scale = Vector2(1.03, 1.03)
	if _order_drag_list != null and is_instance_valid(_order_drag_list):
		for i in _order_drag_list.get_child_count():
			var c := _order_drag_list.get_child(i) as Control
			if c != null and c != _order_drag_card:
				c.modulate = Color(1, 1, 1, 0.6)


# Live reorder: whichever card the finger's grab point currently covers
# becomes the new slot; the grabbed card follows the finger vertically.
func _update_order_drag(event_pos: Vector2) -> void:
	var list := _order_drag_list
	var card := _order_drag_card
	if list == null or card == null or not is_instance_valid(list) or not is_instance_valid(card):
		return
	var count := list.get_child_count()
	if count == 0:
		return

	var grab_y := event_pos.y - _order_drag_grab_offset
	var target := _order_drag_pos
	for i in count:
		if i == _order_drag_pos:
			continue
		var c := list.get_child(i) as Control
		if c == null:
			continue
		var r := c.get_global_rect()
		if grab_y >= r.position.y and grab_y <= r.position.y + r.size.y:
			target = i
			break

	if target != _order_drag_pos:
		var moved_idx: int = int(_order_drag_current_order[_order_drag_pos])
		_order_drag_current_order.remove_at(_order_drag_pos)
		_order_drag_current_order.insert(target, moved_idx)
		list.move_child(card, target)
		_order_drag_pos = target
		_renumber_order_chips(list)

	# The grabbed card tracks the finger (in list-local coordinates, so it
	# stays correct regardless of the list's scroll offset).
	card.position.y = event_pos.y - list.get_global_rect().position.y - _order_drag_grab_offset
	# Keep it within the list's vertical span.
	var top := 0.0
	var bottom := 0.0
	var first := list.get_child(0) as Control
	if first != null:
		top = first.position.y
	var last := list.get_child(count - 1) as Control
	if last != null:
		bottom = last.position.y + last.size.y - card.size.y
	card.position.y = clampf(card.position.y, top, bottom)


# Drop: rebuild the list in the final order (fresh, normal styles) and flash
# the card that landed in the released slot.
func _finish_order_drag() -> void:
	var list := _order_drag_list
	var final_pos := _order_drag_pos
	if list != null and is_instance_valid(list):
		_rebuild_ordering_list(list, _order_drag_current_order, _order_drag_item_texts)
		_flash_order_row(list, final_pos)
	_clear_order_drag_state()


# Abort without reordering: restore the pre-drag order if a drag had started.
func _cancel_order_drag() -> void:
	if _order_drag_active and _order_drag_list != null and is_instance_valid(_order_drag_list):
		var cur: Array = _order_drag_current_order
		var orig: Array = _order_drag_original_order
		cur.clear()
		for v in orig:
			cur.append(v)
		_rebuild_ordering_list(_order_drag_list, cur, _order_drag_item_texts)
	_clear_order_drag_state()


func _clear_order_drag_state() -> void:
	_order_drag_active = false
	_order_drag_hold_armed = false
	_order_drag_handle = null
	_order_drag_card = null
	_order_drag_list = null
	_order_drag_current_order = []
	_order_drag_original_order = []
	_order_drag_item_texts = []
	_order_drag_pos = 0
	_order_drag_press_msec = 0
	_order_drag_grab_offset = 0.0
	_order_drag_last_pos = Vector2.ZERO


func _renumber_order_chips(list: VBoxContainer) -> void:
	for i in list.get_child_count():
		var card := list.get_child(i) as PanelContainer
		if card == null:
			continue
		var row := card.get_child(0) as HBoxContainer
		if row == null:
			continue
		var chip := row.get_child(1) as PanelContainer
		if chip == null:
			continue
		var lbl := chip.get_child(0) as Label
		if lbl != null:
			lbl.text = str(i + 1)


# When PageView takes over a gesture (e.g. a second finger swipes the page
# while a card is being dragged), finish the drag in place rather than
# leaving it hanging.
func _on_gesture_cancelled_by_page() -> void:
	if _order_drag_active:
		_finish_order_drag()
	else:
		_cancel_order_drag()


# ------------------------------------------------------------
# CATEGORIZE
# ------------------------------------------------------------
func _build_categorize() -> void:
	var categories: Array = _exercise.get("categories", [])
	var category_texts: Array = []
	for cat in categories:
		category_texts.append(_get_option_text(cat))

	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var text := _make_label(_get_item_main_text(item), 38, _c_text(), false)
		item_vbox.add_child(text)

		var ob := _make_option_dropdown(category_texts, "Category")
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")
		if answer is int and answer >= 0 and answer < category_texts.size():
			answer = category_texts[answer]
		elif answer is String:
			for cat in categories:
				if cat is Dictionary and str(cat.get("id", "")) == str(answer):
					answer = _get_option_text(cat)
					break

		_items.append({
			"type": "categorize",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# OPEN ENDED / PRONUNCIATION / WRITING
# ------------------------------------------------------------
func _build_open_ended() -> void:
	var _item_index := 0
	for item in _exercise.get("items", []):
		# Prefer a stable "id" from the JSON item itself for saving answers.
		# Falling back to the array index only when no id is given keeps old
		# content working, but any content with an explicit "id" per item
		# survives reordering/inserting new questions without mixing up
		# a student's previously saved answers.
		var save_key := str(item.get("id", "")) if item.has("id") and str(item.get("id", "")) != "" else "idx_%d" % _item_index
		_item_index += 1

		var item_vbox := _start_item_block(item)

		var q := _get_item_main_text(item)
		if q != "":
			var q_label := _make_label(q, 38, _c_text(), false)
			item_vbox.add_child(q_label)

		var te := TextEdit.new()
		te.mouse_filter = Control.MOUSE_FILTER_PASS
		te.placeholder_text = _t("write_your_answer")
		te.custom_minimum_size = Vector2(0, 180)
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.add_theme_font_size_override("font_size", 40)
		# Dark answer box: use light text instead of black text.
		te.add_theme_color_override("font_color", _c_text())
		te.add_theme_color_override("font_placeholder_color", _c_text_dim())
		te.add_theme_color_override("caret_color", C_PRIMARY)
		# Keep selected text readable on the dark background.
		te.add_theme_color_override(
			"selection_color",
			Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35)
		)
		te.add_theme_color_override("font_selected_color", Color.WHITE)
		if _font_regular:
			te.add_theme_font_override("font", _font_regular)

		var te_style := StyleBoxFlat.new()
		# Replace the white background with the dark panel color.
		te_style.bg_color = _c_surface()
		te_style.set_corner_radius_all(10)
		te_style.border_width_bottom = 2
		te_style.border_color = _c_border()
		te_style.set_content_margin_all(14)
		te.add_theme_stylebox_override("normal", te_style)

		var te_focus: StyleBoxFlat = te_style.duplicate()
		te_focus.border_color = C_PRIMARY
		te.add_theme_stylebox_override("focus", te_focus)

		item_vbox.add_child(te)
		_register_scroll_control(te)

		# Connect text_changed to reset Save button state
		te.text_changed.connect(_on_open_ended_text_changed)

		var rubric: Array = item.get("rubric", _exercise.get("rubric", []))
		for r in rubric:
			var cb := CheckBox.new()
			cb.mouse_filter = Control.MOUSE_FILTER_PASS
			cb.text = _get_en_text(r)
			cb.add_theme_font_size_override("font_size", 36)
			if _font_regular:
				cb.add_theme_font_override("font", _font_regular)
			item_vbox.add_child(cb)
			_register_scroll_control(cb)

		var default_self_check := str(_exercise.get("type", "")) == "pronunciation"
		var self_check := bool(item.get("self_check", _exercise.get("self_check", default_self_check)))
		if self_check:
			var done_check := CheckBox.new()
			done_check.mouse_filter = Control.MOUSE_FILTER_PASS
			done_check.text = _t("self_check_label")
			_apply_fa_meta(done_check, "self_check_label")
			done_check.add_theme_font_size_override("font_size", 36)
			if _font_regular:
				done_check.add_theme_font_override("font", _font_regular)
			item_vbox.add_child(done_check)
			_register_scroll_control(done_check)

		var sample_text := _get_en_text(item.get("sample_answer", ""))
		var sample: Label = null
		if sample_text != "":
			sample = _make_label(_t("sample_answer_prefix") + sample_text, 34, _c_success(), false)
			sample.set_meta("text_fa", _get_fa_text(item.get("sample_answer", "")))
			sample.visible = false
			item_vbox.add_child(sample)

		_items.append({
			"sample_label": sample,
			"text_edit": te,
			"save_key": save_key,
		})

	# Load any previously saved answers
	_load_open_ended_answers()


func _on_open_ended_text_changed() -> void:
	# When the user edits text after saving, revert button to "Save" (green)
	if _done_btn != null and _is_saved:
		_is_saved = false
		_done_btn.text = _t("save")
		_apply_fa_meta(_done_btn, "save")
		_set_button_color(_done_btn, _c_success())


# ------------------------------------------------------------
# WORD BANK
# ------------------------------------------------------------
func _build_word_bank() -> void:
	var bank: Array = _exercise.get("word_bank", [])
	var bank_texts: Array = []
	for w in bank:
		bank_texts.append(_get_option_text(w))

	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var text := _make_label(_get_item_main_text(item), 38, _c_text(), false)
		item_vbox.add_child(text)

		var ob := _make_option_dropdown(bank_texts, _t("choose_a_word"))
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")
		if answer is int and answer >= 0 and answer < bank_texts.size():
			answer = bank_texts[answer]
		elif answer is String:
			for w in bank:
				if w is Dictionary and str(w.get("id", "")) == str(answer):
					answer = _get_option_text(w)
					break

		_items.append({
			"type": "word_bank",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# SENTENCE ORDERING / UNSCRAMBLE
# ------------------------------------------------------------
func _build_sentence_ordering() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item, 14)

		var words: Array = item.get("words", [])
		var word_texts: Array = []
		for w in words:
			word_texts.append(_get_option_text(w))

		var answer_words_raw: Array = item.get("answer", word_texts)
		var answer_words: Array = []
		var all_int := true
		for x in answer_words_raw:
			if not (x is int or x is float):
				all_int = false
				break
		if all_int and answer_words_raw.size() == word_texts.size():
			for x in answer_words_raw:
				var idx := int(x)
				if idx >= 0 and idx < word_texts.size():
					answer_words.append(word_texts[idx])
				else:
					answer_words.append(str(x))
		else:
			for w in answer_words_raw:
				answer_words.append(_get_option_text(w))

		var built_row := HFlowContainer.new()
		built_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		built_row.add_theme_constant_override("h_separation", 8)
		built_row.add_theme_constant_override("v_separation", 8)
		built_row.custom_minimum_size = Vector2(0, 64)
		built_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(built_row)

		var sep := HSeparator.new()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_child(sep)

		var bank_row := HFlowContainer.new()
		bank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bank_row.add_theme_constant_override("h_separation", 8)
		bank_row.add_theme_constant_override("v_separation", 8)
		bank_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(bank_row)

		var order: Array = []
		var word_btns: Array = []
		for i in word_texts.size():
			var wb := _make_chip_button(str(word_texts[i]))
			word_btns.append(wb)
			bank_row.add_child(wb)

		for i in word_texts.size():
			word_btns[i].pressed.connect(
				_on_bank_word_pressed.bind(i, order, word_btns, built_row, word_texts)
			)

		_items.append({
			"type": "sentence_ordering",
			"get": func():
				var chosen: Array = []
				for idx in order:
					chosen.append(word_texts[idx])
				return _join_words(chosen),
			"answer": _join_words(answer_words),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


func _on_bank_word_pressed(idx: int, order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	var btn: Button = word_btns[idx]
	if btn.disabled:
		return
	btn.disabled = true
	btn.modulate.a = 0.3
	order.append(idx)
	_rebuild_order_row(order, word_btns, built_row, words)


func _rebuild_order_row(order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	for c in built_row.get_children():
		built_row.remove_child(c)
		c.queue_free()
	for pos in order.size():
		var idx: int = order[pos]
		var chip := _make_chip_button(str(words[idx]), true)
		chip.pressed.connect(_on_built_word_pressed.bind(pos, order, word_btns, built_row, words))
		built_row.add_child(chip)


func _on_built_word_pressed(pos: int, order: Array, word_btns: Array, built_row: HFlowContainer, words: Array) -> void:
	var idx: int = order[pos]
	order.remove_at(pos)
	var btn: Button = word_btns[idx]
	btn.disabled = false
	btn.modulate.a = 1.0
	_rebuild_order_row(order, word_btns, built_row, words)


# ------------------------------------------------------------
# LETTER SCRAMBLE
# ------------------------------------------------------------
func _build_letter_scramble() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var scrambled: String = str(item.get("scrambled", ""))
		var spaced := ""
		for i in scrambled.length():
			spaced += scrambled[i].to_upper()
			if i < scrambled.length() - 1:
				spaced += "  "
		var label := _make_label(spaced, 44, C_PRIMARY, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(label)

		var hint_raw = item.get("hint", "")
		if _get_en_text(hint_raw) != "":
			var hint := _make_label("Hint: " + _get_en_text(hint_raw), 32, _c_text_dim(), false)
			hint.set_meta("text_fa", _get_fa_text(hint_raw))
			item_vbox.add_child(hint)

		var le := _make_line_edit("Type the word...")
		item_vbox.add_child(le)

		_items.append({
			"type": "letter_scramble",
			"get": func(): return le.text,
			"answer": item.get("answer", ""),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# SIMPLE TABLE FILL
# ------------------------------------------------------------
func _build_table_fill() -> void:
	var columns: Array = _exercise.get("columns", [])
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(columns.size(), 1)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(grid)

	for col in columns:
		var h := _make_label(_get_en_text(col), 34, _c_text_dim(), true)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)

	for row in _exercise.get("rows", []):
		for cell in row.get("cells", []):
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 6)
			cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell_box)

			if cell.get("editable", false):
				var le := _make_line_edit("...")
				cell_box.add_child(le)
				_items.append({
					"type": "fill_blank",
					"get": func(): return le.text,
					"answer": cell.get("answer", []),
					"feedback": _make_feedback(cell_box),
					"explanation_en": "",
					"explanation_fa": "",
				})
			else:
				var lbl := _make_label(_get_en_text(cell.get("text", "")), 36, _c_text(), false)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(lbl)


# ------------------------------------------------------------
# ADVANCED TABLE FILL
# Cell types: label / line / dropdown / true_false / yes_no / checkbox
# ------------------------------------------------------------
func _build_table_fill_advanced() -> void:
	# Supports either a single table via "columns"/"rows" (legacy) or multiple
	# tables via "tables": [ { "title": {...}, "columns": [...], "rows": [...] } ].
	var tables: Array = _exercise.get("tables", [])
	if tables.is_empty() and _exercise.has("columns"):
		tables = [ { "columns": _exercise.get("columns", []), "rows": _exercise.get("rows", []) } ]

	for table in tables:
		var columns: Array = []
		var rows: Array = []
		if table is Dictionary:
			columns = table.get("columns", [])
			rows = table.get("rows", [])
		else:
			columns = _exercise.get("columns", [])
			rows = _exercise.get("rows", [])

		if table is Dictionary and table.has("title"):
			var tl := _make_label(_get_en_text(table.get("title", "")), 34, _c_text_dim(), true)
			_active_vbox.add_child(tl)

		if columns.is_empty():
			continue

		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = maxi(columns.size(), 1)
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 16)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_active_vbox.add_child(grid)

		for col in columns:
			var h := _make_label(_get_en_text(col), 34, C_PRIMARY, true)
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(h)

		for row in rows:
			var cells: Array = []
			if row is Dictionary:
				cells = row.get("cells", [])
			elif row is Array:
				cells = row
			for cell in cells:
				var cell_box := VBoxContainer.new()
				cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell_box.add_theme_constant_override("separation", 6)
				cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(cell_box)

				if not cell is Dictionary:
					var plain := _make_label(str(cell), 34, _c_text(), false)
					plain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cell_box.add_child(plain)
					continue

				var ctype := str(cell.get("type", cell.get("editor", "label")))
				match ctype:
					"line", "fill_blank", "text":
						var le := _make_line_edit(str(cell.get("placeholder", "...")))
						cell_box.add_child(le)
						_items.append({
							"type": "fill_blank",
							"get": func(): return le.text,
							"answer": cell.get("answer", []),
							"feedback": _make_feedback(cell_box),
							"explanation_en": _get_en_text(cell.get("explanation", "")),
							"explanation_fa": _get_fa_text(cell.get("explanation", "")),
						})
					"dropdown", "select":
						var options: Array = cell.get("options", [])
						var option_texts: Array = []
						for opt in options:
							option_texts.append(_get_option_text(opt))
						var ob := _make_option_dropdown(option_texts, str(cell.get("placeholder", _t("choose"))))
						cell_box.add_child(ob)
						var ans: Variant = cell.get("answer", "")
						if ans is int and ans >= 0 and ans < option_texts.size():
							ans = option_texts[ans]
						elif ans is String:
							for opt in options:
								if opt is Dictionary and str(opt.get("id", "")) == str(ans):
									ans = _get_option_text(opt)
									break
						_items.append({
							"type": "dropdown",
							"get": func():
								if ob.selected > 0:
									return ob.get_item_text(ob.selected)
								return "",
							"answer": ans,
							"feedback": _make_feedback(cell_box),
							"explanation_en": _get_en_text(cell.get("explanation", "")),
							"explanation_fa": _get_fa_text(cell.get("explanation", "")),
						})
					"true_false", "yes_no":
						var group := ButtonGroup.new()
						var yes_text := "Yes" if ctype == "yes_no" else "True"
						var no_text := "No" if ctype == "yes_no" else "False"
						var hbox := HBoxContainer.new()
						hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
						hbox.add_theme_constant_override("separation", 10)
						hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						cell_box.add_child(hbox)
						var b_yes := _make_select_button(yes_text, group, _c_success())
						var b_no := _make_select_button(no_text, group, _c_error())
						hbox.add_child(b_yes)
						hbox.add_child(b_no)
						var ans_tf: Variant = cell.get("answer", true)
						if ans_tf is String:
							var s := _normalize(str(ans_tf))
							ans_tf = (s == "yes" or s == "true" or s == "y" or s == "t")
						_items.append({
							"type": ctype,
							"get": func():
								if b_yes.button_pressed:
									return true
								if b_no.button_pressed:
									return false
								return null,
							"answer": ans_tf,
							"feedback": _make_feedback(cell_box),
							"explanation_en": _get_en_text(cell.get("explanation", "")),
							"explanation_fa": _get_fa_text(cell.get("explanation", "")),
						})
					"checkbox", "check":
						var cb := CheckBox.new()
						cb.mouse_filter = Control.MOUSE_FILTER_PASS
						cb.text = _get_en_text(cell.get("text", ""))
						cb.add_theme_font_size_override("font_size", 36)
						if _font_regular:
							cb.add_theme_font_override("font", _font_regular)
						cell_box.add_child(cb)
						_register_scroll_control(cb)
						_items.append({
							"type": "checkbox",
							"get": func(): return cb.button_pressed,
							"answer": bool(cell.get("answer", false)),
							"feedback": _make_feedback(cell_box),
							"explanation_en": _get_en_text(cell.get("explanation", "")),
							"explanation_fa": _get_fa_text(cell.get("explanation", "")),
						})
					"textarea", "multiline":
						var te := TextEdit.new()
						te.mouse_filter = Control.MOUSE_FILTER_PASS
						te.placeholder_text = str(cell.get("placeholder", _t("type_your_answer")))
						# Free-form box: starts tall and grows with each typed line so the
						# user can write as many words as they want, one per line.
						const _TEXTAREA_BASE := 170.0
						const _TEXTAREA_LINE_GROWTH := 54.0
						te.custom_minimum_size = Vector2(0, _TEXTAREA_BASE)
						te.text_changed.connect(func():
							var lines := float(te.get_line_count())
							var target := _TEXTAREA_BASE + maxf(0.0, lines - 2.0) * _TEXTAREA_LINE_GROWTH
							if te.custom_minimum_size.y != target:
								te.custom_minimum_size = Vector2(te.custom_minimum_size.x, target)
						)
						te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						te.add_theme_font_size_override("font_size", 34)
						# Dark answer box: light text instead of black.
						te.add_theme_color_override("font_color", _c_text())
						te.add_theme_color_override("font_placeholder_color", _c_text_dim())
						te.add_theme_color_override("caret_color", C_PRIMARY)
						te.add_theme_color_override(
							"selection_color",
							Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35)
						)
						te.add_theme_color_override("font_selected_color", Color.WHITE)
						if _font_regular:
							te.add_theme_font_override("font", _font_regular)
						var te_style := StyleBoxFlat.new()
						te_style.bg_color = _c_surface()
						te_style.set_corner_radius_all(10)
						te_style.border_width_bottom = 2
						te_style.border_color = _c_border()
						te_style.set_content_margin_all(12)
						te.add_theme_stylebox_override("normal", te_style)
						var te_focus: StyleBoxFlat = te_style.duplicate()
						te_focus.border_color = C_PRIMARY
						te.add_theme_stylebox_override("focus", te_focus)
						cell_box.add_child(te)
						_register_scroll_control(te)
						_items.append({
							"type": "textarea",
							"get": func(): return te.text,
							"answer": cell.get("answer", []),
							"placeholder": str(cell.get("placeholder", "")),
							"feedback": _make_feedback(cell_box),
							"explanation_en": _get_en_text(cell.get("explanation", "")),
							"explanation_fa": _get_fa_text(cell.get("explanation", "")),
						})
					_:
						var lbl := _make_label(_get_en_text(cell.get("text", "")), 34, _c_text(), false)
						lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						cell_box.add_child(lbl)


# ------------------------------------------------------------
# SINGLE-CATEGORY TEXT HIGHLIGHT
# ------------------------------------------------------------
func _build_text_highlight() -> void:
	var p_raw = _exercise.get("passage", "")
	var passage_text := _get_en_text(p_raw)
	var words: PackedStringArray = passage_text.split(" ", false)
	var answer_indices: Array = _exercise.get("answer_indices", [])

	var hint := _make_label("Tap the words that match the instruction above.", 30, _c_text_dim(), false)
	_active_vbox.add_child(hint)

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(flow)

	for i in words.size():
		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 0)
		flow.add_child(pair)

		var wb := _make_word_toggle(words[i])
		pair.add_child(wb)

		var fb := Label.new()
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.add_theme_font_size_override("font_size", 28)
		fb.visible = false
		pair.add_child(fb)

		var is_target: bool = answer_indices.has(i)
		_items.append({
			"type": "text_highlight",
			"get": func(): return wb.button_pressed,
			"answer": is_target,
			"feedback": fb,
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# MULTI-CATEGORY TEXT HIGHLIGHT
# ------------------------------------------------------------
func _build_text_highlight_multi() -> void:
	var categories := _normalize_categories(_exercise.get("categories", []))
	if categories.is_empty():
		categories = _normalize_categories(["A", "B"])

	var passage_text := _get_en_text(_exercise.get("passage", _exercise.get("reading", "")))
	var tokens: Array = []
	if _exercise.has("tokens"):
		for t in _exercise.get("tokens", []):
			tokens.append(_get_option_text(t))
	else:
		tokens = Array(passage_text.split(" ", false))

	var legend := HFlowContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 8)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(legend)
	for c in categories:
		var chip := _make_label(str(c["label"]), 28, c["color"], true)
		legend.add_child(chip)

	var hint := _make_label("Tap a word to change its label. Tap again to cycle.", 30, _c_text_dim(), false)
	_active_vbox.add_child(hint)

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(flow)

	var selected_cat: Array = []
	var buttons: Array = []
	for i in tokens.size():
		selected_cat.append("")

	var answer_map: Dictionary = {}
	var ans_raw: Variant = _exercise.get("answer_indices", _exercise.get("answers", {}))
	if ans_raw is Array:
		for i in ans_raw.size():
			var cat_id := _category_id_from_value(ans_raw[i], categories)
			if cat_id != "":
				answer_map[i] = cat_id
	elif ans_raw is Dictionary:
		for k in ans_raw:
			var idx := int(str(k))
			answer_map[idx] = _category_id_from_value(ans_raw[k], categories)

	for i in tokens.size():
		var idx := i
		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 0)
		flow.add_child(pair)

		var wb := Button.new()
		wb.mouse_filter = Control.MOUSE_FILTER_PASS
		wb.text = str(tokens[idx])
		wb.add_theme_font_size_override("font_size", 38)
		if _font_regular:
			wb.add_theme_font_override("font", _font_regular)
		_update_multi_word_style(wb, "", categories)
		pair.add_child(wb)
		buttons.append(wb)
		_register_scroll_control(wb)
		wb.pressed.connect(_on_multi_word_pressed.bind(idx, buttons, selected_cat, categories))

		var fb := Label.new()
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.add_theme_font_size_override("font_size", 28)
		fb.visible = false
		pair.add_child(fb)

		_items.append({
			"type": "text_highlight_multi",
			"get": func(): return str(selected_cat[idx]),
			"answer": str(answer_map.get(idx, "")),
			"feedback": fb,
			"explanation_en": "",
			"explanation_fa": "",
		})


func _on_multi_word_pressed(idx: int, buttons: Array, selected_cat: Array, categories: Array) -> void:
	if categories.is_empty():
		return
	var current := -1
	for i in categories.size():
		if str(categories[i]["id"]) == str(selected_cat[idx]):
			current = i
			break
	var next := current + 1
	if next >= categories.size():
		selected_cat[idx] = ""
	else:
		selected_cat[idx] = str(categories[next]["id"])
	_update_multi_word_style(buttons[idx], str(selected_cat[idx]), categories)


func _update_multi_word_style(btn: Button, cat_id: String, categories: Array) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	if cat_id == "":
		style.bg_color = Color(1, 1, 1, 0)
		style.border_width_bottom = 1
		style.border_color = _c_border()
	else:
		var col := _get_category_color(cat_id, categories)
		style.bg_color = Color(col.r, col.g, col.b, 0.22)
		style.border_width_bottom = 3
		style.border_color = col
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _normalize_categories(raw: Array) -> Array:
	var out: Array = []
	var default_colors := [
		Color("#2563EB"),
		Color("#16A34A"),
		Color("#DC2626"),
		Color("#F59E0B"),
		Color("#7C3AED"),
		Color("#0891B2"),
	]
	for i in raw.size():
		var c = raw[i]
		var id := ""
		var label := ""
		var color: Color = default_colors[i % default_colors.size()]
		if c is Dictionary:
			id = str(c.get("id", c.get("label", "cat_%d" % i)))
			label = _get_en_text(c.get("label", id))
			if c.has("color"):
				color = Color(str(c.get("color")))
		else:
			id = str(c)
			label = str(c)
		if label == "":
			label = id
		out.append({
			"id": id,
			"label": label,
			"color": color,
		})
	return out


func _category_id_from_value(val: Variant, categories: Array) -> String:
	var s := str(val)
	if s == "":
		return ""
	for c in categories:
		if s == str(c["id"]) or _normalize(s) == _normalize(str(c["label"])):
			return str(c["id"])
	return s


func _get_category_color(cat_id: String, categories: Array) -> Color:
	for c in categories:
		if str(c["id"]) == cat_id:
			return c["color"]
	return C_PRIMARY


# ------------------------------------------------------------
# TRANSFORMATION
# ------------------------------------------------------------
func _build_transformation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item, 10)

		var prompt := _make_label(_get_item_main_text(item), 38, _c_text(), true)
		item_vbox.add_child(prompt)

		var task_raw = item.get("task", "")
		if _get_en_text(task_raw) != "":
			var task := _make_label("Task: " + _get_en_text(task_raw), 32, _c_text_dim(), false)
			task.set_meta("text_fa", _get_fa_text(task_raw))
			item_vbox.add_child(task)

		var le := _make_line_edit("Write your answer...")
		item_vbox.add_child(le)

		_items.append({
			"type": "transformation",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# ERROR CORRECTION
# ------------------------------------------------------------
func _build_error_correction() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var s_raw = item.get("sentence", item.get("text", ""))
		var sentence_text := _get_en_text(s_raw)
		var wrong: String = str(item.get("wrong_word", item.get("target", "")))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", 42)
		rtl.add_theme_font_size_override("bold_font_size", 42)
		rtl.add_theme_font_size_override("italics_font_size", 42)
		rtl.add_theme_font_size_override("bold_italics_font_size", 42)
		rtl.add_theme_color_override("default_color", _c_text())
		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var marked := sentence_text
		if wrong != "":
			marked = sentence_text.replace(wrong, "[color=#DC2626][u]" + wrong + "[/u][/color]")
		rtl.text = marked
		item_vbox.add_child(rtl)

		var le := _make_line_edit("Type the correction...")
		item_vbox.add_child(le)

		_items.append({
			"type": "error_correction",
			"get": func(): return le.text,
			"answer": item.get("answer", ""),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# WORD BUILDING
# ------------------------------------------------------------
func _build_word_building() -> void:
	var options: Array = _exercise.get("options", [])
	var option_texts: Array = []
	for opt in options:
		option_texts.append(_get_option_text(opt))

	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(row)

		var prefix_label := _make_label(_get_en_text(item.get("prefix", "")) + "  +", 40, _c_text(), true)
		row.add_child(prefix_label)

		var ob := _make_option_dropdown(option_texts)
		row.add_child(ob)

		var answer: Variant = item.get("answer", "")
		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = _get_option_text(opt)
					break

		_items.append({
			"type": "word_building",
			"get": func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			"answer": answer,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": "",
			"explanation_fa": "",
		})


# ------------------------------------------------------------
# WORD SEARCH
# ------------------------------------------------------------
func _build_word_search() -> void:
	var word_list: Array = _exercise.get("words", [])
	var correct_words := _get_word_search_correct_words(word_list)

	if word_list.is_empty():
		var msg := _make_label("No words were provided for this word search.", 32, _c_text_dim(), false)
		_active_vbox.add_child(msg)
		return

	var words_title := _make_label("Tap the words:", 32, _c_text_dim(), true)
	_active_vbox.add_child(words_title)

	# Use a flow container so the words wrap correctly.
	var words_flow := HFlowContainer.new()
	words_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words_flow.add_theme_constant_override("h_separation", 14)
	words_flow.add_theme_constant_override("v_separation", 14)
	words_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(words_flow)

	for w in word_list:
		var word_text := _get_option_text(w)
		if word_text == "":
			continue

		# Create each word as a real selectable button.
		var wb := Button.new()
		wb.mouse_filter = Control.MOUSE_FILTER_PASS
		wb.text = word_text
		wb.toggle_mode = true
		wb.add_theme_font_size_override("font_size", 36)

		# This prevents the words from collapsing or piling up.
		wb.custom_minimum_size = Vector2(0, 64)
		wb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		wb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if _font_regular:
			wb.add_theme_font_override("font", _font_regular)

		_style_word_search_word_button(wb, "idle")
		wb.toggled.connect(_on_word_search_word_toggled.bind(wb))
		_register_scroll_control(wb)

		words_flow.add_child(wb)

		var is_correct := _is_word_search_word_correct(word_text, correct_words)

		_items.append({
			"type": "word_search_word",
			"get": func(): return wb.button_pressed,
			"answer": is_correct,
			"word_button": wb,
		})

func _get_word_search_row_text(row: Variant) -> String:
	# Supports both ["A", "B", "C"] and "ABC".
	if row is Array:
		var out := ""
		for ch in row:
			out += str(ch)
		return out

	return str(row)


func _get_word_search_answer_cells(grid_rows: Array, word_list: Array) -> Dictionary:
	var answer_set: Dictionary = {}
	var raw_cells: Variant = _exercise.get("answer_cells", [])

	# Manual answer_cells always wins.
	if raw_cells is Array and not raw_cells.is_empty():
		for cell in raw_cells:
			if cell is Array and cell.size() >= 2:
				answer_set["%d_%d" % [int(cell[0]), int(cell[1])]] = true
			elif cell is Vector2i:
				answer_set["%d_%d" % [cell.x, cell.y]] = true
			else:
				answer_set[str(cell).replace(" ", "").replace(",", "_")] = true

		return answer_set

	if raw_cells is Dictionary and not raw_cells.is_empty():
		for key in raw_cells:
			if bool(raw_cells[key]):
				answer_set[str(key).replace(" ", "").replace(",", "_")] = true

		return answer_set

	# If no manual answer_cells are provided, try to locate the words automatically.
	var correct_words_raw: Variant = _exercise.get("answer_words", _exercise.get("correct_words", []))
	var search_words: Array = []

	if correct_words_raw is Array and not correct_words_raw.is_empty():
		search_words = correct_words_raw
	else:
		search_words = word_list

	for w in search_words:
		var found_cells := _find_word_search_cells(grid_rows, _get_option_text(w))
		for key in found_cells:
			answer_set[key] = true

	return answer_set


func _find_word_search_cells(grid_rows: Array, word: String) -> Array:
	var result: Array = []
	var needle := _clean_word_search_text(word)

	if needle == "":
		return result

	var rows := grid_rows.size()
	if rows == 0:
		return result

	# Use a typed array so the compiler knows these are Vector2i values.
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(-1, 1),
	]

	for r in rows:
		var row_index: int = int(r)
		var row_text := _get_word_search_row_text(grid_rows[row_index])

		for c in row_text.length():
			var col_index: int = int(c)

			for d in directions:
				var dir: Vector2i = d
				var cells: Array = []
				var ok := true

				for i in needle.length():
					var char_index: int = int(i)

					# Explicit int types prevent the inference error.
					var rr: int = row_index + dir.y * char_index
					var cc: int = col_index + dir.x * char_index

					if rr < 0 or rr >= rows:
						ok = false
						break

					var current_row := _get_word_search_row_text(grid_rows[rr])

					if cc < 0 or cc >= current_row.length():
						ok = false
						break

					var cell_letter := _clean_word_search_text(current_row.substr(cc, 1))

					if cell_letter != needle.substr(char_index, 1):
						ok = false
						break

					cells.append("%d_%d" % [rr, cc])

				if ok and cells.size() == needle.length():
					result.append_array(cells)

	return result

func _clean_word_search_text(s: String) -> String:
	var out := ""
	s = s.to_upper()

	# Remove spaces, keep visible characters.
	for ch in s:
		if ch.strip_edges() != "":
			out += ch

	return out


func _on_word_search_cell_toggled(pressed: bool, btn: Button) -> void:
	# Do not allow visual state changes after grading.
	if _is_graded:
		return

	if pressed:
		_style_word_search_cell(btn, "selected")
	else:
		_style_word_search_cell(btn, "idle")

func _get_word_search_correct_words(word_list: Array) -> Array:
	# You can define correct words in JSON using:
	# "answer_words": ["apple", "book"]
	# or
	# "correct_words": ["apple", "book"]
	var raw: Variant = _exercise.get("answer_words", _exercise.get("correct_words", []))

	var source: Array = []

	if raw is Array and not raw.is_empty():
		source = raw
	elif raw is String and str(raw).strip_edges() != "":
		source = [raw]
	else:
		# If no correct words are provided, all listed words are treated as correct.
		source = word_list

	var out: Array = []

	for w in source:
		var s := _normalize(_get_option_text(w))
		if s != "":
			out.append(s)

	return out


func _is_word_search_word_correct(word_text: String, correct_words: Array) -> bool:
	var normalized_word := _normalize(word_text)

	for correct in correct_words:
		if _normalize(str(correct)) == normalized_word:
			return true

	return false


func _on_word_search_word_toggled(pressed: bool, btn: Button) -> void:
	# Do not change visual state after grading.
	if _is_graded:
		return

	if pressed:
		_style_word_search_word_button(btn, "selected")
	else:
		_style_word_search_word_button(btn, "idle")


func _style_word_search_word_button(btn: Button, state: String) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1

	var bg := _c_surface()
	var border := _c_border()
	var font_color := _c_text()

	match state:
		"selected":
			# User selected before checking.
			bg = _c_warning()
			border = _c_warning()
			font_color = Color("#241a00")
		"correct":
			# Correct answer after checking.
			bg = _c_success()
			border = _c_success()
			font_color = Color("#03251a")
		"wrong":
			# Wrong selected word after checking.
			bg = _c_error()
			border = _c_error()
			font_color = Color("#2b0505")
		_:
			# Idle / unselected.
			bg = _c_surface()
			border = _c_border()
			font_color = _c_text()

	style.bg_color = bg
	style.border_color = border

	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color)

func _grade_word_search() -> void:
	var correct_total := 0
	var correct_selected := 0
	var wrong_selected := 0

	for item in _items:
		if str(item.get("type", "")) != "word_search_word":
			continue

		var btn: Button = item.get("word_button", null)
		if btn == null:
			continue

		var is_correct: bool = bool(item.get("answer", false))
		var is_selected: bool = btn.button_pressed

		# Freeze the buttons after checking.
		btn.disabled = true

		if is_correct:
			correct_total += 1

			if is_selected:
				correct_selected += 1

			# All correct words become green.
			_style_word_search_word_button(btn, "correct")
		else:
			if is_selected:
				wrong_selected += 1

				# Wrong selected words become red.
				_style_word_search_word_button(btn, "wrong")
			else:
				_style_word_search_word_button(btn, "idle")

	_is_graded = true

	if _score_banner:
		_score_banner.visible = true
		if correct_total == 0:
			_score_banner.text = _t_fa("no_correct_words")
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", _c_warning())
		elif correct_selected == correct_total and wrong_selected == 0:
			_score_banner.text = _t_fa("all_correct_words")
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", _c_success())
		elif wrong_selected > 0:
			_score_banner.text = _t_fa("chose_correct_and_wrong") % [
				correct_selected,
				correct_total,
				wrong_selected
			]
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", _c_error())
		else:
			_score_banner.text = _t_fa("chose_correct") % [
				correct_selected,
				correct_total
			]
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", C_PRIMARY)

	if _note_label:
		_note_label.visible = true

	if _check_btn:
		_check_btn.text = _t("try_again")
		_apply_fa_meta(_check_btn, "try_again")

	exercise_checked.emit(
		str(_exercise.get("exercise_id", "")),
		correct_selected,
		correct_total
	)

func _style_word_search_cell(btn: Button, state: String) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_content_margin_all(3)

	var bg := Color(0, 0, 0, 0)
	var font_color := _c_text()

	match state:
		"selected":
			# User-selected before checking.
			bg = _c_warning()
			font_color = Color("#241a00")
		"correct":
			# Correct answer after checking.
			bg = _c_success()
			font_color = Color("#03251a")
		"wrong":
			# Wrong selected cell after checking.
			bg = _c_error()
			font_color = Color("#2b0505")
		_:
			# Idle / unselected.
			bg = Color(0, 0, 0, 0)
			font_color = _c_text()

	style.bg_color = bg

	# Override every state so the color remains visible after disabling.
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color)

# ------------------------------------------------------------
# CHART FILL
# ------------------------------------------------------------
func _build_chart_fill() -> void:
	var columns: int = _exercise.get("columns", 2)
	var headers: Array = _exercise.get("headers", [])
	var rows: Array = _exercise.get("rows", [])
	var show_labels: bool = _exercise.get("show_labels", true)

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(grid)

	if show_labels and not headers.is_empty():
		for header in headers:
			var h := _make_label(_get_en_text(header), 34, C_PRIMARY, true)
			h.set_meta("text_fa", _get_fa_text(header))
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(h)

	for row in rows:
		var cells: Array = row.get("cells", [])
		for cell in cells:
			var cell_box := VBoxContainer.new()
			cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_box.add_theme_constant_override("separation", 4)
			cell_box.alignment = BoxContainer.ALIGNMENT_CENTER
			cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell_box)

			if cell.get("editable", false):
				var placeholder: String = _get_en_text(cell.get("placeholder", "..."))
				var le := _make_chart_input(placeholder)
				cell_box.add_child(le)
				_items.append({
					"type": "chart_fill",
					"get": func(): return le.text,
					"answer": cell.get("answer", []),
					"feedback": _make_feedback(cell_box),
					"explanation_en": _get_en_text(cell.get("explanation", {})),
					"explanation_fa": _get_fa_text(cell.get("explanation", {})),
				})
			else:
				var text_val: Dictionary = cell.get("text", {})
				var lbl := _make_label(_get_en_text(text_val), 34, _c_text(), false)
				lbl.set_meta("text_fa", _get_fa_text(text_val))
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(lbl)


# ------------------------------------------------------------
# ODD ONE OUT
# ------------------------------------------------------------
func _build_odd_one_out() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var words_raw: Array = item.get("words", item.get("options", []))
		var word_texts: Array = []
		for w in words_raw:
			word_texts.append(_get_option_text(w))

		var question_text := "Which word does not belong?"
		if item.has("question"):
			question_text = _get_en_text(item.get("question", ""))
		var q_label := _make_label(question_text, 34, _c_text(), true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		# One wide column for 2-3 options, two equal columns for more.
		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = 2 if word_texts.size() >= 4 else 1
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(grid)

		for w in word_texts:
			var b := _make_select_button(str(w), group, _c_warning())
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = _normalize_answer_index(item.get("answer", -1))
		if answer is String:
			answer = _find_option_index(word_texts, answer)
		# Build answer_display with the actual word instead of index.
		var answer_display := ""
		if answer is int and answer >= 0 and answer < word_texts.size():
			answer_display = str(word_texts[answer])

		_items.append({
			"type": "odd_one_out",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"answer_display": answer_display,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# GRAMMAR CHOICE
# ------------------------------------------------------------
func _build_grammar_choice() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var sentence: String = _get_en_text(item.get("sentence", item.get("text", "")))
		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", 42)
		rtl.add_theme_font_size_override("bold_font_size", 42)
		rtl.add_theme_font_size_override("italics_font_size", 42)
		rtl.add_theme_font_size_override("bold_italics_font_size", 42)
		rtl.add_theme_color_override("default_color", _c_text())
		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)
		var highlighted := sentence.replace("___", "[color=#2563EB][u]___[/u][/color]")
		rtl.text = highlighted
		item_vbox.add_child(rtl)

		var options: Array = item.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = maxi(mini(option_texts.size(), 2), 1)
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(grid)

		for opt in option_texts:
			var b := _make_select_button(str(opt), group, C_INFO)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)
		# Store the correct option's text so feedback shows the actual word,
		# not the numeric option index.
		var answer_display := ""
		if answer is int and answer >= 0 and answer < option_texts.size():
			answer_display = str(option_texts[answer])
		_items.append({
			"type": "grammar_choice",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"answer_display": answer_display,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# PASSIVE TRANSFORMATION
# ------------------------------------------------------------
func _build_passive_transformation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var active_text: String = _get_en_text(item.get("active", item.get("prompt", "")))
		var label := _make_label("Active: " + active_text, 36, _c_text(), true)
		item_vbox.add_child(label)

		var hint_text := _get_en_text(item.get("hint", "Rewrite in passive voice:"))
		var hint := _make_label("Task: " + hint_text, 32, _c_text_dim(), false)
		item_vbox.add_child(hint)

		var le := _make_line_edit("Type the passive sentence...")
		item_vbox.add_child(le)

		_items.append({
			"type": "passive_transformation",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# GRAMMAR IDENTIFICATION
# ------------------------------------------------------------
func _build_grammar_identification() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var text_val: String = _get_en_text(item.get("text", item.get("sentence", "")))
		var target: String = str(item.get("target", ""))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", 40)
		rtl.add_theme_font_size_override("bold_font_size", 40)
		rtl.add_theme_font_size_override("italics_font_size", 40)
		rtl.add_theme_font_size_override("bold_italics_font_size", 40)
		rtl.add_theme_color_override("default_color", _c_text())
		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var highlighted := text_val
		if target != "":
			highlighted = text_val.replace(target, "[color=#DC2626][u]" + target + "[/u][/color]")
		rtl.text = highlighted
		item_vbox.add_child(rtl)

		var question := _make_label("What is the grammatical form of the underlined word or phrase?", 32, _c_text_dim(), false)
		item_vbox.add_child(question)

		var options: Array = item.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		for opt in option_texts:
			var b := _make_select_button(str(opt), group, C_PURPLE)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)
		# Store the correct option's text so feedback shows the actual word.
		var answer_display := ""
		if answer is int and answer >= 0 and answer < option_texts.size():
			answer_display = str(option_texts[answer])
		_items.append({
			"type": "grammar_identification",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"answer_display": answer_display,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# QUESTION FORMATION
# ------------------------------------------------------------
func _build_question_formation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var prompt_text: String = _get_en_text(item.get("prompt", "Form a question:"))
		var label := _make_label(prompt_text, 36, _c_text(), true)
		label.set_meta("text_fa", _get_fa_text(item.get("prompt", "")))
		item_vbox.add_child(label)

		var le := _make_line_edit("Type your question...")
		item_vbox.add_child(le)

		_items.append({
			"type": "question_formation",
			"get": func(): return le.text,
			"answer": item.get("answer", []),
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
			"answer_patterns": item.get("answer_patterns", []),
			"required_words": item.get("required_words", []),
			"forbidden_words": item.get("forbidden_words", []),
		})


# ------------------------------------------------------------
# TOKEN LABEL
# ------------------------------------------------------------
func _build_token_label() -> void:
	var default_labels: Array = _exercise.get("labels", [])
	if default_labels.is_empty():
		default_labels = ["S", "O", "V", "Adv"]

	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item, 14)

		var inst := _get_en_text(item.get("instruction", ""))
		if inst != "":
			item_vbox.add_child(_make_label(inst, 32, _c_text_dim(), false))

		var labels_raw: Array = item.get("labels", default_labels)
		var categories := _normalize_categories(labels_raw)
		var label_ids: Array = []
		var label_names: Array = []
		for c in categories:
			label_ids.append(str(c["id"]))
			label_names.append(str(c["label"]))

		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 12)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(flow)

		var tokens: Array = item.get("tokens", [])
		var token_answers: Array = item.get("answers", [])

		for t_i in tokens.size():
			var token = tokens[t_i]
			var token_box := VBoxContainer.new()
			token_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			token_box.add_theme_constant_override("separation", 4)
			token_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			flow.add_child(token_box)

			var token_text := ""
			var ans := ""
			var expl_en := ""
			var expl_fa := ""
			if token is Dictionary:
				token_text = _get_en_text(token.get("text", token.get("word", "")))
				ans = _category_id_from_value(token.get("answer", ""), categories)
				expl_en = _get_en_text(token.get("explanation", ""))
				expl_fa = _get_fa_text(token.get("explanation", ""))
			else:
				token_text = _get_en_text(token)
				if t_i < token_answers.size():
					ans = _category_id_from_value(token_answers[t_i], categories)

			# Show the readable label in feedback instead of the raw category id.
			var ans_display := ans
			for c in categories:
				if str(c["id"]) == ans:
					ans_display = str(c["label"])
					break

			var word_label := _make_label(token_text, 36, _c_text(), true)
			token_box.add_child(word_label)

			var ob := OptionButton.new()
			ob.mouse_filter = Control.MOUSE_FILTER_PASS
			ob.add_item("—")
			for lname in label_names:
				ob.add_item(lname)
			ob.selected = 0
			ob.add_theme_font_size_override("font_size", 32)
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _font_regular:
				ob.add_theme_font_override("font", _font_regular)
			token_box.add_child(ob)
			_register_scroll_control(ob)

			var fb := _make_feedback(token_box)
			var ids := label_ids.duplicate()
			_items.append({
				"type": "token_label",
				"get": func():
					if ob.selected > 0 and ob.selected - 1 < ids.size():
						return ids[ob.selected - 1]
					return "",
				"answer": ans,
				"answer_display": ans_display,
				"feedback": fb,
				"explanation_en": expl_en,
				"explanation_fa": expl_fa,
			})


# ------------------------------------------------------------
# IMAGE CHOICE
# ------------------------------------------------------------
func _build_image_choice() -> void:
	var question := _get_en_text(_exercise.get("question", _exercise.get("prompt", "")))
	if question != "":
		_active_vbox.add_child(_make_label(question, 38, _c_text(), true))

	var options: Array = _exercise.get("options", [])
	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(flow)

	var group := ButtonGroup.new()
	var option_btns: Array[Button] = []
	for opt in options:
		var b := _make_image_option_button(opt, group)
		option_btns.append(b)
		flow.add_child(b)

	var answer: Variant = _exercise.get("answer", -1)
	if answer is String:
		answer = _find_option_index(options, answer)
	# Store the correct option's text so feedback shows the actual word.
	var answer_display := ""
	if answer is int and answer >= 0 and answer < options.size():
		answer_display = _get_option_text(options[answer])
	var fb := _make_feedback(_active_vbox)
	_items.append({
		"type": "image_choice",
		"get": func():
			for i in option_btns.size():
				if option_btns[i].button_pressed:
					return i
			return -1,
		"answer": answer,
		"answer_display": answer_display,
		"feedback": fb,
		"explanation_en": _get_en_text(_exercise.get("explanation", "")),
		"explanation_fa": _get_fa_text(_exercise.get("explanation", "")),
	})


# ------------------------------------------------------------
# IMAGE MATCH
# ------------------------------------------------------------
func _build_image_match() -> void:
	var options: Array = _exercise.get("options", [])
	for item in _exercise.get("items", []):
		var item_vbox := _start_item_block(item)

		var text := _get_item_main_text(item)
		if text != "":
			item_vbox.add_child(_make_label(text, 38, _c_text(), true))

		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 12)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(flow)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		for opt in options:
			var b := _make_image_option_button(opt, group)
			option_btns.append(b)
			flow.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)
		# Store the correct option's text so feedback shows the actual word.
		var answer_display := ""
		if answer is int and answer >= 0 and answer < options.size():
			answer_display = _get_option_text(options[answer])
		_items.append({
			"type": "image_match",
			"get": func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			"answer": answer,
			"answer_display": answer_display,
			"feedback": _make_feedback(item_vbox),
			"explanation_en": _get_en_text(item.get("explanation", "")),
			"explanation_fa": _get_fa_text(item.get("explanation", "")),
		})


# ------------------------------------------------------------
# IMAGE HOTSPOT / MAP MARKING
# ------------------------------------------------------------
func _build_image_hotspot() -> void:
	var img_path := _get_first_image_path(_exercise)
	if img_path == "" or not ResourceLoader.exists(img_path):
		var missing_label := _make_label(_t("image_not_found_prefix") + img_path, 32, _c_error(), false)
		missing_label.set_meta("text_fa", str(UI_STRINGS["image_not_found_prefix"]["fa"]) + img_path)
		_active_vbox.add_child(missing_label)
		return
	var tex := load(img_path) as Texture2D
	if tex == null:
		_active_vbox.add_child(_make_label("Could not load image: " + img_path, 32, _c_error(), false))
		return

	var base_size: Vector2 = tex.get_size()
	if base_size.x <= 0:
		base_size.x = 900
	if base_size.y <= 0:
		base_size.y = 600

	# Clamp the map to the real screen width so it never overflows.
	var max_width := minf(float(_exercise.get("max_width", 900)), _viewport_width() - 72.0)
	max_width = maxf(max_width, 200.0)
	var ratio := max_width / base_size.x

	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(max_width, base_size.y * ratio)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_vbox.add_child(ctrl)

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

	var overlay: HotspotOverlayScript = HotspotOverlayScript.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.base_size = base_size
	overlay.hotspots = _exercise.get("hotspots", [])

	var answer_ids: Array = []
	var ans_raw: Variant = _exercise.get("answer", [])
	if ans_raw is Array:
		for a in ans_raw:
			answer_ids.append(str(a))
	else:
		answer_ids.append(str(ans_raw))

	overlay.multi = bool(_exercise.get("multi", answer_ids.size() != 1))
	ctrl.add_child(overlay)

	var fb := _make_feedback(_active_vbox)
	_items.append({
		"type": "image_hotspot",
		"get": func(): return overlay.selected.duplicate(),
		"answer": answer_ids,
		"feedback": fb,
		"answer_display": _join_string_array(answer_ids, ", "),
		"explanation_en": _get_en_text(_exercise.get("explanation", "")),
		"explanation_fa": _get_fa_text(_exercise.get("explanation", "")),
	})