extends Node
## ============================================================
##  UNIFIED HEADER BAR — regression test for the app-wide bar.
##
##  Every screen in the app wears the same header: a 200 px tall white surface
##  with 35 px bottom shoulders, 60 px side padding, a centred title and SQUARE
##  ICON BUTTONS of one size in one fixed slot (back and home on the left,
##  translation / audio / Leitner on the right). Nothing on the bar is text and
##  nothing on the bar moves or scales.
##
##  Run with run_tests on this file.
## ============================================================

## Mirrors HeaderBarStyler and scenes/shared/HeaderBar.tres. Restated here on
## purpose: the test must fail if the shipped values drift, not follow them.
const HEADER_HEIGHT := 200.0
const HEADER_RADIUS := 35
const PAD_X := 60.0
const BUTTON_SIZE := 96.0

const WORKBOOK_SCENE: PackedScene = preload("res://scenes/workbook/Workbook.tscn")
const SURFACE_PATH := "res://scenes/shared/HeaderBar.tres"
const LessonMenuScript := preload("res://scenes/lesson_menu/lesson_menu.gd")
const HeaderBarStyler := preload("res://autoload/theme/header_bar_styler.gd")


func test_a_screen_header_wears_the_new_bar() -> void:
	var bar: PanelContainer = await _spawn_header("HeaderBar", false, true)
	Global.style_header(bar)
	await get_tree().process_frame

	_check(is_equal_approx(bar.position.y, 0.0), "the bar starts at the top edge")
	_check(is_equal_approx(bar.size.y, HEADER_HEIGHT), "the bar is 200 px tall")
	_check(is_equal_approx(bar.size.x, _screen_size().x), "the bar spans the full width")

	var surface := bar.get_theme_stylebox("panel") as StyleBoxFlat
	_check(surface != null, "the bar paints a panel style")
	if surface != null:
		_check(surface.bg_color == Color(1, 1, 1, 1), "the bar is the main menu's white surface")
		_check(
			surface.corner_radius_bottom_left == HEADER_RADIUS
			and surface.corner_radius_bottom_right == HEADER_RADIUS,
			"the bar rounds its bottom shoulders"
		)
		_check(
			surface.corner_radius_top_left == 0 and surface.corner_radius_top_right == 0,
			"the bar meets the screen edge square"
		)
		_check(
			surface.border_width_top == 0 and surface.border_width_bottom == 0
			and surface.border_width_left == 0 and surface.border_width_right == 0,
			"the bar carries no hairline border"
		)

	var buttons: Array[Button] = _buttons(bar)
	_check(buttons.size() == 5, "the bar carries its five buttons")
	for button: Button in buttons:
		_check(button.text == "", "%s shows an icon, not a word" % button.name)
		_check(button.icon != null, "%s carries its icon" % button.name)
		_check(
			button.custom_minimum_size.is_equal_approx(Vector2(BUTTON_SIZE, BUTTON_SIZE)),
			"%s is pinned to the one square size" % button.name
		)
		_check(
			button.size.is_equal_approx(Vector2(BUTTON_SIZE, BUTTON_SIZE)),
			"%s is laid out square" % button.name
		)
		_check(button.scale.is_equal_approx(Vector2.ONE), "%s stays still" % button.name)

	var leading: Node = bar.find_child("HeaderLeading", true, false)
	_check(leading != null, "the left cluster is built")
	if leading != null:
		var order: Array[String] = []
		for child: Node in leading.get_children():
			order.append(String(child.name))
		_check(order == ["BackButton", "HomeButton"], "back then home on the left")

	var trailing: Node = bar.find_child("HeaderTrailing", true, false)
	_check(trailing != null, "the right cluster is built")
	if trailing != null:
		var order: Array[String] = []
		for child: Node in trailing.get_children():
			order.append(String(child.name))
		_check(
			order == ["TranslationToggleButton", "AudioButton", "LeitnerButton"],
			"translation, audio then Leitner on the right"
		)

	var back := bar.find_child("BackButton", true, false) as Button
	_check(
		back != null and is_equal_approx(back.get_global_rect().position.x, PAD_X),
		"the back arrow sits %d px from the left edge" % int(PAD_X)
	)
	var last := bar.find_child("LeitnerButton", true, false) as Button
	_check(
		last != null and is_equal_approx(last.get_global_rect().end.x, _screen_size().x - PAD_X),
		"the right cluster ends %d px from the right edge" % int(PAD_X)
	)

	var title := bar.find_child("HeaderTitle", true, false) as Label
	_check(title != null, "the bar keeps its title")
	if title != null:
		_check(
			absf(title.get_global_rect().get_center().x - bar.get_global_rect().get_center().x) < 1.0,
			"the title is centred on the bar"
		)
		_check(title.get_theme_font_size("font_size") == 40, "the title uses the bar's type ramp")
		_check(title.label_settings == null, "the bar owns the title's type, not the scene")

	bar.queue_free()
	await get_tree().process_frame


