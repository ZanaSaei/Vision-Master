extends Node
## ============================================================
##  DESIGN SYSTEM TESTS — run with run_scene on TestDesignSystem.tscn.
##
##  Guards the app-wide restyle. Three layers of protection:
##
##   1. The palettes and token scales stay complete and self-consistent, so a
##      half-finished edit can't ship white-on-white.
##   2. Every component factory returns a StyleBoxFlat with the properties the
##      reference sheet specifies (opaque fills, pill buttons, three shadows).
##   3. The Theme that ThemeService installs on the tree root actually carries
##      the redesign, and every theme item name is VALID for its control type.
##
##  Layer 3 matters most: a wrong item name is silently accepted by Godot
##  (it just stores an unused entry), so a typo'd stylebox name would restyle
##  nothing, raise no error, and be invisible until someone looked at the
##  screen. test_theme_items_are_valid() makes that failure loud.
## ============================================================

var _failures := 0


func _ready() -> void:
	# The test runner enumerates and invokes every test_* method itself, so
	# `_ready` must NOT also run them there — that would execute the whole
	# suite twice. A direct WINDOWED run has no runner to drive it, so it
	# orchestrates itself; that is also the only path where the GPU render
	# check can actually execute, because the runner is headless.
	if DisplayServer.get_name() == "headless":
		return
	print("Running the design-system suite directly (windowed, so the render check will execute).")
	test_palettes_complete()
	test_token_scales()
	test_button_states()
	test_cards_and_insets()
	test_table_rows()
	test_modal_composition()
	test_toggle_and_progress()
	test_header_bar()
	test_menu_style_components()
	test_base_theme_carries_design()
	test_theme_items_are_valid()
	await test_theme_cascades_to_live_controls()
	await test_button_states_render()
	_report()


############################################################
# 1. PALETTES & TOKENS
############################################################
func test_palettes_complete() -> void:
	_check(DesignTokens.missing_roles().is_empty(),
		"both palettes define every role (missing: %s)" % str(DesignTokens.missing_roles()))
	_check(DesignTokens.PALETTE_DARK.size() == DesignTokens.PALETTE_LIGHT.size(),
		"both palettes define the same number of roles (%d)" % DesignTokens.PALETTE_DARK.size())


func test_token_scales() -> void:
	_check(DesignTokens.RADIUS_XS < DesignTokens.RADIUS_SM
			and DesignTokens.RADIUS_SM < DesignTokens.RADIUS_MD
			and DesignTokens.RADIUS_MD < DesignTokens.RADIUS_LG
			and DesignTokens.RADIUS_LG < DesignTokens.RADIUS_XL,
		"the radius scale rises monotonically")
	_check(DesignTokens.SHADOW_SOFT_SIZE < DesignTokens.SHADOW_MEDIUM_SIZE
			and DesignTokens.SHADOW_MEDIUM_SIZE < DesignTokens.SHADOW_DEEP_SIZE,
		"the three shadow levels rise monotonically")
	_check(DesignTokens.SPACE_XS < DesignTokens.SPACE_SM
			and DesignTokens.SPACE_SM < DesignTokens.SPACE_MD
			and DesignTokens.SPACE_MD < DesignTokens.SPACE_LG
			and DesignTokens.SPACE_LG < DesignTokens.SPACE_XL,
		"the spacing scale rises monotonically")
	_check(DesignTokens.ICON_SM < DesignTokens.ICON_MD and DesignTokens.ICON_MD < DesignTokens.ICON_LG,
		"the icon size scale rises monotonically")
	# A pill must exceed the largest real radius, i.e. it really is "fully round".
	_check(DesignTokens.RADIUS_PILL > DesignTokens.RADIUS_XL * 4,
		"the pill radius is effectively infinite")


