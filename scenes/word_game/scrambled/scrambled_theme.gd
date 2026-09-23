class_name ScrambledTheme
extends RefCounted
## ============================================================
##  SCRAMBLED THEME — the visual language of «بازی املا».
##
##  The game screens are skipped by the app-wide theme walk (they are listed
##  in ThemeService.SELF_THEMED_SCRIPTS) because a game board must not lose
##  its colours to a restyle pass. Everything theme-dependent therefore comes
##  from here: the page tint, the card surfaces and the text roles read the
##  palette through MenuStyle, while the game parts — the letter tiles, their
##  candy palette, the solved green, the amber near-miss — are fixed, so a
##  board looks the same in Dark and Light and a live theme toggle never
##  repaints a puzzle in progress.
##
##  Tiles draw themselves (see ScrambledTile), so nothing here is ever
##  applied to a Panel or a Label by the walk.
## ============================================================

## The letter-tile palette. Soft candy colours in the style of classic word
## games: a flat face, a darker extruded bottom edge and a big white letter.
const TILE_COLORS := [
	Color("#A78BFA"),   # lavender
	Color("#F472B6"),   # pink
	Color("#60A5FA"),   # blue
	Color("#34D399"),   # mint
	Color("#FBBF24"),   # amber
	Color("#FB7185"),   # coral
	Color("#2DD4BF"),   # teal
	Color("#F97316"),   # orange
]

## The dark outline around every tile block, in both themes — part of the
## tile's identity, like its colours.
const TILE_OUTLINE := Color("#4A3B63")

## A solved tile turns green, and the near-miss nudge is amber.
const SOLVED_COLOR := Color("#31C463")
const NUDGE_COLOR := Color("#FFB703")

## The meaning card wears a printed look — warm cream, green frame, dark ink —
## in both themes, like a card dealt on top of the board.
const CARD_BG := Color(0.984, 0.953, 0.898)
const CARD_BORDER := Color(0.345, 0.780, 0.525)
const CARD_INK := Color(0.208, 0.216, 0.290)
const CARD_INK_DIM := Color(0.373, 0.392, 0.463)
const CARD_ACCENT := Color(0.180, 0.639, 0.404)


static func tile_color(index: int) -> Color:
	if TILE_COLORS.is_empty():
		return Color("#4D96FF")
	return TILE_COLORS[absi(index) % TILE_COLORS.size()]


static func tile_edge(body: Color) -> Color:
	return body.darkened(0.34)


## The colour of the extruded bottom edge of a tile: a deeper shade of its
## face, which is what makes the tile read as a chunky 3D block.
static func tile_side(body: Color) -> Color:
	return body.darkened(0.30)


## Letters are always white on the candy colours, like the classic games.
static func tile_letter(_body: Color) -> Color:
	return Color(1, 1, 1)


## The page behind the game. Matches the app's other screens so the animated
## backdrop keeps reading the same way.
static func page_tint() -> Color:
	if MenuStyle.is_dark():
		return Color(0.055, 0.070, 0.130)
	return Color(0.937, 0.965, 1.0)


## A soft plate behind a tile row: barely there in both themes.
static func track_color() -> Color:
	if MenuStyle.is_dark():
		return Color(1, 1, 1, 0.05)
	return Color(0.09, 0.13, 0.25, 0.05)


## The empty slot the carried tile would drop into.
static func ghost_color(pulse: float) -> Color:
	var base := Color("#4D96FF")
	return Color(base.r, base.g, base.b, 0.10 + 0.16 * pulse)


static func ghost_border_color(pulse: float) -> Color:
	var base := Color("#4D96FF")
	return Color(base.r, base.g, base.b, 0.55 + 0.40 * pulse)


## Rounded panel used by the game's chips and cards.
static func chip_style(fill: Color, radius: int = 22, border: Color = Color(0, 0, 0, 0),
		border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## The printed meaning card: cream paper with a green frame.
static func hint_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(36)
	style.set_border_width_all(5)
	style.border_color = CARD_BORDER
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 10)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	return style


## Timer bar fill for a solve time: green while the word is still worth the
## top band, then amber, orange and red as the bands fall away.
static func timer_color(seconds: float) -> Color:
	if seconds <= 10.0:
		return Color("#31C463")
	if seconds <= 30.0:
		return Color("#8BC34A")
	if seconds <= 50.0:
		return NUDGE_COLOR
	if seconds <= 60.0:
		return Color("#FF9245")
	return Color("#EF4444")


static func timer_track_color() -> Color:
	if MenuStyle.is_dark():
		return Color(1, 1, 1, 0.10)
	return Color(0.09, 0.13, 0.25, 0.09)
