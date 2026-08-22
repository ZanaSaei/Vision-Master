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

const BACKGROUND := Color("#12141C")
const SURFACE := Color("#1E2230")

const PRIMARY := Color("#6C7AFF")
const PRIMARY_DARK := Color("#8490FF")
const PRIMARY_LIGHT := Color("#262B4D")

const SECONDARY := Color("#6FD6C2")
const SECONDARY_LIGHT := Color("#18332C")

const TEXT := Color("#EAEDF5")
const TEXT_SECONDARY := Color("#A8B0C2")
const TEXT_MUTED := Color("#6E7689")

const SUCCESS := Color("#3CCF7E")
const SUCCESS_LIGHT := Color("#173322")

const ERROR := Color("#F26D86")
const ERROR_LIGHT := Color("#3A1E27")

const WARNING := Color("#FFC24D")
const WARNING_LIGHT := Color("#3A2E14")

const XP := Color("#FFC24D")

const DISABLED := Color("#2A2F3D")


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
		SURFACE,
		20,
		Color("#2E3446"),
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
		PRIMARY,
		18
	)


static func primary_button_hover() -> StyleBoxFlat:
	return rounded_box(
		PRIMARY_DARK,
		18
	)


static func primary_button_pressed() -> StyleBoxFlat:
	return rounded_box(
		PRIMARY_DARK,
		18
	)


static func secondary_button() -> StyleBoxFlat:
	return rounded_box(
		SURFACE,
		18,
		Color("#3A4154"),
		2
	)


static func success_button() -> StyleBoxFlat:
	return rounded_box(
		SUCCESS_LIGHT,
		18,
		SUCCESS,
		2
	)


static func error_button() -> StyleBoxFlat:
	return rounded_box(
		ERROR_LIGHT,
		18,
		ERROR,
		2
	)


static func selected_button() -> StyleBoxFlat:
	return rounded_box(
		PRIMARY_LIGHT,
		18,
		PRIMARY,
		3
	)


static func disabled_button() -> StyleBoxFlat:
	return rounded_box(
		DISABLED,
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
		TEXT_MUTED
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
			PRIMARY_LIGHT,
			18,
			PRIMARY,
			2
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		rounded_box(
			PRIMARY_LIGHT,
			18,
			PRIMARY,
			2
		)
	)

	button.add_theme_color_override(
		"font_color",
		TEXT
	)

	button.add_theme_color_override(
		"font_hover_color",
		PRIMARY_DARK
	)

	button.add_theme_color_override(
		"font_pressed_color",
		PRIMARY_DARK
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
	var style := rounded_box(
		Color("#232B3E"),
		18,
		Color("#303A50"),
		1
	)

	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.35
	)

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
