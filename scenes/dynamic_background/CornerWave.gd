class_name CornerWave
extends Node2D

## A single wavy blob anchored to one screen corner. It bulges diagonally
## into the screen along a wavy edge, then straight lines back to the
## corner along the two screen edges (which is where the polygon's fill
## meets the corner exactly, no gaps).
##
## edge_points are authored in "canonical top-left space": the corner is
## treated as if it were the top-left corner, with the first point sitting
## on the TOP edge (x, 0) and the last point sitting on the LEFT edge
## (0, y). For other corners, the points are mirrored automatically.

enum CornerType { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

@export var corner: CornerType = CornerType.TOP_LEFT
@export var edge_points: Array[Vector2] = []
@export var top_color: Color = Color(0.06, 0.11, 0.4)
@export var mid_color: Color = Color(0.09, 0.14, 0.46)
@export var bottom_color: Color = Color(0.03, 0.05, 0.18)
@export var smooth_segments: int = 14

var rest_position: Vector2 = Vector2.ZERO
var enter_from: Vector2 = Vector2.ZERO

var _polygon: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()


func setup(p_corner: CornerType, p_edge_points: Array[Vector2], p_top_color: Color, p_bottom_color: Color, p_enter_from: Vector2) -> void:
	corner = p_corner
	edge_points = p_edge_points
	top_color = p_top_color
	bottom_color = p_bottom_color
	enter_from = p_enter_from
	rest_position = Vector2.ZERO
	position = enter_from
	rebuild()


func rebuild() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if edge_points.size() < 2:
		return

	var mirror_x: bool = corner == CornerType.TOP_RIGHT or corner == CornerType.BOTTOM_RIGHT
	var mirror_y: bool = corner == CornerType.BOTTOM_LEFT or corner == CornerType.BOTTOM_RIGHT

	var world_points: Array = []
	for p in edge_points:
		var x: float = (1.0 - p.x) if mirror_x else p.x
		var y: float = (1.0 - p.y) if mirror_y else p.y
		world_points.append(Vector2(x * vp.x, y * vp.y))

	var smoothed: PackedVector2Array = _smooth_curve(world_points, smooth_segments)

	# Determine the corner position
	var corner_x: float = vp.x if mirror_x else 0.0
	var corner_y: float = vp.y if mirror_y else 0.0
	var corner_point: Vector2 = Vector2(corner_x, corner_y)

	_polygon = PackedVector2Array()
	_colors = PackedColorArray()

	# Always start from the corner
	_polygon.append(corner_point)
	_colors.append(_gradient_color(clamp(corner_point.y / vp.y, 0.0, 1.0)))

	# Add the smoothed points
	for point in smoothed:
		# Clamp the points to keep them within the screen bounds
		var clamped_point: Vector2 = Vector2(
			clamp(point.x, 0.0, vp.x),
			clamp(point.y, 0.0, vp.y)
		)
		_polygon.append(clamped_point)
		_colors.append(_gradient_color(clamp(clamped_point.y / vp.y, 0.0, 1.0)))

	queue_redraw()


## 3-stop vertical gradient: top → mid (midpoint) → bottom.
func _gradient_color(t: float) -> Color:
	if t < 0.5:
		return top_color.lerp(mid_color, t * 2.0)
	return mid_color.lerp(bottom_color, (t - 0.5) * 2.0)


func _draw() -> void:
	if _polygon.size() >= 3:
		draw_polygon(_polygon, _colors)


static func _smooth_curve(points: Array, segments: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n: int = points.size()
	if n < 2:
		for p in points:
			result.append(p)
		return result
	for i in range(n - 1):
		var p0: Vector2 = points[max(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[min(i + 2, n - 1)]
		for s in range(segments):
			var t: float = float(s) / float(segments)
			result.append(_catmull_rom_point(p0, p1, p2, p3, t))
	result.append(points[n - 1])
	return result


static func _catmull_rom_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)
