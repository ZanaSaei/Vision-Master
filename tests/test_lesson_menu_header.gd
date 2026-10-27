extends Node
## ============================================================
##  LESSON MENU HEADER — regression test for the top bar.
##
##  The lesson menu shows its section cards under a fixed header bar: the same
##  bar the main menu puts on top of its own screen (full width, 200 px tall,
##  rounded bottom shoulders). The screen's top label — "pick a section" — lives
##  on that bar instead of scrolling away with the cards, the bar paints over the
##  scrolling list, and it lets wheel / drag gestures through to it.
##
##  Run with run_tests on this file.
## ============================================================

const LessonMenuScript := preload("res://scenes/lesson_menu/lesson_menu.gd")
const LESSON_MENU_SCENE: PackedScene = preload("res://scenes/lesson_menu/LessonMenu.tscn")

## Mirrors HeaderBar in scenes/main_menu/MainMenu.tscn, which authors
## `custom_minimum_size = Vector2(0, 200)` and a StyleBoxFlat with 35 px bottom
## corner radii. The lesson menu follows the main menu, as asked.
const MAIN_MENU_HEADER_HEIGHT := 200.0
const MAIN_MENU_HEADER_RADIUS := 35


func test_header_bar_sits_on_top_at_the_main_menu_size() -> void:
	var screen: Control = await _spawn_lesson_menu()
	var header: Control = screen.get_node_or_null("HeaderBar") as Control
	_check(header is PanelContainer, "the screen has a header bar")

	_check(is_equal_approx(header.position.y, 0.0), "the bar starts at the top edge")
	_check(
		is_equal_approx(header.size.y, MAIN_MENU_HEADER_HEIGHT),
		"the bar is 200 px tall, like the main menu's"
	)
	_check(
		is_equal_approx(header.size.x, _screen_size().x),
		"the bar spans the full width"
	)

	var bar: StyleBoxFlat = header.get_theme_stylebox("panel") as StyleBoxFlat
	_check(bar != null, "the bar paints a panel style")
	if bar != null:
		_check(
			bar.corner_radius_bottom_left == MAIN_MENU_HEADER_RADIUS
			and bar.corner_radius_bottom_right == MAIN_MENU_HEADER_RADIUS,
			"the bar rounds its bottom shoulders"
		)
		_check(
			bar.corner_radius_top_left == 0 and bar.corner_radius_top_right == 0,
			"the bar meets the screen edge square"
		)

	screen.queue_free()
	await get_tree().process_frame


func test_top_label_lives_on_the_bar() -> void:
	var screen: Control = await _spawn_lesson_menu()
	var header: Control = screen.get_node("HeaderBar") as Control
	var label: Label = screen.get("_title_label") as Label

	_check(label != null, "the screen keeps a reference to its top label")
	_check(header.is_ancestor_of(label), "the top label sits on the header bar")
	_check(
		label.text == LessonMenuScript.HEADER_TEXT,
		"the label still carries the screen's top prompt"
	)

	var bar_rect: Rect2 = header.get_global_rect()
	var label_rect: Rect2 = label.get_global_rect()
	_check(bar_rect.encloses(label_rect), "the label fits inside the bar")
	_check(
		absf(label_rect.get_center().x - bar_rect.get_center().x) < 1.0,
		"the label is centred across the bar"
	)
	_check(
		absf(label_rect.get_center().y - bar_rect.get_center().y) < 1.0,
		"the label is centred in the bar"
	)

	# The bar is the screen's title, so it is tinted with the book's accent.
	var book_accent: Color = LessonMenuScript.BOOK_COLORS.get(
		int(screen.get("_book")), MenuStyle.accent()
	)
	_check(
		label.get_theme_color("font_color") == book_accent,
		"the title takes the current book's accent colour"
	)

	screen.queue_free()
	await get_tree().process_frame


func test_bar_paints_over_the_list_and_the_list_starts_below_it() -> void:
	var screen: Control = await _spawn_lesson_menu()
	var header: Control = screen.get_node("HeaderBar") as Control
	var scroll: ScrollContainer = screen.get("_scroll") as ScrollContainer

	_check(
		header.get_index() > scroll.get_index(),
		"the bar is added after the list, so it draws over the cards that scroll up"
	)

	var cards: Array = screen.get("_card_buttons")
	_check(cards.size() > 0, "the screen built its section cards")
	if cards.is_empty():
		screen.queue_free()
		await get_tree().process_frame
		return
	var first_card: Control = cards[0] as Control
	_check(
		first_card.get_global_rect().position.y >= header.get_global_rect().end.y,
		"the first card starts below the bar"
	)

	screen.queue_free()
	await get_tree().process_frame


func test_bar_lets_gestures_reach_the_list() -> void:
	var screen: Control = await _spawn_lesson_menu()
	var header: Control = screen.get_node("HeaderBar") as Control

	_check(
		header.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the bar ignores the mouse"
	)
	var blocking: Array[String] = []
	for node: Node in _descendants(header):
		if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(String(node.name))
	_check(
		blocking.is_empty(),
		"nothing on the bar swallows wheel / drag gestures (%s)" % str(blocking)
	)

	screen.queue_free()
	await get_tree().process_frame


## Spawns the real screen so the assertions run against what ships.
func _spawn_lesson_menu() -> Control:
	var screen: Control = LESSON_MENU_SCENE.instantiate() as Control
	add_child(screen)
	# _ready() builds the UI and starts the entrance tween; the anchored bar
	# only has its final rect after a layout pass.
	for _i: int in range(3):
		await get_tree().process_frame
	return screen


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)
