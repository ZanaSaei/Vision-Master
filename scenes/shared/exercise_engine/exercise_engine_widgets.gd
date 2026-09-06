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
	if fa_dominant and _font_farsi:
		l.add_theme_font_override("font", _font_farsi)
	elif bold and _font_bold:
		l.add_theme_font_override("font", _font_bold)
	elif not bold and _font_regular:
		l.add_theme_font_override("font", _font_regular)
	return l


# Creates an RTL Farsi label for showing a translation line under authored
# English content, then adds it to _active_vbox right after the content it
# translates. Visible only while show_translation is on; set_show_translation()
# flips every collected Farsi label at once.
func _add_fa_label(fa_text: String, font_size: int = 32, color: Color = Color(0, 0, 0, -1)) -> Label:
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


func _make_select_button(text: String, group: ButtonGroup, accent: Color) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = "   " + text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", _c_text())
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = _c_surface()
	normal.set_corner_radius_all(16)
	normal.set_border_width_all(2)
	normal.border_color = _c_border()
	normal.set_content_margin_all(16)
	normal.shadow_color = Color(0, 0, 0, 0.10)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	hover.border_color = accent
	hover.border_width_left = 3
	hover.border_width_right = 3
	hover.border_width_top = 3
	hover.border_width_bottom = 3
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 1.0)
	pressed.border_color = accent
	pressed.set_border_width_all(3)
	pressed.shadow_size = 8
	b.add_theme_stylebox_override("pressed", pressed)

	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

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
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", _c_text())
	b.add_theme_color_override("font_hover_color", C_PRIMARY)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)

	if opt is Dictionary:
		var path := str(opt.get("image", opt.get("path", "")))
		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				b.icon = tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = _c_surface()
	normal.set_corner_radius_all(16)
	normal.set_border_width_all(2)
	normal.border_color = _c_border()
	normal.set_content_margin_all(14)
	normal.shadow_color = Color(0, 0, 0, 0.10)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.12)
	hover.border_color = C_PRIMARY
	hover.set_border_width_all(3)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 1.0)
	pressed.border_color = C_PRIMARY
	pressed.set_border_width_all(3)
	pressed.shadow_size = 8
	b.add_theme_stylebox_override("pressed", pressed)

	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

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
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", 40)
	le.add_theme_color_override("font_color", _c_text())
	le.add_theme_color_override("font_placeholder_color", _c_text_dim())
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_regular:
		le.add_theme_font_override("font", _font_regular)

	var le_style := StyleBoxFlat.new()
	le_style.bg_color = _c_surface()
	le_style.set_corner_radius_all(16)
	le_style.set_border_width_all(2)
	le_style.border_color = _c_border()
	le_style.set_content_margin_all(18)
	le_style.shadow_color = Color(0, 0, 0, 0.08)
	le_style.shadow_size = 4
	le_style.shadow_offset = Vector2(0, 2)
	le.add_theme_stylebox_override("normal", le_style)

	var le_hover: StyleBoxFlat = le_style.duplicate()
	le_hover.border_color = C_PRIMARY.lightened(0.2)
	le.add_theme_stylebox_override("hover", le_hover)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = C_PRIMARY
	le_focus.shadow_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.20)
	le_focus.shadow_size = 8
	le.add_theme_stylebox_override("focus", le_focus)

	le.add_theme_color_override("caret_color", C_PRIMARY)
	le.add_theme_color_override("selection_color", Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35))
	_register_scroll_control(le)
	return le


func _make_chart_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", 38)
	le.add_theme_color_override("font_color", _c_text())
	le.add_theme_color_override("font_placeholder_color", _c_text_dim())
	le.add_theme_color_override("caret_color", C_PRIMARY)
	le.add_theme_color_override(
		"selection_color",
		Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35)
	)
	le.add_theme_color_override("font_selected_color", Color.WHITE)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_regular:
		le.add_theme_font_override("font", _font_regular)

	var le_style := StyleBoxFlat.new()
	le_style.bg_color = _c_surface()
	le_style.set_corner_radius_all(12)
	le_style.set_border_width_all(2)
	le_style.border_color = _c_border()
	le_style.set_content_margin_all(12)
	le_style.shadow_color = Color(0, 0, 0, 0.08)
	le_style.shadow_size = 3
	le.add_theme_stylebox_override("normal", le_style)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = C_PRIMARY
	le_focus.shadow_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.20)
	le_focus.shadow_size = 7
	le.add_theme_stylebox_override("focus", le_focus)

	_register_scroll_control(le)
	return le


