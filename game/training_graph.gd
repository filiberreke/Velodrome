extends Control
## Full-session trends; separate labelled scales, gaps for missing sensors.
const SERIES := [["game_speed_kmh", "Snelheid", "km/u", 40.0, Color("67c9ff")], ["power_w", "Vermogen", "W", 200.0, Color("ffe247")], ["heart_rate_bpm", "Hartslag", "bpm", 160.0, Color("ff8293")], ["cadence_rpm", "Cadans", "rpm", 100.0, Color("7ee6ae")]]
var samples: Array = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 190
	resized.connect(queue_redraw)
func set_samples(values: Array) -> void:
	samples = values
	queue_redraw()
static func valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0
func _draw() -> void:
	var skin := preload("res://menu_theme.gd").panel(Color(.04,.10,.17,.64), Color(.65,.75,.85,.45), 0, 12)
	draw_style_box(skin, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var columns := 2 if size.x < 1100 else 4
	var top := 56.0 if columns == 2 else 36.0
	var area := Rect2(16, top, maxf(1,size.x - 32), maxf(1,size.y - top-24))
	for fraction in [.25,.5,.75]:
		var y: float = area.end.y - float(fraction) * area.size.y
		draw_line(Vector2(area.position.x,y), Vector2(area.end.x,y), Color(1,1,1,.12))
	var duration := maxf(1.0, float(samples[-1].time_s)) if not samples.is_empty() else 1.0
	for index in range(SERIES.size()):
		var series: Array = SERIES[index]
		var maximum: float = series[3]
		var latest: Variant = null
		for sample in samples:
			var value: Variant = sample.get(series[0])
			if valid(value): maximum = maxf(maximum, ceil(float(value) / 20) * 20)
			latest = value
		var label := "%s %s %s · schaal 0–%.0f" % [series[1], "%.0f" % float(latest) if valid(latest) else "—", series[2], maximum]
		draw_string(font, Vector2(16 + (index%columns) * (size.x-32)/columns, 24+(index/columns)*20), label, HORIZONTAL_ALIGNMENT_LEFT, (size.x-32)/columns-8, 15, series[4])
		var points := PackedVector2Array()
		var stride := maxi(1, int(ceil(float(samples.size()) / maxf(200, area.size.x))))
		for i in range(samples.size()):
			var value: Variant = samples[i].get(series[0])
			if not valid(value):
				if points.size() > 1: draw_polyline(points, series[4], 2, true)
				points.clear()
				continue
			if i % stride != 0 and i != samples.size()-1: continue
			points.append(Vector2(area.position.x + float(samples[i].time_s)/duration * area.size.x, area.end.y - float(value)/maximum * area.size.y))
		if points.size() > 1: draw_polyline(points, series[4], 2, true)
	for tick in range(5):
		var seconds := int(duration * tick / 4)
		var caption := "%d:%02d" % [seconds/60,seconds%60]
		var x := clampf(area.position.x + area.size.x * tick/4.0 - 18,16,size.x-58)
		draw_string(font, Vector2(x,size.y-9),caption,HORIZONTAL_ALIGNMENT_LEFT,60,13,Color.WHITE)
