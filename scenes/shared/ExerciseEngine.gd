# ============================================================
# ExerciseEngine.gd - Universal Interactive Exercise Renderer
# ============================================================
# Godot 4.7
# Improved version with:
# - ScrollContainer.follow_focus for keyboard handling (simpler)
# - ExerciseItem class for typed items
# - Caching and performance optimizations
# - Centralized theme constants
# - Better error handling
# - Cleaner structure with helper methods
# - All 30+ exercise types implemented
# ============================================================

class_name ExerciseEngine
extends VBoxContainer

signal exercise_checked(exercise_id: String, correct: int, total: int)

# ---------- Theme Constants ----------
const COLORS := {
	"primary": Color("#22D3EE"),
	"success": Color("#34D399"),
	"error": Color("#F87171"),
	"text": Color("#F1F5F9"),
	"muted": Color("#94A3B8"),
	"tint": Color("#1a2f5c"),
	"warning": Color("#FBBF24"),
	"info": Color("#22D3EE"),
	"purple": Color("#A78BFA"),
	"orange": Color("#FB923C"),
}

const FONT_SIZES := {
	"badge": 28,
	"title": 40,
	"body": 36,
	"body_small": 34,
	"hint": 32,
	"tiny": 28,
	"button": 34,
	"input": 36,
	"checkbox": 32,
}

const SPACING := {
	"section": 32,
	"item": 18,
	"tight": 10,
	"loose": 14,
	"button_row": 14,
}

const PADDING := {
	"button": 16,
	"input": 14,
	"badge": 10,
	"panel": 24,
}

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const SAVE_PATH := "user://exercise_saves.json"
const AUDIO_PANEL_SCENE_PATH := "res://scenes/shared/AudioPanel.tscn"

# ---------- Exercise Type Metadata ----------
const TYPE_META := {
	"multiple_choice":          { "badge": "Multiple Choice",         "color": Color("#2563EB") },
	"true_false":               { "badge": "True / False",            "color": Color("#7C3AED") },
	"matching":                 { "badge": "Matching",                "color": Color("#0891B2") },
	"fill_blank":               { "badge": "Fill in the Blank",       "color": Color("#EA580C") },
	"cloze":                    { "badge": "Choose the Best Form",    "color": Color("#DB2777") },
	"ordering":                 { "badge": "Put in Order",            "color": Color("#CA8A04") },
	"categorize":               { "badge": "Categorize",              "color": Color("#059669") },
	"open_ended":               { "badge": "Your Turn",               "color": Color("#64748B") },
	"pronunciation":            { "badge": "Pronunciation",           "color": Color("#64748B") },
	"writing":                  { "badge": "Writing",                 "color": Color("#64748B") },
	"passage":                  { "badge": "Reading",                 "color": Color("#334155") },
	"reading":                  { "badge": "Reading",                 "color": Color("#334155") },
	"word_bank":                { "badge": "Word Bank",               "color": Color("#0D9488") },
	"sentence_ordering":        { "badge": "Unscramble the Sentence", "color": Color("#9333EA") },
	"sentence_unscramble":      { "badge": "Unscramble the Sentence", "color": Color("#9333EA") },
	"letter_scramble":          { "badge": "Unscramble the Word",     "color": Color("#F59E0B") },
	"table_fill":               { "badge": "Complete the Table",      "color": Color("#4338CA") },
	"table_fill_advanced":      { "badge": "Complete the Table",      "color": Color("#4338CA") },
	"text_highlight":           { "badge": "Find & Mark",             "color": Color("#0EA5E9") },
	"text_highlight_multi":     { "badge": "Find & Mark",             "color": Color("#0EA5E9") },
	"transformation":           { "badge": "Rewrite the Sentence",    "color": Color("#BE123C") },
	"error_correction":         { "badge": "Find the Mistake",        "color": Color("#B91C1C") },
	"word_building":            { "badge": "Build the Word",          "color": Color("#65A30D") },
	"word_search":              { "badge": "Word Search",             "color": Color("#7C2D12") },
	"word_find":                { "badge": "Word Search",             "color": Color("#7C2D12") },
	"chart_fill":               { "badge": "Complete the Chart",      "color": Color("#1E40AF") },
	"odd_one_out":              { "badge": "Odd One Out",             "color": Color("#F97316") },
	"grammar_choice":           { "badge": "Grammar Choice",          "color": Color("#06B6D4") },
	"passive_transformation":   { "badge": "Passive Transformation",  "color": Color("#8B5CF6") },
	"grammar_identification":   { "badge": "Grammar Identification",  "color": Color("#EC4899") },
	"question_formation":       { "badge": "Question Formation",      "color": Color("#14B8A6") },
	"token_label":              { "badge": "Label the Sentence",      "color": Color("#7C3AED") },
	"image_choice":             { "badge": "Choose the Picture",      "color": Color("#0284C7") },
	"image_match":              { "badge": "Match Pictures",          "color": Color("#0891B2") },
	"image_hotspot":            { "badge": "Mark the Image",          "color": Color("#B45309") },
}

# ---------- Configuration ----------
var use_internal_scroll := false
var audio_panel_scene_path := AUDIO_PANEL_SCENE_PATH
var audio_panel: Node = null
var audio_types: Array = []
var audio_allow_any_type := false

# ---------- Internal State ----------
var _exercise: Dictionary = {}
var _items: Array[ExerciseItem] = []
var _score_banner: Label = null
var _check_btn: Button = null
var _reveal_btn: Button = null
var _done_btn: Button = null
var _note_label: Label = null
var _is_graded := false
var _is_open_ended := false
var _is_non_interactive := false
var _font_regular: FontFile
var _font_bold: FontFile
var _active_vbox: VBoxContainer
var _scroll: ScrollContainer = null
var _target: Control = null
var _audio_btn: Button = null
var _audio_path := ""
var _audio_panel: Node = null
var _audio_panel_owned := false

# Gesture state
var _drag_source: Control = null
var _drag_active := false
var _press_pos := Vector2.ZERO
var _press_time_msec := 0
var _hold_blocked := false
const DRAG_THRESHOLD := 28.0
const HOLD_MAX_MSEC := 350

# Cached viewport width
var _cached_viewport_width: float = -1.0
var _cached_viewport_width_time: int = 0

# Group counter for exercise letter codes
static var _group_counter := 0

# ---------- Inner Class: ExerciseItem ----------
class ExerciseItem:
	var type: String
	var get_func: Callable      # returns user answer
	var answer: Variant          # expected answer(s)
	var answer_display: String   # for feedback
	var feedback_label: Label    # to show correct/incorrect
	var explanation_en: String
	var explanation_fa: String
	# Additional data for specific types
	var sample_label: Label = null
	var text_edit: TextEdit = null
	var word_button: Button = null
	# For text input types
	var compiled_patterns: Array[RegEx] = []
	var required_words: Array = []
	var forbidden_words: Array = []

	func _init(
		p_type: String,
		p_get: Callable,
		p_answer: Variant,
		p_feedback: Label,
		p_answer_display: String = "",
		p_explanation_en: String = "",
		p_explanation_fa: String = "",
		p_compiled_patterns: Array[RegEx] = [],
		p_required_words: Array = [],
		p_forbidden_words: Array = []
	):
		type = p_type
		get_func = p_get
		answer = p_answer
		feedback_label = p_feedback
		answer_display = p_answer_display
		explanation_en = p_explanation_en
		explanation_fa = p_explanation_fa
		compiled_patterns = p_compiled_patterns
		required_words = p_required_words
		forbidden_words = p_forbidden_words

	func is_correct(user_answer: Variant) -> bool:
		return ExerciseEngine._compare_answer(user_answer, answer, compiled_patterns, required_words, forbidden_words)

# ---------- Lifecycle ----------
func _ready() -> void:
	var regular := load(FONT_REGULAR_PATH)
	if regular is FontFile:
		_font_regular = regular
	var bold := load(FONT_BOLD_PATH)
	if bold is FontFile:
		_font_bold = bold

	add_theme_constant_override("separation", SPACING.item)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_group("exercise_engines")
	_ensure_layout_target()

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if _drag_source == null or _drag_active or _hold_blocked:
		return
	if not is_instance_valid(_drag_source):
		_drag_source = null
		return
	if Time.get_ticks_msec() - _press_time_msec > HOLD_MAX_MSEC:
		_hold_blocked = true
		_drag_source.set_block_signals(true)
		var vp := get_viewport()
		if vp != null:
			var focused := vp.gui_get_focus_owner()
			if focused != null and _is_editable_control(focused):
				focused.release_focus()
		if _is_editable_control(_drag_source):
			_drag_source.release_focus()
		_hide_virtual_keyboard()

func _exit_tree() -> void:
	if _audio_panel != null and is_instance_valid(_audio_panel):
		if _audio_panel.is_playing():
			_audio_panel.stop_and_close()
		if _audio_panel_owned:
			_audio_panel.queue_free()

# ---------- Layout Target ----------
func _ensure_layout_target() -> void:
	if _target != null:
		return
	if not use_internal_scroll:
		_target = self
		return
	_scroll = ScrollContainer.new()
	_scroll.name = "ExerciseScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true   # Auto-scroll focused input above keyboard
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_target = VBoxContainer.new()
	_target.name = "ExerciseContent"
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target.add_theme_constant_override("separation", SPACING.item)
	_scroll.add_child(_target)

func _get_scroll_target() -> ScrollContainer:
	if _scroll != null:
		return _scroll
	var n := get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null

# ---------- Viewport Caching ----------
func _get_viewport_width() -> float:
	var now := Time.get_ticks_msec()
	if _cached_viewport_width > 0 and now - _cached_viewport_width_time < 100:
		return _cached_viewport_width
	var vp := get_viewport()
	if vp != null:
		var w := vp.get_visible_rect().size.x
		if w > 0.0:
			_cached_viewport_width = w
			_cached_viewport_width_time = now
			return w
	return 1280.0

func _safe_media_width(requested: int) -> int:
	var max_allowed := int(_get_viewport_width()) - 80
	return clampi(requested, 120, maxi(max_allowed, 160))

