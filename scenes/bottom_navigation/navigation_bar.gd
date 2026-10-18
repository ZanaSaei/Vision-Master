
extends Control
class_name VisionNavigationBar

signal item_selected(index: int)
signal menu_item_selected(menu_index: int)

const ITEM_COUNT: int = 6
const MENU_ITEM_COUNT: int = 4
const SELECTOR_SIZE: float = 84.0
const ACTIVE_ICON_SIZE: float = 44.0
const NORMAL_ICON_SIZE: float = 54.0
const CUTOUT_RADIUS: float = 50.0
const NORMAL_ICON_TOUCH_RADIUS: float = 38.0
const ICON_CLEAR_FADE_DURATION: float = 0.72
const ICON_LIFT_DISTANCE: float = 14.0
const SELECTED_LABEL_DROP: float = 5.0

const MOVE_DURATION: float = 0.42
const TRAVEL_ARC_HEIGHT: float = 12.0
const ICON_FADE_OUT: float = 0.20
const ICON_FADE_IN: float = 0.28

const MENU_PANEL_WIDTH: float = 66.0
const MENU_PANEL_HEIGHT: float = 224.0
const MENU_PANEL_BOTTOM_GAP: float = 46.0

const ITEM_NAMES: Array[String] = [
	"خانه",
	"کتاب",
	"بازی",
	"امتحان نهایی",
	"فلش کارت",
	"منو"
]

const NORMAL_ICONS: Array[Texture2D] = [
	preload("res://assets/images/ui/nav_bar/home.svg"),
	preload("res://assets/images/ui/nav_bar/book.svg"),
	preload("res://assets/images/ui/nav_bar/game.svg"),
	preload("res://assets/images/ui/nav_bar/exam.svg"),
	preload("res://assets/images/ui/nav_bar/flashcard.svg"),
	preload("res://assets/images/ui/nav_bar/menu.svg")
]

const ACTIVE_ICONS: Array[Texture2D] = [
	preload("res://assets/images/ui/nav_bar/home ac.svg"),
	preload("res://assets/images/ui/nav_bar/book ac.svg"),
	preload("res://assets/images/ui/nav_bar/game ac.svg"),
	preload("res://assets/images/ui/nav_bar/exam ac.svg"),
	preload("res://assets/images/ui/nav_bar/flashcard ac.svg"),
	preload("res://assets/images/ui/nav_bar/menu ac.svg")
]

const MENU_SUB_ICONS: Array[Texture2D] = [
	preload("res://assets/images/ui/nav_bar/profile.svg"),
	preload("res://assets/images/ui/nav_bar/buy.svg"),
	preload("res://assets/images/ui/nav_bar/settings.svg"),
	preload("res://assets/images/ui/nav_bar/about me.svg")
]

const ITEM_SCENES: Array[String] = [
	"res://scenes/main_menu/MainMenu.tscn",
	"res://scenes/book_menu/BookSelection.tscn",
	"res://scenes/word_game/WordGameHub.tscn",
	"res://scenes/exam/FinalExams.tscn",
	"res://scenes/vocabulary/FlashcardHub.tscn",
	""
]

const MENU_SUB_SCENES: Array[String] = [
	"res://scenes/auth/Auth.tscn",
	"res://scenes/purchase/Purchase.tscn",
	"res://scenes/settings/Settings.tscn",
	"res://scenes/about_me/AboutMe.tscn"
]

# Scenes that display the persistent bottom bar. This single bar is owned by
# the BottomNavigation autoload; scenes no longer carry their own copy, so it
# stays perfectly still and smooth while the screens change beneath it.
const BAR_SCENES: Array[String] = [
	"res://scenes/main_menu/MainMenu.tscn",
	"res://scenes/book_menu/BookSelection.tscn",
	"res://scenes/lesson_menu/LessonMenu.tscn",
	"res://scenes/word_game/WordGameHub.tscn",
	"res://scenes/word_game/WordGameLearning.tscn",
	"res://scenes/word_game/DailyWordGame.tscn",
	"res://scenes/word_game/OfficialChallengeGame.tscn",
	"res://scenes/word_game/ChallengeLeaderboard.tscn",
	"res://scenes/exam/FinalExams.tscn",
	"res://scenes/exam/FinalExamList.tscn",
	"res://scenes/vocabulary/FlashcardHub.tscn",
	"res://scenes/saved_words/SavedWords.tscn",
	"res://scenes/auth/Auth.tscn",
	"res://scenes/purchase/Purchase.tscn",
	"res://scenes/settings/Settings.tscn",
	"res://scenes/about_me/AboutMe.tscn"
]

