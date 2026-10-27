extends Node
## ============================================================
##  GLOSSY MENU CARD — regression test for the shiny section cards.
##
##  The lesson menu's section cards are glossy buttons: a raised face carrying a
##  whisper of the section colour (MenuTheme.gloss_body) with a sheen overlay on
##  top of it (GlossSheen + gloss_sheen.gdshader) that brightens on hover and
##  flattens while pressed.
##
##  What must stay true:
##    • a glossy card carries exactly ONE coating, tinted with its accent and
##      masked with the card's own corner radius,
##    • the coating never eats the card's clicks and paints under its content,
##    • restyling (a theme change) reuses the coating instead of stacking one,
##    • hover / press / release drive the shine,
##    • the shine actually paints — a bright band at the top, the shaded bottom
##      and rounded corners that keep their curve.
##
##  Run with run_tests on this file.
## ============================================================

const GlossSheenScript := preload("res://ui/widgets/gloss_sheen.gd")
const LESSON_MENU_SCENE: PackedScene = preload("res://scenes/lesson_menu/LessonMenu.tscn")

const ACCENT := Color("#4C8DF6")
const OTHER_ACCENT := Color("#E4572E")
const RADIUS := 26
## Sized like a real section card, so the radius mask is measured against the
## proportions the sheen shader is tuned for.
const CARD_SIZE := Vector2(600, 150)


func test_card_carries_exactly_one_shine_coating() -> void:
	var card: Button = await _glossy_card(ACCENT)
	var glosses: Array[GlossSheen] = _glosses(card)
	_check(glosses.size() == 1, "the card carries exactly one shine coating (%d)" % glosses.size())
	if glosses.is_empty():
		await _discard(card)
		return

	var gloss: GlossSheen = glosses[0]
	_check(gloss.get_script() == GlossSheenScript, "the coating is a GlossSheen")
	_check(
		gloss.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the coating never swallows the card's clicks"
	)
	_check(
		gloss.get_index() == 0,
		"the coating paints under the icon chip and the labels"
	)
	_check(
		gloss.size.is_equal_approx(CARD_SIZE),
		"the coating covers the whole face (%s vs %s)" % [str(gloss.size), str(CARD_SIZE)]
	)

	await _discard(card)


func test_shine_is_tinted_and_masked_like_the_card() -> void:
	var card: Button = await _glossy_card(ACCENT)
	var gloss: GlossSheen = _glosses(card)[0]
	var mat: ShaderMaterial = gloss.material as ShaderMaterial
	_check(mat != null, "the coating has a material")
	_check(mat.shader != null, "the coating runs a shader")

	_check(
		(mat.get_shader_parameter("tint") as Color) == ACCENT,
		"the shine is tinted with the section accent"
	)
	_check(
		is_equal_approx(float(mat.get_shader_parameter("corner_radius")), float(RADIUS)),
		"the shine mask matches the card's corner radius"
	)
	var measured: Vector2 = mat.get_shader_parameter("rect_size")
	_check(
		measured.is_equal_approx(CARD_SIZE),
		"the shader measures the card in pixels (%s)" % str(measured)
	)

	var uniforms: PackedStringArray = PackedStringArray()
	for uniform: Dictionary in mat.shader.get_shader_uniform_list():
		uniforms.append(String(uniform.get("name", "")))
	for required: String in ["rect_size", "corner_radius", "tint", "sheen"]:
		_check(uniforms.has(required), "the shader exposes `%s`" % required)

	await _discard(card)


func test_face_is_a_light_glass_wash_rimmed_with_the_accent() -> void:
	var card: Button = await _glossy_card(ACCENT)
	var normal: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
	var hover: StyleBoxFlat = card.get_theme_stylebox("hover") as StyleBoxFlat
	var pressed: StyleBoxFlat = card.get_theme_stylebox("pressed") as StyleBoxFlat
	_check(normal != null and hover != null and pressed != null, "the card paints all three states")
	if normal == null or hover == null or pressed == null:
		await _discard(card)
		return

	var body: Color = MenuTheme.gloss_body(ACCENT)
	_check(normal.bg_color == body, "the face is the glossy body for the accent")
	_check(
		body.get_luminance() > 0.85,
		"the face stays light enough for the theme's dark ink (%.2f)" % body.get_luminance()
	)
	_check(
		normal.bg_color.r < 0.999 or normal.bg_color.b < 0.999,
		"the face is tinted, not dead white"
	)
	_check(
		normal.corner_radius_top_left == RADIUS and normal.corner_radius_bottom_right == RADIUS,
		"the face keeps the card's rounded corners"
	)
	_check(
		normal.border_width_left == DesignTokens.BORDER_SUBTLE,
		"the face is rimmed with a hairline"
	)
	_check(
		is_equal_approx(normal.border_color.a, 0.45),
		"the rim is a soft accent line, not the old solid accent"
	)

	# The gloss sits ON TOP of the elevation, so hover still lifts and a press
	# still sinks — the shine only adds light.
	_check(
		hover.bg_color.get_luminance() > normal.bg_color.get_luminance(),
		"hover lifts the face"
	)
	_check(
		hover.shadow_size >= normal.shadow_size,
		"hover keeps the deeper shadow"
	)
	_check(
		pressed.bg_color.get_luminance() < normal.bg_color.get_luminance(),
		"press sinks the face"
	)
	_check(
		card.get_theme_stylebox("focus") == hover,
		"focus shows the same lifted face"
	)

	await _discard(card)


