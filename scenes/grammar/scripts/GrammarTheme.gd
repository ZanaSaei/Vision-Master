class_name GrammarTheme
extends RefCounted


# ============================================================
# BIDI (mixed Persian/English) HELPER
# ------------------------------------------------------------
# Farsi-dominant lines that embed English tokens (will, going to,
# as...as, ...) render with a RTL base direction. Without help the
# Unicode bidi algorithm visually reorders the Latin fragments and
# any "+"-chained structure around them, producing scrambled text.
# Wrapping every contiguous Latin run in directional ISOLATES
# (LRI U+2066 ... PDI U+2069) pins each run's internal order and
# its position, no matter what surrounds it. Display-only: this
# must never be applied to strings used for answer comparison.
# ============================================================
# Returns true when Persian characters outnumber Latin ones in `text`.
# Same rule the shared exercise engine uses to pick the base direction.
static func is_fa_dominant(text: String) -> bool:
	var fa := 0
	var lat := 0
	for i in text.length():
		var u := text.unicode_at(i)
		if u >= 0x0600 and u <= 0x06FF:
			fa += 1
		elif (u >= 0x41 and u <= 0x5A) or (u >= 0x61 and u <= 0x7A) or (u >= 0xC0 and u <= 0x24F):
			lat += 1
	return fa > 0 and fa >= lat


# One-call way to display any (possibly mixed Persian/English) string on a
# Label or Button: applies bidi isolates and picks the correct base
# direction. Use this for every JSON-driven text in the grammar system.
static func set_bidi_text(control: Control, text: String) -> void:
	control.text = bidi_fix(text)
	control.text_direction = (
		Control.TEXT_DIRECTION_RTL if is_fa_dominant(text) else Control.TEXT_DIRECTION_LTR
	)


static func _is_farsi(u: int) -> bool:
	return u >= 0x0600 and u <= 0x06FF


static func _is_latin(u: int) -> bool:
	return (u >= 0x41 and u <= 0x5A) or (u >= 0x61 and u <= 0x7A) or (u >= 0xC0 and u <= 0x24F)


# Characters that belong INSIDE an English phrase: letters, digits,
# apostrophes, hyphens and ZWNJ keep tokens like "be going to", "I'll",
# "well-known" from being split apart.
static func _is_run_char(u: int) -> bool:
	return _is_latin(u) or (u >= 0x30 and u <= 0x39) \
			or u == 0x27 or u == 0x2019 or u == 0x2D or u == 0x200C


static func bidi_fix(text: String) -> String:
	if text.is_empty():
		return text
	var fa := 0
	var lat := 0
	for i in text.length():
		var u := text.unicode_at(i)
		if _is_farsi(u):
			fa += 1
		elif _is_latin(u):
			lat += 1
	# Only Farsi-dominant lines need isolates; pure or Latin-dominant
	# lines already render correctly with an LTR base direction.
	if fa == 0 or fa < lat:
		return text
	var lri := char(0x2066)
	var pdi := char(0x2069)
	var out := ""
	var i := 0
	var n := text.length()
	while i < n:
		if _is_run_char(text.unicode_at(i)):
			# Start of an English phrase: swallow the WHOLE segment up to
			# the next Farsi character — including spaces between English
			# words and attached punctuation — so a multi-word phrase like
			# "May I ....?" becomes ONE LTR island. Wrapping each word in
			# its own isolate lets the neutral gaps between them resolve
			# to the RTL paragraph direction and visually scramble the
			# phrase into "?.... I May".
			var j := i
			while j < n and not _is_farsi(text.unicode_at(j)):
				j += 1
			# Trailing whitespace / bare connectors ("+", "=") / opening
			# brackets belong to the gap between the phrase and the
			# Persian text, not to the phrase itself.
			var end_i := j
			while end_i > i:
				var prev := text.unicode_at(end_i - 1)
				if prev == 0x20 or prev == 0x09 or prev == 0x0A \
						or prev == 0x2B or prev == 0x3D \
						or prev == 0x28 or prev == 0x5B or prev == 0x7B:
					end_i -= 1
				else:
					break
			out += lri + text.substr(i, end_i - i) + pdi
			# Emit the trailing neutrals we trimmed, outside the island.
			while end_i < j:
				out += text[end_i]
				end_i += 1
			i = j
		else:
			out += text[i]
			i += 1
	return out


