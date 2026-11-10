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
var pending_gains: Dictionary = {} # Hold gains until a protected sprint-line crossing
var peloton = preload("res://peloton_state.gd").new()

func reset(count: int, race_laps: int = 40) -> void:
	assert(count >= 4 and race_laps >= INTERVAL and race_laps % INTERVAL == 0)
	laps = race_laps
	for values in [points, credits, gains, losses]:
		values.resize(count)
		values.fill(0)
	sprints.clear(); events.clear(); main_ids.clear(); pending_gains.clear()
	peloton.reset()
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
	var bunch: Dictionary = peloton.sample(distances, credits, [])
	if bunch.is_empty(): return
	main_ids.assign(bunch.ids)
	var positions: Array[float] = preload("res://peloton_state.gd").race_positions(distances, credits)
	for i in range(distances.size()):
		var change := 0
		if positions[i] - float(bunch.tail) >= LAP - 0.00000001: change = 1
		elif float(bunch.front) - positions[i] >= LAP - 0.00000001: change = -1
		if change == 0 or pending_gains.has(i): continue
		# Preserve sprint eligibility when the bunch is caught inside the last 100 m.
		var upcoming_lap: int = floori(distances[i] / LAP) + 1 - credits[i]
		var metres_to_line: float = LAP - fposmod(distances[i], LAP)
		if change > 0 and metres_to_line <= 100.0 and upcoming_lap == next_sprint_lap():
			pending_gains[i] = true
			continue
		_award_lap(i, change, seconds)

func _award_lap(i: int, change: int, seconds: float) -> void:
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
	for crossing in crossings:
		if finish_clock < 0.0:
			_judge_laps(_interpolate(previous, current, seconds, dt, crossing.seconds), crossing.seconds)
		var race_lap: int = int(crossing.lap) - credits[int(crossing.rider)]
		if race_lap == laps and finish_clock < 0.0: finish_clock = crossing.seconds
		var exists := false
		for sprint in sprints:
			if sprint.lap == race_lap: exists = true
		if race_lap > 0 and race_lap <= laps and race_lap % INTERVAL == 0 and not exists:
			sprints.append({"lap": race_lap, "seconds": crossing.seconds, "order": [], "times": [], "awards": []})
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
		# Sprint points are awarded before this rider's provisional lap bonus.
		if pending_gains.has(int(crossing.rider)):
			pending_gains.erase(int(crossing.rider))
			_award_lap(int(crossing.rider), 1, crossing.seconds)

	if finish_clock < 0.0: _judge_laps(current, seconds)

func _interpolate(previous: Array[float], current: Array[float], seconds: float, dt: float, at: float) -> Array[float]:
	var result: Array[float] = []
	var fraction: float = clampf((at-seconds+dt)/maxf(dt,0.000000001),0.,1.)
	for i in range(current.size()): result.append(lerpf(previous[i],current[i],fraction))
	return result

func notice(leader_distance: float) -> String:
	if complete(): return "Puntenkoers afgelopen · jouw score: %d punten" % points[0]
	if finish_clock >= 0.0: return "Laatste sprint · uitslag wordt aangevuld · %d punten" % points[0]
	var next: int = next_sprint_lap()
	var remaining: float = maxf(0.0, next * LAP - leader_distance)
	var title: String = "DUBBELE EINDSPRINT" if next == laps else "SPRINT"
	return "%d punten · %s over %.0f m (ronde %d)" % [points[0], title, remaining, next]
