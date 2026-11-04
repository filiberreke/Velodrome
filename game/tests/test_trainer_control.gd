extends SceneTree
const Client := preload("res://trainer_control.gd")
class RouteGame extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _advance_race(_dt: float) -> void:
		distances[0] += 0.2
		lane_offsets[0] += 0.15
var failures := 0
var seen: Array[Dictionary] = []
var source_ports: Array[int] = []
var bridge := {"started": true, "disabled": false, "simulation_supported": true, "aero_scale_supported": true, "mode": "SIM", "desired_mode": "SIM", "desired_sim_backend": "resistance", "udp_owned": false, "release_confirmed": false}
var drop_grade := true
var first_grade: Dictionary = {}
var takeover := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func pump(server: PacketPeerUDP) -> void:
	while server.get_available_packet_count() > 0:
		var request: Dictionary = JSON.parse_string(server.get_packet().get_string_from_utf8())
		var source_port := server.get_packet_port()
		seen.append(request)
		source_ports.append(source_port)
		var cmd: String = request.command
		if cmd == "set_grade":
			bridge.udp_owned = true
			bridge.desired_sim_backend = "simulation"
			if drop_grade:
				drop_grade = false
				first_grade = request.duplicate(true)
				continue
		elif cmd == "set_target_power":
			bridge.mode = "RELEASED"; bridge.desired_mode = "ERG"
			bridge.release_confirmed = true; bridge.udp_owned = false
		elif cmd == "set_mode":
			bridge.mode = "SIM"; bridge.desired_mode = "SIM"
		var reply := {"type": "ack", "ok": true, "v": 1, "id": request.id, "state": bridge.duplicate(true)}
		if takeover and cmd == "heartbeat":
			reply.type = "error"; reply.ok = false; reply.code = "no_lease"
		server.set_dest_address("127.0.0.1", source_port)
		server.put_packet(JSON.stringify(reply).to_utf8_buffer())

func cycle(client: RefCounted, server: PacketPeerUDP, active: bool, now: float) -> void:
	client.tick(active, 4.123, 0.31, now)
	await process_frame
	pump(server)
	await process_frame

