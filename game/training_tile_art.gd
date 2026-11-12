extends Control
## Resolution-independent chart. Saved tiles use their actual workout blocks.
const Style := preload("res://menu_theme.gd")
var workout_blocks: Array = []
func _ready() -> void:
	resized.connect(queue_redraw)
func set_workout(blocks: Array) -> void:
	workout_blocks = blocks.duplicate(true)
	queue_redraw()
static func chart_sections(blocks: Array) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for block in blocks:
		if block.kind == "IntervalsT":
			for i in range(int(block.repeat)):
				sections.append({"seconds":float(block.on_duration),"low":float(block.on_power),"high":float(block.on_power),"kind":"SteadyState"})
				sections.append({"seconds":float(block.off_duration),"low":float(block.off_power),"high":float(block.off_power),"kind":"Recovery"})
		else:
			var low := float(block.get("power_low",0))
			var high := float(block.get("power_high",low)) if block.kind in ["Warmup","Cooldown","Ramp"] else low
			sections.append({"seconds":float(block.duration),"low":low,"high":high,"kind":str(block.kind)})
	return sections
func _draw() -> void:
	var area := Rect2(Vector2(0, size.y * .08), Vector2(size.x, size.y * .84))
	draw_style_box(Style.panel(Style.PALE, Style.LINE, 0, 12), area)
	var padding := Vector2(18,minf(18,area.size.y*.15))
	var origin := area.position + padding
	var width := maxf(1,area.size.x - padding.x*2)
	var height := maxf(1,area.size.y - padding.y*2)
	for level in [.25, .5, .75]:
		var y: float = origin.y + height * float(level)
		draw_line(Vector2(origin.x, y), Vector2(origin.x + width, y), Style.LINE, 1, true)
	var blocks := workout_blocks
	if blocks.is_empty():
		blocks = [{"kind":"Warmup","duration":180,"power_low":.25,"power_high":.55},{"kind":"SteadyState","duration":180,"power_low":.65}]
		for i in range(3): blocks.append({"kind":"IntervalsT","repeat":1,"on_duration":70,"off_duration":40,"on_power":.95,"off_power":.35})
		blocks.append({"kind":"Cooldown","duration":230,"power_low":.55,"power_high":.2})
	var sections := chart_sections(blocks)
	var total := 0.0
	var peak := 1.25
	for section in sections:
		total += section.seconds
		peak = maxf(peak,maxf(section.low,section.high))
	if total <= 0: return
	var base := origin.y + height
	var x := origin.x
	for section in sections:
		var span: float = width * section.seconds/total
		var low: float = clampf(section.low/peak,0,1)
		var high: float = clampf(section.high/peak,0,1)
		if section.kind == "FreeRide": low = .06; high = .06
		var colour := Color("9aaab9") if section.kind in ["FreeRide","Recovery"] else Color("e5767b") if maxf(section.low,section.high) > .9 else Color("54b87a") if section.kind == "Warmup" else Color("439ee9")
		var points := PackedVector2Array([Vector2(x, base), Vector2(x, base - height * low), Vector2(x + span, base - height * high), Vector2(x + span, base)])
		if span > 0 and maxf(low,high) > 0: draw_colored_polygon(points, colour)
		x += span
	draw_line(Vector2(origin.x, base), Vector2(origin.x + width, base), Style.MUTED, 1, true)
