class_name ExerciseEngine
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

signal exercise_checked(exercise_id: String, correct: int, total: int)

# ---------- Theme ----------
const C_PRIMARY := Color("#22D3EE")
const C_SUCCESS := Color("#34D399")
const C_ERROR   := Color("#F87171")
const C_TEXT    := Color("#F1F5F9")
const C_MUTED   := Color("#94A3B8")
const C_TINT    := Color("#1a2f5c")
const C_WARNING := Color("#FBBF24")
const C_INFO    := Color("#22D3EE")
const C_PURPLE  := Color("#A78BFA")
const C_ORANGE  := Color("#FB923C")

# ---------- Theme-aware color helpers ----------
# All UI chrome colors are resolved from the active Dark/Light palette
# (Global). C_* above remain as the app's scene accents (cyan/purple/orange
# etc.) which stay the same in both modes. Feedback + surface/text colors are
# resolved live so the whole exercise UI follows the current theme.
static func _c_surface() -> Color:
	return Global.get_theme_color("surface")

static func _c_surface_alt() -> Color:
	return Global.get_theme_color("surface_alt")

static func _c_border() -> Color:
	return Global.get_theme_color("border")

static func _c_text() -> Color:
	return Global.get_theme_color("text")

static func _c_text_dim() -> Color:
	return Global.get_theme_color("text_dim")

static func _c_success() -> Color:
	return Global.get_theme_color("success")

static func _c_error() -> Color:
	return Global.get_theme_color("error")

static func _c_warning() -> Color:
	return Global.get_theme_color("warning")

const CLOZE_OPT_FONT := 42            # matches the cloze passage text size
const MIN_FONT := 28                   # nothing rendered smaller than this

const FONT_REGULAR_PATH := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_VAZIRMATN    := "res://assets/fonts/Vazirmatn-Regular.ttf"

const SAVE_PATH := "user://exercise_saves.json"

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

const UI_STRINGS := {
	"info_prefix":              { "en": "Info: ",                                              "fa": "نکته: " },
	"image_placeholder":        { "en": "Image placeholder",                                    "fa": "تصویر در دسترس نیست" },
	"image_not_found_prefix":   { "en": "Image not found: ",                                    "fa": "تصویر پیدا نشد: " },
	"show_sample_answer":       { "en": "Show Sample Answer",                                   "fa": "نمایش پاسخ نمونه" },
	"hide_sample_answer":       { "en": "Hide Sample Answer",                                   "fa": "پنهان کردن پاسخ نمونه" },
	"save":                     { "en": "Save",                                                 "fa": "ذخیره" },
	"saved":                    { "en": "Saved",                                                 "fa": "ذخیره شد" },
	"check_answer":             { "en": "Check Answer",                                          "fa": "بررسی پاسخ" },
	"try_again":                { "en": "Try Again",                                             "fa": "تلاش دوباره" },
	"type_your_answer":         { "en": "Type your answer...",                                   "fa": "پاسخ خود را بنویسید..." },
	"write_your_answer":        { "en": "Write your answer here...",                             "fa": "پاسخ خود را اینجا بنویسید..." },
	"self_check_label":         { "en": "I practiced this aloud / I completed this.",            "fa": "این تمرین را با صدای بلند انجام دادم / آن را کامل کردم." },
	"sample_answer_prefix":     { "en": "Sample answer: ",                                       "fa": "پاسخ نمونه: " },
	"choose_a_word":            { "en": "Choose a word",                                         "fa": "یک کلمه را انتخاب کنید" },
	"choose":                   { "en": "Choose",                                                "fa": "انتخاب کنید" },
	"no_correct_words":         { "en": "No correct words were defined for this exercise.",      "fa": "کلمهٔ درستی برای این تمرین تعریف نشده است." },
	"all_correct_words":        { "en": "Excellent! All correct words chosen!",                  "fa": "عالی! همهٔ کلمات درست را انتخاب کردی!" },
	"chose_correct_and_wrong":  { "en": "You chose %d/%d correct words and %d wrong words.",     "fa": "%d از %d کلمهٔ درست را انتخاب کردی و %d کلمهٔ اشتباه." },
	"chose_correct":            { "en": "You chose %d/%d correct words.",                        "fa": "%d از %d کلمهٔ درست را انتخاب کردی." },
	"empty":                    { "en": "Empty",                                                 "fa": "خالی" },
	"correct":                  { "en": "Correct!",                                              "fa": "درست است!" },
	"correct_answer_prefix":    { "en": "Correct answer: ",                                      "fa": "پاسخ درست: " },
	"excellent_score":          { "en": "Excellent! %d/%d correct!",                              "fa": "عالی! %d از %d درست بود!" },
	"got_score":                { "en": "You got %d/%d.",                                         "fa": "%d از %d درست بود." },
}


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
const _DRAG_THRESHOLD := 28.0