func test_buttons_keep_the_same_slot_on_every_screen() -> void:
	# Two screens with different button sets: the left arrow must not move, and
	# the right cluster must stay flush with the right edge.
	var full: PanelContainer = await _spawn_header("HeaderBar", false, true)
	Global.style_header(full)
	var light: PanelContainer = await _spawn_light_header("TopBar")
	Global.style_header(light)
	await get_tree().process_frame

	var full_back := full.find_child("BackButton", true, false) as Button
	var light_back := light.find_child("BackButton", true, false) as Button
	_check(full_back != null and light_back != null, "both screens have a back button")
	if full_back != null and light_back != null:
		_check(
			full_back.get_global_rect().position.is_equal_approx(light_back.get_global_rect().position),
			"the back arrow sits in the same pixel on both screens"
		)
		_check(
			full_back.size.is_equal_approx(light_back.size),
			"the back arrow is the same size on both screens"
		)

	var full_audio := full.find_child("AudioButton", true, false) as Button
	var light_audio := light.find_child("AudioButton", true, false) as Button
	_check(full_audio != null and light_audio != null, "both screens have an audio button")
	if full_audio != null and light_audio != null:
		_check(
			full_audio.size.is_equal_approx(light_audio.size),
			"the audio button is the same size on both screens"
		)

	# Whichever buttons a screen shows, the right cluster hangs off the right
	# edge, so its last item sits at the same pixel every time.
	var full_trailing := full.find_child("HeaderTrailing", true, false) as Control
	var light_trailing := light.find_child("HeaderTrailing", true, false) as Control
	_check(full_trailing != null and light_trailing != null, "both screens build a right cluster")
	if full_trailing != null and light_trailing != null:
		var full_last := full_trailing.get_child(full_trailing.get_child_count() - 1) as Control
		var light_last := light_trailing.get_child(light_trailing.get_child_count() - 1) as Control
		_check(
			is_equal_approx(full_last.get_global_rect().end.x, _screen_size().x - PAD_X)
			and is_equal_approx(light_last.get_global_rect().end.x, _screen_size().x - PAD_X),
			"the right cluster ends flush with the right edge on both screens"
		)

	full.queue_free()
	light.queue_free()
	await get_tree().process_frame


func test_margin_box_headers_behave_the_same() -> void:
	# WordReview-shaped header: MarginContainer -> row -> back + counter label.
	var bar: PanelContainer = await _spawn_header("HeaderBar", true, false)
	Global.style_header(bar)
	await get_tree().process_frame

	_check(is_equal_approx(bar.size.y, HEADER_HEIGHT), "a margin-box header is 200 px tall too")
	var back := bar.find_child("BackButton", true, false) as Button
	_check(
		back != null and is_equal_approx(back.get_global_rect().position.x, PAD_X),
		"its back arrow also sits %d px in" % int(PAD_X)
	)
	_check(
		back != null and back.custom_minimum_size.is_equal_approx(Vector2(BUTTON_SIZE, BUTTON_SIZE)),
		"its back arrow is the same square icon button"
	)
	var title := bar.find_child("DueCounter", true, false) as Label
	_check(title != null, "the counter label becomes the bar's title")
	if title != null:
		_check(
			absf(title.get_global_rect().get_center().x - bar.get_global_rect().get_center().x) < 1.0,
			"the counter is centred on the bar"
		)

	bar.queue_free()
	await get_tree().process_frame


func test_a_header_added_at_runtime_is_styled_automatically() -> void:
	# The engine must reach a bar nobody remembered to style: ThemeService
	# watches the tree, so a screen that never calls style_header still lands
	# on the app-wide bar.
	var bar: PanelContainer = await _spawn_header("HeaderBar", false, true)
	_check(not is_equal_approx(bar.size.y, HEADER_HEIGHT), "the raw scene bar still has its old height")

	for _i: int in range(3):
		await get_tree().process_frame

	_check(is_equal_approx(bar.size.y, HEADER_HEIGHT), "the watcher shrank the bar to 200 px")
	var back := bar.find_child("BackButton", true, false) as Button
	_check(back != null and back.text == "" and back.icon != null, "the watcher iconised its buttons")

	bar.queue_free()
	await get_tree().process_frame


