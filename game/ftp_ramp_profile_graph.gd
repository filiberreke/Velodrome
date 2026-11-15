extends Control
## FTP ramp target profile and actual measured watts; uses race power-meter colours.
const HudTheme := preload("res://menu_theme.gd")
const Meter := preload("res://power_meter.gd")
var samples: Array[Dictionary] = []
var elapsed := 0.0
var ramp_started := -1.0
var running := false
var workout_blocks: Array = []
var workout_ftp := 200.0
var workout_duration := 0.0
var twenty_mode := false
var twenty_target := 0.0
var twenty_start := 300.0
func _ready() -> void:
	custom_minimum_size.y = 170
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func update_profile(points: Array[Dictionary], seconds: float, ramp_at_seconds: float, active: bool) -> void:
	workout_blocks = []
	samples = points
	elapsed = seconds
	ramp_started = ramp_at_seconds
	twenty_mode = false
	running = active
	queue_redraw()
func update_twenty(points: Array[Dictionary], seconds: float, target: float, test_start: float) -> void:
	workout_blocks = []
	samples = points
	elapsed = seconds
	twenty_mode = true
	twenty_target = target
	twenty_start = test_start
	running = true
	queue_redraw()
func update_workout(points: Array[Dictionary], seconds: float, blocks: Array, ftp: float, duration: float) -> void:
	samples = points
	elapsed = seconds
	workout_blocks = blocks
	workout_ftp = ftp
	workout_duration = duration
	twenty_mode = false
	running = true
	queue_redraw()

func _target_block(area: Rect2, from_s: float, to_s: float, max_w: float, start: float, end: float, low: float, high: float) -> void:
	if end <= from_s or start >= to_s: return
	var a := maxf(start, from_s)
	var b := minf(end, to_s)
	var xa := area.position.x + (a-from_s)/(to_s-from_s)*area.size.x
	var xb := area.position.x + (b-from_s)/(to_s-from_s)*area.size.x
	var ya := area.end.y - lerpf(low,high,(a-start)/(end-start))/max_w*area.size.y
	var yb := area.end.y - lerpf(low,high,(b-start)/(end-start))/max_w*area.size.y
	draw_colored_polygon(PackedVector2Array([Vector2(xa,area.end.y),Vector2(xa,ya),Vector2(xb,yb),Vector2(xb,area.end.y)]),Color("9ba4af",0.45))