# Gesture thresholds.
const _GESTURE_THRESHOLD := 24.0
const _HOLD_MAX_MSEC := 350

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
		Global.on_theme_changed(_apply_theme)
	_apply_theme()

	_ensure_layout_target()

# Restyles theme-driven chrome live. Individual widget StyleBoxes built in
# build() already resolve their colors through _c_*() at construction time, so
# they are correct for the current mode whenever the exercise is (re)built.
# The base theme is re-applied here so theme-agnostic children follow too, and
# the master card stylebox is updated in place on a toggle.
func _apply_theme() -> void:
	if not is_inside_tree():
		return
	theme = Global.get_base_theme()
	if _scroll != null:
		_scroll.theme = Global.get_base_theme()
	if _target != null:
		_target.theme = Global.get_base_theme()
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


# ============================================================
# MAIN ENTRY
# ============================================================
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

	# `increment_group` is kept for backward-compatible call sites but is no
	# longer needed: the instruction letter (A./B./C. ...) is now computed
	# fresh from the engine's actual position in the page every time it's
	# built, instead of a running counter. See _compute_letter_index().


# ============================================================
# TEXT HELPERS
# ============================================================
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


# ============================================================
# HEADER / PANEL / COMMON BLOCKS
# ============================================================
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
	badge.add_theme_font_size_override("font_size", 32)
	# Use white text on a solid accent background for maximum visibility.
	badge.add_theme_color_override("font_color", Color.WHITE)

	var badge_style := StyleBoxFlat.new()
	# Solid accent background so the badge is always clearly visible.
	badge_style.bg_color = accent
	badge_style.set_corner_radius_all(20)
	badge_style.set_content_margin_all(10)
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
	style.set_corner_radius_all(16)
	_master_panel_style = style

	var type := str(_exercise.get("type", "open_ended"))
	var meta: Dictionary = TYPE_META.get(type, TYPE_META["open_ended"])
	style.border_width_left = 8
	style.border_color = meta["color"]
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.set_content_margin_all(24)

	panel.add_theme_stylebox_override("panel", style)

	_active_vbox = VBoxContainer.new()
	_active_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_vbox.add_theme_constant_override("separation", 32)
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
		if child is ExerciseEngine:
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
	instruction.text = final_text
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
		_apply_fa_meta(_check_btn, "check_answer")
		_check_btn.pressed.connect(_on_check_pressed)
		btn_row.add_child(_check_btn)

	if btn_row.get_child_count() > 0:
		_target.add_child(btn_row)


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.text = text
	btn.add_theme_font_size_override("font_size", 38)
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
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

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
# ORDERING WITH UP/DOWN ARROWS
# ------------------------------------------------------------
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
	list_vbox.add_theme_constant_override("separation", 10)
	container.add_child(list_vbox)

	var fb := _make_feedback(container)
	_rebuild_ordering_list(list_vbox, current_order, item_texts)

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

		var num := _make_label("%d." % (pos + 1), 34, _c_text_dim(), true)
		num.custom_minimum_size.x = 60
		row.add_child(num)

		var txt := _make_label(str(item_texts[idx]), 36, _c_text(), false)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)

		# Use arrow symbols instead of "Up" / "Down"
		var up := _make_button("↑", _c_text_dim())
		up.custom_minimum_size = Vector2(70, 60)
		up.disabled = (pos == 0)
		up.pressed.connect(_on_order_move.bind(list_vbox, current_order, item_texts, pos, -1))
		row.add_child(up)

		var down := _make_button("↓", _c_text_dim())
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
	_items.append({
		"type": "image_hotspot",
		"get": func(): return overlay.selected.duplicate(),
		"answer": answer_ids,
		"feedback": fb,
		"answer_display": _join_string_array(answer_ids, ", "),
		"explanation_en": _get_en_text(_exercise.get("explanation", "")),
		"explanation_fa": _get_fa_text(_exercise.get("explanation", "")),
	})


