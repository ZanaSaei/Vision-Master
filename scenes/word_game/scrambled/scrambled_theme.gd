class_name ScrambledTheme
extends RefCounted
## ============================================================
##  SCRAMBLED THEME — the visual language of «بازی املا».
##
##  The game screens are skipped by the app-wide theme walk (they are listed
##  in ThemeSceneStyler.SELF_THEMED_SCRIPTS) because a game board must not lose
##  its colours to a restyle pass. Everything theme-dependent therefore comes
##  from here: the page tint, the card surfaces and the text roles read the
##  palette through MenuStyle, while the game parts — the letter tiles, their
##  candy palette, the solved green, the amber near-miss — are fixed, so a
##  board looks the same in Dark and Light and a live theme toggle never
##  repaints a puzzle in progress.
##
##  Tiles draw themselves (see ScrambledTile), so nothing here is ever
##  applied to a Panel or a Label by the walk.
## ==============================================## The letter-tile palette, retuned to the app's design language: the blue
## action colour and the warm gold lead, supported by muted slate, moss, teal,
## coral and cream. A flat face with a darker extruded edge and a big letter.
const TILE_COLORS := [
	Color("#4C8DF6"),   # design blue
	Color("#D9B36C"),   # warm gold
	Color("#6E8BB0"),   # slate blue
	Color("#6FAE7C"),   # moss
	Color("#5FB8C4"),   # teal
	Color("#D97A6C"),   # coral
	Color("#A98BB8"),   # mauve
	Color("#E3D7BD"),   # cream
]

## The dark outline around every tile block, in both themes — part of the
## tile's identity, like its colours.
const TILE_OUTLINE := Color("#2A2D33")

## A solved tile turns green, and the near-miss nudge is amber.
const SOLVED_COLOR := Color("#5FBF7F")
const NUDGE_COLOR := Color("#E0B96B")

## The meaning card wears a printed look — warm cream paper, gold frame, dark
## ink — matching the design system's paper surface in both themes.
const CARD_BG := Color(0.929, 0.902, 0.839)
const CARD_BORDER := Color(0.851, 0.702, 0.424)
const CARD_INK := Color(0.212, 0.200, 0.173)
const CARD_INK_DIM := Color(0.373, 0.392, 0.463)
const CARD_ACCENT := Color(0.298, 0.553, 0.965)


static func tile_color(index: int) -> Color:
	if TILE_COLORS.is_empty():
		return DesignTokens.PALETTE_DARK["accent"]
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
		return DesignTokens.color_of(true, "bg")
	return DesignTokens.color_of(false, "bg")


## A soft plate behind a tile row: barely there in both themes.
static func track_color() -> Color:
	if MenuStyle.is_dark():
		return Color(DesignTokens.PALETTE_DARK["surface_sunken"], 0.60)
	return Color(DesignTokens.PALETTE_LIGHT["surface_sunken"], 0.70)


## The empty slot the carried tile would drop into.
static func ghost_color(pulse: float) -> Color:
	var base := DesignTokens.PALETTE_DARK["accent"]
	return Color(base.r, base.g, base.b, 0.10 + 0.16 * pulse)


static func ghost_border_color(pulse: float) -> Color:
	var base := DesignTokens.PALETTE_DARK["accent"]
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


## Filled, chunky, candy-style button — the game's own button look rather than
## the menu's: a solid block, a darker extruded edge, and a soft drop shadow
## that deepens on hover.
static func candy_button_style(color: Color, hover: bool = false) -> StyleBoxFlat:
	var fill := color.lightened(0.10) if hover else color
	var style := chip_style(fill, 30, tile_edge(fill), 3)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0.06, 0.09, 0.18, 0.30 if hover else 0.22)
	style.shadow_size = 26 if hover else 18
	style.shadow_offset = Vector2(0.0, 12.0 if hover else 8.0)
	return style


## The printed meaning card: cream paper with a green frame.
static func hint_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(36)
	style.set_border_width_all(DesignTokens.BORDER_PROMINENT)
	style.border_color = CARD_BORDER
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = DesignTokens.SHADOW_DEEP_SIZE
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
		return DesignTokens.PALETTE_DARK["success"]
	if seconds <= 30.0:
		return DesignTokens.PALETTE_DARK["success"].darkened(0.12)
	if seconds <= 50.0:
		return NUDGE_COLOR
	if seconds <= 60.0:
		return DesignTokens.PALETTE_DARK["warning"].darkened(0.10)
	return DesignTokens.PALETTE_DARK["error"]


static func timer_track_color() -> Color:
	if MenuStyle.is_dark():
		return Color(DesignTokens.PALETTE_DARK["surface_sunken"], 0.80)
	return Color(DesignTokens.PALETTE_LIGHT["surface_sunken"], 0.85)


