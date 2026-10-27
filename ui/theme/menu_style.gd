class_name MenuStyle
extends RefCounted
## ============================================================
##  MENU STYLE — the public face of the menu design language.
##
##  A thin facade. The 925-line original that owned fonts, palette access, the
##  component factory AND the tween choreography all at once is now three
##  single-responsibility modules:
##
##    res://ui/theme/menu_theme.gd      fonts, palette access, accented styles
##    res://ui/widgets/menu_widgets.gd  ready-made component factory
##    res://ui/motion/ui_motion.gd      interaction choreography
##
##  Everything below forwards, so the ~250 existing `MenuStyle.x()` call sites
##  keep working unchanged. New code should prefer the module it actually needs
##  (and, for anything static, an authored scene in res://ui/components/).
##
##  Visual values are NOT defined here or in the modules: they live in
##  res://resources/styleboxes + res://resources/themes (styles) and
##  res://resources/motion (animation), all editable in the Inspector.
## ============================================================

const ThemeModule := preload("res://ui/theme/menu_theme.gd")
const WidgetModule := preload("res://ui/widgets/menu_widgets.gd")
const MotionModule := preload("res://ui/motion/ui_motion.gd")

# ── Font paths (kept for callers that need the raw resource path) ──
const FONT_VAZIR        := ThemeModule.FONT_VAZIR
const FONT_JAKARTA      := ThemeModule.FONT_JAKARTA
const FONT_JAKARTA_BOLD := ThemeModule.FONT_JAKARTA_BOLD
const FONT_NUNITO_BOLD  := ThemeModule.FONT_NUNITO_BOLD
const FONT_JOSEFIN      := ThemeModule.FONT_JOSEFIN


# ══════════════════════════════════════════════════════════════
#  FONTS  →  MenuTheme
# ══════════════════════════════════════════════════════════════

static func font(path: String) -> Font:
	return ThemeModule.font(path)

static func vazir() -> Font:
	return ThemeModule.vazir()

static func nunito() -> Font:
	return ThemeModule.nunito()

static func jakarta() -> Font:
	return ThemeModule.jakarta()

static func jakarta_bold() -> Font:
	return ThemeModule.jakarta_bold()

static func josefin() -> Font:
	return ThemeModule.josefin()

## Picks the family that can shape the string (Vazirmatn for Persian).
static func family_for(s: String) -> Font:
	return ThemeModule.family_for(s)


# ══════════════════════════════════════════════════════════════
#  THEME STATE + PALETTE  →  MenuTheme
# ══════════════════════════════════════════════════════════════

static func is_dark() -> bool:
	return ThemeModule.is_dark()

static func c(role: String) -> Color:
	return ThemeModule.c(role)

static func text() -> Color:
	return ThemeModule.text()

static func text_dim() -> Color:
	return ThemeModule.text_dim()

static func accent() -> Color:
	return ThemeModule.accent()

static func accent_soft() -> Color:
	return ThemeModule.accent_soft()

static func accent_bright() -> Color:
	return ThemeModule.accent_bright()

static func surface() -> Color:
	return ThemeModule.surface()

static func border() -> Color:
	return ThemeModule.border()

static func card_bg() -> Color:
	return ThemeModule.card_bg()

static func ink() -> Color:
	return ThemeModule.ink()

static func gold() -> Color:
	return ThemeModule.gold()

static func gold_bright() -> Color:
	return ThemeModule.gold_bright()

static func accent_deep() -> Color:
	return ThemeModule.accent_deep()

static func sunken() -> Color:
	return ThemeModule.sunken()

static func paper() -> Color:
	return ThemeModule.paper()

static func muted() -> Color:
	return ThemeModule.muted()

static func on_accent(accent_col: Color) -> Color:
	return ThemeModule.on_accent(accent_col)

static func subtitle_color() -> Color:
	return ThemeModule.subtitle_color()

static func pill_text(accent_col: Color) -> Color:
	return ThemeModule.pill_text(accent_col)

## Loads a mode-specific shared stylebox by file base name.
static func stylebox(file_base: String) -> StyleBox:
	return ThemeModule.stylebox(file_base)


# ══════════════════════════════════════════════════════════════
#  ACCENTED STYLES  →  MenuTheme
# ══════════════════════════════════════════════════════════════

static func card_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, lifted: bool = false, flat: bool = false) -> StyleBoxFlat:
	return ThemeModule.card_style(accent_col, radius, lifted, flat)

static func card_hover_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, flat: bool = false) -> StyleBoxFlat:
	return ThemeModule.card_hover_style(accent_col, radius, flat)

static func card_pressed_style(accent_col: Color, radius: int = DesignTokens.RADIUS_MD, flat: bool = false) -> StyleBoxFlat:
	return ThemeModule.card_pressed_style(accent_col, radius, flat)