func test_the_shared_surface_resource_is_the_new_bar() -> void:
	var surface := load(SURFACE_PATH) as StyleBoxFlat
	_check(surface != null, "the shared header surface loads")
	if surface == null:
		return
	_check(surface.bg_color == Color(1, 1, 1, 1), "the shared surface is white")
	_check(
		surface.corner_radius_bottom_left == HEADER_RADIUS
		and surface.corner_radius_bottom_right == HEADER_RADIUS,
		"the shared surface has 35 px bottom shoulders"
	)
	_check(
		surface.corner_radius_top_left == 0 and surface.corner_radius_top_right == 0,
		"the shared surface has square top corners"
	)
	_check(surface.border_width_bottom == 0, "the shared surface dropped its gold hairline")


func test_every_authored_scene_header_is_200_tall() -> void:
	# Scene-authored geometry must match what the engine applies, otherwise the
	# first frame (and the editor) shows an old 320 px bar under the new one.
	var offenders: Array[String] = []
	for path: String in _header_scene_paths():
		var text := FileAccess.get_file_as_string(path)
		var height := _authored_header_height(text)
		if not is_equal_approx(height, HEADER_HEIGHT):
			offenders.append("%s (%.0f px)" % [path.get_file(), height])
	_check(offenders.is_empty(), "every scene header is authored 200 px tall %s" % str(offenders))


func test_header_buttons_stay_out_of_the_hover_choreography() -> void:
	var bar: PanelContainer = await _spawn_header("HeaderBar", false, true)
	Global.style_header(bar)
	await get_tree().process_frame

	var back := bar.find_child("BackButton", true, false) as Button
	_check(back != null, "the bar has a back button")
	if back != null:
		UiMotion.wire_microinteractions(back)
		_check(
			back.mouse_entered.get_connections().is_empty(),
			"the bar button is left out of the hover lift"
		)
		_check(back.scale.is_equal_approx(Vector2.ONE), "and it never scales")

	bar.queue_free()
	await get_tree().process_frame


func test_a_real_screen_wears_the_bar() -> void:
	# The workbook ships back / home / title / translation, so it proves the
	# wiring against a screen the engine never styled explicitly.
	var screen: Control = WORKBOOK_SCENE.instantiate() as Control
	add_child(screen)
	for _i: int in range(3):
		await get_tree().process_frame

	var bar: Control = screen.get_node_or_null("HeaderBar") as Control
	_check(bar != null, "the workbook has a header bar")
	if bar == null:
		screen.queue_free()
		await get_tree().process_frame
		return
	_check(is_equal_approx(bar.size.y, HEADER_HEIGHT), "the workbook bar is 200 px tall")
	_check(bar.get_theme_stylebox("panel") is StyleBoxFlat, "the workbook bar paints the shared surface")

	var buttons: Array[Button] = _buttons(bar)
	_check(buttons.size() == 3, "the workbook keeps its three header buttons")
	for button: Button in buttons:
		_check(
			button.text == "" and button.icon != null,
			"the workbook's %s is an icon button" % button.name
		)
		_check(
			button.size.is_equal_approx(Vector2(BUTTON_SIZE, BUTTON_SIZE)),
			"the workbook's %s is square" % button.name
		)

	var content: Control = screen.get_node_or_null("MarginContainer") as Control
	_check(content != null, "the workbook has a content area")
	if content != null:
		_check(
			content.get_global_rect().position.y < HEADER_HEIGHT + 120.0,
			"the content starts just under the bar, with no dead band"
		)

	screen.queue_free()
	await get_tree().process_frame


func test_no_screen_keeps_the_old_dead_band() -> void:
	# The bar shrank by 120 px, so a screen still positioning its content where
	# the old 320 px bar ended would show an empty band under the new one.
	var offenders: Array[String] = []
	for path: String in _header_scene_paths():
		var inside_header := false
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("[node "):
				inside_header = trimmed.contains("name=\"HeaderBar\"")
				continue
			if inside_header or not trimmed.begins_with("offset_top = "):
				continue
			var value := trimmed.trim_prefix("offset_top = ").to_float()
			if value >= 300.0 and value < 600.0:
				offenders.append("%s (%.0f px)" % [path.get_file(), value])
	_check(offenders.is_empty(), "no screen starts its content in the old dead band %s" % str(offenders))


