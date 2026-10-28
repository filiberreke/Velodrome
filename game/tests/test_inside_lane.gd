extends SceneTree
const Brain := preload("res://x_scratch_ai.gd")
const PointsAI := preload("res://points_ai.gd")
const Rules := preload("res://points_race_rules.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func choose(model, distances: Array[float], speeds: Array[float], lanes: Array[float], finished: Array[float], mode: int = Brain.MODE_DRAFT, wheel: int = -1, gap: float = 1000.0, sprint: bool = false, clock: float = 20.0) -> void:
	model._prefer_inner_line(1,clock,distances,speeds,lanes,finished,mode,wheel,gap,sprint)
func run_tests() -> void:
	var model = Brain.new()
	var profiles: Array[int] = [0,1,2,3]
	var forms: Array[float] = [1.,1.,1.,1.]
	var lanes: Array[float] = [1.18,5.98,3.58,2.38]
	var distances: Array[float] = [500.,600.,650.,700.]
	var speeds: Array[float] = [12.,12.,12.,12.]
	var finished: Array[float] = [-1.,-1.,-1.,-1.]
	var drafts: Array[float] = [0.,0.,0.,0.]
	var credits: Array[int] = [0,0,0,0]
	model.reset(profiles,forms,lanes)
	model.lane_lock[1] = 1000.0
	choose(model,distances,speeds,lanes,finished,Brain.MODE_DRAFT,-1,1000.0,false,10.0)
	check(is_equal_approx(model.lane_targets[1],1.18),"Free rider may move inside during initial acceleration too")
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],1.18),"Free ordinary rider returns inside despite stale lane lock")
	distances[2] = 600.
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],5.98),"Cancel pending default descent when its corridor becomes occupied")
	# Empty destination, occupied intermediate corridor: retain tactical line.
	distances[2] = 600.; model.lane_targets[1] = 5.98
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],5.98),"Do not cut across a rider between current and inner lane")
	lanes[2] = 1.18; model.lane_targets[1] = 5.98
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],5.98),"Occupied inner lane does not trigger a squeeze into intermediate lanes")
	# Circular distance sees riders one lap down and across the start line.
	lanes[2] = 3.58; distances[1] = 749.; distances[2] = 500.
	model.lane_targets[1] = 5.98
	choose(model,distances,speeds,lanes,finished)
	check(model.lane_targets[1] >= 4.78,"Lapped rider in the physical corridor is not ignored")
	distances[1] = 749.; distances[2] = 751.
	choose(model,distances,speeds,lanes,finished)
	check(model.lane_targets[1] >= 4.78,"Start-line wrap remains occupied")
	# A fast rider approaching from behind makes a currently empty descent unsafe.
	distances[1] = 600.; distances[2] = 588.; speeds[2] = 16.
	choose(model,distances,speeds,lanes,finished)
	check(model.lane_targets[1] >= 4.78,"Wait for faster rear rider before crossing their line")
	speeds[2] = 12.; distances[2] = 650.
	for mode in [Brain.MODE_ATTACK,Brain.MODE_BREAK_PULL]:
		model.lane_targets[1] = 5.98
		choose(model,distances,speeds,lanes,finished,mode)
		check(is_equal_approx(model.lane_targets[1],5.98),"Preserve deliberate attack/takeover lane")
	model.pull_off_until[1] = 30.; model.lane_targets[1] = 7.18
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],7.18),"Preserve active pull-off")
	model.pull_off_until[1] = 0.
	for mode in [Brain.MODE_DRAFT,Brain.MODE_CHASE,Brain.MODE_BREAK_DRAFT]:
		model.lane_targets[1] = 3.58
		choose(model,distances,speeds,lanes,finished,mode,2,5.)
		check(is_equal_approx(model.lane_targets[1],3.58),"Useful wheel remains a reason to ride higher")
	model.lane_targets[1] = 5.98
	choose(model,distances,speeds,lanes,finished,Brain.MODE_DRAFT,-1,1000.,true)
	check(is_equal_approx(model.lane_targets[1],5.98),"Preserve sprint positioning")
	model.sprint_started[1] = true
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],5.98),"Preserve launched sprint")
	model.sprint_started[1] = false
	finished[2] = 20.; distances[2] = 600.
	choose(model,distances,speeds,lanes,finished)
	check(is_equal_approx(model.lane_targets[1],1.18),"Finished riders do not reserve a race corridor")
	model.lane_targets[0] = 5.98
	model._prefer_inner_line(0,20.,distances,speeds,lanes,finished,Brain.MODE_DRAFT,-1,1000.,false)
	check(model.lane_targets[0] == 5.98,"Never steer the human")
	# Previously planned lower-index merges reserve the swept corridor too.
	model.reset(profiles,forms,lanes); finished.fill(-1.)
	distances.assign([500.,600.,600.,700.]); lanes.assign([1.18,5.98,4.78,2.38])
	model.lane_targets[1] = 1.18
	model.lane_targets[2] = 4.78
	model._prefer_inner_line(2,20.,distances,speeds,lanes,finished,Brain.MODE_DRAFT,-1,1000.,false)
	check(is_equal_approx(model.lane_targets[2],4.78),"Simultaneous descent cannot claim an already reserved corridor")
	# Exercise actual tactical step for all profiles, scratch and points.
	for brain in [Brain.new(),PointsAI.new()]:
		for kind in [1,2,3]:
			profiles.assign([0,kind,2,3]);lanes.assign([1.18,5.98,3.58,2.38]);distances.assign([1000.,1100.,950.,940.])
			brain.reset(profiles,forms,lanes);brain.cooldown.fill(1000.);brain.lane_lock[1] = 1000.
			if brain is PointsAI:
				brain.jury = Rules.new();brain.jury.reset(4,40)
			brain.step(0.1,20.,distances,speeds,lanes,drafts,finished,profiles,40,80.,credits)
			check(is_equal_approx(brain.lane_targets[1],1.18),"All AI profiles choose inner lane through actual step")
	# Confirm the existing geometry already makes higher laps longer.
	var game = preload("res://main.gd").new()
	var inner := 0.0; var outer := 0.0
	for n in range(500):
		inner += game._path_metric(float(n)*0.5,1.18)*0.5
		outer += game._path_metric(float(n)*0.5,7.18)*0.5
	check(outer > inner + 20.0,"Outer lane must already cost more actual distance")
	game.free()
	print("INSIDE_LANE_GEOMETRY ",JSON.stringify({"inner_lap_m":inner,"outer_lap_m":outer}))
	print("INSIDE_LANE_OK" if failures == 0 else "INSIDE_LANE_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