############################################################
# 2. COMPONENT FACTORIES
############################################################
func test_button_states() -> void:
	for dark in [true, false]:
		var which := "dark" if dark else "light"
		var resting := DesignTokens.button_default(dark)
		var hover := DesignTokens.button_hover(dark)
		var pressed := DesignTokens.button_pressed(dark)
		var disabled := DesignTokens.button_disabled(dark)
		var focus := DesignTokens.button_focus(dark)

		# The reference's default state: cream, pill, gold rim, warm glow.
		_check(resting.bg_color.a >= 0.999, "%s: default button fill is opaque" % which)
		_check(resting.corner_radius_top_left == DesignTokens.RADIUS_PILL, "%s: default button is a pill" % which)
		_check(resting.border_width_left == DesignTokens.BORDER_STANDARD, "%s: default button wears the gold rim" % which)
		_check(resting.border_color == DesignTokens.color_of(dark, "gold_rim"), "%s: the rim is the gold token" % which)
		_check(resting.shadow_size > 0, "%s: default button is elevated" % which)

		# Hover is the blue state, and it must glow harder than resting.
		_check(hover.bg_color == DesignTokens.color_of(dark, "accent"), "%s: hover fill is the accent" % which)
		_check(hover.shadow_size > resting.shadow_size, "%s: hover glows harder than resting" % which)

		# Pressed differs from hover, and disabled loses contrast AND its shadow.
		_check(pressed.bg_color != hover.bg_color, "%s: pressed differs from hover" % which)
		_check(disabled.shadow_size == 0, "%s: disabled button has no shadow" % which)
		_check(disabled.border_width_left == 0, "%s: disabled button has no rim" % which)

		# The focus ring is transparent so it layers over any other state.
		_check(focus.bg_color.a == 0.0, "%s: focus ring body is transparent" % which)
		_check(focus.border_width_left >= DesignTokens.BORDER_STANDARD, "%s: focus ring outline is visible" % which)

		# Cream needs dark ink; the blue states need white.
		_check(DesignTokens.button_text_color("default", dark) == DesignTokens.color_of(dark, "ink"),
			"%s: default button uses ink type" % which)
		_check(DesignTokens.button_text_color("hover", dark) == DesignTokens.color_of(dark, "on_accent"),
			"%s: hover button uses white type" % which)
		_check(DesignTokens.button_text_color("disabled", dark) == DesignTokens.color_of(dark, "text_muted"),
			"%s: disabled button uses muted type" % which)

		_check(DesignTokens.button_primary(dark).bg_color == DesignTokens.color_of(dark, "accent"),
			"%s: primary button is the accent blue" % which)


func test_cards_and_insets() -> void:
	for dark in [true, false]:
		var which := "dark" if dark else "light"
		var card := DesignTokens.card(dark)
		_check(card.bg_color.a >= 0.999, "%s: card fill is opaque" % which)
		_check(card.bg_color == DesignTokens.color_of(dark, "surface"), "%s: card fill is the surface role" % which)
		_check(card.border_width_left == DesignTokens.BORDER_SUBTLE, "%s: card has a hairline border" % which)
		_check(card.shadow_size == DesignTokens.SHADOW_SOFT_SIZE, "%s: card carries the soft elevation" % which)
		_check(DesignTokens.card(dark, true).shadow_size == DesignTokens.SHADOW_MEDIUM_SIZE,
			"%s: a lifted card elevates one level" % which)
		_check(DesignTokens.card(dark, false, true).shadow_size == 0,
			"%s: a flat card has no elevation" % which)
		_check(DesignTokens.card_paper(dark).bg_color.a >= 0.999, "%s: paper card is opaque" % which)
		_check(DesignTokens.card_paper(dark).border_color == DesignTokens.color_of(dark, "gold_rim"),
			"%s: paper card wears the gold rim" % which)
		_check(DesignTokens.card_accent(dark).bg_color.a >= 0.999, "%s: accent card is opaque" % which)

		var ins := DesignTokens.inset(dark)
		_check(ins.bg_color == DesignTokens.color_of(dark, "surface_sunken"),
			"%s: inset uses the sunken role" % which)
		_check(ins.border_width_top > ins.border_width_left, "%s: inset has a lit top edge" % which)
		_check(DesignTokens.input_focus(dark).border_color == DesignTokens.color_of(dark, "accent"),
			"%s: a focused input gets the blue ring" % which)
		_check(DesignTokens.input_focus(dark).shadow_size > 0,
			"%s: the focus ring glows (always visible, per the sheet)" % which)


