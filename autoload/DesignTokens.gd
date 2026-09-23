class_name DesignTokens
extends RefCounted
## ============================================================
##  DESIGN TOKENS — the single source of truth for the app's visual language.
##
##  Everything visual in Vision Master resolves to a value in this file: the
##  palette, the corner-radius scale, border thickness, shadow levels, icon
##  sizes, the spacing scale, and a StyleBoxFlat factory for every component
##  (cards, five button states, inputs, dropdowns, toggles, sliders, progress
##  bars, toasts, modals, table rows and empty-state tiles).
##
##  WHY a separate module instead of scattering colours through scenes:
##  the app is code-generated UI — screens build their trees in GDScript and
##  read their colours from the theme. Keeping the whole visual language in one
##  place means a restyle is a change here, not a sweep through 49 scenes, and
##  it keeps Dark / Light in lockstep by construction.
##
##  Consumers: ThemeService (palette + base Theme), MenuStyle (menu components),
##  ScrambledTheme / ExerciseTheme / GrammarTheme (gameplay modules).
##
##  SCALE NOTE: the design language was authored against a ~930px reference
##  panel, while this app renders a 1080x1920 portrait mobile viewport. Every
##  length below is therefore the reference token multiplied to app scale
##  (radius 4/8/12/18 -> 8/18/24/36, shadow 8/16/28, icon 14/18/22 -> 34/44/54)
##  so the proportions in the reference are preserved at app size.
## ============================================================


# ══════════════════════════════════════════════════════════════
#  PALETTE
#  Dark is the reference design: a soft-UI charcoal shell, cream paper
#  surfaces, a warm gold rim and a vivid blue action colour. Light is the
#  same language inverted onto warm paper so the theme toggle stays coherent.
# ══════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- accents --
# The signature values as standalone consts. They exist so a SCREEN can name
# them in a `const` initialiser: indexing a const Dictionary is not a constant
# expression in GDScript, but referencing a const Color is. The palette below
# is built from these, so there is still exactly one place each colour lives.
const ACCENT              := Color("#4C8DF6")
const ACCENT_BRIGHT       := Color("#7FB2FF")
const ACCENT_DEEP         := Color("#2E5FAE")
const GOLD                := Color("#D9B36C")
const GOLD_BRIGHT         := Color("#F0DFA6")
const INK                 := Color("#36332C")
const PAPER               := Color("#EDE6D6")
const SURFACE_SUNKEN_DARK := Color("#2A2D33")
const SUCCESS             := Color("#5FBF7F")
const ERROR               := Color("#E06C75")
const WARNING             := Color("#E0B96B")

## Roles every palette must define. `ThemeService.get_theme_color()` falls back
## to white for an unknown role, so a missing key degrades to "invisible" —
## this list is the contract both palettes are validated against below.
const PALETTE_ROLES := [
	"bg_base", "bg", "surface", "surface_alt", "surface_sunken", "sidebar",
	"border", "border_strong", "text", "text_dim", "text_muted", "ink",
	"accent", "accent_bright", "accent_deep", "accent_soft", "on_accent",
	"gold", "gold_bright", "gold_soft", "gold_rim",
	"success", "error", "warning", "success_soft", "error_soft", "warning_soft",
	"overlay", "wave_top", "wave_mid", "wave_bottom",
]

