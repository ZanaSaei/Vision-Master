# ============================================================
# ExerciseEngine - HotspotOverlay (was an inner class of
# ExerciseEngine). Draws clickable hotspot polygons over an
# image and reports selection. Part of the split module.
# ============================================================
class_name ExerciseHotspotOverlay
extends Control

signal hotspot_changed(selected_ids: Array)

var hotspots: Array = []
var selected: Array = []
var multi := true
var base_size := Vector2(1, 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var norm := Vector2(
			event.position.x / maxf(size.x, 1.0),
			event.position.y / maxf(size.y, 1.0)
		)
		var hit := ""
		for i in hotspots.size():
			if _hotspot_contains(hotspots[i], norm):
				hit = _hotspot_id(hotspots[i], i)
				break
		if hit != "":
			if multi:
				if selected.has(hit):
					selected.erase(hit)
				else:
					selected.append(hit)
			else:
				if selected.size() == 1 and selected[0] == hit:
					selected.clear()
				else:
					selected = [hit]
			queue_redraw()
			hotspot_changed.emit(selected.duplicate())
			accept_event()

func _draw() -> void:
	for i in hotspots.size():
		var hs: Dictionary = hotspots[i]
		var id := _hotspot_id(hs, i)
		var is_sel := selected.has(id)
		var col := Color(str(hs.get("color", "#2563EB")))
		var fill_alpha := 0.45 if is_sel else 0.18
		var fill := Color(col.r, col.g, col.b, fill_alpha)
		var line := Color(col.r, col.g, col.b, 0.9)
		var poly := _scaled_polygon(hs)
		if poly.size() >= 3:
			draw_colored_polygon(poly, fill)
			draw_polyline(poly, line, 3.0, true)
		var label := str(hs.get("label", id))
		if label != "":
			var center := _polygon_center(poly)
			draw_string(
				ThemeDB.fallback_font,
				center,
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				18,
				Color(0.1, 0.1, 0.1, 0.9)
			)

func _hotspot_id(hs: Dictionary, index: int) -> String:
	return str(hs.get("id", "hotspot_%d" % index))

func _hotspot_contains(hs: Dictionary, norm_pos: Vector2) -> bool:
	if hs.has("polygon"):
		var poly := _normalized_polygon(hs)
		return Geometry2D.is_point_in_polygon(norm_pos, poly)
	if hs.has("rect"):
		var rect := _normalized_rect(hs["rect"])
		return rect.has_point(norm_pos)
	return false

func _scaled_polygon(hs: Dictionary) -> PackedVector2Array:
	var poly := _normalized_polygon(hs)
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(p.x * size.x, p.y * size.y))
	if out.size() < 3 and hs.has("rect"):
		var r := _normalized_rect(hs["rect"])
		var p0 := Vector2(r.position.x * size.x, r.position.y * size.y)
		var p1 := Vector2(r.end.x * size.x, r.position.y * size.y)
		var p2 := Vector2(r.end.x * size.x, r.end.y * size.y)
		var p3 := Vector2(r.position.x * size.x, r.end.y * size.y)
		out = PackedVector2Array()
		out.append(p0)
		out.append(p1)
		out.append(p2)
		out.append(p3)
	return out

func _normalized_polygon(hs: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if hs.has("polygon"):
		for p in hs["polygon"]:
			if p is Array and p.size() >= 2:
				var v := Vector2(float(p[0]), float(p[1]))
				if _is_pixel(v):
					v = Vector2(
						v.x / maxf(base_size.x, 1.0),
						v.y / maxf(base_size.y, 1.0)
					)
				out.append(v)
	elif hs.has("rect"):
		var r := _normalized_rect(hs["rect"])
		out.append(r.position)
		out.append(Vector2(r.end.x, r.position.y))
		out.append(r.end)
		out.append(Vector2(r.position.x, r.end.y))
	return out

func _normalized_rect(rect: Variant) -> Rect2:
	if rect is Array and rect.size() >= 4:
		var r := Rect2(
			float(rect[0]),
			float(rect[1]),
			float(rect[2]),
			float(rect[3])
		)
		if _is_pixel(Vector2(r.position.x, r.position.y)) or _is_pixel(r.size):
			r.position.x /= maxf(base_size.x, 1.0)
			r.position.y /= maxf(base_size.y, 1.0)
			r.size.x /= maxf(base_size.x, 1.0)
			r.size.y /= maxf(base_size.y, 1.0)
		return r
	elif rect is Rect2:
		return rect
	return Rect2()

func _is_pixel(v: Vector2) -> bool:
	return v.x > 1.0001 or v.y > 1.0001

func _polygon_center(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2(10, 20)
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())