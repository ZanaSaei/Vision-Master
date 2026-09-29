class_name MenuWidgets
extends RefCounted
## ============================================================
##  MENU WIDGETS — the app's shared component factory.
##
##  Split out of the old 925-line MenuStyle god-module. Each function returns a
##  ready-to-add Control that already wears the app's design language, so a
##  screen composes UI instead of restating styling. Children are NAMED
##  ("Chip", "TitleLabel", "SubLabel", "ChevronLabel", ...) so a caller can
##  reach in and adjust content afterwards.
##
##  Colours and styles come from MenuTheme (which reads the shared stylebox
##  resources) and motion from UiMotion (which reads the motion profiles), so
##  this file holds layout and composition only — no visual literals.
##
##  NOTE: this is a factory for genuinely dynamic content (a list whose length
##  comes from JSON, a toast raised at runtime). Static screen chrome belongs in
##  the scene tree — see res://ui/components/ for the authored component scenes.
## ============================================================

const ROUNDED_COVER_SHADER := preload("res://scenes/shared/rounded_cover.gdshader")


# ══════════════════════════════════════════════════════════════
#  TEXT COMPONENTS
# ══════════════════════════════════════════════════════════════

## Small rounded label pill (e.g. a count or status badge).
static func pill_label(label_text: String, accent_col: Color, font_size: int = 34) -> Label:
	var lbl := Label.new()
	lbl.text = label_text
	style_pill(lbl, accent_col, font_size)
	return lbl


## Dresses an EXISTING label as a pill, so a component scene can declare its
## chips as nodes and still wear the one badge shape the app uses everywhere.
static func style_pill(lbl: Label, accent_col: Color, font_size: int = 34) -> void:
	lbl.add_theme_font_override("font", MenuTheme.vazir())
	lbl.add_theme_font_size_override("font_size", font_size)
	# The pill chip is translucent, so pick a text colour with real contrast.
	lbl.add_theme_color_override("font_color", MenuTheme.pill_text(accent_col))
	lbl.add_theme_stylebox_override("normal", MenuTheme.pill_style(accent_col))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(0, 60)


## Section heading: a shaded ruled label over an optional gold micro-caption —
## the "Cards" / "RADIUS STEPS" pattern that groups the reference sheet.
static func make_section_header(title: String, caption: String = "") -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "SectionHeader"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", DesignTokens.SPACE_XS)

	var head := Label.new()
	head.name = "Title"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.text = title
	head.add_theme_font_override("font", MenuTheme.family_for(title))
	head.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)
	head.add_theme_color_override("font_color", MenuTheme.text())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	if caption != "":
		var cap := Label.new()
		cap.name = "Caption"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.text = caption
		cap.add_theme_font_override("font", MenuTheme.vazir())
		cap.add_theme_font_size_override("font_size", DesignTokens.FONT_TINY)
		# Gold micro-caption is the reference's accent for a sub-label.
		cap.add_theme_color_override("font_color", MenuTheme.gold())
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)

	return col


# ══════════════════════════════════════════════════════════════
#  BUTTONS
# ══════════════════════════════════════════════════════════════