# ---------- Gesture Handling ----------
func _register_scroll_control(ctrl: Control) -> void:
	if _is_editable_control(ctrl):
		ctrl.focus_mode = Control.FOCUS_NONE
		ctrl.focus_exited.connect(_on_editable_focus_exited.bind(ctrl))
	ctrl.gui_input.connect(_on_scroll_child_gui_input.bind(ctrl))

func _is_editable_control(ctrl: Control) -> bool:
	return ctrl is LineEdit or ctrl is TextEdit

func _on_editable_focus_exited(ctrl: Control) -> void:
	if is_instance_valid(ctrl):
		ctrl.focus_mode = Control.FOCUS_NONE
	if is_inside_tree():
		call_deferred("_hide_virtual_keyboard")

func _on_scroll_child_gui_input(event: InputEvent, source: Control) -> void:
	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and _drag_source == source:
		var drag_pos := Vector2.ZERO
		if event is InputEventMouseMotion:
			drag_pos = event.global_position
		elif event is InputEventScreenDrag:
			drag_pos = event.position
		var move_distance := (drag_pos - _press_pos).length()
		if not _drag_active and not _hold_blocked and move_distance > DRAG_THRESHOLD:
			_drag_active = true
			if is_instance_valid(source):
				source.set_block_signals(true)
			if _is_editable_control(source):
				source.release_focus()
			else:
				var vp := get_viewport()
				if vp != null:
					var focused := vp.gui_get_focus_owner()
					if focused != null and _is_editable_control(focused):
						focused.release_focus()
			_hide_virtual_keyboard()
		return

	var is_press := false
	var is_release := false
	var press_pos := Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
		press_pos = event.global_position
	elif event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
		press_pos = event.position

	if is_press:
		if _drag_source != null and is_instance_valid(_drag_source):
			_drag_source.call_deferred("set_block_signals", false)
		_drag_source = source
		_drag_active = false
		_hold_blocked = false
		_press_pos = press_pos
		_press_time_msec = Time.get_ticks_msec()
		if _is_editable_control(source):
			if source.has_focus():
				source.focus_mode = Control.FOCUS_ALL
			else:
				source.focus_mode = Control.FOCUS_NONE
	elif is_release:
		if source != null and is_instance_valid(source) and _drag_source == source:
			if _drag_active or _hold_blocked:
				source.call_deferred("set_block_signals", false)
			elif _is_editable_control(source):
				var duration := Time.get_ticks_msec() - _press_time_msec
				if duration <= HOLD_MAX_MSEC:
					_confirm_editable_tap(source)
		_drag_active = false
		_hold_blocked = false
		_drag_source = null

func _confirm_editable_tap(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.focus_mode = Control.FOCUS_ALL
	ctrl.grab_focus()
	if OS.get_name() in ["Android", "iOS"] and DisplayServer.has_method("virtual_keyboard_show"):
		var text := ""
		if ctrl is LineEdit:
			text = ctrl.text
		elif ctrl is TextEdit:
			text = ctrl.text
		DisplayServer.virtual_keyboard_show(text)

func _hide_virtual_keyboard() -> void:
	if OS.get_name() in ["Android", "iOS"] and DisplayServer.has_method("virtual_keyboard_hide"):
		DisplayServer.virtual_keyboard_hide()

# ---------- Persistence ----------
func _load_all_saves() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data
	return {}

func _write_saves(saves: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saves))

func _save_open_ended_answers() -> void:
	var ex_id := str(_exercise.get("exercise_id", ""))
	if ex_id == "":
		return
	var saves := _load_all_saves()
	if not saves.has(ex_id):
		saves[ex_id] = {}
	for i in _items.size():
		var item := _items[i]
		if item.text_edit != null and is_instance_valid(item.text_edit):
			saves[ex_id][str(i)] = item.text_edit.text
	_write_saves(saves)

func _load_open_ended_answers() -> void:
	var ex_id := str(_exercise.get("exercise_id", ""))
	if ex_id == "":
		return
	var saves := _load_all_saves()
	if not saves.has(ex_id):
		return
	var ex_saves: Dictionary = saves[ex_id]
	for i in _items.size():
		var item := _items[i]
		if item.text_edit != null and is_instance_valid(item.text_edit):
			var key := str(i)
			if ex_saves.has(key):
				item.text_edit.text = str(ex_saves[key])

# ---------- Main Build Entry ----------
func build(exercise: Dictionary, increment_group := true) -> void:
	_exercise = exercise
	_items.clear()
	_is_graded = false
	_note_label = null
	_score_banner = null
	_check_btn = null
	_reveal_btn = null
	_done_btn = null
	_audio_btn = null
	_audio_path = ""
	_drag_source = null
	_drag_active = false

	var type := str(exercise.get("type", "open_ended"))
	_is_open_ended = type in ["open_ended", "pronunciation", "writing"]
	_is_non_interactive = type in ["passage", "reading"]

	_ensure_layout_target()
	for child in _target.get_children():
		_target.remove_child(child)
		child.queue_free()

	_add_badge()
	_create_master_panel()

	if type not in ["cloze", "text_highlight", "text_highlight_multi"]:
		_add_common_passage()
	_add_instruction()

	if type != "image_hotspot":
		_add_images()
	_add_audio_button()

	match type:
		"multiple_choice":          _build_multiple_choice()
		"true_false":               _build_true_false()
		"matching":                 _build_matching()
		"fill_blank":               _build_fill_blank()
		"cloze":                    _build_cloze()
		"ordering":                 _build_ordering()
		"categorize":               _build_categorize()
		"open_ended", "pronunciation", "writing": _build_open_ended()
		"passage", "reading":       pass
		"word_bank":                _build_word_bank()
		"sentence_ordering", "sentence_unscramble": _build_sentence_ordering()
		"letter_scramble":          _build_letter_scramble()
		"table_fill":               _build_table_fill()
		"table_fill_advanced":      _build_table_fill_advanced()
		"text_highlight":           _build_text_highlight()
		"text_highlight_multi":     _build_text_highlight_multi()
		"transformation":           _build_transformation()
		"error_correction":         _build_error_correction()
		"word_building":            _build_word_building()
		"word_search", "word_find": _build_word_search()
		"chart_fill":               _build_chart_fill()
		"odd_one_out":              _build_odd_one_out()
		"grammar_choice":           _build_grammar_choice()
		"passive_transformation":   _build_passive_transformation()
		"grammar_identification":   _build_grammar_identification()
		"question_formation":       _build_question_formation()
		"token_label":              _build_token_label()
		"image_choice":             _build_image_choice()
		"image_match":              _build_image_match()
		"image_hotspot":            _build_image_hotspot()
		_:                          _build_open_ended()

	_add_note()
	_add_footer_buttons()

	if _scroll != null:
		_scroll.scroll_vertical = 0

	if increment_group:
		_group_counter += 1

# ---------- Build Helpers ----------
func _get_en_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("en", ""))
	return str(val)

func _get_fa_text(val: Variant) -> String:
	if val is Dictionary:
		return str(val.get("fa", ""))
	return ""

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

func _join_string_array(arr: Array, sep: String) -> String:
	var out := ""
	for i in arr.size():
		out += str(arr[i])
		if i < arr.size() - 1:
			out += sep
	return out

static func _normalize(s: String) -> String:
	s = str(s).to_lower().strip_edges()
	s = s.replace(char(0x2019), "'").replace("'", "")
	for ch in [".", ",", "!", "?", ";", ":", "\"", "(", ")", "[", "]", "{", "}", "/"]:
		s = s.replace(ch, " ")
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s.strip_edges()

func _format_answer(answer: Variant) -> String:
	if answer is Array:
		var parts: Array = []
		for a in answer:
			parts.append(_format_answer(a))
		return _join_string_array(parts, " / ")
	if answer is bool:
		return "True" if answer else "False"
	if answer is Dictionary:
		return _get_en_text(answer)
	if answer == null:
		return ""
	return str(answer)

# ---------- Common UI Blocks ----------
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
	badge.text = str(meta["badge"])
	badge.add_theme_font_size_override("font_size", FONT_SIZES.badge)
	badge.add_theme_color_override("font_color", Color.WHITE)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = accent
	badge_style.set_corner_radius_all(20)
	badge_style.set_content_margin_all(PADDING.badge)
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
	style.bg_color = COLORS.tint
	style.set_corner_radius_all(16)

	var type := str(_exercise.get("type", "open_ended"))
	var meta: Dictionary = TYPE_META.get(type, TYPE_META["open_ended"])
	style.border_width_left = 8
	style.border_color = meta["color"]
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.set_content_margin_all(PADDING.panel)

	panel.add_theme_stylebox_override("panel", style)

	_active_vbox = VBoxContainer.new()
	_active_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_vbox.add_theme_constant_override("separation", SPACING.section)
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
		var title_label := _make_label(title, FONT_SIZES.title, COLORS.primary, true)
		_active_vbox.add_child(title_label)

	var rtl := RichTextLabel.new()
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(0, 120)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", FONT_SIZES.body)
	rtl.add_theme_color_override("default_color", COLORS.text)
	if _font_regular:
		rtl.add_theme_font_override("normal_font", _font_regular)
	rtl.text = text
	if passage_raw is Dictionary:
		rtl.set_meta("text_fa", _get_fa_text(passage_raw))
	_active_vbox.add_child(rtl)

func _add_instruction() -> void:
	var text_raw = _exercise.get("instruction", "")
	var text_val := _get_en_text(text_raw)
	if text_val == "":
		return
	var show_letter := bool(_exercise.get("show_letter", true))
	var final_text := text_val
	if show_letter:
		var letter_code := char(65 + (_group_counter % 26))
		final_text = letter_code + ". " + text_val

	var instruction := Label.new()
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction.text = final_text
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	instruction.add_theme_font_size_override("font_size", FONT_SIZES.title)
	instruction.add_theme_color_override("font_color", COLORS.text)
	instruction.set_meta("text_fa", _get_fa_text(text_raw))
	if _font_bold:
		instruction.add_theme_font_override("font", _font_bold)
	_active_vbox.add_child(instruction)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style := StyleBoxLine.new()
	sep_style.color = COLORS.muted.lightened(0.7)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	_active_vbox.add_child(sep)

