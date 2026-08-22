class_name GrammarTheme
extends RefCounted


# ============================================================
# COLORS
# ============================================================

const BACKGROUND := Color("#F7F9FC")
const SURFACE := Color("#FFFFFF")

const PRIMARY := Color("#5B67F1")
const PRIMARY_DARK := Color("#4652D4")
const PRIMARY_LIGHT := Color("#EEF0FF")

const SECONDARY := Color("#5CC8B2")
const SECONDARY_LIGHT := Color("#E8FAF5")

const TEXT := Color("#202535")
const TEXT_SECONDARY := Color("#6B7280")
const TEXT_MUTED := Color("#9AA1AF")

const SUCCESS := Color("#32B86C")
const SUCCESS_LIGHT := Color("#E7F8EE")

const ERROR := Color("#E85D75")
const ERROR_LIGHT := Color("#FDE9ED")

const WARNING := Color("#F4B740")
const WARNING_LIGHT := Color("#FFF5DA")

const XP := Color("#FFB938")

const DISABLED := Color("#D9DEE8")


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
		20
	)

	style.shadow_color = Color(
		0.05,
		0.07,
		0.12,
		0.08
	)

	style.shadow_size = 8
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
		Color("#DDE2F0"),
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
		19
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
		18
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
