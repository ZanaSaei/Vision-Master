# ============================================================
# ExerciseEngine - CORE layer.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# Core holds: the exercise_checked signal, re-exported theme
# constants, state vars, lifecycle (_ready/_process), theme, 
# gesture/scroll/keyboard handling, persistence, and the pure
# _normalize() helper used by text helpers + graders.
# ============================================================
class_name ExerciseEngineCore
extends VBoxContainer

# ============================================================
# Universal interactive exercise renderer for Godot 4.7
# ============================================================
# Feed it any exercise Dictionary from JSON.
# It builds the UI, collects answers, and grades via "Check Answer".
#
# Scrolling:
# - By default the engine is content-sized (like a plain VBox),
#   so it never collapses inside content-driven layouts.
# - TAP still presses buttons; HOLD + DRAG scrolls the nearest
#   parent ScrollContainer (see _on_scroll_child_gui_input).
#   Put your workbook page content inside a ScrollContainer and
#   the engines cooperate with it automatically.
# - If you want an engine to scroll INSIDE a fixed-height box,
#   set `use_internal_scroll = true` BEFORE adding it to the tree.
# ============================================================

@warning_ignore("unused_signal")
signal exercise_checked(exercise_id: String, correct: int, total: int)

# ---------- Theme (re-exported from preload("res://scenes/shared/exercise_engine/exercise_theme.gd").gd) ----------
const C_PRIMARY := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_PRIMARY
const C_SUCCESS := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_SUCCESS
const C_ERROR := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_ERROR
const C_TEXT := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_TEXT
const C_MUTED := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_MUTED
const C_TINT := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_TINT
const C_WARNING := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_WARNING
const C_INFO := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_INFO
const C_PURPLE := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_PURPLE
const C_ORANGE := preload("res://scenes/shared/exercise_engine/exercise_theme.gd").C_ORANGE
const UI_STRINGS := preload("res://scenes/shared/exercise_engine/exercise_strings.gd").UI_STRINGS

# Theme-aware color helpers delegate to ExerciseTheme; kept here so
# every existing _c_*() call site keeps working unchanged.
static func _c_surface() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_surface()
static func _c_surface_alt() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_surface_alt()
static func _c_border() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_border()
static func _c_text() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_text()
static func _c_text_dim() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_text_dim()
static func _c_success() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_success()
static func _c_error() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_error()
static func _c_warning() -> Color:
	return preload("res://scenes/shared/exercise_engine/exercise_theme.gd")._c_warning()

const CLOZE_OPT_FONT := 42            # matches the cloze passage text size
const MIN_FONT := 28                   # nothing rendered smaller than this

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

const SAVE_PATH := "user://exercise_saves.json"

const TYPE_META := {
	"multiple_choice":          { "badge": "Multiple Choice",         "color": Color("#6366F1") },
	"true_false":               { "badge": "True / False",            "color": Color("#8B5CF6") },
	"matching":                 { "badge": "Matching",                "color": Color("#0EA5E9") },
	"fill_blank":               { "badge": "Fill in the Blank",       "color": Color("#F97316") },
	"cloze":                    { "badge": "Choose the Best Form",    "color": Color("#EC4899") },
	"ordering":                 { "badge": "Put in Order",            "color": Color("#EAB308") },
	"categorize":               { "badge": "Categorize",              "color": Color("#10B981") },
	"open_ended":               { "badge": "Your Turn",               "color": Color("#64748B") },
	"pronunciation":            { "badge": "Pronunciation",           "color": Color("#64748B") },
	"writing":                  { "badge": "Writing",                 "color": Color("#64748B") },
	"passage":                  { "badge": "Reading",                 "color": Color("#475569") },
	"reading":                  { "badge": "Reading",                 "color": Color("#475569") },
	"word_bank":                { "badge": "Word Bank",               "color": Color("#14B8A6") },
	"sentence_ordering":        { "badge": "Unscramble the Sentence", "color": Color("#A855F7") },
	"sentence_unscramble":      { "badge": "Unscramble the Sentence", "color": Color("#A855F7") },
	"letter_scramble":          { "badge": "Unscramble the Word",     "color": Color("#F59E0B") },
	"table_fill":               { "badge": "Complete the Table",      "color": Color("#4F46E5") },
	"table_fill_advanced":      { "badge": "Complete the Table",      "color": Color("#4F46E5") },
	"text_highlight":           { "badge": "Find & Mark",             "color": Color("#38BDF8") },
	"text_highlight_multi":     { "badge": "Find & Mark",             "color": Color("#38BDF8") },
	"transformation":           { "badge": "Rewrite the Sentence",    "color": Color("#E11D48") },
	"error_correction":         { "badge": "Find the Mistake",        "color": Color("#DC2626") },
	"word_building":            { "badge": "Build the Word",          "color": Color("#84CC16") },
	"word_search":              { "badge": "Word Search",             "color": Color("#B45309") },
	"word_find":                { "badge": "Word Search",             "color": Color("#B45309") },
	"chart_fill":               { "badge": "Complete the Chart",      "color": Color("#1D4ED8") },
	"odd_one_out":              { "badge": "Odd One Out",             "color": Color("#EA580C") },
	"grammar_choice":           { "badge": "Grammar Choice",          "color": Color("#06B6D4") },
	"passive_transformation":   { "badge": "Passive Transformation",  "color": Color("#7C3AED") },
	"grammar_identification":   { "badge": "Grammar Identification",  "color": Color("#DB2777") },
	"question_formation":       { "badge": "Question Formation",      "color": Color("#0D9488") },
	"token_label":              { "badge": "Label the Sentence",      "color": Color("#7C3AED") },
	"image_choice":             { "badge": "Choose the Picture",      "color": Color("#0369A1") },
	"image_match":              { "badge": "Match Pictures",          "color": Color("#0891B2") },
	"image_hotspot":            { "badge": "Mark the Image",          "color": Color("#92400E") },
}