func _draw() -> void:
	if size.x < 80 or size.y < 80: return
	var area := Rect2(44, 16, size.x - 60, size.y - 46)
	var from_s := maxf(0.0, elapsed - 360.0)
	var to_s := (1500.0 if twenty_mode else maxf(600.0, elapsed + 300.0))
	if twenty_mode: from_s = 0.0
	if not workout_blocks.is_empty():
		from_s = 0.0
		to_s = maxf(1.0,workout_duration)
	var max_w := 400.0
	if ramp_started >= 0.0 and not twenty_mode and workout_blocks.is_empty(): max_w = maxf(400.0, 100.0 + 20.0 * ceilf(maxf(0.0, to_s-ramp_started)/60.0) + 40.0)
	if twenty_mode: max_w = maxf(max_w, twenty_target * 1.25)
	for block in workout_blocks: max_w = maxf(max_w,maxf(float(block.power_low),float(block.power_high))*workout_ftp+40.0)
	for s in samples: max_w = maxf(max_w, float(s.w) + 40.0)
	var font := get_theme_default_font()
	for i in range(5):
		var watts := max_w * i / 4.0
		var yy := area.end.y - watts / max_w * area.size.y
		draw_line(Vector2(area.position.x, yy), Vector2(area.end.x, yy), HudTheme.LINE, 1.0)
		draw_string(font, Vector2(2, yy+5), "%d" % roundi(watts), HORIZONTAL_ALIGNMENT_LEFT, 40, 13, HudTheme.MUTED)
	# The five-minute free warmup is followed by 100 W and +20 W every minute.
	# During warmup the planned start is already known; after ERG confirmation
	# the supplied ramp start aligns the blocks to the trainer's actual clock.
	if not workout_blocks.is_empty():
		var start := 0.0
		for block in workout_blocks:
			var end := start + float(block.duration)
			if block.kind != "FreeRide":
				_target_block(area,from_s,to_s,max_w,start,end,float(block.power_low)*workout_ftp,float(block.power_high)*workout_ftp)
			start = end
	elif twenty_mode:
		_target_block(area,from_s,to_s,max_w,twenty_start,to_s,twenty_target,twenty_target)
		var x0 := area.position.x + (twenty_start - from_s) / (to_s - from_s) * area.size.x
		var y0 := area.end.y - twenty_target / max_w * area.size.y
		var xnow := area.position.x + (minf(maxf(elapsed,twenty_start),to_s) - from_s) / (to_s - from_s) * area.size.x
		draw_line(Vector2(x0,y0),Vector2(area.end.x,y0),Color("9ba4af"),5.0,true)
		if elapsed > twenty_start: draw_line(Vector2(x0,y0),Vector2(xnow,y0),Meter.zone_color(twenty_target),5.0,true)
		if elapsed > 0.0 and twenty_start > 0.0:
			var warm_end := minf(elapsed,twenty_start)
			var wx := area.position.x + (warm_end - from_s) / (to_s - from_s) * area.size.x
			draw_line(Vector2(area.position.x,area.end.y),Vector2(wx,area.end.y),HudTheme.LINE,2.0,true)
	elif ramp_started >= 0.0:
		for index in range(61):
			var start_s: float = ramp_started + index * 60.0
			var end_s: float = start_s + 60.0
			if start_s > to_s: break
			if end_s < from_s: continue
			var watts: float = float(mini(1300, 100 + index * 20))
			_target_block(area,from_s,to_s,max_w,start_s,end_s,watts,watts)
			var y: float = area.end.y - watts / max_w * area.size.y
			var xa: float = area.position.x + (maxf(start_s, from_s) - from_s) / (to_s - from_s) * area.size.x
			var xb: float = area.position.x + (minf(end_s, to_s) - from_s) / (to_s - from_s) * area.size.x
			var covered_end: float = minf(end_s, elapsed)
			if covered_end > maxf(start_s, from_s):
				var completed_x: float = area.position.x + (minf(covered_end, to_s) - from_s) / (to_s - from_s) * area.size.x
				draw_line(Vector2(xa, y), Vector2(completed_x, y), Meter.zone_color(watts), 5.0, true)
				if completed_x < xb:
					draw_line(Vector2(completed_x, y), Vector2(xb, y), Color("9ba4af"), 5.0, true)
			else:
				draw_line(Vector2(xa, y), Vector2(xb, y), Color("9ba4af"), 5.0, true)
			if index > 0 and start_s >= from_s:
				var prior_w: float = float(100 + (index - 1) * 20)
				var prev_y: float = area.end.y - prior_w / max_w * area.size.y
				var col: Color = Meter.zone_color(watts) if start_s <= elapsed else Color("9ba4af")
				draw_line(Vector2(xa, prev_y), Vector2(xa, y), col, 3.0, true)
	# Heart rate and cadence overlay the filled watt blocks on their own scales.
	# Each measurement holds its value until the next sample, leaving telemetry gaps empty.
	for i in range(samples.size()-1):
		var record: Dictionary = samples[i]
		var start := float(record.t)
		var end := float(samples[i+1].t)
		if end <= start or end-start > 10.0 or end <= from_s or start >= to_s: continue
		var power := float(record.w)
		var xa := area.position.x + (maxf(start,from_s)-from_s)/(to_s-from_s)*area.size.x
		var xb := area.position.x + (minf(end,to_s)-from_s)/(to_s-from_s)*area.size.x
		var height := maxf(0.0,power)/max_w*area.size.y
		draw_rect(Rect2(xa,area.end.y-height,xb-xa,height),Meter.zone_color(power))
	var trace_area := Rect2(area.position.x, area.position.y, area.size.x, area.size.y)
	for channel in ["hr", "rpm"]:
		var prior := Vector2.ZERO
		var has_prior := false
		var channel_max := 210.0 if channel == "hr" else 150.0
		var channel_color := Color("c34a5b") if channel == "hr" else Color("278a71")
		for record in samples:
			var when: float = float(record.t)
			var value: float = float(record.get(channel,-1.0))
			if when < from_s or when > to_s or value < 0.0:
				has_prior = false
				continue
			var px := trace_area.position.x + (when-from_s)/(to_s-from_s)*trace_area.size.x
			var py := trace_area.end.y - clampf(value/channel_max,0.0,1.0)*trace_area.size.y
			var point := Vector2(px,py)
			if has_prior: draw_line(prior,point,channel_color,1.9,true)
			prior = point
			has_prior = true
	if running:
		var x := area.position.x + clampf((elapsed-from_s)/(to_s-from_s), 0, 1)*area.size.x
		draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),HudTheme.BLUE,1.5)
	draw_string(font,Vector2(area.position.x + 8,area.position.y + 14),"W  /  HR (rood)  /  RPM (groen)",HORIZONTAL_ALIGNMENT_LEFT,360,13,HudTheme.MUTED)
	for i in range(5):
		var seconds := lerpf(from_s,to_s,float(i)/4.0)
		draw_string(font,Vector2(area.position.x+area.size.x*i/4.0-12,size.y-9),"%d:%02d" % [int(seconds)/60,int(seconds)%60],HORIZONTAL_ALIGNMENT_LEFT,60,13,HudTheme.MUTED)
