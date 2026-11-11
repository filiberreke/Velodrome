extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = preload("res://main.gd").new()
	var before = preload("res://tests/track_bowl_before.gd").new()
	var old_max_grade := 0.0
	var max_grade := 0.0
	var max_tangent_step := 0.0
	var min_bank := 90.0
	var max_bank := 0.0
	for i in range(5000):
		var d := float(i) * 0.05
		var a: Vector3 = game._at(d,game.TRACK_EDGE)
		var b: Vector3 = game._at(d,game.TRACK_OUTER_EDGE)
		check(absf(a.distance_to(b) - (game.TRACK_OUTER_EDGE-game.TRACK_EDGE)) < 0.0001,"Constant wood surface width")
		var angle := rad_to_deg(atan2(b.y-a.y,Vector2(b.x-a.x,b.z-a.z).length()))
		min_bank = minf(min_bank,angle); max_bank = maxf(max_bank,angle)
		var forward: Vector3 = game._at(d+0.05,7.18)-game._at(d-0.05,7.18)
		var old_forward: Vector3 = before._at(d+0.05,7.18)-before._at(d-0.05,7.18)
		old_max_grade = maxf(old_max_grade,absf(old_forward.y)/Vector2(old_forward.x,old_forward.z).length())
		max_grade = maxf(max_grade,absf(forward.y)/Vector2(forward.x,forward.z).length())
		max_tangent_step = maxf(max_tangent_step,game._direction(d+0.05,7.18).angle_to(game._direction(d,7.18)))
		check(game._track_normal(d,4.0).y > 0.6,"Upward consistent surface normal")
		check(game._at(d,4.0).distance_to(game._at(d+250.0,4.0)) < 0.0001,"Closed periodic riding line")
	check(absf(min_bank-12.0)<0.001 and absf(max_bank-42.0)<0.001,"Realistic 12–42 degree banking range")
	check(max_grade < 0.15,"Upper riding line has no short steep ramp")
	check(max_grade < old_max_grade * 0.5,"More than halve the old upper-lane ramp gradient")
	check(max_tangent_step < 0.006,"Smooth heading and pitch across transitions")
	for s in [0.0,125.0,250.0,game.STRAIGHT-18.0,game.STRAIGHT+18.0,game.STRAIGHT+PI*game.RADIUS-18.0,game.STRAIGHT+PI*game.RADIUS+18.0]:
		for lane in [0.78,1.18,7.18,9.03]:
			var d: float = -s
			var left: Vector3 = (game._at(d,lane)-game._at(d-0.01,lane))/0.01
			var right: Vector3 = (game._at(d+0.01,lane)-game._at(d,lane))/0.01
			check(left.distance_to(right)<0.003,"Continuous tangent at every transition and lap seam")
	print("TRACK_BOWL_METRICS ",JSON.stringify({"min_bank_deg":min_bank,"max_bank_deg":max_bank,"old_max_upper_lane_grade_pct":old_max_grade*100.0,"max_upper_lane_grade_pct":max_grade*100.0,"max_tangent_change_deg_per_5cm":rad_to_deg(max_tangent_step)}))
	before.free()
	game.free()
	print("TRACK_BOWL_OK" if failures==0 else "TRACK_BOWL_FAILED %d"%failures)
	quit(0 if failures==0 else 1)
