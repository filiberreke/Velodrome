extends SceneTree
const Records := preload("res://pursuit_records.gd")
const Pacer := preload("res://pursuit_pacer.gd")
class Model extends "res://main.gd":
	func _ready() -> void:
		set_physics_process(false)
	func _spawn_peloton() -> void:
		pass
	func _take_finish_photo(_winner: int) -> void:
		pass
	func _save_recording(_reason: String) -> void:
		pass
	func _capture_demo_fit_sample() -> void:
		pass

class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _take_finish_photo(_winner: int) -> void:
		pass

var failures := 0
var directory: String
var metrics: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	directory = "res://tests/tmp_pursuit_" + str(Time.get_ticks_usec())
	call_deferred("run_test")

func ride(distance: int, replay: Dictionary = {}, dt: float = 0.05) -> Dictionary:
	var game = Model.new()
	root.add_child(game)
	game.race_mode = 4
	game.race_laps = distance / 250
	game._configure_peloton()
	game._prepare_pursuit(replay, 250.0)
	game.watts = 340.0 if replay.is_empty() else 500.0
	game.running = true
	game.start_state = "RACING"
	check(game.rider_count == 2, "Exactly two pursuit starters")
	var a: Vector3 = game._at(game._rider_distance(0, 0.0), game.LANES[0])
	var b: Vector3 = game._at(game._rider_distance(1, 0.0), game.LANES[0])
	check(absf(a.x + b.x) < 0.001 and absf(a.z + b.z) < 0.001, "Start lines exactly opposite")
	check(absf(a.z) < 0.001 and absf(a.x) > 18.0, "Player starts at the existing straight-centre pursuit marking")
	check(game._at(game._rider_distance(0, distance), game.LANES[0]).distance_to(a) < 0.001, "Player finishes at own start line")
	check(game._at(game._rider_distance(1, distance), game.LANES[0]).distance_to(b) < 0.001, "Opponent finishes at opposite own start line")
	game.draft_strengths.fill(1.0)
	check(game._draft_target(0) == 0.0 and game._draft_drag_reduction(0) == 0.0 and game._effective_draft_strength(1) == 0.0, "No draft for either pursuit rider")
	check(is_equal_approx(game._next_speed(12.0, 300.0, 0.1, 0.0), game._next_speed(12.0, 300.0, 0.1, 1.0)), "Pursuit force balance ignores even supplied drafting")
	var constant: float = game.pursuit_pacer.target_w
	var varied := false
	var lane_error := false
	while not game._all_riders_finished() and game.clock < 2000.0:
		if game.clock > 25.0 and game.clock < 40.0:
			game.player_lane = 1
		else:
			game.player_lane = 0
		game.ai_lane_targets[1] = game.LANES[-1] # Tactics must not pull AI outwards.
		var opponent_active: bool = game.finish_times[1] < 0.0
		game.clock += dt
		game._update_race(dt)
		if not is_equal_approx(game.lane_offsets[1], game.LANES[0]):
			lane_error = true
		if replay.is_empty() and opponent_active and absf(game.ai_power_w[1] - constant) > 0.01:
			varied = true
	check(game._all_riders_finished(), "Both riders complete %d m" % distance)
	check(not varied, "AI power stays constant for the entire distance")
	check(not lane_error, "Opponent stays on the lowest line for the entire race")
	check(game.lap_times[0].size() == distance / 250 and game.lap_times[1].size() == distance / 250, "Each rider has own complete lap timing")
	for rider in range(2):
		check(game.pursuit_half_stats[rider].size() == distance / 125, "Every segment has average speed and power")
		for half in range(distance / 125):
			var prior: float = float(game.pursuit_half_crossings[rider][half - 1]) if half > 0 else 0.0
			var duration: float = float(game.pursuit_half_crossings[rider][half]) - prior
			var stats: Dictionary = game.pursuit_half_stats[rider][half]
			check(absf(float(stats["kmh"]) * duration / 3.6 - 125.0) < 0.0001, "Average speed matches segment distance and duration")
			if rider == 0:
				check(absf(float(stats["watts"]) - game.watts) < 0.0001, "Player constant power average exact across partial steps")
			elif replay.is_empty():
				check(absf(float(stats["watts"]) - constant) < 0.0001, "AI constant power average exact")
			else:
				check(float(stats["watts"]) >= 0.0 and float(stats["watts"]) <= 340.001, "Saved ride wattage derived from saved samples")
		check(game.pursuit_half_crossings[rider].size() == distance / 125, "Every half lap timed for both AI and replay")
		check(absf(float(game.pursuit_half_crossings[rider][-1]) - game.finish_times[rider]) < 0.00001, "Half lap finish crossing matches actual finish")
		var prior := 0.0
		for crossing in game.pursuit_half_crossings[rider]:
			check(float(crossing) > prior, "Half lap times strictly increase")
			prior = float(crossing)
	if not replay.is_empty():
		for half in range(distance / 125):
			check(absf(float(game.pursuit_half_crossings[1][half]) - Records.time_at_distance(replay, (half + 1) * 125.0)) < 0.000001, "Replay half lap interpolates saved distance accurately")
	check(game.pursuit_pacer.reserve_j >= 0.0, "AI never spends unavailable reserve")
	var data := {"version": Records.VERSION, "physics": Records.PHYSICS, "name": "Testpoging", "time_s": game.finish_times[0], "distance_m": distance, "samples": game.pursuit_trace.duplicate(true)}
	check(Records.valid(data), "Complete player attempt has valid replay samples")
	if not replay.is_empty():
		check(absf(game.finish_times[1] - float(replay["time_s"])) < 0.000001, "Replay finish time exactly matches saved attempt with a different timestep")
		for lap in range(game.race_laps):
			check(absf(game.last_lap_crossing[1] - float(replay["time_s"])) < 0.000001, "Replay final lap crossing is exact")
	metrics.append({"distance_m": distance, "opponent": "AI" if replay.is_empty() else "saved ride", "cp_w": 250.0, "constant_w": constant if replay.is_empty() else 0.0, "player_s": game.finish_times[0], "opponent_s": game.finish_times[1], "predicted_s": game.pursuit_pacer.predicted_seconds, "reserve_j": game.pursuit_pacer.reserve_j, "dt": dt})
	game.free()
	return data

