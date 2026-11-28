extends SceneTree
## Scripted compact field. All riders use the native longitudinal physics.
const Measure := preload("res://tests/measure_elimination_pushing.gd")
const Motion := preload("res://elimination_motion.gd")

func _initialize() -> void:
	run.call_deferred()

func normal_outward_space(g: Measure.Race) -> bool:
	var next: Array[float] = g.lane_offsets.duplicate()
	var target := minf(g.LANES[-1], next[0] + Motion.LATERAL_CLEARANCE)
	next[0] = target
	var metrics: Array[float] = []
	for i in range(g.rider_count):
		metrics.append(g._path_metric(g.distances[i], g.lane_offsets[i]))
	var result := Motion.constrain_lanes(g.distances, g.speeds, g.lane_offsets, next,
		g.finish_times, metrics, Motion.LATERAL_CLEARANCE / g.LANE_CHANGE_MPS)
	return target > g.lane_offsets[0] and absf(result[0] - target) < 0.00001

func run() -> void:
	for tactic in ["steady", "accelerate", "ease_off", "steer_once", "steer_twice"]:
		seed(17)
		var g := Measure.Race.new()
		root.add_child(g)
		g.race_mode = 2
		g.rider_count = 8
		g.race_laps = 14
		g.elimination_notice = Label.new()
		g.add_child(g.elimination_notice)
		g._configure_peloton()
		g.lane_offsets.assign([1.18, 1.18, 1.78, 1.78, 1.78, 1.78, 2.38, 2.38])
		g.distances.assign([100.0, 102.08, 100.0, 102.2, 97.8, 95.6, 100.0, 102.5])
		g.x_ai.lane_targets.assign(g.lane_offsets)
		g.x_ai.lane_lock.fill(60.0)
		g.speeds.fill(10.0)
		g.baseline_speed = 10.0
		g.running = true
		g.start_state = "RACING"
		g.trainer_seen = true
		var first_space := -1.0
		var max_offset := g.lane_offsets[0]
		for frame in range(121):
			g.watts = 320.0
			if frame in range(10, 40) and tactic == "accelerate":
				g.watts = 650.0
			elif frame in range(10, 40) and tactic == "ease_off":
				g.watts = 80.0
			if (frame == 5 and tactic.begins_with("steer_")) or (frame == 58 and tactic == "steer_twice"):
				g._steer_player(1)
			g.clock += 0.1
			g._update_race(0.1)
			max_offset = maxf(max_offset, g.lane_offsets[0])
			if first_space < 0.0 and normal_outward_space(g):
				first_space = g.clock
		var row := {"tactic": tactic, "initial_lane": 1.18, "max_lane": max_offset,
			"final_lane": g.lane_offsets[0], "first_normal_exit_s": first_space, "blocks": g.intervals,
			"open_blocks": g.opened, "overlap_samples": g.overlap_samples, "penalty_j": g.penalty_j,
			"final_distance": g.distances[0], "final_speed_ms": g.speeds[0]}
		if "elimination_push" in g:
			row["pushes"] = g.get("elimination_push").statistics()
		print("PUSH_SCENARIO ", JSON.stringify(row))
		g.free()
	quit()
