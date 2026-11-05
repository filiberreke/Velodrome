extends SceneTree
const Records := preload("res://time_trial_records.gd")
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class History extends "res://time_trial_records.gd":
	var rides: Array = []
	func all_rides() -> Array: return rides
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	for distance in [500, 1000]:
		for dt in [0.1, 1.0 / 60.0]:
			var g := Model.new()
			root.add_child(g)
			g.race_mode = 7
			g.race_laps = distance / 250
			g.time_trial_start_type = "flying"
			g._configure_peloton()
			g._prepare_pursuit({}, 0.0)
			g._begin_riding()
			g.watts = 500.0
			var markers: Array[int] = []
			var tick := 0
			while g.start_state == "RUN_UP" and tick < int(150.0 / dt):
				var marker: int = g.flying_start.remaining_marker(g)
				if not markers.has(marker): markers.append(marker)
				var before: float = g._training_distance()
				var speed_before: float = g.speeds[0]
				g.flying_start.step(g, dt)
				check(g._training_distance() >= before and g._training_distance() - before < 3.0, "No position jump over the start line")
				if g.start_state == "RUN_UP":
					check(g.clock == 0.0 and g.lap_times[0].is_empty() and g.pursuit_half_crossings[0].is_empty() and g.player_power_integral == 0.0, "Run-up does not count towards race statistics")
				else:
					check(g.clock <= dt and absf(g.speeds[0] - speed_before) < 1.0, "Tick is split at the start with momentum preserved")
				tick += 1
			check(g.start_state == "RACING" and g.flying_start.distance_offset == 250.0, "One full acceleration lap triggers flying start")
			check(markers == [250, 200, 150, 100, 50], "All countdown distances appear in order")
			check(g.speeds[0] > 30.0 / 3.6, "Solo run-up permits full acceleration above the neutral pack speed")
			while not g.finished and g.clock < 180.0:
				g.clock += dt
				g._update_race(dt)
			check(g.finished and g.distances[0] == distance, "Full selected racing distance is completed after the run-up")
			check(g.lap_times[0].size() == distance / 250 and g.pursuit_half_crossings[0].size() == distance / 125, "Only timed racing laps and checkpoints are recorded")
			check(is_equal_approx(g.pursuit_half_crossings[0][-1], g.finish_times[0]), "Final split equals finish time")
			check(g._training_distance() == distance + 250.0 and g._training_seconds() > g.finish_times[0], "Workout includes the run-up separately from race time")
			var previous_time := -1.0
			var previous_distance := -1.0
			for sample in g.demo_fit_records:
				check(sample.time_s >= previous_time and sample.distance_m >= previous_distance, "Training export remains monotonic")
				previous_time = sample.time_s
				previous_distance = sample.distance_m
			check(g.time_trial_records.references(distance, -1.0, "flying").last.get("start_type") == "flying", "Completed flying result is stored in the flying category")
			g.free()
	# Old records without start_type remain standing starts.
	var history := History.new()
	history.rides = [{"distance_m": 500, "seconds": 40.0, "finished_at": 100.0}, {"distance_m": 500, "seconds": 30.0, "finished_at": 101.0, "start_type": "flying"}]
	check(history.references(500, 102.0).alltime.seconds == 40.0, "Legacy standing records remain compatible")
	check(history.references(500, 102.0, "flying").alltime.seconds == 30.0, "Flying records never mix with standing references")
	var g := Screen.new()
	root.add_child(g)
	g.set_physics_process(false)
	await process_frame
	await process_frame
	g.setup_panel.select_mode(7)
	check(g.setup_panel.time_trial_start.selected == 0, "Standing start remains the menu default")
	g.setup_panel.time_trial_start.select(1)
	g.setup_panel.time_trial_distance.select(0)
	g._confirm_start()
	g.broadcast_intro.finish()
	g.start_state = "COUNTDOWN"
	g.countdown = 0.0
	g.watts = 0.0
	g._physics_process(0.1)
	check(g.start_state == "RUN_UP" and g.time_trial_start_type == "flying", "Menu choice reaches actual countdown start")
	for marker in [200, 150, 100, 50]:
		g.distances[0] = 250.0 - marker + 0.01
		g._update_countdown_display()
		g._update_hud()
		check(not g.countdown_label.visible and g.race_overlay.status_label.text == "Aanloopronde — nog %d m tot start" % marker, "Run-up distance appears only in the dark status panel at %d m" % marker)
		check(g.race_overlay.solo_elapsed_label.text == "00:00.0" and g.race_overlay.solo_estimate_label.text == "—", "HUD clock and estimate wait for GO")
	g._finish_flying_start()
	g._update_countdown_display()
	check(g.race_overlay.signals.countdown_label.text == "GO!" and g.race_overlay.signals.countdown_label.visible and not g.countdown_label.visible, "Screen-space GO appears at timed start without duplicate 3D label")
	g._reset()
	check(g.flying_start.elapsed == 0.0 and g.flying_start.distance_offset == 0.0, "Reset clears flying start offsets")
	g.setup_panel.select_mode(7)
	g.setup_panel.time_trial_start.select(0)
	g._confirm_start()
	g.broadcast_intro.finish()
	g._begin_riding()
	check(g.start_state == "RACING" and g.time_trial_start_type == "standing" and g.speeds[0] == 0.0, "Standing start still enters timed race at rest")
	g._reset()
	g.setup_panel.select_mode(7)
	g.setup_panel.time_trial_start.select(1)
	g._confirm_start()
	g.broadcast_intro.finish()
	g.trainer_seen = true
	g.connected = true
	g.trainer_ready = true
	g._begin_riding()
	g._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 400.0, "speed_kmh": 45.0, "sample_id": 1})
	g._physics_process(0.1)
	check(g.recording_active and not g.ride_records.is_empty() and g.start_state == "RUN_UP", "Trainer recording begins during the run-up")
	g.last_telemetry = g._now_s() - 60.0
	g.dropout_since = g._now_s() - 60.0
	var paused_distance: float = g.distances[0]
	var paused_time: float = g.flying_start.elapsed
	g._physics_process(0.1)
	check(g.distances[0] == paused_distance and g.flying_start.elapsed == paused_time, "Expired trainer signal pauses run-up without switching to demo")
	g._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 400.0, "speed_kmh": 45.0, "sample_id": 2})
	g._physics_process(0.1)
	check(g.distances[0] > paused_distance, "Fresh trainer data resumes run-up")
	g.distances[0] = 249.99
	g.speeds[0] = 14.0
	g.baseline_speed = 14.0
	g._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 400.0, "speed_kmh": 45.0, "sample_id": 3})
	var recorded: Dictionary = g.ride_records[-1]
	g._physics_process(0.1)
	g._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 400.0, "speed_kmh": 45.0, "sample_id": 4})
	check(g.start_state == "RACING" and g.ride_records[-1].time_s > recorded.time_s and g.ride_records[-1].distance_m > recorded.distance_m, "Real trainer recording remains continuous over GO")
	g._reset()
	g.setup_panel.select_mode(9)
	var page = g.setup_panel.records_page
	page.mode_choice.select(2)
	page.start_choice.select(1)
	page.refresh()
	check(page.start_choice.visible and page.category.text.contains("Vliegende start"), "Records page exposes the flying-start category")
	for ride in page.shown: check(ride.get("start_type", "standing") == "flying", "Visible record rows match selected start type")
	g.free()
	await process_frame
	print("FLYING TIME TRIAL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

