extends SceneTree

const Push := preload("res://elimination_push.gd")
const Motion := preload("res://elimination_motion.gd")
const Trainer := preload("res://trainer_control.gd")
const FitExport := preload("res://fit_export.gd")
const Visual := preload("res://rider_visual.gd")
const Native := preload("res://tests/measure_elimination_native.gd")

class Game extends Native.Game:
	func _ride_context() -> String:
		return "race"

class Client extends Trainer:
	var commands: Array[Dictionary] = []
	func _open() -> bool: return true
	func _receive(_now: float) -> void: pass
	func _request(command: String, params: Dictionary, now: float, mutation: bool = false) -> void:
		var packet := {"command": command, "at": now, "id": str(commands.size())}
		packet.merge(params)
		commands.append(packet)
		if mutation:
			pending = {"packet": packet, "retry_at": now + 0.3, "tries": 0}

var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func make_game(lanes: Array[float], positions: Array[float], player_grid: int = 0) -> Game:
	var g := Game.new()
	root.add_child(g)
	g.race_mode = 2
	g.rider_count = lanes.size()
	g.race_laps = (lanes.size() - 1) * 2
	g.elimination_notice = Label.new()
	g.add_child(g.elimination_notice)
	g._configure_peloton()
	g.player_lane = player_grid
	g.lane_offsets.assign(lanes)
	g.x_ai.lane_targets.assign(lanes)
	g.distances.assign(positions)
	g.speeds.fill(10.0)
	g.baseline_speed = 10.0
	g.trainer_seen = true
	g.running = true
	g.start_state = "RACING"
	g.watts = 300.0
	return g

func step(g: Game, duration: float) -> void:
	g.clock += duration
	g._update_race(duration)

func direct(g: Game, rider: int, target: float, start: float = 0.0) -> void:
	var metrics: Array[float] = []
	for i in range(g.rider_count):
		metrics.append(g._path_metric(g.distances[i], g.lane_offsets[i]))
	g._elimination_try_push(rider, target, start, metrics, 50.0)

