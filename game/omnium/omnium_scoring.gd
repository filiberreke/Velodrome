extends RefCounted
static func place_points(place: int) -> int:
	if place < 1 or place > 24: return 0
	return 42 - 2 * place if place <= 20 else 1

static func totals(riders: Array, results: Array) -> Dictionary:
	var scores := {}
	for rider in riders: scores[String(rider.id)] = 0
	for result in results:
		if result.discipline == "points":
			for id in result.points: scores[id] += int(result.points[id])
		else:
			for i in range(result.order.size()): scores[result.order[i]] += place_points(i + 1)
	return scores

# Equal final sprint times use best places in the other three disciplines.
# A remaining exact equality remains a shared sporting rank.
static func compare(a: String, b: String, scores: Dictionary, results: Array) -> int:
	if scores[a] != scores[b]: return -1 if scores[a] > scores[b] else 1
	if results.size() < 4: return 0
	var times: Dictionary = results[3].get("final_sprint_times", results[3].get("finish_times", {}))
	if not times.has(a) or not times.has(b): return 0
	if float(times[a]) != float(times[b]):
		return -1 if float(times[a]) < float(times[b]) else 1
	var first: Array[int] = []
	var second: Array[int] = []
	for i in range(3):
		first.append(results[i].order.find(a) + 1)
		second.append(results[i].order.find(b) + 1)
	first.sort(); second.sort()
	for i in range(3):
		if first[i] != second[i]: return -1 if first[i] < second[i] else 1
	return 0
