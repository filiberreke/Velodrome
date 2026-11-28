extends SceneTree
## Run on either revision with -- --seed=17 (runs both riders and all field sizes).
const Motion = preload("res://elimination_motion.gd")
const Native = preload("res://tests/measure_elimination_native.gd")

class Race extends Native.Game:
	var intervals: Array = []
	var opened: Dictionary = {}
	var exits := 0
	var overlap_samples := 0
	var boundary_samples := 0
	var delivered_j := 0.0
	var penalty_j := 0.0
	var speed_integral := 0.0
	var rider_seconds := 0.0
	var rider_zero_eliminated_blocked := false
	var day_seed := 17

	func _load_rider_config() -> void:
		super._load_rider_config()
		form_rng.seed = day_seed

	func _ride_context() -> String:
		return "race"

	func _move_lanes(dt: float) -> Array[float]:
		var prior := lane_offsets.duplicate()
		var targets: Array = x_ai.lane_targets.duplicate()
		targets[0] = LANES[player_lane]
		var result := super._move_lanes(dt)
		for i in range(rider_count):
			if finish_times[i] >= 0.0:
				continue
			var wants_move: bool = absf(targets[i] - prior[i]) > 0.045
			var blocked: bool = wants_move and absf(lane_offsets[i] - prior[i]) < 0.25 * LANE_CHANGE_MPS * dt
			if blocked:
				opened.get_or_add(i, clock)
			elif opened.has(i):
				var escaped: bool = absf(lane_offsets[i] - prior[i]) >= 0.25 * LANE_CHANGE_MPS * dt
				intervals.append([i, clock - float(opened[i]), escaped])
				exits += int(escaped)
				opened.erase(i)
		return result

	func _advance_race(dt: float) -> void:
		var active: Array[int] = []
		for i in range(rider_count):
			if finish_times[i] < 0.0:
				active.append(i)
		super._advance_race(dt)
		for i in active:
			if finish_times[i] >= 0.0 and opened.has(i):
				intervals.append([i, clock - float(opened[i]), false])
				opened.erase(i)
				if i == 0 and elimination_rules.eliminated.has(i):
					rider_zero_eliminated_blocked = true
			delivered_j += (watts if i == 0 else ai_power_w[i]) * dt
			if "elimination_push" in self:
				var push: Variant = get("elimination_push")
				var actual: float = watts if i == 0 else ai_power_w[i]
				penalty_j += (actual - push.drive_power(i, actual, clock - dt)) * dt
			speed_integral += speeds[i] * dt
			rider_seconds += dt
			if lane_offsets[i] < LANES[0] - 0.00001 or lane_offsets[i] > LANES[-1] + 0.00001:
				boundary_samples += 1
			for j in active:
				if j >= i or finish_times[i] >= 0.0 or finish_times[j] >= 0.0:
					continue
				if absf(lane_offsets[i] - lane_offsets[j]) < Motion.LATERAL_CLEARANCE - 0.00001 and absf(Motion.signed_gap(distances[i], distances[j])) < Motion.MIN_GAP - 0.00001:
					overlap_samples += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var race_seed := 17
	var counts := [8, 16, 24]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			race_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--count="):
			counts = [int(arg.trim_prefix("--count="))]
	var incomplete := 0
	for count in counts:
		for policy in ["autonomous", "steering"]:
			seed(race_seed)
			var race := Race.new()
			root.add_child(race)
			race.day_seed = race_seed
			race.race_mode = 2
			race.rider_count = count
			race.race_laps = (count - 1) * 2
			race.elimination_notice = Label.new()
			race.add_child(race.elimination_notice)
			race._configure_peloton()
			race.running = true
			race.start_state = "RACING"
			race.trainer_seen = true
			var start := Time.get_ticks_usec()
			var next_command := 0.0
			while not race._all_riders_finished() and race.clock < 2400.0:
				var urgent: bool = race.elimination_rules.next_line_m - race.distances.max() < 110.0
				race.watts = (450.0 if urgent else 280.0) if policy == "autonomous" else (390.0 if urgent else 320.0)
				if race.clock >= next_command and race.finish_times[0] < 0.0:
					var held := race.opened.has(0)
					if policy == "steering" and urgent and (held or race.player_lane < 2):
						race._steer_player(1)
					elif not urgent and race.player_lane > 0 and not held:
						race._steer_player(-1)
					next_command = race.clock + 1.0
				race.clock += 0.1
				race._update_race(0.1)
			incomplete += int(not race._all_riders_finished())
			var row := {"count": count, "seed": race_seed, "policy": policy, "complete": race._all_riders_finished(), "duration": race.clock, "runtime": (Time.get_ticks_usec() - start) / 1000000.0, "blocks": race.intervals, "exits": race.exits, "eliminated_blocked": race.rider_zero_eliminated_blocked, "overlap_samples": race.overlap_samples, "boundary_samples": race.boundary_samples, "delivered_j": race.delivered_j, "penalty_j": race.penalty_j, "rider_seconds": race.rider_seconds, "speed_integral": race.speed_integral, "wprime": race.x_ai.wprime, "elimination_order": race.elimination_rules.eliminated, "race_laps": race.race_laps}
			if "elimination_push" in race:
				row["pushes"] = race.get("elimination_push").statistics()
			print("PUSH_RACE ", JSON.stringify(row))
			race.free()
	quit(1 if incomplete else 0)
