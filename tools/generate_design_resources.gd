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
const EXERCISE_THEME_PATH := "res://scenes/shared/exercise_engine/exercise_theme.gd"
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
var _et: GDScript


func _init() -> void:
	_dt = load(DT_PATH)
	_et = load(EXERCISE_THEME_PATH)
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

	# ── Exercise-engine widgets ─────────────────────────────────
	# The shared ExerciseEngine builds its answer widgets in code and styles
	# them with Theme TYPE VARIATIONS defined here, so their look lives in the
	# Theme resource (editable in the Inspector) instead of scattered inline
	# StyleBoxFlat construction. Values mirror the previous inline styles.
	_write_exercise_variations(t)

	var err := ResourceSaver.save(t, THEME_DIR + "vision_master_light.tres")
	if err != OK:
		push_error("theme save failed (%d)" % err)


# ══════════════════════════════════════════════════════════════
#  EXERCISE WIDGET TYPE VARIATIONS
#  Registered on the Light theme so every ExerciseEngine control that sets
#  `theme_type_variation` resolves them through the app-wide theme.
# ══════════════════════════════════════════════════════════════

func _pal(role: String) -> Color:
	return _dt.PALETTE_LIGHT.get(role, Color.WHITE)


## A select/action-style pill button: surface body with an accent hover/press.
func _ex_choice_button(t: Theme, name: String, accent: Color, font_size: int, margin: int = 16) -> void:
	var border: Color = _pal("border")
	var text: Color = _pal("text")
	t.set_type_variation(name, "Button")

	var normal: StyleBoxFlat = _dt.box(_pal("surface"), 16, border, 2)
	normal.set_content_margin_all(margin)
	normal.shadow_color = Color(0, 0, 0, 0.10)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	hover.border_color = accent
	hover.set_border_width_all(3)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 1.0)
	pressed.border_color = accent
	pressed.set_border_width_all(3)
	pressed.shadow_size = 8

	t.set_stylebox("normal", name, normal)
	t.set_stylebox("hover", name, hover)
	t.set_stylebox("pressed", name, pressed)
	t.set_font("font", name, load(FONT_REGULAR) as Font)
	t.set_font_size("font_size", name, font_size)
	t.set_color("font_color", name, text)
	t.set_color("font_hover_color", name, accent)
	t.set_color("font_pressed_color", name, Color.WHITE)


