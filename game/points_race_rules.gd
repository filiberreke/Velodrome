extends RefCounted
## Points jury: one leader clock, physical line passages and repeatable lap events.
const LAP := 250.0
const INTERVAL := 10
var points: Array[int] = []
var credits: Array[int] = []
var gains: Array[int] = []
var losses: Array[int] = []
var sprints: Array[Dictionary] = []
var events: Array[Dictionary] = []
var laps := 40
var finish_clock := -1.0
var last_sprint_clock := -1.0
var main_ids: Array[int] = []

func reset(count: int, race_laps: int = 40) -> void:
	assert(count >= 4 and race_laps >= INTERVAL and race_laps % INTERVAL == 0)
	laps = race_laps
	for values in [points, credits, gains, losses]:
		values.resize(count)
		values.fill(0)
	sprints.clear(); events.clear(); main_ids.clear()
	finish_clock = -1.0
	last_sprint_clock = -1.0

func next_sprint_lap() -> int:
	for lap in range(INTERVAL, laps + 1, INTERVAL):
		var complete := false
		for sprint in sprints:
			if sprint.lap == lap and sprint.order.size() == points.size():
				complete = true
		if not complete:
			return lap
	return -1

func complete() -> bool:
	return not sprints.is_empty() and sprints[-1].lap == laps and sprints[-1].order.size() == points.size()

func better(a: int, b: int, distances: Array[float]) -> bool:
	if points[a] != points[b]:
		return points[a] > points[b]
	if not sprints.is_empty() and sprints[-1].lap == laps:
		var order: Array = sprints[-1].order
		var first: int = order.find(a)
		var second: int = order.find(b)
		if first >= 0 or second >= 0:
			return first >= 0 and (second < 0 or first < second)
	return distances[a] > distances[b] if not is_equal_approx(distances[a], distances[b]) else a < b

func _judge_laps(distances: Array[float], seconds: float) -> void:
	var order: Array[int] = []
	for i in range(distances.size()): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return fposmod(distances[a], LAP) < fposmod(distances[b], LAP))
	var cut := 0
	var biggest := -1.0
	for i in range(order.size()):
		var gap: float = fposmod(distances[order[(i + 1) % order.size()]] - distances[order[i]], LAP)
		if gap > biggest:
			biggest = gap; cut = i
	var rotated: Array[int] = []
	for i in range(order.size()): rotated.append(order[(cut + 1 + i) % order.size()])
	var groups: Array = []
	for i in rotated:
		if groups.is_empty() or fposmod(distances[i] - distances[int(groups[-1][-1])], LAP) > 12.0:
			groups.append([i])
		else:
			groups[-1].append(i)
	var group: Array = []
	var continuity := -1
	for candidate in groups:
		var overlap := 0
		for i in candidate:
			if main_ids.has(i): overlap += 1
		if candidate.size() > group.size() or (candidate.size() == group.size() and overlap > continuity):
			group = candidate; continuity = overlap
	if group.size() < 3: return
	var adjusted: Array[float] = []
	for i in range(distances.size()): adjusted.append(distances[i] - credits[i] * LAP)
	var sample: Array[float] = []
	for i in group: sample.append(adjusted[i])
	sample.sort()
	var anchor: float = sample[sample.size() / 2]
	if sample.size() % 2 == 0: anchor = 0.5 * (anchor + sample[sample.size() / 2 - 1])
	var tail := INF
	var front := -INF
	for i in group:
		var aligned: float = adjusted[i] - round((adjusted[i] - anchor) / LAP) * LAP
		tail = minf(tail, aligned); front = maxf(front, aligned)
	if front - tail > LAP * 0.5: return
	main_ids.assign(group)
	# Immutable bunch reference for simultaneous catches, including the human.
	for i in range(distances.size()):
		var change := 0
		if adjusted[i] - tail >= LAP - 0.00000001: change = 1
		elif front - adjusted[i] >= LAP - 0.00000001: change = -1
		if change == 0: continue
		credits[i] += change
		points[i] += 20 * change
		if change > 0: gains[i] += 1
		else: losses[i] += 1
		events.append({"rider": i, "delta": change, "points": 20 * change, "seconds": seconds})

func advance(previous: Array[float], current: Array[float], seconds: float, dt: float, finish_times: Array[float]) -> void:
	var crossings: Array[Dictionary] = []
	for i in range(current.size()):
		if finish_times[i] >= 0.0: continue
		for lap in range(maxi(1, floori(previous[i] / LAP) + 1), floori(current[i] / LAP) + 1):
			var fraction: float = (lap * LAP - previous[i]) / maxf(0.000000001, current[i] - previous[i])
			crossings.append({"rider": i, "lap": lap, "seconds": seconds - dt + dt * fraction})
	crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.rider < b.rider if a.seconds == b.seconds else a.seconds < b.seconds)
	if finish_clock < 0.0:
		for crossing in crossings:
			if crossing.lap == laps:
				finish_clock = crossing.seconds
				break
	var cutoff: float = minf(seconds, finish_clock) if finish_clock >= 0.0 else seconds
	if cutoff > seconds - dt:
		var positions: Array[float] = []
		var fraction: float = clampf((cutoff - seconds + dt) / maxf(dt, 0.000000001), 0.0, 1.0)
		for i in range(current.size()): positions.append(lerpf(previous[i], current[i], fraction))
		_judge_laps(positions, cutoff)
	for crossing in crossings:
		var exists := false
		for sprint in sprints:
			if sprint.lap == crossing.lap: exists = true
		if crossing.lap <= laps and crossing.lap % INTERVAL == 0 and not exists:
			sprints.append({"lap": crossing.lap, "seconds": crossing.seconds, "order": [], "times": [], "awards": []})
			last_sprint_clock = crossing.seconds
		for sprint in sprints:
			if crossing.seconds < sprint.seconds or sprint.order.has(crossing.rider): continue
			var rewards: Array = [10, 6, 4, 2] if sprint.lap == laps else [5, 3, 2, 1]
			var place: int = sprint.order.size()
			var award: int = rewards[place] if place < rewards.size() else 0
			sprint.order.append(crossing.rider)
			sprint.times.append(crossing.seconds)
			sprint.awards.append(award)
			points[crossing.rider] += award
			if sprint.lap == laps: finish_times[crossing.rider] = crossing.seconds

func notice(leader_distance: float) -> String:
	if complete(): return "Puntenkoers afgelopen · jouw score: %d punten" % points[0]
	if finish_clock >= 0.0: return "Laatste sprint · uitslag wordt aangevuld · %d punten" % points[0]
	var next: int = next_sprint_lap()
	var remaining: float = maxf(0.0, next * LAP - leader_distance)
	var title: String = "DUBBELE EINDSPRINT" if next == laps else "SPRINT"
	return "%d punten · %s over %.0f m (ronde %d)" % [points[0], title, remaining, next]
