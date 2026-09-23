# ============================================================
# ExerciseEngine - theme palette + live theme-aware colors.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# ============================================================
class_name ExerciseTheme

# ---------- Theme ----------
const C_PRIMARY := Color("#4C8DF6")   # Design blue — primary action, check buttons
const C_SUCCESS := Color("#5FBF7F")   # Design green
const C_ERROR   := Color("#E06C75")   # Design red
const C_TEXT    := Color("#E7E5E0")   # Design light type
const C_MUTED   := Color("#A6A49D")   # Design muted
const C_TINT    := Color("#24272D")   # Design page (fallback bg)
const C_WARNING := Color("#E0B96B")   # Design amber
const C_INFO    := Color("#7FB2FF")   # Design bright blue
const C_PURPLE  := Color("#A98BB8")   # Mauve (audio button)
const C_ORANGE  := Color("#D97A6C")   # Coral (sample answer button)

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