## An action button in the new language.
## `kind`: "primary" (blue), "secondary"/"default" (cream + gold rim),
##         "ghost" (transparent, for in-card actions).
static func make_button(btn_text: String, kind: String = "primary", min_height: int = 96) -> Button:
	var btn := Button.new()
	btn.name = kind.capitalize() + "Button"
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", MenuTheme.family_for(btn_text))
	btn.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)

	var dark := MenuTheme.is_dark()
	if kind == "primary":
		btn.add_theme_stylebox_override("normal", MenuTheme.stylebox("button_primary"))
		btn.add_theme_stylebox_override("hover", MenuTheme.stylebox("button_primary_hover"))
		btn.add_theme_stylebox_override("pressed", MenuTheme.stylebox("button_pressed"))
		btn.add_theme_stylebox_override("focus", MenuTheme.stylebox("button_focus"))
		btn.add_theme_color_override("font_color", DesignTokens.button_text_color("hover", dark))
		btn.add_theme_color_override("font_hover_color", DesignTokens.button_text_color("hover", dark))
	elif kind == "ghost":
		var hover := MenuTheme.pill_style(MenuTheme.accent())
		btn.add_theme_stylebox_override("normal", MenuTheme.stylebox_plain("nav_button_normal"))
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", MenuTheme.stylebox("button_focus"))
		btn.add_theme_color_override("font_color", MenuTheme.accent())
		btn.add_theme_color_override("font_hover_color", MenuTheme.accent_bright())
	else:
		btn.add_theme_stylebox_override("normal", MenuTheme.stylebox("button_default"))
		btn.add_theme_stylebox_override("hover", MenuTheme.stylebox("button_hover"))
		btn.add_theme_stylebox_override("pressed", MenuTheme.stylebox("button_pressed"))
		btn.add_theme_stylebox_override("focus", MenuTheme.stylebox("button_focus"))
		btn.add_theme_color_override("font_color", DesignTokens.button_text_color("default", dark))
		btn.add_theme_color_override("font_hover_color", DesignTokens.button_text_color("hover", dark))

	btn.add_theme_color_override("font_pressed_color", DesignTokens.button_text_color("pressed", dark))
	UiMotion.wire_microinteractions(btn)
	return btn


## Clean back button: transparent normally, soft accent pill on hover/press.
static func make_back_button(icon_path: String, size: int = 96) -> Button:
	var b := Button.new()
	b.name = "BackButton"
	b.icon = load(icon_path) as Texture2D
	b.expand_icon = true
	b.custom_minimum_size = Vector2(size, size)
	b.text = ""
	b.add_theme_stylebox_override("normal", MenuTheme.stylebox_plain("nav_button_normal"))
	b.add_theme_stylebox_override("hover", MenuTheme.stylebox("nav_button_hover"))
	b.add_theme_stylebox_override("pressed", MenuTheme.stylebox("nav_button_pressed"))
	b.add_theme_stylebox_override("focus", MenuTheme.stylebox("nav_button_focus"))
	return b


# ══════════════════════════════════════════════════════════════
#  CARDS
# ══════════════════════════════════════════════════════════════

## Soft, friendly tip/summary card to fill the bottom of a menu.
static func make_tip_card(message: String, emoji: String = "💡") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TipCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 108)
	panel.add_theme_stylebox_override("panel", MenuTheme.stylebox("inset"))

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hb)

	var emoji_lbl := Label.new()
	emoji_lbl.name = "Glyph"
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_lbl.text = emoji
	emoji_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_BODY)
	hb.add_child(emoji_lbl)

	var msg := Label.new()
	msg.name = "Message"
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.text = message
	msg.add_theme_font_override("font", MenuTheme.vazir())
	msg.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	msg.add_theme_color_override("font_color", MenuTheme.subtitle_color())
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(msg)

	return panel


# ══════════════════════════════════════════════════════════════
#  MENU CARDS
# ══════════════════════════════════════════════════════════════

