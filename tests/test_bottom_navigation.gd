extends Node
class_name BottomNavigationRegressionTests

const NAVIGATION_BAR_SCENE: PackedScene = preload("res://scenes/bottom_navigation/NavigationBar.tscn")


func _spawn_ready_bar() -> VisionNavigationBar:
	var bar: VisionNavigationBar = NAVIGATION_BAR_SCENE.instantiate() as VisionNavigationBar
	bar.auto_navigate = false
	add_child(bar)
	# _ready() awaits two frames while it lays out and captures positions.
	for _i: int in range(4):
		await get_tree().process_frame
	return bar


func test_menu_keeps_primary_selection_and_selector_position() -> void:
	var navigation_bar: VisionNavigationBar = await _spawn_ready_bar()
	navigation_bar.visible = true
	navigation_bar.current_index = 1
	VisionNavigationBar._last_primary_index = 1
	navigation_bar.call("_set_selector_position", 1, false)
	var selector: Control = navigation_bar.get_node("Selector") as Control
	var selector_position_before: Vector2 = selector.position

	navigation_bar.call("select_item", 5)

	_check(
		int(navigation_bar.get("current_index")) == 1,
		"Opening Menu keeps the primary selector index"
	)
	_check(
		VisionNavigationBar._last_primary_index == 1,
		"Opening Menu keeps the last primary index"
	)
	_check(
		selector.position.is_equal_approx(selector_position_before),
		"Opening Menu does not move the selector"
	)
	_check(
		bool(navigation_bar.get("menu_panel_open")),
		"Opening Menu shows the popup"
	)
	navigation_bar.queue_free()
	await get_tree().process_frame


func test_apply_scene_path_tracks_the_active_scene() -> void:
	var navigation_bar: VisionNavigationBar = await _spawn_ready_bar()

	navigation_bar.apply_scene_path("res://scenes/book_menu/BookSelection.tscn")
	_check(navigation_bar.visible, "The bar shows on a scene that owns it")
	_check(
		int(navigation_bar.get("current_index")) == 1,
		"Books selects the Books tab"
	)
	_check(
		VisionNavigationBar._last_primary_index == 1,
		"Books updates the last primary index"
	)

	# Side-menu destinations select the Menu tab and highlight their popup item.
	navigation_bar.apply_scene_path("res://scenes/settings/Settings.tscn")
	await get_tree().create_timer(VisionNavigationBar.MOVE_DURATION + 0.05).timeout
	_check(navigation_bar.visible, "The bar shows on a side-menu scene")
	_check(
		int(navigation_bar.get("current_index")) == 5,
		"A side-menu destination moves the selector to Menu"
	)
	_check(
		VisionNavigationBar._last_primary_index == 1,
		"A side-menu destination remembers the previous primary tab"
	)
	var menu_selector: Control = navigation_bar.get_node("Selector") as Control
	var menu_target_position: Vector2 = navigation_bar.call("_get_selector_position", 5)
	_check(
		menu_selector.position.is_equal_approx(menu_target_position),
		"The selector circle is positioned over the Menu tab"
	)
	_check(
		int(navigation_bar.get("active_menu_index")) == 2,
		"Settings highlights its menu destination icon"
	)
	var menu_highlights: Array[Panel] = navigation_bar.get("menu_item_highlights")
	_check(
		menu_highlights.size() == 4 and menu_highlights[2].visible,
		"The matching menu icon has a rounded highlight"
	)
	_check(
		not bool(navigation_bar.get("_is_navigating")),
		"Menu destinations leave navigation enabled"
	)
	navigation_bar.select_item(0)
	_check(
		int(navigation_bar.get("current_index")) == 0,
		"Primary navigation remains selectable from a menu destination"
	)

	# A scene that does not own the bar hides it.
	navigation_bar.apply_scene_path("res://scenes/exam/FinalExam.tscn")
	_check(not navigation_bar.visible, "The bar hides on a scene without navigation")

	navigation_bar.queue_free()
	await get_tree().process_frame


func test_menu_destination_highlight_tracks_each_side_scene() -> void:
	var navigation_bar: VisionNavigationBar = await _spawn_ready_bar()
	var menu_scene_paths: Array[String] = [
		"res://scenes/auth/Auth.tscn",
		"res://scenes/purchase/Purchase.tscn",
		"res://scenes/settings/Settings.tscn",
		"res://scenes/about_me/AboutMe.tscn"
	]
	var menu_highlights: Array[Panel] = navigation_bar.get("menu_item_highlights")

	for menu_index: int in range(menu_scene_paths.size()):
		navigation_bar.apply_scene_path(menu_scene_paths[menu_index])
		_check(
			int(navigation_bar.get("active_menu_index")) == menu_index,
			"Menu scene %d sets the matching active index" % menu_index
		)
		for highlight_index: int in range(menu_highlights.size()):
			var menu_highlight: Panel = menu_highlights[highlight_index]
			_check(
				menu_highlight.visible == (highlight_index == menu_index),
				"Only the current menu destination is highlighted"
			)
		_check(
			not bool(navigation_bar.get("_is_navigating")),
			"Navigation unlocks after menu scene %d" % menu_index
		)

	navigation_bar.apply_scene_path("res://scenes/main_menu/MainMenu.tscn")
	_check(
		int(navigation_bar.get("active_menu_index")) == -1,
		"Returning to a primary scene clears the menu highlight"
	)
	_check(
		int(navigation_bar.get("current_index")) == 0,
		"Returning to Home moves the selector back to Home"
	)
	navigation_bar.queue_free()
	await get_tree().process_frame


func test_bottom_tab_scene_paths_remain_primary_destinations() -> void:
	var navigation_bar: VisionNavigationBar = await _spawn_ready_bar()
	var home_index: int = int(navigation_bar.call(
		"_target_primary_index",
		"res://scenes/main_menu/MainMenu.tscn"
	))
	var books_index: int = int(navigation_bar.call(
		"_target_primary_index",
		"res://scenes/book_menu/BookSelection.tscn"
	))
	var menu_destination_index: int = int(navigation_bar.call(
		"_target_primary_index",
		"res://scenes/settings/Settings.tscn"
	))
	_check(home_index == 0, "Home remains a primary tab destination")
	_check(books_index == 1, "Books remains a primary tab destination")
	_check(menu_destination_index == 5, "Side-menu scenes remain outside the primary tabs")
	navigation_bar.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)
