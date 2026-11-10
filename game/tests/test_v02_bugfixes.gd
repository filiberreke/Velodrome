extends SceneTree
## Run with: godot --headless --path game --script res://tests/test_v02_bugfixes.gd
const AI := preload("res://x_scratch_ai.gd")
const Points := preload("res://points_race_rules.gd")

func _initialize() -> void:
	_test_ai_strength()
	_test_sprint_before_lap_credit()
	print("v0.2 bugfix regression checks passed")
	quit()

func _test_ai_strength() -> void:
	for percent in [40.0, 60.0, 80.0, 100.0]:
		var ai = AI.new()
		ai.reset([0, 1, 2, 3], [1.0, 1.0, 1.0, 1.0], [1.18, 1.18, 1.18, 1.18])
		ai.apply_ai_strength(percent)
		assert(is_equal_approx(ai.cp[0], 0.0))
		for rider in range(1, 4):
			var factor: float = percent / 100.0
			assert(is_equal_approx(ai.cp[rider], AI.CP[rider] * factor))
			assert(is_equal_approx(ai.pmax[rider], AI.PMAX[rider] * factor))
			assert(is_equal_approx(ai.wmax[rider], AI.WMAX[rider] * factor))
			assert(is_equal_approx(ai.wprime[rider], ai.wmax[rider]))

func _test_sprint_before_lap_credit() -> void:
	var jury = Points.new()
	jury.reset(6, 20)
	# Sprint on lap 10 is complete; the next official sprint is lap 20.
	jury.sprints.append({"lap": 10, "seconds": 10.0, "order": [0,1,2,3,4,5], "times": [], "awards": []})
	# Rider 0 has caught the bunch a lap ahead, inside 100m before lap 20.
	var bunch: Array[float] = [4925.0, 4675.0, 4675.0, 4675.0, 4675.0, 4675.0]
	var finish: Array[float] = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
	jury.advance(bunch, bunch, 20.0, 0.01, finish)
	assert(jury.pending_gains.has(0))
	assert(jury.credits[0] == 0)
	assert(jury.points[0] == 0)
	var after: Array[float] = bunch.duplicate()
	bunch[0] = 4999.0
	after[0] = 5001.0
	jury.advance(bunch, after, 21.0, 0.1, finish)
	assert(jury.credits[0] == 1)
	assert(jury.points[0] == 30) # 10 final sprint points + 20 gained lap
	assert(not jury.pending_gains.has(0))