func run_test() -> void:
	check(Client.route_grade(Vector3.ZERO, Vector3(10, 1, 0)) == 10.0, "Actual rise/run yields 10%")
	check(Client.route_grade(Vector3.ZERO, Vector3(10, -1, 0)) == -10.0, "Descending path signed")
	check(Client.route_grade(Vector3.ZERO, Vector3(0, 1, 0)) == 0, "No forward path cannot divide by zero")
	check(Client.route_grade(Vector3.ZERO, Vector3(1, 1, 0)) == 20, "Game grade limited to bridge domain")
	var game := RouteGame.new(); root.add_child(game)
	game.distances[0] = game.STRAIGHT + 25.0
	game.lane_offsets[0] = 4.78
	var pos: Vector3 = game._at(game.distances[0], game.lane_offsets[0])
	check(absf(Client.route_grade(pos, game._at(game.distances[0] + .1, game.lane_offsets[0]))) < .01, "42 degree bank is not 42% longitudinal grade")
	game._update_race(.1)
	check(game.trainer_road_grade > 0, "Game wrapper includes climbing across banked lanes")
	game.free()
	var client := Client.new()
	client.tick(false, 5, .31, 100)
	check(not client.socket.is_bound(), "Demo never opens command socket")
	var server := PacketPeerUDP.new()
	check(server.bind(0, "127.0.0.1") == OK, "Mock bridge loopback bound")
	client.port = server.get_local_port()
	for i in range(35): await cycle(client, server, true, 100.0 + .1 * i)
	check(client.phase == "ACTIVE" and client.owned, "Status handshake and simulation lease completed over UDP")
	var grades: Array = seen.filter(func(p): return p.command == "set_grade")
	check(grades.size() == 2 and grades[0] == grades[1] and grades[0] == first_grade, "Lost ACK retries byte-equivalent command with identical id")
	check(grades[0].grade_pct == 4.12 and grades[0].aero_scale == .31, "Grade quantization and slipstream sent")
	check(seen.filter(func(p): return p.command == "heartbeat").size() >= 2, "New heartbeats sustain constant grade")
	check(seen.filter(func(p): return p.command == "set_mode").is_empty(), "SIM is not reset on each update")
	check(source_ports.all(func(p): return p == source_ports[0]), "Stable source socket for lease and retries")
	for i in range(5): await cycle(client, server, false, 104.0 + .1 * i)
	check(seen.any(func(p): return p.command == "set_target_power" and p.watts == 0), "Finish/reset releases with 0 W, not 0%")
	client.arm()
	for i in range(15): await cycle(client, server, true, 105.0 + .1 * i)
	check(client.owned and client.phase == "ACTIVE", "Explicit next race can resume own released session")
	var releases_before := seen.filter(func(p): return p.command == "set_target_power").size()
	takeover = true
	for i in range(25): await cycle(client, server, true, 107.0 + .1 * i)
	check(client.phase == "BLOCKED" and not client.owned, "Console takeover prevents automatic reclaim")
	check(seen.filter(func(p): return p.command == "set_target_power").size() == releases_before, "No reset of another owner's control")
	client.close(); server.close()
	# Initial ERG must never be hijacked.
	var erg := Client.new(); erg.port = 9
	erg.arm()
	erg.tick(true, 5, .31, 200)
	var probe_id: String = erg.requests.keys()[0]
	erg.handle_response({"type": "ack", "ok": true, "v": 1, "id": probe_id, "state": {"started": true, "disabled": false, "simulation_supported": true, "mode": "ERG", "desired_mode": "ERG", "udp_owned": false}}, 200.1)
	check(erg.phase == "BLOCKED" and not erg.owned and erg.pending.is_empty(), "Existing ERG preserved")
	erg.close()
	# Old v0.15 gets grade only; a missing ACK cannot trigger indefinite writes.
	var legacy := Client.new(); legacy.port = 9
	legacy.tick(true, 3, .31, 300)
	var legacy_id: String = legacy.requests.keys()[0]
	var legacy_state := {"started": true, "disabled": false, "simulation_supported": true, "mode": "SIM", "desired_mode": "SIM", "udp_owned": false}
	legacy.handle_response({"type": "ack", "ok": true, "v": 1, "id": legacy_id, "state": legacy_state}, 300.01)
	legacy.tick(true, 3, .31, 300.02)
	check(legacy.pending.packet.command == "set_grade" and not legacy.pending.packet.has("aero_scale"), "Old bridge receives compatible grade-only command")
	for stamp in [300.4, 301.1, 302.4, 304.9]: legacy.tick(true, 3, .31, stamp)
	check(legacy.phase == "BLOCKED" and legacy.pending.is_empty(), "Mutation timeout bounds retries")
	legacy.tick(false, 0, 1, 305)
	legacy.tick(true, 0, 1, 306)
	check(legacy.phase == "BLOCKED", "Reconnect cannot automatically re-arm after failure")
	legacy.close()
	# A new explicit start can use a recovered bridge without restarting it.
	var recovered := Client.new(); recovered.port = 9
	recovered.tick(true, 3, 1, 400)
	var recovered_id: String = recovered.requests.keys()[0]
	var recovered_state := {"started": true, "disabled": false, "simulation_supported": true, "mode": "RELEASED", "desired_mode": "ERG", "udp_owned": false, "waiting_for_feedback": true, "reconnect_ready": true, "release_confirmed": false}
	recovered.handle_response({"type": "ack", "ok": true, "v": 1, "id": recovered_id, "state": recovered_state}, 400.1)
	check(recovered.phase == "PROBE" and recovered.pending.is_empty(), "Recovery waits for fresh power and Reset confirmation")
	recovered.tick(true, 3, 1, 401.1)
	recovered_id = recovered.requests.keys()[-1]
	recovered_state.waiting_for_feedback = false
	recovered_state.release_confirmed = true
	recovered.handle_response({"type": "ack", "ok": true, "v": 1, "id": recovered_id, "state": recovered_state}, 401.2)
	check(not recovered.pending.is_empty() and recovered.pending.packet.command == "set_mode" and recovered.pending.packet.mode == "SIM", "Explicit race claims released recovery session without bridge restart")
	recovered.close()
	# A new Godot process has no may_resume history, but the player's explicit
	# race start may claim a confirmed release left by the previous process.
	var released_state := {"started": true, "disabled": false, "simulation_supported": true, "mode": "RELEASED", "desired_mode": "ERG", "udp_owned": false, "release_confirmed": false}
	var fresh := Client.new(); fresh.port = 9; fresh.arm()
	fresh.tick(true, 0, 1, 500)
	var fresh_id: String = fresh.requests.keys()[0]
	fresh.handle_response({"type": "ack", "ok": true, "v": 1, "id": fresh_id, "state": released_state.duplicate()}, 500.1)
	check(fresh.phase == "PROBE" and fresh.pending.is_empty(), "Explicit start waits for confirmed release")
	fresh.tick(true, 0, 1, 501.1)
	fresh_id = fresh.requests.keys()[-1]
	released_state.release_confirmed = true
	fresh.handle_response({"type": "ack", "ok": true, "v": 1, "id": fresh_id, "state": released_state.duplicate()}, 501.2)
	check(fresh.pending.get("packet", {}).get("command") == "set_mode", "Explicit start recovers released bridge without previous session history")
	fresh.close()
	var implicit := Client.new(); implicit.port = 9
	implicit.arm(false); implicit.tick(true, 0, 1, 600)
	var implicit_id: String = implicit.requests.keys()[0]
	implicit.handle_response({"type": "ack", "ok": true, "v": 1, "id": implicit_id, "state": released_state.duplicate()}, 600.1)
	check(implicit.phase == "BLOCKED" and implicit.pending.is_empty(), "Automatic recovery cannot claim an unrelated released session")
	implicit.close()
	var busy := Client.new(); busy.port = 9; busy.arm()
	busy.tick(true, 0, 1, 700)
	var busy_id: String = busy.requests.keys()[0]
	released_state.udp_owned = true
	busy.handle_response({"type": "ack", "ok": true, "v": 1, "id": busy_id, "state": released_state.duplicate()}, 700.1)
	check(busy.phase == "BLOCKED" and busy.pending.is_empty(), "Explicit start cannot claim another controller's session")
	busy.close()
	# A new race can be armed while the previous race's release ACK is pending.
	# On receipt of the reset ACK it must enter PROBE, not stay BLOCKED.
	var quick := Client.new(); quick.port = 9
	check(quick._open(), "Quick recovery mock UDP socket opened")
	quick.owned = true
	quick.enabled_before = true
	quick.phase = "ACTIVE"
	quick.release(800.0)
	var release_id: String = str(quick.pending.packet.id)
	quick.arm()
	quick.tick(true, 0, 1, 800.1)
	quick.handle_response({"type": "ack", "v": 1, "ok": true, "id": release_id, "state": released_state.duplicate()}, 800.2)
	check(quick.phase == "PROBE" and quick.armed, "Pending release ACK starts a newly armed game's probe")
	quick.tick(true, 0, 1, 800.3)
	check(quick.requests.values().any(func(r): return r.packet.command == "status"), "New race checks bridge status after late reset")
	quick.close()
	print("TRAINER_CONTROL_OK" if failures == 0 else "TRAINER_CONTROL_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

