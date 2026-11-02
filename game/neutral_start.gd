extends RefCounted
## Marshalled opening lap. These are game pacing choices, not UCI speed limits.
const MAX_SPEED_MPS := 30.0 / 3.6
const MIN_START_SPEED_MPS := 12.0 / 3.6
const MAX_GROUP_SPAN_M := 40.0
var elapsed := 0.0
var distance_offset := 0.0
var grid: Array[float] = []

func reset() -> void:
	elapsed = 0.0
	distance_offset = 0.0
	grid.clear()

func begin(game) -> void:
	reset()
	grid.assign(game.distances)
	game.start_state = "NEUTRAL"

func step(game, dt: float) -> void:
	if dt <= 0.0: return
	var before: Array[float] = game.distances.duplicate()
	var prior_speeds: Array[float] = game.speeds.duplicate()
	var prior_lanes: Array[float] = game.lane_offsets.duplicate()
	var height_changes: Array[float] = game._move_lanes(dt)
	game._update_drafting(dt)
	var player_speed: float = game._next_speed(game.baseline_speed, game.watts, dt, game._effective_draft_strength(0))
	var player_step: float = minf(MAX_SPEED_MPS, player_speed) * dt / game._path_metric(before[0], game.lane_offsets[0])
	var dh: float = game._at(before[0] + player_step, game.lane_offsets[0]).y - game._at(before[0], game.lane_offsets[0]).y
	player_speed = clampf(game._banked_speed(player_speed, dh, height_changes[0], absf(game.lane_offsets[0] - prior_lanes[0]), dt, game.watts), 0.0, MAX_SPEED_MPS)
	game.speeds[0] = player_speed
	var reference_rate: float = player_speed / game._path_metric(before[0], game.lane_offsets[0])
	game.distances[0] += reference_rate * dt
	for i in range(1, game.rider_count):
		# Keep the original staggered formation around the human pace setter.
		var error_m: float = before[0] + grid[i] - grid[0] - before[i]
		var metric: float = game._path_metric(before[i], game.lane_offsets[i])
		var target: float = clampf((reference_rate + error_m * 0.8) * metric, 0.0, MAX_SPEED_MPS)
		game.speeds[i] = move_toward(game.speeds[i], target, 2.0 * dt)
		game.distances[i] += game.speeds[i] * dt / metric
		game.ai_power_w[i] = 120.0 if game.speeds[i] > 0.1 else 0.0
	var compact: bool = game.distances.max() - game.distances.min() <= MAX_GROUP_SPAN_M
	var ready: bool = player_speed >= MIN_START_SPEED_MPS and compact
	if game.distances[0] >= game.LAP and ready:
		# Split the physics tick at the line: no lost distance or early race time.
		var fraction: float = clampf((game.LAP - before[0]) / maxf(game.distances[0] - before[0], 0.000001), 0.0, 1.0)
		for i in range(game.rider_count):
			game.distances[i] = lerpf(before[i], game.distances[i], fraction) - game.LAP
			game.speeds[i] = lerpf(prior_speeds[i], game.speeds[i], fraction)
			game.lane_offsets[i] = lerpf(prior_lanes[i], game.lane_offsets[i], fraction)
		elapsed += dt * fraction
		distance_offset = game.LAP
		game._finish_neutral_start()
		var remaining: float = dt * (1.0 - fraction)
		if remaining > 0.0:
			game.clock += remaining
			game._update_race(remaining)
	else:
		# If the rider crawls to the line, hold the start there until rolling.
		game.distances[0] = minf(game.distances[0], game.LAP - 0.001)
		elapsed += dt
		game.baseline_speed = game.speeds[0]
	game._capture_demo_fit_sample()

func notice(game) -> String:
	if game.distances[0] >= game.LAP - 1.0 and game.speeds[0] < MIN_START_SPEED_MPS:
		return "Geneutraliseerde ronde — versnel rustig voor de start"
	return "Geneutraliseerde ronde — blijf bij het peloton · nog %.0f m" % maxf(0.0, game.LAP - game.distances[0])