func test_table_rows() -> void:
	for dark in [true, false]:
		var which := "dark" if dark else "light"
		var plain := DesignTokens.table_row("default", dark)
		var hover := DesignTokens.table_row("hover", dark)
		var selected := DesignTokens.table_row("selected", dark)
		_check(plain.bg_color != hover.bg_color
				and hover.bg_color != selected.bg_color
				and plain.bg_color != selected.bg_color,
			"%s: the three table row states are visually distinct" % which)
		_check(hover.bg_color == DesignTokens.color_of(dark, "accent"), "%s: hover row fills with the accent" % which)
		_check(selected.border_color == DesignTokens.color_of(dark, "gold_rim"),
			"%s: selected row wears the gold rim" % which)
		for state in ["default", "hover", "selected"]:
			_check(DesignTokens.table_row(state, dark).bg_color.a >= 0.999,
				"%s: '%s' row fill is opaque" % [which, state])
		_check(DesignTokens.table_row_text_color("hover", dark) == DesignTokens.color_of(dark, "on_accent"),
			"%s: hover row type is white" % which)


func test_modal_composition() -> void:
	for dark in [true, false]:
		var which := "dark" if dark else "light"
		var parts := DesignTokens.modal(dark)
		var head := parts["header"] as StyleBoxFlat
		var body := parts["body"] as StyleBoxFlat
		_check(head != null and body != null, "%s: the modal yields a header and a body" % which)
		if head == null or body == null:
			continue
		_check(head.bg_color == DesignTokens.color_of(dark, "accent"), "%s: modal header is the accent band" % which)
		_check(head.corner_radius_top_left > 0 and head.corner_radius_bottom_left == 0,
			"%s: modal header rounds its top corners only" % which)
		_check(body.corner_radius_bottom_left > 0 and body.corner_radius_top_left == 0,
			"%s: modal body rounds its bottom corners only" % which)
		_check(body.corner_radius_bottom_left == head.corner_radius_top_left,
			"%s: the modal's top and bottom corners match" % which)
		_check(body.shadow_size == DesignTokens.SHADOW_DEEP_SIZE,
			"%s: the modal floats on the deep shadow" % which)
		_check(DesignTokens.modal_text_color(dark).get_luminance() < 0.5,
			"%s: modal type is dark ink (its body is always paper)" % which)


func test_toggle_and_progress() -> void:
	for dark in [true, false]:
		var which := "dark" if dark else "light"
		var on := DesignTokens.toggle_track(true, dark)
		var off := DesignTokens.toggle_track(false, dark)
		_check(on.bg_color != off.bg_color, "%s: the toggle has distinct on/off tracks" % which)
		_check(on.bg_color == DesignTokens.color_of(dark, "accent"), "%s: the ON track is the accent" % which)
		_check(on.shadow_size > 0 and off.shadow_size == 0, "%s: only the ON track glows" % which)
		_check(DesignTokens.toggle_knob(dark).bg_color.a >= 0.999, "%s: the toggle knob is opaque" % which)

		var fill := DesignTokens.progress_fill(dark)
		var track := DesignTokens.progress_track(dark)
		_check(fill.bg_color == DesignTokens.color_of(dark, "accent"), "%s: progress fill is the accent" % which)
		_check(track.bg_color.a >= 0.999, "%s: progress track is opaque" % which)
		_check(track.bg_color != fill.bg_color, "%s: track and fill are distinguishable" % which)
		_check(fill.corner_radius_top_left == DesignTokens.RADIUS_PILL, "%s: the progress fill is rounded" % which)

		# A Slider grabber must be a Texture2D, not a stylebox.
		_check(DesignTokens.slider_grabber_texture(dark) is Texture2D,
			"%s: the slider grabber is a texture" % which)


