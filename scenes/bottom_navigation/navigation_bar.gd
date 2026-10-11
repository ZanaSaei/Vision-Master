
extends Control
class_name VisionNavigationBar

signal item_selected(index: int)

const ITEM_COUNT: int = 6
const SELECTOR_SIZE: float = 84.0
const CUTOUT_RADIUS: float = 50.0
const NORMAL_ICON_TOUCH_RADIUS: float = 28.0
const ICON_CLEAR_FADE_DURATION: float = 0.72
const ICON_LIFT_DISTANCE: float = 14.0
const SELECTED_LABEL_DROP: float = 5.0

const MOVE_DURATION: float = 0.42
const TRAVEL_ARC_HEIGHT: float = 12.0
const ICON_FADE_OUT: float = 0.20
const ICON_FADE_IN: float = 0.28

const ITEM_NAMES: Array[String] = [
	"خانه",
	"کتاب ها",
	"بازی",
	"امتحان",
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

@export_range(0, 5, 1) var initial_index: int = 0

@export var navigation_color: Color = Color.WHITE
@export var selector_color: Color = Color.WHITE
@export var label_color: Color = Color("#30343B")

@onready var bar_background: ColorRect = $BarBackground
@onready var items: HBoxContainer = $MarginContainer/Items
@onready var selector: Control = $Selector
@onready var circle: Panel = $Selector/Circle
@onready var active_icon: TextureRect = $Selector/ActiveIcon

var current_index: int = 0
var is_initialized: bool = false
var normal_icons: Array[TextureRect] = []
var labels: Array[Label] = []
var label_rest_positions: Array[Vector2] = []
var label_tweens: Array[Tween] = []
var icon_visibility_tweens: Array[Tween] = []
var icon_is_clear: Array[bool] = []
var icon_rest_positions: Array[Vector2] = []

var selector_tween: Tween
var icon_tween: Tween
var scale_tween: Tween
var selector_start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Stay visible so the container lays out its children, but fully transparent
	# until every item, label, and the selector has been positioned correctly.
	modulate.a = 0.0
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_PASS

	bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.mouse_filter = Control.MOUSE_FILTER_PASS
	selector.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_configure_selector()
	_configure_items()

	resized.connect(_on_resized)

	# Wait for container layout to settle before saving the scene-authored positions.
	for _layout_frame in range(6):
		await get_tree().process_frame

	_refresh_layout()
	for _final_layout_frame in range(2):
		await get_tree().process_frame
	_capture_item_rest_positions()

	current_index = clampi(initial_index, 0, ITEM_COUNT - 1)
	_set_selector_position(current_index, false)
	_set_label_position(current_index, true)
	_set_initial_icon_visibility()
	_set_active_icon(current_index)
	_set_item_appearance(current_index, false)
	is_initialized = true
	_update_cutout_shader()
	_update_icons_covered_by_cutout()
	set_process(true)
	modulate.a = 1.0


func _process(_delta: float) -> void:
	_update_cutout_shader()
	_update_icons_covered_by_cutout()


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
	active_icon.offset_left = -15.0
	active_icon.offset_top = -15.0
	active_icon.offset_right = 15.0
	active_icon.offset_bottom = 15.0
	active_icon.size = Vector2(30.0, 30.0)
	active_icon.pivot_offset = active_icon.size * 0.5


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
		normal_icon.position = Vector2.ZERO

		label.add_theme_color_override("font_color", label_color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.size = Vector2(item.size.x, label.size.y)
		label.position = Vector2(0.0, 0.0)
		label.offset_left = 0.0
		label.offset_right = item.size.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		labels.append(label)
		label_rest_positions.append(Vector2.ZERO)
		label_tweens.append(null)

		item.gui_input.connect(_on_item_gui_input.bind(i))


func _on_item_gui_input(
	event: InputEvent,
	index: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_item(index)

	elif event is InputEventScreenTouch:
		if event.pressed:
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

	if index == current_index:
		return

	var previous_index: int = current_index
	current_index = index
	active_icon.visible = false
	_animate_label(previous_index, false)
	_animate_label(index, true)

	_animate_selector(index)

	item_selected.emit(index)


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
	_refresh_layout()

	if items.get_child_count() == ITEM_COUNT:
		_set_selector_position(current_index, false)