# ══════════════════════════════════════════════════════════════════════════
#  THE GAME'S THEME
#
#  Every look of «بازی املا» is declared ONCE here, as a theme TYPE VARIATION,
#  and the game's scenes simply name the variation they want with
#  `theme_type_variation`. No component calls add_theme_*_override for a static
#  look any more, which is what the project's UI rules ask for: one place owns
#  a colour, a font or a shape, and the dark/light switch becomes a single
#  theme swap instead of a walk over every node.
#
#  WHAT STAYS AN OVERRIDE, and why: the board's tile colours (solved green,
#  the amber nudge, the per-tile candy palette) and the Wordle-style keyboard
#  states carry MEANING — they say "this letter is right" rather than "this is
#  how the app looks" — so they are computed per tile at runtime. Those are the
#  only overrides the game has left.
# ══════════════════════════════════════════════════════════════════════════

## Variation names. A scene names one of these; the look behind it lives here.
## Held as constants so a typo is a compile error rather than a node that
## silently falls back to the plain app look.
const V_CHIP_PROGRESS := &"ScrambledChipProgress"
const V_CHIP_MODE := &"ScrambledChipMode"
const V_CHIP_WORTH := &"ScrambledChipWorth"
const V_CHIP_SCORE := &"ScrambledChipScore"
const V_TIMER_BAR := &"ScrambledTimerBar"
const V_INSTRUCTION := &"ScrambledInstruction"
const V_HINT_CARD := &"ScrambledHintCard"
const V_HINT_CAPTION := &"ScrambledHintCaption"
const V_HINT_MEANING := &"ScrambledHintMeaning"
const V_HINT_PERSIAN := &"ScrambledHintPersian"
const V_HINT_WORTH := &"ScrambledHintWorth"
const V_CANDY_BUTTON := &"ScrambledCandyButton"
const V_REVEAL_BUTTON := &"ScrambledRevealButton"
const V_DANGER_BUTTON := &"ScrambledDangerButton"
const V_DIALOG_CARD := &"ScrambledDialogCard"
const V_DIALOG_TITLE := &"ScrambledDialogTitle"
const V_DIALOG_BODY := &"ScrambledDialogBody"
## The dialog's safe answer. Its own variation rather than the app's Button,
## because the game's theme carries no base theme to inherit one from.
const V_SAFE_BUTTON := &"ScrambledSafeButton"
const V_PRAISE := &"ScrambledPraise"
const V_POINTS := &"ScrambledPoints"

## The accents each variation wears. Fixed per meaning, so a number keeps its
## colour identity as it changes.
const CHIP_MODE_ACCENT := Color("#C77DFF")
const CHIP_WORTH_ACCENT := Color("#FFB703")
const CHIP_SCORE_ACCENT := Color("#31C463")
const DANGER_ACCENT := Color("#FF6B6B")
const CANDY_RADIUS := 30
const CANDY_FONT_SIZE := 40
const REVEAL_FONT_SIZE := 30
const DIALOG_RADIUS := 34
const DIALOG_BUTTON_FONT_SIZE := 36
const TIMER_RADIUS := 12
const PRAISE_FONT_SIZE := 84
const POINTS_FONT_SIZE := 62