func _add_note() -> void:
	var note_raw = _exercise.get("note", "")
	var note := _get_en_text(note_raw)
	if note == "":
		return
	_note_label = _make_label("Info: " + note, FONT_SIZES.hint, COLORS.muted, false)
	_note_label.set_meta("text_fa", _get_fa_text(note_raw))
	_note_label.visible = false
	if _is_open_ended or _is_non_interactive:
		_note_label.visible = true
	_active_vbox.add_child(_note_label)

func _add_images() -> void:
	var images: Array = _exercise.get("images", [])
	if images.is_empty():
		var single_img = _exercise.get("image", "")
		if single_img != "":
			images = [single_img]
	for img_data in images:
		_active_vbox.add_child(_make_media_control(img_data))

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

	max_width = _safe_media_width(max_width)

	if path == "":
		var ph := _make_label("Image placeholder", FONT_SIZES.tiny, COLORS.muted, false)
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
				var cap := _make_label(caption, FONT_SIZES.tiny, COLORS.muted, false)
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(cap)
			return vbox

	var missing := _make_label("Image not found: " + path.get_file(), FONT_SIZES.tiny, COLORS.muted, false)
	vbox.add_child(missing)
	return vbox

# ---------- Footer Buttons ----------
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
		_score_banner.add_theme_font_size_override("font_size", FONT_SIZES.body)
		_score_banner.visible = false
		if _font_bold:
			_score_banner.add_theme_font_override("font", _font_bold)
		_target.add_child(_score_banner)

	var btn_row := HBoxContainer.new()
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_theme_constant_override("separation", SPACING.button_row)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _is_open_ended:
		if has_sample:
			_reveal_btn = _make_button("Show Sample Answer", COLORS.orange)
			_reveal_btn.pressed.connect(_on_reveal_sample)
			btn_row.add_child(_reveal_btn)
		_done_btn = _make_button("Save", COLORS.success)
		_done_btn.pressed.connect(_on_open_ended_done)
		btn_row.add_child(_done_btn)
	elif graded_count > 0:
		_check_btn = _make_button("Check Answer", COLORS.primary)
		_check_btn.pressed.connect(_on_check_pressed)
		btn_row.add_child(_check_btn)

	if btn_row.get_child_count() > 0:
		_target.add_child(btn_row)

func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.text = text
	btn.add_theme_font_size_override("font_size", FONT_SIZES.button)
	btn.add_theme_color_override("font_color", Color.WHITE)
	_set_button_color(btn, color)
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	_register_scroll_control(btn)
	return btn

func _set_button_color(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(PADDING.button)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

# ---------- Widget Factories ----------
func _make_label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 0
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold and _font_bold:
		l.add_theme_font_override("font", _font_bold)
	elif not bold and _font_regular:
		l.add_theme_font_override("font", _font_regular)
	return l

func _make_option_button(text: String, group: ButtonGroup) -> Button:
	return _make_select_button(text, group, COLORS.primary)

func _make_select_button(text: String, group: ButtonGroup, accent: Color) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = "    " + text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 0)
	b.add_theme_font_size_override("font_size", FONT_SIZES.body)
	b.add_theme_color_override("font_color", COLORS.text)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#0f1b3d")
	normal.set_corner_radius_all(10)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#3d4a7a")
	normal.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	hover.border_color = accent.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	pressed.border_color = accent
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
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
	b.custom_minimum_size = Vector2(190, 160)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = _get_option_text(opt)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", FONT_SIZES.hint)
	b.add_theme_color_override("font_color", COLORS.text)
	b.add_theme_color_override("font_hover_color", COLORS.primary)
	b.add_theme_color_override("font_pressed_color", COLORS.primary)

	if opt is Dictionary:
		var path := str(opt.get("image", opt.get("path", "")))
		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				b.icon = tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#0f1b3d")
	normal.set_corner_radius_all(12)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#3d4a7a")
	normal.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.07)
	hover.border_color = COLORS.primary.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.14)
	pressed.border_color = COLORS.primary
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pressed)

	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	_register_scroll_control(b)
	return b

func _make_option_dropdown(options: Array, placeholder := "Choose") -> Dropdown:
	var dd := Dropdown.new()
	dd.mouse_filter = Control.MOUSE_FILTER_PASS
	dd.placeholder = placeholder
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
	le.add_theme_font_size_override("font_size", FONT_SIZES.input)
	le.add_theme_color_override("font_color", COLORS.text)
	le.add_theme_color_override("font_placeholder_color", COLORS.muted)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_regular:
		le.add_theme_font_override("font", _font_regular)

	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color("#0f1b3d")
	le_style.set_corner_radius_all(10)
	le_style.border_width_bottom = 2
	le_style.border_color = COLORS.primary.lightened(0.3)
	le_style.set_content_margin_all(PADDING.input)
	le.add_theme_stylebox_override("normal", le_style)

	var le_hover: StyleBoxFlat = le_style.duplicate()
	le_hover.border_color = COLORS.primary
	le.add_theme_stylebox_override("hover", le_hover)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = COLORS.primary
	le.add_theme_stylebox_override("focus", le_focus)

	le.add_theme_color_override("caret_color", COLORS.primary)
	_register_scroll_control(le)
	return le

func _make_chart_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", FONT_SIZES.body_small)
	le.add_theme_color_override("font_color", COLORS.text)
	le.add_theme_color_override("font_placeholder_color", COLORS.muted)
	le.add_theme_color_override("caret_color", COLORS.primary)
	le.add_theme_color_override(
		"selection_color",
		Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.35)
	)
	le.add_theme_color_override("font_selected_color", Color.WHITE)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_regular:
		le.add_theme_font_override("font", _font_regular)

	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color("#0f1b3d")
	le_style.set_corner_radius_all(8)
	le_style.border_width_bottom = 2
	le_style.border_color = Color("#3d4a7a")
	le_style.set_content_margin_all(10)
	le.add_theme_stylebox_override("normal", le_style)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = COLORS.primary
	le.add_theme_stylebox_override("focus", le_focus)

	_register_scroll_control(le)
	return le

func _make_chip_button(text: String, filled := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = text
	b.add_theme_font_size_override("font_size", FONT_SIZES.body_small)
	b.add_theme_color_override("font_color", Color("#000000") if filled else COLORS.text)
	b.add_theme_color_override("font_hover_color", Color("#000000") if filled else COLORS.primary)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	var style := StyleBoxFlat.new()
	style.bg_color = COLORS.primary if filled else Color("#0f1b3d")
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = COLORS.primary if filled else Color("#3d4a7a")
	style.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)

	var disabled: StyleBoxFlat = style.duplicate()
	disabled.bg_color = Color("#1a2540")
	disabled.border_color = Color("#2d3a6a")
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color("#4a5580"))

	_register_scroll_control(b)
	return b

