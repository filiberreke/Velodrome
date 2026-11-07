extends SceneTree
const Ramp := preload("res://ftp_ramp.gd")
const Training := preload("res://ftp_training.gd")
const Client := preload("res://trainer_control.gd")
class ClockTraining extends Training:
	var clock := 0.0
	func now_s() -> float: return clock
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func ramp() -> RefCounted:
	var session := Ramp.new()
	session.start(0.0)
	session.tick(300.0, false)
	session.tick(301.0, true)
	return session

func run_test() -> void:
	var session := Ramp.new()
	session.start(10.0)
	check(session.phase == "WARMUP" and session.target(10.0) == 0, "Free warmup has no ERG target")
	session.sample(20.0, 900.0)
	session.tick(309.99, false)
	check(session.phase == "WARMUP" and session.best_60 == 0, "Exactly five minutes; warmup power excluded")
	session.tick(310.0, false)
	check(session.phase == "CONNECTING" and session.target(310.0) == 100, "Ramp requests 100 W after countdown")
	session.tick(312.0, true)
	check(session.ramp_at == 312.0 and session.target(371.99) == 100 and session.target(372.0) == 120, "60-second stages begin at hardware confirmation")
	session = ramp()
	for t in range(91): session.sample(301.0 + t, 200.0 if t < 60 else 300.0)
	check(is_equal_approx(session.best_60, 250.0) and is_equal_approx(session.ftp(), 187.5), "Partial final stage contributes to rolling measured minute")
	session = ramp()
	# Uneven sample spacing must be weighted by elapsed time, not sample count.
	var at := 301.0
	while at < 391.0:
		session.sample(at, 250.0)
		at = minf(391.0, at + (0.27 if int(at * 100) % 2 == 0 else 0.81))
	session.sample(391.0, 250.0)
	check(is_equal_approx(session.best_60, 250.0), "Irregular measured intervals integrate to correct power")
	check(session.segments.size() < 230, "Rolling history remains bounded")
	session = ramp()
	session.sample(301.0, 250.0)
	session.sample(303.0, 250.0)
	check(session.phase == "RESULT" and session.best_60 == 0.0, "Gap cannot be filled with held power")
	session = ramp()
	for t in range(22): session.sample(301.0 + t, 50.0)
	check(session.phase == "RESULT", "Sustained underpower stops after grace period")
	session = ramp()
	for t in range(16): session.sample(301.0 + t, 89.0, 25.0)
	check(session.phase == "RESULT", "Low cadence and underpower detect stall")
	session = ramp()
	for t in range(16): session.sample(301.0 + t, 100.0, -1.0)
	check(session.phase == "RAMP", "Absent cadence does not cause false stall")
	session.sample(317.0, NAN)
	check(session.phase == "RESULT", "Non-finite measurement stops safely")
	var old_bridge := ClockTraining.new()
	root.add_child(old_bridge)
	old_bridge.set_process(false)
	old_bridge.receive({"type":"telemetry", "valid":true, "power_w":200, "sample_id":1}, 0.0)
	check(not old_bridge.fresh(0.0) and old_bridge.bridge_update_needed, "Old bridge cannot masquerade as fresh measured power")
	old_bridge.receive({"type":"telemetry", "valid":true, "power_w":200, "sample_id":2, "power_sample_id":1, "power_age_s":2.0}, 2.0)
	check(not old_bridge.fresh(2.0), "Cadence/speed packets cannot hide stale power")
	old_bridge.free()
	# A Reset ACK only accepts the request. Continue status polling until the
	# bridge confirms the actual FTMS release, even after the HUD is hidden.
	var release_client := Client.new()
	release_client.erg_only = true
	release_client.phase = "RELEASING"
	release_client.requests["reset"] = {"packet":{"command":"set_target_power", "watts":0}, "seq":1}
	release_client.handle_response({"type":"ack", "v":1, "ok":true, "id":"reset", "state":{"release_confirmed":false, "udp_owned":false}}, 0.0)
	check(release_client.phase == "RELEASING", "Accepted Reset is not hardware confirmation")
	release_client.requests["status"] = {"packet":{"command":"status"}, "seq":2}
	release_client.handle_response({"type":"ack", "v":1, "ok":true, "id":"status", "state":{"release_confirmed":true, "udp_owned":false}}, 1.0)
	check(release_client.phase == "IDLE", "Status confirms eventual hardware release")
	await test_udp()
	print("FTP_RAMP failures=", failures)
	quit(0 if failures == 0 else 1)

