extends RefCounted
## Scratch classification and physical peloton lapping on a 250 m closed track.
## IMPORTANT: all distances are cumulative, NOT modulo distances.
const LAP_M := 250.0
const CONTACT_BEHIND_M := 2.0
const CLUSTER_GAP_M := 12.0
var credits: Array[int] = []
var events: Array[Dictionary] = []
var previous_progress: Array[float] = []

func reset(count: int) -> void:
	credits.resize(count)
	credits.fill(0)
	previous_progress.clear()
	events.clear()

static func ahead_gap(follower_m: float, leader_m: float) -> float:
	# Geometric gap from one wheel to the next, wrapping across the start line.
	# Absolute lap advantage remains stored separately.
	return fposmod(leader_m - follower_m, LAP_M)

func examine(progress: Array[float], finished: Array[float], seconds: float) -> void:
	if previous_progress.size() != progress.size():
		previous_progress = progress.duplicate()
		return
	# Largest compact reference group of still-active, not-yet-lapped cyclists.
	# A genuine lapping requires a *crossing* of the 248 m contact threshold;
	# merely being close in modulo geometry must not grant a lap.
	var ordinary: Array[int] = []
	for i in range(progress.size()):
		if credits[i] == 0 and finished[i] < 0.0:
			ordinary.append(i)
	ordinary.sort_custom(func(a: int, b: int) -> bool: return progress[a] < progress[b])
	var clusters: Array = []
	for i in ordinary:
		if clusters.is_empty() or progress[i] - progress[int(clusters[-1][-1])] > CLUSTER_GAP_M:
			clusters.append([i])
		else:
			clusters[-1].append(i)
	var bunch: Array = []
	for group in clusters:
		if group.size() > bunch.size():
			bunch = group
	if bunch.size() >= 3:
		var tail: int = int(bunch[0])
		var middle: int = int(bunch[bunch.size() / 2])
		for i in range(progress.size()):
			if credits[i] != 0 or finished[i] >= 0.0 or bunch.has(i):
				continue
			var gap_now: float = progress[i] - progress[tail]
			var gap_old: float = previous_progress[i] - previous_progress[tail]
			# The escape passes to within two metres behind the reference tail.
			if gap_old < LAP_M - CONTACT_BEHIND_M and gap_now >= LAP_M - CONTACT_BEHIND_M and gap_now <= LAP_M + 0.5 and progress[i] - progress[middle] >= 215.0:
				credits[i] = 1
				events.append({"rider": i, "kind": "gain", "time_s": seconds, "physical_gap_m": maxf(0.0, LAP_M - gap_now), "bunch_size": bunch.size()})
		# A rider can also *lose* a lap when the reference bunch catches him.
		# This uses the same circular geometry and a crossing, never rank alone.
		for i in range(progress.size()):
			if credits[i] != 0 or finished[i] >= 0.0 or bunch.has(i):
				continue
			var loss_now: float = progress[tail] - progress[i]
			var loss_old: float = previous_progress[tail] - previous_progress[i]
			if loss_old < LAP_M - CONTACT_BEHIND_M and loss_now >= LAP_M - CONTACT_BEHIND_M and loss_now <= LAP_M + 0.5 and progress[middle] - progress[i] >= 215.0:
				credits[i] = -1
				events.append({"rider": i, "kind": "loss", "time_s": seconds, "physical_gap_m": maxf(0.0, LAP_M - loss_now), "bunch_size": bunch.size()})
	previous_progress = progress.duplicate()

func better(a: int, b: int, finish_times: Array[float], progress: Array[float]) -> bool:
	if credits[a] != credits[b]:
		return credits[a] > credits[b]
	var af: bool = finish_times[a] >= 0.0
	var bf: bool = finish_times[b] >= 0.0
	if af and bf:
		return finish_times[a] < finish_times[b]
	if af != bf:
		return af
	return progress[a] > progress[b]
