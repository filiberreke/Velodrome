extends RefCounted
## Lane requests only. Power, speed and collision limits remain in main.gd.
const CLEARANCE := 0.88
const FOLLOWING := 2.2
var enabled := false
var manual_until := -1.0
var blocked_until := -1.0
var target := -1.0

func reset() -> void:
	enabled = false
	manual_until = -1.0
	blocked_until = -1.0
	target = -1.0

func manual(clock: float) -> void:
	manual_until = clock + 2.0
	target = -1.0

func observe(clock: float, requested: float, actual: float, dt: float) -> void:
	# Compare actual travelled metres after the shared collision pass with the
	# unconstrained physical step; ordinary drafting never triggers this.
	if dt > 0.0 and requested - actual > 0.03 * dt:
		blocked_until = clock + 0.45

func corridor_clear(candidate: float, distances: Array[float], speeds: Array[float], lanes: Array[float], done: Array[float], requests: Array[float], lateral_speed: float) -> bool:
	var low := minf(lanes[0], candidate) - CLEARANCE
	var high := maxf(lanes[0], candidate) + CLEARANCE
	var horizon := absf(candidate - lanes[0]) / maxf(0.1, lateral_speed) + 0.5
	for j in range(1, distances.size()):
		if done[j] >= 0.0: continue
		# Include the AI's intended swept corridor, and closing traffic behind.
		if maxf(lanes[j], requests[j]) <= low or minf(lanes[j], requests[j]) >= high: continue
		var gap := fposmod(distances[j] - distances[0] + 125.0, 250.0) - 125.0
		var future := gap + (speeds[j] - speeds[0]) * horizon
		var nearest := 0.0 if gap * future <= 0.0 else minf(absf(gap), absf(future))
		# Allow leaving the wheel that caused the block, provided its gap is
		# not already overlapping. All other crossed corridors need merge room.
		var leaving_wheel := absf(lanes[j] - lanes[0]) < CLEARANCE and absf(lanes[j] - candidate) >= CLEARANCE and gap >= FOLLOWING - 0.01
		if nearest < (FOLLOWING - 0.01 if leaving_wheel else 4.5): return false
	return true

func lane(clock: float, distances: Array[float], speeds: Array[float], lanes: Array[float], done: Array[float], requests: Array[float], choices: Array, lateral_speed: float) -> float:
	if not enabled or clock < manual_until or done[0] >= 0.0: return -1.0
	if target >= 0.0:
		if absf(target - lanes[0]) < 0.02:
			target = -1.0
		else:
			if corridor_clear(target, distances, speeds, lanes, done, requests, lateral_speed): return target
			# Stop at the actual position and retry when the hazard clears.
			return lanes[0]
	if clock >= blocked_until: return -1.0
	for candidate in choices:
		if absf(float(candidate) - lanes[0]) < CLEARANCE or absf(float(candidate) - lanes[0]) > 1.5: continue
		if corridor_clear(float(candidate), distances, speeds, lanes, done, requests, lateral_speed):
			target = float(candidate)
			return target
	return -1.0

func notice(clock: float) -> String:
	if clock >= blocked_until: return ""
	return "GEBLOKKEERD · VERMOGEN BEPERKT · " + ("inhaalhulp zoekt veilige ruimte" if enabled and clock >= manual_until else "stuur naar een vrije rijlijn")