func test_movement() -> void:
	var g := make_game([1.78, 1.18, 6.0], [60.0, 60.0, 48.0], 1)
	g._steer_player(-1)
	step(g, 0.6)
	check(g.lane_offsets[0] >= 1.18 + Motion.LATERAL_CLEARANCE - 0.00001, "Inward steering keeps existing clearance")
	check(g.elimination_push.attempts.is_empty(), "Inward steering cannot initiate a push")
	g.free()

	g = make_game([1.18, 4.18, 5.98], [60.0, 60.0, 60.0])
	g._steer_player(1)
	step(g, 0.6)
	check(is_equal_approx(g.lane_offsets[0], 1.78) and g._elimination_player_effort() == 0.0, "Free outward lane incurs no penalty")
	g.free()

	for displaced in [1, 2, 3]:
		var lanes: Array[float] = [1.18, 1.78, 2.38, 2.98]
		var positions: Array[float] = [249.98, 250.03, 249.95, 250.07]
		for i in range(displaced + 1, 4):
			lanes[i] = 5.98 + 0.6 * (i - displaced - 1)
		g = make_game(lanes, positions)
		g._process_steering(30)
		step(g, 1.0 / 60)
		check(g.lane_offsets[1] > lanes[1] and g.lane_offsets[1] < lanes[1] + Push.DISTANCE_M, "First physics step glides")
		check(g.elimination_push.attempts.size() == 1 and g.elimination_push.attempts[0].displaced.size() == displaced, "All and only blocking riders are counted")
		step(g, 0.3)
		for i in range(1, 4):
			if i <= displaced:
				check(is_equal_approx(g.lane_offsets[i], lanes[i] + Push.DISTANCE_M), "Passives move exactly 30 cm across the timing line")
			check(g.elimination_push.seconds_left(i, 0.31) == 0.0, "Passives retain full drive power and have no cooldown")
		check(g.elimination_push.drive_power(0, 300.0, 0.0) == 250.0, "Pushing costs 50 W")
		check(g.elimination_push.drive_power(0, 37.0, 0.0) == 0.0, "Effective output is floored")
		check(g.elimination_push.drive_power(0, 300.0, 4.999) == 250.0 and g.elimination_push.drive_power(0, 300.0, 5.0) == 300.0, "Power cost lasts five seconds")
		check(is_equal_approx(g.player_power_integral, g.clock * 300.0) and g.player_peak_watts == 300.0 and g.player_samples[-1].y == 300.0, "Raw power is recorded throughout")
		for i in range(4):
			check(g.lane_offsets[i] <= g.LANES[-1], "Piste edge holds")
			for j in range(i):
				check(absf(g.lane_offsets[i] - g.lane_offsets[j]) >= Motion.LATERAL_CLEARANCE - 0.00001 or absf(Motion.signed_gap(g.distances[i], g.distances[j])) >= Motion.MIN_GAP - 0.00001, "Separation holds during cascade")
		for _i in range(10):
			g._process_steering(90)
		step(g, 5.0)
		check(g.elimination_push.attempts.size() == 1 and g._elimination_player_effort() == 0.0, "Held steering cannot initiate a second push")
		g._configure_peloton()
		check(g.elimination_push.attempts.is_empty() and g.elimination_push.effort_until.is_empty(), "New race clears previous effort")
		g.free()

	g = make_game([5.98, 6.58, 7.18], [100.0, 100.0, 100.0], 8)
	direct(g, 0, 6.58)
	check(g.elimination_push.attempts.size() == 1 and g.elimination_push.attempts[0].rejection == "edge", "Edge rejects full chain")
	check(g.elimination_push.ends.is_empty() and g._elimination_player_effort() == 0.0 and g.lane_offsets == [5.98, 6.58, 7.18], "Refusal leaves geometry and power unchanged")
	g.free()

	g = make_game([2.38, 1.18, 1.78, 2.98], [50.0, 50.0, 50.0, 50.0], 2)
	direct(g, 1, 1.78)
	direct(g, 2, 2.38)
	check(g.elimination_push.attempts[-1].rejection == "busy", "Concurrent cascades cannot commit overlapping reservations")
	step(g, 0.35)
	g._steer_player(-1)
	step(g, 0.25)
	check(is_equal_approx(g.lane_offsets[0], 2.68), "Passive player cannot immediately steer back")
	check(g.elimination_push.seconds_left(0, g.clock) == 0.0 and g.elimination_push.seconds_left(2, g.clock) == 0.0, "AI initiated cascade only charges AI initiator")
	g.x_ai.lane_targets.assign(g.lane_offsets)
	direct(g, 1, 2.2, 2.0)
	check(g.elimination_push.attempts[-1].rejection == "cooldown", "Fresh request cannot bypass active penalty")
	direct(g, 1, 2.2, 5.0)
	check(g.elimination_push.attempts[-1].rejection.is_empty(), "A fresh push is allowed at expiry")
	g.free()

func test_ai_policy() -> void:
	var g := make_game([1.78, 1.18, 1.18, 7.18], [350.0, 350.0, 352.2, 353.0], 1)
	var active: Array[int] = [3, 2, 0, 1]
	g.x_ai.last_motion[1] = {"leader": 2, "power_excess": 90.0}
	g.x_ai.elimination_line_m = 500.0
	g.x_ai.boxed_since[1] = 1.0
	var choice: float = g.x_ai._escape_line(1, 3, active, g.distances, g.speeds, g.lane_offsets, {}, 5.0, false)
	check(choice == g.lane_offsets[1] and g.x_ai.push_targets.is_empty(), "No push in the early part of the cycle")
	g.x_ai.elimination_line_m = 450.0
	g.x_ai._escape_line(1, 3, active, g.distances, g.speeds, g.lane_offsets, {}, 3.0, false)
	check(g.x_ai.push_targets.is_empty(), "No AI push before three seconds boxed")
	g.x_ai._escape_line(1, 3, active, g.distances, g.speeds, g.lane_offsets, {}, 5.0, false)
	check(g.x_ai.push_targets.has(1), "Boxed AI near the cut asks to escape")
	step(g, 0.3)
	check(g.lane_offsets[0] >= 2.08 - 0.00001 and g.elimination_push.seconds_left(0, g.clock) == 0.0, "Tactical AI can push the player without charging the player")
	g.free()

	g = make_game([3.58, 1.18, 1.18, 7.18], [350.0, 350.0, 352.2, 353.0], 4)
	g.x_ai.last_motion[1] = {"leader": 2, "power_excess": 90.0}
	g.x_ai.boxed_since[1] = 1.0
	g.x_ai.elimination_line_m = 450.0
	choice = g.x_ai._escape_line(1, 3, active, g.distances, g.speeds, g.lane_offsets, {}, 5.0, false)
	check(is_equal_approx(choice, 1.78) and g.x_ai.push_targets.is_empty(), "AI takes ordinary available lanes first")
	g.free()