func test_the_lesson_menu_mirrors_the_engine_constants() -> void:
	# The lesson menu builds its bar by hand (it is the reference screen) — its
	# numbers must equal the engine's, or the two menus drift apart.
	_check(
		is_equal_approx(LessonMenuScript.HEADER_HEIGHT, HeaderBarStyler.BAR_HEIGHT),
		"the lesson menu bar is the engine's height"
	)
	_check(
		LessonMenuScript.HEADER_RADIUS == HeaderBarStyler.BAR_RADIUS,
		"the lesson menu bar is the engine's radius"
	)
	_check(
		LessonMenuScript.HEADER_PAD_X == int(HeaderBarStyler.PAD_X),
		"the lesson menu pads the bar like the engine"
	)
	_check(
		LessonMenuScript.HEADER_LABEL_SIZE == HeaderBarStyler.TITLE_FONT_SIZE,
		"the lesson menu title is the engine's size"
	)


func test_every_header_button_icon_exists() -> void:
	var missing: Array[String] = []
	for kind: String in HeaderBarStyler.ICONS:
		var path: String = HeaderBarStyler.ICONS[kind]
		if not ResourceLoader.exists(path):
			missing.append(path)
	_check(missing.is_empty(), "every header button has its icon %s" % str(missing))


# ══════════════════════════════════════════════════════════════
#  FIXTURES
# ══════════════════════════════════════════════════════════════

## Builds a header the way the .tscn screens author it: a 320 px panel with a
## row of text buttons, so the test proves the engine re-shapes it. The bar is
## parented straight to the test node, so freeing it frees the whole fixture.
func _spawn_header(bar_name: String, with_margin: bool, full: bool, omit: Array = []) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = bar_name
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 320.0
	add_child(bar)

	var row := HBoxContainer.new()
	row.name = "HeaderContent"
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 45)
	if with_margin:
		var margin := MarginContainer.new()
		margin.name = "MarginContainer"
		bar.add_child(margin)
		margin.add_child(row)
	else:
		bar.add_child(row)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "بازگشت"
	row.add_child(back)

	if not full:
		var counter := Label.new()
		counter.name = "DueCounter"
		counter.text = "۱۲ کلمه"
		row.add_child(counter)
		return bar

	if not omit.has("HomeButton"):
		var home := Button.new()
		home.name = "HomeButton"
		home.text = "🏠"
		row.add_child(home)

	var title := Label.new()
	title.name = "HeaderTitle"
	title.text = "درس ۱\nمکالمه"
	var settings := LabelSettings.new()
	settings.font_size = 55
	title.label_settings = settings
	row.add_child(title)

	if not omit.has("TranslationToggleButton"):
		var translation := Button.new()
		translation.name = "TranslationToggleButton"
		translation.text = "Translate"
		row.add_child(translation)
	if not omit.has("AudioButton"):
		var audio := Button.new()
		audio.name = "AudioButton"
		audio.text = "صدا"
		row.add_child(audio)
	if not omit.has("LeitnerButton"):
		var leitner := Button.new()
		leitner.name = "LeitnerButton"
		row.add_child(leitner)
	return bar


## A lighter screen: only a back arrow, the title and the audio button.
func _spawn_light_header(bar_name: String) -> PanelContainer:
	return await _spawn_header(
		bar_name, false, true, ["HomeButton", "TranslationToggleButton", "LeitnerButton"]
	)


func _buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			out.append(node as Button)
			continue
		for child: Node in node.get_children():
			stack.push_back(child)
	return out


func _header_scene_paths() -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = ["res://scenes"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub: String in dir.get_directories():
			stack.append(dir_path.path_join(sub))
		for file_name: String in dir.get_files():
			if not file_name.ends_with(".tscn"):
				continue
			var path := dir_path.path_join(file_name)
			if FileAccess.get_file_as_string(path).contains("name=\"HeaderBar\""):
				out.append(path)
	out.sort()
	return out


## Height a scene authors for its HeaderBar: `offset_bottom` on an anchored
## bar, or `custom_minimum_size = Vector2(0, N)` on the main menu's Control.
func _authored_header_height(text: String) -> float:
	var inside := false
	var found := -1.0
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("[node "):
			inside = trimmed.contains("name=\"HeaderBar\"")
			continue
		if not inside:
			continue
		if trimmed.begins_with("offset_bottom = "):
			found = maxf(found, trimmed.trim_prefix("offset_bottom = ").to_float())
		elif trimmed.begins_with("custom_minimum_size = Vector2("):
			var pair := trimmed.trim_prefix("custom_minimum_size = Vector2(").split(")")
			if pair.size() > 0:
				var parts := String(pair[0]).split(",")
				if parts.size() == 2:
					found = maxf(found, String(parts[1]).strip_edges().to_float())
	return found


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)