# ------------------------------------------------------------
# UI CHROME LOCALIZATION
# ------------------------------------------------------------
# Everything ABOVE (badges, passages, instructions, hints, notes,
# sample answers) is authored content and already carries a "fa" field
# from your JSON, surfaced via set_meta("text_fa", ...) for whatever
# translate-toggle you use elsewhere in the app.
#
# Everything BELOW is UI chrome generated by this script itself
# ("Correct!", "Check Answer", "Empty", ...) and previously had no
# Farsi at all. UI_STRINGS + _t() fixes that. Each string still also
# gets set_meta("text_fa", ...) wherever the resulting Control is
# available, so it stays consistent with the rest of this file's
# convention and keeps working with any external translate-toggle.
#
# `ui_locale` controls what's shown by DEFAULT before any external
# toggle runs. Left at "en" so existing behavior/screenshots don't
# change until you deliberately opt in — set to "fa" (or wire it to
# your Global.gd language setting) whenever you're ready.
var ui_locale := "en"



# Looks up a UI_STRINGS entry for the current ui_locale, falling back
# to English (then to the key itself) if something's missing.
func _t(key: String) -> String:
	var entry: Dictionary = UI_STRINGS.get(key, {})
	return str(entry.get(ui_locale, entry.get("en", key)))


# Convenience for attaching the Farsi variant as text_fa meta, matching
# the convention already used for content strings elsewhere in this file.
func _apply_fa_meta(ctrl: Object, key: String) -> void:
	if ctrl == null:
		return
	var entry: Dictionary = UI_STRINGS.get(key, {})
	if entry.has("fa"):
		ctrl.set_meta("text_fa", str(entry["fa"]))

# Always returns the Farsi variant of a UI_STRINGS entry, regardless of
# ui_locale. Answer feedback labels must always be Farsi, while the actual
# answer content stays English.
func _t_fa(key: String) -> String:
	var entry: Dictionary = UI_STRINGS.get(key, {})
	return str(entry.get("fa", entry.get("en", key)))

# false = classic content-sized VBox (recommended inside workbook pages).
# true  = the engine wraps itself in a ScrollContainer (fixed-height boxes).
var use_internal_scroll := false

# When true, the engine's built-in footer buttons (Check Answer / Save /
# Show Sample Answer) are hidden. Used on exam pages that present a single
# global "Check All Answers" button instead. Per-item feedback labels are
# still shown after grading.
var hide_footer_buttons := false

var _exercise: Dictionary = {}
var _items: Array = []
# Shared engine state declared in the base class but used by the descendant
# classes in this chain (widgets/builders/grading). The analyzer only looks
# inside this file, so each is flagged "declared but never used" on reload —
# a false positive introduced by the file split. Silence for this block:
@warning_ignore_start("unused_private_class_variable")
var _score_banner: Label = null
var _check_btn: Button = null
var _reveal_btn: Button = null
var _done_btn: Button = null
# Tracks Save/Saved state directly instead of comparing displayed button
# text (which broke as soon as the text became localizable, and was
# fragile even before that).
var _is_saved := false
var _note_label: Label = null
var _is_graded := false
var _is_open_ended := false
var _is_non_interactive := false
var _font_regular: FontFile
var _font_bold: FontFile
var _font_farsi: FontFile