## Builds a full modern menu card button:
##   [icon chip]   Title          ❯
##                 subtitle
## Children are named "Chip", "TitleLabel", "SubLabel", "ChevronLabel" so
## callers can tweak them afterwards. Pass an `image_path` to show a cover
## image inside the chip instead of an emoji.
static func make_card(
	title: String,
	subtitle: String,
	emoji: String,
	accent_col: Color,
	min_height: int = 158,
	image_path: String = "",
	flat: bool = false
) -> Button:
	var btn := Button.new()
	btn.name = "MenuCard"
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL
	# Keep the stylebox shadow within the control bounds; scale-based hover
	# effects otherwise get clipped at both horizontal edges.
	btn.clip_contents = false
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal_style: StyleBoxFlat = MenuTheme.card_style(accent_col, 26, false, flat)
	var hover_style: StyleBoxFlat = MenuTheme.card_hover_style(accent_col, 26, flat)
	var pressed_style: StyleBoxFlat = MenuTheme.card_pressed_style(accent_col, 26, flat)
	var focus_style: StyleBoxFlat = MenuTheme.card_hover_style(accent_col, 26, flat)
	for style: StyleBoxFlat in [normal_style, hover_style, pressed_style, focus_style]:
		style.set_border_width_all(3)
		style.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.95)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", focus_style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	btn.add_child(margin)

	var hb := HBoxContainer.new()
	hb.name = "Row"
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hb)

	# ---- Card layout: icon chip (left) · text · forward arrow (right, ❯).
	# The app's drawer/menus slide in from the RIGHT, so the forward arrow
	# points right — towards the next screen.
	# Icon chip (left, friendly colour identity). With an `image_path` the chip
	# becomes a rounded cover thumbnail clipped to the accent frame.
	var chip := PanelContainer.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cover chips are portrait to match the 230x320 book-cover ratio (~0.72) so
	# the full cover is visible with no crop or stretch; emoji chips stay square.
	chip.custom_minimum_size = Vector2(124, 150) if image_path != "" else Vector2(132, 132)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.clip_contents = true
	chip.add_theme_stylebox_override("panel", MenuTheme.icon_chip(accent_col))
	if image_path != "":
		var img := TextureRect.new()
		img.name = "Cover"
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = load(image_path) as Texture2D
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		# clip_contents would only clip to a rectangle, so the cover image
		# rounds its own corners with a tiny shader to match the chip's rounded
		# accent frame (no more sharp 90-degree corners).
		var rounded := ShaderMaterial.new()
		rounded.shader = ROUNDED_COVER_SHADER
		img.material = rounded
		chip.add_child(img)
	else:
		var emoji_lbl := Label.new()
		emoji_lbl.name = "Emoji"
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emoji_lbl.text = emoji
		emoji_lbl.add_theme_font_size_override("font_size", 58)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(emoji_lbl)
	hb.add_child(chip)

	# Title + subtitle column.
	var col := VBoxContainer.new()
	col.name = "TextColumn"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = title
	title_lbl.add_theme_font_override("font", MenuTheme.family_for(title))
	title_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", MenuTheme.text())
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_lbl)
	var sub_lbl := Label.new()
	sub_lbl.name = "SubLabel"
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_override("font", MenuTheme.vazir())
	sub_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_BODY)
	sub_lbl.add_theme_color_override("font_color", MenuTheme.subtitle_color())
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_lbl)
	hb.add_child(col)

	# Forward arrow — points RIGHT (towards the next screen).
	var chev := Label.new()
	chev.name = "ChevronLabel"
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chev.text = "❯"
	chev.add_theme_font_size_override("font_size", DesignTokens.FONT_HERO)
	var chev_col := Color(accent_col.r, accent_col.g, accent_col.b, 0.9)
	if MenuTheme.is_dark():
		chev_col = accent_col.lightened(0.3)
	chev.add_theme_color_override("font_color", chev_col)
	chev.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(chev)

	return btn


# ══════════════════════════════════════════════════════════════
#  FEEDBACK COMPONENTS
# ══════════════════════════════════════════════════════════════

