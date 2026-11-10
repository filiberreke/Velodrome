extends SceneTree
## Run with: godot --headless --path game --script res://tests/test_v02_bugfixes.gd
const AI := preload("res://x_scratch_ai.gd")
const Points := preload("res://points_race_rules.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	_test_ai_strength()
	_test_sprint_before_lap_credit()
	_test_exact_line_catch()
	print("V02_BUGFIXES failures=", failures)
	quit(0 if failures == 0 else 1)

func _test_ai_strength() -> void:
	for percent in [40.0, 60.0, 80.0, 100.0]:
		var ai = AI.new()
		ai.reset([0, 1, 2, 3], [1.0, 1.0, 1.0, 1.0], [1.18, 1.18, 1.18, 1.18])
		ai.apply_ai_strength(percent)
		check(is_equal_approx(ai.cp[0], 0.0), "Human physiology is not scaled")
		for rider in range(1, 4):
			var factor: float = percent / 100.0
			check(is_equal_approx(ai.cp[rider], AI.CP[rider] * factor), "CP scales once")
			check(is_equal_approx(ai.pmax[rider], AI.PMAX[rider] * factor), "Peak power scales once")
			check(is_equal_approx(ai.wmax[rider], AI.WMAX[rider] * factor), "Wprime capacity scales once")
			check(is_equal_approx(ai.wprime[rider], ai.wmax[rider]), "Scaled reserve starts full")

func _test_sprint_before_lap_credit() -> void:
	var jury = Points.new()
	jury.reset(6, 20)
	# Sprint on lap 10 is complete; the next official sprint is lap 20.
	jury.sprints.append({"lap": 10, "seconds": 10.0, "order": [0,1,2,3,4,5], "times": [], "awards": []})
	# Rider 0 has caught the bunch a lap ahead, inside 100m before lap 20.
	var bunch: Array[float] = [4925.0, 4675.0, 4675.0, 4675.0, 4675.0, 4675.0]
	var finish: Array[float] = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
	jury.advance(bunch, bunch, 20.0, 0.01, finish)
	check(jury.pending_gains.has(0), "Gain is held before sprint")
	check(jury.credits[0] == 0, "Credit remains provisional")
	check(jury.points[0] == 0, "No early lap points")
	var after: Array[float] = bunch.duplicate()
	bunch[0] = 4999.0
	after[0] = 5001.0
	jury.advance(bunch, after, 21.0, 0.1, finish)
	check(jury.credits[0] == 1, "Lap credited after line crossing")
	check(jury.points[0] == 30, "Final sprint plus gained lap")
	var notices = preload("res://points_notifications.gd").new()
	notices.seen_awards[10] = true
	check(notices.collect(jury,5001.) == ["+ 10 punten", "+ 20 punten!"],"Sprint popup precedes gained-lap popup")
	check(not jury.pending_gains.has(0), "Pending gain clears after sprint")

func _test_exact_line_catch() -> void:
	for race_laps in [20,40]:
		var jury = Points.new(); jury.reset(6,race_laps)
		jury.sprints.append({"lap":10,"seconds":10.,"order":[0,1,2,3,4,5],"times":[],"awards":[]})
		var ends: Array[float] = [-1.,-1.,-1.,-1.,-1.,-1.]
		# The gap becomes 250 m exactly at the sprint line, with no prior pending gain.
		jury.advance([4999.,4749.1,4749.1,4749.1,4749.1,4749.1],[5001.,4750.9,4750.9,4750.9,4750.9,4750.9],21.,.1,ends)
		check(jury.sprints[-1].lap == 20 and jury.sprints[-1].order[0] == 0,"Line catch retains sprint eligibility")
		check(jury.credits[0] == 1 and jury.points[0] == (30 if race_laps == 20 else 25),"Sprint points then lap bonus")
		check(jury.pending_gains.is_empty(),"Line catch clears pending gain")
		check((jury.finish_clock >= 0.) == (race_laps == 20),"Only final sprint ends race")
	for remaining in [101.,100.,75.]:
		var jury = Points.new(); jury.reset(6,20)
		jury.sprints.append({"lap":10,"seconds":10.,"order":[0,1,2,3,4,5],"times":[],"awards":[]})
		var position: float = 5000.-remaining
		jury._judge_laps([position,position-250.,position-250.,position-250.,position-250.,position-250.],20.)
		check(jury.pending_gains.has(0) == (remaining <= 100.),"Inclusive last-100-m protection boundary")
		check(jury.credits[0] == (0 if remaining <= 100. else 1),"Outside protection gain is immediate")
	var group = Points.new(); group.reset(8,40)
	var ends: Array[float] = [-1.,-1.,-1.,-1.,-1.,-1.,-1.,-1.]
	var before: Array[float] = [2425.,2424.,2174.,2174.,2174.,2174.,2174.,2174.]
	group.advance(before,before,10.,.1,ends)
	check(group.pending_gains.has(0) and group.pending_gains.has(1),"Multiple gains can remain pending together")
	group.advance([2499.,2498.,2248.,2248.,2248.,2248.,2248.,2248.],[2502.,2501.,2251.,2251.,2251.,2251.,2251.,2251.],11.,.1,ends)
	check(group.points[0] == 25 and group.points[1] == 23,"Each pending rider receives their own sprint place and bonus")
	check(group.credits[0] == 1 and group.credits[1] == 1 and group.pending_gains.is_empty(),"Both pending gains clear once")