func _write_exercise_variations(t: Theme) -> void:
	const EX_FONT_REGULAR := "res://assets/fonts/PlusJakartaSans-Regular.ttf"
	const EX_FONT_BOLD := "res://assets/fonts/PlusJakartaSans-Bold.ttf"
	var accent: Color = _et.C_PRIMARY
	var surface: Color = _pal("surface")
	var surface_alt: Color = _pal("surface_alt")
	var border: Color = _pal("border")
	var text: Color = _pal("text")
	var text_dim: Color = _pal("text_dim")

	# ── Choice buttons (selectable answers). One per accent in use. ──
	_ex_choice_button(t, "ChoiceButton", accent, 40)
	_ex_choice_button(t, "ChoiceButtonSuccess", _pal("success"), 40)
	_ex_choice_button(t, "ChoiceButtonError", _pal("error"), 40)
	_ex_choice_button(t, "ChoiceButtonWarning", _pal("warning"), 40)
	_ex_choice_button(t, "ChoiceButtonInfo", _et.C_INFO, 40)
	_ex_choice_button(t, "ChoiceButtonPurple", _et.C_PURPLE, 40)
	# Image option buttons are the same shape with a tighter margin + font.
	_ex_choice_button(t, "ImageChoiceButton", accent, 34, 14)

	# ── Chip buttons (word bank / built sentence chips). ──
	for filled in [false, true]:
		var chip_name := "ChipButtonFilled" if filled else "ChipButton"
		t.set_type_variation(chip_name, "Button")
		var style: StyleBoxFlat = _dt.box(accent if filled else surface, 40, accent, 2)
		style.set_content_margin_all(14)
		style.shadow_color = Color(0, 0, 0, 0.15)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 2)
		var chip_hover := style.duplicate() as StyleBoxFlat
		chip_hover.bg_color = accent if filled else Color(accent.r, accent.g, accent.b, 0.15)
		chip_hover.shadow_size = 8
		var chip_disabled := style.duplicate() as StyleBoxFlat
		chip_disabled.bg_color = surface_alt
		chip_disabled.border_color = border
		t.set_stylebox("normal", chip_name, style)
		t.set_stylebox("hover", chip_name, chip_hover)
		t.set_stylebox("pressed", chip_name, chip_hover)
		t.set_stylebox("disabled", chip_name, chip_disabled)
		t.set_font("font", chip_name, load(EX_FONT_REGULAR) as Font)
		t.set_font_size("font_size", chip_name, 38)
		t.set_color("font_color", chip_name, Color.WHITE if filled else text)
		t.set_color("font_hover_color", chip_name, Color.WHITE)
		t.set_color("font_disabled_color", chip_name, text_dim)

	# ── Word toggles (word search / text highlight). ──
	for compact in [false, true]:
		var wt_name := "WordToggleCompact" if compact else "WordToggle"
		var margin := 3 if compact else 8
		t.set_type_variation(wt_name, "Button")
		var wt_normal: StyleBoxFlat = _dt.box(Color(0, 0, 0, 0), 8)
		wt_normal.set_content_margin_all(margin)
		var wt_pressed: StyleBoxFlat = _dt.box(_et.C_WARNING, 8)
		wt_pressed.set_content_margin_all(margin)
		wt_pressed.shadow_color = Color(_et.C_WARNING.r, _et.C_WARNING.g, _et.C_WARNING.b, 0.35)
		wt_pressed.shadow_size = 6
		wt_pressed.shadow_offset = Vector2(0, 2)
		t.set_stylebox("normal", wt_name, wt_normal)
		t.set_stylebox("hover", wt_name, wt_normal.duplicate())
		t.set_stylebox("pressed", wt_name, wt_pressed)
		t.set_font("font", wt_name, load(EX_FONT_REGULAR) as Font)
		t.set_font_size("font_size", wt_name, 34 if compact else 40)
		t.set_color("font_color", wt_name, text)
		t.set_color("font_pressed_color", wt_name, Color.WHITE)
		t.set_color("font_hover_color", wt_name, accent)

	# ── Answer text inputs. ──
	t.set_type_variation("AnswerLineEdit", "LineEdit")
	var ale: StyleBoxFlat = _dt.box(surface, 16, border, 2)
	ale.set_content_margin_all(18)
	ale.shadow_color = Color(0, 0, 0, 0.08)
	ale.shadow_size = 4
	ale.shadow_offset = Vector2(0, 2)
	var ale_hover := ale.duplicate() as StyleBoxFlat
	ale_hover.border_color = accent.lightened(0.2)
	var ale_focus := ale.duplicate() as StyleBoxFlat
	ale_focus.border_color = accent
	ale_focus.shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
	ale_focus.shadow_size = 8
	t.set_stylebox("normal", "AnswerLineEdit", ale)
	t.set_stylebox("hover", "AnswerLineEdit", ale_hover)
	t.set_stylebox("focus", "AnswerLineEdit", ale_focus)
	t.set_font("font", "AnswerLineEdit", load(EX_FONT_REGULAR) as Font)
	t.set_font_size("font_size", "AnswerLineEdit", 40)
	t.set_color("font_color", "AnswerLineEdit", text)
	t.set_color("font_placeholder_color", "AnswerLineEdit", text_dim)
	t.set_color("caret_color", "AnswerLineEdit", accent)
	t.set_color("selection_color", "AnswerLineEdit", Color(accent.r, accent.g, accent.b, 0.35))

	t.set_type_variation("ChartInput", "LineEdit")
	var ci: StyleBoxFlat = _dt.box(surface, 12, border, 2)
	ci.set_content_margin_all(12)
	ci.shadow_color = Color(0, 0, 0, 0.08)
	ci.shadow_size = 3
	var ci_focus := ci.duplicate() as StyleBoxFlat
	ci_focus.border_color = accent
	ci_focus.shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
	ci_focus.shadow_size = 7
	t.set_stylebox("normal", "ChartInput", ci)
	t.set_stylebox("focus", "ChartInput", ci_focus)
	t.set_font("font", "ChartInput", load(EX_FONT_REGULAR) as Font)
	t.set_font_size("font_size", "ChartInput", 38)
	t.set_color("font_color", "ChartInput", text)
	t.set_color("font_placeholder_color", "ChartInput", text_dim)
	t.set_color("caret_color", "ChartInput", accent)
	t.set_color("selection_color", "ChartInput", Color(accent.r, accent.g, accent.b, 0.35))
	t.set_color("font_selected_color", "ChartInput", Color.WHITE)

	# ── Feedback label (font only; colour is set at grade time). ──
	t.set_type_variation("FeedbackLabel", "Label")
	t.set_font("font", "FeedbackLabel", load(EX_FONT_BOLD) as Font)
	t.set_font_size("font_size", "FeedbackLabel", 36)

	# ── Ordering card + chip + handle + arrow. ──
	t.set_type_variation("OrderCard", "PanelContainer")
	var card: StyleBoxFlat = _dt.box(surface_alt, 18, Color(border.r, border.g, border.b, 0.45), 2)
	card.content_margin_left = 18
	card.content_margin_right = 14
	card.content_margin_top = 12
	card.content_margin_bottom = 12
	card.shadow_color = Color(0, 0, 0, 0.12)
	card.shadow_size = 6
	card.shadow_offset = Vector2(0, 3)
	t.set_stylebox("panel", "OrderCard", card)

	t.set_type_variation("OrderChip", "PanelContainer")
	var chip: StyleBoxFlat = _dt.box(Color(accent.r, accent.g, accent.b, 0.16), 16, Color(accent.r, accent.g, accent.b, 0.55), 2)
	chip.set_content_margin_all(4)
	t.set_stylebox("panel", "OrderChip", chip)

	t.set_type_variation("OrderHandle", "PanelContainer")
	t.set_stylebox("panel", "OrderHandle", _dt.box(Color(accent.r, accent.g, accent.b, 0.05), 16, Color(border.r, border.g, border.b, 0.5), 2))

	t.set_type_variation("OrderArrow", "Button")
	var oa_normal: StyleBoxFlat = _dt.box(Color(accent.r, accent.g, accent.b, 0.05), 18, Color(border.r, border.g, border.b, 0.5), 2)
	oa_normal.set_content_margin_all(8)
	var oa_hover: StyleBoxFlat = _dt.box(Color(accent.r, accent.g, accent.b, 0.12), 18, accent, 2)
	oa_hover.set_content_margin_all(8)
	var oa_pressed: StyleBoxFlat = _dt.box(Color(accent.r, accent.g, accent.b, 0.24), 18, accent, 2)
	oa_pressed.set_content_margin_all(8)
	t.set_stylebox("normal", "OrderArrow", oa_normal)
	t.set_stylebox("hover", "OrderArrow", oa_hover)
	t.set_stylebox("pressed", "OrderArrow", oa_pressed)
	t.set_stylebox("focus", "OrderArrow", StyleBoxEmpty.new())
	t.set_font("font", "OrderArrow", load(EX_FONT_BOLD) as Font)
	t.set_font_size("font_size", "OrderArrow", 44)
	t.set_color("font_color", "OrderArrow", text_dim)
	t.set_color("font_hover_color", "OrderArrow", accent)
	t.set_color("font_pressed_color", "OrderArrow", accent)
	t.set_color("font_focus_color", "OrderArrow", text_dim)
	t.set_color("font_hover_pressed_color", "OrderArrow", accent)


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