## Floating notification toast: cream pill, circular tick badge, ink copy.
## `tone` picks the badge colour: "success" | "error" | "warning" | "info".
static func make_toast(message: String, tone: String = "success") -> PanelContainer:
	var dark := MenuTheme.is_dark()
	var panel := PanelContainer.new()
	panel.name = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MenuTheme.stylebox("toast"))

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", DesignTokens.SPACE_SM)
	panel.add_child(hb)

	var badge_tint: Color = {
		"success": DesignTokens.color_of(dark, "success"),
		"error": DesignTokens.color_of(dark, "error"),
		"warning": DesignTokens.color_of(dark, "warning"),
		"info": DesignTokens.color_of(dark, "accent"),
	}.get(tone, DesignTokens.color_of(dark, "success"))

	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(DesignTokens.ICON_MD, DesignTokens.ICON_MD)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style: StyleBoxFlat = MenuTheme.stylebox("toast_badge").duplicate() as StyleBoxFlat
	badge_style.bg_color = badge_tint
	badge.add_theme_stylebox_override("panel", badge_style)
	var tick := Label.new()
	tick.name = "Glyph"
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A glyph in the badge means the toast needs no external icon asset.
	tick.text = "✓" if tone == "success" else ("!" if tone != "info" else "i")
	tick.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	tick.add_theme_color_override("font_color", Color.WHITE)
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(tick)
	hb.add_child(badge)

	var msg := Label.new()
	msg.name = "Message"
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.text = message
	msg.add_theme_font_override("font", MenuTheme.family_for(message))
	msg.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	# Always ink: the toast body is cream in BOTH themes.
	msg.add_theme_color_override("font_color", DesignTokens.color_of(true, "ink"))
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(msg)

	return panel


## The raised empty-state card: a rounded icon plate over a title and muted
## copy, on the inset surface. Replaces the ad-hoc "nothing here" labels.
static func make_empty_state(title: String, message: String, glyph: String = "≡") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EmptyState"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MenuTheme.stylebox("empty_tile"))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", DesignTokens.SPACE_SM)
	panel.add_child(col)

	var plate := PanelContainer.new()
	plate.name = "IconPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(96, 96)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", MenuTheme.stylebox("inset"))
	var gl := Label.new()
	gl.name = "Glyph"
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gl.text = glyph
	gl.add_theme_font_size_override("font_size", DesignTokens.ICON_MD)
	gl.add_theme_color_override("font_color", MenuTheme.muted())
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(gl)
	col.add_child(plate)

	var t := Label.new()
	t.name = "Title"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.text = title
	t.add_theme_font_override("font", MenuTheme.family_for(title))
	t.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)
	t.add_theme_color_override("font_color", MenuTheme.text())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)

	var m := Label.new()
	m.name = "Message"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.text = message
	m.add_theme_font_override("font", MenuTheme.family_for(message))
	m.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	m.add_theme_color_override("font_color", MenuTheme.muted())
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(m)

	return panel


## One table row with the reference's three states. Named "Label" so a caller
## can retarget the copy.
static func make_table_row(row_text: String, state: String = "default") -> PanelContainer:
	var dark := MenuTheme.is_dark()
	var row := PanelContainer.new()
	row.name = "TableRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var file_base := "table_row"
	if state == "hover":
		file_base = "table_row_hover"
	elif state == "selected":
		file_base = "table_row_selected"
	row.add_theme_stylebox_override("panel", MenuTheme.stylebox(file_base))

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = row_text
	lbl.add_theme_font_override("font", MenuTheme.family_for(row_text))
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	lbl.add_theme_color_override("font_color", DesignTokens.table_row_text_color(state, dark))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row