# Master switch for showing the Farsi translation of authored content
# (passages, instructions, notes, cloze passages). Workbook wires its
# header toggle button to set_show_translation(). Farsi labels are
# appended during build() and simply shown/hidden based on this flag.
var show_translation := false
var _fa_labels: Array = []


# Loaded once per app run and shared by every ExerciseEngine instance,
# instead of re-resolving the font path on every _ready().
static var _shared_font_regular: FontFile
static var _shared_font_bold: FontFile
static var _shared_font_farsi: FontFile
var _active_vbox: VBoxContainer
var _scroll: ScrollContainer = null
var _target: Control = null
var _master_panel_style: StyleBoxFlat = null
var _theme_hook_active := false

# --- Inline cloze state (choices are picked by tapping blanks in the text) ---
var _cloze_rtl: RichTextLabel = null
var _cloze_click_global := Vector2.ZERO   # last tap position on cloze label (global coords)
var _cloze_popup: PopupPanel = null
var _cloze_popup_list: VBoxContainer = null  # holds the option rows
var _cloze_segments: Array = []     # [{ "index": int }] for blanks, String for prose
var _cloze_choices: Array = []      # chosen option text per blank ("" = not chosen)
var _cloze_correct: Array = []      # correct option text per blank
var _cloze_options: Array = []      # option texts per blank
var _cloze_graded: Array = []       # bool per blank (set after grading)
var _cloze_graded_all := false
var _cloze_active := -1             # blank index whose popup is open

# --- Tap vs drag scrolling state ---
var _drag_source: Control = null
var _drag_active := false
var _press_pos := Vector2.ZERO
# Reduced from 28 → 14 px so even a tiny finger-shift on Android starts
# a scroll rather than accidentally selecting a button or typing field.
const _DRAG_THRESHOLD := 14.0




# Gesture thresholds.
const _GESTURE_THRESHOLD := 14.0
# Reduced from 350 → 180 ms. At 350 ms a held-and-released tap still
# opened the keyboard / pressed buttons. 180 ms distinguishes a deliberate
# tap from a press-hold-drag reliably on touchscreen devices.
const _HOLD_MAX_MSEC := 180

# Press timing for long-press prevention.
var _press_time_msec := 0
var _hold_blocked := false

# Used to bring tapped typing fields above the Android keyboard.
var _focus_scroll_request_id := 0
var _focus_scroll_tween: Tween

# Used to create temporary bottom space for the virtual keyboard.
var _keyboard_spacer: Control = null
const KEYBOARD_SPACER_META := "exercise_keyboard_spacer"

# ---------- Audio support ----------
# Path to your AudioPanel scene. Adjust to match your FileSystem dock.
var audio_panel_scene_path := "res://scenes/shared/AudioPanel.tscn"

# Optional: assign your own panel instead of letting the engine create one.
var audio_panel: Node = null

# Choose which exercise types show the audio button.
# Example: ["multiple_choice", "fill_blank", "cloze", "reading"]
var audio_types: Array = []

# If true, ANY exercise with an "audio" field gets the button.
var audio_allow_any_type := false

var _audio_btn: Button = null
var _audio_path := ""
var _audio_panel: Node = null
# True when this engine created the panel itself.
var _audio_panel_owned := false
@warning_ignore_restore("unused_private_class_variable")

func _ready() -> void:
	if _shared_font_regular == null:
		var regular := load(FONT_REGULAR_PATH)
		if regular is FontFile:
			_shared_font_regular = regular
	_font_regular = _shared_font_regular

	if _shared_font_bold == null:
		var bold := load(FONT_BOLD_PATH)
		if bold is FontFile:
			_shared_font_bold = bold
	_font_bold = _shared_font_bold

	if _shared_font_farsi == null:
		var farsi := load(FONT_VAZIRMATN)
		if farsi is FontFile:
			_shared_font_farsi = farsi
	_font_farsi = _shared_font_farsi

	add_theme_constant_override("separation", 18)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# PageView uses this group to cancel exercise gestures during swipes/scrolls.
	add_to_group("exercise_engines")

	# Assign the app-wide base theme and follow live Dark/Light toggles.
	if not _theme_hook_active:
		_theme_hook_active = true
		var g: Node = _global()
		if g != null:
			g.call("on_theme_changed", _apply_theme)
	_apply_theme()

	_ensure_layout_target()