func test_header_bar() -> void:
	for dark in [true, false]:
		var which := "dark" if dark else "light"
		var bar := DesignTokens.header_bar(dark)
		_check(bar.corner_radius_bottom_left > bar.corner_radius_top_left,
			"%s: the header bar rounds its bottom, not its top" % which)
		_check(bar.border_width_bottom > 0, "%s: the header bar has a bottom underline" % which)
		_check(bar.border_color == DesignTokens.color_of(dark, "gold_rim"),
			"%s: the header underline is gold" % which)
		_check(bar.shadow_size > 0, "%s: the header bar floats on a shadow" % which)


func test_menu_style_components() -> void:
	var dark := MenuStyle.is_dark()
	_check(MenuStyle.card_bg() == DesignTokens.color_of(dark, "surface"),
		"MenuStyle card fill follows the surface token")

	var card := MenuStyle.card_style(Color("#4C8DF6"))
	_check(card.bg_color.a >= 0.999, "MenuStyle card fill is opaque")
	_check(card.border_width_left == DesignTokens.BORDER_SUBTLE, "MenuStyle card has a hairline border")
	_check(card.content_margin_left == 0,
		"MenuStyle card adds no padding of its own (its MarginContainer owns the insets)")
	_check(MenuStyle.card_hover_style(Color("#4C8DF6")).shadow_size > card.shadow_size,
		"MenuStyle card hover elevates further than resting")

	# Every component the reference sheet adds must build without a scene.
	# Each one is a CanvasItem, so they are all collected and freed below: an
	# orphaned Control keeps its canvas RID alive to shutdown, which makes the
	# whole suite report as failed even though every assertion passed.
	var section := MenuStyle.make_section_header("Cards", "sub")
	var row := MenuStyle.make_table_row("Default", "default")
	var empty := MenuStyle.make_empty_state("Nothing here", "yet")
	var toast := MenuStyle.make_toast("Saved")
	var toggle := MenuStyle.make_toggle_row("Sound", true)
	var progress := MenuStyle.make_progress(0.4)
	_check(section != null, "section header builds")
	_check(row != null, "table row builds")
	_check(empty != null, "empty state builds")
	_check(toast != null, "toast builds")
	_check(toggle != null, "toggle row builds")
	_check(progress != null, "progress indicator builds")

	var primary := MenuStyle.make_button("Continue", "primary")
	var secondary := MenuStyle.make_button("Cancel", "secondary")
	_check(primary.get_theme_stylebox("normal").bg_color == DesignTokens.color_of(dark, "accent"),
		"a primary button is the accent blue")
	_check(secondary.get_theme_stylebox("normal").bg_color != primary.get_theme_stylebox("normal").bg_color,
		"a secondary button's fill differs from the primary one")

	var modal := MenuStyle.make_modal("Title", "Body copy", "Cancel", "Content")
	_check(modal.has("root") and modal.has("cancel") and modal.has("confirm"),
		"the modal exposes root / cancel / confirm")

	for node in [section, row, empty, toast, toggle, progress, primary, secondary, modal.get("root")]:
		var control := node as Node
		if control != null:
			control.free()