const PALETTE_DARK := {
	# ── Shell: the charcoal plate the whole design sits on ──
	"bg_base":        Color("#1E2126"),   # outermost / behind everything
	"bg":             Color("#24272D"),   # page background
	"surface":        Color("#31353C"),   # card face
	"surface_alt":    Color("#3A3E46"),   # raised card / secondary surface
	"surface_sunken": SURFACE_SUNKEN_DARK,  # inset field, empty tile, table row
	"sidebar":        Color("#2B2F36"),   # tokens sidebar panel

	# ── Hairlines ──
	"border":         Color(1, 1, 1, 0.10),
	"border_strong":  Color(1, 1, 1, 0.16),

	# ── Type ──
	"text":           Color("#E7E5E0"),
	"text_dim":       Color("#A6A49D"),
	"text_muted":     Color("#83817B"),
	"ink":            INK,                # dark type meant for cream surfaces

	# ── Blue action colour (hover/pressed buttons, focus rings, toggles) ──
	"accent":         ACCENT,
	"accent_bright":  ACCENT_BRIGHT,
	"accent_deep":    ACCENT_DEEP,
	"accent_soft":    Color(0.298, 0.553, 0.965, 0.16),
	"on_accent":      Color("#FFFFFF"),

	# ── Warm gold: the signature rim, the "default" button, selected rows ──
	"gold":           GOLD,
	"gold_bright":    GOLD_BRIGHT,
	"gold_soft":      Color(0.851, 0.702, 0.424, 0.18),
	"gold_rim":       Color(0.851, 0.702, 0.424, 0.55),

	# ── Feedback ──
	"success":        SUCCESS,
	"error":          ERROR,
	"warning":        WARNING,
	"success_soft":   Color(0.373, 0.749, 0.498, 0.18),
	"error_soft":     Color(0.878, 0.424, 0.459, 0.18),
	"warning_soft":   Color(0.878, 0.725, 0.420, 0.18),

	# ── Scrim + ambient backdrop ──
	"overlay":        Color(0, 0, 0, 0.62),
	"wave_top":       Color("#3A4A63"),
	"wave_mid":       Color("#C0A063"),
	"wave_bottom":    Color("#2A3140"),
}

const PALETTE_LIGHT := {
	"bg_base":        Color("#EFEBE1"),
	"bg":             Color("#F5F2EA"),
	"surface":        Color("#FFFFFF"),
	"surface_alt":    Color("#FAF7F0"),
	"surface_sunken": Color("#EBE5D8"),
	"sidebar":        Color("#F2EEE4"),

	"border":         Color(0.235, 0.196, 0.118, 0.14),
	"border_strong":  Color(0.235, 0.196, 0.118, 0.24),

	"text":           Color("#2F2C26"),
	"text_dim":       Color("#6E6A61"),
	"text_muted":     Color("#918C82"),
	"ink":            Color("#36332C"),

	# Deeper blue so it keeps contrast against cream rather than glowing.
	"accent":         Color("#2F6FD8"),
	"accent_bright":  Color("#4C8DF6"),
	"accent_deep":    Color("#22539F"),
	"accent_soft":    Color(0.184, 0.435, 0.847, 0.12),
	"on_accent":      Color("#FFFFFF"),

	"gold":           Color("#A87C24"),
	"gold_bright":    Color("#C9A24A"),
	"gold_soft":      Color(0.659, 0.486, 0.141, 0.16),
	"gold_rim":       Color(0.659, 0.486, 0.141, 0.45),

	"success":        Color("#2E8B57"),
	"error":          Color("#C0392B"),
	"warning":        Color("#B8860B"),
	"success_soft":   Color(0.180, 0.545, 0.341, 0.14),
	"error_soft":     Color(0.753, 0.224, 0.169, 0.14),
	"warning_soft":   Color(0.722, 0.525, 0.043, 0.14),

	"overlay":        Color(0, 0, 0, 0.38),
	"wave_top":       Color("#DCE6F5"),
	"wave_mid":       Color("#E4D4A8"),
	"wave_bottom":    Color("#F0EDE4"),
}


# ══════════════════════════════════════════════════════════════
#  RADIUS STEPS   (reference: 4 / 8 / 12 / 18)
# ══════════════════════════════════════════════════════════════
const RADIUS_XS   := 8     # chips, tiny badges
const RADIUS_SM   := 18    # inputs, table rows, inset fields
const RADIUS_MD   := 24    # buttons, cards, dropdown panels
const RADIUS_LG   := 36    # large cards, modal body
const RADIUS_XL   := 48    # page shells, header bars
const RADIUS_PILL := 999   # fully rounded: toggles, sliders, toast, pills

# ══════════════════════════════════════════════════════════════
#  BORDER THICKNESS   (reference: 0.5 subtle / 1 standard / 1.5 prominent)
# ══════════════════════════════════════════════════════════════
const BORDER_SUBTLE    := 1
const BORDER_STANDARD  := 2
const BORDER_PROMINENT := 3

# ══════════════════════════════════════════════════════════════
#  SHADOW LEVELS   (reference: level 1 soft / level 2 medium / level 3 deep)
#  Soft-UI elevation is carried by the shadow, so these are generous.
# ══════════════════════════════════════════════════════════════
const SHADOW_SOFT_SIZE   := 14
const SHADOW_MEDIUM_SIZE := 22
const SHADOW_DEEP_SIZE   := 34