@export_range(0, 5, 1) var initial_index: int = 0
@export var auto_navigate: bool = true

@export var navigation_color: Color = Color.WHITE
@export var selector_color: Color = Color.WHITE
@export var label_color: Color = Color("#30343B")

@onready var bar_background: ColorRect = $BarBackground
@onready var items: HBoxContainer = $MarginContainer/Items
@onready var selector: Control = $Selector
@onready var circle: Panel = $Selector/Circle
@onready var active_icon: TextureRect = $Selector/ActiveIcon
@onready var menu_panel: Panel = get_node_or_null("MenuPanel") as Panel
@onready var menu_items_container: VBoxContainer = get_node_or_null("MenuPanel/MenuItems") as VBoxContainer

var current_index: int = 0
static var _last_primary_index: int = 0
var is_initialized: bool = false
var menu_panel_open: bool = false
var _is_navigating: bool = false
var normal_icons: Array[TextureRect] = []
var labels: Array[Label] = []
var label_rest_positions: Array[Vector2] = []
var label_tweens: Array[Tween] = []
var icon_visibility_tweens: Array[Tween] = []
var icon_is_clear: Array[bool] = []
var icon_rest_positions: Array[Vector2] = []
var menu_sub_items: Array[Control] = []
var menu_item_highlights: Array[Panel] = []
var active_menu_index: int = -1

var selector_tween: Tween
var icon_tween: Tween
var scale_tween: Tween
var menu_panel_tween: Tween
var selector_start_position: Vector2 = Vector2.ZERO

# Scene path requested before _ready() finished laying the bar out.
var _pending_scene_path: String = ""


func _ready() -> void:
	# Persistent chrome: this bar is built ONCE by the BottomNavigation autoload
	# and lives for the whole session. It is never re-instantiated on a scene
	# swap, so it cannot flicker, re-layout, or teleport its selector when the
	# screens change under it.
	if not is_in_group("bottom_navigation"):
		add_to_group("bottom_navigation")

	# Transparent until laid out, but still "visible" so the containers size
	# their children correctly (hiding a Control freezes its layout pass, which
	# would make the item rest positions capture as zero).
	modulate.a = 0.0
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_PASS

	bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.mouse_filter = Control.MOUSE_FILTER_PASS
	selector.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_configure_selector()
	_configure_items()
	_configure_menu_panel()

	resized.connect(_on_resized)

	# Wait for container layout to settle before saving the authored positions.
	await get_tree().process_frame
	if not is_inside_tree():
		return

	move_to_front()
	_refresh_layout()
	await get_tree().process_frame
	if not is_inside_tree():
		return

	_capture_item_rest_positions()

	current_index = clampi(initial_index, 0, ITEM_COUNT - 2)
	_last_primary_index = current_index
	_set_selector_position(current_index, false)
	_position_menu_panel()
	_set_label_position(current_index, true)
	_set_initial_icon_visibility()
	_set_active_icon(current_index)
	_set_item_appearance(current_index, false)
	is_initialized = true
	_update_cutout_shader()
	_update_icons_covered_by_cutout()
	modulate.a = 1.0

	# A scene may have been announced while we were still laying out.
	if _pending_scene_path != "":
		var pending_path: String = _pending_scene_path
		_pending_scene_path = ""
		apply_scene_path(pending_path)


## Called by the BottomNavigation autoload whenever the current scene changes.
## Shows/hides the bar and animates the selector to the tab that owns the new
## scene. Safe to call before _ready() has finished: the request is parked.
func apply_scene_path(scene_path: String) -> void:
	if not is_initialized:
		_pending_scene_path = scene_path
		return

	var show_bar: bool = BAR_SCENES.has(scene_path)
	visible = show_bar
	set_process(show_bar)
	_set_menu_panel_open(false, false)

	if not show_bar:
		return

	var detected_menu_index: int = _detect_menu_scene_index(scene_path)
	if detected_menu_index >= 0:
		# Menu destinations use a direct scene swap rather than the tab
		# transition manager, so unlock navigation once their scene is active.
		_is_navigating = false

	var detected_index: int = _detect_scene_index(scene_path)
	if detected_index >= 0 and detected_index < ITEM_COUNT - 1:
		_set_primary_index(detected_index, true)
	elif detected_menu_index >= 0:
		# Menu destinations select the Menu tab itself; remember the last primary
		# tab separately so returning to the app tabs does not lose its selection.
		_set_primary_index(ITEM_COUNT - 1, true)

	_set_active_menu_destination(detected_menu_index)


