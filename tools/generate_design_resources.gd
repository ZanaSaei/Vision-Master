extends SceneTree
## ============================================================
##  DESIGN RESOURCE GENERATOR — maintenance tool (not shipped).
##
##  Turns the code-only design system (autoload/DesignTokens.gd) into real
##  editor resources so the visual language is editable in the Inspector and
##  shareable between scenes:
##
##    res://resources/styleboxes/*.tres   one file per component state
##    res://resources/themes/*.tres       the single Light app Theme
##    res://resources/textures/*.tres     generated slider grabber discs
##    res://resources/motion/*.tres       UI motion profiles
##    res://resources/typography/*.tres   the type scale
##
##  Run it ONLY when a token VALUE in DesignTokens changes and the shipped
##  resources must be regenerated:
##
##    godot --headless --path <project> --script res://tools/generate_design_resources.gd
##
##  Hand-edits to the generated .tres files are overwritten, which is the
##  point: DesignTokens stays the single source of truth for the *initial*
##  values, while the .tres files are what scenes and scripts actually read.
## ============================================================

const DT_PATH := "res://autoload/DesignTokens.gd"
const MOTION_SCRIPT := "res://scripts/resources/ui_motion_profile.gd"
const TYPE_SCALE_SCRIPT := "res://scripts/resources/type_scale.gd"

const STYLEBOX_DIR := "res://resources/styleboxes/"
const THEME_DIR := "res://resources/themes/"
const TEXTURE_DIR := "res://resources/textures/"
const MOTION_DIR := "res://resources/motion/"
const TYPOGRAPHY_DIR := "res://resources/typography/"

const FONT_BODY := "res://assets/fonts/Vazirmatn-Regular.ttf"
const FONT_DISPLAY := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
const FONT_REGULAR := "res://assets/fonts/PlusJakartaSans-Regular.ttf"

## Written once per mode. The key is the file base name, the value is a Callable
## taking `dark` and returning the StyleBox.
static var _variant_specs: Array = []

var _dt: GDScript


func _init() -> void:
	_dt = load(DT_PATH)
	for dir in [STYLEBOX_DIR, THEME_DIR, TEXTURE_DIR, MOTION_DIR, TYPOGRAPHY_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)

	_write_styleboxes()
	_write_textures()
	_write_themes()
	_write_motion_profiles()
	_write_type_scale()
	print("DESIGN_RESOURCES: done.")
	quit()


# ══════════════════════════════════════════════════════════════
#  STYLEBOXES
# ══════════════════════════════════════════════════════════════

