class_name MenuTheme
extends RefCounted
## ============================================================
##  MENU THEME — fonts, palette access and the menu accent styles.
##
##  Split out of the old 925-line MenuStyle god-module (which also owned the
##  widget factory and the tween choreography). This module is the only place
##  that answers "which font, which colour, which accented card style?". It is
##  stateless and static, so any screen or component can call it without an
##  instance and without knowing about the scene tree.
##
##  All colours resolve through DesignTokens / the active palette, and every
##  stylebox is DERIVED FROM a shared resource in res://resources/styleboxes/
##  (never built from raw numbers), so geometry and elevation stay editable in
##  the Inspector. The only thing this module adds per call is the caller's
##  identity accent, which by definition cannot be a static resource.
## ============================================================

const STYLEBOX_DIR := "res://resources/styleboxes/"

## How much of the page shows through a GLOSSY card's face. Open enough that the
## card reads as a pane of glass over the artwork behind it, closed enough that
## the theme's dark ink keeps its contrast on top of it. One value for every
## state, so the glass never firms up or turns see-through as the card is used.
const GLOSS_FACE_ALPHA := 0.88

const FONT_VAZIR        := "res://assets/fonts/Vazirmatn-Regular.ttf"
const FONT_JAKARTA      := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_NUNITO_BOLD  := "res://assets/fonts/Nunito-Bold.ttf"
const FONT_JOSEFIN      := "res://assets/fonts/JosefinSans-Bold.ttf"

static var _font_cache: Dictionary = {}


# ---------------------------------------------------------------- fonts --
## Loads a font once per process. The cache is a `static var`, so it is the one
## thing Godot still reports as "in use" at exit — that is the cache working.
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


# ---------------------------------------------------------------- state --
static func is_dark() -> bool:
	return false


static func mode_suffix() -> String:
	return "light"


## Loads a mode-specific shared stylebox.
static func stylebox(file_base: String) -> StyleBox:
	return load("%s%s_%s.tres" % [STYLEBOX_DIR, file_base, mode_suffix()])


## Loads a mode-independent shared stylebox.
static func stylebox_plain(file_base: String) -> StyleBox:
	return load("%s%s.tres" % [STYLEBOX_DIR, file_base])


# --------------------------------------------------------------- colours --
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


static func muted() -> Color:
	return DesignTokens.color_of(is_dark(), "text_muted")


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


## The soft-UI charcoal surface in Dark, warm paper in Light. Read straight from
## the design tokens: never hardcoded here, so a token change lands everywhere.
static func card_bg() -> Color:
	return DesignTokens.color_of(is_dark(), "surface")


static func paper() -> Color:
	return Color("#FFFDF6")


## Foreground colour that reads well on a saturated accent fill.
static func on_accent(accent_col: Color) -> Color:
	return Color(1, 1, 1) if accent_col.get_luminance() < 0.55 else Color(0.07, 0.08, 0.16)


## Subtitle colour — a touch brighter than the theme's dim text in Dark so it
## stays readable on the deep navy cards, and a touch darker in Light so it
## stays readable on the pale backdrop.
static func subtitle_color() -> Color:
	var d := text_dim()
	if is_dark():
		return d.lightened(0.18)
	return text().lerp(d, 0.45)


## Text colour for translucent pill/chip backgrounds (theme-aware):
## light tinted text on Dark, deep tinted text on Light.
static func pill_text(accent_col: Color) -> Color:
	if is_dark():
		return accent_col.lightened(0.55)
	return accent_col.darkened(0.12)


# ------------------------------------------------------------ card styles --
## Soft-UI card: rounded, hairline border, elevation carried by the shadow.
## Geometry comes from the shared card resource; the identity accent is applied
## as the border so a card keeps its colour. Pass `flat = true` for a
## shadowless surface.
static func card_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, lifted: bool = false, flat: bool = false) -> StyleBoxFlat:
	var file_base := "card"
	if lifted:
		file_base = "card_lifted"
	elif flat:
		file_base = "card_flat"
	var s: StyleBoxFlat = (stylebox(file_base) as StyleBoxFlat).duplicate() as StyleBoxFlat
	s.set_corner_radius_all(radius)
	s.set_border_width_all(DesignTokens.BORDER_SUBTLE)
	s.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.42 if is_dark() else 0.30)
	# Zero padding keeps the card's own MarginContainer in charge of insets,
	# exactly as before this restyle, so no existing layout shifts.
	DesignTokens.pad(s, 0, 0)
	return s


## The light body a GLOSSY card is painted with: white carrying a whisper of the
## section's accent, so the sheen overlay has a colour to refract instead of
## shining on a dead-white face. Kept pale on purpose — the card's text stays
## the theme's dark ink on top of it — and kept slightly see-through, so the
## page behind the card reads through the glass.
static func gloss_body(accent_col: Color) -> Color:
	var body := Color(1, 1, 1).lerp(accent_col, 0.09)
	body.a = GLOSS_FACE_ALPHA
	return body


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
	var style: StyleBoxFlat = (stylebox("icon_chip_accent") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.set_corner_radius_all(radius)
	# Tint the shared chip with the caller's identity colour, keeping the
	# resource's alpha/saturation relationship between fill and border.
	var alpha := 0.26 if is_dark() else 0.14
	style.bg_color = Color(accent_col.r, accent_col.g, accent_col.b, alpha)
	# Keep the icon chip rim subtle, matching the slimmer menu-card outline.
	style.set_border_width_all(DesignTokens.BORDER_SUBTLE)
	style.border_color = accent_col.lightened(0.18 if is_dark() else 0.04)
	return style


## Fully rounded status pill tinted by the caller's accent.
static func pill_style(accent_col: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = (stylebox("pill_accent") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var alpha := 0.22 if is_dark() else 0.12
	style.bg_color = Color(accent_col.r, accent_col.g, accent_col.b, alpha)
	style.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.45)
	return style


# ---------------------------------------------------------------- bars --
## Rounded-bottom header bar (top of menu screens).
## Pass `flat = true` for a shadowless (flat) header.
static func header_bar_style(radius_bottom: int = DesignTokens.RADIUS_LG, flat: bool = false) -> StyleBoxFlat:
	var s: StyleBoxFlat = (stylebox("header_bar") as StyleBoxFlat).duplicate() as StyleBoxFlat
	DesignTokens.round_bottom(s, radius_bottom)
	if flat:
		s.shadow_size = 0
		s.shadow_offset = Vector2.ZERO
	return s


# ----------------------------------------------------------------- text --
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


## Picks the family that can actually shape the string.
static func family_for(s: String) -> Font:
	return vazir() if has_persian(s) else nunito()
