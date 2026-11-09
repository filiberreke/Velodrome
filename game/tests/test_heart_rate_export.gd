extends SceneTree
const Fit := preload("res://fit_export.gd")
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
class UploadSpy extends Node:
	var payload := PackedByteArray()
	func begin_export(path: String, _title: String, _description: String = "") -> void:
		payload = FileAccess.get_file_as_bytes(path)
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func decode_records(bytes: PackedByteArray) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
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
			if definition["global"] == 20: records.append(values)
	check(position == end, "FIT message sizes match header data size")
	check(Fit._crc(bytes) == 0, "FIT CRC intact")
	return records

func run_test() -> void:
	for unavailable in [null, false, true, 0, -1, 255, 300, 143.5, "143", INF, NAN]:
		check(Fit.heart_rate_value(unavailable) == 255, "Unavailable and malformed HR use FIT invalid sentinel")
	for value in [1, 143, 254, 143.0]: check(Fit.heart_rate_value(value) == int(value), "Integral valid HR encoded unchanged")
	var samples: Array[Dictionary] = []
	var expected := [143, 144, 255, 255, 255, 200]
	for i in range(6):
		var sample := {"time_s": float(i), "distance_m": float(i) * 10.0, "power_w": 181, "game_speed_kmh": 36.0, "cadence_rpm": 91}
		if i != 2: sample["heart_rate_bpm"] = [143, 144, null, null, 300, 200][i]
		samples.append(sample)
	for gps in [false, true]:
		var records := decode_records(Fit.build(samples, 1700000000, gps))
		check(records.size() == expected.size(), "GPS and indoor FIT retain every second")
		for i in range(records.size()):
			check(records[i][3] == expected[i], "Standard FIT record heart-rate field round trips")
			check(records[i][7] == 181 and records[i][4] == 91 and records[i][6] == 10000 and records[i][5] == i * 1000, "Existing power, cadence, speed and distance unchanged")
	var game := Model.new(); root.add_child(game)
	game.trainer_seen = true; game.start_state = "RACING"; game.recording_active = true
	game.ride_start_unix = 1700000000
	game.clock = 0.0
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 170, "cadence_rpm": 87, "sample_id": 1, "heart_rate_bpm": 143})
	check(game.ride_records[0]["heart_rate_bpm"] == 143, "Live bridge HR stored with player sample")
	game.clock = 0.5
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 170, "cadence_rpm": 87, "sample_id": 1, "heart_rate_bpm": 144})
	check(game.ride_records.size() == 1 and game.ride_records[0]["heart_rate_bpm"] == 143, "HR update does not duplicate or backdate FTMS samples")
	game.clock = 1.0
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 175, "cadence_rpm": 88, "sample_id": 2, "heart_rate_bpm": 144})
	game.clock = 2.0
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 180, "cadence_rpm": 89, "sample_id": 3, "heart_rate_bpm": null})
	check(game.ride_records[-1]["heart_rate_bpm"] == null, "Expired HR not carried forward")
	var spy := UploadSpy.new(); game.add_child(spy); game.strava_client = spy
	game._start_strava_upload()
	var uploaded := decode_records(spy.payload)
	check(uploaded.size() == 3 and uploaded[0][3] == 143 and uploaded[1][3] == 144 and uploaded[2][3] == 255, "Actual Strava upload FIT carries player's HR and missing value")
	game._save_recording("hr_export_test")
	var folder := DirAccess.open(game.recording_folder)
	var csv_path := ""
	for filename in folder.get_files():
		if filename.ends_with(".csv") and "hr_export_test" in filename: csv_path = game.recording_folder.path_join(filename)
	var csv := FileAccess.open(csv_path, FileAccess.READ)
	check(csv.get_csv_line()[-1] == "heart_rate_bpm", "CSV header includes HR")
	check(csv.get_csv_line()[-1] == "143" and csv.get_csv_line()[-1] == "144" and csv.get_csv_line()[-1] == "", "CSV preserves HR and blank missing value")
	csv.close()
	game._export_strava_tcx()
	var tcx := FileAccess.get_file_as_string(game.strava_export_path)
	check(tcx.count("<HeartRateBpm>") == 2 and "<Value>143</Value>" in tcx and "<Value>144</Value>" in tcx, "Legacy TCX also includes available player HR")
	DirAccess.remove_absolute(csv_path)
	DirAccess.remove_absolute(game.strava_export_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://strava_upload_temp.fit"))
	game.free()
	print("HEART_RATE_EXPORT_OK" if failures == 0 else "HEART_RATE_EXPORT_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
