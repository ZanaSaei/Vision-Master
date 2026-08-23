class_name ThemeManager
extends Node
## ══════════════════════════════════════════════════════════════
##  THEME MANAGER  (autoload "ThemeManager")
##
##  Owns the app's Dark / Light theme system.
##  - Builds and applies a complete base `Theme` to the scene tree
##    root, so every control that relies on the default theme (the
##    bulk of the content scenes) follows the active mode with the
##    correct font colors.
##  - Retints the app-wide animated background (MenuBackground).
##  - Exposes a semantic color palette via get_color(role) so custom
##    scenes can style themselves dynamically.
##  - Persists the chosen mode through Global's settings.json.
##
##  Dark and Light are "universe" palettes: bright text on dark
##  surfaces for DARK, dark text on light surfaces for LIGHT.
## ══════════════════════════════════════════════════════════════

signal theme_changed(mode: int)

enum ThemeMode { DARK, LIGHT }

const FONT := "res://assets/fonts/Vazirmatn-Regular.ttf"

var mode: int = ThemeMode.DARK

# Current active palette (a Dictionary of named roles -> Color).
var palette: Dictionary = {}

var _theme: Theme = Theme.new()
var _font: Font

## Static handle to the running singleton (set in _ready). Exposed as a
## global class so scripts can call it without the editor having refreshed
## its autoload global-name table.
static var instance: ThemeManager = null


# ── static accessors (class-callable) ─────────────────────────
static func get_singleton() -> ThemeManager:
	return instance


static func get_color(role: String) -> Color:
	if instance != null:
		return instance.palette.get(role, Color.WHITE)
	return Color.WHITE


static func is_dark() -> bool:
	return instance == null or instance.mode == ThemeMode.DARK


static func set_mode(new_mode: int) -> void:
	if instance != null:
		instance._set_mode(new_mode)


static func on_theme_changed(callback: Callable) -> void:
	if instance != null:
		instance.theme_changed.connect(callback)


# ── Palettes ───────────────────────────────────────────────────
const PALETTES := {
	ThemeMode.DARK: {
		"bg":            Color(0.055, 0.062, 0.125),      # deep indigo-navy
		"surface":       Color(0.088, 0.102, 0.20),       # cards
		"surface_alt":   Color(0.135, 0.150, 0.29),       # raised / buttons
		"border":        Color(1, 1, 1, 0.10),
		"text":          Color(0.90, 0.915, 1.0),
		"text_dim":      Color(0.60, 0.63, 0.82),
		"accent":        Color(0.545, 0.361, 0.965),      # #8B5CF6
		"accent_bright": Color(0.80, 0.66, 1.0),
		"accent_soft":   Color(0.545, 0.361, 0.965, 0.16),
		"on_accent":     Color(1, 1, 1, 1),
		"success":       Color(0.30, 0.84, 0.60),
		"error":         Color(1.0, 0.40, 0.46),
		"warning":       Color(1.0, 0.80, 0.36),
		"overlay":       Color(0, 0, 0, 0.6),
		# animated background — violet→indigo gradient
		"bg_base":       Color(0.028, 0.036, 0.11),
		"wave_top":      Color(0.32, 0.21, 0.66),
		"wave_mid":      Color(0.20, 0.24, 0.66),
		"wave_bottom":   Color(0.09, 0.12, 0.42),
	},
	ThemeMode.LIGHT: {
		"bg":            Color(0.955, 0.960, 0.99),       # soft periwinkle
		"surface":       Color(1, 1, 1, 1),               # cards
		"surface_alt":   Color(0.90, 0.912, 0.97),
		"border":        Color(0.10, 0.11, 0.25, 0.14),
		"text":          Color(0.10, 0.115, 0.23),        # deep indigo
		"text_dim":      Color(0.36, 0.39, 0.55),
		"accent":        Color(0.40, 0.26, 0.92),         # violet
		"accent_bright": Color(0.50, 0.36, 1.0),
		"accent_soft":   Color(0.40, 0.26, 0.92, 0.10),
		"on_accent":     Color(1, 1, 1, 1),
		"success":       Color(0.12, 0.60, 0.42),
		"error":         Color(0.86, 0.20, 0.32),
		"warning":       Color(0.84, 0.58, 0.04),
		"overlay":       Color(0.05, 0.06, 0.16, 0.35),
		# animated background — lavender gradient
		"bg_base":       Color(0.92, 0.925, 0.99),
		"wave_top":      Color(0.60, 0.55, 0.98),
		"wave_mid":      Color(0.74, 0.66, 1.0),
		"wave_bottom":   Color(0.84, 0.82, 1.0),
	},
}