## The modal dialog: a blue header band over a cream body with a Cancel /
## Confirm pair. Returns a Dictionary of the pieces so the caller can wire the
## buttons and read the result:
##   {"root": Control, "cancel": Button, "confirm": Button, "content": Control}
## The returned root is a full-rect overlay — add it to a CanvasLayer and call
## `root.queue_free()` when done.
static func make_modal(
	title: String,
	content: String,
	cancel_text: String = "Cancel",
	confirm_text: String = "Content"
) -> Dictionary:
	var dark := MenuTheme.is_dark()

	var root := Control.new()
	root.name = "Modal"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Scrim so the dialog reads as floating above the page.
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = DesignTokens.color_of(dark, "overlay")
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var col := VBoxContainer.new()
	col.name = "Dialog"
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(720, 0)

	# The whole dialog is ONE shadowed paper body with zero padding, so the
	# header band can sit flush against the top edge with no seam.
	var dialog := PanelContainer.new()
	var body_style: StyleBoxFlat = (MenuTheme.stylebox("card_paper") as StyleBoxFlat).duplicate() as StyleBoxFlat
	DesignTokens.pad(body_style, 0, 0)
	dialog.add_theme_stylebox_override("panel", body_style)
	dialog.add_child(col)
	center.add_child(dialog)

	var head := PanelContainer.new()
	head.name = "Header"
	var head_style: StyleBoxFlat = (MenuTheme.stylebox("modal_header") as StyleBoxFlat).duplicate() as StyleBoxFlat
	head_style.set_corner_radius_all(0)
	head_style.corner_radius_top_left = DesignTokens.RADIUS_MD
	head_style.corner_radius_top_right = DesignTokens.RADIUS_MD
	head.add_theme_stylebox_override("panel", head_style)
	var head_lbl := Label.new()
	head_lbl.name = "HeaderLabel"
	head_lbl.text = title
	head_lbl.add_theme_font_override("font", MenuTheme.family_for(title))
	head_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)
	head_lbl.add_theme_color_override("font_color", DesignTokens.color_of(dark, "on_accent"))
	head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(head_lbl)
	col.add_child(head)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", DesignTokens.SPACE_LG)
	content_margin.add_theme_constant_override("margin_right", DesignTokens.SPACE_LG)
	content_margin.add_theme_constant_override("margin_top", DesignTokens.SPACE_LG)
	content_margin.add_theme_constant_override("margin_bottom", DesignTokens.SPACE_LG)
	col.add_child(content_margin)

	var content_col := VBoxContainer.new()
	content_col.name = "ContentColumn"
	content_col.add_theme_constant_override("separation", DesignTokens.SPACE_LG)
	content_margin.add_child(content_col)

	var msg := Label.new()
	msg.name = "ContentLabel"
	msg.text = content
	msg.add_theme_font_override("font", MenuTheme.family_for(content))
	msg.add_theme_font_size_override("font_size", DesignTokens.FONT_BODY)
	# Ink, because the modal body is always a light paper surface.
	msg.add_theme_color_override("font_color", DesignTokens.modal_text_color(dark))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_col.add_child(msg)

	var row := HBoxContainer.new()
	row.name = "Actions"
	row.add_theme_constant_override("separation", DesignTokens.SPACE_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_col.add_child(row)

	# Cancel is the neutral cream button; Confirm is the blue primary — the
	# exact pairing the reference modal shows.
	var cancel := make_button(cancel_text, "secondary", 88)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var confirm := make_button(confirm_text, "primary", 88)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(confirm)

	return {"root": root, "cancel": cancel, "confirm": confirm, "content": content_margin}


# ══════════════════════════════════════════════════════════════
#  CONTROLS
# ══════════════════════════════════════════════════════════════

## A labelled toggle row using the reference's switch.
static func make_toggle_row(label_text: String, is_on: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ToggleRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", DesignTokens.SPACE_SM)

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = label_text
	lbl.add_theme_font_override("font", MenuTheme.family_for(label_text))
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	lbl.add_theme_color_override("font_color", MenuTheme.text())
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var sw := CheckButton.new()
	sw.name = "Switch"
	sw.button_pressed = is_on
	sw.custom_minimum_size = Vector2(120, 68)
	sw.add_theme_stylebox_override("normal", MenuTheme.stylebox("toggle_off"))
	sw.add_theme_stylebox_override("hover", MenuTheme.stylebox("toggle_off"))
	sw.add_theme_stylebox_override("pressed", MenuTheme.stylebox("toggle_on"))
	sw.add_theme_stylebox_override("hover_pressed", MenuTheme.stylebox("toggle_on"))
	row.add_child(sw)

	return row


## A thick rounded progress indicator with the blue fill + gold remainder.
static func make_progress(value: float, width: int = 0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "ProgressIndicator"
	bar.max_value = 1.0
	bar.value = clampf(value, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 26)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0 else Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", MenuTheme.stylebox("progress_track"))
	bar.add_theme_stylebox_override("fill", MenuTheme.stylebox("progress_fill"))
	return bar