# ══════════════════════════════════════════════════════════════
#  ICON SIZES   (reference: 14 / 18 / 22)
# ══════════════════════════════════════════════════════════════
const ICON_SM := 34
const ICON_MD := 44
const ICON_LG := 54

# ══════════════════════════════════════════════════════════════
#  SPACING SCALE   (reference: 4 / 8 / 18 / 24 / 32 / 48)
# ══════════════════════════════════════════════════════════════
const SPACE_XS := 8
const SPACE_SM := 16
const SPACE_MD := 36
const SPACE_LG := 48
const SPACE_XL := 64
const SPACE_2XL := 96

# ══════════════════════════════════════════════════════════════
#  TYPE SCALE
# ══════════════════════════════════════════════════════════════
const FONT_TINY   := 26
const FONT_SMALL  := 30
const FONT_BODY   := 34
const FONT_LABEL  := 38
const FONT_TITLE  := 48
const FONT_HERO   := 62


# ══════════════════════════════════════════════════════════════
#  PALETTE ACCESS
# ══════════════════════════════════════════════════════════════

## Returns the palette dictionary for a theme mode without needing the autoload.
## MenuStyle and the module themes fall back to this during early boot, before
## Global has finished wiring ThemeService.
static func palette(dark: bool) -> Dictionary:
	return PALETTE_DARK if dark else PALETTE_LIGHT


## Convenience: one role straight out of a palette.
static func color_of(dark: bool, role: String) -> Color:
	return palette(dark).get(role, Color.WHITE)


# ══════════════════════════════════════════════════════════════
#  LOW-LEVEL STYLEBOX HELPERS
#  Every factory below is built from these, so geometry is never restated.
# ══════════════════════════════════════════════════════════════

## A filled, optionally bordered, optionally elevated rounded rect.
static func box(
		fill: Color,
		radius: int = RADIUS_MD,
		border_color: Color = Color(0, 0, 0, 0),
		border_width: int = 0,
		shadow_color: Color = Color(0, 0, 0, 0),
		shadow_size: int = 0,
		shadow_offset: Vector2 = Vector2.ZERO
	) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if border_width > 0:
		s.set_border_width_all(border_width)
		s.border_color = border_color
	if shadow_size > 0:
		s.shadow_color = shadow_color
		s.shadow_size = shadow_size
		s.shadow_offset = shadow_offset
	return s


## Uniform inner padding, applied only to the sides actually given.
static func pad(s: StyleBoxFlat, x: int, y: int) -> StyleBoxFlat:
	s.content_margin_left = x
	s.content_margin_right = x
	s.content_margin_top = y
	s.content_margin_bottom = y
	return s


## Padding with different horizontal / vertical amounts on each side.
static func pad_box(s: StyleBoxFlat, left: int, top: int, right: int, bottom: int) -> StyleBoxFlat:
	s.content_margin_left = left
	s.content_margin_top = top
	s.content_margin_right = right
	s.content_margin_bottom = bottom
	return s


## A soft elevation shadow tinted by its own fill, so a blue card casts blue.
## `size` is accepted for call-site symmetry with the shadow factories but not
## read here: the caller sets shadow_size on the StyleBoxFlat itself, so the
## tint and the geometry stay independently tunable.
static func glow(tint: Color, strength: float, _size: int) -> Color:
	return Color(tint.r, tint.g, tint.b, strength)


## Rounds only the top two corners — used by a modal's header band, which has to
## meet the square-shouldered body below it.
static func round_top(s: StyleBoxFlat, radius: int) -> StyleBoxFlat:
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	return s


## Rounds only the bottom two corners — the modal body / page header mirror.
static func round_bottom(s: StyleBoxFlat, radius: int) -> StyleBoxFlat:
	s.corner_radius_top_left = 0
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s


# ══════════════════════════════════════════════════════════════
#  BUTTONS — the five states in the reference sheet.
#    Default : cream surface with a warm gold rim + gold outer glow
#    Hover   : vivid blue, brighter blue rim, blue glow
#    Pressed : deeper blue, tight shadow (reads as pushed IN)
#    Disabled: flat grey, no rim, no shadow, no glow
#    Focus   : a soft blue ring drawn around whatever state is showing
# ══════════════════════════════════════════════════════════════