func test_trainer_client() -> void:
	for example in [[85.0, 30.0, 0.72], [85.0, 40.0, 0.54], [85.0, 45.0, 0.48],
			[85.0, 50.0, 0.43], [98.0, 33.0, 0.57]]:
		check(absf(Trainer.push_grade_for(50.0, example[0], example[1] / 3.6) - example[2]) < 0.006, "Trainer speed and mass determine grade")
	check(Trainer.push_grade_for(50.0, 30.0, 0.01) == Trainer.PUSH_MAX_GRADE, "Slow-speed cap")
	check(Trainer.push_grade_for(50.0, 85.0, 0.0) == 0.0 and Trainer.push_grade_for(50.0, NAN, 12.0) == 0.0 and Trainer.push_grade_for(50.0, 85.0, INF) == 0.0, "Missing, zero and invalid inputs suppress the grade")
	var client := Client.new()
	client.enabled_before = true
	client.phase = "ACTIVE"
	client.owned = true
	client.state = {"desired_mode": "SIM", "push_grade_supported": true}
	client.tick(true, 1.1, 0.8, 100.0, 0, 0.54, 5.0)
	check(client.commands[-1].grade_pct == 1.1 and client.commands[-1].push_grade_pct == 0.54 and client.commands[-1].push_duration_ms == 5000, "Physical surcharge is separate from normal grade")
	client.shift(1, 100.1)
	check(client.commands[-1].command == "shift", "Virtual shift may travel while the grade ACK is pending")
	var initial_id: String = client.pending.packet.id
	client.tick(true, 1.1, 0.8, 100.4, 0, 0.54, 4.6)
	check(client.commands[-1].id != initial_id and client.commands[-1].push_duration_ms <= 4600, "An unacknowledged pulse is replaced with its remaining duration")
	client.pending = {}
	client.tick(true, 1.75, 0.8, 101.0, 0, 0.54, 4.0)
	check(client.commands[-1].grade_pct == 1.75 and client.commands[-1].push_duration_ms == 4000, "Changing the road grade retains only the remaining surcharge")
	client.pending = {}
	client.tick(true, 1.75, 0.8, 105.0)
	check(client.commands[-1].command == "set_grade" and not client.commands[-1].has("push_grade_pct"), "Expiry restores the current grade")
	client.pending = {}
	client.release(105.1)
	check(client.commands[-1].command == "set_target_power" and client.commands[-1].watts == 0, "Pause or finish release clears the trainer load")
	client = Client.new()
	client.enabled_before = true
	client.phase = "READY"
	client.state = {"desired_mode": "SIM"}
	client.tick(true, 0.0, 1.0, 100.0, 0, 0.54, 2.0)
	check(not client.commands[-1].has("push_grade_pct"), "Legacy bridge receives the original grade command")

	var g := make_game([1.18, 1.78], [40.0, 40.0])
	g.trainer_control = Client.new()
	g.connected = true
	g.trainer_ready = true
	direct(g, 0, 1.78)
	g._update_trainer_control()
	check(g.trainer_control.commands.is_empty(), "Headless races send no physical trainer commands")
	g.free()