############################################################
# 3. THE INSTALLED THEME
############################################################
func test_base_theme_carries_design() -> void:
	var theme: Theme = Global.get_base_theme()
	_check(theme != null, "ThemeService has built a base Theme")
	if theme == null:
		return

	_check(get_tree().root.theme == theme,
		"the base Theme is installed on the tree root (so it cascades app-wide)")

	var dark: bool = Global.theme_is_dark()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_check(theme.get_stylebox(state, "Button") is StyleBoxFlat,
			"the base Theme styles Button '%s'" % state)

	var resting := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	_check(resting != null and resting.corner_radius_top_left == DesignTokens.RADIUS_PILL,
		"the base Theme's button is the designed pill")
	_check(theme.get_color("font_color", "Button") == DesignTokens.button_text_color("default", dark),
		"the base Theme's button type matches its cream fill")
	_check(theme.get_color("font_color", "Label") == DesignTokens.color_of(dark, "text"),
		"the base Theme's label type is the text role")

	# The boxes and controls from the reference sheet.
	_check(theme.get_stylebox("panel", "Panel") is StyleBoxFlat, "the base Theme styles Panel")
	_check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxFlat, "the base Theme styles PanelContainer")
	_check(theme.get_stylebox("normal", "LineEdit") is StyleBoxFlat, "the base Theme styles LineEdit")
	_check(theme.get_stylebox("focus", "LineEdit") is StyleBoxFlat, "the base Theme styles the focused LineEdit")
	_check(theme.get_stylebox("background", "ProgressBar") is StyleBoxFlat, "the base Theme styles the progress track")
	_check(theme.get_stylebox("fill", "ProgressBar") is StyleBoxFlat, "the base Theme styles the progress fill")
	_check(theme.get_stylebox("slider", "HSlider") is StyleBoxFlat, "the base Theme styles the slider track")
	_check(theme.get_icon("grabber", "HSlider") is Texture2D, "the base Theme gives the slider a grabber texture")
	_check(theme.get_stylebox("scroll", "VScrollBar") is StyleBoxFlat, "the base Theme styles the scrollbar trough")
	_check(theme.get_stylebox("grabber", "VScrollBar") is StyleBoxFlat, "the base Theme styles the scrollbar handle")
	_check(theme.get_stylebox("panel", "PopupMenu") is StyleBoxFlat, "the base Theme styles popup menus")
	_check(theme.get_stylebox("panel", "AcceptDialog") is StyleBoxFlat, "the base Theme styles dialogs")


## A theme item whose NAME is not defined on its control type is silently
## accepted by Godot and simply never used — so a typo restyles nothing and
## raises no error. This walks the whole theme and fails on any such item.
func test_theme_items_are_valid() -> void:
	var theme: Theme = Global.get_base_theme()
	if theme == null:
		_check(false, "a base Theme exists to audit")
		return
	var built_in := ThemeDB.get_default_theme()
	var bogus: Array = []
	for type_name in theme.get_type_list():
		for item in theme.get_stylebox_list(type_name):
			if not built_in.get_stylebox_list(type_name).has(item):
				bogus.append("%s.stylebox:%s" % [type_name, item])
		for item in theme.get_color_list(type_name):
			if not built_in.get_color_list(type_name).has(item):
				bogus.append("%s.color:%s" % [type_name, item])
		for item in theme.get_icon_list(type_name):
			if not built_in.get_icon_list(type_name).has(item):
				bogus.append("%s.icon:%s" % [type_name, item])
		for item in theme.get_constant_list(type_name):
			if not built_in.get_constant_list(type_name).has(item):
				bogus.append("%s.constant:%s" % [type_name, item])
	_check(bogus.is_empty(), "every theme item name is valid on its control type (bogus: %s)" % str(bogus))


