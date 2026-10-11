class_name ThemeSceneStyler
extends RefCounted
## ============================================================
##  THEME SCENE STYLER — the generic Dark / Light scene walk.
##
##  Split out of ThemeService. Walks any scene and restyles its Controls so
##  Dark / Light stays consistent app-wide. Scenes that already implement their
##  own theme walk (settings, about_me, the grammar system, the menu screens)
##  are skipped, otherwise they would be styled twice.
##
##  This collaborator is a pure function of its context — it holds no autoload
##  reference and builds no styleboxes of its own: every box it applies comes
##  from res://resources/styleboxes/, so the look is editable in the Inspector.
## ============================================================

const STYLEBOX_DIR := "res://resources/styleboxes/"

## Explicit preload rather than the global class name: this collaborator and the
## header engine are siblings created at boot, and a preload keeps the reference
## resolvable regardless of when the editor's class cache is refreshed.
const HeaderStyler := preload("res://autoload/theme/header_bar_styler.gd")

## Scenes that theme themselves. Matched on the script's file name so a file
## move does not silently start double-styling a screen.
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
	"spelling_game.gd",
	"scrambled_words.gd",
	"gameplay.gd",
	"mode_select.gd",
	"lesson_select.gd",
	"results.gd",
]

## Labels that read better muted in both themes.
const DIM_LABELS := [
	"Subtitle", "Hint", "ContactHint", "VersionValue", "CreditLabel",
	"SubName", "DevName", "VersionName",
]

## Labels that paint their OWN background colour and therefore decide their own
## font colour (e.g. the exercise engine's single-letter badge: white type on a
## dark square). The walk must leave these alone, otherwise it would force the
## theme's text colour on top and the glyph would vanish into the square.
## Opt in with `add_to_group(ThemeSceneStyler.KEEP_FONT_COLOR_GROUP)`.
const KEEP_FONT_COLOR_GROUP := "keep_font_color"

var _dark: bool = true
var _palette: Dictionary = {}
## The header engine, so a header bar met during the walk is handed to the one
## component that knows how to lay it out.
var _header: HeaderStyler = null


func setup(dark: bool, palette: Dictionary, header_styler: HeaderStyler) -> void:
	_dark = dark
	_palette = palette
	_header = header_styler


func _color(role: String) -> Color:
	return _palette.get(role, Color.WHITE)


func _sb(file_base: String) -> StyleBox:
	var suffix := "dark" if _dark else "light"
	return load(STYLEBOX_DIR + "%s_%s.tres" % [file_base, suffix])


# ══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════

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
	# BottomNavigation owns a bespoke visual design. Leave its complete subtree
	# alone so app-wide card styling cannot overwrite its scene-authored styles.
	if node.name == "BottomNavigation":
		return
	if node is CanvasLayer:
		return
	if node is PageView:
		return
	if node is GrammarHint:
		return
	if node.name in HeaderStyler.HEADER_BAR_NAMES and node is Control:
		if _header != null:
			_header.style_header(node)
		return

	if node is ColorRect:
		_style_background_rect(node)
	# Panel appearance is scene-authored. Do not apply shared card styles here;
	# each scene can now configure its own Panel/PanelContainer in its scene file.
	elif node is PanelContainer or node is Panel:
		pass
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
	# Keep the scene's own alpha so a translucent scrim stays translucent.
	cr.color = Color(_color("bg"), cr.color.a)


## A PanelContainer that merely WRAPS a header bar (some scenes nest one) must
## not paint a card behind it.
func _is_header_bar_panel(node: Node) -> bool:
	for c in node.get_children():
		if c.name in HeaderStyler.HEADER_BAR_NAMES:
			return true
	return false


func _hide_header_bar_panel(node: Control) -> void:
	var s: StyleBoxFlat = (_sb("panel_transparent") as StyleBoxFlat).duplicate() as StyleBoxFlat
	s.border_color = Color(0, 0, 0, 0)
	s.set_border_width_all(0)
	s.content_margin_left = HeaderStyler.PAD_X
	s.content_margin_right = HeaderStyler.PAD_X
	s.content_margin_top = HeaderStyler.PAD_Y
	s.content_margin_bottom = HeaderStyler.PAD_Y
	node.add_theme_stylebox_override("panel", s)


func _style_card(node: Node) -> void:
	# A scene-authored panel keeps its own padding and corner radius (only the
	# radius is clamped up to the smallest design-system step) but takes its
	# colors from the shared card stylebox, so every box in the app matches the
	# shell and a single .tres edit moves them all at once.
	var old: StyleBox = node.get_theme_stylebox("panel")
	var style: StyleBoxFlat = (_sb("card") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if old is StyleBoxFlat:
		var of := old as StyleBoxFlat
		style.content_margin_left = of.content_margin_left
		style.content_margin_top = of.content_margin_top
		style.content_margin_right = of.content_margin_right
		style.content_margin_bottom = of.content_margin_bottom
		if of.corner_radius_top_left > 0:
			style.set_corner_radius_all(of.corner_radius_top_left)
	node.add_theme_stylebox_override("panel", style)


func _style_label(label: Label) -> void:
	# A label that wears its own coloured background (see KEEP_FONT_COLOR_GROUP)
	# keeps the font colour its creator chose.
	if label.is_in_group(KEEP_FONT_COLOR_GROUP):
		return
	var n := label.name
	if n.ends_with("Title") or n.ends_with("Header"):
		label.add_theme_color_override("font_color", _color("accent_bright"))
	elif n in DIM_LABELS:
		label.add_theme_color_override("font_color", _color("text_dim"))
	else:
		label.add_theme_color_override("font_color", _color("text"))


func _style_button(btn: Button) -> void:
	# A button that brought its OWN coloured background needs its label forced
	# to white, because the design system's state colours assume a cream or an
	# accent fill.
	#
	# A button that uses the SHARED design must NOT be overridden: the theme
	# already supplies ink-on-cream for the resting state and white-on-blue for
	# hover/pressed. Forcing one colour here used to put near-white type on the
	# cream pill in the Dark theme — unreadable — so the override is applied
	# only where a custom background actually demands it.
	if _button_has_colored_bg(btn):
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(state, Color(1, 1, 1))


func _button_has_colored_bg(btn: Button) -> bool:
	var st: StyleBox = btn.get_theme_stylebox("normal")
	if st is StyleBoxFlat:
		var c: Color = (st as StyleBoxFlat).bg_color
		var mx := maxf(maxf(c.r, c.g), c.b)
		var mn := minf(minf(c.r, c.g), c.b)
		return c.a > 0.4 and ((mx - mn) > 0.25 or c.get_luminance() < 0.45)
	return false