# ============================================================
# GRAMMAR THEME  —  delegates 100% to the app-wide theme owner
# ------------------------------------------------------------
# Grammar never defines its own colors. Every color in this
# class resolves through Global.get_theme_color(role), where
# Global.gd is the single source of truth for the app's Dark /
# Light "universes". This keeps grammar screens pixel-consistent
# with the rest of the app and removes the old hardcoded palette
# that diverged from the global one.
#
# The only things defined here are the *non-color* grammar UI
# constants (typography sizes, spacing, fonts) and the semantic
# color accessors below, which simply map grammar-facing names to
# Global's roles for readability.
# ============================================================


# ============================================================
# SEMANTIC COLOR ACCESSORS  (theme-aware, all via Global)
# ============================================================

# Main app background behind everything.
static func background_color() -> Color:
	return Global.get_theme_color("bg")


# Primary readable text.
static func text_color() -> Color:
	return Global.get_theme_color("text")


# Secondary / dimmer text.
static func text_secondary_color() -> Color:
	return Global.get_theme_color("text_dim")


# Muted / placeholder text.
static func text_muted_color() -> Color:
	return Global.get_theme_color("text_dim")


# Primary brand accent (button fills, borders, selected markers).
static func accent_color() -> Color:
	return Global.get_theme_color("accent")


# Lighter accent used for hover fills / bright accents.
static func accent_bright_color() -> Color:
	return Global.get_theme_color("accent_bright")


# Muted accent surface used for selected / hover chip backgrounds.
static func accent_soft_color() -> Color:
	return Global.get_theme_color("accent_soft")


# Accent used as a *font* color (reads well on a surface).
static func accent_font_color() -> Color:
	return Global.get_theme_color("accent")


# Alias of the primary accent (grammar's former "PRIMARY").
static func primary_color() -> Color:
	return Global.get_theme_color("accent")


# Alias of the bright accent (grammar's former "PRIMARY_DARK").
static func primary_dark_color() -> Color:
	return Global.get_theme_color("accent_bright")


# Alias of the muted accent surface (grammar's former "PRIMARY_LIGHT").
static func primary_light_color() -> Color:
	return Global.get_theme_color("accent_soft")


static func success_color() -> Color:
	return Global.get_theme_color("success")


static func success_soft_color() -> Color:
	return Global.get_theme_color("success_soft")


static func error_color() -> Color:
	return Global.get_theme_color("error")


static func error_soft_color() -> Color:
	return Global.get_theme_color("error_soft")


static func warning_color() -> Color:
	return Global.get_theme_color("warning")


static func warning_soft_color() -> Color:
	return Global.get_theme_color("warning_soft")


# Gold / XP color (maps to the app-wide warning gold).
static func xp_color() -> Color:
	return Global.get_theme_color("warning")


# Dimmed text for locked/disabled units.
static func locked_text_color() -> Color:
	return Global.get_theme_color("text_dim")


# Disabled / muted surface fill.
static func disabled_color() -> Color:
	return Global.get_theme_color("surface_alt")


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
const CONTENT_MARGIN := 50


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
		Global.get_theme_color("surface"),
		20,
		Global.get_theme_color("border"),
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


# Raised info card used for the teaching content on a unit's first learning
# page. Uses surface_alt so it clearly contrasts with the parent "surface"
# container — this avoids the flat / dull "white-on-white" (light) or
# "dark-on-dark" (dark) look that nested surface-on-surface boxes produce.
static func info_card_style() -> StyleBoxFlat:
	var style := rounded_box(
		Global.get_theme_color("surface_alt"),
		20,
		Global.get_theme_color("border"),
		1
	)

	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)

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
		Global.get_theme_color("surface"),
		18,
		Global.get_theme_color("border"),
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
		disabled_color(),
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
	# Unified app header look: theme surface, rounded-bottom pill, accent underline.
	var style := rounded_box(
		Global.get_theme_color("surface"),
		48,
		Global.get_theme_color("accent"),
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


# Flat icon button used in grammar header bars — matches the app-wide header
# icon look (transparent resting state, soft accent hover/press disc).
static func make_header_icon_button(
	icon_path: String,
	callback: Callable,
	size: float = 112.0
) -> Button:
	var button := Button.new()
	button.flat = true
	button.expand_icon = true
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_constant_override("icon_max_width", int(size))
	button.add_theme_constant_override("icon_max_height", int(size))
	var accent: Color = accent_color()
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.set_border_width_all(0)
	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(int(size / 2.0))
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	var press := StyleBoxFlat.new()
	press.set_corner_radius_all(int(size / 2.0))
	press.bg_color = Color(accent.r, accent.g, accent.b, 0.26)
	button.add_theme_stylebox_override("normal", clear)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", press)
	button.add_theme_stylebox_override("focus", hover)
	button.icon = load(icon_path)
	button.text = ""
	button.pressed.connect(callback)
	return button
