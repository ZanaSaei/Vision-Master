extends Node
class_name ThemeService
## ============================================================
##  THEME SERVICE — the app-wide Dark / Light theme engine.
##
##  Owns the palette, the base Theme resource, the generic scene-styling
##  walk, and the unified header bar. This block (plus its styling helpers
## below) used to live inside the Global god-object; Global now owns one of
## us and forwards its public API so every existing call-site keeps working.
## ============================================================

signal theme_changed(mode: int)

enum ThemeMode { DARK, LIGHT }

var theme_mode: int = ThemeMode.DARK
var theme_palette: Dictionary = {}
var _theme: Theme = Theme.new()
var _theme_font: Font

const THEME_FONT := "res://assets/fonts/Vazirmatn-Regular.ttf"
# ---------------------------------------------------------------
# DARK  — Modern Deep Slate & Vibrant Neon Indigo
# ---------------------------------------------------------------
# LIGHT — Crisp Clean White & Playful Punchy Indigo
# ---------------------------------------------------------------
const THEME_PALETTES := {
	ThemeMode.DARK: {
		"bg":            Color("#0F172A"),
		"surface":       Color("#1E293B"),
		"surface_alt":   Color("#334155"),
		"border":        Color(1, 1, 1, 0.12),
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


## Base Theme for shared components (already applied to the tree root).
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
	theme_changed.emit(theme_mode)


func setup(initial_mode: int) -> void:
	_theme_font = load(THEME_FONT) as Font
	if initial_mode != ThemeMode.DARK and initial_mode != ThemeMode.LIGHT:
		initial_mode = ThemeMode.DARK
	theme_mode = initial_mode
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
	"spelling_game.gd",
	"scrambled_words.gd",
	"gameplay.gd",
	"mode_select.gd",
	"lesson_select.gd",
	"results.gd",
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
	if node is CanvasLayer:
		return
	if node is PageView:
		return
	if node is GrammarHint:
		return
	if node.name in HEADER_BAR_NAMES and node is Control:
		style_header(node)
		return

	if node is ColorRect:
		_style_background_rect(node)
	elif node is PanelContainer or node is Panel:
		if _is_header_bar_panel(node):
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
		return c.a > 0.4 and ((mx - mn) > 0.25 or c.get_luminance() < 0.45)
	return false
# ══════════════════════════════════════════════════════════════
# UNIFIED HEADER BAR — one consistent look across every scene.
# Same shapes, same labels, same colors in Dark and Light.
# Same GEOMETRY too: every bar is HEADER_BAR_HEIGHT tall with HEADER_PAD_*
# padding, and every header row carries its items in the same order at the
# same positions:
#     [back][home][leading]      title (centred)      [translation][audio][leitner]
# ══════════════════════════════════════════════════════════════
const HEADER_BAR_NAMES := ["HeaderBar", "TopBar", "TopHeader", "TitleBar"]
# Height of the bar itself, in pixels (all scenes author 320 in their .tscn).
const HEADER_BAR_HEIGHT := 320.0
# Distance from the bar's left/right edge to the first item.
const HEADER_PAD_X := 30.0
# Distance from the bar's top/bottom edge to the row (kept symmetric so the
# items are exactly centred vertically).
const HEADER_PAD_Y := 24.0
# Gap between two items in the header row.
const HEADER_ITEM_GAP := 16.0
# Names of the nodes the row layout rebuilds on every pass.
const HEADER_LEADING_NAME := "HeaderLeading"
const HEADER_TRAILING_NAME := "HeaderTrailing"
const HEADER_FLEX_NAME := "HeaderFlex"


func style_header(header: Node) -> void:
	if header == null:
		return
	var accent := get_theme_color("accent")
	var dark := theme_is_dark()

	# Style the items first: the layout below measures them, so every button
	# must already carry its final (uniform) size when the row is rebuilt.
	var stack: Array = [header]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			_style_header_button(n)
		elif n is Label:
			_style_header_label(n)
		for c in n.get_children():
			stack.push_back(c)

	var row := find_header_row(header)
	var inner := header_inner_margin(header, row)
	if header is PanelContainer or header is Panel:
		var bar := _header_bar_stylebox(dark, accent)
		if inner != null:
			# A MarginContainer owns the padding in this header, so the bar
			# itself must not add any — otherwise the two would stack up, and
			# a scene that later swaps the stylebox would shift its items.
			bar.content_margin_left = 0.0
			bar.content_margin_right = 0.0
			bar.content_margin_top = 0.0
			bar.content_margin_bottom = 0.0
		header.add_theme_stylebox_override("panel", bar)

	normalize_header_geometry(header, inner)
	layout_header_row(row)


# ── Geometry ──────────────────────────────────────────────────
## The header's content row: the shallowest BoxContainer under `header` that
## directly holds header items (a button or a label).
static func find_header_row(header: Node) -> BoxContainer:
	if header == null:
		return null
	for child in header.get_children():
		if child is BoxContainer:
			for item in child.get_children():
				if item is BaseButton or item is Label:
					return child as BoxContainer
		var deeper := find_header_row(child)
		if deeper != null:
			return deeper
	return null


## The MarginContainer sitting between the bar and its row. The menu screens
## build one, the .tscn lesson screens do not. Null when there is none.
static func header_inner_margin(header: Node, row: Node) -> MarginContainer:
	if header == null or row == null:
		return null
	var found: MarginContainer = null
	var node := row.get_parent()
	while node != null and node != header:
		if node is MarginContainer:
			found = node as MarginContainer
		node = node.get_parent()
	return found


## Pins the bar to the canonical height and makes exactly one element own the
## padding, so the first item always sits HEADER_PAD_X from the left edge and
## the row is vertically centred in the bar.
func normalize_header_geometry(header: Node, inner: MarginContainer) -> void:
	var bar := header as Control
	if bar == null:
		return
	if bar.get_parent() is Container:
		# Built inside a layout (grammar screens): the flow owns the width,
		# so only the height is pinned.
		bar.custom_minimum_size.y = HEADER_BAR_HEIGHT
	else:
		bar.anchor_left = 0.0
		bar.anchor_top = 0.0
		bar.anchor_right = 1.0
		bar.anchor_bottom = 0.0
		bar.offset_left = 0.0
		bar.offset_top = 0.0
		bar.offset_right = 0.0
		bar.offset_bottom = HEADER_BAR_HEIGHT
		bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bar.grow_vertical = Control.GROW_DIRECTION_END
	if inner != null:
		inner.add_theme_constant_override("margin_left", int(HEADER_PAD_X))
		inner.add_theme_constant_override("margin_right", int(HEADER_PAD_X))
		inner.add_theme_constant_override("margin_top", int(HEADER_PAD_Y))
		inner.add_theme_constant_override("margin_bottom", int(HEADER_PAD_Y))

# ── Row layout ────────────────────────────────────────────────
## Rebuilds a header row into the app-wide order:
##   [back][home][leading]   <title, centred>   [translation][audio][leitner]
## Both sides get the SAME fixed width, so the title stays exactly centred on
## the bar no matter which side buttons a scene hides or shows later.
static func layout_header_row(row: BoxContainer) -> void:
	if row == null:
		return
	_unwrap_header_row(row)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", int(HEADER_ITEM_GAP))
	# Scenes author this row either shrink-centred (the .tscn lesson screens)
	# or expanding (the menu screens); pin it so the row always spans the bar
	# and the left edge is the same pixel column everywhere.
	row.size_flags_horizontal = Control.SIZE_FILL
	row.size_flags_vertical = Control.SIZE_FILL

	var back_group: Array[Node] = []
	var leading: Array[Node] = []
	var trailing: Array[Node] = []
	var title: Node = null
	for child in row.get_children():
		if _is_header_spacer_placeholder(child):
			# Placeholder Controls some scenes use to fake spacing — the row
			# below spaces itself, so they are dropped.
			(child as Control).visible = false
			continue
		var kind := _header_button_kind(child) if child is BaseButton else ""
		if kind == "back":
			back_group.append(child)
		elif kind == "home":
			leading.append(child)
		elif kind == "translation" or kind == "audio" or kind == "leitner":
			trailing.append(child)
		elif title == null and _is_header_title(child):
			title = child
		elif title == null:
			leading.append(child)
		else:
			trailing.append(child)

	# The back button is always the first item on the left, whatever order the
	# scene authored its header in.
	var left: Array[Node] = []
	for b in back_group:
		left.append(b)
	for l in leading:
		left.append(l)
	leading = left

	if title == null:
		# Nothing to centre: pack the leading items left, the rest right.
		for child in leading:
			_detach_from_parent(child)
			row.add_child(child)
		if not leading.is_empty() and not trailing.is_empty():
			var flex := Control.new()
			flex.name = HEADER_FLEX_NAME
			flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(flex)
		for child in trailing:
			_detach_from_parent(child)
			row.add_child(child)
		return

	var side := maxf(_row_side_width(leading), _row_side_width(trailing))
	var lead_wrap := _make_header_side(leading, HEADER_LEADING_NAME, BoxContainer.ALIGNMENT_BEGIN, side)
	var trail_wrap := _make_header_side(trailing, HEADER_TRAILING_NAME, BoxContainer.ALIGNMENT_END, side)
	_center_header_title(title)
	row.add_child(lead_wrap)
	_detach_from_parent(title)
	row.add_child(title)
	row.add_child(trail_wrap)
	# Pin the order explicitly: any dropped placeholder is left behind the
	# canonical three so the row reads the same in every scene.
	row.move_child(lead_wrap, 0)
	row.move_child(title, 1)
	row.move_child(trail_wrap, 2)


static func _make_header_side(items: Array[Node], wrap_name: String, align: BoxContainer.AlignmentMode, side: float) -> HBoxContainer:
	var side_wrap := HBoxContainer.new()
	side_wrap.name = wrap_name
	side_wrap.alignment = align
	side_wrap.size_flags_vertical = Control.SIZE_FILL
	side_wrap.add_theme_constant_override("separation", int(HEADER_ITEM_GAP))
	side_wrap.custom_minimum_size.x = side
	for item in items:
		_detach_from_parent(item)
		side_wrap.add_child(item)
	return side_wrap


## A node can only be re-parented after it has been detached.
static func _detach_from_parent(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)


static func _center_header_title(title: Node) -> void:
	if title is Label:
		var direct := title as Label
		direct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		direct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		direct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return
	var el := title as Control
	if el == null:
		return
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	el.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nested := _first_label(el)
	if nested == null:
		return
	nested.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nested.size_flags_horizontal = Control.SIZE_FILL
	if not (el is Container):
		# A plain Control (title + spacer) has no minimum size of its own, so
		# give it the label's so the centred slot keeps the right width.
		el.custom_minimum_size.x = maxf(el.custom_minimum_size.x, nested.get_combined_minimum_size().x)


## Moves the wrappers built by a previous pass back into the row so the next
## pass classifies again from scratch (theme switches re-apply the header).
static func _unwrap_header_row(row: BoxContainer) -> void:
	for child in row.get_children():
		if child.name != HEADER_LEADING_NAME and child.name != HEADER_TRAILING_NAME:
			continue
		var side_wrap := child as HBoxContainer
		if side_wrap == null:
			continue
		for item in side_wrap.get_children():
			side_wrap.remove_child(item)
			row.add_child(item)
		row.remove_child(side_wrap)
		side_wrap.queue_free()
	for child in row.get_children():
		if child.name == HEADER_FLEX_NAME:
			row.remove_child(child)
			child.queue_free()


static func _row_side_width(items: Array[Node]) -> float:
	var total := 0.0
	for item in items:
		var c := item as Control
		if c != null:
			total += c.get_combined_minimum_size().x
	if items.size() > 1:
		total += HEADER_ITEM_GAP * float(items.size() - 1)
	return total


## A spacer Control (not a button or label) with no children of its own.
static func _is_header_spacer_placeholder(node: Node) -> bool:
	if node is BaseButton or node is Label:
		return false
	var c := node as Control
	return c != null and c.get_child_count() == 0


## The title is the row's text: a Label, or the container/spacer that holds it.
static func _is_header_title(node: Node) -> bool:
	if node is Label:
		return true
	if node is BaseButton:
		return false
	if not (node is Control):
		return false
	return _first_label(node) != null and not _has_button(node)


static func _first_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child as Label
		var deeper := _first_label(child)
		if deeper != null:
			return deeper
	return null


static func _has_button(node: Node) -> bool:
	for child in node.get_children():
		if child is BaseButton:
			return true
		if _has_button(child):
			return true
	return false




func _header_bar_stylebox(dark: bool, accent: Color) -> StyleBoxFlat:
	var bar := StyleBoxFlat.new()
	bar.set_corner_radius_all(48)
	bar.corner_radius_top_left = 10
	bar.corner_radius_top_right = 10
	if dark:
		bar.bg_color = Color(0.06, 0.08, 0.16, 0.88)
	else:
		bar.bg_color = Color("#BFDBFE")
	bar.border_width_left = 2; bar.border_width_top = 2
	bar.border_width_right = 1; bar.border_width_bottom = 3
	var rim: Color = accent.lerp(Color.WHITE, 0.50)
	rim.a = 0.70
	bar.border_color = rim
	bar.shadow_color = Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 0.60)
	bar.shadow_size = 24
	bar.shadow_offset = Vector2(0, 6)
	# Symmetric padding so the row sits exactly in the middle of the bar; the
	# canonical values are shared with normalize_header_geometry().
	bar.content_margin_left = HEADER_PAD_X
	bar.content_margin_right = HEADER_PAD_X
	bar.content_margin_top = HEADER_PAD_Y
	bar.content_margin_bottom = HEADER_PAD_Y
	return bar


const HEADER_ICONS := {
	"back":        "res://images/Back.png",
	"home":        "res://images/Main_Menu.png",
	"audio":       "res://images/audio_play.png",
	"leitner":     "res://images/Leitner.png",
	"translation": "res://images/Translate.png",
}
const HEADER_BUTTON_SIZE := 168.0
const HEADER_TRANSLATION_LABEL := "ترجمه"


static func _header_button_kind(btn: Node) -> String:
	var n := String(btn.name).to_lower()
	if n.contains("back"):
		return "back"
	if n.contains("home") or n.contains("menu"):
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
	# Only the recognised header buttons get the app icons; an unknown button
	# keeps whatever icon/text its scene gave it.
	if HEADER_ICONS.has(kind):
		btn.icon = load(HEADER_ICONS[kind])
		btn.text = ""


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