extends SceneTree

class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func press(game: Node3D, direction: int) -> void:
	game._process_steering(0)
	game._process_steering(direction * 100)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game := Model.new()
	root.add_child(game)
	check(game.LANES.size() == 11, "Eleven selectable player lanes")
	check(is_equal_approx(game.LANES[0], 1.18) and is_equal_approx(game.LANES[-1], 7.18), "Original physical boundaries preserved")
	check(is_equal_approx(game.LANES[-1] - game.LANES[0], 6.0), "Total lateral span remains six metres")
	for i in range(1, game.LANES.size()):
		check(is_equal_approx(game.LANES[i] - game.LANES[i - 1], 0.60), "Each player step is 0.60 m")
	for mode in [0, 1, 2, 4, 7]:
		game.race_mode = mode; game.rider_count = 4 if mode < 4 else (2 if mode == 4 else 1)
		game.race_laps = 10
		game._configure_peloton()
		game.running = true; game.finished = false; game.start_state = "RACING"; game.player_lane = 0
		for i in range(1, 11):
			press(game, 1)
			check(game.player_lane == i, "Fresh right press selects exactly the next lane in mode %d" % mode)
			game._process_steering(100); game._process_steering(-100)
			check(game.player_lane == i, "Hold/reversal without release does not repeat")
		press(game, 1)
		check(game.player_lane == 10, "Outer boundary clamps to lane eleven")
		for i in range(9, -1, -1):
			press(game, -1)
			check(game.player_lane == i, "Fresh left press selects exactly the previous lane")
		press(game, -1)
		check(game.player_lane == 0, "Inner boundary clamps to lane one")
		game._steer_player(1)
		check(game.player_lane == 1, "Keyboard uses the same next lane")
		game.player_lane = 10; game.lane_offsets[0] = game.LANES[0]
		game._move_lanes(0.1)
		check(is_equal_approx(game.lane_offsets[0], game.LANES[0] + game.LANE_CHANGE_MPS * 0.1), "Movement animates at the original lateral speed")
		game.finished = true; game._steer_player(-1); press(game, -1)
		check(game.player_lane == 10, "Finished races ignore keyboard and paddle steering")
		game.finished = false
	# Original six-abreast start grid must not shrink to half-width corridors.
	for mode in [0, 1]:
		game.race_mode = mode; game.rider_count = 12; game._configure_peloton()
		check(is_equal_approx(game.lane_offsets[5], 7.18) and is_equal_approx(game.distances[6], -2.4), "Original start grid preserved")
		for i in range(12):
			for j in range(i):
				check(absf(game.lane_offsets[i] - game.lane_offsets[j]) >= 0.88 or absf(game.distances[i] - game.distances[j]) >= 2.0, "Starting bicycles do not overlap")
	# Continuous AI targets remain reachable by animation without snapping to player lanes.
	for mode in [0, 1, 2]:
		game.race_mode = mode; game.rider_count = 4; game._configure_peloton()
		game.distances.assign([50.0, 53.0, 90.0, 110.0]); game.speeds.fill(12.0)
		game.lane_offsets.assign([1.78, 1.95, 5.98, 7.18]); game.x_ai.lane_targets = game.lane_offsets.duplicate()
		game.x_ai.lane_targets[1] = 2.05; game.player_lane = 1
		game._move_lanes(0.1)
		check(game.player_lane == 1 and is_equal_approx(game.lane_offsets[0], 1.78), "Only manual input sets the player's lane")
		check(is_equal_approx(game.lane_offsets[1], 2.05), "AI retains continuous intermediate lane target")
		var aligned: float = game._draft_target(0)
		check(aligned > 0.0 and game.draft_leaders[0] == 1, "Player receives slipstream from intermediate AI position")
		game.lane_offsets[0] = 1.18
		check(aligned > game._draft_target(0), "Finer player line improves alignment and drafting")
	# Formation uses its physical pull-off distance, independent of player indices.
	game.race_mode = 5; game.team_size = 4; game.rider_count = 8; game._configure_peloton()
	game.team_race.ours.reset(4); game.team_race.theirs.reset(4); game.team_race.velocity[0] = 10.0
	game.player_lane = 3
	press(game, -1)
	check(game.player_lane == 3 and game.team_race.ours.exchanges == 0, "Team left has no lane control")
	press(game, 1)
	check(game.player_lane == 3 and game.team_race.ours.exchanges == 1, "Single right press requests pull-off without lane control")
	game._process_steering(100)
	check(game.team_race.ours.exchanges == 1, "Held team paddle does not repeat")
	game.team_race.ours.lanes[0] = 1.0
	game.team_race._apply_formation(game)
	check(is_equal_approx(game.lane_offsets[0], 3.58), "Team pull-off retains original physical width")
	check(is_equal_approx(game.FINISH_CAMERA_LANE_M, 2.38), "Finish camera retains original position")
	game.free()
	print("PLAYER_LANES_OK" if failures == 0 else "PLAYER_LANES_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
