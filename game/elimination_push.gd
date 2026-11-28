extends RefCounted
## One outward reservation at a time. Timers use the fixed elimination clock.
const Motion := preload("res://elimination_motion.gd")
const DISTANCE_M := 0.30
const POWER_W := 50.0
const DURATION_S := 5.0
const PASSIVE_HOLD_S := 1.2
const AI_BLOCKED_S := 3.0
const AI_SPRINT_DISTANCE_M := 115.0
const AI_MIN_POWER_EXCESS_W := 35.0
const AI_MAX_WHEEL_GAP_M := 4.5
const EPSILON := 0.00001

var ends: Dictionary = {}
var initiator := -1
var remaining_m := 0.0
var held_until: Dictionary = {}
var effort_until: Dictionary = {}
var attempts: Array[Dictionary] = []

func seconds_left(rider: int, clock: float) -> float:
	return maxf(0.0, float(effort_until.get(rider, 0.0)) - clock)

func drive_power(rider: int, delivered: float, clock: float) -> float:
	return maxf(0.0, delivered - POWER_W) if seconds_left(rider, clock) > EPSILON else delivered

func held(rider: int, clock: float) -> bool:
	return ends.has(rider) or clock < float(held_until.get(rider, 0.0))

func endpoint(rider: int, lane: float) -> float:
	return float(ends.get(rider, lane))

static func blocked(a: int, b: int, target: float, other_target: float, lanes: Array[float],
		distances: Array[float], speeds: Array[float], metrics: Array[float], horizon: float) -> bool:
	if Motion.laterally_separate(lanes[a], target, lanes[b], other_target):
		return false
	if Motion.moving_apart(lanes[a], target, lanes[b], other_target):
		return false
	var gap := Motion.signed_gap(distances[a], distances[b])
	var relative := speeds[b] / metrics[b] - speeds[a] / metrics[a]
	var clearance := Motion.MERGE_GAP
	if absf(lanes[a] - lanes[b]) < Motion.LATERAL_CLEARANCE and absf(target - other_target) >= absf(lanes[a] - lanes[b]) - EPSILON:
		clearance = Motion.MIN_GAP
	return not Motion.leaves_safely(gap, relative, horizon, clearance)

func try_start(rider: int, target: float, outside: float, clock: float, lateral_speed: float,
		lanes: Array[float], distances: Array[float], speeds: Array[float],
		metrics: Array[float], finished: Array[float], sprint_distance: float) -> bool:
	var travel := minf(DISTANCE_M, minf(target, outside) - lanes[rider])
	if travel <= EPSILON or finished[rider] >= 0.0:
		return false
	var horizon := DISTANCE_M / lateral_speed
	var group: Array[int] = [rider]
	var destinations := {rider: lanes[rider] + travel}
	var rejection := ""
	var cursor := 0
	while cursor < group.size() and rejection.is_empty():
		var member := group[cursor]
		var end := float(destinations[member])
		if end > outside + EPSILON:
			rejection = "edge"
			break
		destinations[member] = minf(end, outside)
		for other in range(lanes.size()):
			if destinations.has(other) or finished[other] >= 0.0:
				continue
			if not blocked(member, other, end, lanes[other], lanes, distances, speeds, metrics, horizon):
				continue
			if lanes[other] <= lanes[member]:
				rejection = "clearance"
				break
			group.append(other)
			destinations[other] = lanes[other] + DISTANCE_M
		cursor += 1
	if group.size() == 1:
		return false
	if rejection.is_empty():
		for a in group:
			for b in group:
				if b <= a:
					continue
				if blocked(a, b, destinations[a], destinations[b], lanes, distances, speeds, metrics, horizon):
					rejection = "clearance"
	if not ends.is_empty():
		rejection = "busy"
	elif seconds_left(rider, clock) > EPSILON:
		rejection = "cooldown"
	attempts.append({"rider": rider, "time": clock, "sprint_m": sprint_distance,
		"displaced": group.slice(1), "rejection": rejection})
	if not rejection.is_empty():
		return false
	initiator = rider
	ends = destinations
	remaining_m = DISTANCE_M
	effort_until[rider] = clock + DURATION_S
	return true

func glide(lanes: Array[float], requested: Array[float], finished: Array[float], step: float) -> void:
	var fraction := minf(1.0, step / remaining_m)
	for rider in ends:
		if finished[rider] < 0.0:
			requested[rider] = lerpf(lanes[rider], ends[rider], fraction)

func advance(step: float, clock: float) -> void:
	remaining_m = maxf(0.0, remaining_m - step)
	if remaining_m > EPSILON:
		return
	for rider in ends:
		if rider != initiator:
			held_until[rider] = clock + PASSIVE_HOLD_S
	ends.clear()
	initiator = -1

func statistics() -> Array[Dictionary]:
	return attempts
