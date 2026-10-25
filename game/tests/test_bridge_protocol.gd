extends SceneTree
const Game := preload("res://main.gd")
class Protocol extends "res://main.gd":
	var resets := 0
	func _ready() -> void: set_physics_process(false)
	func _save_recording(_reason: String) -> void: pass
	func _reset() -> void:
		resets += 1
		start_state = "SETUP"
		running = false
var failures := 0
var udp_tested := false

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	check(Game.UDP_PORT == 51723, "Existing UDP port unchanged")
	for gear in range(1, 13):
		check(Game._bridge_optional_integer(gear, 1, 12) == gear, "All specified SIM gears accepted")
		check(Game._bridge_optional_integer(float(gear), 1, 12) == gear, "Integral JSON floats accepted")
	for invalid in [null, false, true, 0, -1, 13, 4.5, "4", [], {}, INF, NAN]:
		check(Game._bridge_optional_integer(invalid, 1, 12) == null, "Invalid gear unavailable")
	for invalid in [null, false, 0, -10, 143.5, "143", INF, NAN, [], {}]:
		check(Game._bridge_optional_integer(invalid) == null, "Invalid heart rate unavailable")
	var game := Protocol.new(); root.add_child(game)
	check(game.trainer_heart_rate_bpm == null and game.trainer_selected_gear == null, "Optional fields initially unavailable")
	game.trainer_seen = true; game.start_state = "RACING"; game.running = true
	game.recording_active = true
	game._process_bridge_json('{"type":"telemetry","valid":true,"power_w":170,"speed_kmh":39.0,"cadence_rpm":87,"sample_id":42,"heart_rate_bpm":143,"gear":4}')
	check(game.watts == 170.0 and game.trainer_speed_kmh == 39.0 and game.cadence == 87.0 and game.connected, "Existing KICKR fields and valid flag retained")
	check(game.trainer_selected_gear == 4 and game.trainer_gear == "4" and game.trainer_heart_rate_bpm == 143, "Protocol v0.13.1 example processed")
	check(game.ride_records.size() == 1, "One FTMS record for original sample")
	game._process_bridge_json('{"type":"telemetry","valid":true,"power_w":185,"speed_kmh":39.1,"cadence_rpm":88,"sample_id":42,"heart_rate_bpm":144,"gear":5}')
	check(game.trainer_selected_gear == 5 and game.trainer_heart_rate_bpm == 144 and game.watts == 185.0, "Same sample id still updates all live telemetry")
	check(game.ride_records.size() == 1, "Repeated sample id does not duplicate original FTMS record")
	game._process_bridge_packet({"type": "telemetry", "valid": false, "heart_rate_bpm": 155, "gear": null, "sample_id": 42})
	check(not game.connected and game.trainer_heart_rate_bpm == 155 and game.trainer_selected_gear == null and game.trainer_gear == "—", "Heart rate independent of invalid KICKR; null ERG/STOP gear clears previous value")
	check(game.watts == 185.0 and game.cadence == 88.0, "Existing short dropout hold retained")
	game._process_bridge_packet({"type": "telemetry", "valid": false, "heart_rate_bpm": null})
	check(game.trainer_heart_rate_bpm == null, "Bridge stale-heart-rate null clears immediately")
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": null, "speed_kmh": null, "cadence_rpm": null, "sample_id": null})
	check(game.watts == 0.0 and game.cadence == -1.0 and game.trainer_speed_kmh == -1.0, "Null numeric KICKR fields safe")
	check(game.trainer_selected_gear == null and game.trainer_heart_rate_bpm == null, "Missing optional fields unavailable")
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": -20, "speed_kmh": "bad", "cadence_rpm": [], "gear": 13, "heart_rate_bpm": 100.5})
	check(game.watts == 0.0 and game.trainer_speed_kmh == -1.0 and game.cadence == -1.0 and game.trainer_selected_gear == null and game.trainer_heart_rate_bpm == null, "Malformed numeric fields rejected without unsafe casts")
	game._process_bridge_packet({"type": "telemetry", "valid": false, "gear": 6, "heart_rate_bpm": 160})
	var last_received: float = game.last_bridge_telemetry
	game.last_telemetry = -100.0
	game._expire_bridge_optional_fields(last_received + 0.5)
	check(game.trainer_heart_rate_bpm == 160, "KICKR timeout does not clear a live independent HR stream")
	game._expire_bridge_optional_fields(last_received + 1.01)
	check(game.trainer_heart_rate_bpm == null and game.trainer_selected_gear == null and game.trainer_gear == "—", "Stopped whole UDP stream expires optional data")
	for invalid_json in ['not json', '[]', 'null', '42', '"hello"', '{"type":"unknown"}']:
		game._process_bridge_json(invalid_json)
	check(game.trainer_heart_rate_bpm == null, "Malformed or unrelated messages cannot invent telemetry")
	game.player_lane = 2
	for button in ["RIGHT", "SHIFT_UP_RIGHT"]: game._process_bridge_packet({"type": "button", "button": button})
	check(game.player_lane == 4, "Existing right button aliases retained")
	for button in ["LEFT", "SHIFT_DOWN_LEFT", "SHIFT_DOWN_RIGHT"]: game._process_bridge_packet({"type": "button", "button": button})
	check(game.player_lane == 1, "Existing left button aliases retained")
	game.running = false; game._process_bridge_packet({"type": "button", "button": "RIGHT"})
	check(game.player_lane == 1, "Buttons do not move rider outside running race")
	game._process_bridge_packet({"type": "button", "button": "A"})
	check(game.resets == 1, "Existing A reset button retained")
	game.trainer_seen = false; game.start_state = "RACING"
	game._process_bridge_packet({"type": "telemetry", "valid": true, "gear": 4, "heart_rate_bpm": 145})
	check(game.resets == 2 and game.trainer_selected_gear == 4 and game.trainer_heart_rate_bpm == 145, "Existing mid-demo trainer reset retained, then metadata applied")
	check(Game._gear_from_packet({"gear_label": " 50×15 "}) == "50×15", "Legacy label fallback retained")
	check(Game._gear_from_packet({"gear": null, "gear_label": "old"}) == "—", "Canonical null gear overrides any legacy label")
	var error: Error = game.udp.bind(0, "127.0.0.1")
	if error == OK:
		var sender := PacketPeerUDP.new()
		check(sender.set_dest_address("127.0.0.1", game.udp.get_local_port()) == OK, "Loopback sender configured on ephemeral test port")
		check(sender.put_packet('{"type":"telemetry","valid":false,"sample_id":42,"heart_rate_bpm":152,"gear":null}'.to_utf8_buffer()) == OK, "Loopback packet sent")
		for i in range(30):
			await process_frame
			if game.udp.get_available_packet_count() > 0: break
		game._read_bridge()
		udp_tested = game.trainer_heart_rate_bpm == 152
		check(udp_tested and game.trainer_selected_gear == null, "Actual UDP receive path updates independent HR")
		sender.close(); game.udp.close()
	else:
		print("BRIDGE_UDP_LOOPBACK_UNAVAILABLE: ", error)
	game.free()
	var file := FileAccess.open("res://tests/bridge_protocol_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "udp_loopback_tested": udp_tested})); file.close()
	print("BRIDGE_PROTOCOL_OK" if failures == 0 else "BRIDGE_PROTOCOL_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
