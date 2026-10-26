extends SceneTree

class TestRace extends "res://main.gd":
	func _ready() -> void:
		set_physics_process(false)
	func _spawn_peloton() -> void:
		pass
	func _take_finish_photo(_winner: int) -> void:
		pass
	func _save_recording(_reason: String) -> void:
		pass
	func _capture_demo_fit_sample() -> void:
		pass
	func _register_performance() -> void:
		pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_races")

func run_races() -> void:
	for count in range(6, 13):
		run_race(count, 0.1)
	# Also exercise the normal physics tick with the largest supported field.
	run_race(12, 1.0 / 60.0)
	print("SCRATCH_LARGE_FIELD_OK" if failures == 0 else "SCRATCH_LARGE_FIELD_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

func run_race(count: int, dt: float) -> void:
		var game = TestRace.new()
		root.add_child(game)
		game.rider_count = count
		game.race_laps = 4
		game._configure_peloton()
		game.rider_forms.fill(1.0)
		game.x_ai.reset(game.rider_profiles, game.rider_forms, game.lane_offsets)
		game.x_ai.rng.seed = 23102026
		for i in range(1, count):
			game.x_ai.cooldown[i] = 75.0 + 5.0 * i
			game.x_ai.cooperation[i] = 0.6
			game.x_ai.aggression[i] = 0.6
		for i in range(count):
			for j in range(i):
				var same_lane: bool = absf(game.lane_offsets[i] - game.lane_offsets[j]) < 0.88
				check(not same_lane or absf(game.distances[i] - game.distances[j]) >= 2.0, "Starting bicycles overlap: %d/%d in field %d" % [i, j, count])
		game.watts = 315.0
		game.running = true
		game.start_state = "RACING"
		while not game._all_riders_finished() and game.clock < 180.0:
			game.clock += dt
			game._update_race(dt)
			if absf(game.clock - 20.0) < 0.01:
				for i in range(1, count):
					check(game.speeds[i] > 6.0, "Launch stalled for rider %d in field %d" % [i, count])
		check(game._all_riders_finished(), "Every rider finishes in field %d" % count)
		var slowest_first_lap := 0.0
		for i in range(count):
			check(game.lap_times[i].size() == 4, "Exactly four lap crossings for rider %d" % i)
			if not game.lap_times[i].is_empty():
				slowest_first_lap = maxf(slowest_first_lap, game.lap_times[i][0])
		check(slowest_first_lap < 45.0, "First lap delayed by overlapping bicycles in field %d: %.2f s" % [count, slowest_first_lap])
		print("SCRATCH_FIELD riders=%d dt=%.4f slowest_first_lap=%.2f finish=%.2f" % [count, dt, slowest_first_lap, game.clock])
		game.free()
