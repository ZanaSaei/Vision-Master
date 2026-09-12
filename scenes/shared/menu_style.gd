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


## Card fill: cream (from Background.png) in Light, deep indigo-navy in Dark.
static func card_bg() -> Color:
	if is_dark():
		return Color(0.078, 0.088, 0.17)
	return Color("#FFF7BA")


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
## Soft, rounded, friendly card with a subtle accent-tinted border + shadow.
## Pass `flat = true` for a completely shadowless (flat) surface.
static func card_style(accent_col: Color, radius: int = 26, lifted: bool = false, flat: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = card_bg()
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	if is_dark():
		s.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.42)
	else:
		s.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.30)
	# Gentle shadow. In Light it stays very subtle so no grey box reads
	# between the stacked cards; in Dark it gives the needed depth.
	if flat:
		# Flat design: no elevation, so no shadow at all.
		s.shadow_size = 0
		s.shadow_offset = Vector2.ZERO
	else:
		s.shadow_color = Color(0, 0, 0, 0.22 if is_dark() else 0.06)
		s.shadow_size = 20 if lifted else 14
		s.shadow_offset = Vector2(0, 8 if lifted else 5)
	return s


static func card_hover_style(accent_col: Color, radius: int = 26, flat: bool = false) -> StyleBoxFlat:
	var s := card_style(accent_col, radius, true, flat)
	if not flat:
		s.shadow_size = 26
	if is_dark():
		s.bg_color = s.bg_color.lightened(0.05)
	return s


static func card_pressed_style(accent_col: Color, radius: int = 26, flat: bool = false) -> StyleBoxFlat:
	var s := card_style(accent_col, radius, false, flat)
	if not flat:
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 2)
	if is_dark():
		s.bg_color = s.bg_color.darkened(0.03)
	return s


## Rounded square chip behind the emoji/icon of a card.
static func icon_chip(accent_col: Color, radius: int = 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if is_dark():
		s.bg_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.28)
	else:
		s.bg_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.13)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.38)
	return s


## Small rounded label pill (e.g. a count or status badge).
static func pill_label(label_text: String, accent_col: Color, font_size: int = 34) -> Label:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", vazir())
	lbl.add_theme_font_size_override("font_size", font_size)
	# The pill chip is translucent, so pick a text colour with real contrast.
	lbl.add_theme_color_override("font_color", pill_text(accent_col))
	lbl.add_theme_stylebox_override("normal", icon_chip(accent_col, 20))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(0, 60)
	return lbl


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
	var style := StyleBoxFlat.new()
	if is_dark():
		style.bg_color = Color(0.078, 0.088, 0.17, 0.7)
	else:
		style.bg_color = Color("#FFF7BA", 0.6)
	style.set_corner_radius_all(24)
	style.set_border_width_all(1)
	if is_dark():
		style.border_color = Color(1, 1, 1, 0.08)
	else:
		style.border_color = Color(0, 0, 0, 0.08)
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
	btn.clip_contents = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("normal", card_style(accent_col, 26, false, flat))
	btn.add_theme_stylebox_override("hover", card_hover_style(accent_col, 26, flat))
	btn.add_theme_stylebox_override("pressed", card_pressed_style(accent_col, 26, flat))
	btn.add_theme_stylebox_override("focus", card_hover_style(accent_col, 26, flat))

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
	chip.custom_minimum_size = Vector2(108, 150) if image_path != "" else Vector2(108, 108)
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
		emoji_lbl.add_theme_font_size_override("font_size", 50)
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
		tw.tween_property(btn, "scale", Vector2(1.015, 1.015), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.965, 0.965), 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


# ---------------------------------------------------------------- bars --
## Rounded-bottom header bar (top of menu screens).
## Pass `flat = true` for a shadowless (flat) header.
static func header_bar_style(radius_bottom: int = 44, flat: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if is_dark():
		s.bg_color = Color(0.078, 0.088, 0.17, 0.94)
	else:
		s.bg_color = Color("#BFDBFE")
	s.corner_radius_bottom_left = radius_bottom
	s.corner_radius_bottom_right = radius_bottom
	if not flat:
		s.shadow_color = Color(0, 0, 0, 0.12)
		s.shadow_size = 20
		s.shadow_offset = Vector2(0, 6)
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