func run_test() -> void:
	var split_model = Model.new()
	split_model.race_mode = 4
	split_model.race_laps = 4
	split_model.clock = 1.0
	split_model._register_pursuit_half_crossings(0, 0.0, 0.0, 1.0, 100.0)
	split_model.clock = 3.0
	split_model._register_pursuit_half_crossings(0, 0.0, 250.0, 2.0, 300.0)
	check(absf(float(split_model.pursuit_half_stats[0][0]["watts"]) - 200.0) < 0.00001, "First segment average includes stationary time and changing power")
	check(absf(float(split_model.pursuit_half_stats[0][1]["watts"]) - 300.0) < 0.00001, "Two crossings within one step split energy correctly")
	split_model.pursuit_replay = {"samples": [{"t": 0.0, "p": 100.0}, {"t": 10.0, "p": 300.0}]}
	check(absf(split_model._pursuit_replay_energy(2.0, 4.0) - 320.0) < 0.00001, "Saved varying power integrated over partial sample intervals")
	split_model.free()
	var library = Records.new()
	library.directory = directory.path_join("records")
	var one: Dictionary = ride(1000)
	var four: Dictionary = ride(4000)
	check(metrics[0]["constant_w"] > metrics[1]["constant_w"] and metrics[1]["constant_w"] > 250.0, "Constant power is highest for the shorter distance, both above CP using finite reserve")
	var model = Model.new()
	model.race_mode = 4
	var stronger = Pacer.new()
	stronger.prepare(model, 1000.0, 300.0, model._rider_distance(1, 0.0), model.LANES[0])
	check(stronger.target_w > float(metrics[0]["constant_w"]), "Higher chosen CP gives a stronger constant opponent")
	model.free()
	var saved: Dictionary = library.save("Eerste 1 km", 1000, one["time_s"], one["samples"])
	check(not saved.has("error"), "Completed attempt can be named and saved")
	if saved.has("error"):
		quit(1)
		return
	var restarted = Records.new()
	restarted.directory = library.directory
	var loaded: Dictionary = restarted.load_ride(saved["id"])
	check(not loaded.is_empty() and loaded["name"] == "Eerste 1 km", "Ride persists across library restart")
	check(restarted.list_rides(1000).size() == 1 and restarted.list_rides(4000).is_empty(), "Replay menu filters distances")
	check(library.save(" ", 1000, one["time_s"], one["samples"]).has("error"), "Name required")
	var incomplete: Array[Dictionary] = one["samples"].duplicate(true)
	incomplete.pop_back()
	check(library.save("Onvolledig", 1000, one["time_s"], incomplete).has("error"), "Incomplete rides cannot be saved")
	check(restarted.load_ride("../anything").is_empty(), "Ride IDs cannot address arbitrary paths")
	var bad: Dictionary = loaded.duplicate(true)
	bad["samples"][1]["t"] = -1.0
	check(not Records.valid(bad), "Broken sample sequence rejected")
	var now: Dictionary = Records.at_time(loaded, float(loaded["time_s"]) * 0.5)
	check(now["d"] > 0.0 and now["d"] < 1000.0, "Replay interpolates race progress by time")
	check(is_equal_approx(Records.time_at_distance(loaded, 1000.0), loaded["time_s"]), "Distance-to-time replay inversion")
	ride(1000, loaded, 0.073)
	var saved_four: Dictionary = library.save("Eerste 4 km", 4000, four["time_s"], four["samples"])
	check(not saved_four.has("error"), "4 km attempt can be saved independently")
	var loaded_four: Dictionary = restarted.load_ride(saved_four.get("id", ""))
	check(not loaded_four.is_empty() and restarted.list_rides(4000).size() == 1, "4 km library reload and distance selection")
	if not loaded_four.is_empty():
		ride(4000, loaded_four, 0.11)
	# Real menu, start wiring, result save controls and persistence selection.
	var screen = Screen.new()
	screen.pursuit_library.directory = directory.path_join("screen")
	root.add_child(screen)
	screen.set_physics_process(false)
	await process_frame
	await process_frame
	var menu = screen.setup_panel
	menu.select_mode(1)
	menu.pursuit_flow.next_step()
	var options = menu.pursuit_options
	check(options.distance_m() == 1000 and options.cp_input.value == 265.0 and not menu.start_button.disabled, "Pursuit defaults: 1 km, selected sample rider, CP 265 W")
	options.opponent_choice.select(1)
	options.refresh_state()
	check(menu.start_button.disabled, "Missing saved ride disables replay start")
	options.distance_choice.select(1)
	options.refresh_rides()
	check(options.distance_m() == 4000, "4 km is available")
	options.opponent_choice.select(0)
	options.distance_choice.select(0)
	options.refresh_rides()
	await process_frame
	await process_frame
	check(menu.start_button.get_global_rect().end.y <= 1080.1, "Pursuit configuration fits reference screen")
	screen._confirm_start(); screen.broadcast_intro.finish()
	check(screen.race_mode == 4 and screen.rider_count == 2 and screen.race_laps == 4 and screen.start_state == "WAIT_STOP", "Pursuit uses existing standing-start/countdown flow")
	screen._update_hud()
	check(not screen.race_overlay.slipstream_bar.visible and screen.minimap.start_lines.size() == 2, "Pursuit hides slipstream and marks both start lines")
	check(absf(screen.minimap.progress[1] - screen.minimap.progress[0] - 125.0) < 0.0001, "Minimap shows true opposite positions, not progress tied at zero")
	for frame in range(65):
		screen._physics_process(0.1)
	check(screen.start_state == "RACING" and screen.clock > 0.0 and screen.distances[0] > 0.0 and screen.distances[1] > 0.0, "Actual countdown launches both riders from a standing start")
	screen.pursuit_trace.assign(one["samples"])
	screen.finish_times[0] = one["time_s"]
	screen.distances[0] = 1000.0
	screen._refresh_fullscreen_results()
	check(screen.pursuit_save_box.visible, "Finish results offer named save")
	screen.pursuit_save_name.text = "Mijn opgeslagen rit"
	screen._save_pursuit_ride()
	check(not screen.pursuit_saved_id.is_empty() and screen.pursuit_save_button.disabled, "Save button persists a named ride and prevents duplicate click")
	screen._reset()
	menu.select_mode(1)
	menu.pursuit_flow.next_step()
	options.opponent_choice.select(1)
	options.refresh_state()
	check(not menu.start_button.disabled and options.rides.size() == 1, "Saved attempt becomes selectable opponent")
	screen._confirm_start(); screen.broadcast_intro.finish()
	check(screen.pursuit_replay.get("name", "") == "Mijn opgeslagen rit", "Start loads the selected attempt")
	screen._reset()
	menu.select_mode(0)
	check(menu.count_input.value == 8, "Pursuit reset preserves separate Scratch participant settings")
	menu.count_input.value = 8
	screen._confirm_start(); screen.broadcast_intro.finish()
	screen._update_hud()
	check(screen.race_mode == 0 and screen.rider_count == 8 and screen.race_overlay.slipstream_bar.visible and screen.minimap.start_lines.size() == 1, "Switching back restores Scratch configuration and HUD")
	screen.free()
	var file := FileAccess.open("res://tests/pursuit_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	file.close()
	print("PURSUIT_OK" if failures == 0 else "PURSUIT_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
