extends RefCounted
## Cumulative odometer distances stay intact. Race positions remove awarded laps.
const LAP := 250.0
var previous_ids: Array[int] = []

static func race_positions(progress: Array[float], credits: Array[int]) -> Array[float]:
	var result: Array[float] = []
	for i in range(progress.size()): result.append(progress[i] - float(credits[i]) * LAP)
	return result

func reset() -> void: previous_ids.clear()

func sample(progress: Array[float], credits: Array[int], finished: Array[float]) -> Dictionary:
	var order: Array[int] = []
	for i in range(progress.size()):
		if finished.is_empty() or finished[i] < 0.0: order.append(i)
	if order.size() < 3: return {}
	order.sort_custom(func(a: int, b: int) -> bool: return fposmod(progress[a],LAP) < fposmod(progress[b],LAP))
	var cut := 0
	var longest := -1.0
	for i in range(order.size()):
		var gap: float = fposmod(progress[order[(i+1)%order.size()]] - progress[order[i]],LAP)
		if gap > longest: longest = gap; cut = i
	var groups: Array = []
	for index in range(order.size()):
		var i: int = order[(cut+1+index)%order.size()]
		if groups.is_empty() or fposmod(progress[i]-progress[int(groups[-1][-1])],LAP) > 12.0:
			groups.append([i])
		else: groups[-1].append(i)
	var group: Array = []
	var continuity := -1
	for candidate in groups:
		var overlap := 0
		for i in candidate:
			if previous_ids.has(i): overlap += 1
		if candidate.size() > group.size() or (candidate.size() == group.size() and overlap > continuity):
			group = candidate; continuity = overlap
	if group.size() < 3: return {}
	var positions := race_positions(progress,credits)
	var values: Array[float] = []
	for i in group: values.append(positions[i])
	values.sort()
	var anchor: float = values[values.size()/2]
	if values.size()%2 == 0: anchor = 0.5*(anchor+values[values.size()/2-1])
	var tail := INF
	var front := -INF
	for i in group:
		var aligned: float = positions[i]-round((positions[i]-anchor)/LAP)*LAP
		tail = minf(tail,aligned); front = maxf(front,aligned)
	if front-tail > LAP*0.5: return {}
	previous_ids.assign(group)
	return {"ids":previous_ids.duplicate(),"tail":tail,"front":front,"center":0.5*(tail+front)}

static func gap_text(position: float, bunch: Dictionary) -> String:
	if bunch.is_empty(): return "Peloton niet gevormd"
	if position > float(bunch.front)+1.0: return "%.0f m vóór peloton" % (position-float(bunch.front))
	if position < float(bunch.tail)-1.0: return "%.0f m achter peloton" % (float(bunch.tail)-position)
	return "In het peloton"