# ============================================================
# WIDGET HELPERS
# ============================================================
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
	label.text = clean
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
	b.text = "    " + text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Lets the button stretch inside grids so columns fill the screen.
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 0)
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", _c_text())
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)

	var normal := StyleBoxFlat.new()
	normal.bg_color = _c_surface()
	normal.set_corner_radius_all(10)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = _c_border()
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
	b.add_theme_font_size_override("font_size", 34)
	# Dark image option button needs light text.
	b.add_theme_color_override("font_color", _c_text())
	b.add_theme_color_override("font_hover_color", C_PRIMARY)
	b.add_theme_color_override("font_pressed_color", C_PRIMARY)

	if opt is Dictionary:
		var path := str(opt.get("image", opt.get("path", "")))
		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				b.icon = tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var normal := StyleBoxFlat.new()
	# Dark button background instead of white.
	normal.bg_color = _c_surface()
	normal.set_corner_radius_all(12)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = _c_border()
	normal.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.07)
	hover.border_color = C_PRIMARY.lightened(0.35)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.14)
	pressed.border_color = C_PRIMARY
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pressed)

	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	_register_scroll_control(b)
	return b


func _make_option_dropdown(options: Array, placeholder := "") -> Dropdown:
	var dd := Dropdown.new()
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
	le_style.set_corner_radius_all(10)
	le_style.border_width_bottom = 2
	le_style.border_color = C_PRIMARY.lightened(0.3)
	le_style.set_content_margin_all(14)
	le.add_theme_stylebox_override("normal", le_style)

	var le_hover: StyleBoxFlat = le_style.duplicate()
	le_hover.border_color = C_PRIMARY
	le.add_theme_stylebox_override("hover", le_hover)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = C_PRIMARY
	le.add_theme_stylebox_override("focus", le_focus)

	le.add_theme_color_override("caret_color", C_PRIMARY)
	_register_scroll_control(le)
	return le


func _make_chart_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.mouse_filter = Control.MOUSE_FILTER_PASS
	le.placeholder_text = placeholder
	le.add_theme_font_size_override("font_size", 38)
	# Dark input field: light text, muted placeholder, visible caret.
	le.add_theme_color_override("font_color", _c_text())
	le.add_theme_color_override("font_placeholder_color", _c_text_dim())
	le.add_theme_color_override("caret_color", C_PRIMARY)
	# Keep selected text readable.
	le.add_theme_color_override(
		"selection_color",
		Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35)
	)
	le.add_theme_color_override("font_selected_color", Color.WHITE)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_regular:
		le.add_theme_font_override("font", _font_regular)

	var le_style := StyleBoxFlat.new()
	# Use the same dark background as the other input fields.
	le_style.bg_color = _c_surface()
	le_style.set_corner_radius_all(8)
	le_style.border_width_bottom = 2
	le_style.border_color = _c_border()
	le_style.set_content_margin_all(10)
	le.add_theme_stylebox_override("normal", le_style)

	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = C_PRIMARY
	le.add_theme_stylebox_override("focus", le_focus)

	_register_scroll_control(le)
	return le


