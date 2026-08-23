class_name GrammarTheme
extends RefCounted


# ============================================================
# COLORS
# ============================================================

# ============================================================
# COLORS  —  eye-friendly DARK palette (soft, low contrast)
# Surfaces are dark slate; text is warm light. Bright accent
# colors are kept saturated but gentle so they read on dark.
# ============================================================

const BACKGROUND := Color("049797ff")
const SURFACE := Color("0e2619ff")

const PRIMARY := Color("#6C7AFF")
const PRIMARY_DARK := Color("#8490FF")
const PRIMARY_LIGHT := Color("#262B4D")

const SECONDARY := Color("#6FD6C2")
const SECONDARY_LIGHT := Color("#18332C")

const TEXT := Color("ffffffff")
const TEXT_SECONDARY := Color("ffffdcff")
const TEXT_MUTED := Color("ffffebff")

const SUCCESS := Color("#3CCF7E")
const SUCCESS_LIGHT := Color("#173322")

const ERROR := Color("#F26D86")
const ERROR_LIGHT := Color("#3A1E27")

const WARNING := Color("#FFC24D")
const WARNING_LIGHT := Color("#3A2E14")

const XP := Color("#FFC24D")

const DISABLED := Color("#2A2F3D")


# ============================================================
# THEME-AWARE COLORS
# ------------------------------------------------------------
# The grammar palette, resolved per app theme mode. Dark mode
# reproduces the legacy constants above exactly; Light mode
# borrows the app-wide Global palette where a role maps 1:1 and
# keeps grammar-specific accent / gold hues with a light variant.
# All static style helpers below derive from these, so every
# GrammarTheme-styled widget follows the current Dark / Light mode.
# ============================================================

static func _pick(dark: Color, light: Color) -> Color:
	return dark if Global.theme_is_dark() else light


# Primary brand accent (button fills, borders, selected markers).
static func accent_color() -> Color:
	return _pick(PRIMARY, Global.get_theme_color("accent"))


# Lighter accent used for hover fills / bright accents.
static func accent_bright_color() -> Color:
	return _pick(PRIMARY_DARK, Global.get_theme_color("accent_bright"))


# Muted accent surface used for selected / hover chip backgrounds.
static func accent_soft_color() -> Color:
	return _pick(PRIMARY_LIGHT, Global.get_theme_color("accent_soft"))


# Accent used as a *font* color (needs to read on a light surface).
static func accent_font_color() -> Color:
	return _pick(PRIMARY_DARK, Global.get_theme_color("accent"))


static func text_secondary_color() -> Color:
	return _pick(TEXT_SECONDARY, Global.get_theme_color("text_dim"))


static func text_muted_color() -> Color:
	return _pick(TEXT_MUTED, Global.get_theme_color("text_dim"))


static func success_color() -> Color:
	return Global.get_theme_color("success")


static func success_soft_color() -> Color:
	return _pick(SUCCESS_LIGHT, Global.get_theme_color("success").lightened(0.82))


static func error_color() -> Color:
	return Global.get_theme_color("error")


static func error_soft_color() -> Color:
	return _pick(ERROR_LIGHT, Global.get_theme_color("error").lightened(0.85))


static func warning_color() -> Color:
	return Global.get_theme_color("warning")


static func xp_color() -> Color:
	return _pick(XP, Color(0.62, 0.45, 0.0))


# ============================================================
# TYPOGRAPHY & SPACING (sized for a phone portrait UI)
# ============================================================

const HEADING_SIZE := 46
const BODY_LARGE_SIZE := 42
const BODY_SIZE := 46
const BODY_SMALL_SIZE := 34
const SECTION_SIZE := 42
const CAPTION_SIZE := 28

const SPACING_SM := 50
const SPACING_MD := 100
const SPACING_LG := 30

const BUTTON_HEIGHT := 78
const CARD_RADIUS := 24

# Shared font size for question answer buttons. Matching uses its own
# value below so its pair labels can differ from the rest.
const BUTTON_FONT_SIZE := 36
const BUTTON_FONT_SIZE_MATCHING := 24

# Margin kept clear around the whole screen edge so content never
# sits under a phone notch / rounded corner.
const SAFE_MARGIN := 60

# Extra padding inside the main grammar content card.
const CONTENT_MARGIN := 20


# ============================================================
# FONTS
# ============================================================

const FONT_FA_REGULAR_PATH := \
	"res://assets/fonts/Vazirmatn-Regular.ttf"

const FONT_FA_BOLD_PATH := \
	"res://assets/fonts/Vazirmatn-Regular.ttf"
	

const FONT_EN_REGULAR_PATH := \
	"res://assets/fonts/Nunito-Regular.ttf"
	

const FONT_EN_BOLD_PATH := \
	"res://assets/fonts/Nunito-Bold.ttf"
	


static func get_fa_regular() -> Font:
	return load(FONT_FA_REGULAR_PATH) as Font