func _make_word_toggle(word: String, compact := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = word
	b.toggle_mode = true
	if compact:
		b.add_theme_font_size_override("font_size", FONT_SIZES.hint)
		b.custom_minimum_size = Vector2(36, 44)
	else:
		b.add_theme_font_size_override("font_size", FONT_SIZES.body)
	b.add_theme_color_override("font_color", COLORS.text)
	b.add_theme_color_override("font_pressed_color", Color("#000000"))
	b.add_theme_color_override("font_hover_color", COLORS.primary)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(3 if compact else 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal.duplicate())

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLORS.warning
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(3 if compact else 6)
	b.add_theme_stylebox_override("pressed", pressed)

	_register_scroll_control(b)
	return b

func _make_feedback(parent: Node) -> Label:
	var fb := Label.new()
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.autowrap_mode = TextServer.AUTOWRAP_WORD
	fb.add_theme_font_size_override("font_size", FONT_SIZES.hint)
	fb.visible = false
	if _font_bold:
		fb.add_theme_font_override("font", _font_bold)
	parent.add_child(fb)
	return fb

# ---------- Audio ----------
func _add_audio_button() -> void:
	var type := str(_exercise.get("type", "open_ended"))
	if not _should_show_audio_button(type):
		return
	_audio_path = _get_audio_path()
	if _audio_path == "":
		return
	_audio_panel = _get_or_create_audio_panel()
	if _audio_panel == null:
		return

	_audio_btn = _make_button("Play the Audio", COLORS.purple)
	_audio_btn.pressed.connect(_on_audio_button_pressed)
	_active_vbox.add_child(_audio_btn)

	if not _audio_panel.audio_closed.is_connected(_on_audio_panel_closed):
		_audio_panel.audio_closed.connect(_on_audio_panel_closed)
	if not _audio_panel.audio_finished.is_connected(_on_audio_panel_closed):
		_audio_panel.audio_finished.connect(_on_audio_panel_closed)

func _should_show_audio_button(type: String) -> bool:
	if _exercise.has("show_audio"):
		return bool(_exercise.get("show_audio"))
	if audio_allow_any_type:
		return true
	return audio_types.has(type)

func _get_audio_path() -> String:
	var raw: Variant = _exercise.get("audio", "")
	if raw is Dictionary:
		return str(raw.get("path", ""))
	return str(raw)

func _get_or_create_audio_panel() -> Node:
	if _audio_panel != null and is_instance_valid(_audio_panel):
		return _audio_panel
	if audio_panel != null and is_instance_valid(audio_panel):
		_audio_panel = audio_panel
		return _audio_panel
	if is_inside_tree():
		var found := get_tree().get_first_node_in_group("audio_panel")
		if found != null:
			_audio_panel = found
			return _audio_panel

	if not is_inside_tree():
		push_warning("ExerciseEngine: build() before entering tree, audio skipped.")
		return null
	if not ResourceLoader.exists(audio_panel_scene_path):
		push_warning("ExerciseEngine: AudioPanel scene not found: ", audio_panel_scene_path)
		return null

	var scene := load(audio_panel_scene_path) as PackedScene
	if scene == null:
		return null
	var panel: Node = scene.instantiate()
	get_tree().root.add_child(panel)
	if panel is Control:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.hide()
	panel.add_to_group("audio_panel")
	_audio_panel = panel
	_audio_panel_owned = true
	return _audio_panel

func _on_audio_button_pressed() -> void:
	if _audio_panel == null or not is_instance_valid(_audio_panel):
		_audio_panel = _get_or_create_audio_panel()
	if _audio_panel == null:
		return
	if _audio_panel.is_playing():
		_audio_panel.stop_and_close()
		_set_audio_button_idle()
	else:
		_audio_panel.load_and_play(_audio_path)
		_set_audio_button_playing()

func _set_audio_button_playing() -> void:
	if _audio_btn != null and is_instance_valid(_audio_btn):
		_audio_btn.text = "Stop the Audio"
		_set_button_color(_audio_btn, COLORS.error)

func _set_audio_button_idle() -> void:
	if _audio_btn != null and is_instance_valid(_audio_btn):
		_audio_btn.text = "Play the Audio"
		_set_button_color(_audio_btn, COLORS.purple)

func _on_audio_panel_closed() -> void:
	_set_audio_button_idle()

# ---------- Grading ----------
func _on_check_pressed() -> void:
	if _is_graded:
		_reset_for_retry()
		return
	if str(_exercise.get("type", "")) in ["word_search", "word_find"]:
		_grade_word_search()
		return

	var correct := 0
	var total := 0
	for item in _items:
		if item.get_func == null:
			continue
		total += 1
		var user_answer = item.get_func.call()
		var is_correct := item.is_correct(user_answer)
		var fb: Label = item.feedback_label
		if fb == null:
			continue
		fb.visible = true

		var answer_text: String = str(item.answer_display if item.answer_display != "" else _format_answer(item.answer))
		var item_type := str(item.type)

		var user_str := str(user_answer).strip_edges()
		if user_str == "" and item_type in ["fill_blank", "chart_fill", "transformation", "letter_scramble", "error_correction", "passive_transformation", "question_formation"]:
			fb.text = "Empty"
			fb.add_theme_color_override("font_color", COLORS.warning)
			continue

		if is_correct:
			correct += 1
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✓"
			else:
				fb.text = "Correct!"
			fb.add_theme_color_override("font_color", COLORS.success)
		else:
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✗"
			else:
				fb.text = "Correct answer: " + answer_text
				if item.explanation_en != "":
					fb.text += "\n" + item.explanation_en
			fb.add_theme_color_override("font_color", COLORS.error)

	_is_graded = true

	if _score_banner:
		_score_banner.visible = true
		if total > 0 and correct == total:
			_score_banner.text = "Excellent! %d/%d correct!" % [correct, total]
			_score_banner.add_theme_color_override("font_color", COLORS.success)
		else:
			_score_banner.text = "You got %d/%d." % [correct, total]
			_score_banner.add_theme_color_override("font_color", COLORS.primary)

	if _note_label:
		_note_label.visible = true

	if _check_btn:
		_check_btn.text = "Try Again"

	exercise_checked.emit(str(_exercise.get("exercise_id", "")), correct, total)

# Static method used by ExerciseItem
static func _compare_answer(user_answer: Variant, correct_answer: Variant, patterns: Array[RegEx] = [], required: Array = [], forbidden: Array = []) -> bool:
	if user_answer == null:
		return false
	if correct_answer == null:
		return false

	if correct_answer is Array and correct_answer.is_empty():
		return str(user_answer).strip_edges() != ""

	if _compare_single(user_answer, correct_answer):
		return true

	var user_str := str(user_answer)
	var norm := _normalize(user_str)

	for rx in patterns:
		if rx.search(user_str):
			return true

	if not required.is_empty():
		var req_ok := true
		for w in required:
			if not norm.contains(_normalize(str(w))):
				req_ok = false
				break
		if req_ok:
			for w in forbidden:
				if norm.contains(_normalize(str(w))):
					req_ok = false
					break
		if req_ok:
			return true

	return false

static func _compare_single(user_answer: Variant, correct_answer: Variant) -> bool:
	if correct_answer is Array:
		if user_answer is Array:
			if user_answer.size() != correct_answer.size():
				return false
			for i in user_answer.size():
				if not _compare_single(user_answer[i], correct_answer[i]):
					return false
			return true
		var normalized := _normalize(str(user_answer))
		for accepted in correct_answer:
			if _normalize(str(accepted)) == normalized:
				return true
		return false
	if user_answer is Array:
		return false
	if correct_answer is bool:
		if user_answer is bool:
			return user_answer == correct_answer
		var s := _normalize(str(user_answer))
		if s in ["true", "t", "yes", "y"]:
			return correct_answer == true
		if s in ["false", "f", "no", "n"]:
			return correct_answer == false
		return false
	if correct_answer is int and user_answer is String and user_answer.is_valid_int():
		return int(user_answer) == int(correct_answer)
	if user_answer is String and correct_answer is String:
		return _normalize(user_answer) == _normalize(correct_answer)
	return user_answer == correct_answer

func _reset_for_retry() -> void:
	_is_graded = false
	if _score_banner:
		_score_banner.visible = false
	if _check_btn:
		_check_btn.text = "Check Answer"
	build(_exercise, false)

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
			_set_button_color(_reveal_btn, COLORS.muted)
		else:
			_reveal_btn.text = "Show Sample Answer"
			_set_button_color(_reveal_btn, COLORS.orange)

func _on_open_ended_done() -> void:
	_save_open_ended_answers()
	if _note_label:
		_note_label.visible = true
	if _done_btn:
		_done_btn.text = "Saved"
		_set_button_color(_done_btn, COLORS.muted)
	exercise_checked.emit(str(_exercise.get("exercise_id", "")), 1, 1)

func _on_open_ended_text_changed() -> void:
	if _done_btn != null and _done_btn.text == "Saved":
		_done_btn.text = "Save"
		_set_button_color(_done_btn, COLORS.success)

# ---------- Container Helper ----------
func _create_item_container() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", SPACING.tight)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(vbox)
	return vbox

# ============================================================
# EXERCISE TYPE BUILDERS
# ============================================================

# ---------- Multiple Choice ----------
func _build_multiple_choice() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var q_label := _make_label(_get_item_main_text(item), FONT_SIZES.title, COLORS.text, true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var options: Array = item.get("options", [])
		for opt in options:
			var b := _make_option_button(_get_option_text(opt), group)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)

		var answer_display := ""
		if answer is int and answer >= 0 and answer < options.size():
			answer_display = _get_option_text(options[answer])

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"multiple_choice",
			func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			answer,
			fb,
			answer_display,
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- True / False ----------
func _build_true_false() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var statement := _make_label(_get_item_main_text(item), FONT_SIZES.body, COLORS.text, false)
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
		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"true_false",
			func():
				if t_btn.button_pressed:
					return true
				if f_btn.button_pressed:
					return false
				return null,
			ans,
			fb,
			"",
			_get_en_text(corr_raw),
			_get_fa_text(corr_raw)
		)
		_items.append(item_data)

# ---------- Matching ----------
func _build_matching() -> void:
	var exercise_options: Array = _exercise.get("options", [])
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), FONT_SIZES.body_small, COLORS.text, false)
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

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"matching",
			func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			answer,
			fb,
			""
		)
		_items.append(item_data)

# ---------- Fill in the Blank ----------
func _build_fill_blank() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), FONT_SIZES.body_small, COLORS.text, false)
		item_vbox.add_child(text)

		var hint := _get_en_text(item.get("hint", ""))
		if hint != "":
			item_vbox.add_child(_make_label("Hint: " + hint, FONT_SIZES.hint, COLORS.muted, false))

		var le := _make_line_edit("Type your answer...")
		item_vbox.add_child(le)

		var fb := _make_feedback(item_vbox)
		# Precompile patterns
		var compiled: Array[RegEx] = []
		for pat in item.get("answer_patterns", []):
			var rx := RegEx.new()
			if rx.compile(str(pat)) == OK:
				compiled.append(rx)

		var item_data := ExerciseItem.new(
			"fill_blank",
			func(): return le.text,
			item.get("answer", []),
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", "")),
			compiled,
			item.get("required_words", []),
			item.get("forbidden_words", [])
		)
		_items.append(item_data)

# ---------- Cloze ----------
func _build_cloze() -> void:
	var p_raw = _exercise.get("passage", "")
	var passage := _make_label(_get_en_text(p_raw), FONT_SIZES.body_small, COLORS.muted, false)
	passage.set_meta("text_fa", _get_fa_text(p_raw))
	_active_vbox.add_child(passage)

	for i in _exercise.get("blanks", []).size():
		var blank: Dictionary = _exercise["blanks"][i]
		var item_vbox := _create_item_container()

		var label := _make_label("(%d) ______" % (i + 1), FONT_SIZES.body_small, COLORS.text, true)
		item_vbox.add_child(label)

		var options: Array = blank.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var ob := _make_option_dropdown(option_texts)
		item_vbox.add_child(ob)

		var answer: Variant = blank.get("answer", "")
		if answer is int and answer >= 0 and answer < option_texts.size():
			answer = option_texts[answer]
		elif answer is String:
			for opt in options:
				if opt is Dictionary and str(opt.get("id", "")) == str(answer):
					answer = _get_option_text(opt)
					break

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"cloze",
			func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			answer,
			fb,
			"",
			_get_en_text(blank.get("explanation", "")),
			_get_fa_text(blank.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- Ordering ----------
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
	container.add_theme_constant_override("separation", SPACING.tight)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(container)

	var list_vbox := VBoxContainer.new()
	list_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_vbox.add_theme_constant_override("separation", 10)
	container.add_child(list_vbox)

	var fb := _make_feedback(container)
	_rebuild_ordering_list(list_vbox, current_order, item_texts)

	var ordered_texts: Array = []
	for idx in answer_order:
		var i := int(idx)
		if i >= 0 and i < item_texts.size():
			ordered_texts.append(str(item_texts[i]))

	var item_data := ExerciseItem.new(
		"ordering",
		func(): return current_order.duplicate(),
		answer_order.duplicate(),
		fb,
		_join_string_array(ordered_texts, " → ")
	)
	_items.append(item_data)

func _rebuild_ordering_list(list_vbox: VBoxContainer, current_order: Array, item_texts: Array) -> void:
	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	for pos in current_order.size():
		var idx := int(current_order[pos])
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_vbox.add_child(row)

		var num := _make_label("%d." % (pos + 1), FONT_SIZES.body_small, COLORS.muted, true)
		num.custom_minimum_size.x = 60
		row.add_child(num)

		var txt := _make_label(str(item_texts[idx]), FONT_SIZES.body, COLORS.text, false)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)

		var up := _make_button("↑", COLORS.muted)
		up.custom_minimum_size = Vector2(70, 60)
		up.disabled = (pos == 0)
		up.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, -1))
		row.add_child(up)

		var down := _make_button("↓", COLORS.muted)
		down.custom_minimum_size = Vector2(70, 60)
		down.disabled = (pos == current_order.size() - 1)
		down.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, 1))
		row.add_child(down)