func _make_chip_button(text: String, filled := false) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = text
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color("#000000") if filled else _c_text())
	b.add_theme_color_override("font_hover_color", Color("#000000") if filled else C_PRIMARY)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	var style := StyleBoxFlat.new()
	style.bg_color = C_PRIMARY if filled else _c_surface()
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = C_PRIMARY if filled else _c_border()
	style.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
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
	b.add_theme_color_override("font_pressed_color", Color("#000000"))
	b.add_theme_color_override("font_hover_color", C_PRIMARY)
	if _font_regular:
		b.add_theme_font_override("font", _font_regular)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(3 if compact else 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal.duplicate())

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#fbbf24")
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(3 if compact else 6)
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


func _exit_tree() -> void:
	# Stop the audio and free the panel if this engine created it.
	if _audio_panel != null and is_instance_valid(_audio_panel):
		if _audio_panel.is_playing():
			_audio_panel.stop_and_close()
		if _audio_panel_owned:
			_audio_panel.queue_free()
	# Stop following live theme changes.
	if _theme_hook_active and is_instance_valid(Global):
		_theme_hook_active = false
		if Global.theme_changed.is_connected(_apply_theme):
			Global.theme_changed.disconnect(_apply_theme)

# ============================================================
# GRADING
# ============================================================
func _on_check_pressed() -> void:
	if _is_graded:
		_reset_for_retry()
		return
	# Word Search uses its own visual grading.
	if str(_exercise.get("type", "")) in ["word_search", "word_find"]:
		_grade_word_search()
		return
	var correct := 0
	var total := 0
	for item in _items:
		if not item.has("get"):
			continue
		total += 1
		var user_answer = item["get"].call()
		var is_correct := _is_item_correct(item, user_answer)
		# Count BEFORE the feedback check: some types (e.g. inline cloze) carry
		# no per-item feedback label but must still be scored.
		if is_correct:
			correct += 1
		var fb: Label = item.get("feedback", null)
		if fb == null:
			continue
		fb.visible = true
		# Prefer the human-readable answer text. Fall back to the formatted
		# raw answer only when no display text exists.
		# Prefer the human-readable answer text; fall back to the raw
		# answer only when no display text exists.
		var answer_text: String = str(item.get("answer_display", ""))
		if answer_text == "":
			answer_text = _format_answer(item.get("answer"))
		var item_type := str(item.get("type", ""))
		# If the user left a text field empty, show the Farsi "Empty" label.
		var user_str := str(user_answer).strip_edges()
		if user_str == "" and item_type in ["fill_blank", "chart_fill", "transformation", "letter_scramble", "error_correction", "passive_transformation", "question_formation"]:
			fb.text = _t_fa("empty")
			fb.set_meta("text_fa", fb.text)
			fb.add_theme_color_override("font_color", _c_warning())
			continue
		if is_correct:
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✓"
			else:
				# Feedback label is always Farsi.
				fb.text = _t_fa("correct")
				fb.set_meta("text_fa", fb.text)
			fb.add_theme_color_override("font_color", _c_success())
		else:
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✗"
			else:
				var expl_en := str(item.get("explanation_en", ""))
				var expl_fa := str(item.get("explanation_fa", ""))
				# Label in Farsi, but the correct answer itself stays English.
				fb.text = _t_fa("correct_answer_prefix") + answer_text
				if expl_en != "":
					fb.text += "\n" + expl_en
				# Farsi mirror, kept for the translate-toggle convention.
				var fa_text := _t_fa("correct_answer_prefix") + answer_text
				if expl_fa != "":
					fa_text += "\n" + expl_fa
				elif expl_en != "":
					fa_text += "\n" + expl_en
				fb.set_meta("text_fa", fa_text)
			fb.add_theme_color_override("font_color", _c_error())
	_is_graded = true
	# Inline cloze recolors its blank slots instead of using per-item labels.
	if str(_exercise.get("type", "")) == "cloze":
		_apply_cloze_feedback()
	if _score_banner:
		_score_banner.visible = true
		if total > 0 and correct == total:
			_score_banner.text = _t_fa("excellent_score") % [correct, total]
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", _c_success())
		else:
			_score_banner.text = _t_fa("got_score") % [correct, total]
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", C_PRIMARY)
	if _note_label:
		_note_label.visible = true
	if _check_btn:
		_check_btn.text = _t("try_again")
		_apply_fa_meta(_check_btn, "try_again")
	exercise_checked.emit(str(_exercise.get("exercise_id", "")), correct, total)

