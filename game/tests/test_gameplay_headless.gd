extends SceneTree
# Runs the actual main.gd race loop and force/banking/drafting calculations.
# Suppress rendering, trainer networking, recordings and finish-photo capture.
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

var failures := 0
var snapshots: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_races")

func run_races() -> void:
	for scenario in [[8, 10], [12, 50]]:
		var game = TestRace.new()
		root.add_child(game)
		game.rider_count = scenario[0]
		game.race_laps = scenario[1]
		game.ai_difficulty = 80.0
		game._configure_peloton()
		# Fix forms and RNG after default initialization, before any race steps.
		game.rider_forms.fill(1.0)
		game.x_ai.reset(game.rider_profiles, game.rider_forms, game.lane_offsets)
		game.x_ai.rng.seed = 23102026
		for i in range(1, game.rider_count):
			game.x_ai.cooldown[i] = 75.0 + 5.0 * i
			game.x_ai.cooperation[i] = 0.6
			game.x_ai.aggression[i] = 0.6
		game.watts = 300.0
		game.running = true
		game.start_state = "RACING"
		check(game.LANES.size() == 11, "Eleven player riding lines available")
		var key := InputEventKey.new()
		key.keycode = KEY_B
		key.pressed = true
		game._unhandled_key_input(key)
		check(game.look_back_held, "Rear-view key press")
		key.pressed = false
		game._unhandled_key_input(key)
		check(not game.look_back_held and game.camera_mode == 1, "Rear-view release restores camera selection")
		game.draft_strengths[0] = 1.0
		game.speeds[0] = 20.0 / 3.6
		var low: float = game._draft_drag_reduction(0)
		game.speeds[0] = 50.0 / 3.6
		check(game._draft_drag_reduction(0) > low, "Speed-dependent aerodynamic shelter")
		game.draft_strengths[0] = 0.0
		game.speeds[0] = 0.0
		check(game._next_speed(16.0, 1700.0, 0.1, 0.6) > 16.0, "Sprint physics has no imposed 16 m/s cap")
		var next_snapshot := 10
		var start_checked := false
		var dt := 0.1
		var bad_state := false
		while not game._all_riders_finished() and game.clock < float(game.race_laps) * 90.0:
			game.clock += dt
			game._update_race(dt)
			for i in range(game.rider_count):
				if not is_finite(game.speeds[i]) or not is_finite(game.distances[i]) or game.speeds[i] < 0.0:
					bad_state = true
				if i > 0 and (game.x_ai.wprime[i] < -0.001 or game.x_ai.wprime[i] > game.x_ai.wmax[i] + 0.001):
					bad_state = true
			if game.clock >= 10.0 and not start_checked:
				start_checked = true
				for i in range(1, game.rider_count):
					check(game.speeds[i] > 2.0 and game.distances[i] > 10.0, "AI starts under own power")
			if game.distances.max() >= float(next_snapshot) * 250.0:
				var riders: Array[Dictionary] = []
				for i in range(game.rider_count):
					riders.append({"id": i, "profile": game.rider_profiles[i], "distance_m": game.distances[i], "speed_kmh": game.speeds[i] * 3.6, "lane_m": game.lane_offsets[i], "wprime_pct": 0.0 if i == 0 else 100.0 * game.x_ai.wprime[i] / game.x_ai.wmax[i], "mode": game.x_ai.modes[i], "lap_credit": game.scratch_rules.credits[i]})
				snapshots.append({"riders": game.rider_count, "laps": game.race_laps, "leader_lap": next_snapshot, "clock_s": game.clock, "positions": riders})
				next_snapshot += 10
		check(not bad_state, "Finite speed/distance and bounded reserves for entire race")
		check(start_checked, "Standing-start assertion executed")
		check(game._all_riders_finished(), "All riders finish %d-rider/%d-lap race" % scenario)
		check(game.x_ai.sprint_started.has(true), "At least one individual final sprint")
		print("GAMEPLAY_RACE: riders=%d laps=%d seconds=%.1f winner=%d" % [scenario[0], scenario[1], game.clock, game._winner_index()])
		game.free()
	var snapshot_file := FileAccess.open("res://tests/headless_snapshots.json", FileAccess.WRITE)
	if snapshot_file != null:
		snapshot_file.store_string(JSON.stringify(snapshots, "\t"))
		snapshot_file.close()
	print("GAMEPLAY_HEADLESS_OK" if failures == 0 else "GAMEPLAY_HEADLESS_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