func _write_styleboxes() -> void:
	var pairs: Dictionary = {
		# Buttons — the five states of the reference sheet.
		"button_default": func(d: bool) -> StyleBoxFlat: return _dt.button_default(d),
		"button_primary": func(d: bool) -> StyleBoxFlat: return _dt.button_primary(d),
		"button_primary_hover": func(d: bool) -> StyleBoxFlat: return _dt.button_primary_hover(d),
		"button_hover": func(d: bool) -> StyleBoxFlat: return _dt.button_hover(d),
		"button_pressed": func(d: bool) -> StyleBoxFlat: return _dt.button_pressed(d),
		"button_disabled": func(d: bool) -> StyleBoxFlat: return _dt.button_disabled(d),
		"button_focus": func(d: bool) -> StyleBoxFlat: return _dt.button_focus(d),
		# Cards & panels.
		"card": func(d: bool) -> StyleBoxFlat: return _dt.card(d),
		"card_lifted": func(d: bool) -> StyleBoxFlat: return _dt.card(d, true),
		"card_flat": func(d: bool) -> StyleBoxFlat: return _dt.card(d, false, true),
		"card_paper": func(d: bool) -> StyleBoxFlat: return _dt.card_paper(d),
		"card_accent": func(d: bool) -> StyleBoxFlat: return _dt.card_accent(d),
		"empty_tile": func(d: bool) -> StyleBoxFlat: return _dt.empty_tile(d),
		"header_bar": func(d: bool) -> StyleBoxFlat: return _dt.header_bar(d),
		# Fields.
		"inset": func(d: bool) -> StyleBoxFlat: return _dt.inset(d),
		"input_focus": func(d: bool) -> StyleBoxFlat: return _dt.input_focus(d),
		# Modal.
		"modal_header": func(d: bool) -> StyleBoxFlat: return (_dt.modal(d) as Dictionary)["header"],
		"modal_body": func(d: bool) -> StyleBoxFlat: return (_dt.modal(d) as Dictionary)["body"],
		# Toast.
		"toast": func(d: bool) -> StyleBoxFlat: return _dt.toast(d),
		"toast_badge": func(d: bool) -> StyleBoxFlat: return _dt.toast_badge(d),
		# Controls.
		"toggle_on": func(d: bool) -> StyleBoxFlat: return _dt.toggle_track(true, d),
		"toggle_off": func(d: bool) -> StyleBoxFlat: return _dt.toggle_track(false, d),
		"toggle_knob": func(d: bool) -> StyleBoxFlat: return _dt.toggle_knob(d),
		"slider_track": func(d: bool) -> StyleBoxFlat: return _dt.slider_track(d),
		"slider_fill": func(d: bool) -> StyleBoxFlat: return _dt.slider_fill(d),
		"progress_track": func(d: bool) -> StyleBoxFlat: return _dt.progress_track(d),
		"progress_fill": func(d: bool) -> StyleBoxFlat: return _dt.progress_fill(d),
		# Table rows.
		"table_row_hover": func(d: bool) -> StyleBoxFlat: return _dt.table_row("hover", d),
		"table_row_selected": func(d: bool) -> StyleBoxFlat: return _dt.table_row("selected", d),
		"table_row": func(d: bool) -> StyleBoxFlat: return _dt.table_row("normal", d),
		# Scrollbars (trough is mode independent, written below).
		"scrollbar_grabber": func(d: bool) -> StyleBoxFlat: return _dt.scrollbar_grabber(d),
		# Accent-tinted chips & pills, using the palette accent as the identity.
		"icon_chip_accent": func(d: bool) -> StyleBoxFlat:
			return _dt.icon_chip(_dt.ACCENT, _dt.RADIUS_XS, d),
		"pill_accent": func(d: bool) -> StyleBoxFlat: return _dt.pill(_dt.ACCENT, d),
	}

	for base in pairs:
		var factory: Callable = pairs[base]
		for dark in [false]:
			var suffix := "light"
			var sb: StyleBox = factory.call(dark)
			_save_sb("%s_%s" % [base, suffix], sb)

	# Mode-independent pieces.
	var clear: StyleBoxFlat = _dt.box(Color(0, 0, 0, 0))
	_save_sb("panel_transparent", clear)
	_save_sb("nav_button_normal", _dt.box(Color(0, 0, 0, 0), _dt.RADIUS_PILL) as StyleBoxFlat)
	_save_sb("scrollbar_track", _dt.scrollbar_track() as StyleBox)

	# Nav / icon-button states. Dark lifts with white, Light with the accent, so
	# a transparent icon button still reads as interactive on either backdrop.
	for dark in [false]:
		var suffix := "light"
		var accent: Color = _dt.color_of(dark, "accent")
		var tint: Color = Color(1, 1, 1, 0.10) if dark else Color(accent.r, accent.g, accent.b, 0.12)
		var hover: StyleBoxFlat = _dt.box(tint, _dt.RADIUS_PILL)
		_save_sb("nav_button_hover_%s" % suffix, hover)

		var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
		pressed.bg_color.a += 0.06
		_save_sb("nav_button_pressed_%s" % suffix, pressed)

		var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
		focus.border_color = accent
		focus.set_border_width_all(1)
		_save_sb("nav_button_focus_%s" % suffix, focus)

	for dark in [false]:
		var suffix := "light"
		var sep := StyleBoxLine.new()
		sep.color = _dt.color_of(dark, "border_strong")
		sep.thickness = 1
		_save_sb("separator_%s" % suffix, sep)