func feed(page: Control, id: int, power: Variant = 180.0, valid: bool = true) -> void:
	page.receive({"type": "telemetry", "sample_id": id, "power_sample_id": id, "power_age_s": 0.0, "valid": valid, "power_w": power, "cadence_rpm": 80}, page.clock)

func test_udp() -> void:
	var server := PacketPeerUDP.new()
	check(server.bind(0, "127.0.0.1") == OK, "Local bridge mock binds")
	var page := ClockTraining.new()
	root.add_child(page)
	page.set_process(false)
	page.trainer.port = server.get_local_port()
	feed(page, 1)
	page.begin()
	page._process(0.0)
	check(not page.trainer.socket.is_bound(), "Warmup sends no trainer commands")
	check(page.result.text.contains("05:00") and page.warmup_hint.visible, "Countdown and advisory power displayed")
	page.clock = 299.9
	feed(page, 2)
	page._process(0.0)
	check(page.result.text.contains("00:01"), "Countdown rounds up before ERG")
	page.clock = 300.0
	feed(page, 3)
	page._process(0.0)
	var state := {"started": true, "disabled": false, "simulation_supported": false, "power_supported": true, "mode": "SIM", "desired_mode": "SIM", "udp_owned": false, "release_confirmed": false, "revision": 0, "applied_revision": -1, "confirmed_target_w": null}
	var seen: Array[Dictionary] = []
	for i in range(30):
		page.clock = 300.1 + i * 0.1
		feed(page, 4 + i)
		page._process(0.0)
		await process_frame
		while server.get_available_packet_count() > 0:
			var request: Dictionary = JSON.parse_string(server.get_packet().get_string_from_utf8())
			var port := server.get_packet_port()
			seen.append(request)
			if request.command == "set_mode":
				state.desired_mode = request.mode
				state.mode = "RELEASED"
			elif request.command == "set_target_power":
				state.revision += 1
				state.udp_owned = request.watts > 0
				state.mode = "ERG" if request.watts > 0 else "RELEASED"
				state.release_confirmed = request.watts == 0
				state.confirmed_target_w = request.watts
				state.applied_revision = state.revision
			server.set_dest_address("127.0.0.1", port)
			server.put_packet(JSON.stringify({"type":"ack", "v":1, "ok":true, "id":request.id, "state":state.duplicate(true)}).to_utf8_buffer())
		await process_frame
	check(page.test.phase == "RAMP", "ERG-only trainer can run without SIM feature")
	var has_target := false
	for command in seen:
		if command.command == "set_target_power" and command.watts == 100: has_target = true
	check(has_target, "Existing wire protocol sends 100 W target")
	check(page.test.best_60 == 0.0, "Short effort cannot yield FTP")
	# The same FTMS sample replayed with valid=true must not refresh freshness.
	var before: float = page.last_sample
	page.clock += 0.5
	feed(page, page.sample_id)
	check(page.last_sample == before, "Duplicate sample IDs never extend power validity")
	page.clock += 1.0
	page._process(0.0)
	check(page.test.phase == "RESULT" and not page.trainer.owned, "Silent stale measurements end test and release lease")
	await process_frame
	var released := false
	while server.get_available_packet_count() > 0:
		var request: Dictionary = JSON.parse_string(server.get_packet().get_string_from_utf8())
		if request.command == "set_target_power" and request.watts == 0: released = true
	check(released, "Safety stop uses Reset/release 0 W")
	# A delayed positive ACK after Reset must not resurrect the old test.
	page.trainer.requests["late"] = {"packet": {"command":"set_target_power", "watts":100}, "seq":999}
	page.trainer.handle_response({"type":"ack", "v":1, "ok":true, "id":"late", "state":state}, page.clock)
	check(not page.trainer.owned and page.trainer.phase == "RELEASING", "Late load ACK cannot restart stopped session")
	page.free()
	server.close()
