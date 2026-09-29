class_name MenuStyle
## Vision Master — shared modern menu design language.
##
## Theme-aware friendly cards, icon chips, pills and micro-interactions used
## by every menu screen so the whole app feels like one cohesive, modern,
## friendly product. Everything reads Dark / Light through the Global
## autoload, so a single call produces the right look in both themes.

const FONT_VAZIR          := "res://assets/fonts/Vazirmatn-Regular.ttf"
const FONT_JAKARTA        := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD   := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_NUNITO_BOLD    := "res://assets/fonts/Nunito-Bold.ttf"
const FONT_JOSEFIN        := "res://assets/fonts/JosefinSans-Bold.ttf"

const ROUNDED_COVER_SHADER := preload("res://scenes/shared/rounded_cover.gdshader")

static var _font_cache: Dictionary = {}


# ---------------------------------------------------------------- fonts --
static func font(path: String) -> Font:
	if not _font_cache.has(path):
		_font_cache[path] = load(path) as Font
	return _font_cache[path]


static func vazir() -> Font:
	return font(FONT_VAZIR)


static func nunito() -> Font:
	return font(FONT_NUNITO_BOLD)


static func jakarta() -> Font:
	return font(FONT_JAKARTA)


static func jakarta_bold() -> Font:
	return font(FONT_JAKARTA_BOLD)


static func josefin() -> Font:
	return font(FONT_JOSEFIN)


# --------------------------------------------------------------- theme --
static func is_dark() -> bool:
	return Global.theme_is_dark()


static func c(role: String) -> Color:
	return Global.get_theme_color(role)


static func text() -> Color:
	return c("text")


static func text_dim() -> Color:
	return c("text_dim")


static func accent() -> Color:
	return c("accent")


static func accent_soft() -> Color:
	return c("accent_soft")


static func accent_bright() -> Color:
	return c("accent_bright")


static func surface() -> Color:
	return c("surface")


static func border() -> Color:
	return c("border")


## Card fill, read straight from the design tokens: the soft-UI charcoal
## surface in Dark, warm paper in Light. Never hardcoded here, so a token
## change lands on every menu at once.
static func card_bg() -> Color:
	return DesignTokens.color_of(is_dark(), "surface")


# ------------------------------------------------------- token shortcuts --
# Thin, readable accessors over DesignTokens so a screen never has to reach
# into the palette dictionary itself. Kept here (rather than on the tokens)
# because they are theme-mode aware and MenuStyle owns "which mode are we in".
static func ink() -> Color:
	return DesignTokens.color_of(is_dark(), "ink")


static func gold() -> Color:
	return DesignTokens.color_of(is_dark(), "gold")


static func gold_bright() -> Color:
	return DesignTokens.color_of(is_dark(), "gold_bright")


static func accent_deep() -> Color:
	return DesignTokens.color_of(is_dark(), "accent_deep")


static func sunken() -> Color:
	return DesignTokens.color_of(is_dark(), "surface_sunken")


static func paper() -> Color:
	return Color("#EDE6D6") if is_dark() else Color("#FFFDF6")


static func muted() -> Color:
	return DesignTokens.color_of(is_dark(), "text_muted")


## Foreground colour that reads well on a saturated accent fill.
static func on_accent(accent_col: Color) -> Color:
	return Color(1, 1, 1) if accent_col.get_luminance() < 0.55 else Color(0.07, 0.08, 0.16)


## Subtitle colour — a touch brighter than the theme's dim text in Dark so
## it stays readable on the deep navy cards, and a touch darker in Light so
## it stays readable on the pale backdrop.
static func subtitle_color() -> Color:
	var d := text_dim()
	if is_dark():
		return d.lightened(0.18)
	return text().lerp(d, 0.45)


# ---------------------------------------------------------------- cards --
## Soft-UI card: rounded, hairline border, elevation carried by the shadow.
## The border keeps the caller's accent so a card retains its colour identity,
## while fill / radius / shadow / elevation come from the design tokens.
## Pass `flat = true` for a shadowless surface.
static func card_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, lifted: bool = false, flat: bool = false) -> StyleBoxFlat:
	var s := DesignTokens.card(is_dark(), lifted, flat)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(DesignTokens.BORDER_SUBTLE)
	s.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.42 if is_dark() else 0.30)
	# Zero padding keeps the card's own MarginContainer in charge of insets,
	# exactly as before this restyle, so no existing layout shifts.
	DesignTokens.pad(s, 0, 0)
	return s


