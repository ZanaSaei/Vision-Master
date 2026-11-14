# ============================================================
# ExerciseEngine - WIDGETS layer.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# Holds: text/string helpers, all widget factories and the
# audio button / panel.
# ============================================================
class_name ExerciseEngineWidgets
extends "res://scenes/shared/exercise_engine/exercise_engine_core.gd"
const DropdownScript := preload("res://scenes/shared/exercise_engine/Dropdown.gd")

# Reusable widget scenes (static styling lives in the Theme; see the widgets/
# folder scripts). The factories below instantiate these instead of building
# the controls from scratch, keeping their signatures unchanged.
const CHOICE_BUTTON_SCENE := preload("res://scenes/shared/exercise_engine/widgets/ChoiceButton.tscn")
const CHIP_BUTTON_SCENE := preload("res://scenes/shared/exercise_engine/widgets/ChipButton.tscn")
const ANSWER_LINE_EDIT_SCENE := preload("res://scenes/shared/exercise_engine/widgets/AnswerLineEdit.tscn")
const FEEDBACK_LABEL_SCENE := preload("res://scenes/shared/exercise_engine/widgets/FeedbackLabel.tscn")

# ---------- text / string helpers ----------
func _get_en_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("en", ""))
	return str(val)


func _get_fa_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("fa", ""))
	return ""


# Returns true when Persian characters outnumber Latin ones in `text`.
# Used to pick RTL vs LTR base direction for mixed Persian/English lines
# so punctuation and word order stay correct (a single stray Persian word
# should not flip a mostly-English line to RTL, and vice versa).
func _is_fa_dominant(text: String) -> bool:
	var fa := 0
	var lat := 0
	for i in text.length():
		var u: int = text.unicode_at(i)
		if u >= 0x0600 and u <= 0x06FF:
			fa += 1
		elif (u >= 0x0041 and u <= 0x007A) or (u >= 0x00C0 and u <= 0x024F):
			lat += 1
	return fa > 0 and fa >= lat


func _get_item_main_text(item: Dictionary) -> String:
	for key in ["question", "prompt", "text", "statement", "sentence", "title", "word", "active"]:
		if item.has(key):
			var val := _get_en_text(item.get(key))
			if val != "":
				return val
	return ""


func _get_option_text(opt: Variant) -> String:
	if opt is Dictionary:
		if opt.has("en") or opt.has("fa"):
			return _get_en_text(opt)
		for key in ["label", "text", "title", "name", "id"]:
			if opt.has(key):
				return _get_en_text(opt.get(key))
		return ""
	return str(opt)


func _find_option_index(options: Array, value: Variant) -> int:
	var s := str(value)
	for i in options.size():
		var opt = options[i]
		if opt is Dictionary and str(opt.get("id", "")) == s:
			return i
		if _normalize(_get_option_text(opt)) == _normalize(s):
			return i
	return -1


# Centralized choice resolver for multiple choice, odd one out, grammar choice,
# image choice, etc. Handles ints, floats (from JSON), dict IDs, and array options.
func _resolve_choice_answer(options: Array, raw_answer: Variant) -> Dictionary:
	var norm_ans = _normalize_answer_index(raw_answer)
	var answer_index := -1
	var answer_text := ""

	if norm_ans is Array:
		var accepted: Array = []
		for entry in norm_ans:
			var res := _resolve_choice_answer(options, entry)
			var idx: int = int(res.get("index", -1))
			if idx >= 0:
				accepted.append(idx)
				if answer_text == "":
					answer_text = str(res.get("text", ""))
		var primary_idx: int = accepted[0] if not accepted.is_empty() else -1
		return {
			"index": primary_idx,
			"text": answer_text,
			"accepted_indices": accepted,
		}

	if norm_ans is int:
		var idx_int: int = norm_ans
		if idx_int >= 0 and idx_int < options.size():
			answer_index = idx_int
			answer_text = _get_option_text(options[idx_int])
	elif norm_ans != null:
		var found_idx := _find_option_index(options, norm_ans)
		if found_idx >= 0 and found_idx < options.size():
			answer_index = found_idx
			answer_text = _get_option_text(options[found_idx])
		else:
			answer_text = _get_en_text(norm_ans)

	var accepted_arr: Array = []
	if answer_index >= 0:
		accepted_arr.append(answer_index)
	return {
		"index": answer_index,
		"text": answer_text,
		"accepted_indices": accepted_arr,
	}