## The resting button: cream paper, gold rim, warm glow. This is the reference
## sheet's "Default" state — the neutral / secondary action.
## The fill is OPAQUE on purpose: `gold_soft` carries an alpha, and lerping
## from it would leave the button translucent, letting the page show through.
static func button_default(dark: bool = true) -> StyleBoxFlat:
	var fill: Color = Color("#E3D7BD") if dark else Color("#EFE7D2")
	var rim: Color = PALETTE_DARK["gold_rim"] if dark else PALETTE_LIGHT["gold_rim"]
	var gold: Color = PALETTE_DARK["gold"] if dark else PALETTE_LIGHT["gold"]
	var s := box(
		fill,
		RADIUS_PILL,
		rim,
		BORDER_STANDARD,
		glow(gold, 0.42 if dark else 0.24, SHADOW_SOFT_SIZE),
		SHADOW_SOFT_SIZE,
		Vector2.ZERO
	)
	return pad(s, SPACE_MD, SPACE_SM)


## The PRIMARY action — the modal's "Content" button and every "Continue" /
## "Check" / "Next" in the app. Flat accent blue with a bright rim + blue glow.
static func button_primary(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(
		p["accent"],
		RADIUS_PILL,
		p["accent_bright"],
		BORDER_STANDARD,
		glow(p["accent"], 0.50, SHADOW_MEDIUM_SIZE),
		SHADOW_MEDIUM_SIZE,
		Vector2.ZERO
	)
	return pad(s, SPACE_MD, SPACE_SM)


## Primary hover: a shade brighter so it still reacts after being the resting
## style of a call-to-action.
static func button_primary_hover(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(
		p["accent_bright"],
		RADIUS_PILL,
		p["accent_bright"],
		BORDER_STANDARD,
		glow(p["accent"], 0.65, SHADOW_MEDIUM_SIZE),
		SHADOW_MEDIUM_SIZE,
		Vector2.ZERO
	)
	return pad(s, SPACE_MD, SPACE_SM)


## Hover: the blue state. Fill lifts toward accent_bright.
static func button_hover(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(
		p["accent"],
		RADIUS_PILL,
		p["accent_bright"],
		BORDER_STANDARD,
		glow(p["accent"], 0.55, SHADOW_MEDIUM_SIZE),
		SHADOW_MEDIUM_SIZE,
		Vector2.ZERO
	)
	return pad(s, SPACE_MD, SPACE_SM)


## Pressed: deeper blue and a tighter shadow so the button sinks.
static func button_pressed(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(
		p["accent_deep"],
		RADIUS_PILL,
		p["accent"],
		BORDER_STANDARD,
		glow(p["accent_deep"], 0.50, SHADOW_SOFT_SIZE),
		SHADOW_SOFT_SIZE,
		Vector2(0, 4)
	)
	return pad(s, SPACE_MD, SPACE_SM)


## Disabled: contrast drops and the shadow is removed entirely.
static func button_disabled(dark: bool = true) -> StyleBoxFlat:
	var fill := Color("#4A4E54") if dark else Color("#D8D3C7")
	var s := box(fill, RADIUS_PILL, Color(0, 0, 0, 0), 0)
	return pad(s, SPACE_MD, SPACE_SM)


## Focus ring: a transparent body carrying only the blue outline, so it can be
## layered over any state without hiding it.
static func button_focus(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(Color(0, 0, 0, 0), RADIUS_PILL, p["accent_bright"], BORDER_PROMINENT)
	return pad(s, SPACE_MD, SPACE_SM)


## Text colour for a button in a given state. The cream default needs dark ink;
## the blue hover/pressed states need white.
static func button_text_color(state: String, dark: bool = true) -> Color:
	var p := palette(dark)
	match state:
		"default":
			# The resting button is cream in BOTH themes, so its label is always
			# ink. Light briefly used `gold` here, which lands at barely 3.5:1 on
			# the cream fill — under the 4.5:1 target for body-sized text.
			return p["ink"]
		"disabled":
			return p["text_muted"]
		_:
			return p["on_accent"]


# ══════════════════════════════════════════════════════════════
#  CARDS
# ══════════════════════════════════════════════════════════════

## The standard raised card: surface fill, hairline border, medium elevation.
static func card(dark: bool = true, lifted: bool = false, flat: bool = false) -> StyleBoxFlat:
	var p := palette(dark)
	var fill: Color = p["surface_alt"] if lifted else p["surface"]
	var s := box(fill, RADIUS_MD, p["border"], BORDER_SUBTLE)
	if not flat:
		s.shadow_color = Color(0, 0, 0, 0.32 if dark else 0.10)
		s.shadow_size = SHADOW_MEDIUM_SIZE if lifted else SHADOW_SOFT_SIZE
		s.shadow_offset = Vector2(0, 10 if lifted else 6)
	return pad(s, SPACE_MD, SPACE_MD)


## The warm paper card — the cream tile in the reference, with a gold rim.
## Use for anything meant to feel "dealt on top of" the app.
static func card_paper(dark: bool = true) -> StyleBoxFlat:
	var fill: Color = Color("#EDE6D6") if dark else Color("#FFFDF6")
	var s := box(
		fill,
		RADIUS_MD,
		PALETTE_DARK["gold_rim"] if dark else PALETTE_LIGHT["gold_rim"],
		BORDER_SUBTLE,
		Color(0, 0, 0, 0.35 if dark else 0.12),
		SHADOW_MEDIUM_SIZE,
		Vector2(0, 10)
	)
	return pad(s, SPACE_MD, SPACE_MD)


## The blue-tinted card (the reference's first card) — an accent-identified tile.
static func card_accent(dark: bool = true) -> StyleBoxFlat:
	var fill: Color = Color("#3C5570") if dark else Color("#DCE8F8")
	var s := box(fill, RADIUS_MD, palette(dark)["accent_soft"], BORDER_SUBTLE)
	s.shadow_color = Color(0, 0, 0, 0.34 if dark else 0.10)
	s.shadow_size = SHADOW_MEDIUM_SIZE
	s.shadow_offset = Vector2(0, 10)
	return pad(s, SPACE_MD, SPACE_MD)


## Inset / sunken surface: inputs, empty-state tiles, unselected table rows.
## A StyleBoxFlat cannot draw a true inner shadow, so the "pressed into the
## plate" read comes from a fill darker than its parent plus a light top edge.
static func inset(dark: bool = true, radius: int = RADIUS_SM) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(p["surface_sunken"], radius, p["border"], BORDER_SUBTLE)
	s.border_width_top = BORDER_STANDARD
	s.border_color = Color(1, 1, 1, 0.06) if dark else Color(0, 0, 0, 0.07)
	return pad(s, SPACE_MD, SPACE_SM)


## Focused input: the inset body plus the reference's always-visible soft ring.
static func input_focus(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(
		p["surface_sunken"],
		RADIUS_SM,
		p["accent"],
		BORDER_STANDARD,
		glow(p["accent"], 0.40, SHADOW_SOFT_SIZE),
		SHADOW_SOFT_SIZE,
		Vector2.ZERO
	)
	return pad(s, SPACE_MD, SPACE_SM)


# ══════════════════════════════════════════════════════════════
#  CHIPS, PILLS & BADGES
# ══════════════════════════════════════════════════════════════

## Rounded square behind a card's icon / emoji, tinted by its identity colour.
static func icon_chip(accent_col: Color, radius: int = RADIUS_XS, dark: bool = true) -> StyleBoxFlat:
	var a := 0.26 if dark else 0.14
	var s := box(
		Color(accent_col.r, accent_col.g, accent_col.b, a),
		radius,
		Color(accent_col.r, accent_col.g, accent_col.b, 0.42),
		BORDER_SUBTLE
	)
	return s


## Fully rounded status pill (counts, levels, tags).
static func pill(accent_col: Color, dark: bool = true) -> StyleBoxFlat:
	var a := 0.22 if dark else 0.12
	var s := box(
		Color(accent_col.r, accent_col.g, accent_col.b, a),
		RADIUS_PILL,
		Color(accent_col.r, accent_col.g, accent_col.b, 0.45),
		BORDER_SUBTLE
	)
	return pad(s, SPACE_SM, SPACE_XS)


# ══════════════════════════════════════════════════════════════
#  TABLES (the reference's three row states)
# ══════════════════════════════════════════════════════════════

static func table_row(state: String, dark: bool = true) -> StyleBoxFlat:
	match state:
		"hover":
			var p := palette(dark)
			var s := box(
				p["accent"],
				RADIUS_SM,
				p["accent_bright"],
				BORDER_SUBTLE,
				glow(p["accent"], 0.45, SHADOW_SOFT_SIZE),
				SHADOW_SOFT_SIZE,
				Vector2.ZERO
			)
			return pad(s, SPACE_MD, SPACE_SM)
		"selected":
			var q := palette(dark)
			# Opaque gold-cream: lerping from `gold_soft` would inherit its
			# alpha and the row would blend into whatever sits behind it.
			var sel_fill: Color = Color("#4A4231") if dark else Color("#F2E7C9")
			var g := box(
				sel_fill,
				RADIUS_SM,
				q["gold_rim"],
				BORDER_STANDARD,
				glow(q["gold"], 0.30, SHADOW_SOFT_SIZE),
				SHADOW_SOFT_SIZE,
				Vector2.ZERO
			)
			return pad(g, SPACE_MD, SPACE_SM)
		_:
			return inset(dark, RADIUS_SM)


## Type colour that stays legible on each row state.
static func table_row_text_color(state: String, dark: bool = true) -> Color:
	var p := palette(dark)
	if state == "hover":
		return p["on_accent"]
	if state == "selected":
		return p["gold_bright"] if dark else p["gold"]
	return p["text"]


# ══════════════════════════════════════════════════════════════
#  MODAL DIALOG — blue header band, cream body, deep diffuse shadow.
#  Emitted as a Dictionary so a caller can put `header` on the title bar and
#  `body` on the content panel without this module knowing the tree shape.
# ══════════════════════════════════════════════════════════════

static func modal(dark: bool = true) -> Dictionary:
	var p := palette(dark)
	var header := box(p["accent"], RADIUS_LG, p["accent_bright"], BORDER_SUBTLE)
	round_top(header, RADIUS_LG)
	pad(header, SPACE_MD, SPACE_SM)

	# A single deep shadow belongs to the BODY: the header sits flush on top of
	# it, so giving both an elevation would double the darkening at the seam.
	var body_fill: Color = Color("#EFE9DA") if dark else Color("#FFFDF6")
	var body := box(body_fill, RADIUS_LG, p["border"], BORDER_SUBTLE)
	round_bottom(body, RADIUS_LG)
	pad(body, SPACE_LG, SPACE_LG)
	body.shadow_color = Color(0, 0, 0, 0.50 if dark else 0.18)
	body.shadow_size = SHADOW_DEEP_SIZE
	body.shadow_offset = Vector2(0, 16)

	return {"header": header, "body": body}


## Type colours for the modal, since its body is always a light surface.
static func modal_text_color(dark: bool = true) -> Color:
	return Color("#3A3730") if dark else Color("#2F2C26")


# ══════════════════════════════════════════════════════════════
#  TOAST — cream notification with a success tick, floating on a soft shadow.
# ══════════════════════════════════════════════════════════════

static func toast(dark: bool = true) -> StyleBoxFlat:
	var fill: Color = Color("#EDE6D6") if dark else Color("#FFFDF6")
	var s := box(
		fill,
		RADIUS_MD,
		PALETTE_DARK["gold_rim"] if dark else PALETTE_LIGHT["gold_rim"],
		BORDER_SUBTLE,
		Color(0, 0, 0, 0.38 if dark else 0.14),
		SHADOW_MEDIUM_SIZE,
		Vector2(0, 10)
	)
	return pad(s, SPACE_MD, SPACE_SM)


## The circular tick badge inside a toast.
static func toast_badge(dark: bool = true) -> StyleBoxFlat:
	return box(PALETTE_DARK["success"] if dark else PALETTE_LIGHT["success"], RADIUS_PILL)


# ══════════════════════════════════════════════════════════════
#  CONTROLS — toggle, slider, progress
# ══════════════════════════════════════════════════════════════

## Toggle track: accent + glow when on, flat grey when off.
static func toggle_track(on: bool, dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	if on:
		var s := box(
			p["accent"],
			RADIUS_PILL,
			p["accent_bright"],
			BORDER_SUBTLE,
			glow(p["accent"], 0.45, SHADOW_SOFT_SIZE),
			SHADOW_SOFT_SIZE,
			Vector2.ZERO
		)
		return s
	return box(Color("#4A4E54") if dark else Color("#CFC9BC"), RADIUS_PILL)


## Toggle knob: a cream disc that carries its own small shadow.
static func toggle_knob(dark: bool = true) -> StyleBoxFlat:
	var fill: Color = Color("#EDE6D6") if dark else Color("#FFFFFF")
	var s := box(
		fill,
		RADIUS_PILL,
		Color(0, 0, 0, 0.10),
		BORDER_SUBTLE,
		Color(0, 0, 0, 0.42),
		SHADOW_SOFT_SIZE,
		Vector2(0, 3)
	)
	return s


## Slider: a sunken track, an accent fill up to the current value, and a cream
## grabber matching the reference's discs.
static func slider_track(dark: bool = true) -> StyleBoxFlat:
	return box(palette(dark)["surface_sunken"], RADIUS_PILL)


static func slider_fill(dark: bool = true) -> StyleBoxFlat:
	return box(palette(dark)["accent"], RADIUS_PILL)


## A Slider's `grabber` is an ICON (Texture2D), NOT a StyleBox — Godot's
## Slider theme type exposes `slider` / `grabber_area` as styleboxes and
## `grabber` as a texture. So the reference's cream knob is drawn procedurally
## as a radial-gradient disc instead of shipping an image asset.
static func slider_grabber_texture(dark: bool = true) -> Texture2D:
	var fill: Color = Color("#EDE6D6") if dark else Color("#FFFFFF")
	var grad := Gradient.new()
	# Hold the fill out to 0.86 of the radius, then fall to fully transparent,
	# which gives a crisp disc rather than a fuzzy blob.
	grad.set_color(0, fill)
	grad.set_color(1, Color(fill.r, fill.g, fill.b, 0.0))
	grad.add_point(0.86, fill)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = ICON_LG
	tex.height = ICON_LG
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


## Progress bar: blue fill with the reference's glowing rounded cap, over a
## gold-tinted remainder track.
static func progress_fill(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(
		p["accent"],
		RADIUS_PILL,
		p["accent_bright"],
		BORDER_SUBTLE,
		glow(p["accent"], 0.50, SHADOW_SOFT_SIZE),
		SHADOW_SOFT_SIZE,
		Vector2.ZERO
	)
	return s


static func progress_track(dark: bool = true) -> StyleBoxFlat:
	# Opaque so the un-filled remainder reads as a real gold-tinted track
	# rather than the page showing through a translucent tint.
	var fill: Color = Color("#4A4231") if dark else Color("#E9DFC0")
	return box(fill, RADIUS_PILL)


# ══════════════════════════════════════════════════════════════
#  EMPTY STATE — the inset tile with a rounded icon and centred muted copy.
# ══════════════════════════════════════════════════════════════

static func empty_tile(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var s := box(p["surface_sunken"], RADIUS_MD, p["border"], BORDER_SUBTLE)
	s.content_margin_left = SPACE_LG
	s.content_margin_right = SPACE_LG
	s.content_margin_top = SPACE_XL
	s.content_margin_bottom = SPACE_XL
	return s


# ══════════════════════════════════════════════════════════════
#  CHROME — header bar & scrollbars
# ══════════════════════════════════════════════════════════════

## Page header: rounded bottom shoulders, a gold underline and a soft drop.
static func header_bar(dark: bool = true) -> StyleBoxFlat:
	var p := palette(dark)
	var fill: Color = Color("#2E323A", 0.96) if dark else Color("#FFFDF6", 0.97)
	var s := box(fill, RADIUS_XL, p["border"], 0)
	round_bottom(s, RADIUS_LG)
	s.border_width_bottom = BORDER_PROMINENT
	s.border_color = p["gold_rim"]
	s.shadow_color = Color(0, 0, 0, 0.42 if dark else 0.14)
	s.shadow_size = SHADOW_MEDIUM_SIZE
	s.shadow_offset = Vector2(0, 8)
	return s


static func scrollbar_grabber(dark: bool = true) -> StyleBoxFlat:
	return box(palette(dark)["accent"], RADIUS_PILL)


static func scrollbar_track() -> StyleBoxFlat:
	return box(Color(0, 0, 0, 0), RADIUS_PILL)


# ══════════════════════════════════════════════════════════════
#  VALIDATION — used by tests to guarantee the two palettes stay in lockstep.
# ══════════════════════════════════════════════════════════════

## Every role both palettes must define. Returns the missing role names, so a
## half-finished palette fails loudly in a test instead of silently rendering
## white-on-white in production.
static func missing_roles() -> Array:
	var missing: Array = []
	for role in PALETTE_ROLES:
		if not PALETTE_DARK.has(role):
			missing.append("dark:" + role)
		if not PALETTE_LIGHT.has(role):
			missing.append("light:" + role)
	return missing