func _save_sb(file_base: String, sb: StyleBox) -> void:
	if sb == null:
		push_error("no stylebox for " + file_base)
		return
	var err := ResourceSaver.save(sb, STYLEBOX_DIR + file_base + ".tres")
	if err != OK:
		push_error("save failed for %s (%d)" % [file_base, err])


# ══════════════════════════════════════════════════════════════
#  TEXTURES
# ══════════════════════════════════════════════════════════════

func _write_textures() -> void:
	for dark in [false]:
		var suffix := "light"
		var tex: Texture2D = _dt.slider_grabber_texture(dark)
		if tex != null:
			ResourceSaver.save(tex, TEXTURE_DIR + "slider_grabber_%s.tres" % suffix)


# ══════════════════════════════════════════════════════════════
#  THEMES
#  Built by loading the styleboxes written above, so a theme and its
#  styleboxes can never drift apart.
# ══════════════════════════════════════════════════════════════

func _write_themes() -> void:
	_build_theme(false)


func _sb(name: String, _dark: bool) -> StyleBox:
	var suffix := "light"
	return load(STYLEBOX_DIR + "%s_%s.tres" % [name, suffix])


func _build_theme(dark: bool) -> void:
	var t := Theme.new()
	t.default_font = load(FONT_BODY) as Font
	t.default_font_size = _dt.FONT_BODY

	var text: Color = _dt.color_of(dark, "text")
	var dim: Color = _dt.color_of(dark, "text_dim")
	var accent: Color = _dt.color_of(dark, "accent")

	# ── Labels ──────────────────────────────────────────────────
	t.set_color("font_color", "Label", text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 0)

	# ── Buttons: the reference sheet's five states ───────────────
	# Mobile UI has no hover-only appearance, so hover reuses the resting state
	# and only `pressed` differs — it still needs to read as a real tap.
	t.set_stylebox("normal", "Button", _sb("button_default", dark))
	t.set_stylebox("hover", "Button", _sb("button_default", dark))
	t.set_stylebox("pressed", "Button", _sb("button_pressed", dark))
	t.set_stylebox("disabled", "Button", _sb("button_disabled", dark))
	t.set_stylebox("focus", "Button", _sb("button_focus", dark))
	t.set_color("font_color", "Button", _dt.button_text_color("default", dark))
	t.set_color("font_hover_color", "Button", _dt.button_text_color("default", dark))
	t.set_color("font_pressed_color", "Button", _dt.button_text_color("pressed", dark))
	t.set_color("font_focus_color", "Button", _dt.button_text_color("default", dark))
	t.set_color("font_disabled_color", "Button", _dt.button_text_color("disabled", dark))

	# Panel and PanelContainer deliberately have no global style here. Panels
	# are authored individually in their scenes; ScrollContainer remains clear.
	t.set_stylebox("panel", "ScrollContainer", load(STYLEBOX_DIR + "panel_transparent.tres"))

	# ── Scrollbars ──────────────────────────────────────────────
	# Godot 4 scrollbars expose `scroll` for the trough and `grabber*` for the
	# handle; there is no `track` item (that was Godot 3).
	var grab := _sb("scrollbar_grabber", dark)
	var trough: StyleBox = load(STYLEBOX_DIR + "scrollbar_track.tres")
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, trough)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab)
		t.set_stylebox("grabber_pressed", bar, grab)

	# ── Text inputs ─────────────────────────────────────────────
	var le_normal := (_sb("inset", dark) as StyleBoxFlat).duplicate() as StyleBoxFlat
	le_normal.content_margin_top = 12
	le_normal.content_margin_bottom = 12
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", _sb("input_focus", dark))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("font_placeholder_color", "LineEdit", dim)
	t.set_color("selection_color", "LineEdit", _dt.color_of(dark, "accent_soft"))

	t.set_stylebox("normal", "TextEdit", _dt.inset(dark, _dt.RADIUS_MD))
	t.set_stylebox("focus", "TextEdit", _sb("input_focus", dark))
	t.set_color("font_color", "TextEdit", text)
	t.set_color("caret_color", "TextEdit", accent)

	# ── Progress ────────────────────────────────────────────────
	t.set_stylebox("background", "ProgressBar", _sb("progress_track", dark))
	t.set_stylebox("fill", "ProgressBar", _sb("progress_fill", dark))
	t.set_color("font_color", "ProgressBar", text)

	# ── Sliders ─────────────────────────────────────────────────
	# `slider` / `grabber_area*` are STYLEBOXES but `grabber*` are ICONS, so the
	# knob is a generated disc texture rather than a stylebox.
	var sl_track := _sb("slider_track", dark)
	var sl_fill := _sb("slider_fill", dark)
	var suffix := "light"
	var sl_knob: Texture2D = load(TEXTURE_DIR + "slider_grabber_%s.tres" % suffix)
	for slider in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", slider, sl_track)
		t.set_stylebox("grabber_area", slider, sl_fill)
		t.set_stylebox("grabber_area_highlight", slider, sl_fill)
		if sl_knob != null:
			t.set_icon("grabber", slider, sl_knob)
			t.set_icon("grabber_highlight", slider, sl_knob)
			t.set_icon("grabber_disabled", slider, sl_knob)

	# ── Toggles ─────────────────────────────────────────────────
	var off := _sb("toggle_off", dark)
	var on := _sb("toggle_on", dark)
	for toggle in ["CheckButton", "CheckBox"]:
		t.set_stylebox("normal", toggle, off)
		t.set_stylebox("hover", toggle, off)
		t.set_stylebox("pressed", toggle, on)
		t.set_stylebox("hover_pressed", toggle, on)
		t.set_stylebox("disabled", toggle, off)
		t.set_color("font_color", toggle, text)
		t.set_color("font_hover_color", toggle, _dt.color_of(dark, "accent_bright"))
		t.set_color("font_pressed_color", toggle, text)
		t.set_color("font_disabled_color", toggle, dim)

	# ── OptionButton ────────────────────────────────────────────
	t.set_color("font_color", "OptionButton", text)
	t.set_color("font_hover_color", "OptionButton", text)
	t.set_color("font_disabled_color", "OptionButton", dim)

	# ── RichTextLabel: `default_color` is its type colour, and the type has
	# no `font_color` item at all ──────────────────────────────────
	t.set_color("default_color", "RichTextLabel", text)
	t.set_color("font_selected_color", "RichTextLabel", _dt.color_of(dark, "on_accent"))
	t.set_color("selection_color", "RichTextLabel", _dt.color_of(dark, "accent_soft"))

	# ── TabContainer ────────────────────────────────────────────
	t.set_color("font_selected_color", "TabContainer", accent)
	t.set_color("font_hovered_color", "TabContainer", _dt.color_of(dark, "accent_bright"))
	t.set_color("font_unselected_color", "TabContainer", dim)
	t.set_color("font_disabled_color", "TabContainer", _dt.color_of(dark, "text_muted"))
	t.set_stylebox("panel", "TabContainer", _sb("card_lifted", dark))

	# ── Separators ──────────────────────────────────────────────
	var sep := _sb("separator", dark)
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", sep)

	# ── Popups ──────────────────────────────────────────────────
	var popup_panel := (_sb("card_lifted", dark) as StyleBoxFlat).duplicate() as StyleBoxFlat
	popup_panel.set_corner_radius_all(_dt.RADIUS_MD)
	t.set_stylebox("panel", "PopupMenu", popup_panel)
	t.set_stylebox("hover", "PopupMenu", _sb("table_row_hover", dark))
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", _dt.color_of(dark, "on_accent"))
	t.set_color("font_accelerator_color", "PopupMenu", dim)
	t.set_color("font_separator_color", "PopupMenu", dim)

	t.set_stylebox("panel", "PopupPanel", _sb("card_lifted", dark))
	# Window has no `panel` item — its frame is `embedded_border`. Dialogs take
	# their panel from AcceptDialog, which ConfirmationDialog inherits.
	t.set_stylebox("embedded_border", "Window", _sb("card_lifted", dark))
	t.set_stylebox("panel", "AcceptDialog", _sb("card_lifted", dark))

	# ── Tooltips ────────────────────────────────────────────────
	t.set_stylebox("panel", "TooltipPanel", _sb("pill_accent", dark))
	t.set_color("font_color", "TooltipLabel", text)

	var err := ResourceSaver.save(t, THEME_DIR + "vision_master_light.tres")
	if err != OK:
		push_error("theme save failed (%d)" % err)