func _on_order_move(list_vbox: VBoxContainer, current_order: Array, item_texts: Array, pos: int, delta: int) -> void:
	var new_pos := pos + delta
	if new_pos < 0 or new_pos >= current_order.size():
		return
	var tmp: int = int(current_order[pos])
	current_order[pos] = current_order[new_pos]
	current_order[new_pos] = tmp
	_rebuild_ordering_list(list_vbox, current_order, item_texts)

# ---------- Categorize ----------
func _build_categorize() -> void:
	var categories: Array = _exercise.get("categories", [])
	var category_texts: Array = []
	for cat in categories:
		category_texts.append(_get_option_text(cat))

	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), FONT_SIZES.body_small, COLORS.text, false)
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

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"categorize",
			func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			answer,
			fb
		)
		_items.append(item_data)

# ---------- Open Ended / Pronunciation / Writing ----------
func _build_open_ended() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var q := _get_item_main_text(item)
		if q != "":
			var q_label := _make_label(q, FONT_SIZES.body_small, COLORS.text, false)
			item_vbox.add_child(q_label)

		var te := TextEdit.new()
		te.mouse_filter = Control.MOUSE_FILTER_PASS
		te.placeholder_text = "Write your answer here..."
		te.custom_minimum_size = Vector2(0, 180)
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.add_theme_font_size_override("font_size", FONT_SIZES.input)
		te.add_theme_color_override("font_color", COLORS.text)
		te.add_theme_color_override("font_placeholder_color", COLORS.muted)
		te.add_theme_color_override("caret_color", COLORS.primary)
		te.add_theme_color_override(
			"selection_color",
			Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.35)
		)
		te.add_theme_color_override("font_selected_color", Color.WHITE)
		if _font_regular:
			te.add_theme_font_override("font", _font_regular)

		var te_style := StyleBoxFlat.new()
		te_style.bg_color = Color("#0f1b3d")
		te_style.set_corner_radius_all(10)
		te_style.border_width_bottom = 2
		te_style.border_color = Color("#3d4a7a")
		te_style.set_content_margin_all(PADDING.input)
		te.add_theme_stylebox_override("normal", te_style)

		var te_focus: StyleBoxFlat = te_style.duplicate()
		te_focus.border_color = COLORS.primary
		te.add_theme_stylebox_override("focus", te_focus)

		item_vbox.add_child(te)
		_register_scroll_control(te)
		te.text_changed.connect(_on_open_ended_text_changed)

		var rubric: Array = item.get("rubric", _exercise.get("rubric", []))
		for r in rubric:
			var cb := CheckBox.new()
			cb.mouse_filter = Control.MOUSE_FILTER_PASS
			cb.text = _get_en_text(r)
			cb.add_theme_font_size_override("font_size", FONT_SIZES.checkbox)
			if _font_regular:
				cb.add_theme_font_override("font", _font_regular)
			item_vbox.add_child(cb)
			_register_scroll_control(cb)

		var default_self_check := str(_exercise.get("type", "")) == "pronunciation"
		var self_check := bool(item.get("self_check", _exercise.get("self_check", default_self_check)))
		if self_check:
			var done_check := CheckBox.new()
			done_check.mouse_filter = Control.MOUSE_FILTER_PASS
			done_check.text = "I practiced this aloud / I completed this."
			done_check.add_theme_font_size_override("font_size", FONT_SIZES.checkbox)
			if _font_regular:
				done_check.add_theme_font_override("font", _font_regular)
			item_vbox.add_child(done_check)
			_register_scroll_control(done_check)

		var sample_text := _get_en_text(item.get("sample_answer", ""))
		var sample: Label = null
		if sample_text != "":
			sample = _make_label("Sample answer: " + sample_text, FONT_SIZES.body_small, COLORS.success, false)
			sample.set_meta("text_fa", _get_fa_text(item.get("sample_answer", "")))
			sample.visible = false
			item_vbox.add_child(sample)

		var item_data := ExerciseItem.new(
			"open_ended",
			func(): return te.text,
			null,
			null
		)
		item_data.text_edit = te
		item_data.sample_label = sample
		_items.append(item_data)

	_load_open_ended_answers()

# ---------- Word Bank ----------
func _build_word_bank() -> void:
	var bank: Array = _exercise.get("word_bank", [])
	var bank_texts: Array = []
	for w in bank:
		bank_texts.append(_get_option_text(w))

	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var text := _make_label(_get_item_main_text(item), FONT_SIZES.body_small, COLORS.text, false)
		item_vbox.add_child(text)

		var ob := _make_option_dropdown(bank_texts, "Choose a word")
		item_vbox.add_child(ob)

		var answer: Variant = item.get("answer", "")
		if answer is int and answer >= 0 and answer < bank_texts.size():
			answer = bank_texts[answer]
		elif answer is String:
			for w in bank:
				if w is Dictionary and str(w.get("id", "")) == str(answer):
					answer = _get_option_text(w)
					break

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"word_bank",
			func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			answer,
			fb
		)
		_items.append(item_data)

# ---------- Sentence Ordering / Unscramble ----------
func _build_sentence_ordering() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

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

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"sentence_ordering",
			func():
				var chosen: Array = []
				for idx in order:
					chosen.append(word_texts[idx])
				return _join_words(chosen),
			_join_words(answer_words),
			fb
		)
		_items.append(item_data)

func _join_words(arr: Array) -> String:
	var parts: Array = []
	for a in arr:
		parts.append(str(a))
	return " ".join(parts)

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

# ---------- Letter Scramble ----------
func _build_letter_scramble() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var scrambled: String = str(item.get("scrambled", ""))
		var spaced := ""
		for i in scrambled.length():
			spaced += scrambled[i].to_upper()
			if i < scrambled.length() - 1:
				spaced += "  "
		var label := _make_label(spaced, FONT_SIZES.title, COLORS.primary, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(label)

		var hint_raw = item.get("hint", "")
		if _get_en_text(hint_raw) != "":
			var hint := _make_label("Hint: " + _get_en_text(hint_raw), FONT_SIZES.hint, COLORS.muted, false)
			hint.set_meta("text_fa", _get_fa_text(hint_raw))
			item_vbox.add_child(hint)

		var le := _make_line_edit("Type the word...")
		item_vbox.add_child(le)

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"letter_scramble",
			func(): return le.text,
			item.get("answer", ""),
			fb
		)
		_items.append(item_data)

# ---------- Simple Table Fill ----------
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
		var h := _make_label(_get_en_text(col), FONT_SIZES.body_small, COLORS.muted, true)
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
				var fb := _make_feedback(cell_box)
				var item_data := ExerciseItem.new(
					"fill_blank",
					func(): return le.text,
					cell.get("answer", []),
					fb
				)
				_items.append(item_data)
			else:
				var lbl := _make_label(_get_en_text(cell.get("text", "")), FONT_SIZES.body, COLORS.text, false)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(lbl)

# ---------- Advanced Table Fill ----------
func _build_table_fill_advanced() -> void:
	var columns: Array = _exercise.get("columns", [])
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(columns.size(), 1)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_child(grid)

	for col in columns:
		var h := _make_label(_get_en_text(col), FONT_SIZES.body_small, COLORS.primary, true)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)

	for row in _exercise.get("rows", []):
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
				var plain := _make_label(str(cell), FONT_SIZES.body_small, COLORS.text, false)
				plain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(plain)
				continue

			var ctype := str(cell.get("type", cell.get("editor", "label")))
			match ctype:
				"line", "fill_blank", "text":
					var le := _make_line_edit(str(cell.get("placeholder", "...")))
					cell_box.add_child(le)
					var fb := _make_feedback(cell_box)
					# Precompile patterns
					var compiled: Array[RegEx] = []
					for pat in cell.get("answer_patterns", []):
						var rx := RegEx.new()
						if rx.compile(str(pat)) == OK:
							compiled.append(rx)
					var item_data := ExerciseItem.new(
						"fill_blank",
						func(): return le.text,
						cell.get("answer", []),
						fb,
						"",
						_get_en_text(cell.get("explanation", "")),
						_get_fa_text(cell.get("explanation", "")),
						compiled,
						cell.get("required_words", []),
						cell.get("forbidden_words", [])
					)
					_items.append(item_data)
				"dropdown", "select":
					var options: Array = cell.get("options", [])
					var option_texts: Array = []
					for opt in options:
						option_texts.append(_get_option_text(opt))
					var ob := _make_option_dropdown(option_texts, str(cell.get("placeholder", "Choose")))
					cell_box.add_child(ob)
					var ans: Variant = cell.get("answer", "")
					if ans is int and ans >= 0 and ans < option_texts.size():
						ans = option_texts[ans]
					elif ans is String:
						for opt in options:
							if opt is Dictionary and str(opt.get("id", "")) == str(ans):
								ans = _get_option_text(opt)
								break
					var fb := _make_feedback(cell_box)
					var item_data := ExerciseItem.new(
						"dropdown",
						func():
							if ob.selected > 0:
								return ob.get_item_text(ob.selected)
							return "",
						ans,
						fb,
						"",
						_get_en_text(cell.get("explanation", "")),
						_get_fa_text(cell.get("explanation", ""))
					)
					_items.append(item_data)
				"true_false", "yes_no":
					var group := ButtonGroup.new()
					var yes_text := "Yes" if ctype == "yes_no" else "True"
					var no_text := "No" if ctype == "yes_no" else "False"
					var hbox := HBoxContainer.new()
					hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
					hbox.add_theme_constant_override("separation", 10)
					hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cell_box.add_child(hbox)
					var b_yes := _make_select_button(yes_text, group, COLORS.success)
					var b_no := _make_select_button(no_text, group, COLORS.error)
					hbox.add_child(b_yes)
					hbox.add_child(b_no)
					var ans_tf: Variant = cell.get("answer", true)
					if ans_tf is String:
						var s := _normalize(str(ans_tf))
						ans_tf = (s == "yes" or s == "true" or s == "y" or s == "t")
					var fb := _make_feedback(cell_box)
					var item_data := ExerciseItem.new(
						ctype,
						func():
							if b_yes.button_pressed:
								return true
							if b_no.button_pressed:
								return false
							return null,
						ans_tf,
						fb,
						"",
						_get_en_text(cell.get("explanation", "")),
						_get_fa_text(cell.get("explanation", ""))
					)
					_items.append(item_data)
				"checkbox", "check":
					var cb := CheckBox.new()
					cb.mouse_filter = Control.MOUSE_FILTER_PASS
					cb.text = _get_en_text(cell.get("text", ""))
					cb.add_theme_font_size_override("font_size", FONT_SIZES.checkbox)
					if _font_regular:
						cb.add_theme_font_override("font", _font_regular)
					cell_box.add_child(cb)
					_register_scroll_control(cb)
					var fb := _make_feedback(cell_box)
					var item_data := ExerciseItem.new(
						"checkbox",
						func(): return cb.button_pressed,
						bool(cell.get("answer", false)),
						fb,
						"",
						_get_en_text(cell.get("explanation", "")),
						_get_fa_text(cell.get("explanation", ""))
					)
					_items.append(item_data)
				_:
					var lbl := _make_label(_get_en_text(cell.get("text", "")), FONT_SIZES.body_small, COLORS.text, false)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cell_box.add_child(lbl)