## The end-to-end proof: a Control added to the live tree resolves the designed
## styles through the theme cascade, with no styling call of its own.
func test_theme_cascades_to_live_controls() -> void:
	var probe := Button.new()
	add_child(probe)
	var panel := PanelContainer.new()
	add_child(panel)
	await get_tree().process_frame

	var sb: StyleBox = probe.get_theme_stylebox("normal")
	# Report the observed values in the label: if this ever regresses, the
	# message should say WHAT was resolved, not merely that it was wrong.
	var radius := -1
	if sb is StyleBoxFlat:
		radius = (sb as StyleBoxFlat).corner_radius_top_left
	_check(radius == DesignTokens.RADIUS_PILL,
		"a live Button inherits the designed pill (radius=%d, box=%s)" % [radius, sb.get_class()])
	_check(panel.get_theme_stylebox("panel") is StyleBoxFlat,
		"a live PanelContainer inherits the designed card")
	var expected := DesignTokens.button_text_color("default", Global.theme_is_dark())
	var got := probe.get_theme_color("font_color")
	_check(got == expected,
		"a live Button inherits the designed type colour (got %s, want %s)" % [got, expected])

	# Detach and free immediately: a queued_free here would never be processed
	# (the scene ends first) and would leave canvas items alive at exit.
	remove_child(probe)
	probe.free()
	remove_child(panel)
	panel.free()


############################################################
# 4. RENDER CHECK
############################################################
## Renders real Buttons into a SubViewport and samples the result, proving the
## styles PAINT rather than merely exist. The corner sample is the important
## one: it only reads as background if the pill radius truly clipped the box,
## and the channel comparisons prove the warm cream and the blue actually land.
##
## Skipped (not failed) under a headless harness, where there is no GPU and the
## viewport texture comes back empty.
func test_button_states_render() -> void:
	# A headless display server has no GPU and never emits the post-draw signal,
	# so awaiting it would hang the whole suite. Skip cleanly instead: this
	# check is meaningful on a real window, which is where it should run.
	if DisplayServer.get_name() == "headless":
		print("SKIP  button render check (headless display server)")
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 120)
	# A SubViewport that is never displayed must be told to render every frame;
	# the default UPDATE_WHEN_VISIBLE leaves it blank, which would make every
	# pixel read as black and let the colour checks pass vacuously.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(400, 120)
	viewport.add_child(backdrop)

	var dark := Global.theme_is_dark()
	var resting := Button.new()
	resting.text = ""
	resting.position = Vector2(20, 20)
	resting.size = Vector2(360, 80)
	resting.add_theme_stylebox_override("normal", DesignTokens.button_default(dark))
	viewport.add_child(resting)

	var hot := Button.new()
	hot.text = ""
	hot.position = Vector2(20, 20)
	hot.size = Vector2(360, 80)
	hot.add_theme_stylebox_override("normal", DesignTokens.button_hover(dark))
	hot.visible = false
	viewport.add_child(hot)

	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		print("SKIP  button render check (headless harness: no viewport texture)")
		remove_child(viewport)
		viewport.free()
		return

	# ── Resting: the warm cream default, with a clipped pill corner ──
	var resting_px := image.get_pixel(200, 60)
	_check(resting_px.a > 0.9, "the resting button paints an opaque fill")
	# Prove something PAINTED before judging its hue: on a blank viewport every
	# pixel is black, which would satisfy a naive r>=b comparison trivially.
	_check(resting_px.v > 0.2,
		"the resting button painted rather than leaving the backdrop (got %s)" % resting_px)
	_check(resting_px.r >= resting_px.b, "the resting button paints the warm cream default")
	_check(image.get_pixel(22, 22).v < 0.2, "the pill radius clips the corner back to the background")

	# ── Hover: the blue accent ──
	resting.visible = false
	hot.visible = true
	# TWO draws: one frame to absorb the visibility swap, the next to have the
	# changed tree actually painted before the texture is read back.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	var hot_px := image.get_pixel(200, 60)
	_check(hot_px.b > hot_px.r, "the hover button paints the blue accent (got %s)" % hot_px)
	_check(hot_px.b > resting_px.b,
		"hover is measurably bluer than the resting state (hover %s vs resting %s)" % [hot_px, resting_px])

	remove_child(viewport)
	viewport.free()


############################################################
# HARNESS
############################################################
func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS  " if condition else "FAIL  ") + label)


func _report() -> void:
	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
