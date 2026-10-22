class_name HeaderBarStyler
extends RefCounted
## ============================================================
##  HEADER BAR STYLER — the app-wide header bar engine.
##
##  Split out of ThemeService (which had grown to own the palette, the scene
##  walk AND the header engine). This collaborator owns exactly one thing:
##  given a Control in the scene that is a header bar, style it and lay its
##  items out in the app-wide order
##
##      [back][home][leading]   title (centred)   [translation][audio][leitner]
##
##  It is a pure function of its context: it never reaches for an autoload, so
##  it can be exercised in isolation. Call `set_context()` whenever the theme
##  mode changes.
##
##  Every colour and geometry value comes from DesignTokens / the shared
##  stylebox and texture resources — nothing visual is defined here.
## ============================================================

const STYLEBOX_DIR := "res://resources/styleboxes/"

const HEADER_BAR_NAMES := ["HeaderBar", "TopBar", "TopHeader", "TitleBar"]
## Height of the bar itself, in pixels (all scenes author 320 in their .tscn).
const BAR_HEIGHT := 320.0
## Distance from the bar's left/right edge to the first item.
const PAD_X := 30.0
## Distance from the bar's top/bottom edge to the row (kept symmetric so the
## items are exactly centred vertically).
const PAD_Y := 24.0
## Gap between two items in the header row.
const ITEM_GAP := 16.0
## Names of the nodes the row layout rebuilds on every pass.
const LEADING_NAME := "HeaderLeading"
const TRAILING_NAME := "HeaderTrailing"
const FLEX_NAME := "HeaderFlex"

## Square size every header item is pinned to, so the row reads identically in
## every scene no matter which buttons that scene happens to show.
const BUTTON_SIZE := 168.0
const TRANSLATION_LABEL := "ترجمه"

## Canonical icons per recognised header button. Keys are produced by
## `_button_kind()` from the button's own name.
const ICONS := {
	"back":        "res://assets/images/ui/Back.png",
	"home":        "res://assets/images/ui/Main_Menu.png",
	"audio":       "res://assets/images/ui/audio_play.png",
	"leitner":     "res://assets/images/ui/Leitner.png",
	"translation": "res://assets/images/ui/Translate.png",
}

var _dark: bool = false
var _palette: Dictionary = {}


## Pushes the active theme context in. Must be called before any styling, and
## again on every Dark / Light switch.
func set_context(dark: bool, palette: Dictionary) -> void:
	_dark = dark
	_palette = palette


func _color(role: String) -> Color:
	return _palette.get(role, Color.WHITE)


func _sb(file_base: String) -> StyleBox:
	var suffix := "light"
	return load(STYLEBOX_DIR + "%s_%s.tres" % [file_base, suffix])


## Mode-independent stylebox — a transparent body is the same in both themes.
func _sb_plain(file_base: String) -> StyleBox:
	return load(STYLEBOX_DIR + "%s.tres" % file_base)


# ══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════

func style_header(header: Node) -> void:
	if header == null:
		return

	# Style the items first: the layout below measures them, so every button
	# must already carry its final (uniform) size when the row is rebuilt.
	var stack: Array = [header]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			_style_button(n)
		elif n is Label:
			_style_label(n)
		for c in n.get_children():
			stack.push_back(c)

	var row := find_row(header)
	var inner := inner_margin(header, row)
	if header is PanelContainer or header is Panel:
		var bar := _bar_stylebox()
		if inner != null:
			# A MarginContainer owns the padding in this header, so the bar
			# itself must not add any — otherwise the two would stack up, and
			# a scene that later swaps the stylebox would shift its items.
			bar.content_margin_left = 0.0
			bar.content_margin_right = 0.0
			bar.content_margin_top = 0.0
			bar.content_margin_bottom = 0.0
		header.add_theme_stylebox_override("panel", bar)

	normalize_geometry(header, inner)
	layout_row(row)


# ══════════════════════════════════════════════════════════════
#  GEOMETRY
# ══════════════════════════════════════════════════════════════

## The header's content row: the shallowest BoxContainer under `header` that
## directly holds header items (a button or a label).
static func find_row(header: Node) -> BoxContainer:
	if header == null:
		return null
	for child in header.get_children():
		if child is BoxContainer:
			for item in child.get_children():
				if item is BaseButton or item is Label:
					return child as BoxContainer
		var deeper := find_row(child)
		if deeper != null:
			return deeper
	return null


## The MarginContainer sitting between the bar and its row. The menu screens
## build one, the .tscn lesson screens do not. Null when there is none.
static func inner_margin(header: Node, row: Node) -> MarginContainer:
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
## padding, so the first item always sits PAD_X from the left edge and the row
## is vertically centred in the bar.
static func normalize_geometry(header: Node, inner: MarginContainer) -> void:
	var bar := header as Control
	if bar == null:
		return
	if bar.get_parent() is Container:
		# Built inside a layout (grammar screens): the flow owns the width,
		# so only the height is pinned.
		bar.custom_minimum_size.y = BAR_HEIGHT
	else:
		bar.anchor_left = 0.0
		bar.anchor_top = 0.0
		bar.anchor_right = 1.0
		bar.anchor_bottom = 0.0
		bar.offset_left = 0.0
		bar.offset_top = 0.0
		bar.offset_right = 0.0
		bar.offset_bottom = BAR_HEIGHT
		bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bar.grow_vertical = Control.GROW_DIRECTION_END
	if inner != null:
		inner.add_theme_constant_override("margin_left", int(PAD_X))
		inner.add_theme_constant_override("margin_right", int(PAD_X))
		inner.add_theme_constant_override("margin_top", int(PAD_Y))
		inner.add_theme_constant_override("margin_bottom", int(PAD_Y))