static func card_hover_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, flat: bool = false) -> StyleBoxFlat:
	var s := card_style(accent_col, radius, true, flat)
	if not flat:
		s.shadow_size = DesignTokens.SHADOW_DEEP_SIZE
	# The lift has to read in BOTH themes, so Light gets a small lighten too
	# instead of the old Dark-only bump that left Light cards static.
	s.bg_color = s.bg_color.lightened(0.05 if is_dark() else 0.02)
	return s


static func card_pressed_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, flat: bool = false) -> StyleBoxFlat:
	var s := card_style(accent_col, radius, false, flat)
	if not flat:
		# A tight shadow reads as the card sinking INTO the plate.
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
	s.bg_color = s.bg_color.darkened(0.04 if is_dark() else 0.05)
	return s


## Rounded square chip behind the emoji/icon of a card.
static func icon_chip(accent_col: Color, radius: int = DesignTokens.RADIUS_XS) -> StyleBoxFlat:
	var style: StyleBoxFlat = DesignTokens.icon_chip(accent_col, radius, is_dark())
	# Use a strong accent rim so the emoji chip reads as a distinct framed badge.
	style.set_border_width_all(4)
	style.border_color = accent_col.lightened(0.18 if is_dark() else 0.04)
	return style


## Small rounded label pill (e.g. a count or status badge).
static func pill_label(label_text: String, accent_col: Color, font_size: int = 34) -> Label:
	var lbl := Label.new()
	lbl.text = label_text
	style_pill(lbl, accent_col, font_size)
	return lbl


## Dresses an EXISTING label as a pill, so a component scene can declare its
## chips as nodes and still wear the one badge shape the app uses everywhere.
static func style_pill(lbl: Label, accent_col: Color, font_size: int = 34) -> void:
	lbl.add_theme_font_override("font", vazir())
	lbl.add_theme_font_size_override("font_size", font_size)
	# The pill chip is translucent, so pick a text colour with real contrast.
	lbl.add_theme_color_override("font_color", pill_text(accent_col))
	lbl.add_theme_stylebox_override("normal", icon_chip(accent_col, 20))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(0, 60)


## Text colour for translucent pill/chip backgrounds (theme-aware):
## light tinted text on Dark, deep tinted text on Light.
static func pill_text(accent_col: Color) -> Color:
	if is_dark():
		return accent_col.lightened(0.55)
	return accent_col.darkened(0.12)


## Soft, friendly tip/summary card to fill the bottom of a menu.
static func make_tip_card(message: String, emoji: String = "💡") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 108)
	var style := DesignTokens.inset(is_dark(), DesignTokens.RADIUS_MD)
	panel.add_theme_stylebox_override("panel", style)

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hb)

	var emoji_lbl := Label.new()
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_lbl.text = emoji
	emoji_lbl.add_theme_font_size_override("font_size", 34)
	hb.add_child(emoji_lbl)

	var msg := Label.new()
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.text = message
	msg.add_theme_font_override("font", vazir())
	msg.add_theme_font_size_override("font_size", 30)
	msg.add_theme_color_override("font_color", subtitle_color())
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(msg)

	return panel


# --------------------------------------------------------- build cards --
## True when a string contains Arabic/Persian glyphs (needs Vazirmatn).
static func has_persian(s: String) -> bool:
	for ch in s:
		var code := ch.unicode_at(0)
		if (code >= 0x0600 and code <= 0x06FF) or (code >= 0xFB50 and code <= 0xFDFF):
			return true
	return false


