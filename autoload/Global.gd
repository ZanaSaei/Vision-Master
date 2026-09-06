extends Node

signal review_words_changed()

# ============================================================
#  GLOBAL.GD — Autoload Singleton
#  Handles: loading lesson JSON data, and the saved-words system
# ============================================================

# ============================================================
# TTS (Text-To-Speech) Engine
# ============================================================
var english_voice_id: String = ""
var _category_cache: Dictionary = {}
# Cache of parsed JSON lesson arrays keyed by res:// path, plus a per-file
# book_lesson -> entry index so lookups are O(1) instead of re-parsing the
# whole file and linearly scanning it on every scene entry.
var _json_cache: Dictionary = {}
var _lesson_index_cache: Dictionary = {}
var _word_db_loaded := false

const DICTIONARY_PATH := "res://data/v_dictionary.json"

var word_review_return: String = ""
# ---------- VOCABULARY DATA LOADING ----------

var intro_animation_played := false

var audio_player: AudioStreamPlayer

# Word database for quick lookup
var word_database: Dictionary = {}

# Verb forms mapping
var verb_forms: Dictionary = {}


func load_vocabulary(book_number: int, lesson_number: int) -> Dictionary:
	var path := "res://data/v%d_vocabularies.json" % book_number
	return _lookup_lesson_entry(path, book_number, lesson_number)


func get_audio_path(book_number: int, lesson_number: int, filename: String) -> String:
	return "res://assets/audio/v%d/l%d/%s" % [book_number, lesson_number, filename]


# ============================================================
# UNIFIED CONVERSATION / READING DATA LOADING
# ------------------------------------------------------------
# v_conversation.json and v_reading.json are each a single flat
# array of lesson entries (like v_dictionary.json), with "book"
# and "lesson" fields on every entry — instead of the old
# per-book "v{book}_conversations.json" / "{lessons:{"1":...}}"
# format. These two functions find the matching entry.
# ============================================================

const CONVERSATION_PATH := "res://data/v_conversation.json"
const READING_PATH      := "res://data/v_reading.json"


func load_conversation(book_number: int, lesson_number: int) -> Dictionary:
	return _load_unified_lesson_entry(CONVERSATION_PATH, book_number, lesson_number)


func load_reading(book_number: int, lesson_number: int) -> Dictionary:
	return _load_unified_lesson_entry(READING_PATH, book_number, lesson_number)


func _load_unified_lesson_entry(path: String, book_number: int, lesson_number: int) -> Dictionary:
	return _lookup_lesson_entry(path, book_number, lesson_number)


## Parses a lesson-data JSON file (a flat array of lesson entries) exactly
## once per session and caches it. Returns the cached Array (empty on error).
func _load_lesson_file(path: String) -> Array:
	if _json_cache.has(path):
		return _json_cache[path]
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Failed to parse JSON at %s — %s" % [path, json.get_error_message()])
		return []
	var data = json.data
	if not data is Array:
		push_error("Invalid JSON format at %s: expected an array of lesson entries" % path)
		return []
	_json_cache[path] = data
	return data


## Finds a lesson entry by book/lesson. Builds a book_lesson -> entry index
## for the file on first use, so lookups are O(1) instead of a linear scan.
func _lookup_lesson_entry(path: String, book_number: int, lesson_number: int) -> Dictionary:
	if not _lesson_index_cache.has(path):
		_lesson_index_cache[path] = {}
		var index: Dictionary = _lesson_index_cache[path]
		for entry in _load_lesson_file(path):
			var b := int(entry.get("book", -1))
			var l := int(entry.get("lesson", -1))
			if b < 0 or l < 0:
				continue
			index["%d_%d" % [b, l]] = entry
	return _lesson_index_cache[path].get("%d_%d" % [book_number, lesson_number], {})


# Joins an array of sentence objects ({"en":..., "fa":..., "start":..., "end":...})
# into one plain-text string using only the "en" field. Farsi and timing data
# are intentionally ignored here for now (used later for karaoke sync/translation).
func join_sentences(sentences: Array) -> String:
	var parts: Array = []
	for s in sentences:
		var en: String = s.get("en", "")
		if en != "":
			parts.append(en)
	return " ".join(parts)


# Some entries in the unified files store "audio" as a full res:// path
# (e.g. "res://assets/audio/v1/l1/conversation.mp3") rather than just a
# filename. This resolves either form to a usable path.
func resolve_audio_path(book_number: int, lesson_number: int, audio_value: String, fallback_filename: String) -> String:
	if audio_value == "":
		return get_audio_path(book_number, lesson_number, fallback_filename)
	if audio_value.begins_with("res://"):
		return audio_value
	return get_audio_path(book_number, lesson_number, audio_value)


# ---------- SAVED WORDS SYSTEM ----------

const SAVED_WORDS_PATH  := "user://saved_words.json"
const PROGRESS_PATH     := "user://progress.json"
const REVIEW_WORDS_PATH  := "user://review_words.json"

var current_book: int   = 1
var current_lesson: int = 1
var flashcard_mode: String = "lesson"
var _last_scene: String = ""
var saved_words: Array = []
var review_words: Array = []
var grammar_unlocked_units: Dictionary = {}
var grammar_start_unit_index: int = 0
var grammar_xp: Dictionary = {}
# Per lesson ("book_lesson") -> Array of بخش indices already completed, so XP
# is only awarded once per unit (never on replays).
var grammar_completed_units: Dictionary = {}

# ---------- APP SETTINGS ----------
const SETTINGS_PATH := "user://settings.json"
var sound_enabled: bool = true   # UI sound effects (Sfx autoload)
var tts_enabled: bool = true     # English text-to-speech pronunciation
var theme_mode: int = 0          # 0 = Dark, 1 = Light

# ---------- THEME SYSTEM (Dark / Light universes) ----------
# Exposed on Global (an already-registered autoload) so every scene can
# call Global.* without depending on a newly-registered global name.
signal theme_changed(mode: int)

enum ThemeMode { DARK, LIGHT }

const THEME_FONT := "res://assets/fonts/Vazirmatn-Regular.ttf"

var theme_palette: Dictionary = {}
var _theme: Theme = Theme.new()
var _theme_font: Font