## Moves the selector to a navigation item. Only primary tabs update the saved
## primary selection; the Menu tab can be selected for side-menu destinations.
func _set_primary_index(index: int, animate: bool) -> void:
	index = clampi(index, 0, ITEM_COUNT - 1)
	if index < ITEM_COUNT - 1:
		_last_primary_index = index
	if index == current_index:
		return
	if not is_initialized:
		current_index = index
		return

	var previous_index: int = current_index
	current_index = index
	active_icon.visible = false

	if animate:
		_animate_label(previous_index, false)
		_animate_label(index, true)
		_animate_selector(index)
	else:
		_set_label_position(previous_index, false)
		_set_label_position(index, true)
		_set_selector_position(index, false)
		_set_active_icon(index)
		_set_initial_icon_visibility()

	_set_item_appearance(index, false)


func _detect_scene_index(scene_path: String) -> int:
	if scene_path == "":
		return -1
	if scene_path.ends_with("MainMenu.tscn"):
		return 0
	if (
		scene_path.ends_with("BookSelection.tscn")
		or scene_path.ends_with("BookMenu.tscn")
		or scene_path.ends_with("BookMenu_backup.tscn")
		or scene_path.ends_with("LessonMenu.tscn")
	):
		return 1
	if scene_path.contains("/word_game/"):
		return 2
	if scene_path.contains("/exam/"):
		return 3
	if (
		scene_path.ends_with("FlashcardHub.tscn")
		or scene_path.ends_with("SavedWords.tscn")
		or scene_path.ends_with("WordReview.tscn")
	):
		return 4
	if (
		scene_path.ends_with("Auth.tscn")
		or scene_path.ends_with("Purchase.tscn")
		or scene_path.ends_with("Settings.tscn")
		or scene_path.ends_with("AboutMe.tscn")
	):
		return 5
	return -1


func _detect_menu_scene_index(scene_path: String) -> int:
	return MENU_SUB_SCENES.find(scene_path)


func _set_active_menu_destination(menu_index: int) -> void:
	active_menu_index = menu_index
	for index: int in range(menu_item_highlights.size()):
		var highlight: Panel = menu_item_highlights[index]
		highlight.visible = index == active_menu_index


func _current_scene_path() -> String:
	if not is_inside_tree():
		return ""
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene != self and current_scene.scene_file_path != "":
		return current_scene.scene_file_path
	if owner != null and owner != self and owner.scene_file_path != "":
		return owner.scene_file_path
	var p: Node = get_parent()
	if p != null and p.scene_file_path != "":
		return p.scene_file_path
	return ""


func _process(_delta: float) -> void:
	_update_cutout_shader()
	_update_icons_covered_by_cutout()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not menu_panel_open or menu_panel == null or not menu_panel.visible:
		return

	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed = true
			pos = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			pressed = true
			pos = event.position

	if not pressed:
		return

	for sub_idx: int in range(menu_sub_items.size()):
		var sub_item: Control = menu_sub_items[sub_idx]
		if sub_item.get_global_rect().has_point(pos):
			get_viewport().set_input_as_handled()
			_on_menu_sub_item_activated(sub_idx)
			return

	if menu_panel.get_global_rect().has_point(pos):
		get_viewport().set_input_as_handled()
		return

	if items.get_child_count() == ITEM_COUNT:
		var menu_btn: Control = items.get_child(ITEM_COUNT - 1) as Control
		if menu_btn != null and menu_btn.get_global_rect().has_point(pos):
			return

	_set_menu_panel_open(false, true)


func _update_icons_covered_by_cutout() -> void:
	if normal_icons.size() != ITEM_COUNT or not is_initialized:
		return
	if not is_node_ready() or not visible:
		return
	var cutout_center_global: Vector2 = (
		bar_background.get_global_transform()
		* Vector2(
			selector.position.x + selector.pivot_offset.x,
			0.0
		)
	)
	for i in range(ITEM_COUNT):
		var normal_icon: TextureRect = normal_icons[i]
		var icon_center_global: Vector2 = (
			normal_icon.get_global_transform()
			* (normal_icon.size * 0.5)
		)
		var distance_to_cutout: float = cutout_center_global.distance_to(
			icon_center_global
		)
		var is_tapped_icon: bool = i == current_index
		var cutout_touches_icon: bool = (
			distance_to_cutout <= CUTOUT_RADIUS + NORMAL_ICON_TOUCH_RADIUS
		)
		if is_tapped_icon:
			if not icon_is_clear[i]:
				_set_icon_clear_state(i, true, true)
		elif cutout_touches_icon:
			if not icon_is_clear[i]:
				_set_icon_clear_state(i, true, false)
		elif icon_is_clear[i]:
			_set_icon_clear_state(i, false, false)


