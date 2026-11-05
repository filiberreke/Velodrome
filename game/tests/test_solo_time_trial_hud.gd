extends SceneTree
const HUD := preload("res://race_hud.gd")
const Records := preload("res://time_trial_records.gd")
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _take_finish_photo(_winner: int) -> void: pass
class History extends "res://time_trial_records.gd":
	var rides: Array = []
	func all_rides() -> Array: return rides
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var history := History.new()
	var now := 20000000.0
	history.rides = [
		{"distance_m": 500, "seconds": 30.0, "finished_at": now - Records.WINDOW_SECONDS - 1},
		{"distance_m": 500, "seconds": 31.0, "finished_at": now - Records.WINDOW_SECONDS},
		{"distance_m": 500, "seconds": 33.0, "finished_at": now - 1},
		{"distance_m": 1000, "seconds": 10.0, "finished_at": now},
		{"distance_m": 500, "seconds": 1.0, "finished_at": now + 1}]
	var references := history.references(500, now)
	check(references.last.seconds == 33.0 and references.recent.seconds == 31.0 and references.alltime.seconds == 30.0, "References filter distance, future dates and the inclusive 60-day boundary")
	check(history.references(1000, now).last.seconds == 10.0, "1000 m history stays separate")
	for distance in [500, 1000]:
		var model := Model.new()
		root.add_child(model)
		model.race_mode = 7
		model.race_laps = distance / 250
		model._configure_peloton()
		model._prepare_pursuit({}, 0.0)
		model.watts = 400.0
		model.running = true
		model.start_state = "RACING"
		while not model._all_riders_finished() and model.clock < 300.0:
			model.clock += 0.05
			model._update_race(0.05)
		check(model._all_riders_finished() and model.pursuit_half_crossings[0].size() == distance / 125, "Full solo simulation records every checkpoint at %d m" % distance)
		check(is_equal_approx(float(model.pursuit_half_crossings[0][-1]), model.finish_times[0]), "Final checkpoint equals interpolated finish")
		model.free()
	check(HUD.estimated_finish(20.0, 250.0, 36.0) == 45.0, "Estimate includes elapsed and remaining distance at current speed")
	for speed in [0.0, -1.0, 0.9, NAN, INF]:
		check(HUD.estimated_finish(20.0, 250.0, speed) == null, "Stopped, slow and invalid speed hides estimate")
	check(HUD.estimated_finish(45.0, 0.0, 0.0) == 45.0, "Finish keeps exact elapsed even at zero speed")
	check(HUD.solo_clock(59.999) == "00:59.999" and HUD.solo_clock(60.0) == "01:00.000", "Millisecond clock rolls over correctly")
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var ui = game.race_overlay
	for distance in [500, 1000]:
		game._reset()
		game.setup_panel.select_mode(7)
		game.setup_panel.time_trial_distance.select(0 if distance == 500 else 1)
		game.setup_panel.time_trial_reference.select(3)
		game._confirm_start()
		game.broadcast_intro.finish()
		game.start_state = "RACING"
		game.running = true
		check(game.race_mode == 7 and game.rider_count == 1, "Solo starts with one rider at %d m" % distance)
		check(game._race_length() == distance, "Selected distance reaches game")
		game.clock = 20.0
		game.distances[0] = 250.0
		game.speeds[0] = 10.0
		game.pursuit_half_crossings[0] = [11.0, 20.0]
		game._update_hud()
		check(ui.solo_panel.visible and not ui.nearby_panel.visible, "Checkpoints replace surrounding riders")
		check(ui.lap_label.get_parent().visible and not ui.position_label.get_parent().visible and not ui.scratch_center.visible and not ui.pursuit_center.visible, "Lap stays in map; bottom hides position and race leadership")
		check(ui.solo_bottom.visible and ui.solo_elapsed_label.text == "00:20.0", "Bottom shows elapsed time")
		check(ui.solo_estimate_label.text == ("00:45" if distance == 500 else "01:35"), "Estimate uses actual race progress rather than shifted track position")
		check(not ui.slipstream_heading.visible and not ui.slipstream_bar.visible, "Solo has no drafting HUD")
		check(ui.solo_rows[0].elapsed.text == "9.000" and ui.solo_rows[1].elapsed.text == "11.000", "Latest 125 m duration appears first, with three decimals")
		check(ui.solo_rows[0].distance.text == "250 m" and ui.solo_rows[1].distance.text == "125 m", "Newest distance is at the top")
		check(ui.solo_rows[distance / 125 - 1].row.visible, "Final checkpoint visible")
		if distance == 500: check(not ui.solo_rows[4].row.visible, "500 m has four checkpoints")
		for row in ui.solo_rows: check(row.delta.text.is_empty(), "No comparison omits deltas")
		for kind in ["last", "recent", "alltime"]:
			game.time_trial_reference_kind = kind
			game.time_trial_reference = {"splits": [12.2, 19.6]}
			game._update_hud()
			check(ui.solo_rows[1].delta.text == "-1.200 s" and ui.solo_rows[1].delta.get_theme_color("font_color") == Color("27734a"), "Faster is negative and green for " + kind)
			check(ui.solo_rows[0].delta.text == "+1.600 s" and ui.solo_rows[0].delta.get_theme_color("font_color") == Color("af3843"), "Slower is positive and red for " + kind)
		game.time_trial_reference = {}
		game.speeds[0] = 0.0
		game._update_hud()
		check(ui.solo_estimate_label.text == "—" and ui.solo_rows[0].delta.text.is_empty(), "Unavailable comparison and stopped estimate clear old values")
		game.finish_times[0] = 45.123
		game.distances[0] = distance + 1.0
		game.clock = 60.0
		game._update_hud()
		check(ui.solo_elapsed_label.text == "00:45.1" and ui.solo_estimate_label.text == "00:45", "Finish uses tenths for elapsed and whole seconds for estimate")
	game._reset()
	game.setup_panel.select_mode(1)
	game.setup_panel.pursuit_flow.next_step()
	game._confirm_start()
	game.broadcast_intro.finish()
	game.pursuit_half_crossings = [[11.0, 20.0], [12.0, 22.0]]
	game.pursuit_half_stats = [[{}, {}], [{}, {}]]
	game._update_hud()
	check(game.race_mode == 4 and ui.team_laps_panel.visible and not ui.nearby_panel.visible, "Individual pursuit shows its split history")
	check(ui.team_lap_rows[0]["distance"].text == "250 m" and ui.team_lap_rows[0]["value"].text == "9.00 s (+2.00 s)", "Individual pursuit shows latest segment and matching opponent gap first")
	game._reset()
	game.setup_panel.select_mode(0)
	game._confirm_start()
	game.broadcast_intro.finish()
	game._update_hud()
	check(not ui.solo_panel.visible and not ui.solo_bottom.visible and ui.nearby_panel.visible and ui.scratch_center.visible and ui.position_label.get_parent().visible and ui.lap_label.get_parent().visible, "Returning to scratch restores normal HUD")
	game.free()
	await process_frame
	print("SOLO HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