func test_scope_and_clock() -> void:
	var g := make_game([1.18, 1.78, 2.38], [50.0, 50.0, 50.0])
	g.trainer_seen = false
	g._steer_player(1)
	step(g, 0.5)
	var remaining := g._elimination_player_effort()
	check(absf(remaining - 4.5) < 0.00001, "Pushing works without a trainer")
	g._pause_race(false)
	g._physics_process(2.0)
	check(absf(g._elimination_player_effort() - remaining) < 0.00001, "A paused race does not spend effort time")
	g.race_paused = false
	step(g, 4.5)
	check(g._elimination_player_effort() == 0.0, "Fast-forwarded physics consumes exactly the remaining duration")
	g.free()

	g = make_game([1.78, 1.18, 2.38, 5.98], [50.0, 50.0, 50.0, 60.0], 1)
	direct(g, 1, 1.78)
	step(g, 0.30)
	check(g.elimination_push.held(0, g.clock) and g.elimination_push.seconds_left(0, g.clock) == 0.0, "Passive hold only prevents steering inward")
	g._steer_player(1)
	step(g, 0.15)
	check(g.elimination_push.attempts[-1].rider == 0 and g.elimination_push.attempts[-1].rejection.is_empty(), "A passive rider can immediately initiate an outward push")
	g.finish_times[0] = g.clock
	check(g._elimination_player_effort() == 0.0, "Elimination clears trainer and HUD effort immediately")
	g.finish_times[0] = -1
	g.race_mode = 0
	check(g._elimination_player_effort() == 0.0, "Other race modes ignore stale elimination effort")
	g.free()

	var old_locale := TranslationServer.get_locale()
	for locale in ["en", "nl"]:
		TranslationServer.set_locale(locale)
		var text := String(TranslationServer.translate("HUD_ELIMINATION_PUSH_EFFORT"))
		check(text.begins_with("Pushing effort" if locale == "en" else "Duwinspanning"), "Effort text is translated in " + locale)
	TranslationServer.set_locale(old_locale)

func test_waiting_at_final_line() -> void:
	var g := make_game([1.18, 1.18, 5.98], [1000.0, 497.962, 400.0])
	g.race_laps = 4
	g.speeds.assign([12.0, 10.0, 10.0])
	g.baseline_speed = 12.0
	step(g, 1.0 / 60.0)
	check(g.finish_times[0] < 0.0 and g.distances[0] == 1000.0, "Leader waits for the jury at the last line")
	check(absf(Motion.signed_gap(g.distances[0], g.distances[1])) >= Motion.MIN_GAP - 0.00001, "Lapped follower brakes for the actual capped advance at the line")
	g.free()

func test_frame_intervals() -> void:
	var reference := {}
	for frame_time in [1.0 / 60.0, 0.1, 0.4]:
		var g := make_game([1.18, 1.78, 2.38], [68.0, 68.1, 68.2])
		g.rider_forms.fill(1.0)
		g.x_ai.reset(g.rider_profiles, g.rider_forms, g.lane_offsets)
		g.x_ai.configure_riders(g.rider_identities, g.rider_forms)
		g._steer_player(1)
		for frame in range(roundi(5.2 / frame_time)):
			step(g, frame_time)
		var outcome := {"distance": g.distances.duplicate(), "lane": g.lane_offsets.duplicate(), "events": g.elimination_push.attempts.duplicate()}
		check(g._elimination_player_effort() == 0.0 and outcome.events.size() == 1, "One push expires normally at every frame interval")
		if reference.is_empty():
			reference = outcome
		else:
			for i in range(g.rider_count):
				check(absf(outcome.distance[i] - reference.distance[i]) < 0.000001 and absf(outcome.lane[i] - reference.lane[i]) < 0.000001, "Race and cascade positions match across frame rates")
		g.free()

