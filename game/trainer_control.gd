extends RefCounted
## Local bridge SIM client. One mutation in flight; ACK is not hardware proof.
const PORT := 51725
var port := PORT
var socket := PacketPeerUDP.new()
var session := "g%d-%d" % [Time.get_ticks_usec(), randi()]
var sequence := 0
var requests: Dictionary = {}
var pending: Dictionary = {}
var state: Dictionary = {}
var phase := "IDLE"
var error := ""
var enabled_before := false
var owned := false
var may_resume := false
var aero_supported := false
var last_status := -100.0
var last_heartbeat := -100.0
var last_change := -100.0
var last_grade := INF
var last_aero := INF
var newest_state := -1
var armed := true
var requested_erg := 0
var last_target := -1

func arm() -> void:
	# Called only by the player's explicit start action, never by reconnection.
	armed = true
	error = ""

static func route_grade(previous: Vector3, current: Vector3) -> float:
	# Bank angle itself is not road grade. Use rise / horizontal travelled path.
	var horizontal := Vector2(current.x - previous.x, current.z - previous.z).length()
	if horizontal < 0.01:
		return 0.0
	return snappedf(clampf(100.0 * (current.y - previous.y) / horizontal, -20.0, 20.0), 0.01)

func _open() -> bool:
	if socket.is_bound(): return true
	if socket.bind(0, "127.0.0.1") != OK: return false
	return socket.set_dest_address("127.0.0.1", port) == OK

func _request(command: String, params: Dictionary, now: float, mutation: bool = false) -> void:
	sequence += 1
	var packet := {"type": "command", "v": 1, "id": "%s-%d" % [session, sequence], "command": command}
	packet.merge(params)
	var request := {"packet": packet, "raw": JSON.stringify(packet).to_utf8_buffer(), "at": now, "retry_at": now + 0.3, "tries": 0, "seq": sequence}
	requests[packet.id] = request
	if mutation: pending = request
	socket.put_packet(request.raw)
	# Bound stale status/heartbeat bookkeeping if the bridge disappears.
	for id in requests.keys():
		if now - float(requests[id].at) > 4.0 and id != pending.get("packet", {}).get("id", ""):
			requests.erase(id)

func _block(reason: String, release_owned: bool = false, now: float = 0.0) -> void:
	armed = false
	error = reason
	push_warning("Trainerkoppeling: " + reason)
	phase = "BLOCKED"
	if release_owned: release(now)

func release(now: float) -> void:
	if not owned and pending.get("packet", {}).get("command", "") != "set_grade": return
	# 0 W is Reset/release; 0% would keep road resistance active.
	may_resume = true
	owned = false
	pending = {}
	phase = "RELEASING"
	_request("set_target_power", {"watts": 0}, now, true)

func _receive(now: float) -> void:
	while socket.get_available_packet_count() > 0:
		var raw := socket.get_packet()
		if socket.get_packet_ip() != "127.0.0.1" or socket.get_packet_port() != port: continue
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if parsed is Dictionary: handle_response(parsed, now)

