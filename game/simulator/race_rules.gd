extends RefCounted
class_name VelodromeRaceRules

const LAP_LENGTH: float = 250.0
const SPRINT_INTERVAL: int = 5
const INTERMEDIATE_POINTS = [3, 2, 1]
const FINAL_POINTS = [6, 4, 2, 1]

static func sprint_laps(laps: int) -> Array[int]:
	var result: Array[int] = []
	for lap in range(SPRINT_INTERVAL, laps, SPRINT_INTERVAL):
		result.append(lap)
	result.append(laps)
	return result

static func ordered_crossings(previous: Array, current: Array, dt: float, line: float) -> Array[Dictionary]:
	# Sub-frame interpolation: even when riders cross during the same physics tick.
	var crossings: Array[Dictionary] = []
	for i in range(mini(previous.size(), current.size())):
		if previous[i] < line and current[i] >= line and current[i] > previous[i]:
			var fraction: float = clampf((line - previous[i]) / (current[i] - previous[i]), 0.0, 1.0)
			crossings.append({"rider": i, "offset_seconds": fraction * dt})
	crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["offset_seconds"], b["offset_seconds"]):
			return a["rider"] < b["rider"]
		return a["offset_seconds"] < b["offset_seconds"])
	return crossings

static func award(points: Array, ranked_ids: Array, is_final: bool) -> void:
	var awards: Array = FINAL_POINTS if is_final else INTERMEDIATE_POINTS
	for place in range(mini(ranked_ids.size(), awards.size())):
		points[ranked_ids[place]] += awards[place]

static func standings(points: Array, finish_rank: Array) -> Array[int]:
	var ids: Array[int] = []
	for i in range(points.size()):
		ids.append(i)
	ids.sort_custom(func(a: int, b: int) -> bool:
		if points[a] != points[b]:
			return points[a] > points[b]
		return finish_rank[a] < finish_rank[b])
	return ids