func test_recording_and_simultaneous_input() -> void:
	var g := make_game([1.18, 1.78, 2.38, 2.98], [68.0, 68.1, 68.2, 68.3])
	g._steer_player(1)
	g.x_ai.push_targets[1] = 2.38
	step(g, 0.35)
	check(g.elimination_push.attempts.size() == 2 and g.elimination_push.attempts[0].rider == 0 and g.elimination_push.attempts[1].rejection == "busy", "One reservation wins when the player and AI ask in the same tick")
	g.recording_active = true
	for sample in [1, 2]:
		g._process_bridge_packet({"type": "telemetry", "power_w": 320, "speed_kmh": 40, "cadence_rpm": 90, "sample_id": sample, "valid": true})
		step(g, 1.0)
	check(g.ride_records.size() == 2 and g.ride_records[1].power_w == 320.0 and not g.ride_records[1].has("grade_pct"), "Live recording keeps trainer watts and omits the synthetic grade")
	var reduced: Array[Dictionary] = g.ride_records.duplicate(true)
	var augmented: Array[Dictionary] = g.ride_records.duplicate(true)
	for sample in reduced:
		sample.power_w -= Push.POWER_W
	for sample in augmented:
		sample["altitude"] = 24.0
		sample["grade_pct"] = 0.54
	var fit := FitExport.build(g.ride_records, 1700000000, true)
	check(not fit.is_empty() and FitExport.build(reduced, 1700000000, true) != fit, "FIT encodes the measured power even during the push")
	check(FitExport.build(augmented, 1700000000, true) == fit, "The FIT/GPS payload ignores synthetic grade and altitude")
	g.free()

func test_reserved_corridor() -> void:
	var lanes: Array[float] = [2.38, 2.98, 3.845]
	var requested: Array[float] = [2.399, 2.999, 3.826]
	var distances: Array[float] = [100.0, 100.0, 97.65]
	var speeds: Array[float] = [10.0, 10.0, 11.8]
	var done: Array[float] = [-1.0, -1.0, -1.0]
	var metrics: Array[float] = [1.0, 1.0, 1.0]
	var resolved := Motion.constrain_lanes(distances, speeds, lanes, requested, done, metrics,
		1.0 / 60.0, {0: 2.68, 1: 3.28}, 0.3 / 1.15)
	check(is_equal_approx(resolved[2], lanes[2]), "An outside rider cannot enter a close reserved corridor while the current merge gap still fits")
	check(is_equal_approx(resolved[1], requested[1]), "The reservation progresses without displacing the outside rider")

func add_rider_visuals(g: Game) -> Array:
	var visuals: Array = []
	for i in range(g.rider_count):
		var bike := Node3D.new()
		var visual := Visual.new()
		bike.add_child(visual)
		g.add_child(bike)
		g.bikes.append(bike)
		visuals.append(visual)
	return visuals

func test_cascade_animation_roles() -> void:
	# Rider 3 pushes the player and rider 1. Only the player passes the
	# push on to rider 2, even though rider 1 was added to the group too.
	var g := make_game([1.78, 1.78, 2.38, 1.18], [101.1, 98.9, 102.7, 100.0], 1)
	var visuals := add_rider_visuals(g)
	direct(g, 3, 1.78)
	for i in range(visuals.size()):
		var layer = visuals[i].shoulder_push_layer
		var gives := i in [0, 3]
		check(is_instance_valid(layer) and layer.role == ("give" if gives else "take")
			and layer.side == ("R" if gives else "L"), "Only riders that send the cascade play the outward give animation")
	check(g.elimination_push.seconds_left(0, 0.0) == 0.0, "Passing on a push animates the player without charging them")
	g._pause_race(false)
	check(is_instance_valid(visuals[0].shoulder_push_layer) and visuals[0].shoulder_push_layer.paused, "Pausing the race pauses the cascade animations")
	g._set_elimination_push_animations_paused(false)
	check(is_instance_valid(visuals[0].shoulder_push_layer) and not visuals[0].shoulder_push_layer.paused, "Resuming allows the clip to continue")
	g.free()

	g = make_game([5.98, 6.58, 7.18], [100.0, 100.0, 100.0], 8)
	visuals = add_rider_visuals(g)
	g._steer_player(1)
	step(g, 1.0 / 60.0)
	check(g.elimination_push.attempts.size() == 1 and g.elimination_push.attempts[0].rejection == "edge", "Outer edge rejects the animated fixture")
	for visual in visuals:
		check(not visual.is_shoulder_push_active(), "A rejected cascade does not play either animation")
	g.free()

func run() -> void:
	test_movement()
	test_ai_policy()
	test_trainer_client()
	test_scope_and_clock()
	test_waiting_at_final_line()
	test_frame_intervals()
	test_recording_and_simultaneous_input()
	test_reserved_corridor()
	test_cascade_animation_roles()
	print("ELIMINATION_PUSHING checks=", checks, " failures=", failures)
	quit(int(failures > 0))