# ---------- Text Highlight ----------
func _build_text_highlight() -> void:
	var p_raw = _exercise.get("passage", "")
	var passage_text := _get_en_text(p_raw)
	var words: PackedStringArray = passage_text.split(" ", false)
	var answer_indices: Array = _exercise.get("answer_indices", [])

	var hint := _make_label("Tap the words that match the instruction above.", FONT_SIZES.hint, COLORS.muted, false)
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
		fb.add_theme_font_size_override("font_size", FONT_SIZES.tiny)
		fb.visible = false
		pair.add_child(fb)

		var is_target: bool = answer_indices.has(i)
		var item_data := ExerciseItem.new(
			"text_highlight",
			func(): return wb.button_pressed,
			is_target,
			fb
		)
		_items.append(item_data)

# ---------- Multi-Text Highlight ----------
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
		var chip := _make_label(str(c["label"]), FONT_SIZES.tiny, c["color"], true)
		legend.add_child(chip)

	var hint := _make_label("Tap a word to change its label. Tap again to cycle.", FONT_SIZES.hint, COLORS.muted, false)
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
		wb.add_theme_font_size_override("font_size", FONT_SIZES.body)
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
		fb.add_theme_font_size_override("font_size", FONT_SIZES.tiny)
		fb.visible = false
		pair.add_child(fb)

		var item_data := ExerciseItem.new(
			"text_highlight_multi",
			func(): return str(selected_cat[idx]),
			str(answer_map.get(idx, "")),
			fb
		)
		_items.append(item_data)

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
		style.border_color = Color("#CBD5E1")
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
	return COLORS.primary

# ---------- Transformation ----------
func _build_transformation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var prompt := _make_label(_get_item_main_text(item), FONT_SIZES.body_small, COLORS.text, true)
		item_vbox.add_child(prompt)

		var task_raw = item.get("task", "")
		if _get_en_text(task_raw) != "":
			var task := _make_label("Task: " + _get_en_text(task_raw), FONT_SIZES.hint, COLORS.muted, false)
			task.set_meta("text_fa", _get_fa_text(task_raw))
			item_vbox.add_child(task)

		var le := _make_line_edit("Write your answer...")
		item_vbox.add_child(le)

		var fb := _make_feedback(item_vbox)
		var compiled: Array[RegEx] = []
		for pat in item.get("answer_patterns", []):
			var rx := RegEx.new()
			if rx.compile(str(pat)) == OK:
				compiled.append(rx)
		var item_data := ExerciseItem.new(
			"transformation",
			func(): return le.text,
			item.get("answer", []),
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", "")),
			compiled,
			item.get("required_words", []),
			item.get("forbidden_words", [])
		)
		_items.append(item_data)

# ---------- Error Correction ----------
func _build_error_correction() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var s_raw = item.get("sentence", item.get("text", ""))
		var sentence_text := _get_en_text(s_raw)
		var wrong: String = str(item.get("wrong_word", item.get("target", "")))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", FONT_SIZES.body_small)
		rtl.add_theme_color_override("default_color", COLORS.text)
		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var marked := sentence_text
		if wrong != "":
			marked = sentence_text.replace(wrong, "[color=#DC2626][u]" + wrong + "[/u][/color]")
		rtl.text = marked
		item_vbox.add_child(rtl)

		var le := _make_line_edit("Type the correction...")
		item_vbox.add_child(le)

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"error_correction",
			func(): return le.text,
			item.get("answer", ""),
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- Word Building ----------
func _build_word_building() -> void:
	var options: Array = _exercise.get("options", [])
	var option_texts: Array = []
	for opt in options:
		option_texts.append(_get_option_text(opt))

	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(row)

		var prefix_label := _make_label(_get_en_text(item.get("prefix", "")) + "  +", FONT_SIZES.title, COLORS.text, true)
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

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"word_building",
			func():
				if ob.selected > 0:
					return ob.get_item_text(ob.selected)
				return "",
			answer,
			fb
		)
		_items.append(item_data)

# ---------- Word Search ----------
func _build_word_search() -> void:
	var word_list: Array = _exercise.get("words", [])
	var correct_words := _get_word_search_correct_words(word_list)

	if word_list.is_empty():
		var msg := _make_label("No words were provided for this word search.", FONT_SIZES.hint, COLORS.muted, false)
		_active_vbox.add_child(msg)
		return

	var words_title := _make_label("Tap the words:", FONT_SIZES.hint, COLORS.muted, true)
	_active_vbox.add_child(words_title)

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

		var wb := Button.new()
		wb.mouse_filter = Control.MOUSE_FILTER_PASS
		wb.text = word_text
		wb.toggle_mode = true
		wb.add_theme_font_size_override("font_size", FONT_SIZES.hint)
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
		var item_data := ExerciseItem.new(
			"word_search_word",
			func(): return wb.button_pressed,
			is_correct,
			null
		)
		item_data.word_button = wb
		_items.append(item_data)

func _get_word_search_row_text(row: Variant) -> String:
	if row is Array:
		var out := ""
		for ch in row:
			out += str(ch)
		return out
	return str(row)

func _get_word_search_answer_cells(grid_rows: Array, word_list: Array) -> Dictionary:
	var answer_set: Dictionary = {}
	var raw_cells: Variant = _exercise.get("answer_cells", [])
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
	for ch in s:
		if ch.strip_edges() != "":
			out += ch
	return out

func _get_word_search_correct_words(word_list: Array) -> Array:
	var raw: Variant = _exercise.get("answer_words", _exercise.get("correct_words", []))
	var source: Array = []
	if raw is Array and not raw.is_empty():
		source = raw
	elif raw is String and str(raw).strip_edges() != "":
		source = [raw]
	else:
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

	var bg := Color("#0f1b3d")
	var border := Color("#3d4a7a")
	var font_color := COLORS.text

	match state:
		"selected":
			bg = COLORS.warning
			border = COLORS.warning
			font_color = Color("#241a00")
		"correct":
			bg = COLORS.success
			border = COLORS.success
			font_color = Color("#03251a")
		"wrong":
			bg = COLORS.error
			border = COLORS.error
			font_color = Color("#2b0505")
		_:
			bg = Color("#0f1b3d")
			border = Color("#3d4a7a")
			font_color = COLORS.text

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
		if str(item.type) != "word_search_word":
			continue
		var btn: Button = item.word_button
		if btn == null:
			continue
		var is_correct: bool = bool(item.answer)
		var is_selected: bool = btn.button_pressed
		btn.disabled = true
		if is_correct:
			correct_total += 1
			if is_selected:
				correct_selected += 1
			_style_word_search_word_button(btn, "correct")
		else:
			if is_selected:
				wrong_selected += 1
				_style_word_search_word_button(btn, "wrong")
			else:
				_style_word_search_word_button(btn, "idle")

	_is_graded = true
	if _score_banner:
		_score_banner.visible = true
		if correct_total == 0:
			_score_banner.text = "No correct words were defined for this exercise."
			_score_banner.add_theme_color_override("font_color", COLORS.warning)
		elif correct_selected == correct_total and wrong_selected == 0:
			_score_banner.text = "Excellent! All correct words chosen!"
			_score_banner.add_theme_color_override("font_color", COLORS.success)
		elif wrong_selected > 0:
			_score_banner.text = "You chose %d/%d correct words and %d wrong words." % [
				correct_selected,
				correct_total,
				wrong_selected
			]
			_score_banner.add_theme_color_override("font_color", COLORS.error)
		else:
			_score_banner.text = "You chose %d/%d correct words." % [
				correct_selected,
				correct_total
			]
			_score_banner.add_theme_color_override("font_color", COLORS.primary)

	if _note_label:
		_note_label.visible = true
	if _check_btn:
		_check_btn.text = "Try Again"

	exercise_checked.emit(
		str(_exercise.get("exercise_id", "")),
		correct_selected,
		correct_total
	)

