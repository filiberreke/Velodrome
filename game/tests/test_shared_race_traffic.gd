extends SceneTree

class Game extends "res://main.gd":
	var photo_rider := -1
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_elimination_photo(rider: int, _line_m: float) -> void: photo_rider = rider
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass

# Isolate movement from each event's tactical power demand.
class FixedAI extends "res://elimination_ai.gd":
	func step(_dt: float, _clock: float, distances: Array[float], _speeds: Array[float], _lanes: Array[float], _drafts: Array[float], _finished: Array[float], _profiles: Array[int], _laps: int, _difficulty: float, _credits: Array[int]) -> Array[float]:
		var result: Array[float] = []; result.resize(distances.size()); result.fill(200.0)
		return result

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func race(mode: int, count: int = 4, fixed: bool = true) -> Game:
	var g := Game.new(); root.add_child(g)
	g.race_mode = mode; g.rider_count = count; g.race_laps = 100
	g.elimination_notice = Label.new(); g.add_child(g.elimination_notice)
	g._configure_peloton(); g.rider_forms.fill(1.0)
	if fixed: g.x_ai = FixedAI.new()
	g.x_ai.reset(g.rider_profiles, g.rider_forms, g.lane_offsets)
	g.x_ai.configure_riders(g.rider_identities, g.rider_forms)
	g.running = true; g.start_state = "RACING"; g.clock = 30.0
	return g
func run_test() -> void:
	# Same-lane tailgating, passing, adjacent lines, on-banking merges,
	# lapped traffic and the former deterministic tie in longitudinal resolve.
	for scenario in range(6):
		var reference: Array = []
		for mode in [0, 1, 2]:
			var g := race(mode)
			g.distances.assign([50.0, 50.5, 20.0, 10.0])
			g.speeds.fill(8.0); g.baseline_speed = 14.0; g.watts = 650.0
			g.lane_offsets.assign([1.18, 1.18, 5.98, 7.18]); g.player_lane = 0
			if scenario == 1: g.player_lane = 2
			if scenario == 2: g.lane_offsets[1] = 1.78
			if scenario == 3:
				g.distances.assign([90.0, 90.5, 20.0, 10.0]); g.lane_offsets[1] = 2.38; g.player_lane = 2
			if scenario == 4: g.distances[1] += 250.0
			if scenario == 5: g.distances[1] = g.distances[0]
			g.x_ai.lane_targets = g.lane_offsets.duplicate()
			for tick in range(20): g.clock += 0.1; g._advance_race(0.1)
			if mode == 0:
				reference = [g.distances.duplicate(), g.speeds.duplicate(), g.lane_offsets.duplicate()]
			else:
				for i in range(4):
					check(is_equal_approx(g.distances[i], reference[0][i]) and is_equal_approx(g.speeds[i], reference[1][i]) and is_equal_approx(g.lane_offsets[i], reference[2][i]), "Identical physical movement for scratch/points/elimination, scenario %d rider %d" % [scenario, i])
			if scenario == 0: check(g.distances[0] > g.distances[1], "Faster player can pass a close wheel")
			if scenario in [1,3]: check(is_equal_approx(g.lane_offsets[0], 2.38), "Requested manual lane completes beside another rider")
			g.free()
	# Actual elimination AI must pass a stationary player at the start.
	for count in [4, 12, 16]:
		var g := race(2, count, false); g.clock = 0.0; g.watts = 0.0; g.baseline_speed = 0.0
		for tick in range(250): g.clock += 0.1; g._advance_race(0.1)
		for i in range(1, count): check(g.distances[i] > g.distances[0] + 5.0, "AI %d/%d passes the stationary player" % [i, count])
		g.free()
	# Rear-wheel jury, photo trigger, elimination notice and complete exit route.
	var g := race(2)
	g.distances.assign([501.0, 504.0, 505.0, 506.0]); g.clock = 40.0
	g._update_elimination_jury(0.1)
	check(g.elimination_rules.eliminated.is_empty(), "Front-wheel crossing cannot eliminate before rear wheel")
	g.distances[0] = 503.0; g.clock += 0.1; g._update_elimination_jury(0.1)
	check(g.elimination_rules.eliminated == [0] and g.photo_rider == 0, "Last rear wheel is eliminated and photo is requested")
	check(g.elimination_notice.text.begins_with("AFGEVALLEN"), "Elimination HUD notice remains")
	for tick in range(5000):
		g._update_eliminated_exit(0, 0.1)
		if int(g.elimination_exit[0].stage) == 3: break
	check(int(g.elimination_exit[0].stage) == 3 and is_zero_approx(g.coast_speeds[0]), "Eliminated rider completes route and stops at the boxes/access zone")
	g.free()
	print("SHARED_RACE_TRAFFIC failures=", failures)
	quit(0 if failures == 0 else 1)