# ══════════════════════════════════════════════════════════════
#  ROW LAYOUT
# ══════════════════════════════════════════════════════════════

## Rebuilds a header row into the app-wide order. Both sides get the SAME
## fixed width, so the title stays exactly centred on the bar no matter which
## side buttons a scene hides or shows later.
static func layout_row(row: BoxContainer) -> void:
	if row == null:
		return
	_unwrap_row(row)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", int(ITEM_GAP))
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
		if _is_spacer_placeholder(child):
			# Placeholder Controls some scenes use to fake spacing — the row
			# below spaces itself, so they are dropped.
			(child as Control).visible = false
			continue
		var kind := _button_kind(child) if child is BaseButton else ""
		if kind == "back":
			back_group.append(child)
		elif kind == "home":
			leading.append(child)
		elif kind == "translation" or kind == "audio" or kind == "leitner":
			trailing.append(child)
		elif title == null and _is_title(child):
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
			_detach(child)
			row.add_child(child)
		if not leading.is_empty() and not trailing.is_empty():
			var flex := Control.new()
			flex.name = FLEX_NAME
			flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(flex)
		for child in trailing:
			_detach(child)
			row.add_child(child)
		return

	var side := maxf(_side_width(leading), _side_width(trailing))
	var lead_wrap := _make_side(leading, LEADING_NAME, BoxContainer.ALIGNMENT_BEGIN, side)
	var trail_wrap := _make_side(trailing, TRAILING_NAME, BoxContainer.ALIGNMENT_END, side)
	_center_title(title)
	row.add_child(lead_wrap)
	_detach(title)
	row.add_child(title)
	row.add_child(trail_wrap)
	# Pin the order explicitly: any dropped placeholder is left behind the
	# canonical three so the row reads the same in every scene.
	row.move_child(lead_wrap, 0)
	row.move_child(title, 1)
	row.move_child(trail_wrap, 2)


static func _make_side(items: Array[Node], wrap_name: String, align: BoxContainer.AlignmentMode, side: float) -> HBoxContainer:
	var side_wrap := HBoxContainer.new()
	side_wrap.name = wrap_name
	side_wrap.alignment = align
	side_wrap.size_flags_vertical = Control.SIZE_FILL
	side_wrap.add_theme_constant_override("separation", int(ITEM_GAP))
	side_wrap.custom_minimum_size.x = side
	for item in items:
		_detach(item)
		side_wrap.add_child(item)
	return side_wrap


## A node can only be re-parented after it has been detached.
static func _detach(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)


static func _center_title(title: Node) -> void:
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
static func _unwrap_row(row: BoxContainer) -> void:
	for child in row.get_children():
		if child.name != LEADING_NAME and child.name != TRAILING_NAME:
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
		if child.name == FLEX_NAME:
			row.remove_child(child)
			child.queue_free()


static func _side_width(items: Array[Node]) -> float:
	var total := 0.0
	for item in items:
		var c := item as Control
		if c != null:
			total += c.get_combined_minimum_size().x
	if items.size() > 1:
		total += ITEM_GAP * float(items.size() - 1)
	return total


## A spacer Control (not a button or label) with no children of its own.
static func _is_spacer_placeholder(node: Node) -> bool:
	if node is BaseButton or node is Label:
		return false
	var c := node as Control
	return c != null and c.get_child_count() == 0


## The title is the row's text: a Label, or the container/spacer that holds it.
static func _is_title(node: Node) -> bool:
	if node is Label:
		return true
	var c := node as Control
	if c == null or c.get_child_count() == 0:
		return false
	if node is BaseButton:
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


# ══════════════════════════════════════════════════════════════
#  ITEM STYLING
# ══════════════════════════════════════════════════════════════

## One bar look for the whole app: square top shoulders (it meets the screen
## edge), rounded bottom, a gold hairline underline and a soft drop shadow.
func _bar_stylebox() -> StyleBoxFlat:
	var bar := _sb("header_bar").duplicate() as StyleBoxFlat
	# Symmetric padding so the row sits exactly in the middle of the bar; the
	# canonical values are shared with normalize_geometry().
	bar.content_margin_left = PAD_X
	bar.content_margin_right = PAD_X
	bar.content_margin_top = PAD_Y
	bar.content_margin_bottom = PAD_Y
	return bar


## Which canonical header role a button plays, inferred from its node name.
static func _button_kind(btn: Node) -> String:
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


func _style_button(btn: Button) -> void:
	var kind := _button_kind(btn)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.flat = true
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.add_theme_constant_override("icon_max_width", int(BUTTON_SIZE))
	btn.add_theme_constant_override("icon_max_height", int(BUTTON_SIZE))
	btn.add_theme_stylebox_override("normal", _sb_plain("nav_button_normal"))
	btn.add_theme_stylebox_override("hover", _sb("nav_button_hover"))
	btn.add_theme_stylebox_override("pressed", _sb("nav_button_pressed"))
	btn.add_theme_stylebox_override("focus", _sb("nav_button_focus"))
	# Only the recognised header buttons get the app icons; an unknown button
	# keeps whatever icon/text its scene gave it.
	if ICONS.has(kind):
		btn.icon = load(ICONS[kind])
		btn.text = ""


## Paints the translation toggle so its on/off state is obvious at a glance.
func set_translation_toggle_state(btn: Button, active: bool) -> void:
	if btn == null:
		return
	var accent := _color("accent")
	if active:
		btn.modulate = accent.lightened(0.35) if _dark else accent
	else:
		btn.modulate = Color(1, 1, 1, 1)


func _style_label(label: Label) -> void:
	var c: Color = _color("accent_bright") if _dark else _color("accent")
	if label.label_settings != null:
		label.label_settings.font_color = c
	label.add_theme_color_override("font_color", c)
