extends RefCounted
## Scratch classification and physical peloton lapping on a 250 m closed track.
## IMPORTANT: all distances are cumulative, NOT modulo distances.
const LAP_M := 250.0
const CONTACT_BEHIND_M := 2.0
const CLUSTER_GAP_M := 12.0
var credits: Array[int] = []
var events: Array[Dictionary] = []
var previous_progress: Array[float] = []
var finish_clock := -1.0

func reset(count: int) -> void:
	finish_clock = -1.0
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

func advance(previous: Array[float], current: Array[float], seconds: float, dt: float, finish_times: Array[float], laps: int) -> void:
	# Keep odometers intact; a lap gained changes classification, not the finish line.
	if previous_progress.size() != previous.size(): previous_progress = previous.duplicate()
	var crossings: Array[Dictionary] = []
	for i in range(current.size()):
		if finish_times[i] >= 0.0: continue
		for lap in range(maxi(1, floori(previous[i] / LAP_M) + 1), floori(current[i] / LAP_M) + 1):
			var fraction: float = (lap * LAP_M - previous[i]) / maxf(0.000000001, current[i] - previous[i])
			crossings.append({"rider": i, "lap": lap, "seconds": seconds - dt + dt * fraction})
	crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.rider < b.rider if a.seconds == b.seconds else a.seconds < b.seconds)
	for crossing in crossings:
		if finish_clock < 0.0:
			var at: Array[float] = []
			var fraction: float = clampf((crossing.seconds - seconds + dt) / maxf(dt, 0.000000001), 0.0, 1.0)
			for i in range(current.size()): at.append(lerpf(previous[i], current[i], fraction))
			examine(at, finish_times, crossing.seconds)
			if int(crossing.lap) - credits[int(crossing.rider)] >= laps:
				finish_clock = crossing.seconds
		if finish_clock >= 0.0 and finish_times[crossing.rider] < 0.0:
			finish_times[crossing.rider] = crossing.seconds
	if finish_clock < 0.0: examine(current, finish_times, seconds)