func _set_initial_icon_clear_state(index: int, should_lift: bool) -> void:
	var icon: TextureRect = normal_icons[index]
	icon_is_clear[index] = true
	icon.modulate.a = 0.0
	icon.visible = false
	if should_lift:
		icon.position = icon_rest_positions[index] + Vector2.UP * ICON_LIFT_DISTANCE


func _set_icon_clear_state(
	index: int,
	should_clear: bool,
	should_lift: bool
) -> void:
	var icon: TextureRect = normal_icons[index]
	var target_alpha: float = 0.0 if should_clear else 1.0
	var rest_position: Vector2 = icon_rest_positions[index]
	var target_position: Vector2 = rest_position
	if should_lift:
		target_position += Vector2.UP * ICON_LIFT_DISTANCE

	if (
		icon_is_clear[index] == should_clear
		and icon.modulate.a == target_alpha
		and icon.position.is_equal_approx(target_position)
	):
		return

	icon_is_clear[index] = should_clear
	var previous_tween: Tween = icon_visibility_tweens[index]
	if previous_tween and previous_tween.is_running():
		previous_tween.kill()

	icon.visible = true
	icon_visibility_tweens[index] = create_tween()
	icon_visibility_tweens[index].set_trans(Tween.TRANS_CUBIC)
	icon_visibility_tweens[index].set_ease(Tween.EASE_OUT)
	icon_visibility_tweens[index].tween_property(
		icon,
		"modulate:a",
		target_alpha,
		ICON_CLEAR_FADE_DURATION
	)
	icon_visibility_tweens[index].parallel().tween_property(
		icon,
		"position",
		target_position,
		ICON_CLEAR_FADE_DURATION
	)
	if should_clear:
		icon_visibility_tweens[index].tween_callback(
			func() -> void:
				if icon_is_clear[index]:
					icon.visible = false
		)
	else:
		icon_visibility_tweens[index].tween_callback(
			func() -> void:
				if not icon_is_clear[index]:
					icon.visible = true
		)


func _update_cutout_shader() -> void:
	var shader_material := bar_background.material as ShaderMaterial
	if shader_material == null:
		return

	var selector_center_global: Vector2 = (
		selector.get_global_transform() * selector.pivot_offset
	)
	var bar_top_global: Vector2 = get_global_transform() * Vector2.ZERO
	var cutout_center_in_background: Vector2 = (
		bar_background.get_global_transform().affine_inverse()
		* Vector2(selector_center_global.x, bar_top_global.y)
	)
	shader_material.set_shader_parameter(
		"cutout_center",
		cutout_center_in_background
	)
	# Keep the shader cutout steady while only the white selector disc animates.
	shader_material.set_shader_parameter("cutout_radius", CUTOUT_RADIUS)
	shader_material.set_shader_parameter("bar_size", bar_background.size)


func _configure_selector() -> void:
	selector.set_anchors_preset(Control.PRESET_TOP_LEFT)
	selector.size = Vector2(SELECTOR_SIZE, SELECTOR_SIZE)
	selector.pivot_offset = Vector2(
		SELECTOR_SIZE * 0.5,
		SELECTOR_SIZE * 0.5
	)

	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.anchor_left = 0.5
	circle.anchor_top = 0.5
	circle.anchor_right = 0.5
	circle.anchor_bottom = 0.5
	circle.offset_left = -(SELECTOR_SIZE - 18.0) * 0.5
	circle.offset_top = -(SELECTOR_SIZE - 18.0) * 0.5
	circle.offset_right = (SELECTOR_SIZE - 18.0) * 0.5
	circle.offset_bottom = (SELECTOR_SIZE - 18.0) * 0.5
	circle.size = Vector2(SELECTOR_SIZE - 18.0, SELECTOR_SIZE - 18.0)
	circle.pivot_offset = circle.size * 0.5

	# Plain white disc: no border, no inner line, no shadow.
	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = Color.WHITE
	# Explicitly override every outline/shadow property; StyleBoxFlat defaults
	# carry a gray border color that can show as a dark rim with antialiasing.
	circle_style.set_corner_radius_all(999)
	circle_style.set_border_width_all(0)
	circle_style.border_color = Color.WHITE
	circle_style.shadow_color = Color(1.0, 1.0, 1.0, 0.0)
	circle_style.shadow_size = 0

	circle.add_theme_stylebox_override("panel", circle_style)

	active_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_icon.anchor_left = 0.5
	active_icon.anchor_top = 0.5
	active_icon.anchor_right = 0.5
	active_icon.anchor_bottom = 0.5
	active_icon.offset_left = -ACTIVE_ICON_SIZE * 0.5
	active_icon.offset_top = -ACTIVE_ICON_SIZE * 0.5
	active_icon.offset_right = ACTIVE_ICON_SIZE * 0.5
	active_icon.offset_bottom = ACTIVE_ICON_SIZE * 0.5
	active_icon.size = Vector2(ACTIVE_ICON_SIZE, ACTIVE_ICON_SIZE)
	active_icon.pivot_offset = active_icon.size * 0.5