# Restyles theme-driven chrome live. Individual widget StyleBoxes built in
# build() already resolve their colors through _c_*() at construction time, so
# they are correct for the current mode whenever the exercise is (re)built.
# The base theme is re-applied here so theme-agnostic children follow too, and
# the master card stylebox is updated in place on a toggle.
func _global() -> Node:
	return get_node_or_null("/root/Global")

func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var g: Node = _global()
	var base_theme: Variant = g.call("get_base_theme") if g != null else null
	theme = base_theme
	if _scroll != null:
		_scroll.theme = base_theme
	if _target != null:
		_target.theme = base_theme
	if _master_panel_style != null:
		_master_panel_style.bg_color = _c_surface()

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return

	# If the user keeps holding without moving, cancel the tap.
	if _drag_source == null or _drag_active or _hold_blocked:
		return

	if not is_instance_valid(_drag_source):
		_drag_source = null
		return

	if Time.get_ticks_msec() - _press_time_msec > _HOLD_MAX_MSEC:
		_hold_blocked = true
		_drag_source.set_block_signals(true)

		# If a typing field or another editable field is focused, close the keyboard.
		var vp := get_viewport()
		if vp != null:
			var focused := vp.gui_get_focus_owner()
			if focused != null and _is_editable_control(focused):
				focused.release_focus()

		if _is_editable_control(_drag_source):
			_drag_source.release_focus()

		_hide_virtual_keyboard()

# ------------------------------------------------------------
# Even with an internal ScrollContainer, report the real content
# size as our minimum so content-driven parents never collapse us
# to zero height.
# ------------------------------------------------------------
func _get_minimum_size() -> Vector2:
	# If we have a separate target (internal scroll), forward its min size.
	if _target != null and _target != self:
		return _target.get_combined_minimum_size()
	# Otherwise, compute the VBoxContainer-like minimum size from our direct children.
	var sep := get_theme_constant("separation", "VBoxContainer") if has_theme_constant("separation", "VBoxContainer") else 0
	var max_width := 0.0
	var total_height := 0.0
	var child_count := 0
	for child in get_children():
		if child is Control:
			var min_size: Vector2 = child.get_combined_minimum_size()
			max_width = max(max_width, min_size.x)
			total_height += min_size.y
			child_count += 1
	if child_count > 0:
		total_height += sep * (child_count - 1)
	var custom := custom_minimum_size
	return Vector2(max(max_width, custom.x), max(total_height, custom.y))


# ------------------------------------------------------------
# Layout target. By default content is added directly to `self`
# (classic behavior). With use_internal_scroll = true a
# ScrollContainer wrapper is created instead.
# ------------------------------------------------------------
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
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_target = VBoxContainer.new()
	_target.name = "ExerciseContent"
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target.add_theme_constant_override("separation", 18)
	_scroll.add_child(_target)


# ============================================================
# INPUT: TAP = CLICK, HOLD + DRAG = SCROLL
# ============================================================
# Buttons normally consume press/drag events, which prevents a
# ScrollContainer from scrolling. Every interactive widget
# registers here. A quick tap still clicks it; as soon as the
# pointer moves beyond the threshold we take over the gesture,
# scroll the nearest ScrollContainer, and block the widget's
# signals so it does NOT get selected.
# ============================================================
func _register_scroll_control(ctrl: Control) -> void:
	# Typing fields need special tap-vs-drag keyboard handling.
	if _is_editable_control(ctrl):
		# Start with no focus so a drag does not open the Android keyboard.
		ctrl.focus_mode = Control.FOCUS_NONE
		# When focus is lost, require a confirmed tap again.
		ctrl.focus_exited.connect(_on_editable_focus_exited.bind(ctrl))
	ctrl.gui_input.connect(_on_scroll_child_gui_input.bind(ctrl))

func cancel_active_gesture() -> void:
	# Called by PageView when a page swipe or page scroll gesture starts.
	if _drag_source != null and is_instance_valid(_drag_source):
		_drag_active = true
		_hold_blocked = true
		_drag_source.set_block_signals(true)

	# Always close the keyboard when PageView takes over the gesture.
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if focused != null and _is_editable_control(focused):
			focused.release_focus()

	_hide_virtual_keyboard()


func reset_active_gesture() -> void:
	# Called by PageView after it finishes a gesture that it consumed.
	if _drag_source != null and is_instance_valid(_drag_source):
		_drag_source.call_deferred("set_block_signals", false)

	_drag_source = null
	_drag_active = false
	_hold_blocked = false