const THEME_PALETTES := {
	# ---------------------------------------------------------------
	# DARK  — Modern Deep Slate & Vibrant Neon Indigo
	# ---------------------------------------------------------------
	ThemeMode.DARK: {
		"bg":            Color("#0F172A"),
		"surface":       Color("#1E293B"),
		"surface_alt":   Color("#334155"),
		"border":        Color(1.0, 1.0, 1.0, 0.12),
		"text":          Color("#F8FAFC"),
		"text_dim":      Color("#94A3B8"),
		"accent":        Color("#818CF8"),
		"accent_bright": Color("#A5B4FC"),
		"accent_soft":   Color(0.5, 0.55, 0.97, 0.15),
		"on_accent":     Color("#FFFFFF"),
		"success":       Color("#34D399"),
		"error":         Color("#F87171"),
		"warning":       Color("#FBBF24"),
		"success_soft":  Color(0.2, 0.82, 0.6, 0.15),
		"error_soft":    Color(0.97, 0.44, 0.44, 0.15),
		"warning_soft":  Color(0.98, 0.75, 0.14, 0.15),
		"overlay":       Color(0, 0, 0, 0.65),
		"bg_base":       Color("#0B1120"),
		"wave_top":      Color("#3730A3"),
		"wave_mid":      Color("#312E81"),
		"wave_bottom":   Color("#1E1B4B"),
	},
	# ---------------------------------------------------------------
	# LIGHT — Crisp Clean White & Playful Punchy Indigo
	# ---------------------------------------------------------------
	ThemeMode.LIGHT: {
		"bg":            Color("#F8FAFC"),
		"surface":       Color("#FFFFFF"),
		"surface_alt":   Color("#F1F5F9"),
		"border":        Color(0.0, 0.0, 0.0, 0.10),
		"text":          Color("#0F172A"),
		"text_dim":      Color("#64748B"),
		"accent":        Color("#4F46E5"),
		"accent_bright": Color("#4338CA"),
		"accent_soft":   Color(0.31, 0.27, 0.90, 0.10),
		"on_accent":     Color("#FFFFFF"),
		"success":       Color("#10B981"),
		"error":         Color("#EF4444"),
		"warning":       Color("#F59E0B"),
		"success_soft":  Color(0.06, 0.72, 0.5, 0.15),
		"error_soft":    Color(0.93, 0.26, 0.26, 0.15),
		"warning_soft":  Color(0.96, 0.62, 0.04, 0.15),
		"overlay":       Color(0, 0, 0, 0.4),
		"bg_base":       Color("#F1F5F9"),
		"wave_top":      Color("#818CF8"),
		"wave_mid":      Color("#A5B4FC"),
		"wave_bottom":   Color("#E0E7FF"),
	},
}


func theme_is_dark() -> bool:
	return theme_mode == ThemeMode.DARK


func get_theme_color(role: String) -> Color:
	return theme_palette.get(role, Color.WHITE)


func on_theme_changed(callback: Callable) -> void:
	theme_changed.connect(callback)


# The app-wide base Theme (already applied to the tree root). Shared
# components can assign this to themselves so all their children follow
# the current Dark / Light palette automatically.
func get_base_theme() -> Theme:
	return _theme


func set_theme_mode(new_mode: int) -> void:
	if new_mode != ThemeMode.DARK and new_mode != ThemeMode.LIGHT:
		new_mode = ThemeMode.DARK
	if new_mode == theme_mode and not theme_palette.is_empty():
		return
	theme_mode = new_mode
	theme_palette = THEME_PALETTES[theme_mode]
	_rebuild_theme()
	_apply_theme_to_root()
	_apply_theme_to_background()
	save_settings()
	theme_changed.emit(theme_mode)


func _setup_theme() -> void:
	_theme_font = load(THEME_FONT) as Font
	if theme_mode != ThemeMode.DARK and theme_mode != ThemeMode.LIGHT:
		theme_mode = ThemeMode.DARK
	theme_palette = THEME_PALETTES[theme_mode]
	_rebuild_theme()
	_apply_theme_to_root()
	_apply_theme_to_background()


func _rebuild_theme() -> void:
	var t := Theme.new()
	t.default_font = _theme_font
	t.default_font_size = 34

	var bg: Color = theme_palette["bg"]
	var surface: Color = theme_palette["surface"]
	var alt: Color = theme_palette["surface_alt"]
	var border: Color = theme_palette["border"]
	var text: Color = theme_palette["text"]
	var dim: Color = theme_palette["text_dim"]
	var accent: Color = theme_palette["accent"]

	t.set_color("font_color", "Label", text)
	t.set_color("font_hover_color", "Label", text)
	t.set_color("font_focus_color", "Label", text)
	t.set_color("font_selected_color", "Label", text)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 0)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = alt
	btn_normal.border_color = border
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(16)
	btn_normal.content_margin_left = 24
	btn_normal.content_margin_right = 24
	btn_normal.content_margin_top = 14
	btn_normal.content_margin_bottom = 14
	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = alt.lerp(accent, 0.18)
	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = alt.lerp(accent, 0.3)
	var btn_focus := btn_normal.duplicate() as StyleBoxFlat
	btn_focus.border_color = accent
	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_stylebox("disabled", "Button", btn_normal)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", text)
	t.set_color("font_pressed_color", "Button", text)
	t.set_color("font_focus_color", "Button", text)
	t.set_color("font_disabled_color", "Button", dim)

	for ptype in ["Panel", "PanelContainer"]:
		var p := StyleBoxFlat.new()
		p.bg_color = surface
		p.border_color = border
		p.set_border_width_all(1)
		p.set_corner_radius_all(20)
		t.set_stylebox("panel", ptype, p)

	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0, 0, 0, 0)
	t.set_stylebox("panel", "ScrollContainer", sc)

	var grab := StyleBoxFlat.new()
	grab.bg_color = accent
	grab.set_corner_radius_all(8)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber", "HScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "HScrollBar", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0)
	t.set_stylebox("track", "VScrollBar", track)
	t.set_stylebox("track", "HScrollBar", track)

	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = bg
	le_normal.border_color = border
	le_normal.set_border_width_all(1)
	le_normal.set_corner_radius_all(12)
	le_normal.content_margin_left = 16
	le_normal.content_margin_right = 16
	var le_focus := le_normal.duplicate() as StyleBoxFlat
	le_focus.border_color = accent
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("font_placeholder_color", "LineEdit", dim)

	t.set_color("font_color", "OptionButton", text)
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_color", "CheckBox", text)
	t.set_color("font_hover_color", "CheckButton", text)
	t.set_color("font_hover_color", "CheckBox", text)
	t.set_color("font_color", "TabContainer", text)
	t.set_color("font_selected_color", "TabContainer", accent)
	t.set_color("font_color", "ProgressBar", text)
	t.set_color("font_color", "RichTextLabel", text)
	t.set_color("default_color", "RichTextLabel", text)

	var sep := StyleBoxLine.new()
	sep.color = border
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", sep)

	var tip := StyleBoxFlat.new()
	tip.bg_color = alt
	tip.border_color = border
	tip.set_border_width_all(1)
	tip.set_corner_radius_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", text)

	_theme = t