func _configure_menu_panel() -> void:
	if menu_panel == null or menu_items_container == null:
		return

	menu_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_panel.size = Vector2(MENU_PANEL_WIDTH, MENU_PANEL_HEIGHT)
	menu_panel.pivot_offset = Vector2(MENU_PANEL_WIDTH * 0.5, MENU_PANEL_HEIGHT)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE
	panel_style.set_corner_radius_all(33)
	panel_style.set_border_width_all(0)
	panel_style.border_color = Color.WHITE
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.14)
	panel_style.shadow_size = 14
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	menu_panel.add_theme_stylebox_override("panel", panel_style)

	menu_sub_items.clear()
	menu_item_highlights.clear()
	var count: int = mini(menu_items_container.get_child_count(), MENU_ITEM_COUNT)
	for i: int in range(count):
		var sub_item := menu_items_container.get_child(i) as Control
		if sub_item == null:
			continue
		sub_item.mouse_filter = Control.MOUSE_FILTER_STOP
		sub_item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var highlight: Panel = Panel.new()
		highlight.name = "ActiveHighlight"
		highlight.set_anchors_preset(Control.PRESET_CENTER)
		highlight.offset_left = -20.0
		highlight.offset_top = -20.0
		highlight.offset_right = 20.0
		highlight.offset_bottom = 20.0
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.visible = false
		var highlight_style: StyleBoxFlat = StyleBoxFlat.new()
		highlight_style.bg_color = Color("#E7F2FF")
		highlight_style.set_corner_radius_all(14)
		highlight_style.set_border_width_all(0)
		highlight.add_theme_stylebox_override("panel", highlight_style)
		sub_item.add_child(highlight)
		sub_item.move_child(highlight, 0)
		menu_item_highlights.append(highlight)

		var icon_node := sub_item.get_node_or_null("Icon") as TextureRect
		if icon_node != null:
			icon_node.texture = MENU_SUB_ICONS[i]
			icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not sub_item.gui_input.is_connected(_on_menu_sub_item_gui_input):
			sub_item.gui_input.connect(_on_menu_sub_item_gui_input.bind(i))
		menu_sub_items.append(sub_item)

	_set_active_menu_destination(active_menu_index)
	menu_panel_open = false
	menu_panel.visible = false
	menu_panel.modulate.a = 0.0


func _get_menu_panel_position() -> Vector2:
	if items.get_child_count() < ITEM_COUNT:
		return Vector2(size.x - MENU_PANEL_WIDTH - 16.0, -MENU_PANEL_HEIGHT - MENU_PANEL_BOTTOM_GAP)
	var menu_item := items.get_child(ITEM_COUNT - 1) as Control
	var item_center_global: Vector2 = (
		menu_item.get_global_transform() * (menu_item.size * 0.5)
	)
	var item_center_local: Vector2 = (
		get_global_transform().affine_inverse() * item_center_global
	)
	return Vector2(
		item_center_local.x - MENU_PANEL_WIDTH * 0.5,
		-MENU_PANEL_HEIGHT - MENU_PANEL_BOTTOM_GAP
	)


func _position_menu_panel() -> void:
	if menu_panel == null:
		return
	menu_panel.position = _get_menu_panel_position()