func test_the_coating_issues_a_draw_command_to_paint_on() -> void:
	# A material only applies to DRAW COMMANDS, and a bare Control issues none:
	# without its own `_draw()` the coating would sit in the tree, carry a shader
	# and still be invisible. That bug is silent, so it is pinned here.
	var card: Button = await _glossy_card(ACCENT)
	var gloss: GlossSheen = _glosses(card)[0]
	_check(
		gloss.has_method("_draw"),
		"the coating issues a draw command, so its shader actually runs"
	)

	# The sheen the tween animates is the same value the shader receives.
	gloss.sheen = 0.42
	var mat: ShaderMaterial = gloss.material as ShaderMaterial
	_check(
		is_equal_approx(float(mat.get_shader_parameter("sheen")), 0.42),
		"the shine state is pushed into the shader (%.2f)"
		% float(mat.get_shader_parameter("sheen"))
	)
	gloss.sheen = GlossSheenScript.SHEEN_REST

	await _discard(card)


func test_restyling_reuses_the_coating_instead_of_stacking_it() -> void:
	var card: Button = await _glossy_card(ACCENT)
	_check(_glosses(card).size() == 1, "one coating before the restyle")

	MenuStyle.style_gloss_card(card, OTHER_ACCENT, RADIUS)
	await _frames(2)

	_check(_glosses(card).size() == 1, "one coating after the restyle")
	var gloss: GlossSheen = _glosses(card)[0]
	var mat: ShaderMaterial = gloss.material as ShaderMaterial
	_check(
		(mat.get_shader_parameter("tint") as Color) == OTHER_ACCENT,
		"the coating is re-tinted for the new accent"
	)
	_check(
		(card.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
			== MenuTheme.gloss_body(OTHER_ACCENT),
		"the face is repainted for the new accent"
	)
	_check(
		card.mouse_entered.get_connections().size() == 1,
		"the hover wiring is not attached twice"
	)

	await _discard(card)


func test_hover_brightens_the_shine_and_a_press_flattens_it() -> void:
	var card: Button = await _glossy_card(ACCENT)
	var gloss: GlossSheen = _glosses(card)[0]
	_check(is_equal_approx(gloss.sheen, GlossSheenScript.SHEEN_REST), "the shine rests at zero")

	card.mouse_entered.emit()
	_check(
		await _wait_for_sheen(gloss, GlossSheenScript.SHEEN_HOVER),
		"hovering brings the shine up (%.2f)" % gloss.sheen
	)

	card.button_down.emit()
	_check(
		await _wait_for_sheen(gloss, GlossSheenScript.SHEEN_PRESSED),
		"pressing flattens the shine (%.2f)" % gloss.sheen
	)

	card.button_up.emit()
	_check(
		await _wait_for_sheen(gloss, GlossSheenScript.SHEEN_REST),
		"releasing settles the shine back to rest (%.2f)" % gloss.sheen
	)

	await _discard(card)


func test_lesson_menu_section_cards_are_all_glossy() -> void:
	var screen: Control = LESSON_MENU_SCENE.instantiate() as Control
	add_child(screen)
	await _frames(3)

	var cards: Array = screen.get("_card_buttons")
	var accents: Array = screen.get("_card_accents")
	_check(cards.size() > 0, "the screen built its section cards")
	_check(cards.size() == accents.size(), "every section card remembers its accent")
	if cards.is_empty():
		await _discard(screen)
		return

	for i: int in range(cards.size()):
		var card: Button = cards[i] as Button
		var accent: Color = accents[i]
		var glosses: Array[GlossSheen] = _glosses(card)
		_check(
			glosses.size() == 1,
			"section card %d carries exactly one shine coating (%d)" % [i, glosses.size()]
		)
		if glosses.is_empty():
			continue
		var mat: ShaderMaterial = glosses[0].material as ShaderMaterial
		_check(
			(mat.get_shader_parameter("tint") as Color) == accent,
			"section card %d is tinted with its own accent" % i
		)
		_check(
			(card.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
				== MenuTheme.gloss_body(accent),
			"section card %d wears the glossy face" % i
		)

	await _discard(screen)


## Renders a glossy button offscreen and reads the pixels back, so the shine is
## verified by what it actually paints and not only by its settings. Skipped when
## the run has no rendering driver (headless), where every pixel reads as zero.
func test_the_shine_paints_a_top_highlight_over_a_shaded_bottom() -> void:
	# The dummy renderer of a headless run has no texture to read back, so this
	# check only runs where something actually draws (the editor's Game tab,
	# `godot --path .` and so on).
	if DisplayServer.get_name() == "headless":
		print("SKIP  headless run — the pixel check needs a rendering driver")
		return

	var size := Vector2i(400, 220)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var card := Button.new()
	card.text = ""
	card.position = Vector2.ZERO
	card.size = Vector2(size)
	viewport.add_child(card)
	MenuStyle.style_gloss_card(card, ACCENT, RADIUS)
	await _frames(2)
	await _wait_for_draw()

	var img: Image = viewport.get_texture().get_image()
	if img == null or img.get_width() == 0 or _is_blank(img):
		print("SKIP  no rendering driver in this run — pixel check needs a window")
		viewport.queue_free()
		return

	var corner: Color = img.get_pixel(3, 3)
	var top: Color = img.get_pixel(size.x / 2, 24)
	var middle: Color = img.get_pixel(size.x / 2, size.y / 2)
	var bottom: Color = img.get_pixel(size.x / 2, size.y - 12)

	print(
		"gloss pixels — corner a=%.2f  top=%.3f  middle=%.3f  bottom=%.3f"
		% [corner.a, top.get_luminance(), middle.get_luminance(), bottom.get_luminance()]
	)
	_print_luminance_map(img)

	_check(corner.a < 0.5, "the shine keeps the rounded corner cut (a=%.2f)" % corner.a)
	_check(middle.a > 0.99, "the face itself is opaque (a=%.2f)" % middle.a)
	_check(
		top.get_luminance() > middle.get_luminance(),
		"the top of the card is brighter than its middle (%.3f > %.3f)"
		% [top.get_luminance(), middle.get_luminance()]
	)
	_check(
		middle.get_luminance() > bottom.get_luminance(),
		"the bottom of the card is shaded under the shine (%.3f > %.3f)"
		% [middle.get_luminance(), bottom.get_luminance()]
	)
	_check(
		middle.b > middle.r,
		"the face carries the accent's hue (b=%.3f > r=%.3f)" % [middle.b, middle.r]
	)

	viewport.queue_free()


# ---------------------------------------------------------------- helpers --

## A real menu card, sized like a section card and dressed glossy.
func _glossy_card(accent_col: Color) -> Button:
	var card: Button = MenuStyle.make_card("Section", "زیربخش", "📘", accent_col, int(CARD_SIZE.y))
	card.size = CARD_SIZE
	add_child(card)
	await _frames(2)
	MenuStyle.style_gloss_card(card, accent_col, RADIUS)
	await _frames(2)
	return card


func _glosses(node: Node) -> Array[GlossSheen]:
	var out: Array[GlossSheen] = []
	for child: Node in node.get_children():
		if child is GlossSheen:
			out.append(child as GlossSheen)
	return out


## Waits (bounded) for the shine tween to reach `target`, so the assertion does
## not depend on the frame rate of the test run.
func _wait_for_sheen(gloss: GlossSheen, target: float, tolerance: float = 0.02) -> bool:
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if absf(gloss.sheen - target) <= tolerance:
			return true
	return absf(gloss.sheen - target) <= tolerance


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


## Waits for one real draw, but never blocks the suite: a headless run may never
## emit frame_post_draw, so the wait falls back to a plain frame budget.
func _wait_for_draw() -> void:
	var drawn := [false]
	var on_draw := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(on_draw)
	for _i: int in range(6):
		await get_tree().process_frame
		if drawn[0]:
			break
	RenderingServer.frame_post_draw.disconnect(on_draw)


func _discard(node: Node) -> void:
	node.queue_free()
	await get_tree().process_frame


func _is_blank(img: Image) -> bool:
	for y: int in range(0, img.get_height(), 8):
		for x: int in range(0, img.get_width(), 8):
			if img.get_pixel(x, y).a > 0.0:
				return false
	return true


## Coarse ASCII luminance map — makes the render's look readable in the test log
## (0 = black, 9 = white, "." = transparent).
func _print_luminance_map(img: Image) -> void:
	var cols := 40
	var rows := 11
	var step_x := maxi(1, img.get_width() / cols)
	var step_y := maxi(1, img.get_height() / rows)
	for row: int in range(rows):
		var line := ""
		for col: int in range(cols):
			var px: Color = img.get_pixel(
				mini(col * step_x + step_x / 2, img.get_width() - 1),
				mini(row * step_y + step_y / 2, img.get_height() - 1)
			)
			if px.a < 0.5:
				line += "."
			else:
				line += str(clampi(int(px.get_luminance() * 10.0), 0, 9))
		print("      " + line)


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)
