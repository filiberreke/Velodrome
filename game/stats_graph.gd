extends Control
var samples: Array[Vector2] = []
var title := ""
var max_distance := 250.0
var max_value := 1000.0

func set_title(value: String) -> void:
	title = value
	queue_redraw()

func set_samples(values: Array, distance_max: float, value_max: float) -> void:
	samples = []
	for v in values:
		if v is Vector2:
			samples.append(v)
	max_distance = maxf(1.0, distance_max)
	max_value = maxf(100.0, value_max)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.12, 0.17, 0.92), true)
	var pad_left := 30.0
	var pad_right := 10.0
	var pad_top := 22.0
	var pad_bottom := 20.0
	var area: Rect2 = Rect2(pad_left, pad_top, size.x - pad_left - pad_right, size.y - pad_top - pad_bottom)
	draw_string(get_theme_default_font(), Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	# axes
	draw_rect(area, Color(0.14, 0.18, 0.24, 0.88), true)
	for fraction in [0.25, 0.5, 0.75]:
		var frac: float = float(fraction)
		var y: float = area.position.y + area.size.y * (1.0 - frac)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(1,1,1,0.08), 1.0, true)
		var label: String = "%d" % int(round(frac * max_value))
		draw_string(get_theme_default_font(), Vector2(3, y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82,0.88,0.95))
	draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), Color(0.8,0.85,0.92), 1.3, true)
	draw_line(Vector2(area.position.x, area.position.y), Vector2(area.position.x, area.end.y), Color(0.8,0.85,0.92), 1.3, true)
	draw_string(get_theme_default_font(), Vector2(area.position.x, size.y - 4), "0 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82,0.88,0.95))
	draw_string(get_theme_default_font(), Vector2(area.end.x - 55, size.y - 4), "%d m" % int(max_distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82,0.88,0.95))
	if samples.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for s: Vector2 in samples:
		var x: float = area.position.x + clampf(s.x / max_distance, 0.0, 1.0) * area.size.x
		var y: float = area.end.y - clampf(s.y / max_value, 0.0, 1.0) * area.size.y
		points.append(Vector2(x, y))
	# filled underlay
	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(Vector2(area.position.x, area.end.y))
	for pt: Vector2 in points:
		poly.append(pt)
	poly.append(Vector2(points[-1].x, area.end.y))
	draw_colored_polygon(poly, Color(0.97,0.74,0.16,0.18))
	draw_polyline(points, Color(0.97,0.78,0.24), 2.6, true)