func _is_item_correct(item: Dictionary, user_answer: Variant) -> bool:
	var item_type := str(item.get("type", ""))
	# Multi-line categorization cell: the user types one word per line. It is
	# correct if every non-empty line is an accepted answer word (case-insensitive).
	if item_type == "textarea":
		var accepted: Array = []
		for w in item.get("answer", []):
			accepted.append(_normalize(str(w)))
		var u := str(user_answer)
		var any_line := false
		for ln in u.split("\n"):
			var s := _normalize(ln)
			if s == "":
				continue
			any_line = true
			if not accepted.has(s):
				return false
		return any_line
	if item_type == "image_hotspot":
		var u: Array = []
		if user_answer is Array:
			for x in user_answer:
				u.append(str(x))
		var c: Array = []
		var ans = item.get("answer", [])
		if ans is Array:
			for x in ans:
				c.append(str(x))
		else:
			c.append(str(ans))
		u.sort()
		c.sort()
		return _compare(u, c)
	# 1) Exact match against the accepted answer(s).
	if _compare(user_answer, item.get("answer")):
		return true
	var user_str := str(user_answer)
	var norm := _normalize(user_str)
	# 2) Optional regex patterns (harmless when the list is empty).
	var patterns: Array = item.get("answer_patterns", [])
	for pat in patterns:
		var rx := RegEx.new()
		if rx.compile(str(pat)) == OK:
			if rx.search(user_str):
				return true
	# 3) Optional required/forbidden words.
	# IMPORTANT: skip this block when the list is empty. Before this fix,
	# an empty required_words list left req_ok = true, so EVERY typed
	# answer was accepted as correct.
	var required: Array = item.get("required_words", [])
	if not required.is_empty():
		var req_ok := true
		for w in required:
			if not norm.contains(_normalize(str(w))):
				req_ok = false
				break
		if req_ok:
			for w in item.get("forbidden_words", []):
				if norm.contains(_normalize(str(w))):
					req_ok = false
					break
		if req_ok:
			return true
	return false

func _compare(user_answer: Variant, correct_answer: Variant) -> bool:
	if user_answer == null:
		return false
	if correct_answer == null:
		return false

	if correct_answer is Array:
		# An empty list means no correct answer was defined for this item.
		# Treat it as wrong instead of accepting anything non-empty.
		if correct_answer.is_empty():
			return false
		if user_answer is Array:
			if user_answer.size() != correct_answer.size():
				return false
			for i in user_answer.size():
				if not _compare(user_answer[i], correct_answer[i]):
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


func _normalize(s: String) -> String:
	s = str(s).to_lower().strip_edges()
	s = s.replace(char(0x2019), "'")
	s = s.replace("'", "")
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


func _reset_for_retry() -> void:
	_is_graded = false
	if _score_banner:
		_score_banner.visible = false
	if _check_btn:
		_check_btn.text = _t("check_answer")
		_apply_fa_meta(_check_btn, "check_answer")
	build(_exercise, false)