func _apply_theme_to_root() -> void:
	if is_inside_tree():
		get_tree().root.theme = _theme


func _apply_theme_to_background() -> void:
	if not is_inside_tree():
		return
	call_deferred("_apply_theme_to_background_deferred")


func _apply_theme_to_background_deferred() -> void:
	var mb: Node = get_tree().root.get_node_or_null("MenuBackground")
	if mb == null or not mb.has_method("apply_theme"):
		return
	mb.apply_theme(
		theme_palette["bg_base"],
		theme_palette["wave_top"],
		theme_palette["wave_mid"],
		theme_palette["wave_bottom"]
	)


# ══════════════════════════════════════════════════════════════
# GENERIC SCENE THEMING
# Walks any scene and restyles its Controls so Dark / Light stays
# consistent across the whole app. Scenes that already implement
# their own theme walk (settings, about_me, the grammar system)
# are skipped to avoid double-styling.
# ══════════════════════════════════════════════════════════════
const SELF_THEMED_SCRIPTS := [
	"settings.gd",
	"about_me.gd",
	"vocab_flashcards.gd",
	"grammar_button.gd",
	"grammar_hub.gd",
	"grammar_lesson.gd",
	"grammar_units.gd",
	"main_menu.gd",
	"word_review.gd",
	"book_menu.gd",
	"lesson_menu.gd",
]

# Labels that read better muted in both themes.
const DIM_LABELS := [
	"Subtitle", "Hint", "ContactHint", "VersionValue", "CreditLabel",
	"SubName", "DevName", "VersionName",
]


func scene_handles_own_theme(root: Node) -> bool:
	var s: Script = root.get_script()
	if s == null:
		return false
	var p := String(s.resource_path).to_lower()
	for script_name in SELF_THEMED_SCRIPTS:
		if p.ends_with(script_name):
			return true
	return false


func style_scene(root: Node) -> void:
	if root == null:
		return
	if scene_handles_own_theme(root):
		return
	_style_walk(root)


func _style_walk(node: Node) -> void:
	# Independent overlay layers (side menu, transitions, animated
	# background) own their theming or are decorative — skip them.
	if node is CanvasLayer:
		return

	# PageView manages its own internal chrome (tabs, indicator, dots) via
	# Global.on_theme_changed — the walker must not touch its children.
	if node is PageView:
		return

	# GrammarHint is a fully self-themed widget (warm-yellow light-bulb
	# bubble + flat bulb button). It styles every part of itself in
	# _apply_theme, so the walker must not re-style its bubble as a card.
	if node is GrammarHint:
		return

	# Unified header bars are themed as a whole (bar + its buttons/labels).
	if node.name in HEADER_BAR_NAMES and node is Control:
		style_header(node)
		return

	if node is ColorRect:
		_style_background_rect(node)
	elif node is PanelContainer or node is Panel:
		if _is_header_bar_panel(node):
			# BookMenu/LessonMenu: the bar panel is invisible — only the
			# header buttons inside it should be visible.
			_hide_header_bar_panel(node)
		else:
			_style_card(node)
	elif node is Label:
		_style_label(node)
	elif node is Button:
		_style_button(node)

	for child in node.get_children():
		_style_walk(child)


func _style_background_rect(cr: ColorRect) -> void:
	var n := cr.name
	if n != "BackgroundColor" and n != "Bg" and not n.contains("Background"):
		return
	if theme_is_dark():
		cr.color = Color(0.055, 0.07, 0.13, cr.color.a)
	else:
		cr.color = Color(0.955, 0.968, 0.98, cr.color.a)


func _is_header_bar_panel(node: Node) -> bool:
	for c in node.get_children():
		if c.name in HEADER_BAR_NAMES:
			return true
	return false


func _hide_header_bar_panel(node: Control) -> void:
	# Transparent fill with the same breathing room as regular header bars,
	# so the buttons inside sit at identical positions to every other scene.
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(0, 0, 0, 0)
	s.set_border_width_all(0)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 16
	s.content_margin_bottom = 12
	node.add_theme_stylebox_override("panel", s)


func _style_card(node: Node) -> void:
	var dark := theme_is_dark()
	var old: StyleBox = node.get_theme_stylebox("panel")
	var style := StyleBoxFlat.new()
	if old is StyleBoxFlat:
		var of := old as StyleBoxFlat
		style.content_margin_left = of.content_margin_left
		style.content_margin_top = of.content_margin_top
		style.content_margin_right = of.content_margin_right
		style.content_margin_bottom = of.content_margin_bottom
		style.set_corner_radius_all(of.corner_radius_top_left if of.corner_radius_top_left > 0 else 20)
	else:
		style.set_corner_radius_all(20)
	if dark:
		style.bg_color = get_theme_color("surface")
		style.border_color = Color(1, 1, 1, 0.10)
	else:
		style.bg_color = Color(1, 1, 1, 1)
		style.border_color = Color(0, 0, 0, 0.10)
	style.set_border_width_all(1)
	node.add_theme_stylebox_override("panel", style)


func _style_label(label: Label) -> void:
	var n := label.name
	if n.ends_with("Title") or n.ends_with("Header"):
		label.add_theme_color_override("font_color", get_theme_color("accent_bright"))
	elif n in DIM_LABELS:
		label.add_theme_color_override("font_color", get_theme_color("text_dim"))
	else:
		label.add_theme_color_override("font_color", get_theme_color("text"))