## Converts Western digits (0-9) in a string to Persian numerals (۰-۹).
static func persian_digits(s: String) -> String:
	var out := ""
	for ch in s:
		var code := ch.unicode_at(0)
		if code >= 48 and code <= 57:
			out += char(code + 1728)
		else:
			out += ch
	return out


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
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL
	# Keep the stylebox shadow within the control bounds; scale-based hover
	# effects otherwise get clipped at both horizontal edges.
	btn.clip_contents = false
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal_style: StyleBoxFlat = card_style(accent_col, 26, false, flat)
	var hover_style: StyleBoxFlat = card_hover_style(accent_col, 26, flat)
	var pressed_style: StyleBoxFlat = card_pressed_style(accent_col, 26, flat)
	var focus_style: StyleBoxFlat = card_hover_style(accent_col, 26, flat)
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
	# Icon chip (left, friendly colour identity). With an `image_path` the
	# chip becomes a rounded cover thumbnail clipped to the accent frame.
	var chip := PanelContainer.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cover chips are portrait to match the 230x320 book-cover ratio (~0.72) so
	# the full cover is visible with no crop or stretch; emoji chips stay square.
	chip.custom_minimum_size = Vector2(124, 150) if image_path != "" else Vector2(132, 132)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.clip_contents = true
	chip.add_theme_stylebox_override("panel", icon_chip(accent_col))
	if image_path != "":
		var img := TextureRect.new()
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = load(image_path) as Texture2D
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		# clip_contents would only clip to a rectangle, so the cover image
		# rounds its own corners with a tiny shader to match the chip's
		# rounded accent frame (no more sharp 90-degree corners).
		var rounded := ShaderMaterial.new()
		rounded.shader = ROUNDED_COVER_SHADER
		img.material = rounded
		chip.add_child(img)
	else:
		var emoji_lbl := Label.new()
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
	title_lbl.add_theme_font_override("font", vazir() if has_persian(title) else nunito())
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", text())
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_lbl)
	var sub_lbl := Label.new()
	sub_lbl.name = "SubLabel"
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_override("font", vazir())
	sub_lbl.add_theme_font_size_override("font_size", 33)
	sub_lbl.add_theme_color_override("font_color", subtitle_color())
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_lbl)
	hb.add_child(col)

	# Forward arrow — points RIGHT (towards the next screen).
	var chev := Label.new()
	chev.name = "ChevronLabel"
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chev.text = "❯"
	chev.add_theme_font_size_override("font_size", 60)
	var chev_col := Color(accent_col.r, accent_col.g, accent_col.b, 0.9)
	if is_dark():
		chev_col = accent_col.lightened(0.3)
	chev.add_theme_color_override("font_color", chev_col)
	chev.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(chev)

	return btn


# -------------------------------------------------- micro-interactions --
## Friendly hover-lift / press-squash micro-interactions on a button.
static func wire_microinteractions(btn: Button) -> void:
	if btn.has_meta("menu_style_wired"):
		return
	btn.set_meta("menu_style_wired", true)
	if btn.pivot_offset == Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0)
	btn.mouse_entered.connect(func() -> void:
		var tw := btn.create_tween()
		# Keep the hover card inside its layout slot: scaling clips the outer
		# edges against the parent ScrollContainer and hides the outline.
		tw.tween_property(btn, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


# ---------------------------------------------------------------- bars --
## Rounded-bottom header bar (top of menu screens).
## Pass `flat = true` for a shadowless (flat) header.
static func header_bar_style(radius_bottom: int = DesignTokens.RADIUS_LG, flat: bool = false) -> StyleBoxFlat:
	var s := DesignTokens.header_bar(is_dark())
	DesignTokens.round_bottom(s, radius_bottom)
	if flat:
		s.shadow_size = 0
		s.shadow_offset = Vector2.ZERO
	return s


## Clean back button: transparent normally, soft accent pill on hover/press.
static func make_back_button(icon_path: String, size: int = 96) -> Button:
	var b := Button.new()
	b.icon = load(icon_path) as Texture2D
	b.expand_icon = true
	b.custom_minimum_size = Vector2(size, size)
	b.text = ""

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)

	var hover := StyleBoxFlat.new()
	if is_dark():
		hover.bg_color = Color(1, 1, 1, 0.10)
	else:
		hover.bg_color = Color(accent().r, accent().g, accent().b, 0.12)
	hover.set_corner_radius_all(int(size / 2.0))

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color.a += 0.06

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = accent()
	focus.set_border_width_all(1)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	return b


# ══════════════════════════════════════════════════════════════
#  COMPONENTS FROM THE REFERENCE SHEET
#  Each one is a self-contained factory returning a ready-to-add Control, so a
#  screen composes UI instead of restating styling. Children are named so the
#  caller can reach in and adjust content afterwards.
# ══════════════════════════════════════════════════════════════

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
	head.add_theme_font_override("font", vazir() if has_persian(title) else nunito())
	head.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)
	head.add_theme_color_override("font_color", text())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	if caption != "":
		var cap := Label.new()
		cap.name = "Caption"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.text = caption
		cap.add_theme_font_override("font", vazir())
		cap.add_theme_font_size_override("font_size", DesignTokens.FONT_TINY)
		# Gold micro-caption is the reference's accent for a sub-label.
		cap.add_theme_color_override("font_color", gold())
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)

	return col


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
	btn.add_theme_font_override("font", vazir() if has_persian(btn_text) else nunito())
	btn.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)

	var dark := is_dark()
	if kind == "primary":
		btn.add_theme_stylebox_override("normal", DesignTokens.button_primary(dark))
		btn.add_theme_stylebox_override("hover", DesignTokens.button_primary_hover(dark))
		btn.add_theme_stylebox_override("pressed", DesignTokens.button_pressed(dark))
		btn.add_theme_stylebox_override("focus", DesignTokens.button_focus(dark))
		btn.add_theme_color_override("font_color", DesignTokens.button_text_color("hover", dark))
		btn.add_theme_color_override("font_hover_color", DesignTokens.button_text_color("hover", dark))
	elif kind == "ghost":
		var clear := StyleBoxFlat.new()
		clear.bg_color = Color(0, 0, 0, 0)
		var hover := DesignTokens.box(accent_soft(), DesignTokens.RADIUS_PILL)
		btn.add_theme_stylebox_override("normal", clear)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", DesignTokens.button_focus(dark))
		btn.add_theme_color_override("font_color", accent())
		btn.add_theme_color_override("font_hover_color", accent_bright())
	else:
		btn.add_theme_stylebox_override("normal", DesignTokens.button_default(dark))
		btn.add_theme_stylebox_override("hover", DesignTokens.button_hover(dark))
		btn.add_theme_stylebox_override("pressed", DesignTokens.button_pressed(dark))
		btn.add_theme_stylebox_override("focus", DesignTokens.button_focus(dark))
		btn.add_theme_color_override("font_color", DesignTokens.button_text_color("default", dark))
		btn.add_theme_color_override("font_hover_color", DesignTokens.button_text_color("hover", dark))

	btn.add_theme_color_override("font_pressed_color", DesignTokens.button_text_color("pressed", dark))
	wire_microinteractions(btn)
	return btn


