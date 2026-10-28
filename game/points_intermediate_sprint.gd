extends RefCounted
## TUSSENSPRINT: the tested Python policy, separate from final sprint/physiology.
## Forecasts are heuristic. This class requests watts; it never spends Wprime
## or changes actual speed, position, lanes, CP, Wmax or peak power.
const SharedAI := preload("res://x_scratch_ai.gd")
const LAP := 250.0
const REWARDS := [5.0, 3.0, 2.0, 1.0]
var attempting: Array[bool] = []
var aborts: Array[int] = []
var last_decisions: Array[Dictionary] = []
var prepared := false
var sprint_lap := -1
var race_laps := 40
var leader_distance := 0.0
var etas: Dictionary = {}
var saved_cp: Array[float] = []
var saved_w: Array[float] = []
var saved_wmax: Array[float] = []
var saved_pmax: Array[float] = []
var saved_speed: Array[float] = []
var saved_distance: Array[float] = []
var saved_points: Array[int] = []

func reset(count: int) -> void:
	attempting.resize(count); attempting.fill(false)
	aborts.resize(count); aborts.fill(0)
	last_decisions.clear()
	for i in range(count): last_decisions.append({})
	prepared = false
	etas.clear()

static func place_probabilities(own_eta: float, others: Array[float]) -> Array[float]:
	# Poisson-binomial finishing ranks with independent logistic ETA uncertainty.
	# These are decision weights, not empirically calibrated race probabilities.
	var distribution: Array[float] = [1.0]
	for eta in others:
		var beats_us: float = 1.0 / (1.0 + exp(clampf((eta - own_eta) / 1.3, -40.0, 40.0)))
		var updated: Array[float] = []
		updated.resize(distribution.size() + 1); updated.fill(0.0)
		for rank in range(distribution.size()):
			updated[rank] += distribution[rank] * (1.0 - beats_us)
			updated[rank + 1] += distribution[rank] * beats_us
		distribution = updated
	while distribution.size() < 4: distribution.append(0.0)
	return distribution.slice(0, 4)

static func preview_speed(speed: float, power: float) -> float:
	# Same 2 s / 0.25 s hypothetical forecast as the Python experiment, at
	# assumed aero factor .85. Actual Godot physics is untouched.
	var v: float = speed
	for substep in range(8):
		var resistance: float = (267.0 / 1331.0) * 0.85 * v * v * v + 0.004 * 80.0 * 9.81 * v
		v = sqrt(maxf(0.0, v * v + (0.5 / 80.0) * (maxf(0.0, power) * 0.975 - resistance)))
	return v

func prepare(ai, distances: Array[float], speeds: Array[float], finished: Array[float], profiles: Array[int], laps: int, leader: float, jury) -> void:
	sprint_lap = jury.next_sprint_lap()
	race_laps = laps
	leader_distance = leader
	prepared = false
	etas.clear()
	if attempting.size() != profiles.size(): reset(profiles.size())
	var remaining: float = sprint_lap * LAP - leader
	if jury.finish_clock >= 0.0 or sprint_lap <= 0 or sprint_lap >= laps or remaining <= 0.0 or remaining > LAP:
		attempting.fill(false)
		for i in range(last_decisions.size()): last_decisions[i] = {}
		return
	saved_cp.assign(ai.cp); saved_w.assign(ai.wprime)
	saved_wmax.assign(ai.wmax); saved_pmax.assign(ai.pmax)
	saved_speed.assign(speeds); saved_distance.assign(distances)
	saved_points.assign(jury.points)
	var fastest := 5.0
	for i in range(profiles.size()):
		if finished[i] < 0.0: fastest = maxf(fastest, speeds[i])
	var opening: float = remaining / fastest
	for i in range(profiles.size()):
		if finished[i] >= 0.0: continue
		var distance: float = fposmod(-distances[i], LAP)
		if distance / maxf(speeds[i], 5.0) < opening - 1.0: distance += LAP
		var seconds: float = maxf(5.0, distance / maxf(speeds[i], 5.0))
		# The human is a normal competitor in the forecast. No invented human
		# CP/Wprime and no write to their trainer/demo watts.
		var power: float = maxf(0.0, ai.human_power_w)
		if profiles[i] > 0:
			var budget: float = saved_cp[i] + 0.65 * saved_w[i] / seconds
			power = minf(SharedAI.pcurve(seconds, saved_cp[i], saved_wmax[i], saved_pmax[i]), budget)
		var projected: float = preview_speed(speeds[i], power)
		etas[i] = distance / maxf(5.0, 0.45 * speeds[i] + 0.55 * projected)
	prepared = true

func demand(i: int, target: float, kind: int) -> float:
	if not prepared or i <= 0 or not etas.has(i): return target
	var others: Array[float] = []
	for ident in etas:
		if ident != i: others.append(float(etas[ident]))
	var probabilities := place_probabilities(float(etas[i]), others)
	var expected := 0.0
	var chance := 0.0
	for rank in range(4):
		expected += probabilities[rank] * REWARDS[rank]
		chance += probabilities[rank]
	var future := 0
	# The points jury schedules every ten laps; include the double final as
	# a future opportunity, exactly as in the tested 40-lap experiment.
	for lap in range(10, race_laps + 1, 10):
		if lap > sprint_lap: future += 1
	var remaining_fraction: float = clampf((race_laps * LAP - leader_distance) / (race_laps * LAP), 0.0, 1.0)
	var score_gap: int = int(saved_points.max()) - saved_points[i]
	var opportunity: float = clampf(expected / 5.0, 0.0, 1.0)
	var urgency: float = 0.06 if score_gap > 0 and score_gap <= 5 and sprint_lap >= 30 else 0.0
	var reserve_fraction: float = clampf(0.18 + 0.24 * remaining_fraction + 0.035 * future - 0.12 * opportunity - urgency, 0.15, 0.55)
	var reserve_j: float = saved_wmax[i] * reserve_fraction
	var available: float = maxf(0.0, saved_w[i] - reserve_j)
	var seconds: float = maxf(5.0, float(etas[i]))
	var own_distance: float = fposmod(-saved_distance[i], LAP)
	var own_seconds: float = maxf(5.0, own_distance / maxf(saved_speed[i], 5.0))
	var factor: float = 0.75 if kind == 1 else (0.99 if kind == 2 else 0.87)
	var effort: float = SharedAI.pcurve(own_seconds, saved_cp[i], saved_wmax[i], saved_pmax[i]) * factor
	var old_budget: float = saved_cp[i] + 0.88 * saved_w[i] / maxf(6.0, own_seconds)
	var sprint_budget: float = saved_cp[i] + available / seconds
	var requested: float = minf(minf(effort, old_budget), sprint_budget)
	var viable: bool = chance >= 0.23 and expected >= 0.45 and available >= 500.0
	var was_attempting: bool = attempting[i]
	var action: String = "sprint" if viable else ("abort" if was_attempting else "skip")
	var result: float = minf(maxf(target, requested), sprint_budget) if viable else (minf(target, saved_cp[i] * 0.90) if was_attempting else target)
	attempting[i] = viable
	if action == "abort": aborts[i] += 1
	last_decisions[i] = {"lap":sprint_lap,"action":action,"p5":probabilities[0],"p3":probabilities[1],"p2":probabilities[2],"p1":probabilities[3],"expected_points":expected,"reserve_j":reserve_j,"w_j":saved_w[i],"target_w":result}
	return result