# ══════════════════════════════════════════════════════════════
#  MOTION PROFILES
# ══════════════════════════════════════════════════════════════

func _write_motion_profiles() -> void:
	var script: GDScript = load(MOTION_SCRIPT)
	for spec in [
		# name, duration, delay, trans, ease, from_scale, from_alpha, distance,
		# settle_duration, settle_trans, settle_ease, peak, loops
		["pop_in", 0.34, 0.0, Tween.TRANS_BACK, Tween.EASE_OUT, 0.86, 0.0, 0.0, 0.22, Tween.TRANS_CUBIC, Tween.EASE_OUT, 1.0, false],
		["slide_in", 0.42, 0.0, Tween.TRANS_CUBIC, Tween.EASE_OUT, 1.0, 0.0, 90.0, 0.30, Tween.TRANS_CUBIC, Tween.EASE_OUT, 1.0, false],
		["pop", 0.12, 0.0, Tween.TRANS_CUBIC, Tween.EASE_OUT, 1.0, 1.0, 0.0, 0.26, Tween.TRANS_ELASTIC, Tween.EASE_OUT, 1.12, false],
		["shake", 0.33, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 1.0, 1.0, 0.0, 0.0, Tween.TRANS_SINE, Tween.EASE_OUT, 1.0, false],
		["pulse", 0.9, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 1.0, 1.0, 0.0, 0.9, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 1.04, true],
		["hover_lift", 0.16, 0.0, Tween.TRANS_QUAD, Tween.EASE_OUT, 1.0, 1.0, 0.0, 0.0, Tween.TRANS_QUAD, Tween.EASE_OUT, 1.0, false],
		["press_squash", 0.07, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN, 1.0, 1.0, 0.0, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN, 1.0, false],
		["press_release", 0.20, 0.0, Tween.TRANS_BACK, Tween.EASE_OUT, 1.0, 1.0, 0.0, 0.0, Tween.TRANS_BACK, Tween.EASE_OUT, 1.0, false],
		["transition_fade", 0.2, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 1.0, 1.0, 0.0, 0.0, Tween.TRANS_SINE, Tween.EASE_OUT, 1.0, false],
		["transition_slide_out", 0.40, 0.0, Tween.TRANS_QUART, Tween.EASE_IN, 0.94, 1.0, 0.0, 0.0, Tween.TRANS_QUART, Tween.EASE_IN, 1.0, false],
		["transition_slide_in", 0.50, 0.0, Tween.TRANS_QUINT, Tween.EASE_OUT, 1.04, 1.0, 0.0, 0.0, Tween.TRANS_QUINT, Tween.EASE_OUT, 1.0, false],
	]:
		var p: Resource = script.new()
		p.duration = spec[1]
		p.delay = spec[2]
		p.transition = spec[3]
		p.easing = spec[4]
		p.from_scale = spec[5]
		p.from_alpha = spec[6]
		p.distance = spec[7]
		p.settle_duration = spec[8]
		p.settle_transition = spec[9]
		p.settle_easing = spec[10]
		p.peak_scale = spec[11]
		p.loops_forever = spec[12]
		var err := ResourceSaver.save(p, MOTION_DIR + str(spec[0]) + ".tres")
		if err != OK:
			push_error("motion save failed for %s (%d)" % [spec[0], err])


# ══════════════════════════════════════════════════════════════
#  TYPE SCALE
# ══════════════════════════════════════════════════════════════

func _write_type_scale() -> void:
	var script: GDScript = load(TYPE_SCALE_SCRIPT)
	var ts: Resource = script.new()
	ts.font_regular = load(FONT_REGULAR)
	ts.font_display = load(FONT_DISPLAY)
	ts.font_farsi = load(FONT_BODY)
	var err := ResourceSaver.save(ts, TYPOGRAPHY_DIR + "type_scale.tres")
	if err != OK:
		push_error("type scale save failed (%d)" % err)