# ---------- Chart Fill ----------
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
			var h := _make_label(_get_en_text(header), FONT_SIZES.body_small, COLORS.primary, true)
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
				var fb := _make_feedback(cell_box)
				var item_data := ExerciseItem.new(
					"chart_fill",
					func(): return le.text,
					cell.get("answer", []),
					fb,
					"",
					_get_en_text(cell.get("explanation", {})),
					_get_fa_text(cell.get("explanation", {}))
				)
				_items.append(item_data)
			else:
				var text_val: Dictionary = cell.get("text", {})
				var lbl := _make_label(_get_en_text(text_val), FONT_SIZES.body_small, COLORS.text, false)
				lbl.set_meta("text_fa", _get_fa_text(text_val))
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell_box.add_child(lbl)

# ---------- Odd One Out ----------
func _build_odd_one_out() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var words_raw: Array = item.get("words", item.get("options", []))
		var word_texts: Array = []
		for w in words_raw:
			word_texts.append(_get_option_text(w))

		var question_text := "Which word does not belong?"
		if item.has("question"):
			question_text = _get_en_text(item.get("question", ""))
		var q_label := _make_label(question_text, FONT_SIZES.body_small, COLORS.text, true)
		item_vbox.add_child(q_label)

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		var grid := GridContainer.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.columns = 2 if word_texts.size() >= 4 else 1
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_child(grid)

		for w in word_texts:
			var b := _make_select_button(str(w), group, COLORS.warning)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(word_texts, answer)

		var answer_display := ""
		if answer is int and answer >= 0 and answer < word_texts.size():
			answer_display = str(word_texts[answer])

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"odd_one_out",
			func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			answer,
			fb,
			answer_display,
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- Grammar Choice ----------
func _build_grammar_choice() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var sentence: String = _get_en_text(item.get("sentence", item.get("text", "")))
		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", FONT_SIZES.body_small)
		rtl.add_theme_color_override("default_color", COLORS.text)
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
			var b := _make_select_button(str(opt), group, COLORS.info)
			option_btns.append(b)
			grid.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"grammar_choice",
			func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			answer,
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- Passive Transformation ----------
func _build_passive_transformation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var active_text: String = _get_en_text(item.get("active", item.get("prompt", "")))
		var label := _make_label("Active: " + active_text, FONT_SIZES.body, COLORS.text, true)
		item_vbox.add_child(label)

		var hint_text := _get_en_text(item.get("hint", "Rewrite in passive voice:"))
		var hint := _make_label("Task: " + hint_text, FONT_SIZES.hint, COLORS.muted, false)
		item_vbox.add_child(hint)

		var le := _make_line_edit("Type the passive sentence...")
		item_vbox.add_child(le)

		var fb := _make_feedback(item_vbox)
		var compiled: Array[RegEx] = []
		for pat in item.get("answer_patterns", []):
			var rx := RegEx.new()
			if rx.compile(str(pat)) == OK:
				compiled.append(rx)
		var item_data := ExerciseItem.new(
			"passive_transformation",
			func(): return le.text,
			item.get("answer", []),
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", "")),
			compiled,
			item.get("required_words", []),
			item.get("forbidden_words", [])
		)
		_items.append(item_data)

# ---------- Grammar Identification ----------
func _build_grammar_identification() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var text_val: String = _get_en_text(item.get("text", item.get("sentence", "")))
		var target: String = str(item.get("target", ""))

		var rtl := RichTextLabel.new()
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", FONT_SIZES.body)
		rtl.add_theme_color_override("default_color", COLORS.text)
		if _font_regular:
			rtl.add_theme_font_override("normal_font", _font_regular)

		var highlighted := text_val
		if target != "":
			highlighted = text_val.replace(target, "[color=#DC2626][u]" + target + "[/u][/color]")
		rtl.text = highlighted
		item_vbox.add_child(rtl)

		var question := _make_label("What is the grammatical form of the underlined word or phrase?", FONT_SIZES.hint, COLORS.muted, false)
		item_vbox.add_child(question)

		var options: Array = item.get("options", [])
		var option_texts: Array = []
		for opt in options:
			option_texts.append(_get_option_text(opt))

		var group := ButtonGroup.new()
		var option_btns: Array[Button] = []
		for opt in option_texts:
			var b := _make_select_button(str(opt), group, COLORS.purple)
			option_btns.append(b)
			item_vbox.add_child(b)

		var answer: Variant = item.get("answer", -1)
		if answer is String:
			answer = _find_option_index(options, answer)

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"grammar_identification",
			func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			answer,
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- Question Formation ----------
func _build_question_formation() -> void:
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var prompt_text: String = _get_en_text(item.get("prompt", "Form a question:"))
		var label := _make_label(prompt_text, FONT_SIZES.body, COLORS.text, true)
		label.set_meta("text_fa", _get_fa_text(item.get("prompt", "")))
		item_vbox.add_child(label)

		var le := _make_line_edit("Type your question...")
		item_vbox.add_child(le)

		var fb := _make_feedback(item_vbox)
		var compiled: Array[RegEx] = []
		for pat in item.get("answer_patterns", []):
			var rx := RegEx.new()
			if rx.compile(str(pat)) == OK:
				compiled.append(rx)
		var item_data := ExerciseItem.new(
			"question_formation",
			func(): return le.text,
			item.get("answer", []),
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", "")),
			compiled,
			item.get("required_words", []),
			item.get("forbidden_words", [])
		)
		_items.append(item_data)

# ---------- Token Label ----------
func _build_token_label() -> void:
	var default_labels: Array = _exercise.get("labels", [])
	if default_labels.is_empty():
		default_labels = ["S", "O", "V", "Adv"]

	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var inst := _get_en_text(item.get("instruction", ""))
		if inst != "":
			item_vbox.add_child(_make_label(inst, FONT_SIZES.hint, COLORS.muted, false))

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

			var word_label := _make_label(token_text, FONT_SIZES.body, COLORS.text, true)
			token_box.add_child(word_label)

			var ob := OptionButton.new()
			ob.mouse_filter = Control.MOUSE_FILTER_PASS
			ob.add_item("—")
			for lname in label_names:
				ob.add_item(lname)
			ob.selected = 0
			ob.add_theme_font_size_override("font_size", FONT_SIZES.tiny)
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _font_regular:
				ob.add_theme_font_override("font", _font_regular)
			token_box.add_child(ob)
			_register_scroll_control(ob)

			var fb := _make_feedback(token_box)
			var ids := label_ids.duplicate()
			var item_data := ExerciseItem.new(
				"token_label",
				func():
					if ob.selected > 0 and ob.selected - 1 < ids.size():
						return ids[ob.selected - 1]
					return "",
				ans,
				fb,
				"",
				expl_en,
				expl_fa
			)
			_items.append(item_data)

# ---------- Image Choice ----------
func _build_image_choice() -> void:
	var question := _get_en_text(_exercise.get("question", _exercise.get("prompt", "")))
	if question != "":
		_active_vbox.add_child(_make_label(question, FONT_SIZES.body_small, COLORS.text, true))

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

	var fb := _make_feedback(_active_vbox)
	var item_data := ExerciseItem.new(
		"image_choice",
		func():
			for i in option_btns.size():
				if option_btns[i].button_pressed:
					return i
			return -1,
		answer,
		fb,
		"",
		_get_en_text(_exercise.get("explanation", "")),
		_get_fa_text(_exercise.get("explanation", ""))
	)
	_items.append(item_data)

# ---------- Image Match ----------
func _build_image_match() -> void:
	var options: Array = _exercise.get("options", [])
	for item in _exercise.get("items", []):
		var item_vbox := _create_item_container()
		_add_item_media(item, item_vbox)

		var text := _get_item_main_text(item)
		if text != "":
			item_vbox.add_child(_make_label(text, FONT_SIZES.body_small, COLORS.text, true))

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

		var fb := _make_feedback(item_vbox)
		var item_data := ExerciseItem.new(
			"image_match",
			func():
				for i in option_btns.size():
					if option_btns[i].button_pressed:
						return i
				return -1,
			answer,
			fb,
			"",
			_get_en_text(item.get("explanation", "")),
			_get_fa_text(item.get("explanation", ""))
		)
		_items.append(item_data)

# ---------- Image Hotspot ----------
func _build_image_hotspot() -> void:
	var img_path := _get_first_image_path(_exercise)
	if img_path == "" or not ResourceLoader.exists(img_path):
		_active_vbox.add_child(_make_label("Image not found: " + img_path, FONT_SIZES.hint, COLORS.error, false))
		return
	var tex := load(img_path) as Texture2D
	if tex == null:
		_active_vbox.add_child(_make_label("Could not load image: " + img_path, FONT_SIZES.hint, COLORS.error, false))
		return

	var base_size: Vector2 = tex.get_size()
	if base_size.x <= 0:
		base_size.x = 900
	if base_size.y <= 0:
		base_size.y = 600

	var max_width := minf(float(_exercise.get("max_width", 900)), _get_viewport_width() - 72.0)
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

	var overlay := HotspotOverlay.new()
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
	var item_data := ExerciseItem.new(
		"image_hotspot",
		func(): return overlay.selected.duplicate(),
		answer_ids,
		fb,
		_join_string_array(answer_ids, ", "),
		_get_en_text(_exercise.get("explanation", "")),
		_get_fa_text(_exercise.get("explanation", ""))
	)
	_items.append(item_data)