func _get_scroll_target() -> ScrollContainer:
	# Prefer our own wrapper, otherwise walk up to the workbook's
	# page ScrollContainer.
	if _scroll != null:
		return _scroll
	var n := get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


func _on_scroll_child_gui_input(event: InputEvent, source: Control) -> void:
	# ------------------------------------------------------------
	# Drag / motion.
	# ------------------------------------------------------------
	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and _drag_source == source:
		var drag_global := Vector2.ZERO

		if event is InputEventMouseMotion:
			drag_global = event.global_position
		elif event is InputEventScreenDrag:
			drag_global = event.position

		var move_distance := (drag_global - _press_pos).length()

		if not _drag_active and not _hold_blocked and move_distance > _DRAG_THRESHOLD:
			# It is a drag, not a tap. Cancel the widget's click/focus.
			_drag_active = true

			if is_instance_valid(source):
				source.set_block_signals(true)

			# Hide the keyboard if a drag starts while typing is focused.
			if _is_editable_control(source):
				source.release_focus()
			else:
				var vp := get_viewport()
				if vp != null:
					var focused := vp.gui_get_focus_owner()
					if focused != null and _is_editable_control(focused):
						focused.release_focus()

			_hide_virtual_keyboard()

		# Do NOT scroll here.
		# PageView owns left/right page swipes and up/down page scrolling.
		return

	# ------------------------------------------------------------
	# Press / release.
	# ------------------------------------------------------------
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
		# Safety net: unblock any previous gesture that may still be active.
		if _drag_source != null and is_instance_valid(_drag_source):
			_drag_source.call_deferred("set_block_signals", false)

		_drag_source = source
		_drag_active = false
		_hold_blocked = false
		_press_pos = press_pos
		_press_time_msec = Time.get_ticks_msec()

		if _is_editable_control(source):
			if source.has_focus():
				# Already focused: allow caret editing, but a drag/hold can still cancel.
				source.focus_mode = Control.FOCUS_ALL
			else:
				# Not focused yet: prevent keyboard during possible drag/hold.
				source.focus_mode = Control.FOCUS_NONE

	elif is_release:
		if source != null and is_instance_valid(source) and _drag_source == source:
			if _drag_active or _hold_blocked:
				# Unblock after this input event is fully processed.
				source.call_deferred("set_block_signals", false)
			elif _is_editable_control(source):
				# Only a fast, clean tap opens the keyboard.
				var duration := Time.get_ticks_msec() - _press_time_msec
				if duration <= _HOLD_MAX_MSEC:
					_confirm_editable_tap(source)

		_drag_active = false
		_hold_blocked = false
		_drag_source = null

func _viewport_width() -> float:
	var vp := get_viewport()
	if vp != null:
		var w := vp.get_visible_rect().size.x
		if w > 0.0:
			return w
	return 1280.0


# Safe width for media/hotspots so nothing is wider than the screen.
func _safe_media_width(requested: int) -> int:
	var max_allowed := int(_viewport_width()) - 80
	return clampi(requested, 120, maxi(max_allowed, 160))


# Scrolls the internal ScrollContainer back to the top.
func scroll_to_top() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 0


# ============================================================
# TYPING FIELD / KEYBOARD HELPERS
# ============================================================
func _is_editable_control(ctrl: Control) -> bool:
	return ctrl is LineEdit or ctrl is TextEdit


func _on_editable_focus_exited(ctrl: Control) -> void:
	if is_instance_valid(ctrl):
		# Require a confirmed tap before the keyboard can open again.
		ctrl.focus_mode = Control.FOCUS_NONE

	# Deferred cleanup lets the user tap another text field without flicker.
	if is_inside_tree():
		call_deferred("_cleanup_keyboard_if_needed")

