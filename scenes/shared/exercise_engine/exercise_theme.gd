# ============================================================
# ExerciseEngine - theme palette + live theme-aware colors.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# ============================================================
class_name ExerciseTheme

# ---------- Theme ----------
const C_PRIMARY := Color("#2F6FD8")   # DesignTokens.ACCENT — primary action, check buttons
const C_SUCCESS := Color("#2E8B57")   # DesignTokens.SUCCESS
const C_ERROR   := Color("#C0392B")   # DesignTokens.ERROR
const C_TEXT    := Color("#2F2C26")   # Design light type (dark ink)
const C_MUTED   := Color("#6E6A61")   # Design muted text
const C_SURFACE := Color("#FFFFFF")   # Design surface
const C_TINT    := Color("#FAF7F0")   # Design surface_alt (fallback bg)
const C_BORDER  := Color(0.235, 0.196, 0.118, 0.14) # Design border
const C_WARNING := Color("#B8860B")   # Design warning
const C_INFO    := Color("#2F6FD8")   # Design bright blue
const C_PURPLE  := Color("#7D52A0")   # Mauve (audio button)
const C_ORANGE  := Color("#C86040")   # Coral (sample answer button)

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
	return g.call("get_theme_color", "surface") if g != null else C_SURFACE

static func _c_surface_alt() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "surface_alt") if g != null else C_TINT

static func _c_border() -> Color:
	var g: Object = _global()
	return g.call("get_theme_color", "border") if g != null else C_BORDER

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
