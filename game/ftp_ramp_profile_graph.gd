extends Control
## FTP ramp target profile and actual measured watts; uses race power-meter colours.
const HudTheme := preload("res://menu_theme.gd")
const Meter := preload("res://power_meter.gd")
var samples: Array[Dictionary] = []
var elapsed := 0.0
var ramp_started := -1.0
var running := false
func _ready() -> void:
	custom_minimum_size.y = 170
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func update_profile(points: Array[Dictionary], seconds: float, ramp_at_seconds: float, active: bool) -> void:
	samples = points
	elapsed = seconds
	ramp_started = ramp_at_seconds
	running = active
	queue_redraw()
func _draw() -> void:
	if size.x < 80 or size.y < 80: return
	var area := Rect2(44, 16, size.x - 60, size.y - 46)
	var from_s := maxf(0.0, elapsed - 360.0)
	var to_s := maxf(600.0, elapsed + 300.0)
	var max_w := 400.0
	if ramp_started >= 0.0: max_w = maxf(400.0, 100.0 + 20.0 * ceilf(maxf(0.0, to_s-ramp_started)/60.0) + 40.0)
	for s in samples: max_w = maxf(max_w, float(s.w) + 40.0)
	var font := get_theme_default_font()
	for i in range(5):
		var watts := max_w * i / 4.0
		var yy := area.end.y - watts / max_w * area.size.y
		draw_line(Vector2(area.position.x, yy), Vector2(area.end.x, yy), HudTheme.LINE, 1.0)
		draw_string(font, Vector2(2, yy+5), "%d" % roundi(watts), HORIZONTAL_ALIGNMENT_LEFT, 40, 13, HudTheme.MUTED)
	var step := 30.0
	var t := from_s
	var previous := Vector2.ZERO
	var has_previous := false
	while t <= to_s + 0.01:
		var target := 0.0
		if ramp_started >= 0.0 and t >= ramp_started:
			target = minf(1300.0, 100.0 + 20.0 * floorf((t-ramp_started)/60.0))
		var point := Vector2(area.position.x + (t-from_s)/(to_s-from_s)*area.size.x, area.end.y - target/max_w*area.size.y)
		if has_previous: draw_line(previous, point, Color("a0a7b0", 0.75), 5.0, true)
		previous = point
		has_previous = true
		t += step
	var last := Vector2.ZERO
	var valid := false
	for s in samples:
		var sec := float(s.t)
		if sec < from_s or sec > to_s:
			valid = false
			continue
		var power := float(s.w)
		var p := Vector2(area.position.x + (sec-from_s)/(to_s-from_s)*area.size.x, area.end.y - power/max_w*area.size.y)
		if valid: draw_line(last, p, Meter.zone_color(power), 2.8, true)
		last = p
		valid = true
	if running:
		var x := area.position.x + clampf((elapsed-from_s)/(to_s-from_s), 0, 1)*area.size.x
		draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),HudTheme.BLUE,1.5)
	for i in range(5):
		var seconds := lerpf(from_s,to_s,float(i)/4.0)
		draw_string(font,Vector2(area.position.x+area.size.x*i/4.0-12,size.y-9),"%d:%02d" % [int(seconds)/60,int(seconds)%60],HORIZONTAL_ALIGNMENT_LEFT,60,13,HudTheme.MUTED)