func _confirm_editable_tap(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return

	# Allow focus only after the tap has been confirmed.
	ctrl.focus_mode = Control.FOCUS_ALL
	ctrl.grab_focus()

	# A new confirmed tap cancels any previous keyboard scroll request.
	_focus_scroll_request_id += 1
	var request_id := _focus_scroll_request_id

	# Create/move the spacer before measuring so the first tap has room immediately.
	_ensure_keyboard_spacer_for(ctrl)

	# On Android/iOS, showing the keyboard one frame after focus is more reliable.
	call_deferred("_show_virtual_keyboard", ctrl)

	_scroll_editable_into_view_after_keyboard(ctrl, request_id)

func _is_mobile() -> bool:
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"


func _show_virtual_keyboard(ctrl: Control = null) -> void:
	# Safety check for deferred calls.
	if ctrl != null and not is_instance_valid(ctrl):
		return

	# Only try to show the keyboard on mobile platforms.
	if not _is_mobile():
		return

	if not DisplayServer.has_method("virtual_keyboard_show"):
		return

	var existing_text := ""

	# Give the keyboard the current text from the tapped typing field.
	if ctrl is LineEdit:
		existing_text = ctrl.text
	elif ctrl is TextEdit:
		existing_text = ctrl.text

	# Godot 4.7 expects at least one argument:
	# virtual_keyboard_show(existing_text)
	DisplayServer.virtual_keyboard_show(existing_text)

func _hide_virtual_keyboard() -> void:
	if _is_mobile() and DisplayServer.has_method("virtual_keyboard_hide"):
		DisplayServer.virtual_keyboard_hide()

	# Remove the temporary bottom space when the keyboard is closed.
	_set_keyboard_spacer_height(0.0)


func _get_scroll_target_for_control(ctrl: Control) -> ScrollContainer:
	# Prefer the nearest ScrollContainer above the tapped typing field.
	var n := ctrl.get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	# Fallback to the engine's own scroll target.
	return _get_scroll_target()


func _scroll_editable_into_view_after_keyboard(ctrl: Control, request_id: int) -> void:
	if not is_inside_tree():
		return

	var kb_height := 0

	if _is_mobile():
		# Previously this polled DisplayServer.virtual_keyboard_get_height()
		# every frame until it "settled," with a separate fallback estimate
		# for the first tap (which often reports 0 before the IME has
		# animated in) and a second refine pass once/if the real height
		# showed up. That's a lot of moving parts for what a fixed,
		# generous reservation solves just as well in practice: Persian
		# IME keyboards (Gboard/SwiftKey) are fairly consistent as a
		# percentage of screen height. See _get_reserved_keyboard_height().
		kb_height = _get_reserved_keyboard_height()
		_ensure_keyboard_spacer_for(ctrl)
		_set_keyboard_spacer_height(float(kb_height) + 90.0)

	# Let the layout update before measuring/scrolling.
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(ctrl) or not is_inside_tree():
		return
	if request_id != _focus_scroll_request_id:
		return

	_scroll_editable_into_view(ctrl, kb_height)

	# Android can settle its layout a frame late (right as the IME finishes
	# animating in), so one short re-check covers that without needing the
	# previous multi-pass height-refinement loop.
	await get_tree().create_timer(0.15).timeout

	if not is_instance_valid(ctrl) or not is_inside_tree():
		return
	if request_id != _focus_scroll_request_id:
		return

	_scroll_editable_into_view(ctrl, kb_height)

func _scroll_editable_into_view(ctrl: Control, kb_height: int = 0) -> void:
	if not is_instance_valid(ctrl):
		return

	var sc := _get_scroll_target_for_control(ctrl)
	if sc == null:
		return

	var vbar := sc.get_v_scroll_bar()
	if vbar == null:
		return

	var max_v := int(vbar.max_value - vbar.page)
	if max_v <= 0:
		return

	var vp := get_viewport()
	if vp == null:
		return

	var scroll_rect := sc.get_global_rect()
	var target_rect := _get_editable_target_rect(ctrl)
	var vp_rect := vp.get_visible_rect()

	var margin := 36.0
	var available_top := maxf(scroll_rect.position.y, vp_rect.position.y) + margin
	var available_bottom := minf(scroll_rect.end.y, vp_rect.end.y) - float(kb_height) - margin

	if available_bottom <= available_top:
		return

	# Already visible above the keyboard.
	if target_rect.position.y >= available_top and target_rect.end.y <= available_bottom:
		return

	var desired_top := target_rect.position.y

	# The important part of the field is below the keyboard.
	if target_rect.end.y > available_bottom:
		desired_top = available_bottom - target_rect.size.y

	# The important part is above the visible scroll area.
	if desired_top < available_top:
		desired_top = available_top

	# If the important area is taller than the available area, keep its top visible.
	if target_rect.size.y > available_bottom - available_top:
		desired_top = available_top

	var delta := target_rect.position.y - desired_top
	if absf(delta) < 2.0:
		return

	var target := clampi(int(sc.scroll_vertical + delta), 0, maxi(max_v, 0))

	if _focus_scroll_tween != null and _focus_scroll_tween.is_valid():
		_focus_scroll_tween.kill()

	_focus_scroll_tween = create_tween()
	_focus_scroll_tween.tween_property(
		sc,
		"scroll_vertical",
		target,
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cleanup_keyboard_if_needed() -> void:
	if not is_inside_tree():
		return

	var vp := get_viewport()
	if vp == null:
		return

	var focused := vp.gui_get_focus_owner()
	if focused != null and _is_editable_control(focused):
		return

	# Cancel pending keyboard scrolling.
	_focus_scroll_request_id += 1

	_hide_virtual_keyboard()
	_set_keyboard_spacer_height(0.0)


func _ensure_keyboard_spacer() -> Control:
	# Compatibility wrapper for older calls.
	if _keyboard_spacer != null and is_instance_valid(_keyboard_spacer):
		return _keyboard_spacer

	return _ensure_keyboard_spacer_for(self)

func _set_keyboard_spacer_height(height: float) -> void:
	# Closing the keyboard removes all temporary bottom padding.
	if height <= 0.0:
		if is_inside_tree():
			for spacer in get_tree().get_nodes_in_group("exercise_keyboard_spacers"):
				if spacer is Control:
					_hide_spacer_control(spacer as Control)
		elif _keyboard_spacer != null and is_instance_valid(_keyboard_spacer):
			_hide_spacer_control(_keyboard_spacer)
		return

	# If we do not have a spacer yet, do nothing.
	# The spacer should be created by _ensure_keyboard_spacer_for().
	if _keyboard_spacer == null or not is_instance_valid(_keyboard_spacer):
		return

	_keyboard_spacer.custom_minimum_size.y = maxf(height, 0.0)
	_keyboard_spacer.visible = height > 1.0
	_keyboard_spacer.update_minimum_size()
	_refresh_spacer_layout(_keyboard_spacer)

func _ensure_keyboard_spacer_for(ctrl: Control) -> Control:
	if not is_inside_tree():
		return null

	var host := _get_keyboard_spacer_host(ctrl)
	if host == null:
		return null

	# If the engine previously used a different spacer host, reset that old spacer.
	if (
		_keyboard_spacer != null
		and is_instance_valid(_keyboard_spacer)
		and _keyboard_spacer.get_parent() != host
	):
		_keyboard_spacer.custom_minimum_size.y = 0.0
		_keyboard_spacer.visible = false

	var spacer: Control = null

	if host.has_meta(KEYBOARD_SPACER_META):
		spacer = host.get_meta(KEYBOARD_SPACER_META) as Control

	if spacer == null or not is_instance_valid(spacer):
		spacer = Control.new()
		spacer.name = "ExerciseKeyboardSpacer"
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size = Vector2(0, 0)
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.visible = false
		spacer.add_to_group("exercise_keyboard_spacers")

		host.add_child(spacer)
		host.set_meta(KEYBOARD_SPACER_META, spacer)
	else:
		if not spacer.is_in_group("exercise_keyboard_spacers"):
			spacer.add_to_group("exercise_keyboard_spacers")

	_keyboard_spacer = spacer

	# Put the spacer beyond the last generated question, not directly under
	# the tapped typing field.
	_move_spacer_after_last_generated_question(host, spacer)

	return spacer


func _get_keyboard_spacer_host(ctrl: Control) -> Control:
	# Internal scroll:
	# keep the spacer inside this engine's own content.
	if _scroll != null and _target != null:
		return _target

	# External page/workbook scroll:
	# put the spacer in the page content container, not inside the tapped exercise.
	var sc := _get_scroll_target_for_control(ctrl)
	if sc != null:
		var host := _get_scroll_content_container(sc)
		if host != null:
			return host

	# Fallback to the old behavior.
	return _target


func _get_scroll_content_container(sc: ScrollContainer) -> Control:
	# Prefer the real layout container that holds the workbook/page content.
	for child in sc.get_children():
		if child is Control:
			var found := _find_layout_host(child as Control)
			if found != null:
				return found

	# Fallback for very simple pages.
	if sc.get_child_count() > 0:
		var child: Node = sc.get_child(0)
		if child is Container and not child.is_in_group("exercise_engines"):
			return child as Control

	return null


func _find_layout_host(node: Control) -> Control:
	# Never place the spacer inside an exercise engine.
	if node.is_in_group("exercise_engines"):
		return null

	# These are normal page/content containers.
	if node is BoxContainer or node is GridContainer or node is FlowContainer:
		return node

	for child in node.get_children():
		if child is Control:
			var found := _find_layout_host(child as Control)
			if found != null:
				return found

	return null


func _move_spacer_after_last_generated_question(host: Control, spacer: Control) -> void:
	if host == null or spacer == null or not is_instance_valid(spacer):
		return

	# Make sure the spacer really belongs to this host.
	if spacer.get_parent() != host:
		var old_parent: Node = spacer.get_parent()
		if old_parent != null:
			old_parent.remove_child(spacer)
		host.add_child(spacer)

	var last_question := -1

	# Find the last direct child of the host that contains an exercise engine.
	# This also works when each exercise is wrapped in another container.
	if is_inside_tree():
		var engines := get_tree().get_nodes_in_group("exercise_engines")

		for engine in engines:
			var node: Node = engine

			while node != null and node.get_parent() != host:
				node = node.get_parent()

			if node != null and node.get_parent() == host and node != spacer:
				var idx: int = host.get_children().find(node)
				if idx > last_question:
					last_question = idx

	var target_index := host.get_child_count() - 1

	if last_question >= 0:
		target_index = last_question + 1

	host.move_child(spacer, mini(target_index, host.get_child_count() - 1))


func _refresh_spacer_layout(spacer: Control) -> void:
	if spacer == null or not is_instance_valid(spacer):
		return

	var parent: Node = spacer.get_parent()

	while parent != null and parent is Control:
		var control_parent := parent as Control

		control_parent.update_minimum_size()

		if control_parent is ScrollContainer:
			(control_parent as ScrollContainer).queue_sort()

		parent = control_parent.get_parent()


func _hide_spacer_control(spacer: Control) -> void:
	if spacer == null or not is_instance_valid(spacer):
		return

	spacer.custom_minimum_size.y = 0.0
	spacer.visible = false
	spacer.update_minimum_size()
	_refresh_spacer_layout(spacer)

func _get_viewport_height() -> float:
	var vp := get_viewport()
	if vp != null:
		var h := vp.get_visible_rect().size.y
		if h > 0.0:
			return h

	return float(DisplayServer.window_get_size().y)


# Reserved bottom space (as a fraction of the viewport height) whenever a
# typing field is focused on mobile. This used to be computed by polling
# DisplayServer.virtual_keyboard_get_height() every frame until it
# "settled" (_wait_for_keyboard_height, now removed), with a separate
# fallback estimate for the unreliable first tap and extra delayed
# re-checks in case Android reported a late size change. Persian IME
# keyboards (Gboard/SwiftKey) are fairly consistent as a percentage of
# screen height, so a fixed, generous fraction gets the same practical
# result with far less code and no polling/race-condition surface.
#
# If this ever looks too tall (wasted blank space) or too short (field
# still partly covered) on your test devices, KEYBOARD_HEIGHT_FRACTION
# is the one number to tune.
const KEYBOARD_HEIGHT_FRACTION := 0.42
const KEYBOARD_HEIGHT_MIN_PX := 220.0

func _get_reserved_keyboard_height() -> int:
	return int(maxf(_get_viewport_height() * KEYBOARD_HEIGHT_FRACTION, KEYBOARD_HEIGHT_MIN_PX))



func _get_editable_target_rect(ctrl: Control) -> Rect2:
	var rect := ctrl.get_global_rect()

	# For tall TextEdit boxes, keep the bottom/caret area visible.
	if ctrl is TextEdit:
		var focus_height := 80.0
		if rect.size.y > focus_height:
			return Rect2(
				Vector2(rect.position.x, rect.end.y - focus_height),
				Vector2(rect.size.x, focus_height)
			)

	return rect

# ============================================================
# PERSISTENCE HELPERS
# ============================================================
func _load_all_saves() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var result = json.data
		if result is Dictionary:
			return result
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
		var item: Dictionary = _items[i]
		if item.has("text_edit") and item["text_edit"] != null:
			var te: TextEdit = item["text_edit"]
			if is_instance_valid(te):
				var key := str(item.get("save_key", str(i)))
				saves[ex_id][key] = te.text
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
		var item: Dictionary = _items[i]
		if item.has("text_edit") and item["text_edit"] != null:
			var te: TextEdit = item["text_edit"]
			var key := str(item.get("save_key", str(i)))
			# Fall back to the old positional key so answers saved by a
			# previous version of the app before this fix aren't lost.
			if not ex_saves.has(key) and ex_saves.has(str(i)):
				key = str(i)
			if is_instance_valid(te) and ex_saves.has(key):
				te.text = str(ex_saves[key])


# ---------- normalization helper (used by graders + text helpers) ----------
func _normalize(s: String) -> String:
	s = str(s).to_lower().strip_edges()
	s = s.replace(char(0x2019), "'")
	s = s.replace("'", "")
	for ch in [".", ",", "!", "?", ";", ":", "\"", "(", ")", "[", "]", "{", "}", "/"]:
		s = s.replace(ch, " ")
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s.strip_edges()
