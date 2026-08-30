# ============================================================
# ExerciseEngine - theme palette + live theme-aware colors.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# ============================================================
class_name ExerciseTheme

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
static func _global() -> Object:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("Global")
	return null

static func _c_surface() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "surface") if g != null else C_TINT

static func _c_surface_alt() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "surface_alt") if g != null else C_TINT

static func _c_border() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "border") if g != null else C_MUTED

static func _c_text() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "text") if g != null else C_TEXT

static func _c_text_dim() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "text_dim") if g != null else C_MUTED

static func _c_success() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "success") if g != null else C_SUCCESS

static func _c_error() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "error") if g != null else C_ERROR

static func _c_warning() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "warning") if g != null else C_WARNING
