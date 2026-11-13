extends SceneTree

class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _save_recording(_reason: String) -> void: pass

class UploadCapture extends Node:
	var received: Array = []
	func begin_export(path: String, title: String, description: String) -> void:
		received = [path, title, description]

class Transport extends "res://strava_client.gd":
	var requests: Array = []
	func _ready() -> void: pass
	func _config_value(_name: String) -> String: return "fixture"
	func _save_tokens(_data: Dictionary) -> void: pass
	func _http(method: int, url: String, headers: PackedStringArray, payload: PackedByteArray) -> Dictionary:
		requests.append({"method": method, "url": url, "headers": headers, "payload": payload})
		if url == TOKEN_URL:
			return {"ok": true, "data": {"access_token": "fixture"}}
		return {"ok": false, "code": 400, "message": "Offline fixture stops after capturing upload"}

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func complete(game) -> void:
	for i in range(game.rider_count): game.finish_times[i] = 100.0 + i
func run_test() -> void:
	var game := Game.new()
	root.add_child(game)
	game.race_laps = 10
	for pair in [[0,"Scratch"],[1,"Puntenkoers"],[2,"Afvalling"],[4,"Achtervolging"],[5,"Ploegenachtervolging"],[7,"Tijdrit"]]:
		game.race_mode = pair[0]
		check(game._strava_activity_title() == "Velodrome - " + pair[1], "Title follows actual race mode: " + pair[1])
	game.ai_difficulty = 85; game.keirin_percent = 70; game.pursuit_opponent_percent = 95
	for mode in [0, 1, 2, 3, 4, 5, 7]:
		game.race_mode = mode; game._configure_peloton()
		var level: int = 70 if mode == 3 else (95 if mode in [4, 5] else 85)
		check(game._strava_activity_description().begins_with("Niveau: %d%%\n" % level), "Correct level in every race mode: %d" % mode)
	game.race_laps = 10
	game.race_mode = 0; game.rider_count = 12; game._configure_peloton(); complete(game)
	game.scratch_rules.credits[1] = 1
	check(game._strava_result_description() == "Uitslag: 2/12", "Scratch uses credited laps, not raw finish time")
	game.finish_times[11] = -1.0
	check(game._strava_result_description() == "Uitslag nog niet definitief.", "Pending classification is not published as a final result")
	game.race_mode = 1; game.rider_count = 16; game._configure_peloton(); complete(game)
	game.points_rules.points[0] = 12; game.points_rules.points[1] = 20; game.points_rules.points[2] = 15
	check(game._strava_result_description() == "Uitslag: 3/16, 12 punten", "Points uses official rank, field size and score")
	game.points_rules.points.fill(-3); game.points_rules.points[0] = -2
	check(game._strava_result_description() == "Uitslag: 1/16, -2 punten", "Negative points are preserved")
	game.race_mode = 2; game.rider_count = 4; game._configure_peloton(); complete(game)
	game.elimination_rules.eliminated.assign([2,0])
	game.finish_times.assign([60.0,89.0,50.0,90.0])
	check(game._strava_result_description() == "Uitslag: 3/4", "Elimination uses original field and elimination order")
	game.race_mode = 4; game._configure_peloton(); complete(game)
	game.finish_times[1] = 99.0
	check(game._strava_result_description() == "Uitslag: 2/2", "Pursuit uses both competitors")
	game.race_mode = 5; game.team_size = 3; game._configure_peloton(); complete(game)
	game.team_race.times.assign([72.0,70.0])
	check(game._strava_result_description() == "Uitslag: 2/2", "Team pursuit counts teams instead of six individual riders")
	game.race_mode = 7; game.race_laps = 2; game._configure_peloton()
	game.lap_times[0] = [20.123,15.456]; game.finish_times[0] = 35.579
	check(game._strava_result_description() == "Tijd: 35.579 s\nRondetijden (250 m):\nRonde 1: 20.123 s\nRonde 2: 15.456 s", "500 m exports own individual full laps with millisecond precision")
	game.race_laps = 4; game.lap_times[0] = [20.0,15.0,16.0,17.0]; game.finish_times[0] = 68.0
	check(game._strava_activity_description().ends_with("Ronde 4: 17.000 s"), "1000 m exports all four laps")
	game.finish_times[0] = -1.0; game.lap_times[0] = [20.0]
	check(game._strava_result_description() == "Tijdrit nog niet voltooid.\nRondetijden (250 m):\nRonde 1: 20.000 s", "Incomplete time trial never invents unfinished laps")
	game.finish_times[0] = 35.0; game.lap_times[0] = [20.0,15.0]
	game.ride_records.assign([{"time_s":0.0,"distance_m":0.0,"game_speed_kmh":0.0,"power_w":250.0,"cadence_rpm":80.0},{"time_s":35.0,"distance_m":500.0,"game_speed_kmh":50.0,"power_w":250.0,"cadence_rpm":80.0}])
	var capture := UploadCapture.new(); game.add_child(capture); game.strava_client = capture
	game.strava_desired_title = "Velodrome - Scratch"
	game._export_to_strava()
	var dialog: Window
	for child in game.get_children():
		if child is Window: dialog = child
	check(dialog != null, "Export dialog opens")
	var input: LineEdit = dialog.find_children("*", "LineEdit", true, false)[0]
	check(input.text == "Velodrome - Tijdrit", "Previous discipline title does not leak into new race")
	var preview: RichTextLabel = dialog.find_children("*", "RichTextLabel", true, false)[0]
	check(preview.text == game._strava_activity_description(), "Dialog previews the actual upload description")
	input.text = "   "
	for button in dialog.find_children("*", "Button", true, false):
		if button.text == "Upload rit": button.pressed.emit()
	check(capture.received.size() == 3, "Upload passes FIT path, title and description to client")
	if capture.received.size() == 3:
		check(capture.received[1] == "Velodrome - Tijdrit" and capture.received[2] == preview.text, "Blank title falls back to current mode and description survives upload path")
		var client := Transport.new(); root.add_child(client)
		client.begin_export(capture.received[0], capture.received[1], capture.received[2])
		check(client.requests.size() == 2, "Offline transport covers token refresh and upload without network")
		if client.requests.size() == 2:
			var body: String = client.requests[1].payload.get_string_from_utf8()
			check('name="name"\r\n\r\nVelodrome - Tijdrit\r\n' in body, "Actual multipart sends requested title")
			check('name="description"\r\n\r\n' + capture.received[2] + '\r\n' in body, "Actual multipart sends multiline lap description")
			check('name="sport_type"\r\n\r\nVirtualRide\r\n' in body, "VirtualRide activity type is retained")
		client.free()
	game.free()
	await process_frame
	print("STRAVA_METADATA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