func _ready() -> void:
	instance = self
	_font = load(FONT) as Font
	# Read the persisted mode (0 = dark, 1 = light).
	mode = int(Global.theme_mode)
	if mode != ThemeMode.DARK and mode != ThemeMode.LIGHT:
		mode = ThemeMode.DARK
	palette = PALETTES[mode]
	_rebuild_theme()
	_apply_to_background()
	_apply_to_root()


func _set_mode(new_mode: int) -> void:
	if new_mode != ThemeMode.DARK and new_mode != ThemeMode.LIGHT:
		new_mode = ThemeMode.DARK
	if new_mode == mode:
		return
	mode = new_mode
	palette = PALETTES[mode]
	_rebuild_theme()
	_apply_to_background()
	_apply_to_root()
	# Persist through the app's settings owner.
	Global.theme_mode = mode
	Global.save_settings()
	theme_changed.emit(mode)


# ══════════════════════════════════════════════════════════════
#  THEME CONSTRUCTION
# ══════════════════════════════════════════════════════════════
func _rebuild_theme() -> void:
	var t := Theme.new()
	t.default_font = _font
	t.default_font_size = 34

	var bg: Color = palette["bg"]
	var surface: Color = palette["surface"]
	var alt: Color = palette["surface_alt"]
	var border: Color = palette["border"]
	var text: Color = palette["text"]
	var dim: Color = palette["text_dim"]
	var accent: Color = palette["accent"]
	var on_accent: Color = palette["on_accent"]

	# --- Labels & generic text ---
	t.set_color("font_color", "Label", text)
	t.set_color("font_hover_color", "Label", text)
	t.set_color("font_focus_color", "Label", text)
	t.set_color("font_selected_color", "Label", text)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 0)

	# --- Buttons (default) ---
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
	btn_hover.bg_color = accent_lerp(alt, accent, 0.18)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = accent_lerp(alt, accent, 0.3)

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

	# --- Panels ---
	for ptype in ["Panel", "PanelContainer"]:
		var p := StyleBoxFlat.new()
		p.bg_color = surface
		p.border_color = border
		p.set_border_width_all(1)
		p.set_corner_radius_all(20)
		t.set_stylebox("panel", ptype, p)

	# --- Scroll containers (transparent, so surfaces show through) ---
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0, 0, 0, 0)
	t.set_stylebox("panel", "ScrollContainer", sc)

	# --- Scrollbars ---
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

	# --- LineEdit ---
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

	# --- OptionButton / CheckButton / CheckBox text ---
	t.set_color("font_color", "OptionButton", text)
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_color", "CheckBox", text)
	t.set_color("font_hover_color", "CheckButton", text)
	t.set_color("font_hover_color", "CheckBox", text)

	# --- Tabs ---
	t.set_color("font_color", "TabContainer", text)
	t.set_color("font_selected_color", "TabContainer", accent)

	# --- ProgressBar ---
	t.set_color("font_color", "ProgressBar", text)
	t.set_color("font_color", "RichTextLabel", text)
	t.set_color("default_color", "RichTextLabel", text)

	# --- HSeparator / VSeparator ---
	var sep := StyleBoxLine.new()
	sep.color = border
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", sep)

	# --- Tooltip ---
	var tip := StyleBoxFlat.new()
	tip.bg_color = alt
	tip.border_color = border
	tip.set_border_width_all(1)
	tip.set_corner_radius_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", text)

	_theme = t


func _apply_to_root() -> void:
	if is_inside_tree():
		get_tree().root.theme = _theme


func _apply_to_background() -> void:
	if not is_inside_tree():
		return
	call_deferred("_apply_to_background_deferred")


func _apply_to_background_deferred() -> void:
	var mb: Node = get_tree().root.get_node_or_null("MenuBackground")
	if mb == null or not mb.has_method("apply_theme"):
		return
	mb.apply_theme(
		palette["bg_base"],
		palette["wave_top"],
		palette["wave_bottom"]
	)


# ── helpers ───────────────────────────────────────────────────
func accent_bright() -> Color:
	return palette["accent_bright"]


func accent_lerp(from: Color, to: Color, t: float) -> Color:
	return from.lerp(to, t)