static func icon_chip(accent_col: Color, radius: int = DesignTokens.RADIUS_XS) -> StyleBoxFlat:
	return ThemeModule.icon_chip(accent_col, radius)

static func header_bar_style(radius_bottom: int = DesignTokens.RADIUS_LG, flat: bool = false) -> StyleBoxFlat:
	return ThemeModule.header_bar_style(radius_bottom, flat)


# ══════════════════════════════════════════════════════════════
#  TEXT  →  MenuTheme
# ══════════════════════════════════════════════════════════════

static func has_persian(s: String) -> bool:
	return ThemeModule.has_persian(s)

static func persian_digits(s: String) -> String:
	return ThemeModule.persian_digits(s)


# ══════════════════════════════════════════════════════════════
#  COMPONENT FACTORY  →  MenuWidgets
# ══════════════════════════════════════════════════════════════

static func pill_label(label_text: String, accent_col: Color, font_size: int = DesignTokens.FONT_BODY) -> Label:
	return WidgetModule.pill_label(label_text, accent_col, font_size)

static func style_pill(lbl: Label, accent_col: Color, font_size: int = DesignTokens.FONT_BODY) -> void:
	WidgetModule.style_pill(lbl, accent_col, font_size)

static func make_section_header(title: String, caption: String = "") -> VBoxContainer:
	return WidgetModule.make_section_header(title, caption)

static func make_button(btn_text: String, kind: String = "primary", min_height: int = 96) -> Button:
	return WidgetModule.make_button(btn_text, kind, min_height)

static func style_button(btn: Button, kind: String = "primary") -> void:
	WidgetModule.style_button(btn, kind)

static func make_back_button(icon_path: String, size: int = 96) -> Button:
	return WidgetModule.make_back_button(icon_path, size)

static func style_back_button(button: Button) -> void:
	WidgetModule.style_back_button(button)

static func make_tip_card(message: String, emoji: String = "💡") -> PanelContainer:
	return WidgetModule.make_tip_card(message, emoji)

static func make_card(
	title: String,
	subtitle: String,
	emoji: String,
	accent_col: Color,
	min_height: int = 158,
	image_path: String = "",
	flat: bool = false
) -> Button:
	return WidgetModule.make_card(title, subtitle, emoji, accent_col, min_height, image_path, flat)

## Dresses an existing menu card as a glossy one (raised face + shine coating).
## Safe to call again on a theme change: the coating is reused, not stacked.
static func style_gloss_card(card: Button, accent_col: Color, radius: int = 26) -> void:
	WidgetModule.style_gloss_card(card, accent_col, radius)

static func make_toast(message: String, tone: String = "success") -> PanelContainer:
	return WidgetModule.make_toast(message, tone)

static func make_empty_state(title: String, message: String, glyph: String = "≡") -> PanelContainer:
	return WidgetModule.make_empty_state(title, message, glyph)

static func make_table_row(row_text: String, state: String = "default") -> PanelContainer:
	return WidgetModule.make_table_row(row_text, state)

static func make_modal(
	title: String,
	content: String,
	cancel_text: String = "Cancel",
	confirm_text: String = "Content"
) -> Dictionary:
	return WidgetModule.make_modal(title, content, cancel_text, confirm_text)

static func make_toggle_row(label_text: String, is_on: bool) -> HBoxContainer:
	return WidgetModule.make_toggle_row(label_text, is_on)

static func make_progress(value: float, width: int = 0) -> ProgressBar:
	return WidgetModule.make_progress(value, width)


# ══════════════════════════════════════════════════════════════
#  MOTION  →  UiMotion (profile-resource driven)
# ══════════════════════════════════════════════════════════════

static func wire_microinteractions(btn: Button) -> void:
	MotionModule.wire_microinteractions(btn)

static func pop_in(node: Control, delay: float = 0.0) -> Tween:
	return MotionModule.pop_in(node, delay)

static func shake(node: Control) -> Tween:
	return MotionModule.shake(node)

## `strength` overrides the profile's peak scale; 0 uses the resource value.
static func pop(node: Control, strength: float = 0.0) -> Tween:
	return MotionModule.pop(node, strength)

## `amount` overrides the profile's peak scale; 0 uses the resource value.
static func pulse_loop(node: Control, amount: float = 0.0) -> Tween:
	return MotionModule.pulse_loop(node, amount)

## `distance` overrides the profile's travel; 0 uses the resource value.
static func slide_in(node: Control, delay: float = 0.0, distance: float = 0.0) -> Tween:
	return MotionModule.slide_in(node, delay, distance)

static func stagger_in(nodes: Array, step: float = 0.07, distance: float = 70.0) -> void:
	MotionModule.stagger_in(nodes, step, distance)