func _make_chip_button(text: String, filled := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = text
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color.WHITE if filled else _c_text())
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	var style := StyleBoxFlat.new()
	style.bg_color = C_PRIMARY if filled else _c_surface()
	style.set_corner_radius_all(40)
	style.set_border_width_all(2)
	style.border_color = C_PRIMARY
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = C_PRIMARY if filled else Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.15)
	hover.shadow_size = 8
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)

	var disabled: StyleBoxFlat = style.duplicate()
	disabled.bg_color = _c_surface_alt()
	disabled.border_color = _c_border()
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", _c_text_dim())

	_register_scroll_control(b)
	return b


# compact = smaller tile for dense grids like word search.
func _make_word_toggle(word: String, compact := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = word
	b.toggle_mode = true
	if compact:
		b.add_theme_font_size_override("font_size", 34)
		b.custom_minimum_size = Vector2(36, 44)
	else:
		b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", _c_text())
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", C_PRIMARY)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(3 if compact else 8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal.duplicate())

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = C_WARNING
	pressed.set_corner_radius_all(8)
	pressed.set_content_margin_all(3 if compact else 8)
	pressed.shadow_color = Color(C_WARNING.r, C_WARNING.g, C_WARNING.b, 0.35)
	pressed.shadow_size = 6
	pressed.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("pressed", pressed)

	_register_scroll_control(b)
	return b


func _make_feedback(parent: Node) -> Label:
	var fb := Label.new()
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.autowrap_mode = TextServer.AUTOWRAP_WORD
	fb.add_theme_font_size_override("font_size", 36)
	fb.visible = false
	if _font_bold:
		fb.add_theme_font_override("font", _font_bold)
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
	
	# 3) Get or create the AudioPanel.
	_audio_panel = _get_or_create_audio_panel()
	if _audio_panel == null:
		return
	
	# 4) Create the Play/Stop toggle button.
	# _make_button() also registers it for tap-vs-drag scrolling.
	_audio_btn = _make_button("Play the Audio", C_PURPLE)
	_audio_btn.pressed.connect(_on_audio_button_pressed)
	_active_vbox.add_child(_audio_btn)
	
	# 5) Connect the panel signals once, so the button label
	# resets when the panel is closed or the track finishes.
	if not _audio_panel.audio_closed.is_connected(_on_audio_panel_closed):
		_audio_panel.audio_closed.connect(_on_audio_panel_closed)
	if not _audio_panel.audio_finished.is_connected(_on_audio_panel_closed):
		_audio_panel.audio_finished.connect(_on_audio_panel_closed)


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
		push_warning("ExerciseEngine: build() was called before the engine entered the tree. Audio button skipped.")
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
	
	# Make it a full-screen overlay.
	if panel is Control:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Start hidden. load_and_play() will show it.
	panel.hide()
	
	# Register it so other engines reuse this instance
	# instead of creating more panels.
	panel.add_to_group("audio_panel")
	
	_audio_panel = panel
	_audio_panel_owned = true
	return _audio_panel


func _on_audio_button_pressed() -> void:
	# Lazy lookup in case the panel was freed or never created.
	if _audio_panel == null or not is_instance_valid(_audio_panel):
		_audio_panel = _get_or_create_audio_panel()
	
	if _audio_panel == null:
		return
	
	if _audio_panel.is_playing():
		# Audio is playing -> stop it and close the panel.
		_audio_panel.stop_and_close()
		_set_audio_button_idle()
	else:
		# Audio is not playing -> open the panel and start playback.
		_audio_panel.load_and_play(_audio_path)
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
	btn.text = text
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.custom_minimum_size = Vector2(0, 72)
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
