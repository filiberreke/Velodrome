extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class FTP extends "res://ftp_training.gd":
	var clock := 100.
	func now_s() -> float: return clock
class Workout extends "res://workout_training.gd":
	var clock := 100.
	func now_s() -> float: return clock
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	await process_frame
	for mode in [0,1,2,3,4,5,7]:
		game.race_mode = mode; game.race_laps = 20; game.rider_count = 6
		game._configure_peloton()
		if mode == 5: game.team_race.prepare(game,{},250.)
		for value in [88.6,0.,-1.,NAN]:
			game.connected = true; game.cadence = value
			game._update_compact_hud(game._physical_order(game._race_positions()))
			var expected := "89 rpm" if value == 88.6 else "0 rpm" if value == 0. else "— rpm"
			check(game.race_overlay.cadence_label.text == expected,"Cadence in race mode %d" % mode)
		game.connected = false; game.cadence = 90.
		game._update_compact_hud(game._physical_order(game._race_positions()))
		check(game.race_overlay.cadence_label.text == "— rpm","Disconnected race cadence is missing")
	game.free()
	for script in [FTP,Workout]:
		var page = script.new(); root.add_child(page); page.set_process(false)
		if page is Workout:
			page.load_workout({"id":"cadence","name":"Cadence","blocks":[{"kind":"SteadyState","duration":600,"power_low":.7,"power_high":.7,"events":[]}]})
		page.test.start(100.)
		var sample := 0
		for value in [88.6,0.,null,-1.,INF]:
			sample += 1
			page.receive({"type":"telemetry","valid":true,"power_w":180.,"speed_kmh":25.,"cadence_rpm":value,"power_sample_id":sample,"power_age_s":0.},100.)
			page._refresh()
			var expected := "89 rpm" if value == 88.6 else "0 rpm" if value == 0. else "— rpm"
			check(page.result.text.contains("Cadans · " + expected),"FTP/workout displays valid, zero or missing cadence")
		page.clock = 112.; page._refresh()
		check(page.cadence_text() == "— rpm","Stale training cadence is missing")
		page.free()
	print("V02_CADENCE failures=",failures)
	quit(0 if failures == 0 else 1)