func _on_reveal_sample() -> void:
	var is_showing := false
	for item in _items:
		if item.has("sample_label") and item["sample_label"] != null:
			item["sample_label"].visible = not item["sample_label"].visible
			if item["sample_label"].visible:
				is_showing = true

	if _reveal_btn:
		if is_showing:
			_reveal_btn.text = _t("hide_sample_answer")
			_apply_fa_meta(_reveal_btn, "hide_sample_answer")
			# Gray color for Hide
			_set_button_color(_reveal_btn, _c_text_dim())
		else:
			_reveal_btn.text = _t("show_sample_answer")
			_apply_fa_meta(_reveal_btn, "show_sample_answer")
			# Orange color for Show
			_set_button_color(_reveal_btn, C_ORANGE)


func _on_open_ended_done() -> void:
	# Save the user's answers to disk
	_save_open_ended_answers()

	if _note_label:
		_note_label.visible = true

	if _done_btn:
		_done_btn.text = _t("saved")
		_apply_fa_meta(_done_btn, "saved")
		_is_saved = true
		# Gray color for Saved state
		_set_button_color(_done_btn, _c_text_dim())

	exercise_checked.emit(str(_exercise.get("exercise_id", "")), 1, 1)


# ============================================================
# CUSTOM DROPDOWN
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

	const _ITEM_FONT := 39
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
		add_theme_color_override("font_color", ExerciseEngine._c_text())
		add_theme_color_override("font_hover_color", ExerciseEngine.C_PRIMARY)
		if _font:
			add_theme_font_override("font", _font)

		var style := StyleBoxFlat.new()
		style.bg_color = ExerciseEngine._c_surface()
		style.set_corner_radius_all(10)
		style.border_width_bottom = 2
		style.border_color = ExerciseEngine.C_PRIMARY.lightened(0.3)
		style.set_content_margin_all(12)
		add_theme_stylebox_override("normal", style)

		var hover: StyleBoxFlat = style.duplicate()
		hover.border_color = ExerciseEngine.C_PRIMARY
		add_theme_stylebox_override("hover", hover)

		var pressed_style: StyleBoxFlat = hover.duplicate()
		pressed_style.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.1)
		add_theme_stylebox_override("pressed", pressed_style)

		_build_popup()
		_refresh_face()
		connect("pressed", _open_popup)

	func _build_popup() -> void:
		_popup = PopupPanel.new()
		var panel := StyleBoxFlat.new()
		panel.bg_color = ExerciseEngine._c_surface()
		panel.set_corner_radius_all(14)
		panel.border_width_left = 1
		panel.border_width_right = 1
		panel.border_width_top = 1
		panel.border_width_bottom = 1
		panel.border_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.4)
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
			longest = maxf(
				longest,
				f.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, _ITEM_FONT).x
			)
		# Keep the popup inside the visible screen.
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
				normal.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.2)
			else:
				normal.bg_color = Color(0, 0, 0, 0)
			normal.set_corner_radius_all(8)
			if is_sel:
				normal.border_width_left = 3
				normal.border_color = ExerciseEngine.C_PRIMARY
			row.add_theme_stylebox_override("normal", normal)

			var hover: StyleBoxFlat = normal.duplicate()
			if is_sel:
				hover.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.16)
			else:
				hover.bg_color = Color(ExerciseEngine.C_PRIMARY.r, ExerciseEngine.C_PRIMARY.g, ExerciseEngine.C_PRIMARY.b, 0.08)
			row.add_theme_stylebox_override("hover", hover)
			row.add_theme_stylebox_override("pressed", hover)
			row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			var lbl := Label.new()
			lbl.text = display
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", _ITEM_FONT)
			var base_color: Color = ExerciseEngine._c_text_dim() if is_placeholder else ExerciseEngine._c_text()
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
				lbl.add_theme_color_override("font_color", ExerciseEngine.C_PRIMARY)
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
# HOTSPOT OVERLAY
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
