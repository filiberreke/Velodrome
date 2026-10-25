extends SceneTree
const Game := preload("res://main.gd")
const Pacer := preload("res://pursuit_pacer.gd")
const Records := preload("res://pursuit_records.gd")
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_team_finish_photo(_front: float, _offsets: Array[float], _lanes: Array[float], _seconds: float) -> void: pass
	func _save_recording(_reason: String) -> void: pass
class UploadSpy extends Node:
	var payload := PackedByteArray()
	func begin_export(path: String, _title: String) -> void:
		payload = FileAccess.get_file_as_bytes(path)
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func fit_records(bytes: PackedByteArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definitions := {}
	var position := int(bytes[0])
	var end := position + int(bytes.decode_u32(4))
	while position < end:
		var header := int(bytes[position]); position += 1
		var local := header & 15
		if header & 64:
			var global_id := int(bytes.decode_u16(position + 2))
			var count := int(bytes[position + 4]); position += 5
			var fields: Array[Dictionary] = []
			for i in range(count):
				fields.append({"id": int(bytes[position]), "size": int(bytes[position + 1])})
				position += 3
			definitions[local] = {"global": global_id, "fields": fields}
		else:
			var definition: Dictionary = definitions[local]
			var values := {}
			for field in definition["fields"]:
				var width: int = field["size"]
				values[field["id"]] = int(bytes.decode_u32(position)) if width == 4 else (int(bytes.decode_u16(position)) if width == 2 else int(bytes[position]))
				position += width
			if definition["global"] == 20: result.append(values)
	return result

func run_test() -> void:
	for count in [3, 4]:
		var game = Model.new(); root.add_child(game)
		game.race_mode = 5; game.team_size = count; game.race_laps = 4
		game._configure_peloton(); game._prepare_pursuit({}, 250.0); game.team_race.prepare(game, {}, 250.0)
		game.start_state = "RACING"; game.running = true
		var train = game.team_race.ours
		train.order.assign([1, 2, 0] if count == 3 else [1, 2, 3, 0])
		for rank in range(count): train.offsets[train.order[rank]] = -float(rank) * 2.5
		train.reference_power = 300.0; train.has_player_pull = true
		game.watts = 300.0 * train.factor(count - 1)
		game.team_race.front[0] = 999.0; game.team_race.progress[0] = 999.0; game.team_race.velocity[0] = 12.0
		var dt := 0.2
		var expected := Pacer.advance(game, 999.0, 12.0, 300.0, dt, game.LANES[0], game.PURSUIT_START_M)
		var crossing: float = 50.0 + dt / float(expected["step"])
		game.clock = 50.0 + dt
		game._update_race(dt)
		check(absf(game.team_race.times[0] - crossing) < 0.000001, "Interpolated first wheel time when AI leads")
		var first := -INF
		for i in range(count): first = maxf(first, game.distances[i])
		check(is_equal_approx(first, 1000.0) and game.distances[0] < 1000.0, "Team ends on first front wheel, not trailing player")
		check(absf(game.last_lap_crossing[0] - crossing) < 0.000001, "Lap timing and finish time agree within fractional frame")
		check(absf(float(game.pursuit_half_crossings[0][-1]) - crossing) < 0.000001, "Half-lap timing shares finish instant")
		check(game.pursuit_trace[-1]["d"] == 1000.0 and is_equal_approx(game.pursuit_trace[-1]["t"], crossing), "Replay ends at team first wheel")
		check(is_equal_approx(float(game.demo_fit_records[-1]["distance_m"]), game.distances[0]) and float(game.demo_fit_records[-1]["power_w"]) == game.watts, "Demo export keeps trailing player's distance and effort")
		# Exercise real UDP recording and the actual upload builder, with a local spy.
		game.trainer_seen = true; game.recording_active = true; game.recording_saved = false
		game.ride_start_unix = 1700000000
		game.clock = 1.0; game.distances[0] = 10.0; game.speeds[0] = 10.0
		game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 121, "cadence_rpm": 81, "speed_kmh": 36, "sample_id": 1})
		game.clock = 3.0; game.distances[0] = 32.0; game.speeds[0] = 11.0
		game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 181, "cadence_rpm": 91, "speed_kmh": 39.6, "sample_id": 2})
		game.team_race.ours.leader_power = 999.0
		game.team_race.progress[0] = 1000.0
		var spy := UploadSpy.new(); game.add_child(spy); game.strava_client = spy
		game._start_strava_upload()
		check(not spy.payload.is_empty(), "Actual Strava upload path builds FIT without networking")
		var records := fit_records(spy.payload)
		check(records.size() == 2 and records[1][7] == 181 and records[1][4] == 91, "Uploaded power and cadence belong to player, not AI leader")
		check(records[1][5] == 2200 and records[1][6] == 11000, "Uploaded distance and speed belong to player, not team head")
		check(records[1][253] - records[0][253] == 2, "Upload duration comes from player samples")
		game.free()
	var old := {"version": Records.VERSION, "physics": Records.PHYSICS, "name": "Oude ploeg", "distance_m": 1000, "time_s": 20.1, "samples": [{"t": 0.0, "d": 0.0, "front": 0.0, "p": 300.0, "lane": 1.0}, {"t": 10.0, "d": 495.0, "front": 500.0, "p": 300.0, "lane": 1.0}, {"t": 20.0, "d": 995.0, "front": 1000.0, "p": 300.0, "lane": 1.0}, {"t": 20.1, "d": 1000.0, "front": 1005.0, "p": 300.0, "lane": 1.0}]}
	var converted := Records.first_wheel_record(old)
	check(Records.valid(converted) and converted["time_s"] == 20.0 and converted["samples"][-1]["d"] == 1000.0, "Old replay reconstructs first wheel timing")
	check(old["time_s"] == 20.1 and old["samples"][-1]["front"] == 1005.0, "Original old record preserved")
	print("TEAM_FIRST_WHEEL_OK" if failures == 0 else "TEAM_FIRST_WHEEL_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