# ============================================================
# CUSTOM DROPDOWN CLASS
# ============================================================
class Dropdown extends Button:
	signal item_selected(index: int)

	var selected: int = 0
	var placeholder := "Choose"
	var _options: Array = []
	var _font: Font
	var _popup: PopupPanel
	var _scroll: ScrollContainer
	var _list: VBoxContainer

	const _ITEM_FONT := 35
	const _MAX_W := 900
	const _MIN_W := 360
	const _MAX_H := 560
	const _PAD_L := 16
	const _PAD_R := 14
	const _PAD_V := 10

	func set_font(f: Font) -> void:
		_font = f

	func add_item(label: String) -> void:
		_options.append(label)

	func get_item_text(index: int) -> String:
		if index <= 0 or index > _options.size():
			return "— " + placeholder + " —"
		return str(_options[index - 1])

	func _ready() -> void:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		clip_text = true
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_theme_font_size_override("font_size", _ITEM_FONT)
		add_theme_color_override("font_color", COLORS.text)
		add_theme_color_override("font_hover_color", COLORS.primary)
		if _font:
			add_theme_font_override("font", _font)

		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0f1b3d")
		style.set_corner_radius_all(10)
		style.border_width_bottom = 2
		style.border_color = COLORS.primary.lightened(0.3)
		style.set_content_margin_all(12)
		add_theme_stylebox_override("normal", style)

		var hover: StyleBoxFlat = style.duplicate()
		hover.border_color = COLORS.primary
		add_theme_stylebox_override("hover", hover)

		var pressed: StyleBoxFlat = hover.duplicate()
		pressed.bg_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.1)
		add_theme_stylebox_override("pressed", pressed)

		_build_popup()
		_refresh_face()
		connect("pressed", _open_popup)

	func _build_popup() -> void:
		_popup = PopupPanel.new()
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("#0f1b3d")
		panel.set_corner_radius_all(14)
		panel.border_width_left = 1
		panel.border_width_right = 1
		panel.border_width_top = 1
		panel.border_width_bottom = 1
		panel.border_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.4)
		panel.shadow_color = Color(0, 0, 0, 0.5)
		panel.shadow_size = 16
		panel.shadow_offset = Vector2(0, 8)
		panel.set_content_margin_all(8)
		_popup.add_theme_stylebox_override("panel", panel)

		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_popup.add_child(_scroll)

		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", 6)
		_scroll.add_child(_list)

		add_child(_popup)
		_popup.about_to_popup.connect(_on_about_to_popup)

	func _open_popup() -> void:
		var btn_rect := get_global_rect()
		var f: Font = _font if _font else ThemeDB.fallback_font
		var longest := 0.0
		for opt in _options:
			longest = maxf(longest, f.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, _ITEM_FONT).x)
		var vp_w := 1280.0
		var vp := get_viewport()
		if vp != null:
			vp_w = vp.get_visible_rect().size.x
		var max_w := minf(float(_MAX_W), vp_w - 24.0)
		var w := clampi(int(maxf(btn_rect.size.x, longest + 70.0)), _MIN_W, int(max_w))
		var wrap_w := float(w - 16 - 10 - _PAD_L - _PAD_R)
		_populate(wrap_w)
		var content_h := int(_list.get_combined_minimum_size().y) + 16
		var h := mini(content_h, _MAX_H)
		_scroll.custom_minimum_size = Vector2(w - 16, h - 16)
		var x := clampi(int(btn_rect.position.x), 8, int(vp_w - w - 8))
		_popup.popup(Rect2i(
			Vector2i(x, int(btn_rect.end.y + 8)),
			Vector2i(w, h)
		))

	func _populate(wrap_w: float) -> void:
		for c in _list.get_children():
			_list.remove_child(c)
			c.queue_free()

		var f: Font = _font if _font else ThemeDB.fallback_font
		var labels := ["— " + placeholder + " —"]
		labels.append_array(_options)

		for i in labels.size():
			var is_sel := (i == selected)
			var is_placeholder := (i == 0)
			var display: String = ("✓  " + str(labels[i])) if is_sel else str(labels[i])

			var row := Button.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.custom_minimum_size.y = f.get_multiline_string_size(
				display,
				HORIZONTAL_ALIGNMENT_LEFT,
				wrap_w,
				_ITEM_FONT
			).y + _PAD_V * 2

			var normal := StyleBoxFlat.new()
			if is_sel:
				normal.bg_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.2)
			else:
				normal.bg_color = Color(0, 0, 0, 0)
			normal.set_corner_radius_all(8)
			if is_sel:
				normal.border_width_left = 3
				normal.border_color = COLORS.primary
			row.add_theme_stylebox_override("normal", normal)

			var hover: StyleBoxFlat = normal.duplicate()
			if is_sel:
				hover.bg_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.16)
			else:
				hover.bg_color = Color(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.08)
			row.add_theme_stylebox_override("hover", hover)
			row.add_theme_stylebox_override("pressed", hover)
			row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			var lbl := Label.new()
			lbl.text = display
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", _ITEM_FONT)
			var base_color: Color = COLORS.muted if is_placeholder else COLORS.text
			lbl.add_theme_color_override("font_color", base_color)
			if _font:
				lbl.add_theme_font_override("font", _font)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.anchor_right = 1.0
			lbl.anchor_bottom = 1.0
			lbl.offset_left = _PAD_L
			lbl.offset_right = -_PAD_R
			lbl.offset_top = _PAD_V
			lbl.offset_bottom = -_PAD_V
			row.add_child(lbl)

			row.pressed.connect(_on_row_pressed.bind(i))
			row.mouse_entered.connect(func():
				lbl.add_theme_color_override("font_color", COLORS.primary)
			)
			row.mouse_exited.connect(func():
				lbl.add_theme_color_override("font_color", base_color)
			)
			_list.add_child(row)

	func _on_about_to_popup() -> void:
		var tw := create_tween().set_parallel(true)
		var rows := _list.get_children()
		for i in rows.size():
			var r: Control = rows[i]
			r.modulate.a = 0.0
			tw.tween_property(r, "modulate:a", 1.0, 0.12).set_delay(i * 0.02)

	func _on_row_pressed(index: int) -> void:
		selected = index
		_refresh_face()
		_popup.hide()
		item_selected.emit(index)

	func _refresh_face() -> void:
		text = get_item_text(selected) + "   ▾"

# ============================================================
# HOTSPOT OVERLAY CLASS
# ============================================================
class HotspotOverlay extends Control:
	signal hotspot_changed(selected_ids: Array)

	var hotspots: Array = []
	var selected: Array = []
	var multi := true
	var base_size := Vector2(1, 1)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var norm := Vector2(
				event.position.x / maxf(size.x, 1.0),
				event.position.y / maxf(size.y, 1.0)
			)
			var hit := ""
			for i in hotspots.size():
				if _hotspot_contains(hotspots[i], norm):
					hit = _hotspot_id(hotspots[i], i)
					break
			if hit != "":
				if multi:
					if selected.has(hit):
						selected.erase(hit)
					else:
						selected.append(hit)
				else:
					if selected.size() == 1 and selected[0] == hit:
						selected.clear()
					else:
						selected = [hit]
				queue_redraw()
				hotspot_changed.emit(selected.duplicate())
				accept_event()

	func _draw() -> void:
		for i in hotspots.size():
			var hs: Dictionary = hotspots[i]
			var id := _hotspot_id(hs, i)
			var is_sel := selected.has(id)
			var col := Color(str(hs.get("color", "#2563EB")))
			var fill_alpha := 0.45 if is_sel else 0.18
			var fill := Color(col.r, col.g, col.b, fill_alpha)
			var line := Color(col.r, col.g, col.b, 0.9)
			var poly := _scaled_polygon(hs)
			if poly.size() >= 3:
				draw_colored_polygon(poly, fill)
				draw_polyline(poly, line, 3.0, true)
			var label := str(hs.get("label", id))
			if label != "":
				var center := _polygon_center(poly)
				draw_string(
					ThemeDB.fallback_font,
					center,
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					18,
					Color(0.1, 0.1, 0.1, 0.9)
				)

	func _hotspot_id(hs: Dictionary, index: int) -> String:
		return str(hs.get("id", "hotspot_%d" % index))

	func _hotspot_contains(hs: Dictionary, norm_pos: Vector2) -> bool:
		if hs.has("polygon"):
			var poly := _normalized_polygon(hs)
			return Geometry2D.is_point_in_polygon(norm_pos, poly)
		if hs.has("rect"):
			var rect := _normalized_rect(hs["rect"])
			return rect.has_point(norm_pos)
		return false

	func _scaled_polygon(hs: Dictionary) -> PackedVector2Array:
		var poly := _normalized_polygon(hs)
		var out := PackedVector2Array()
		for p in poly:
			out.append(Vector2(p.x * size.x, p.y * size.y))
		if out.size() < 3 and hs.has("rect"):
			var r := _normalized_rect(hs["rect"])
			var p0 := Vector2(r.position.x * size.x, r.position.y * size.y)
			var p1 := Vector2(r.end.x * size.x, r.position.y * size.y)
			var p2 := Vector2(r.end.x * size.x, r.end.y * size.y)
			var p3 := Vector2(r.position.x * size.x, r.end.y * size.y)
			out = PackedVector2Array()
			out.append(p0)
			out.append(p1)
			out.append(p2)
			out.append(p3)
		return out

	func _normalized_polygon(hs: Dictionary) -> PackedVector2Array:
		var out := PackedVector2Array()
		if hs.has("polygon"):
			for p in hs["polygon"]:
				if p is Array and p.size() >= 2:
					var v := Vector2(float(p[0]), float(p[1]))
					if _is_pixel(v):
						v = Vector2(
							v.x / maxf(base_size.x, 1.0),
							v.y / maxf(base_size.y, 1.0)
						)
					out.append(v)
		elif hs.has("rect"):
			var r := _normalized_rect(hs["rect"])
			out.append(r.position)
			out.append(Vector2(r.end.x, r.position.y))
			out.append(r.end)
			out.append(Vector2(r.position.x, r.end.y))
		return out

	func _normalized_rect(rect: Variant) -> Rect2:
		if rect is Array and rect.size() >= 4:
			var r := Rect2(
				float(rect[0]),
				float(rect[1]),
				float(rect[2]),
				float(rect[3])
			)
			if _is_pixel(Vector2(r.position.x, r.position.y)) or _is_pixel(r.size):
				r.position.x /= maxf(base_size.x, 1.0)
				r.position.y /= maxf(base_size.y, 1.0)
				r.size.x /= maxf(base_size.x, 1.0)
				r.size.y /= maxf(base_size.y, 1.0)
			return r
		elif rect is Rect2:
			return rect
		return Rect2()

	func _is_pixel(v: Vector2) -> bool:
		return v.x > 1.0001 or v.y > 1.0001

	func _polygon_center(poly: PackedVector2Array) -> Vector2:
		if poly.is_empty():
			return Vector2(10, 20)
		var sum := Vector2.ZERO
		for p in poly:
			sum += p
		return sum / float(poly.size())

# End of ExerciseEngine.gd
