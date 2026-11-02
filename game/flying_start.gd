extends RefCounted
## One unrestricted acceleration lap using the same solo physics as the race.
const SoloPhysics := preload("res://pursuit_pacer.gd")
var elapsed := 0.0
var distance_offset := 0.0

func reset() -> void:
	elapsed = 0.0
	distance_offset = 0.0

func begin(game) -> void:
	reset()
	game.start_state = "RUN_UP"

func remaining_marker(game) -> int:
	return maxi(50, ceili(maxf(0.0, game.LAP - game.distances[0]) / 50.0) * 50)

func notice(game) -> String:
	return "Aanloopronde — nog %d m tot start" % remaining_marker(game)

func step(game, dt: float) -> void:
	if dt <= 0.0: return
	var previous: float = game.distances[0]
	var speed_before: float = game.speeds[0]
	var lane_before: float = game.lane_offsets[0]
	var height: Array[float] = game._pursuit_move_lanes(dt)
	game.draft_strengths.fill(0.0)
	game.draft_leaders.fill(-1)
	var result: Dictionary = SoloPhysics.advance(game, previous, speed_before, game.watts, dt, game.lane_offsets[0], game._rider_distance(0, 0.0), height[0], absf(game.lane_offsets[0] - lane_before))
	game.speeds[0] = float(result.speed)
	var travelled: float = float(result.step)
	game.distances[0] = previous + travelled
	if game.distances[0] >= game.LAP:
		# Keep both clocks and the physical bike continuous across this tick.
		var fraction: float = clampf((game.LAP - previous) / maxf(travelled, 0.000001), 0.0, 1.0)
		game.distances[0] = 0.0
		game.speeds[0] = lerpf(speed_before, game.speeds[0], fraction)
		game.lane_offsets[0] = lerpf(lane_before, game.lane_offsets[0], fraction)
		elapsed += dt * fraction
		distance_offset = game.LAP
		game._finish_flying_start()
		var remaining: float = dt * (1.0 - fraction)
		if remaining > 0.0:
			game.clock += remaining
			game._update_race(remaining)
	else:
		elapsed += dt
		game.baseline_speed = game.speeds[0]
	game._capture_demo_fit_sample()
