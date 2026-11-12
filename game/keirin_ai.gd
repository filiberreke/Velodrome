extends "res://x_scratch_ai.gd"
## Keirin uses the game's calibrated CP/W', not the standalone Python constants.
var sprint_threshold: Array[float] = []
var sprint_start_s: Array[float] = []
var sprint_start_remaining_m: Array[float] = []
var forced_follow_s: Array[float] = []
var all_ai := false # Headless diagnostic only; normal player power remains untouched.

func reset(profiles: Array[int], forms: Array[float], initial_lanes: Array[float]) -> void:
	super.reset(profiles, forms, initial_lanes)
	sprint_threshold.resize(profiles.size()); sprint_threshold.fill(-1.0)
	sprint_start_s.resize(profiles.size()); sprint_start_s.fill(-1.0)
	sprint_start_remaining_m.resize(profiles.size()); sprint_start_remaining_m.fill(-1.0)
	forced_follow_s.resize(profiles.size()); forced_follow_s.fill(0.0)
	if all_ai and cp.size() > 0:
		cp[0] = CP[2]; wmax[0] = WMAX[2]; pmax[0] = PMAX[2]; wprime[0] = wmax[0]

func corridor_clear(i: int, target: float, positions: Array[float], speeds: Array[float], lanes: Array[float], finished: Array[float]) -> bool:
	var low := minf(target, lanes[i]) - 0.85
	var high := maxf(target, lanes[i]) + 0.85
	var horizon := absf(target - lanes[i]) / 1.15 + 0.35
	for j in range(positions.size()):
		if j == i or finished[j] >= 0.0: continue
		var other_low := minf(lanes[j], lane_targets[j])
		var other_high := maxf(lanes[j], lane_targets[j])
		if other_high <= low or other_low >= high: continue
		var gap := positions[j] - positions[i]
		var future := gap + (speeds[j] - speeds[i]) * horizon
		if gap * future <= 0.0 or minf(absf(gap), absf(future)) < 2.0: return false
	return true

func step_keirin(dt: float, clock: float, finish_m: float, positions: Array[float], speeds: Array[float], lanes: Array[float], drafts: Array[float], finished: Array[float], difficulty: float) -> Array[float]:
	var output: Array[float] = []; output.resize(positions.size()); output.fill(0.0)
	for i in range(0 if all_ai else 1, positions.size()):
		if finished[i] >= 0.0: continue
		var remaining := maxf(0.0, finish_m - positions[i])
		if sprint_threshold[i] < 0.0:
			# Reserve-aware individual launch, based on OWN remaining distance.
			var duration := wprime[i] / maxf(1.0, pmax[i] - cp[i]) * rng.randf_range(0.72, 0.88)
			sprint_threshold[i] = clampf(maxf(14.0, speeds[i] + 2.0) * duration, 140.0, 700.0)
		if not sprint_started[i] and remaining <= sprint_threshold[i]:
			sprint_started[i] = true
			sprint_start_s[i] = clock
			sprint_start_remaining_m[i] = remaining
		var wheel := -1
		var gap := INF
		for j in range(positions.size()):
			if j == i or finished[j] >= 0.0: continue
			var ahead := positions[j] - positions[i]
			if ahead > 0.0 and ahead < gap:
				gap = ahead; wheel = j
		var aero := 1.0 - clampf(drafts[i], 0.0, 0.88)
		var wanted := road_power(speeds[i], aero) / DRIVETRAIN
		if wheel >= 0:
			var target_speed := speeds[wheel] + clampf((gap - 2.5) * 0.65, -0.3, 2.0)
			var acceleration := clampf((target_speed - speeds[i]) * 0.9, -1.0, 1.4)
			wanted = maxf(0.0, (road_power(speeds[i], aero) + MASS * maxf(speeds[i], 5.0) * acceleration) / DRIVETRAIN)
			if not sprint_started[i] and wanted > cp[i]: forced_follow_s[i] += dt
		if sprint_started[i]:
			wanted = pmax[i]
			if wheel >= 0 and gap < 6.0:
				var other := 2.38 if lanes[i] < 1.78 else 1.18
				if corridor_clear(i, other, positions, speeds, lanes, finished): lane_targets[i] = other
		# A blocked rider follows at the required power, saving the unused reserve.
		for j in range(positions.size()):
			if j == i or finished[j] >= 0.0: continue
			var separation := positions[j] - positions[i]
			if separation > 0.0 and separation < 4.5 and absf(lanes[j] - lanes[i]) < 0.85:
				var safe_speed := maxf(0.0, speeds[j] + (separation - 2.0) * 0.7)
				var safe_accel := clampf((safe_speed - speeds[i]) / maxf(dt, 0.001), -2.2, 1.4)
				var safe_power := maxf(0.0, (road_power(speeds[i], aero) + MASS * maxf(speeds[i],5.0) * safe_accel) / DRIVETRAIN)
				wanted = minf(wanted, safe_power)
		output[i] = _phys_power(i, wanted, dt)
		power_w[i] = output[i]
	return output