func _style_button(btn: Button) -> void:
	var colored := _button_has_colored_bg(btn)
	var fc: Color = Color(1, 1, 1) if colored else get_theme_color("text")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, fc)


func _button_has_colored_bg(btn: Button) -> bool:
	var st: StyleBox = btn.get_theme_stylebox("normal")
	if st is StyleBoxFlat:
		var c: Color = (st as StyleBoxFlat).bg_color
		var mx := maxf(maxf(c.r, c.g), c.b)
		var mn := minf(minf(c.r, c.g), c.b)
		# Saturated accents AND dark backgrounds both need light text.
		return c.a > 0.4 and ((mx - mn) > 0.25 or c.get_luminance() < 0.45)
	return false


# ══════════════════════════════════════════════════════════════
# UNIFIED HEADER BAR — one consistent look across every scene.
# Same shapes, same labels, same colors in Dark and Light.
# Only the look changes — button functions are untouched.
# ══════════════════════════════════════════════════════════════
const HEADER_BAR_NAMES := ["HeaderBar", "TopBar", "TopHeader", "TitleBar"]


func style_header(header: Node) -> void:
	if header == null or not (header is Control):
		return
	var dark := theme_is_dark()
	var accent := get_theme_color("accent")

	# 1) Bar background — rounded-bottom "pill" bar, theme surface.
	var bar := _header_bar_stylebox(dark, accent)
	if header is PanelContainer or header is Panel:
		header.add_theme_stylebox_override("panel", bar)
	elif header is Control and not (header is Container):
		# Plain-Control headers (Settings/AboutMe) get a background bar
		# inserted behind their floating content. (Container headers such as
		# BookMenu's TopBar are left as-is — a bg child would break their layout.)
		var bg: Panel = header.get_node_or_null("__HeaderBarBg") as Panel
		if bg == null:
			bg = Panel.new()
			bg.name = "__HeaderBarBg"
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header.add_child(bg)
			header.move_child(bg, 0)
		bg.add_theme_stylebox_override("panel", bar.duplicate())

	# 2) Normalise layout rhythm across every header (consistent spacing).
	#    Buttons are pinned to the LEFT (Back button always first) and title
	#    labels are pushed to the RIGHT — a unified layout across all scenes.
	if header is BoxContainer:
		# Container headers (TopBar rows) pin their buttons to the same left
		# position as every other scene; titles expand into the rest.
		var bc := header as BoxContainer
		bc.add_theme_constant_override("separation", 24)
		bc.alignment = BoxContainer.ALIGNMENT_BEGIN
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reorder_header_children(bc)
	for hb in header.find_children("*", "HBoxContainer", true, false):
		(hb as HBoxContainer).add_theme_constant_override("separation", 24)
		(hb as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		# Fill the whole bar so the title label can reach the far right edge
		# (some scenes ship SHRINK_CENTER, which centres the whole cluster).
		(hb as HBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reorder_header_children(hb)
	for hb in header.find_children("*", "VBoxContainer", true, false):
		(hb as VBoxContainer).add_theme_constant_override("separation", 10)

	# Header titles always expand and sit on the RIGHT (unified layout).
	for hl in header.find_children("*", "Label", true, false):
		if hl.name in ["HeaderTitle", "LessonTitle", "Title"]:
			(hl as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(hl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 3) Style every button + label inside the header subtree.
	var stack: Array = [header]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			_style_header_button(n)
		elif n is Label:
			_style_header_label(n)
		for c in n.get_children():
			stack.push_back(c)


func _reorder_header_children(bc: BoxContainer) -> void:
	# Unified header layout: every button pinned to the LEFT (Back button
	# first), then any in-between controls, then title labels pushed to the
	# RIGHT. Idempotent — safe to run on every scene change.
	var buttons: Array[Node] = []
	var others: Array[Node] = []
	var labels: Array[Node] = []
	for c in bc.get_children():
		if c is Button:
			buttons.append(c)
		elif c is Label:
			labels.append(c)
		else:
			others.append(c)
	if buttons.is_empty() and labels.is_empty():
		return
	# The Back button is always the first button from the left.
	var back_first: Array[Node] = []
	var rest: Array[Node] = []
	for b in buttons:
		if _header_button_kind(b as Button) == "back":
			back_first.append(b)
		else:
			rest.append(b)
	buttons = back_first + rest
	var ordered: Array[Node] = buttons + others + labels
	var idx := 0
	for c in ordered:
		bc.move_child(c, idx)
		idx += 1


func _header_bar_stylebox(dark: bool, accent: Color) -> StyleBoxFlat:
	# ── Glossy header bar: translucent glass, bright rim, violet-glow shadow ──
	var bar := StyleBoxFlat.new()
	bar.set_corner_radius_all(48)
	bar.corner_radius_top_left = 10
	bar.corner_radius_top_right = 10
	if dark:
		bar.bg_color = Color(0.06, 0.08, 0.16, 0.88)
	else:
		bar.bg_color = Color(1, 1, 1, 0.68)
	# Bright rim — thicker top/left catches the light.
	bar.border_width_left = 2; bar.border_width_top = 2
	bar.border_width_right = 1; bar.border_width_bottom = 3
	var rim: Color = accent.lerp(Color.WHITE, 0.50)
	rim.a = 0.70
	bar.border_color = rim
	# Strong accent glow underneath.
	bar.shadow_color = Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 0.60)
	bar.shadow_size = 24
	bar.shadow_offset = Vector2(0, 6)
	bar.content_margin_left = 30
	bar.content_margin_right = 30
	bar.content_margin_top = 16
	bar.content_margin_bottom = 12
	return bar

# Header buttons are flat icon buttons using the badge-style PNGs in
# res://images/. Every header button now has a dedicated icon — the
# translation toggle uses Translate.png instead of a text chip.
const HEADER_ICONS := {
	"back":        "res://images/Back.png",
	"home":        "res://images/Main_Menu.png",
	"audio":       "res://images/audio_play.png",
	"leitner":     "res://images/Leitner.png",
	"translation": "res://images/Translate.png",
}
const HEADER_BUTTON_SIZE := 168.0
const HEADER_TRANSLATION_LABEL := "ترجمه"

func _header_button_kind(btn: Button) -> String:
	var n := String(btn.name).to_lower()
	if n.contains("back"):
		return "back"
	if n.contains("home"):
		return "home"
	if n.contains("translation") or n.contains("toggle"):
		return "translation"
	if n.contains("leitner"):
		return "leitner"
	if n.contains("audio"):
		return "audio"
	return ""

func _style_header_button(btn: Button) -> void:
	var accent := get_theme_color("accent")
	var kind := _header_button_kind(btn)

	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# All header buttons are flat icon buttons — soft hover/press disc.
	btn.flat = true
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(HEADER_BUTTON_SIZE, HEADER_BUTTON_SIZE)
	btn.add_theme_constant_override("icon_max_width", int(HEADER_BUTTON_SIZE))
	btn.add_theme_constant_override("icon_max_height", int(HEADER_BUTTON_SIZE))
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.set_border_width_all(0)
	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(int(HEADER_BUTTON_SIZE / 2.0))
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	var press := StyleBoxFlat.new()
	press.set_corner_radius_all(int(HEADER_BUTTON_SIZE / 2.0))
	press.bg_color = Color(accent.r, accent.g, accent.b, 0.26)
	btn.add_theme_stylebox_override("normal", clear)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", press)
	btn.add_theme_stylebox_override("focus", hover)
	btn.icon = load(HEADER_ICONS[kind]) if HEADER_ICONS.has(kind) else null
	btn.text = ""


# Translation toggle is now an icon (Translate.png) — tint conveys on/off.
func set_translation_toggle_state(btn: Button, active: bool) -> void:
	if btn == null:
		return
	var accent := get_theme_color("accent")
	if active:
		btn.modulate = accent.lightened(0.35) if theme_is_dark() else accent
	else:
		btn.modulate = Color(1, 1, 1, 1)

func _style_header_label(label: Label) -> void:
	var c: Color = get_theme_color("accent_bright") if theme_is_dark() else get_theme_color("accent")
	if label.label_settings != null:
		label.label_settings.font_color = c
	label.add_theme_color_override("font_color", c)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return
	var data: Dictionary = json.data
	sound_enabled = bool(data.get("sound_enabled", true))
	tts_enabled = bool(data.get("tts_enabled", true))
	theme_mode = int(data.get("theme_mode", 0))


func save_settings() -> void:
	var data: Dictionary = {
		"sound_enabled": sound_enabled,
		"tts_enabled": tts_enabled,
		"theme_mode": theme_mode,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _ready() -> void:
	_load_saved_words()
	_load_review_words()
	_load_progress()
	# The 1 MB dictionary parse is deferred off the boot critical path (and
	# lazily loaded on first lookup) so startup doesn't freeze on it.
	call_deferred("_load_word_database")
	_load_settings()
	_init_tts() # You can keep or remove TTS init, keeping it for safety
	_setup_theme()

	# Style every scene as it becomes current (covers transitions and the
	# initial launch) so Dark / Light is consistent app-wide.
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_style_initial_scene")

	# Initialize AudioStreamPlayer for playing word audio files
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)


func _on_scene_changed() -> void:
	style_scene(get_tree().current_scene)


func _style_initial_scene() -> void:
	style_scene(get_tree().current_scene)

# ---------- LAST SCENE ----------

func set_last_scene(scene_path: String) -> void:
	_last_scene = scene_path
	_save_progress()


func get_last_scene() -> String:
	return _last_scene


func has_last_scene() -> bool:
	return _last_scene != ""


func _grammar_unlock_key(book: int, lesson: int) -> String:
	return "%d_%d" % [book, lesson]


func get_grammar_unlocked_units(book: int, lesson: int, total_units: int = 0) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	# Derive the unlock count from the completed set so reordering or editing
	# units in a lesson JSON can never leave a stale unlock count: each
	# completed unit grants one more unlocked unit (legacy index-based entries
	# still count, so old saves keep working).
	var completed: Array = grammar_completed_units.get(key, [])
	var unlocked: int = completed.size() + 1
	# Also honor any previously stored (legacy / deep-link) unlock value so
	# we never regress progress that was recorded before this derivation.
	var stored: int = int(grammar_unlocked_units.get(key, 1))
	unlocked = maxi(unlocked, stored)
	if total_units > 0:
		unlocked = clampi(unlocked, 1, total_units)
	else:
		unlocked = maxi(unlocked, 1)
	return unlocked


func set_grammar_unlocked_units(book: int, lesson: int, unlocked: int) -> void:
	var key: String = _grammar_unlock_key(book, lesson)
	var current: int = int(grammar_unlocked_units.get(key, 1))
	var next_value: int = maxi(current, unlocked)
	grammar_unlocked_units[key] = next_value
	_save_progress()


func set_grammar_start_unit(index: int) -> void:
	grammar_start_unit_index = maxi(index, 0)


# ---------- GRAMMAR XP ----------

func get_grammar_xp(book: int, lesson: int) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	return int(grammar_xp.get(key, 0))


# Adds earned XP for a lesson, persists it, and returns the new total.
func add_grammar_xp(book: int, lesson: int, amount: int) -> int:
	var key: String = _grammar_unlock_key(book, lesson)
	var total: int = int(grammar_xp.get(key, 0)) + maxi(amount, 0)
	grammar_xp[key] = total
	_save_progress()
	return total


func get_total_grammar_xp() -> int:
	var total := 0
	for value in grammar_xp.values():
		total += int(value)
	return total


# ---------- GRAMMAR COMPLETED UNITS ----------

func is_unit_completed(book: int, lesson: int, unit_index: int, unit_id: String = "") -> bool:
	var key: String = _grammar_unlock_key(book, lesson)
	var completed: Array = grammar_completed_units.get(key, [])
	# Match by stable id first (content edits / reorders stay consistent),
	# then fall back to the legacy index for old saves.
	if unit_id != "" and unit_id in completed:
		return true
	return unit_index in completed


func mark_unit_completed(book: int, lesson: int, unit_index: int, unit_id: String = "") -> void:
	var key: String = _grammar_unlock_key(book, lesson)
	var completed: Array = grammar_completed_units.get(key, [])
	if unit_id != "":
		if unit_id in completed:
			return
		# If the legacy index form is already present, upgrade it in place to
		# the stable id instead of appending a duplicate — the completed set
		# must stay a set so the unlock count (derived from its size) never
		# over-counts the same unit.
		var legacy_at := completed.find(unit_index)
		if legacy_at >= 0:
			completed[legacy_at] = unit_id
		else:
			completed.append(unit_id)
	else:
		if unit_index in completed:
			return
		completed.append(unit_index)
	grammar_completed_units[key] = completed
	_save_progress()


# ---------- PROGRESS PERSISTENCE ----------

func _save_progress() -> void:
	var data: Dictionary = {
		"last_scene": _last_scene,
		"grammar_unlocked_units": grammar_unlocked_units,
		"grammar_xp": grammar_xp,
		"grammar_completed_units": grammar_completed_units,
	}
	var file: FileAccess = FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var file: FileAccess = FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		_last_scene = str(data.get("last_scene", ""))
		var unlocked: Variant = data.get("grammar_unlocked_units", {})
		if unlocked is Dictionary:
			grammar_unlocked_units = unlocked
		var xp_data: Variant = data.get("grammar_xp", {})
		if xp_data is Dictionary:
			grammar_xp = xp_data
		var completed_data: Variant = data.get("grammar_completed_units", {})
		if completed_data is Dictionary:
			grammar_completed_units = completed_data


func _load_saved_words() -> void:
	if not FileAccess.file_exists(SAVED_WORDS_PATH):
		saved_words = []
		return

	var file := FileAccess.open(SAVED_WORDS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) == OK and json.data is Array:
		saved_words = json.data
	else:
		saved_words = []

func _load_review_words() -> void:
	if not FileAccess.file_exists(REVIEW_WORDS_PATH):
		review_words = []
		return

	var file := FileAccess.open(REVIEW_WORDS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(text) == OK and json.data is Array:
		review_words = json.data
	else:
		review_words = []

func _persist_saved_words() -> void:
	var file := FileAccess.open(SAVED_WORDS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved_words))
	file.close()

func _persist_review_words() -> void:
	var file := FileAccess.open(REVIEW_WORDS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(review_words))
	file.close()

func is_word_saved(word: String, book: int, lesson: int) -> bool:
	for entry in saved_words:
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			return true
	return false


func save_word(word_data: Dictionary) -> void:

	if is_word_saved(
		word_data.get("word"),
		word_data.get("book"),
		word_data.get("lesson")
	):
		return

	var copy = word_data.duplicate(true)

	saved_words.append(copy)
	add_review_word(copy)

	_persist_saved_words()


func remove_word(word: String, book: int, lesson: int) -> void:
	for i in range(saved_words.size()):
		var entry = saved_words[i]
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			saved_words.remove_at(i)
			break
	_persist_saved_words()
	# Keep the review queue in sync so it never holds orphaned words.
	_remove_from_array(review_words, word, book, lesson)
	_persist_review_words()
	review_words_changed.emit()


func _remove_from_array(arr: Array, word: String, book: int, lesson: int) -> void:
	for i in range(arr.size()):
		var entry: Variant = arr[i]
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			arr.remove_at(i)
			return


func get_saved_words() -> Array:
	return saved_words.duplicate(true)


func add_review_word(word_data: Dictionary) -> void:

	for entry in review_words:
		if entry.get("word") == word_data.get("word") \
		and entry.get("book") == word_data.get("book") \
		and entry.get("lesson") == word_data.get("lesson"):
			return

	review_words.append(word_data.duplicate(true))
	_persist_review_words()
	review_words_changed.emit()

func remove_review_word(word:String, book:int, lesson:int) -> void:
	# A word removed from the review list is also removed from saved words —
	# the two stay in sync so neither array keeps orphans.
	_remove_from_array(review_words, word, book, lesson)
	_remove_from_array(saved_words, word, book, lesson)
	_persist_review_words()
	_persist_saved_words()
	review_words_changed.emit()


func get_review_words() -> Array:
	return review_words.duplicate(true)


# ---------- DATA MANAGEMENT (used by the Settings screen) ----------

func clear_saved_words() -> void:
	saved_words.clear()
	review_words.clear()
	_persist_saved_words()
	_persist_review_words()
	review_words_changed.emit()


func clear_review_words() -> void:
	review_words.clear()
	saved_words.clear()
	_persist_review_words()
	_persist_saved_words()
	review_words_changed.emit()


func reset_all_progress() -> void:
	saved_words.clear()
	review_words.clear()
	grammar_unlocked_units.clear()
	grammar_xp.clear()
	grammar_completed_units.clear()
	_last_scene = ""
	_persist_saved_words()
	_persist_review_words()
	_save_progress()
	review_words_changed.emit()


# ---------- ENHANCED WORD DATABASE ----------

func _load_word_database(force := false) -> void:
	"""Load every word from the single unified dictionary file into the database"""
	if _word_db_loaded and not force:
		return
	word_database.clear()
	verb_forms.clear()

	if not FileAccess.file_exists(DICTIONARY_PATH):
		push_error("Dictionary file not found: " + DICTIONARY_PATH)
		return

	var file := FileAccess.open(DICTIONARY_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Failed to parse v_dictionary.json — %s" % json.get_error_message())
		return

	var data = json.data
	if not data is Array:
		push_error("Invalid v_dictionary.json format: expected a flat array of word objects")
		return

	for word_obj in data:
		var word: String = word_obj.get("word", "")
		if word == "":
			continue

		var key := word.to_lower()
		if word_database.has(key):
			continue  # keep the first occurrence if a word appears twice

		var word_data := {
	"word": word,
	"pronunciation": word_obj.get("pronunciation", ""),
	"meaning_en": word_obj.get("meaning_en", ""),
	"meaning_fa": word_obj.get("meaning_fa", ""),
	"example": word_obj.get("example", ""),
	"synonyms": word_obj.get("synonyms", {}),
	"antonyms": word_obj.get("antonyms", {}),
	"word_type": word_obj.get("word_type", "noun"),
	"countable": word_obj.get("countable", null),
	"verb_forms": word_obj.get("verb_forms", {}),
	"audio": word_obj.get("audio", ""),
	"phonetics": word_obj.get("phonetics", "")
}
		word_database[key] = word_data

		if word_data["word_type"] == "verb":
			var forms = word_data["verb_forms"]
			var base_word: String = word_data["word"]
			if forms.has("past"): verb_forms[forms["past"].to_lower()] = base_word
			if forms.has("past_participle"): verb_forms[forms["past_participle"].to_lower()] = base_word
			if forms.has("present_participle"): verb_forms[forms["present_participle"].to_lower()] = base_word
			if forms.has("third_person"): verb_forms[forms["third_person"].to_lower()] = base_word

	print("Word database loaded: %d words" % word_database.size())
	_word_db_loaded = true


func get_word_definition(word: String) -> Dictionary:
	"""Get definition for a word from the database"""
	if not _word_db_loaded:
		_load_word_database()
	if word == "":
		return {}

	var key = word.to_lower()

	# Try exact match
	if word_database.has(key):
		return word_database[key]

	# Check if it's a verb form
	if verb_forms.has(key):
		var base_word = verb_forms[key]
		if word_database.has(base_word.to_lower()):
			return word_database[base_word.to_lower()]

	# Try removing plural 's' for nouns
	if key.ends_with("s") and len(key) > 1:
		var singular = key.trim_suffix("s")
		if word_database.has(singular):
			return word_database[singular]
		# Check if it's a verb form with 's'
		if verb_forms.has(singular):
			var base_word = verb_forms[singular]
			if word_database.has(base_word.to_lower()):
				return word_database[base_word.to_lower()]

	# Try removing 'ing' for verbs
	if key.ends_with("ing") and len(key) > 3:
		var base = key.trim_suffix("ing")
		if word_database.has(base):
			return word_database[base]
		if verb_forms.has(base):
			var base_word = verb_forms[base]
			if word_database.has(base_word.to_lower()):
				return word_database[base_word.to_lower()]

	# Try removing 'ed' for past tense
	if key.ends_with("ed") and len(key) > 2:
		var base = key.trim_suffix("ed")
		if word_database.has(base):
			return word_database[base]
		if verb_forms.has(base):
			var base_word = verb_forms[base]
			if word_database.has(base_word.to_lower()):
				return word_database[base_word.to_lower()]

	# Try removing 'ly' for adverbs
	if key.ends_with("ly") and len(key) > 2:
		var base = key.trim_suffix("ly")
		if word_database.has(base):
			return word_database[base]

	# Try removing 'er' for comparatives
	if key.ends_with("er") and len(key) > 2:
		var base = key.trim_suffix("er")
		if word_database.has(base):
			return word_database[base]

	# Try removing 'est' for superlatives
	if key.ends_with("est") and len(key) > 3:
		var base = key.trim_suffix("est")
		if word_database.has(base):
			return word_database[base]

	return {}


func get_word_definition_from_current_lesson(word: String) -> Dictionary:
	"""Look up a word in the unified dictionary, then tag it with the
	book/lesson the student is currently viewing — so saved words still
	remember where they were learned, and the SRS system still works."""
	var definition := get_word_definition(word)
	if definition.is_empty():
		return {}

	var tagged := definition.duplicate(true)
	tagged["book"] = current_book
	tagged["lesson"] = current_lesson
	return tagged

func reload_word_database() -> void:
	"""Reload the word database"""
	_load_word_database(true)


# ---------- UI HELPERS ----------

func button_bounce(button: Control, shrink_to: float = 0.92, duration: float = 0.08) -> void:
	if button.pivot_offset == Vector2.ZERO:
		button.pivot_offset = button.size / 2.0

	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(shrink_to, shrink_to), duration)
	tween.tween_property(button, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ============================================================
#  SPACED REPETITION SYSTEM (simplified SM-2 / Anki-style)
# ============================================================

const SRS_NEW_CARDS_PER_SESSION := 20


func _today_day_number() -> int:
	# Local-time day number (not UTC) so a "due today" review rolls over at
	# local midnight rather than UTC midnight.
	var local := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict(local) / 86400.0)


func _ensure_srs_fields(entry: Dictionary) -> void:
	if not entry.has("srs_interval"):
		entry["srs_interval"] = 0.0
	if not entry.has("srs_ease"):
		entry["srs_ease"] = 2.5
	if not entry.has("srs_reps"):
		entry["srs_reps"] = 0
	if not entry.has("srs_due"):
		entry["srs_due"] = -1   # -1 means "new, never studied"


func get_due_words() -> Array:
	var today := _today_day_number()
	var reviews: Array = []
	var new_cards: Array = []

	for entry in review_words:
		_ensure_srs_fields(entry)
		if entry["srs_due"] == -1:
			new_cards.append(entry)            # never studied yet
		elif entry["srs_due"] <= today:
			reviews.append(entry)              # due for review

	# Due reviews always come first; new cards follow, capped per session.
	var due: Array = []
	due.append_array(reviews)
	var shown_new := 0
	for entry in new_cards:
		if shown_new >= SRS_NEW_CARDS_PER_SESSION:
			break
		due.append(entry)
		shown_new += 1

	return due

func load_category(category: String, book: int, lesson: int) -> Dictionary:
	if not _category_cache.has(category):
		var path := "res://data/%s.json" % category
		if not FileAccess.file_exists(path):
			push_warning("Category file not found: " + path)
			return {}
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK:
			push_error("JSON error in " + path)
			return {}
		file.close()
		_category_cache[category] = json.data
	
	var data: Dictionary = _category_cache[category]
	return data.get("books", {}).get(str(book), {}).get(str(lesson), {})

func _compute_srs_result(entry: Dictionary, rating: String) -> Dictionary:
	var ease_factor: float = entry.get("srs_ease", 2.5)
	var interval: float = entry.get("srs_interval", 0.0)
	var reps: int        = entry.get("srs_reps", 0)
	var today := _today_day_number()

	var new_ease := ease_factor
	var new_interval := interval
	var new_reps := reps

	match rating:
		"again":
			new_reps = 0
			new_ease = max(1.3, ease_factor - 0.2)
			new_interval = 0.0
		"hard":
			new_ease = max(1.3, ease_factor - 0.15)
			new_interval = max(1.0, (interval if interval > 0 else 1.0) * 1.2)
			new_reps = reps + 1
		"good":
			if reps == 0:
				new_interval = 1.0
			elif reps == 1:
				new_interval = 3.0
			else:
				new_interval = interval * ease_factor
			new_reps = reps + 1
		"easy":
			if reps == 0:
				new_interval = 2.0
			else:
				new_interval = interval * ease_factor * 1.3
			new_ease = ease_factor + 0.15
			new_reps = reps + 1

	var new_due: int
	if rating == "again":
		new_due = today
	else:
		new_due = today + int(ceil(new_interval))

	return {
		"ease": new_ease,
		"interval": new_interval,
		"reps": new_reps,
		"due": new_due
	}


func review_word(word: String, book: int, lesson: int, rating: String) -> void:
	if not rating in ["again", "hard", "good", "easy"]:
		return
	var result: Dictionary = {}
	for entry in saved_words:
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			_ensure_srs_fields(entry)
			result = _compute_srs_result(entry, rating)
			entry["srs_ease"]     = result["ease"]
			entry["srs_interval"] = result["interval"]
			entry["srs_reps"]     = result["reps"]
			entry["srs_due"]      = result["due"]
			break
	_persist_saved_words()
	if result.is_empty():
		return
	# Keep the review queue (the source of get_due_words) in sync so the SRS
	# schedule actually controls when the word comes back. NOTE: we do NOT
	# emit review_words_changed here — the WordReview scene manages its own
	# in-session queue and would re-enter _populate_list() and skip cards.
	_sync_srs_to_review_words(word, book, lesson, result)
	_persist_review_words()


func _sync_srs_to_review_words(word: String, book: int, lesson: int, result: Dictionary) -> void:
	for entry in review_words:
		if entry.get("word") == word and entry.get("book") == book and entry.get("lesson") == lesson:
			entry["srs_ease"]     = result["ease"]
			entry["srs_interval"] = result["interval"]
			entry["srs_reps"]     = result["reps"]
			entry["srs_due"]      = result["due"]
			return


func preview_intervals(entry: Dictionary) -> Dictionary:
	_ensure_srs_fields(entry)
	var result := {}
	for rating in ["again", "hard", "good", "easy"]:
		var r := _compute_srs_result(entry, rating)
		result[rating] = _format_interval(r["interval"], rating)
	return result


func _format_interval(interval: float, rating: String) -> String:
	if rating == "again":
		return "چند دقیقه دیگر"
	var days := int(round(interval))
	if days < 1:
		return "امروز"
	elif days == 1:
		return "۱ روز"
	else:
		return "%d روز" % days

func play_word_audio(audio_filename: String, word_text: String = "") -> void:
	# 1. If no audio filename is provided in the JSON, fallback to TTS immediately
	if audio_filename.is_empty():
		if word_text != "":
			speak_word(word_text)
		return
		
	var path: String = "res://assets/audio/Vocabularies/%s" % audio_filename
		
	# 2. Check if the file actually exists in the project
	if not ResourceLoader.exists(path):
		push_warning("Audio file not found: " + path + ". Falling back to TTS.")
		if word_text != "":
			speak_word(word_text)
		return
		
	# 3. Try to load and play the audio file
	var stream = load(path)
	if stream is AudioStream:
		if audio_player.playing:
			audio_player.stop() # Stop current audio if it's still playing
		audio_player.stream = stream
		audio_player.play()
	else:
		# 4. Fallback if the file exists but fails to load (e.g., corrupted file)
		push_error("Failed to load audio stream from: " + path + ". Falling back to TTS.")
		if word_text != "":
			speak_word(word_text)

func _init_tts() -> void:
	# Ask the OS directly for English voices.
	# (kept untyped on purpose — the return type differs between Godot versions)
	var en_voices = DisplayServer.tts_get_voices_for_language("en")
	if en_voices.size() > 0:
		english_voice_id = _extract_voice_id(en_voices[0])

	# Fallback: scan every installed voice and pick an English one.
	if english_voice_id == "":
		var all_voices = DisplayServer.tts_get_voices()
		for voice in all_voices:
			var voice_id := _extract_voice_id(voice)
			var voice_lang := _extract_voice_language(voice).to_lower()

			var is_english := false
			if voice_lang != "":
				is_english = voice_lang.begins_with("en")
			else:
				is_english = "en" in voice_id.to_lower()

			if is_english and voice_id != "":
				english_voice_id = voice_id
				break

	if english_voice_id == "":
		# Not an error: speech is an optional feature. Some devices (and lean
		# desktop installs) have no TTS voices, so the app just runs without
		# audio. Log once (informational) instead of raising a warning.
		print("[TTS] No English voice available on this device; pronunciation/speech disabled. Install a TTS voice to enable it.")


# ------------------------------------------------------------
# In Godot 4.7, DisplayServer.tts_get_voices() returns an
# Array of Dictionaries (one Dictionary per voice), not plain
# String IDs. These helpers safely pull out the voice ID and
# language whether the entry is a Dictionary or a plain String.
# ------------------------------------------------------------
func _extract_voice_id(voice: Variant) -> String:
	if voice is Dictionary:
		# Try the most common key names for the voice identifier.
		for key in ["id", "identifier", "voice_id", "name"]:
			if voice.has(key):
				return str(voice[key])
		return ""
	return str(voice)


func _extract_voice_language(voice: Variant) -> String:
	if voice is Dictionary:
		for key in ["language", "lang", "locale"]:
			if voice.has(key):
				return str(voice[key])
		return ""
	return str(voice)

# On some devices the TTS engine is not ready at autoload time,
# so give voice detection a second chance right before speaking.
func ensure_english_voice() -> void:
	if english_voice_id == "":
		_init_tts()


func speak_word(text: String) -> void:
	if text.is_empty():
		return
	if not tts_enabled:
		return

	# Retry voice detection in case it failed at startup.
	ensure_english_voice()
	if english_voice_id == "":
		return

	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()

	# Real tts_speak() signature: (text, voice, volume, pitch, rate, utterance_id, interrupt)
	# volume is 0..100. The previous version had these shifted one slot over,
	# which put 0 into the volume slot (mute) and 100.0 into pitch (way out of range).
	DisplayServer.tts_speak(
		text,
		english_voice_id,
		100,  # volume (max, 0-100)
		1.0,    # pitch
		1.0,    # rate (normal speed)
		0,      # utterance_id
		true    # interrupt anything currently speaking
	)