func _set_menu_panel_open(open: bool, animate: bool) -> void:
	if menu_panel == null:
		return
	menu_panel_open = open
	var target_pos: Vector2 = _get_menu_panel_position()

	if menu_panel_tween and menu_panel_tween.is_running():
		menu_panel_tween.kill()

	menu_panel.pivot_offset = Vector2(MENU_PANEL_WIDTH * 0.5, MENU_PANEL_HEIGHT)

	if not animate:
		menu_panel.visible = open
		menu_panel.position = target_pos
		menu_panel.scale = Vector2.ONE if open else Vector2(0.85, 0.85)
		menu_panel.modulate.a = 1.0 if open else 0.0
		return

	if open:
		menu_panel.visible = true
		menu_panel.position = target_pos + Vector2(0.0, 16.0)
		menu_panel.scale = Vector2(0.85, 0.85)
		menu_panel.modulate.a = 0.0

		menu_panel_tween = create_tween().set_parallel(true)
		menu_panel_tween.set_trans(Tween.TRANS_BACK)
		menu_panel_tween.set_ease(Tween.EASE_OUT)
		menu_panel_tween.tween_property(menu_panel, "position", target_pos, 0.24)
		menu_panel_tween.tween_property(menu_panel, "scale", Vector2.ONE, 0.24)
		menu_panel_tween.tween_property(menu_panel, "modulate:a", 1.0, 0.18)
	else:
		menu_panel_tween = create_tween().set_parallel(true)
		menu_panel_tween.set_trans(Tween.TRANS_CUBIC)
		menu_panel_tween.set_ease(Tween.EASE_IN)
		menu_panel_tween.tween_property(
			menu_panel,
			"position",
			target_pos + Vector2(0.0, 12.0),
			0.16
		)
		menu_panel_tween.tween_property(
			menu_panel,
			"scale",
			Vector2(0.85, 0.85),
			0.16
		)
		menu_panel_tween.tween_property(menu_panel, "modulate:a", 0.0, 0.16)
		menu_panel_tween.chain().tween_callback(
			func() -> void:
				if not menu_panel_open and menu_panel != null:
					menu_panel.visible = false
		)


