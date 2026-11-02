extends SceneTree
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func steer(game: Node3D, value: Variant) -> void:
	game._process_bridge_packet({"type": "steering", "value": value})
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game := Model.new()
	root.add_child(game)
	game.running = true; game.start_state = "RACING"; game.player_lane = 2
	for value in [null, true, "80", [], {}, INF, NAN, -101, 101, 24]: steer(game, value)
	check(game.player_lane == 2, "Malformed values and dead zone never steer")
	steer(game, 100)
	check(game.player_lane == 3, "Strong press moves exactly one lane")
	for i in range(20): steer(game, 100)
	check(game.player_lane == 3, "Holding strong pressure never repeats")
	steer(game, 40); steer(game, -100)
	check(game.player_lane == 3, "Pressure changes and reversal without neutral do not add moves")
	steer(game, 20); steer(game, 100)
	check(game.player_lane == 3, "Rearm requires neutral, not just lower pressure")
	steer(game, 0); steer(game, -100)
	check(game.player_lane == 2, "Opposite strong press moves one lane")
	steer(game, 0); steer(game, -100)
	check(game.player_lane == 1, "Fresh press adds one lane")
	steer(game, 0); steer(game, -100)
	check(game.player_lane == 0, "Inner boundary clamps correctly")
	steer(game, 0); steer(game, -100)
	check(game.player_lane == 0, "Holding against boundary stays clamped")
	for i in range(5):
		game.player_lane = 0; steer(game, 0); steer(game, 25 + i * 15)
		check(game.player_lane == 1, "All pressure tiers move exactly one lane")
	game.race_mode = 4
	game.lane_offsets[0] = game.LANES[0]
	game._pursuit_move_lanes(0.1)
	check(game.lane_offsets[0] > game.LANES[0] and game.lane_offsets[0] < game.LANES[5], "Multi-lane target moves smoothly rather than teleporting")
	game.race_mode = 0
	game.player_lane = 2; steer(game, 0)
	for name in ["LEFT", "RIGHT", "SHIFT_UP_LEFT", "SHIFT_DOWN_LEFT", "SHIFT_UP_RIGHT", "SHIFT_DOWN_RIGHT"]:
		game._process_bridge_packet({"type": "button", "button": name})
		game._process_bridge_packet({"type": "button", "button": "RIGHT", "source_button": name})
	check(game.player_lane == 2, "Digital navigation and shifting do not steer")
	game.start_state = "COUNTDOWN"; game.running = false
	steer(game, 100)
	game.start_state = "RACING"; game.running = true
	steer(game, 100)
	check(game.player_lane == 2, "Held-through-GO input is consumed")
	steer(game, 0); steer(game, 40)
	check(game.player_lane == 3, "Fresh gesture after GO steers")
	game.finished = true; steer(game, -100)
	check(game.player_lane == 3, "Finished race ignores steering")
	game.finished = false
	for count in [3, 4]:
		game.race_mode = 5; game.team_race.ours.reset(count); game.team_race.velocity[0] = 10
		steer(game, 0); steer(game, 40)
		check(game.team_race.ours.exchanges == 1, "Analog right starts one team exchange")
		for i in range(10): steer(game, 100)
		check(game.team_race.ours.exchanges == 1, "More pressure and held paddle cannot repeat exchange")
		game.team_race.ours.reset(count)
		steer(game, 100)
		check(game.team_race.ours.exchanges == 0, "Continuously held right cannot trigger new head turn")
		steer(game, 0); steer(game, -80)
		check(game.team_race.ours.exchanges == 0, "Team left retains automatic formation")
		game.team_race.velocity[0] = 0
		steer(game, 0); steer(game, 80)
		check(game.team_race.ours.exchanges == 0, "Stopped team cannot exchange")
	game.udp.bind(0, "127.0.0.1")
	var tx := PacketPeerUDP.new()
	tx.set_dest_address("127.0.0.1", game.udp.get_local_port())
	game.race_mode = 0; game.player_lane = 0; steer(game, 0)
	tx.put_packet('{"type":"steering","value":55}'.to_utf8_buffer())
	for i in range(30):
		await process_frame
		if game.udp.get_available_packet_count() > 0: break
	game._read_bridge()
	check(game.player_lane == 1, "Actual UDP analog frame moves one lane")
	tx.close(); game.udp.close(); game.free()
	print("ANALOG_STEERING_OK" if failures == 0 else "ANALOG_STEERING_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
