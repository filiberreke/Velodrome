extends RefCounted
## One constant, distance-budgeted effort; no draft, randomness or final sprint.
const WPRIME_J := 20000.0
const BUDGET_FRACTION := 0.98
var cp_w := 250.0
var target_w := 250.0
var reserve_j := WPRIME_J
var predicted_seconds := 0.0

static func advance(game: Node3D, progress: float, speed: float, power: float, dt: float, lane: float, origin: float, lateral_height: float = 0.0, lateral_travel: float = 0.0) -> Dictionary:
	var position: float = origin + progress
	var next: float = game._next_speed(speed, power, dt, 0.0)
	var metric: float = game._path_metric(position, lane)
	var estimate: float = next * dt / metric
	var height: float = game._at(position + estimate, lane).y - game._at(position, lane).y
	next = game._banked_speed(next, height, lateral_height, lateral_travel, dt, power)
	return {"speed": next, "step": next * dt / metric}

static func duration(game: Node3D, distance: float, power: float, origin: float, lane: float) -> float:
	var progress := 0.0
	var speed := 0.0
	var clock := 0.0
	var dt := 0.1
	while progress < distance and clock < 3600.0:
		var result: Dictionary = advance(game, progress, speed, power, dt, lane, origin)
		speed = result["speed"]
		var step: float = result["step"]
		if progress + step >= distance:
			return clock + dt * (distance - progress) / maxf(step, 0.000001)
		progress += step
		clock += dt
	return INF

func prepare(game: Node3D, distance: float, cp: float, origin: float, lane: float) -> void:
	cp_w = clampf(cp, 50.0, 800.0)
	reserve_j = WPRIME_J
	var low: float = cp_w
	var high: float = cp_w + 550.0
	for iteration in range(22):
		var candidate: float = (low + high) * 0.5
		var seconds: float = duration(game, distance, candidate, origin, lane)
		if (candidate - cp_w) * seconds <= WPRIME_J * BUDGET_FRACTION:
			low = candidate
		else:
			high = candidate
	target_w = low
	predicted_seconds = duration(game, distance, target_w, origin, lane)

func power(dt: float) -> float:
	if dt <= 0.0:
		return target_w
	var expenditure: float = minf(reserve_j, maxf(0.0, target_w - cp_w) * dt)
	reserve_j -= expenditure
	return cp_w + expenditure / dt