func _on_menu_sub_item_gui_input(event: InputEvent, sub_index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			_on_menu_sub_item_activated(sub_index)
	elif event is InputEventScreenTouch:
		if event.pressed:
			accept_event()
			_on_menu_sub_item_activated(sub_index)


func _on_menu_sub_item_activated(sub_index: int) -> void:
	if sub_index < 0 or sub_index >= MENU_SUB_SCENES.size():
		return
	_set_menu_panel_open(false, true)
	menu_item_selected.emit(sub_index)
	if not auto_navigate:
		return
	var target_scene: String = MENU_SUB_SCENES[sub_index]
	_navigate_to_scene(target_scene, TransitionManager.Slide.FORWARD)


func _configure_items() -> void:
	items.add_theme_constant_override("separation", 0)

	if items.get_child_count() != ITEM_COUNT:
		push_error(
			"NavigationBar requires exactly six children under Items."
		)
		return

	normal_icons.clear()
	labels.clear()
	label_rest_positions.clear()
	label_tweens.clear()
	icon_visibility_tweens.clear()
	icon_is_clear.clear()
	icon_rest_positions.clear()

	for i in range(ITEM_COUNT):
		var item := items.get_child(i) as Control

		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_vertical = Control.SIZE_EXPAND_FILL
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var normal_icon := item.get_node("ActiveIcon") as TextureRect
		var label := item.get_node("Label") as Label

		normal_icon.texture = NORMAL_ICONS[i]
		normal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		normal_icon.visible = true
		normal_icon.modulate.a = 1.0
		normal_icons.append(normal_icon)
		icon_visibility_tweens.append(null)
		icon_is_clear.append(false)
		icon_rest_positions.append(Vector2.ZERO)
		normal_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
		normal_icon.custom_minimum_size = Vector2(NORMAL_ICON_SIZE, NORMAL_ICON_SIZE)
		normal_icon.size = Vector2(NORMAL_ICON_SIZE, NORMAL_ICON_SIZE)
		normal_icon.position = Vector2.ZERO

		label.add_theme_color_override("font_color", label_color)
		label.add_theme_font_size_override("font_size", 22)
		if label.label_settings != null:
			label.label_settings.font_color = label_color
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.size = Vector2(item.size.x, 30.0)
		label.position = Vector2(0.0, 0.0)
		label.offset_left = 0.0
		label.offset_right = item.size.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		labels.append(label)
		label_rest_positions.append(Vector2.ZERO)
		label_tweens.append(null)

		if not item.gui_input.is_connected(_on_item_gui_input):
			item.gui_input.connect(_on_item_gui_input.bind(i))


func _on_item_gui_input(
	event: InputEvent,
	index: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			select_item(index)

	elif event is InputEventScreenTouch:
		if event.pressed:
			accept_event()
			select_item(index)


func _capture_item_rest_positions() -> void:
	for index in range(ITEM_COUNT):
		var item: Control = items.get_child(index)
		var icon: TextureRect = normal_icons[index]
		var label: Label = labels[index]
		icon_rest_positions[index] = Vector2(
			(item.size.x - icon.size.x) * 0.5,
			0.0
		)
		label_rest_positions[index] = Vector2(
			(item.size.x - label.size.x) * 0.5,
			item.size.y - label.size.y - 5.0
		)
		icon.position = icon_rest_positions[index]
		label.position = label_rest_positions[index]


func _set_initial_icon_visibility() -> void:
	for index in range(ITEM_COUNT):
		var icon: TextureRect = normal_icons[index]
		var is_selected: bool = index == current_index
		icon_is_clear[index] = is_selected
		icon.modulate.a = 1.0
		icon.visible = not is_selected
		icon.position = icon_rest_positions[index]


func _set_label_position(index: int, selected: bool) -> void:
	var label: Label = labels[index]
	label.position = label_rest_positions[index]
	if selected:
		label.position.y += SELECTED_LABEL_DROP


func _animate_label(index: int, selected: bool) -> void:
	var label: Label = labels[index]
	var previous_tween: Tween = label_tweens[index]
	if previous_tween and previous_tween.is_running():
		previous_tween.kill()

	var target_position: Vector2 = label_rest_positions[index]
	if selected:
		target_position.y += SELECTED_LABEL_DROP

	label_tweens[index] = create_tween()
	label_tweens[index].set_trans(Tween.TRANS_CUBIC)
	label_tweens[index].set_ease(Tween.EASE_OUT)
	label_tweens[index].tween_property(
		label,
		"position",
		target_position,
		MOVE_DURATION
	)


func select_item(index: int) -> void:
	if index < 0 or index >= ITEM_COUNT:
		return
	if not visible or _is_navigating:
		return

	# "منو" toggles the popup without becoming a selected destination.
	if index == ITEM_COUNT - 1:
		_set_menu_panel_open(not menu_panel_open, true)
		item_selected.emit(index)
		return

	# Any other item (0..4) closes the menu popup panel if it was open.
	if menu_panel_open:
		_set_menu_panel_open(false, true)

	if index == current_index:
		if auto_navigate and index < ITEM_SCENES.size() and ITEM_SCENES[index] != "":
			_navigate_to_scene(
				ITEM_SCENES[index],
				TransitionManager.Slide.BACK
			)
		return

	var previous_index: int = current_index
	current_index = index
	_last_primary_index = index
	active_icon.visible = false
	_animate_label(previous_index, false)
	_animate_label(index, true)

	_animate_selector(index)

	item_selected.emit(index)

	if auto_navigate and index < ITEM_SCENES.size() and ITEM_SCENES[index] != "":
		_navigate_to_scene(
			ITEM_SCENES[index],
			TransitionManager.Slide.FORWARD
			if index > previous_index
			else TransitionManager.Slide.BACK
		)


func _navigate_to_scene(
	target_scene: String,
	tab_direction: int = TransitionManager.Slide.FORWARD
) -> void:
	if target_scene == "" or _is_navigating:
		return
	var current_path: String = _current_scene_path()
	if current_path == target_scene:
		return

	_is_navigating = true
	Sfx.click()

	# Side-menu destinations are layered screens rather than peer tabs. Route
	# those directly; only primary tabs use a quick horizontal push.
	if _target_primary_index(target_scene) >= ITEM_SCENES.size() - 1:
		var error_code: int = get_tree().change_scene_to_file(target_scene)
		if error_code != OK:
			_is_navigating = false
			push_error(
				"NavigationBar: couldn't open '%s' (%s)."
				% [target_scene, error_string(error_code)]
			)
		return

	if TransitionManager._tab_change_busy or TransitionManager._fade_busy or TransitionManager._slide_busy:
		_is_navigating = false
		return

	if not is_in_group("bottom_navigation"):
		add_to_group("bottom_navigation")
	_is_navigating = true
	TransitionManager.tab_change_scene(target_scene, tab_direction)


func set_navigation_busy(busy: bool) -> void:
	_is_navigating = busy


func _target_primary_index(target_scene: String) -> int:
	for index: int in range(ITEM_SCENES.size() - 1):
		if ITEM_SCENES[index] == target_scene:
			return index
	return ITEM_SCENES.size() - 1


func _animate_selector(index: int) -> void:
	if selector_tween and selector_tween.is_running():
		selector_tween.kill()

	if scale_tween and scale_tween.is_running():
		scale_tween.kill()

	selector_start_position = selector.position
	var target_position: Vector2 = _get_selector_position(index)
	var travel_distance: float = absf(target_position.x - selector_start_position.x)
	var arc_height: float = minf(TRAVEL_ARC_HEIGHT, travel_distance * 0.08)

	selector_tween = create_tween()
	selector_tween.set_trans(Tween.TRANS_CUBIC)
	selector_tween.set_ease(Tween.EASE_IN_OUT)
	selector_tween.tween_method(
		_update_selector_travel.bind(target_position, arc_height),
		0.0,
		1.0,
		MOVE_DURATION
	)
	selector_tween.tween_callback(_on_selector_arrived.bind(index))

	# Squash the circle only; keep the active icon and selector transform steady.
	circle.scale = Vector2.ONE
	scale_tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_CUBIC)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(
		circle,
		"scale",
		Vector2(1.12, 0.90),
		MOVE_DURATION * 0.32
	)
	scale_tween.tween_property(
		circle,
		"scale",
		Vector2(0.94, 1.08),
		MOVE_DURATION * 0.24
	)
	scale_tween.tween_property(
		circle,
		"scale",
		Vector2.ONE,
		MOVE_DURATION * 0.44
	)


func _update_selector_travel(
	progress: float,
	target_position: Vector2,
	arc_height: float
) -> void:
	var travel_position: Vector2 = selector_start_position.lerp(
		target_position,
		progress
	)
	travel_position.y -= sin(progress * PI) * arc_height
	selector.position = travel_position


func _on_selector_arrived(index: int) -> void:
	_animate_active_icon(index)
	_set_item_appearance(index, true)


func _animate_active_icon(index: int) -> void:
	if icon_tween and icon_tween.is_running():
		icon_tween.kill()

	active_icon.texture = ACTIVE_ICONS[index]
	active_icon.modulate.a = 0.0
	active_icon.visible = true

	icon_tween = create_tween()
	icon_tween.set_trans(Tween.TRANS_CUBIC)
	icon_tween.set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(
		active_icon,
		"modulate:a",
		1.0,
		ICON_FADE_IN
	)


func _set_active_icon(index: int) -> void:
	active_icon.texture = ACTIVE_ICONS[index]
	active_icon.modulate = Color.WHITE


func _set_item_appearance(
	_selected_index: int,
	_animate: bool
) -> void:
	for normal_icon: TextureRect in normal_icons:
		normal_icon.modulate.a = 1.0


func _get_selector_position(index: int) -> Vector2:
	var item := items.get_child(index) as Control
	var item_center_global: Vector2 = (
		item.get_global_transform() * (item.size * 0.5)
	)
	var selector_parent: Control = selector.get_parent_control()
	var item_center_in_selector_parent: Vector2 = (
		selector_parent.get_global_transform().affine_inverse()
		* item_center_global
	)

	# Center horizontally on the item slot, and pin the vertical center to the
	# top edge of the navigation bar (y = 0 in the selector's own parent space),
	# so the disc straddles the bar and sits in a semicircular notch.
	return Vector2(
		item_center_in_selector_parent.x - selector.pivot_offset.x,
		-selector.pivot_offset.y
	)


func _set_selector_position(
	index: int,
	animate: bool
) -> void:
	var target_position := _get_selector_position(index)

	if animate:
		_animate_selector(index)
	else:
		selector.position = target_position
		selector.scale = Vector2.ONE
		circle.scale = Vector2.ONE


func _refresh_layout() -> void:
	bar_background.color = navigation_color

	var background_shader_material := bar_background.material as ShaderMaterial

	if background_shader_material:
		background_shader_material.set_shader_parameter("bar_color", navigation_color)
		background_shader_material.set_shader_parameter("bar_size", bar_background.size)

	var style := circle.get_theme_stylebox("panel") as StyleBoxFlat

	if style:
		var updated_style := style.duplicate() as StyleBoxFlat
		updated_style.bg_color = Color.WHITE
		updated_style.set_border_width_all(0)
		updated_style.border_color = Color.WHITE
		updated_style.shadow_color = Color(1.0, 1.0, 1.0, 0.0)
		updated_style.shadow_size = 0
		circle.add_theme_stylebox_override("panel", updated_style)


func _on_resized() -> void:
	call_deferred("_refresh_after_resize")


func _refresh_after_resize() -> void:
	if not is_inside_tree():
		return
	_refresh_layout()

	if items.get_child_count() == ITEM_COUNT and normal_icons.size() == ITEM_COUNT:
		_capture_item_rest_positions()
		_set_label_position(current_index, true)
		_set_initial_icon_visibility()
		_set_selector_position(current_index, false)
		_position_menu_panel()