func handle_response(packet: Dictionary, now: float) -> void:
	var id: Variant = packet.get("id")
	if not id is String or not requests.has(id) or packet.get("v") != 1: return
	if packet.get("type") not in ["ack", "error"]: return
	var request: Dictionary = requests[id]
	requests.erase(id)
	var command: String = request.packet.command
	if pending.get("packet", {}).get("id", "") == id: pending = {}
	if packet.get("ok") != true:
		var code: String = str(packet.get("code", "invalid_reply"))
		# Console/another client owns control now. Never reset their session.
		if code in ["no_lease", "control_busy", "wrong_mode"]:
			owned = false
			may_resume = false
		_block(code, owned, now)
		return
	if not packet.get("state") is Dictionary: 
		_block("invalid_state", owned, now)
		return
	if int(request.seq) >= newest_state:
		state = packet.state
		newest_state = int(request.seq)
		aero_supported = state.get("aero_scale_supported", false) == true
	if state.get("disabled", false):
		owned = false
		_block(str(state.get("last_error", "bridge_disabled")))
		return
	if command == "set_target_power" and int(request.packet.get("watts", 0)) == 0:
		# Reset is a release, not a positive ERG target.
		phase = "BLOCKED" if enabled_before else "IDLE"
		return
	if command == "set_target_power":
		owned = true
		phase = "ACTIVE"
		last_target = int(request.packet.watts)
		return
	if command == "set_mode" and phase == "SWITCHING":
		phase = "READY"
		last_grade = INF
		last_aero = INF
		last_target = -1
		return
	if phase in ["BLOCKED", "RELEASING", "IDLE"]: return
	if command == "set_grade":
		owned = true
		may_resume = false
		phase = "ACTIVE"
		last_heartbeat = now
	elif command == "set_mode":
		phase = "READY"
	elif command == "status" and phase == "PROBE":
		if not state.get("started", false): return
		if state.get("waiting_for_feedback", false): return
		if state.get("reconnect_ready", false) and not state.get("release_confirmed", false): return
		if not state.get("simulation_supported", false):
			_block("simulation_unsupported")
		elif state.get("udp_owned", false):
			_block("control_busy")
		elif state.get("mode") == "RELEASED" and state.get("release_confirmed", false) and (may_resume or state.get("reconnect_ready", false)):
			_request("set_mode", {"mode": "SIM"}, now, true)
		elif state.get("mode") == "SIM" and state.get("desired_mode") == "SIM":
			phase = "READY"
		else:
			_block("Bestaande ERG/andere regelmodus blijft behouden")
	elif command in ["heartbeat", "status"] and owned:
		if not state.get("udp_owned", false) or (state.get("desired_mode") == "SIM" and state.get("desired_sim_backend") != "simulation") or state.get("desired_mode") not in ["SIM", "ERG"]:
			owned = false
			may_resume = false
			_block("Trainerbediening overgenomen")

func tick(enabled: bool, grade: float, aero: float, now: float, erg_watts: int = 0) -> void:
	requested_erg = clampi(erg_watts, 0, 1300)
	enabled = enabled and armed
	if not socket.is_bound() and not enabled: return
	if not _open():
		_block("Lokale commandosocket niet beschikbaar")
		return
	if enabled and not enabled_before and phase != "RELEASING":
		phase = "PROBE"
		error = ""
		state = {}
		last_status = -100.0
		last_grade = INF
		last_aero = INF
		last_target = -1
	if not enabled and enabled_before:
		release(now)
		armed = false
	enabled_before = enabled
	_receive(now)
	if not pending.is_empty() and now >= float(pending.retry_at):
		if int(pending.tries) >= 3:
			var was_release: bool = pending.packet.command == "set_target_power"
			pending = {}
			_block("Geen antwoord van bridge", owned and not was_release, now)
		else:
			socket.put_packet(pending.raw) # Identical id, content and source port.
			pending.tries += 1
			pending.retry_at = now + 0.3 * pow(2.0, int(pending.tries))
	if phase in ["PROBE", "READY", "ACTIVE", "RELEASING"] and now - last_status >= 1.0:
		_request("status", {}, now)
		last_status = now
	if owned and phase == "ACTIVE" and now - last_heartbeat >= 1.0:
		_request("heartbeat", {}, now)
		last_heartbeat = now
	if not enabled or phase not in ["READY", "ACTIVE"] or not pending.is_empty(): return
	if now - last_change < 0.2: return
	var target_mode := "ERG" if requested_erg > 0 else "SIM"
	if state.get("desired_mode", "SIM") != target_mode:
		# Switch modes only within our own session; never take over another controller.
		if not owned: return
		phase = "SWITCHING"
		_request("set_mode", {"mode": target_mode}, now, true)
		last_change = now
		return
	if target_mode == "ERG":
		if requested_erg != last_target:
			_request("set_target_power", {"watts": requested_erg, "ramp_w_per_s": 300.0}, now, true)
			last_change = now
		return
	grade = snappedf(clampf(grade, -20.0, 20.0), 0.01)
	aero = snappedf(clampf(aero, 0.0, 1.0), 0.01)
	if absf(grade - last_grade) < 0.05 and (not aero_supported or absf(aero - last_aero) < 0.02): return
	var params := {"grade_pct": grade, "ramp_pct_per_s": 10.0}
	if aero_supported: params["aero_scale"] = aero
	_request("set_grade", params, now, true)
	last_grade = grade
	last_aero = aero
	last_change = now

func close() -> void:
	if socket.is_bound():
		release(Time.get_ticks_msec() / 1000.0)
		socket.close()

