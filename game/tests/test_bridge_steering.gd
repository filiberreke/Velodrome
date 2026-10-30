extends SceneTree

class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func prepare_team(game: Node3D, count: int) -> void:
	game.race_mode = 5
	game.running = true
	game.player_lane = 0
	game.team_race.ours.reset(count)
	game.team_race.velocity[0] = 10.0
	game.team_race.ours.step(2.0, 300.0, 300.0)
	game.start_state = "RACING"
	game._process_bridge_packet({"type": "steering", "value": 0})

func run_test() -> void:
	var game := Model.new()
	root.add_child(game)
	check(game.udp.bind(0, "127.0.0.1") == OK, "Receive socket bound on isolated port")
	var sender := PacketPeerUDP.new()
	sender.set_dest_address("127.0.0.1", game.udp.get_local_port())
	for count in [3, 4]:
		for pressure in [25, 85]:
			prepare_team(game, count)
			sender.put_packet(JSON.stringify({"type": "steering", "value": pressure}).to_utf8_buffer())
			for i in range(30):
				await process_frame
				if game.udp.get_available_packet_count() > 0: break
			game._read_bridge()
			check(game.team_race.ours.player_is_out() and game.team_race.ours.phase == "OUT", "UDP analog %d starts player exchange in team of %d" % [pressure, count])
			check(game.player_lane == 0, "Team input does not modify ignored free-lane selection")
			game._process_bridge_packet({"type": "steering", "value": pressure})
			check(game.team_race.ours.exchanges == 1, "Duplicate right cannot restart exchange")
		for button in ["SHIFT_UP_LEFT", "SHIFT_DOWN_LEFT", "SHIFT_UP_RIGHT", "SHIFT_DOWN_RIGHT"]:
			prepare_team(game, count)
			game._process_bridge_packet({"type": "button", "button": button})
			check(game.team_race.ours.exchanges == 0 and game.player_lane == 0, "Raw shifting must not steer or exchange")
			game._process_bridge_packet({"type": "button", "button": "RIGHT", "source_button": button})
			check(game.team_race.ours.exchanges == 0 and game.player_lane == 0, "Mapped shift preserves source and cannot exchange")
		for button in ["LEFT", "SHIFT_DOWN_LEFT", "SHIFT_DOWN_RIGHT"]:
			prepare_team(game, count)
			game.player_lane = 2
			game._process_bridge_packet({"type": "button", "button": button})
			check(game.player_lane == 2 and game.team_race.ours.exchanges == 0, "Team left matches keyboard: formation controls lanes")
		prepare_team(game, count)
		game.team_race.velocity[0] = 0.0
		game._process_bridge_packet({"type": "steering", "value": 25})
		check(game.team_race.ours.exchanges == 0, "Stopped team cannot exchange")
		prepare_team(game, count)
		game.team_race.ours.order.pop_front()
		game.team_race.ours.order.append(0)
		game._process_bridge_packet({"type": "steering", "value": 25})
		check(game.team_race.ours.exchanges == 0, "Following player cannot exchange")
		prepare_team(game, count)
		game.running = false
		game._process_bridge_packet({"type": "steering", "value": 25})
		check(game.team_race.ours.exchanges == 0, "Input outside running race cannot exchange")
		prepare_team(game, count)
		var key := InputEventKey.new()
		key.keycode = KEY_RIGHT
		key.pressed = true
		game._unhandled_key_input(key)
		check(game.team_race.ours.player_is_out(), "Keyboard retains exchange behavior")
	for mode in [0, 1, 4]:
		game.race_mode = mode
		game.running = true
		game.player_lane = 2
		for button in ["RIGHT", "SHIFT_UP_RIGHT"]: game._process_bridge_packet({"type": "button", "button": button})
		check(game.player_lane == 2, "Digital right navigation does not steer in other modes")
		for button in ["LEFT", "SHIFT_DOWN_LEFT", "SHIFT_DOWN_RIGHT"]: game._process_bridge_packet({"type": "button", "button": button})
		check(game.player_lane == 2, "Digital left navigation does not steer in other modes")
		game.running = false
		game._process_bridge_packet({"type": "button", "button": "RIGHT"})
		check(game.player_lane == 2, "No free steering outside running race")
	sender.close()
	game.udp.close()
	game.free()
	print("BRIDGE_STEERING_OK" if failures == 0 else "BRIDGE_STEERING_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
