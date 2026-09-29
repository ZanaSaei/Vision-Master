extends Node
class_name ThemeService
## ============================================================
##  THEME SERVICE — the app-wide Dark / Light theme engine.
##
##  Owns the active palette, the base Theme resource and the two styling
##  collaborators. Global owns one of us and forwards its public API, so every
##  existing call-site keeps working unchanged.
##
##  DECOMPOSITION (this file used to be 810 lines doing all four jobs):
##    * palette + mode + Theme resource life-cycle   → this file
##    * generic scene styling walk                   → theme/scene_style_walk.gd
##    * unified header bar engine                    → theme/header_bar_styler.gd
##    * the StyleBoxes / type styles themselves      → res://resources/styleboxes
##                                                     res://resources/themes
##
##  The base Theme is now a real .tres resource per mode instead of being
##  assembled in code, so the whole app's typography, colours and component
##  styles are editable in the Inspector. Regenerate the resources with
##  tools/generate_design_resources.gd when a DesignTokens value changes.
## ============================================================

signal theme_changed(mode: int)

enum ThemeMode { DARK, LIGHT }

const THEME_DIR := "res://resources/themes/"
const THEME_DARK_PATH := THEME_DIR + "vision_master_dark.tres"
const THEME_LIGHT_PATH := THEME_DIR + "vision_master_light.tres"

## The palette lives in DesignTokens — see DesignTokens.PALETTE_DARK/LIGHT.
## DARK  — the reference design: soft-UI charcoal, cream paper, gold rim, blue.
## LIGHT — the same language inverted onto warm paper.
const THEME_PALETTES := {
	ThemeMode.DARK: DesignTokens.PALETTE_DARK,
	ThemeMode.LIGHT: DesignTokens.PALETTE_LIGHT,
}

## Explicit preloads rather than the global class names: these siblings are
## built during boot, and a preload keeps the reference resolvable regardless of
## when the editor's class cache is refreshed.
const HeaderStyler := preload("res://autoload/theme/header_bar_styler.gd")
const SceneStyler := preload("res://autoload/theme/scene_style_walk.gd")

## Height of the header bar, in pixels. Re-exported for callers that lay content
## out below the bar; the canonical value lives in the header engine.
const HEADER_BAR_HEIGHT := HeaderStyler.BAR_HEIGHT

var theme_mode: int = ThemeMode.DARK
var theme_palette: Dictionary = {}
var _theme: Theme

var _header_styler: HeaderStyler = HeaderStyler.new()
var _scene_styler: SceneStyler = SceneStyler.new()
var _mode_applied := false


func theme_is_dark() -> bool:
	return theme_mode == ThemeMode.DARK


func get_theme_color(role: String) -> Color:
	return theme_palette.get(role, Color.WHITE)


func on_theme_changed(callback: Callable) -> void:
	theme_changed.connect(callback)


## Base Theme for shared components (already applied to the tree root).
func get_base_theme() -> Theme:
	return _theme


func set_theme_mode(new_mode: int) -> void:
	if new_mode != ThemeMode.DARK and new_mode != ThemeMode.LIGHT:
		new_mode = ThemeMode.DARK
	if new_mode == theme_mode and _mode_applied:
		return
	theme_mode = new_mode
	_activate_theme()
	theme_changed.emit(theme_mode)


func setup(initial_mode: int) -> void:
	if initial_mode != ThemeMode.DARK and initial_mode != ThemeMode.LIGHT:
		initial_mode = ThemeMode.DARK
	theme_mode = initial_mode
	_activate_theme()


## Loads the mode's Theme resource, pushes the context into the collaborators
## and applies the result. One code path for boot and for a live toggle, so the
## two can never diverge.
func _activate_theme() -> void:
	theme_palette = THEME_PALETTES[theme_mode]
	var dark := theme_is_dark()
	_header_styler.set_context(dark, theme_palette)
	_scene_styler.setup(dark, theme_palette, _header_styler)

	_theme = load(THEME_DARK_PATH if dark else THEME_LIGHT_PATH) as Theme
	if _theme == null:
		# The generated resources are missing (a fresh clone before the tool has
		# run). Fall back to a bare Theme so the app still boots instead of
		# crashing on a null root theme.
		push_warning("ThemeService: could not load the %s theme resource; using an empty theme."
			% ("dark" if dark else "light"))
		_theme = Theme.new()

	_mode_applied = true
	_apply_theme_to_root()
	_apply_theme_to_background()


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
#  STYLING ENTRY POINTS (delegated)
# ══════════════════════════════════════════════════════════════

func scene_handles_own_theme(root: Node) -> bool:
	return _scene_styler.scene_handles_own_theme(root)


func style_scene(root: Node) -> void:
	_scene_styler.style_scene(root)


func style_header(header: Node) -> void:
	_header_styler.style_header(header)


func set_translation_toggle_state(btn: Button, active: bool) -> void:
	_header_styler.set_translation_toggle_state(btn, active)


## Static forwarder: GrammarTheme builds its own header row and needs the
## canonical layout without holding a ThemeService reference.
static func layout_header_row(row: BoxContainer) -> void:
	HeaderStyler.layout_row(row)