## Floating notification toast: cream pill, circular tick badge, ink copy.
## `tone` picks the badge colour: "success" | "error" | "warning" | "info".
static func make_toast(message: String, tone: String = "success") -> PanelContainer:
	var dark := is_dark()
	var panel := PanelContainer.new()
	panel.name = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", DesignTokens.toast(dark))

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
	var badge_style := DesignTokens.box(badge_tint, DesignTokens.RADIUS_PILL)
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
	msg.add_theme_font_override("font", vazir() if has_persian(message) else nunito())
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
	panel.add_theme_stylebox_override("panel", DesignTokens.empty_tile(is_dark()))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", DesignTokens.SPACE_SM)
	panel.add_child(col)

	var plate := PanelContainer.new()
	plate.name = "IconPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(96, 96)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", DesignTokens.inset(is_dark(), DesignTokens.RADIUS_SM))
	var gl := Label.new()
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gl.text = glyph
	gl.add_theme_font_size_override("font_size", DesignTokens.ICON_MD)
	gl.add_theme_color_override("font_color", muted())
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(gl)
	col.add_child(plate)

	var t := Label.new()
	t.name = "Title"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.text = title
	t.add_theme_font_override("font", vazir() if has_persian(title) else nunito())
	t.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL)
	t.add_theme_color_override("font_color", text())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)

	var m := Label.new()
	m.name = "Message"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.text = message
	m.add_theme_font_override("font", vazir() if has_persian(message) else nunito())
	m.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	m.add_theme_color_override("font_color", muted())
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(m)

	return panel


