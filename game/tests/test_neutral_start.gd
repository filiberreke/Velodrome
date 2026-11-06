extends SceneTree

class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _read_bridge() -> void: pass
	func _update_visuals(_dt: float) -> void: pass
	func _update_hud() -> void: pass
	func _update_boost_dog(_dt: float) -> void: pass
	func _update_countdown_display() -> void: pass
	func _update_trainer_control() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _take_finish_photo(_rider: int) -> void: pass
	func _take_elimination_photo(_rider: int, _line: float) -> void: pass
	func _finish() -> void: finished = true

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func make_game(mode: int, count: int = 16) -> Game:
	var g := Game.new()
	root.add_child(g)
	g.race_mode = mode
	g.rider_count = count
	g.race_laps = 10 if mode == 1 else 4
	g._configure_peloton()
	g._begin_riding()
	return g
func run_test() -> void:
	for scenario in [[0,16], [1,16], [2,16], [0,24], [1,24], [2,24]]:
		var mode: int = scenario[0]
		for dt in [0.1, 1.0 / 60.0]:
			var g := make_game(mode, scenario[1])
			print("Neutral scenario: mode=%d dt=%.4f" % [mode, dt])
			check(g.start_state == "NEUTRAL" and g.running, "Group events enter neutral start")
			check(is_equal_approx(g.distances[0], g.NEUTRAL_DEPARTURE_M), "Departure is at the middle of the straight")
			check(absf(g._bank_angle(g._track_s(g.distances[0])) - deg_to_rad(g.STRAIGHT_BANK_DEG)) < 0.001, "Departure is on straight banking")
			check(is_zero_approx(g._training_distance()), "Ride distance starts at zero")
			g.watts = 350.0
			var tick := 0
			while g.start_state == "NEUTRAL" and tick < int(150.0 / dt):
				var before: Array[float] = g.distances.duplicate()
				var speed_before: Array[float] = g.speeds.duplicate()
				var training_before: float = g._training_distance()
				g.neutral_start.step(g, dt)
				if g.start_state == "NEUTRAL":
					if before[0] < 0.0 and g.distances[0] >= 0.0:
						check(g.clock == 0.0, "First finish passage only begins the full neutral lap")
					check(g.clock == 0.0 and g.lap_times[0].is_empty(), "No race clock or laps in neutral")
					check(g.speeds.max() <= g.neutral_start.MAX_SPEED_MPS + 0.001, "Moderate opening pace")
					check(g.distances.max() - g.distances.min() < 40.0, "Formation remains compact")
				else:
					check(g.clock < dt and g.distances[0] < 2.0, "Race starts at the line inside the physics tick")
					check(g.speeds[0] > 3.0 and absf(g.speeds[0] - speed_before[0]) < 1.0, "Flying start preserves momentum")
					check(g._training_distance() >= training_before and g._training_distance() - training_before < 2.0, "Training distance stays continuous")
					for i in range(g.rider_count):
						check(absf(g.distances[i] + g.LAP - before[i]) < 2.0, "Physical rider position stays continuous")
				tick += 1
			check(g.start_state == "RACING", "Neutral lap completes for mode %d at %.4f s" % [mode, dt])
			check(g.neutral_start.elapsed > 25.0 and is_equal_approx(g.neutral_start.distance_offset, g.LAP - g.NEUTRAL_DEPARTURE_M), "Approach and full neutral lap excluded from race distance")
			check(g.lap_times[0].is_empty() and g.scratch_rules.events.is_empty(), "No premature lap results or lap gains")
			if mode == 1: check(g.points_rules.sprints.is_empty() and g.points_rules.points.max() == 0, "No points before the official start")
			if mode == 2: check(g.elimination_rules.eliminated.is_empty() and g.elimination_rules.next_line_m == 500.0, "First elimination stays two racing laps away")
			var previous_time := -1.0
			var previous_distance := -1.0
			for sample in g.demo_fit_records:
				check(sample.time_s >= previous_time and sample.distance_m >= previous_distance, "Export samples remain monotonic across start")
				previous_time = sample.time_s
				previous_distance = sample.distance_m
			# Exercise actual race movement and jury after the rebasing.
			for t in range(int(50.0 / dt)):
				if g.finished: break
				g.clock += dt
				g._advance_race(dt)
			check(not g.lap_times[0].is_empty(), "First recorded lap is a racing lap")
			g.free()
	# No pedalling: the group waits and the official race never starts.
	var g := make_game(0)
	g.start_state = "COUNTDOWN"
	g.running = false
	g.watts = 0.0
	g.countdown = 0.0
	g._physics_process(0.1)
	check(g.start_state == "NEUTRAL" and g.running, "Actual countdown enters the opening lap")
	g._steer_player(1)
	check(g.player_lane == 1, "Keyboard steering works in neutral phase")
	g._process_steering(0)
	g._process_steering(100)
	check(g.player_lane == 2, "Trainer steering works in neutral phase")
	var boost := InputEventKey.new()
	boost.pressed = true
	boost.keycode = KEY_SPACE
	g._unhandled_key_input(boost)
	check(not g.boost_used and g.boost_left == 0.0, "Arcade boost is disabled during neutral phase")
	g.player_lane = 0
	g.watts = 0.0
	for tick in range(100): g.neutral_start.step(g, 0.1)
	check(g.start_state == "NEUTRAL" and g.distances[0] < 0.01 and g.clock == 0.0, "Stationary player cannot trigger race start")
	g.distances.fill(249.99)
	g.speeds.fill(1.0)
	g.baseline_speed = 1.0
	g.neutral_start.grid.fill(0.0)
	g.neutral_start.step(g, 0.1)
	check(g.start_state == "NEUTRAL" and g.distances[0] < 250.0, "Insufficient start speed postpones the signal")
	# Physical trainer loss pauses neutral movement, without switching to demo.
	g.trainer_seen = true
	g.connected = false
	g.trainer_ready = false
	g.last_telemetry = -100.0
	g.dropout_since = -100.0
	var stopped: Array[float] = g.distances.duplicate()
	g._physics_process(1.0)
	check(g.distances == stopped and g.start_state == "NEUTRAL", "Disconnected trainer pauses opening lap")
	# Trainer samples include neutral time/metres before and after the start.
	g.connected = true
	g.trainer_ready = true
	g.recording_active = true
	g.neutral_start.elapsed = 40.0
	g.neutral_start.distance_offset = 0.0
	g.distances[0] = 249.0
	g._process_bridge_json('{"type":"telemetry","valid":true,"power_w":220,"speed_kmh":30,"sample_id":1}')
	g.distances[0] -= 250.0
	g.neutral_start.distance_offset = 250.0
	g._finish_neutral_start()
	g.clock = 0.2
	g.distances[0] += 1.0
	g._process_bridge_json('{"type":"telemetry","valid":true,"power_w":220,"speed_kmh":30,"sample_id":2}')
	check(g.ride_records.size() == 2 and g.ride_records[1].time_s > g.ride_records[0].time_s and g.ride_records[1].distance_m > g.ride_records[0].distance_m, "Real trainer recording crosses official start without resetting")
	g.neutral_start.reset()
	check(g.neutral_start.elapsed == 0.0 and g.neutral_start.distance_offset == 0.0 and g.neutral_start.grid.is_empty(), "Restart clears all neutral state")
	g.free()
	# Pedalling and wheel speed never block an opening lap, but stale data does.
	for mode in [0, 1, 2, 7]:
		g = make_game(mode)
		if mode == 7: g.time_trial_start_type = "flying"
		g.trainer_seen = true
		g.connected = true
		g.trainer_ready = true
		g.watts = 250.0
		g.trainer_speed_kmh = 28.0
		g.last_telemetry = g._now_s()
		g.start_state = "WAIT_STOP"
		g._physics_process(0.1)
		check(g.start_state == "COUNTDOWN", "Opening lap accepts an already pedalling trainer")
		g.countdown = 0.5
		g._physics_process(0.1)
		check(g.start_state == "COUNTDOWN", "Pedalling does not reset final countdown second")
		g.countdown = 0.0
		g._physics_process(0.1)
		check(g.start_state == ("RUN_UP" if mode == 7 else "NEUTRAL"), "Countdown enters correct opening phase")
		g.connected = false
		check(not g._start_conditions_met(), "Disconnected trainer still blocks departure")
		g.connected = true
		g.trainer_ready = false
		check(not g._start_conditions_met(), "Stale data still blocks departure")
		g.trainer_ready = true
		g.bridge_bind_error = ERR_ALREADY_IN_USE
		check(not g._start_conditions_met(), "Bridge errors still block departure")
		g.free()
	# Timed disciplines still start from rest directly after the countdown.
	for mode in [4, 5, 7]:
		g = make_game(mode)
		g.trainer_seen = true
		g.connected = true
		g.trainer_ready = true
		g.watts = 250.0
		g.trainer_speed_kmh = 25.0
		check(not g._start_conditions_met() and not g._final_start_speed_ok(), "Standing start still requires rest")
		g.watts = 0.0
		g.trainer_speed_kmh = 0.0
		check(g._start_conditions_met() and g._final_start_speed_ok(), "Standing start accepts stopped trainer")
		check(g.start_state == "RACING" and g.neutral_start.elapsed == 0.0 and g.speeds[0] == 0.0, "Timed event %d retains standing start" % mode)
		g.free()
	print("NEUTRAL START: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
