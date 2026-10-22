class_name UiTheme
extends RefCounted
## ============================================================
##  UI THEME — tiny optional helper for the flexible design system.
##
##  This is NOT a universal component and NOT an autoload. It only
##  forwards to the existing theme engine (Global / ThemeService) so
##  any scene can read the active palette without coupling its
##  structure to a base script.
##
##  Use it when a custom element wants semantic colors or a shared
##  StyleBox. Ignore it when the element is a deliberate exception
##  (book covers, game gradients, nav-bar shader).
##
##  Canonical resources (do NOT duplicate):
##    Theme     res://resources/themes/vision_master_light.tres
##    Styles    res://resources/styleboxes/*.tres  (~90 files)
##    New only  res://ui/styles_flex/danger_light.tres
##    Tokens    DesignTokens (palette + radius/border/shadow/space)
##              TypeScale at res://resources/typography/type_scale.tres
##    Motion    res://resources/motion/*.tres via UiMotion
## ============================================================

const STYLEBOX_DIR := "res://resources/styleboxes/"
const UI_STYLE_DIR := "res://ui/styles_flex/"


## Compatibility check; the app always uses the Light appearance.
static func is_dark() -> bool:
	if is_instance_valid(Global):
		return Global.theme_is_dark()
	return false


## One semantic palette role, e.g. "text", "accent", "surface", "error".
## Falls back to white when the role is unknown (same as ThemeService).
static func color(role: String) -> Color:
	if is_instance_valid(Global):
		return Global.get_theme_color(role)
	return DesignTokens.color_of(is_dark(), role)


## Loads a shared mode-specific StyleBox, e.g. stylebox("button_primary")
## -> res://resources/styleboxes/button_primary_light.tres.
## Returns a duplicate-safe resource: duplicate() before editing corners.
static func stylebox(file_base: String) -> StyleBox:
	var suffix := "light"
	var path := "%s%s_%s.tres" % [STYLEBOX_DIR, file_base, suffix]
	if ResourceLoader.exists(path):
		return load(path) as StyleBox
	return null


## Loads a mode-independent shared StyleBox (e.g. "panel_transparent").
static func stylebox_plain(file_base: String) -> StyleBox:
	var path := "%s%s.tres" % [STYLEBOX_DIR, file_base]
	if ResourceLoader.exists(path):
		return load(path) as StyleBox
	return null


## Loads a style from the small UI/Styles/ additions (danger treatment).
static func ui_style(file_base: String) -> StyleBox:
	var suffix := "light"
	var path := "%s%s_%s.tres" % [UI_STYLE_DIR, file_base, suffix]
	if ResourceLoader.exists(path):
		return load(path) as StyleBox
	return null


## Applies the shared button skin to an EXISTING scene-authored Button.
## Text, layout and sizing stay owned by the scene/Inspector.
## kind: "primary" (blue) | "default" (cream + gold rim) | "danger" (red).
static func style_button(btn: Button, kind: String = "primary") -> void:
	var dark := is_dark()
	match kind:
		"primary":
			btn.add_theme_stylebox_override("normal", stylebox("button_primary"))
			btn.add_theme_stylebox_override("hover", stylebox("button_primary_hover"))
			btn.add_theme_stylebox_override("pressed", stylebox("button_pressed"))
			btn.add_theme_stylebox_override("focus", stylebox("button_focus"))
			btn.add_theme_color_override("font_color", DesignTokens.button_text_color("hover", dark))
			btn.add_theme_color_override("font_hover_color", DesignTokens.button_text_color("hover", dark))
		"danger":
			var danger := ui_style("danger")
			if danger != null:
				btn.add_theme_stylebox_override("normal", danger)
				btn.add_theme_stylebox_override("hover", danger)
				btn.add_theme_stylebox_override("pressed", danger)
				btn.add_theme_stylebox_override("focus", danger)
			btn.add_theme_color_override("font_color", color("on_accent"))
		_:
			btn.add_theme_stylebox_override("normal", stylebox("button_default"))
			btn.add_theme_stylebox_override("hover", stylebox("button_hover"))
			btn.add_theme_stylebox_override("pressed", stylebox("button_pressed"))
			btn.add_theme_stylebox_override("focus", stylebox("button_focus"))
			btn.add_theme_color_override("font_color", DesignTokens.button_text_color("default", dark))


## Connects a scene's _apply_theme-style callback to Global.theme_changed
## and returns the Callable so the scene can disconnect it in _exit_tree.
## Usage: in _ready: _theme_cb = UiTheme.watch(_apply_theme)
##        in _exit_tree: UiTheme.unwatch(_theme_cb)
static func watch(callback: Callable) -> Callable:
	if is_instance_valid(Global):
		Global.on_theme_changed(callback)
	return callback


## Disconnects a callback previously connected via watch().
static func unwatch(callback: Callable) -> void:
	if is_instance_valid(Global) and callback.is_valid():
		if Global.theme_changed.is_connected(callback):
			Global.theme_changed.disconnect(callback)