static func get_fa_bold() -> Font:
	return load(FONT_FA_BOLD_PATH) as Font


static func get_en_regular() -> Font:
	return load(FONT_EN_REGULAR_PATH) as Font


static func get_en_bold() -> Font:
	return load(FONT_EN_BOLD_PATH) as Font


static func measure_text(
	font: Font,
	text: String,
	font_size: int,
	wrap_width: float = -1.0,
	alignment: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Vector2:
	var used_font: Font = font
	if used_font == null:
		used_font = ThemeDB.fallback_font
	
	if wrap_width > 0.0:
		return used_font.get_multiline_string_size(
			text,
			alignment,
			wrap_width,
			font_size
		)
	
	return used_font.get_string_size(
		text,
		alignment,
		-1,
		font_size
	)


# ============================================================
# STYLE BOXES
# ============================================================

static func rounded_box(
	color: Color,
	radius: int = 20,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0
) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()

	style.bg_color = color

	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width

		style.border_color = border_color

	return style


static func card_style() -> StyleBoxFlat:
	var style := rounded_box(
		_pick(SURFACE, Global.get_theme_color("surface")),
		20,
		_pick(Color("#2E3446"), Global.get_theme_color("border")),
		1
	)

	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.28
	)

	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)

	return style


static func primary_button() -> StyleBoxFlat:
	return rounded_box(
		accent_color(),
		18
	)


static func primary_button_hover() -> StyleBoxFlat:
	return rounded_box(
		accent_bright_color(),
		18
	)


static func primary_button_pressed() -> StyleBoxFlat:
	return rounded_box(
		accent_bright_color(),
		18
	)


static func secondary_button() -> StyleBoxFlat:
	return rounded_box(
		_pick(SURFACE, Global.get_theme_color("surface")),
		18,
		_pick(Color("#3A4154"), Global.get_theme_color("border")),
		2
	)


static func success_button() -> StyleBoxFlat:
	return rounded_box(
		success_soft_color(),
		18,
		success_color(),
		2
	)


static func error_button() -> StyleBoxFlat:
	return rounded_box(
		error_soft_color(),
		18,
		error_color(),
		2
	)


static func selected_button() -> StyleBoxFlat:
	return rounded_box(
		accent_soft_color(),
		18,
		accent_color(),
		3
	)


static func disabled_button() -> StyleBoxFlat:
	return rounded_box(
		_pick(DISABLED, Global.get_theme_color("surface_alt")),
		18
	)


# ============================================================
# BUTTON STYLING
# ============================================================

static func style_primary_button(
	button: Button
) -> void:

	button.add_theme_stylebox_override(
		"normal",
		primary_button()
	)

	button.add_theme_stylebox_override(
		"hover",
		primary_button_hover()
	)

	button.add_theme_stylebox_override(
		"pressed",
		primary_button_pressed()
	)

	button.add_theme_stylebox_override(
		"focus",
		primary_button_hover()
	)

	button.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)

	button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)

	button.add_theme_color_override(
		"font_focus_color",
		Color.WHITE
	)

	button.add_theme_color_override(
		"font_disabled_color",
		text_muted_color()
	)

	button.add_theme_font_size_override(
		"font_size",
		BUTTON_FONT_SIZE
	)

	var font := get_fa_bold()

	if font != null:
		button.add_theme_font_override(
			"font",
			font
		)


static func style_secondary_button(
	button: Button
) -> void:

	button.add_theme_stylebox_override(
		"normal",
		secondary_button()
	)

	button.add_theme_stylebox_override(
		"hover",
		rounded_box(
			accent_soft_color(),
			18,
			accent_color(),
			2
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		rounded_box(
			accent_soft_color(),
			18,
			accent_color(),
			2
		)
	)

	button.add_theme_color_override(
		"font_color",
		Global.get_theme_color("text")
	)

	button.add_theme_color_override(
		"font_hover_color",
		accent_font_color()
	)

	button.add_theme_color_override(
		"font_pressed_color",
		accent_font_color()
	)

	button.add_theme_font_size_override(
		"font_size",
		BUTTON_FONT_SIZE
	)

	var font := get_fa_bold()

	if font != null:
		button.add_theme_font_override(
			"font",
			font
		)


static func style_card(
	panel: PanelContainer
) -> void:

	panel.add_theme_stylebox_override(
		"panel",
		card_style()
	)


# Professional raised header bar: a surface clearly different from the
# background, with a soft drop shadow so it reads as floating above.
static func header_style() -> StyleBoxFlat:
	# Unified app header look: theme surface, rounded-bottom pill, violet underline.
	var style := rounded_box(
		_pick(Color("#232B3E"), Global.get_theme_color("surface")),
		48,
		_pick(Color("#303A50"), Global.get_theme_color("accent")),
		1
	)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.border_width_bottom = 3

	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)

	return style


static func style_header_box(
	panel: PanelContainer
) -> void:

	panel.add_theme_stylebox_override(
		"panel",
		header_style()
	)