# Centralized dropdown resolver for matching, categorize, word bank, table fill.
func _resolve_dropdown_answer(options: Array, raw_answer: Variant) -> Dictionary:
	var norm_ans = _normalize_answer_index(raw_answer)
	var answer_str := ""
	var answer_idx := -1

	if norm_ans is int:
		var idx_int: int = norm_ans
		if idx_int >= 0 and idx_int < options.size():
			answer_idx = idx_int
			answer_str = _get_option_text(options[idx_int])
	elif norm_ans != null:
		var s := str(norm_ans)
		for i in options.size():
			var opt = options[i]
			if opt is Dictionary and str(opt.get("id", "")) == s:
				answer_idx = i
				answer_str = _get_option_text(opt)
				break
			if _normalize(_get_option_text(opt)) == _normalize(s):
				answer_idx = i
				answer_str = _get_option_text(opt)
				break
		if answer_str == "":
			answer_str = _get_en_text(norm_ans)

	return {
		"index": answer_idx,
		"text": answer_str,
	}

# ------------------------------------------------------------
# JSON parses every number as float ("answer": 1 -> 1.0), so
# `answer is int` silently fails for answers loaded from JSON.
# Normalize whole-number floats back to int once, right after
# reading them, so index checks and answer_display work.
# ------------------------------------------------------------
func _normalize_answer_index(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	return value

func _join_words(arr: Array) -> String:
	var parts: Array = []
	for a in arr:
		parts.append(str(a))
	return " ".join(parts)


func _join_string_array(arr: Array, sep: String) -> String:
	var out := ""
	for i in arr.size():
		out += str(arr[i])
		if i < arr.size() - 1:
			out += sep
	return out

# ---------- widget factories + audio ----------
# Clears the pressed state of a group of toggle/select buttons. Used by the
# in-place retry reset (a ButtonGroup is left with nothing selected, which is
# the same state the buttons start in before the learner answers).
func _clear_select_buttons(btns: Array) -> void:
	for b in btns:
		if b is BaseButton and is_instance_valid(b):
			(b as BaseButton).button_pressed = false

func _make_label(text: String, font_size: int, color: Color, bold: bool) -> Label:
	font_size += 4
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 0
	l.add_theme_font_size_override("font_size", maxi(font_size, MIN_FONT))
	l.add_theme_color_override("font_color", color)
	var fa_dominant := _is_fa_dominant(text)
	l.text = GrammarTheme.bidi_fix(text)
	l.text_direction = Control.TEXT_DIRECTION_RTL if fa_dominant else Control.TEXT_DIRECTION_LTR
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa_dominant else HORIZONTAL_ALIGNMENT_LEFT
	if fa_dominant and _font_farsi:
		l.add_theme_font_override("font", _font_farsi)
	elif bold and _font_bold:
		l.add_theme_font_override("font", _font_bold)
	elif not bold and _font_regular:
		l.add_theme_font_override("font", _font_regular)
	return l


const COLOR_UNSET := Color(0, 0, 0, -1)

# Creates an RTL Farsi label for showing a translation line under authored
# English content, then adds it to _active_vbox right after the content it
# translates. Visible only while show_translation is on; set_show_translation()
# flips every collected Farsi label at once.
func _add_fa_label(fa_text: String, font_size: int = 32, color := COLOR_UNSET) -> Label:
	font_size += 4
	var clean := fa_text.strip_edges()
	if clean == "":
		return null
	if color.a < 0.0:
		color = _c_text_dim()
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = GrammarTheme.bidi_fix(clean)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", maxi(font_size, MIN_FONT))
	label.add_theme_color_override("font_color", color)
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _font_farsi:
		label.add_theme_font_override("font", _font_farsi)
	label.visible = show_translation
	_fa_labels.append(label)
	_active_vbox.add_child(label)
	return label


# Public switch used by the Workbook header toggle. Shows/hides every Farsi
# translation label this engine built once (they keep their place in the
# layout either way, so toggling never reflows the page).
func set_show_translation(v: bool) -> void:
	show_translation = v
	for label in _fa_labels:
		if is_instance_valid(label):
			label.visible = v


func _make_option_button(text: String, group: ButtonGroup) -> Button:
	return _make_select_button(text, group, C_PRIMARY)


# Maps the accent a select button was asked to use to the matching Theme type
# variation. The appearance itself lives in the Theme resource (generated into
# vision_master_light.tres by tools/generate_design_resources.gd); this only
# chooses which predefined variation to apply, so a restyle is a Theme edit.
func _choice_variation_for(accent: Color) -> StringName:
	if _color_matches(accent, _c_success()):
		return &"ChoiceButtonSuccess"
	if _color_matches(accent, _c_error()):
		return &"ChoiceButtonError"
	if _color_matches(accent, _c_warning()):
		return &"ChoiceButtonWarning"
	if _color_matches(accent, C_INFO):
		return &"ChoiceButtonInfo"
	if _color_matches(accent, C_PURPLE):
		return &"ChoiceButtonPurple"
	return &"ChoiceButton"


func _color_matches(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) and is_equal_approx(a.b, b.b)


func _make_select_button(text: String, group: ButtonGroup, accent: Color) -> Button:
	var b: Button = CHOICE_BUTTON_SCENE.instantiate()
	# Mixed Farsi/English option text needs bidi isolates and a matching
	# base direction, otherwise Latin fragments inside a Farsi line (or
	# Farsi words inside an English line) visually scramble. The engine's
	# own _is_fa_dominant() rule is passed through unchanged.
	b.call("setup", GrammarTheme.bidi_fix(text), _is_fa_dominant(text), group, _choice_variation_for(accent))
	_register_scroll_control(b)
	return b


func _make_image_option_button(opt: Variant, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(190, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = _get_option_text(opt)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Same shape as a ChoiceButton, tighter margins/font — Theme supplied.
	b.theme_type_variation = &"ImageChoiceButton"

	if opt is Dictionary:
		var path := str(opt.get("image", opt.get("path", "")))
		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				b.icon = tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_register_scroll_control(b)
	return b


func _make_option_dropdown(options: Array, placeholder := "") -> DropdownScript:
	var dd: DropdownScript = DropdownScript.new()
	dd.mouse_filter = Control.MOUSE_FILTER_PASS
	dd.placeholder = placeholder if placeholder != "" else _t("choose")
	dd.set_font(_font_regular)
	for opt in options:
		dd.add_item(str(opt))
	dd.selected = 0
	dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_scroll_control(dd)
	return dd


func _make_line_edit(placeholder: String) -> LineEdit:
	var le: LineEdit = ANSWER_LINE_EDIT_SCENE.instantiate()
	le.placeholder_text = placeholder
	_register_scroll_control(le)
	return le


func _make_chart_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.theme_type_variation = &"ChartInput"
	_register_scroll_control(le)
	return le


func _make_chip_button(text: String, filled := false) -> Button:
	var b: Button = CHIP_BUTTON_SCENE.instantiate()
	# Bidi-safe display for mixed Farsi/English chips.
	b.call("setup", GrammarTheme.bidi_fix(text), _is_fa_dominant(text), filled)
	_register_scroll_control(b)
	return b


# compact = smaller tile for dense grids like word search.
func _make_word_toggle(word: String, compact := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	# Bidi-safe display for mixed Farsi/English words.
	b.text = GrammarTheme.bidi_fix(word)
	b.text_direction = Control.TEXT_DIRECTION_RTL if _is_fa_dominant(word) else Control.TEXT_DIRECTION_LTR
	b.toggle_mode = true
	if compact:
		# Even dense grid tiles stay at/above the minimum tap size.
		b.custom_minimum_size = Vector2(48, 56)
	else:
		b.custom_minimum_size = Vector2(0, 76)
	b.theme_type_variation = &"WordToggleCompact" if compact else &"WordToggle"
	_register_scroll_control(b)
	return b


func _make_feedback(parent: Node) -> Label:
	var fb: Label = FEEDBACK_LABEL_SCENE.instantiate()
	parent.add_child(fb)
	return fb


# ============================================================
# AUDIO BUTTON (Play / Stop via AudioPanel.tscn)
# ============================================================
func _add_audio_button() -> void:
	var type := str(_exercise.get("type", "open_ended"))
	
	# 1) Is this exercise allowed to have the audio button?
	if not _should_show_audio_button(type):
		return
	
	# 2) Does the JSON provide an audio file?
	_audio_path = _get_audio_path()
	if _audio_path == "":
		return
	
	# 3) Create the Play/Stop toggle button unconditionally so off-tree
	# build() calls (e.g. from workbook page preloading) keep their audio button.
	_audio_btn = _make_button("Play the Audio", C_PURPLE)
	_audio_btn.pressed.connect(_on_audio_button_pressed)
	_active_vbox.add_child(_audio_btn)
	
	# 4) If already inside tree, connect panel signals.
	if is_inside_tree():
		_connect_audio_panel_signals()


func _connect_audio_panel_signals() -> void:
	var panel := _get_or_create_audio_panel()
	if panel != null:
		if panel.has_signal("audio_closed") and not panel.audio_closed.is_connected(_on_audio_panel_closed):
			panel.audio_closed.connect(_on_audio_panel_closed)
		if panel.has_signal("audio_finished") and not panel.audio_finished.is_connected(_on_audio_panel_closed):
			panel.audio_finished.connect(_on_audio_panel_closed)
		if panel.has_signal("visibility_changed_state") and not panel.visibility_changed_state.is_connected(_on_audio_panel_visibility_changed):
			panel.visibility_changed_state.connect(_on_audio_panel_visibility_changed)


func _on_audio_panel_visibility_changed(is_open: bool) -> void:
	if not is_open:
		_set_audio_button_idle()


func _should_show_audio_button(type: String) -> bool:
	# Per-exercise JSON override:
	# "show_audio": true  -> forces the button ON
	# "show_audio": false -> forces the button OFF
	if _exercise.has("show_audio"):
		return bool(_exercise.get("show_audio"))
	
	# Global mode: allow every type.
	if audio_allow_any_type:
		return true
	
	# Otherwise, only types listed in audio_types are allowed.
	return audio_types.has(type)


func _get_audio_path() -> String:
	# Supports both "audio": "res://path.mp3"
	# and "audio": { "path": "res://path.mp3" }
	var raw: Variant = _exercise.get("audio", "")
	if raw is Dictionary:
		return str(raw.get("path", ""))
	return str(raw)


func _get_or_create_audio_panel() -> Node:
	# 1) Reuse our existing instance.
	if _audio_panel != null and is_instance_valid(_audio_panel):
		return _audio_panel
	
	# 2) Use an externally assigned panel if one was set.
	if audio_panel != null and is_instance_valid(audio_panel):
		_audio_panel = audio_panel
		return _audio_panel
	
	# 3) Reuse a shared panel created by another engine.
	if is_inside_tree():
		var found := get_tree().get_first_node_in_group("audio_panel")
		if found != null:
			_audio_panel = found
			return _audio_panel
	
	# 4) Nothing exists yet -> instantiate AudioPanel.tscn automatically.
	if not is_inside_tree():
		return null
	
	if not ResourceLoader.exists(audio_panel_scene_path):
		push_warning("ExerciseEngine: AudioPanel scene not found: " + audio_panel_scene_path)
		return null
	
	var scene := load(audio_panel_scene_path) as PackedScene
	if scene == null:
		return null
	
	var panel: Node = scene.instantiate()
	
	# Add it to the ROOT so it is never clipped by a ScrollContainer
	# and always draws on top of the workbook pages.
	get_tree().root.add_child(panel)
	
	# Dock it to the bottom of the screen matching AudioPanel.tscn.
	if panel is Control:
		var c_panel := panel as Control
		c_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		c_panel.offset_top = -356.0
		c_panel.offset_bottom = 0.0
		c_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		c_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Start hidden. load_and_play() will show it.
	panel.hide()
	
	# Register it so other engines reuse this instance
	# instead of creating more panels.
	panel.add_to_group("audio_panel")
	
	_audio_panel = panel
	_audio_panel_owned = true
	return _audio_panel


func _on_audio_button_pressed() -> void:
	# Lazy lookup in case the panel was freed or deferred.
	if _audio_panel == null or not is_instance_valid(_audio_panel):
		_audio_panel = _get_or_create_audio_panel()
	
	if _audio_panel == null:
		return
	_connect_audio_panel_signals()
	
	var is_this_playing := _audio_btn != null and _audio_btn.text == "Stop the Audio"
	if is_this_playing and _audio_panel.has_method("is_playing") and _audio_panel.call("is_playing"):
		# Audio is playing for this engine -> stop it and close the panel.
		_audio_panel.call("stop_and_close")
		_set_audio_button_idle()
	else:
		# Play audio for this engine.
		_audio_panel.call("load_and_play", _audio_path)
		_set_audio_button_playing()


func _set_audio_button_playing() -> void:
	if _audio_btn != null and is_instance_valid(_audio_btn):
		_audio_btn.text = "Stop the Audio"
		# Red so it clearly means "stop".
		_set_button_color(_audio_btn, _c_error())


func _set_audio_button_idle() -> void:
	if _audio_btn != null and is_instance_valid(_audio_btn):
		_audio_btn.text = "Play the Audio"
		_set_button_color(_audio_btn, C_PURPLE)


func _on_audio_panel_closed() -> void:
	# Connected to both audio_closed and audio_finished.
	# The panel was closed OR the track ended -> reset the button.
	_set_audio_button_idle()

func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	# Bidi-safe display for mixed Farsi/English button labels.
	btn.text = GrammarTheme.bidi_fix(text)
	btn.text_direction = Control.TEXT_DIRECTION_RTL if _is_fa_dominant(text) else Control.TEXT_DIRECTION_LTR
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", Color.WHITE)
	# Comfortable tap target for action buttons.
	btn.custom_minimum_size = Vector2(0, 88)
	_set_button_color(btn, color)
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	_register_scroll_control(btn)
	return btn


func _set_button_color(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.set_content_margin_all(18)
	style.shadow_color = Color(color.r, color.g, color.b, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.12)
	hover.shadow_size = 14
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