## One table row with the reference's three states. Named "Label" so a caller
## can retarget the copy.
static func make_table_row(row_text: String, state: String = "default") -> PanelContainer:
	var dark := is_dark()
	var row := PanelContainer.new()
	row.name = "TableRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", DesignTokens.table_row(state, dark))

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = row_text
	lbl.add_theme_font_override("font", vazir() if has_persian(row_text) else nunito())
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
	var dark := is_dark()

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
	var body_style := DesignTokens.card_paper(dark)
	DesignTokens.pad(body_style, 0, 0)
	dialog.add_theme_stylebox_override("panel", body_style)
	dialog.add_child(col)
	center.add_child(dialog)

	var head := PanelContainer.new()
	head.name = "Header"
	var head_style := DesignTokens.box(DesignTokens.color_of(dark, "accent"), 0)
	head_style.corner_radius_top_left = DesignTokens.RADIUS_MD
	head_style.corner_radius_top_right = DesignTokens.RADIUS_MD
	DesignTokens.pad(head_style, DesignTokens.SPACE_MD, DesignTokens.SPACE_SM)
	head.add_theme_stylebox_override("panel", head_style)
	var head_lbl := Label.new()
	head_lbl.name = "HeaderLabel"
	head_lbl.text = title
	head_lbl.add_theme_font_override("font", vazir() if has_persian(title) else nunito())
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
	msg.add_theme_font_override("font", vazir() if has_persian(content) else nunito())
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


## A labelled toggle row using the reference's switch.
static func make_toggle_row(label_text: String, is_on: bool) -> HBoxContainer:
	var dark := is_dark()
	var row := HBoxContainer.new()
	row.name = "ToggleRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", DesignTokens.SPACE_SM)

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = label_text
	lbl.add_theme_font_override("font", vazir() if has_persian(label_text) else nunito())
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SMALL)
	lbl.add_theme_color_override("font_color", text())
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var sw := CheckButton.new()
	sw.name = "Switch"
	sw.button_pressed = is_on
	sw.custom_minimum_size = Vector2(120, 68)
	sw.add_theme_stylebox_override("normal", DesignTokens.toggle_track(false, dark))
	sw.add_theme_stylebox_override("hover", DesignTokens.toggle_track(false, dark))
	sw.add_theme_stylebox_override("pressed", DesignTokens.toggle_track(true, dark))
	sw.add_theme_stylebox_override("hover_pressed", DesignTokens.toggle_track(true, dark))
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
	bar.add_theme_stylebox_override("background", DesignTokens.progress_track(is_dark()))
	bar.add_theme_stylebox_override("fill", DesignTokens.progress_fill(is_dark()))
	return bar


# ══════════════════════════════════════════════════════════════
#  JUICE — reusable Tween choreography.
#  Kept here so every screen animates the same way instead of each one
#  inventing its own durations and easings. All are fire-and-forget: they
#  create their own tween and return it so callers may await or chain.
# ══════════════════════════════════════════════════════════════

## Scales a control up from nothing — the "pop in" for cards, tiles and popups.
static func pop_in(node: Control, delay: float = 0.0) -> Tween:
	if node.pivot_offset == Vector2.ZERO:
		node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.86, 0.86)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.34).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.22).set_delay(delay)
	return tw


## Horizontal shake for a wrong answer. Rotates nothing, so it is safe on any
## layout container.
static func shake(node: Control) -> Tween:
	if node.pivot_offset == Vector2.ZERO:
		node.pivot_offset = node.size / 2.0
	var home := node.position
	var tw := node.create_tween()
	# Diminishing offsets: the classic "no" head-shake.
	for offset in [14.0, -12.0, 9.0, -6.0, 3.0, 0.0]:
		tw.tween_property(node, "position:x", home.x + offset, 0.055) \
			.set_trans(Tween.TRANS_SINE)
	return tw


## A short scale bump for a correct answer / successful drop.
static func pop(node: Control, strength: float = 1.12) -> Tween:
	if node.pivot_offset == Vector2.ZERO:
		node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(strength, strength), 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


## Gentle infinite breathing loop, for "tap me" affordances.
static func pulse_loop(node: Control, amount: float = 1.04) -> Tween:
	if node.pivot_offset == Vector2.ZERO:
		node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.set_loops()
	tw.tween_property(node, "scale", Vector2(amount, amount), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## Cinematic entrance: slides in from the right while fading up. `delay` lets a
## caller stagger a list into a cascade.
static func slide_in(node: Control, delay: float = 0.0, distance: float = 90.0) -> Tween:
	var home := node.position
	node.position = Vector2(home.x + distance, home.y)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position", home, 0.42).set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.30).set_delay(delay)
	return tw


## Staggered cascade over a list — the menu entrance used across the app.
static func stagger_in(nodes: Array, step: float = 0.07, distance: float = 70.0) -> void:
	for i in nodes.size():
		var node := nodes[i] as Control
		if node != null:
			slide_in(node, float(i) * step, distance)
