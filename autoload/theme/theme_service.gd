extends Node
class_name ThemeService
## ============================================================
##  THEME SERVICE — the app-wide Light-only theme engine.
##
##  Owns the fixed Light palette, base Theme resource and styling collaborators.
##  Global owns one of us and forwards its public API, so every
##  existing call-site keeps working unchanged.
##
##  DECOMPOSITION (this file used to be 810 lines doing all four jobs):
##    * palette + mode + Theme resource life-cycle   → this file
##    * generic scene styling walk                   → theme/scene_style_walk.gd
##    * unified header bar engine                    → theme/header_bar_styler.gd
##    * the StyleBoxes / type styles themselves      → res://resources/styleboxes
##                                                     res://resources/themes
##
##  The base Theme is a real .tres resource instead of being assembled in code,
##  so the app's typography, colours and component
##  styles are editable in the Inspector. Regenerate the resources with
##  tools/generate_design_resources.gd when a DesignTokens value changes.
## ============================================================

signal theme_changed(mode: int)


const THEME_LIGHT_PATH := "res://resources/themes/vision_master_light.tres"

## The app is permanently styled with the Light palette.
const THEME_PALETTE := DesignTokens.PALETTE_LIGHT

## Explicit preloads rather than the global class names: these siblings are
## built during boot, and a preload keeps the reference resolvable regardless of
## when the editor's class cache is refreshed.
const HeaderStyler := preload("res://autoload/theme/header_bar_styler.gd")
const SceneStyler := preload("res://autoload/theme/scene_style_walk.gd")

## Height of the header bar, in pixels. Re-exported for callers that lay content
## out below the bar; the canonical value lives in the header engine.
const HEADER_BAR_HEIGHT := HeaderStyler.BAR_HEIGHT

var theme_palette: Dictionary = DesignTokens.PALETTE_LIGHT
var _theme: Theme

var _header_styler: HeaderStyler = HeaderStyler.new()
var _scene_styler: SceneStyler = SceneStyler.new()
var _mode_applied := false


func theme_is_dark() -> bool:
	return false


func get_theme_color(role: String) -> Color:
	return theme_palette.get(role, Color.WHITE)


func on_theme_changed(callback: Callable) -> void:
	theme_changed.connect(callback)


## Base Theme for shared components (already applied to the tree root).
func get_base_theme() -> Theme:
	return _theme


func set_theme_mode(_new_mode: int) -> void:
	# Compatibility shim: the app has a fixed Light appearance.
	_activate_theme()
	theme_changed.emit(1)


func setup() -> void:
	_activate_theme()


## Loads the sole Light Theme, pushes its context into the styling collaborators,
## and applies it to the root.
func _activate_theme() -> void:
	theme_palette = THEME_PALETTE
	_header_styler.set_context(false, theme_palette)
	_scene_styler.setup(false, theme_palette, _header_styler)

	_theme = load(THEME_LIGHT_PATH) as Theme
	if _theme == null:
		push_warning("ThemeService: could not load the Light theme resource; using an empty theme.")
		_theme = Theme.new()

	_mode_applied = true
	_apply_theme_to_root()


func _apply_theme_to_root() -> void:
	if is_inside_tree():
		get_tree().root.theme = _theme


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