## Builds the game's Theme.
##
## WHY IT DOES NOT CHAIN ONTO THE APP'S BASE THEME: `Theme.base_theme` cannot be
## assigned from script in this engine build — the assignment is rejected, and a
## rejected one aborts the builder outright, leaving the screen with no theme at
## all. So instead of inheriting, the theme states the few app-wide defaults the
## game's plain controls rely on, read from the SAME design tokens the app theme
## is built from: one source of colours and type, two readers. Nothing below
## invents a font, a grey or a radius of its own.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = MenuStyle.vazir()
	theme.default_font_size = DesignTokens.FONT_BODY
	# A control that wears no variation still has to read on this screen, so the
	# Label defaults are set here rather than left to the engine's white.
	theme.set_color("font_color", "Label", MenuStyle.text())
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
	theme.set_constant("outline_size", "Label", 0)

	# The four standing chips, one variation each so a scene only has to name
	# which number it is showing.
	_pill(theme, V_CHIP_PROGRESS, DesignTokens.ACCENT, 30)
	_pill(theme, V_CHIP_MODE, CHIP_MODE_ACCENT, 28)
	_pill(theme, V_CHIP_WORTH, CHIP_WORTH_ACCENT, 28)
	_pill(theme, V_CHIP_SCORE, CHIP_SCORE_ACCENT, 30)

	# The clock: shape here, colour per tick (the bar's colour is the clock's
	# own reading, not a look).
	theme.set_type_variation(V_TIMER_BAR, &"ProgressBar")
	theme.set_stylebox("background", V_TIMER_BAR, _bar_box(timer_track_color()))
	theme.set_stylebox("fill", V_TIMER_BAR, _bar_box(timer_color(0.0)))

	_label(theme, V_INSTRUCTION, &"Label", MenuStyle.vazir(), 36, MenuStyle.subtitle_color())

	# The printed meaning card: fixed paper colours on purpose, so it reads the
	# same in both themes like a card dealt onto the board.
	theme.set_type_variation(V_HINT_CARD, &"PanelContainer")
	theme.set_stylebox("panel", V_HINT_CARD, hint_card_style())
	_label(theme, V_HINT_CAPTION, &"Label", MenuStyle.vazir(), 32, CARD_ACCENT)
	_label(theme, V_HINT_MEANING, &"Label", MenuStyle.jakarta_bold(), 40, CARD_INK)
	_label(theme, V_HINT_PERSIAN, &"Label", MenuStyle.vazir(), 32, CARD_INK_DIM)
	_label(theme, V_HINT_WORTH, &"Label", MenuStyle.vazir(), 28, CARD_ACCENT)

	_candy_button(theme, V_CANDY_BUTTON, Color("#FFB703"), CANDY_FONT_SIZE)
	_candy_button(theme, V_REVEAL_BUTTON, DesignTokens.ACCENT_BRIGHT, REVEAL_FONT_SIZE)
	_candy_button(theme, V_DANGER_BUTTON, DANGER_ACCENT, DIALOG_BUTTON_FONT_SIZE)

	theme.set_type_variation(V_DIALOG_CARD, &"PanelContainer")
	theme.set_stylebox("panel", V_DIALOG_CARD, MenuStyle.card_style(MenuStyle.accent(), DIALOG_RADIUS, true))
	_label(theme, V_DIALOG_TITLE, &"Label", MenuStyle.vazir(), 46, MenuStyle.text())
	_label(theme, V_DIALOG_BODY, &"Label", MenuStyle.vazir(), 32, MenuStyle.subtitle_color())
	# Staying is the safe answer, so it wears the app accent; leaving wears the
	# one danger colour the dialog owns. Both are the game's candy button, so
	# the pair reads as one choice rather than two design languages.
	_candy_button(theme, V_SAFE_BUTTON, MenuStyle.accent(), DIALOG_BUTTON_FONT_SIZE)

	# Win feedback. Both colours carry meaning — the praise green is the solved
	# colour, the points amber the "worth" colour — so neither follows the theme.
	_label(theme, V_PRAISE, &"Label", MenuStyle.vazir(), PRAISE_FONT_SIZE, SOLVED_COLOR, 10)
	_label(theme, V_POINTS, &"Label", MenuStyle.vazir(), POINTS_FONT_SIZE, NUDGE_COLOR)

	return theme


## A pill chip: translucent accent fill, high-contrast text, fully rounded.
static func _pill(theme: Theme, variation: StringName, accent: Color, font_size: int) -> void:
	_label(theme, variation, &"Label", MenuStyle.vazir(), font_size, MenuStyle.pill_text(accent),
		0, MenuStyle.icon_chip(accent, 20))


## A filled, chunky candy button: the game's own button look rather than the
## menu's. The ink comes from the fill's luminance so a light block gets dark
## text and a saturated one gets white.
static func _candy_button(theme: Theme, variation: StringName, accent: Color,
		font_size: int) -> void:
	theme.set_type_variation(variation, &"Button")
	theme.set_font("font", variation, MenuStyle.vazir())
	theme.set_font_size("font_size", variation, font_size)
	var ink := MenuStyle.on_accent(accent)
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(slot, variation, ink)
	# The same ink on hover and press: a label that flips colour mid-gesture
	# reads as a glitch, not as feedback.
	theme.set_stylebox("normal", variation, candy_button_style(accent, false))
	theme.set_stylebox("focus", variation, candy_button_style(accent, false))
	theme.set_stylebox("hover", variation, candy_button_style(accent, true))
	theme.set_stylebox("pressed", variation, candy_button_style(accent, true))
	theme.set_stylebox("disabled", variation, candy_button_style(accent.darkened(0.35), false))


static func _label(theme: Theme, variation: StringName, base_type: StringName, font: Font,
		font_size: int, color: Color, outline: int = 0, box: StyleBox = null) -> void:
	theme.set_type_variation(variation, base_type)
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)
	theme.set_constant("outline_size", variation, outline)
	if box != null:
		theme.set_stylebox("normal", variation, box)


static func _bar_box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(TIMER_RADIUS)
	style.bg_color = color
	return style
