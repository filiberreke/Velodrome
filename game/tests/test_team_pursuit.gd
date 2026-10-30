extends SceneTree
const Train := preload("res://team_pursuit.gd")
const Records := preload("res://pursuit_records.gd")
const Game := preload("res://main.gd")
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _take_team_finish_photo(_front: float, _offsets: Array[float], _lanes: Array[float], _seconds: float) -> void: pass
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _take_finish_photo(_winner: int) -> void: pass
	func _take_team_finish_photo(_front: float, _offsets: Array[float], _lanes: Array[float], _seconds: float) -> void: pass
var failures := 0
var metrics: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func controller_test(count: int) -> void:
	var train = Train.new(); train.reset(count)
	check(train.target_watts() == -1.0, "No invented target before first completed player pull")
	check(train.order[0] == 0 and is_equal_approx(train.offsets[-1], -2.5 * (count - 1)), "Player starts first, all teammates single file")
	check(is_equal_approx(train.factor(1), 0.8) and is_equal_approx(train.factor(count - 1), 0.5 if count == 3 else 0.4), "Requested follower factors")
	if count == 4: check(is_equal_approx(train.factor(2), 0.6), "Four-rider middle factor 60 percent")
	for i in range(100): train.step(0.1, 200.0 if i < 50 else 400.0, 300.0)
	check(train.request_exchange() and not train.request_exchange(), "One right input starts an exchange, duplicate ignored")
	check(absf(train.copied_watts - 300.0) < 0.00001 and absf(train.copied_seconds - 10.0) < 0.00001, "Next AI inherits time-weighted average and player pull duration")
	check(absf(train.reference_power - 300.0) < 0.00001, "Only completed player pull establishes reference")
	var elapsed := 0.0
	var saw_out := false; var saw_drop := false; var saw_in := false
	while train.player_is_out() and elapsed < 30.0:
		var power: float = train.step(0.05, 0.0, 300.0)
		check(absf(power - 300.0) < 0.0001, "Coasting during exchange cannot slow train")
		saw_out = saw_out or train.phase == "OUT"
		saw_drop = saw_drop or train.phase == "DROP"
		saw_in = saw_in or train.phase == "IN"
		elapsed += 0.05
	check(not train.player_is_out() and saw_out and saw_drop and saw_in, "Complete automatic outward-drop-inward motion")
	check(train.player_rank() == count - 1 and is_zero_approx(train.lanes[0]), "Rejoin at last position on lowest line")
	check(absf(train.step(0.01, 150.0 if count == 3 else 120.0, 300.0) - 300.0) < 0.0001, "Following watts map back to leader watts")
	var stable: float = 150.0 if count == 3 else 120.0
	for varying_hold in [25.0, 900.0, 100.0]:
		train.step(0.01, 150.0, varying_hold)
		check(absf(train.required_watts - stable) < 0.0001 and absf(train.reference_power - 300.0) < 0.00001, "Changing speed resistance or actual AI power never changes target reference")
	check(is_zero_approx(train.step(0.01, 0.0, 300.0)), "After rejoin no pedalling removes team drive")
	var remaining: float = train.copied_seconds - train.turn_seconds
	train.step(maxf(0.0001, remaining - 0.001), 200.0, 300.0)
	check(train.rotation == -1, "AI does not finish copied pull early")
	train.step(0.01, 200.0, 300.0)
	check(train.rotation == 1 and train.order[0] == 2, "AI automatically rotates after copied pull duration")
	for i in range(1000):
		if train.order[0] == 0 and train.rotation < 0: break
		train.step(0.05, 125.0, 999.0)
		check(absf(train.reference_power - 300.0) < 0.00001, "AI pulls cannot update last player reference")
	check(train.order[0] == 0 and train.rotation < 0, "Player returns to head")
	train.step(0.1, 125.0, 10.0)
	check(absf(train.target_watts() - 300.0) < 0.00001, "Previous pull target stays fixed even during new player pull")
	train.request_exchange()
	check(absf(train.reference_power - 125.0) < 0.00001, "Only next completed player pull replaces reference")
	train.reset(count)
	check(train.rotation == -1 and train.order[0] == 0 and train.exchanges == 0, "Fresh race resets relay state")

func ride(count: int, distance: int, previous: Dictionary = {}, dt: float = 0.05) -> Dictionary:
	var game = Model.new(); root.add_child(game)
	game.race_mode = 5; game.team_size = count; game.race_laps = distance / 250
	game._configure_peloton(); game._prepare_pursuit(previous, 250.0)
	game.team_race.prepare(game, previous, 250.0)
	game.start_state = "RACING"; game.running = true
	check(game.rider_count == count * 2, "Both teams have requested size")
	check(not game.team_race.request_player_exchange(), "Standing train cannot start a backwards coasting exchange")
	check(game.distances[0] == 0.0 and game.distances[count - 1] < 0.0, "Player starts at pursuit line, train behind")
	check(absf(game._rider_distance(count, 0.0) - game._rider_distance(0, 0.0) - 125.0) < 0.00001, "Opposing team starts 125 m opposite")
	var steps := 0
	while not game._all_riders_finished() and game.clock < 1200.0:
		var train = game.team_race.ours
		if train.order[0] == 0 and train.turn_seconds >= 12.0: train.request_exchange()
		game.watts = 0.0 if train.player_is_out() else (340.0 if train.order[0] == 0 else maxf(180.0, game.team_race.hold_power(game.team_race.velocity[0])) * train.factor(train.player_rank()))
		game.clock += dt; game._update_race(dt); steps += 1
		for i in range(game.rider_count):
			check(is_zero_approx(game._draft_drag_reduction(i)), "No double drafting or opponent wheel exploit")
	check(game._all_riders_finished() and game.finished, "Both teams finish")
	check(game.team_race.ours.exchanges >= count and game.team_race.theirs.exchanges > 0, "Multiple automatic relay cycles happen")
	check(game.lap_times[0].size() == distance / 250 and game.lap_times[1].size() == distance / 250, "Both team lap tables complete")
	check(game.pursuit_half_crossings[0].size() == distance / 125 and game.pursuit_half_crossings[1].size() == distance / 125, "Half-lap team timing complete")
	var data := {"version": Records.VERSION, "physics": Records.PHYSICS, "distance_m": distance, "time_s": game.team_race.times[0], "name": "Testploeg", "samples": game.pursuit_trace.duplicate(true)}
	check(Records.valid(data), "Complete team performance is recordable")
	if not previous.is_empty(): check(absf(game.team_race.times[1] - float(previous["time_s"])) < 0.000001, "Saved opponent team finish exact with changed timestep")
	metrics.append({"size": count, "distance": distance, "replay": not previous.is_empty(), "time": game.team_race.times[0], "opponent": game.team_race.times[1], "exchanges": game.team_race.ours.exchanges, "steps": steps})
	game.free(); return data

func run_test() -> void:
	controller_test(3); controller_test(4)
	for count in [3, 4]:
		for distance in [1000, 4000]:
			var record: Dictionary = ride(count, distance)
			var storage = Records.new(); storage.configure_team(count)
			storage.directory = "res://tests/tmp_team_%d_%d_%d" % [count, distance, Time.get_ticks_usec()]
			var saved: Dictionary = storage.save("Mijn ploeg", distance, record["time_s"], record["samples"])
			check(not saved.has("error"), "Team record saved with name")
			var loaded: Dictionary = storage.load_ride(saved.get("id", ""))
			check(not loaded.is_empty() and int(loaded.get("team_size", 0)) == count and loaded.get("event", "") == "team", "Team metadata round-trips")
			var wrong = Records.new(); wrong.configure_team(7 - count); wrong.directory = storage.directory
			check(wrong.load_ride(saved.get("id", "")).is_empty(), "Wrong squad size cannot load performance")
			var solo = Records.new(); solo.directory = storage.directory
			check(solo.load_ride(saved.get("id", "")).is_empty(), "Individual library cannot load team performance")
			if not loaded.is_empty(): ride(count, distance, loaded, 0.073)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(storage.directory.path_join(str(saved.get("id", "")) + ".json")))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(storage.directory))
	var game = Screen.new(); root.add_child(game); game.set_physics_process(false)
	await process_frame; await process_frame
	game.setup_panel.select_mode(2)
	var options = game.setup_panel.team_options
	check(options.team_size() == 3 and options.cp_input.value == 250.0, "Team menu defaults")
	options.teammates.select(1); options.teammates.item_selected.emit(1)
	check(options.team_size() == 4 and options.library.squad_size == 4, "Squad size selector configures matching saved records")
	await process_frame; await process_frame
	check(game.setup_panel.start_button.get_global_rect().end.y <= 1080.1, "Team menu navigation fits reference screen")
	game._confirm_start(); game.broadcast_intro.finish()
	check(game.race_mode == 5 and game.rider_count == 8 and game.start_state == "WAIT_STOP", "Team menu enters existing countdown flow")
	game.start_state = "RACING"; game.running = true
	game.watts = 340.0
	for i in range(200): game.clock += 0.05; game._update_race(0.05)
	game._update_hud()
	var ui = game.race_overlay
	check(ui.power_meter.role_label.visible and not ui.power_meter.role_label.text.is_empty() and ui.pursuit_names[0].text == "Jouw ploeg", "Target panel and two-team comparison visible")
	check(ui.power_meter.role_label.text.begins_with("EERSTE KOPBEURT"), "First player pull has no fluctuating target")
	game.team_race.ours.has_player_pull = true
	game.team_race.ours.reference_power = 300.0
	game._update_hud()
	check(not ui.power_meter.target_visible and ui.power_meter.target_label.text.is_empty(), "Player at head has no target")
	game.team_race.velocity[0] += 1.0
	game._update_hud()
	check(not ui.power_meter.target_visible, "Player at head stays without target as speed changes")
	for bike in game.bikes:
		for child in bike.get_children(): check(not child is Label3D, "No floating rider names in team mode")
	game._update_visuals(0.01)
	check(game.team_race.badges.size() == 2 and not game.team_race.badges[0].visible and game.team_race.badges[1].visible, "Only opponent AI head has badge while player leads")
	await process_frame; await process_frame
	check(ui.power_meter.get_global_rect().end.y < ui.status_panel.get_global_rect().position.y, "Target and connection/countdown notice do not overlap")
	game.watts = 0.0; game._update_hud()
	check(ui.power_meter.fill_color == Color.WHITE, "Player at head uses normal zero-watt colour")
	game.watts = 900.0; game._update_hud()
	check(ui.power_meter.fill_color == ui.power_meter.zone_color(900.0), "Player at head uses normal high-watt colour")
	var key := InputEventKey.new(); key.keycode = KEY_D; key.pressed = true
	game._unhandled_key_input(key); game._update_hud()
	check(game.team_race.ours.player_is_out() and ui.power_meter.role_label.text.begins_with("UITBOLLEN"), "Right steering triggers automatic manoeuvre and coasting indication")
	game.clock += 0.05; game._update_race(0.05); game._update_visuals(0.01)
	var badge = game.team_race.badges[0]
	check(badge.visible and badge.rider_id == 1 and badge.power_label.text == "340 W", "Power badge moves to new AI head and shows actual leader power")
	check(absf(badge.power_bar.value - game.team_race.ours.leader_power) < 0.0001, "Statusbar uses actual watts")
	var stopped_at: float = game.clock
	var exchange_at: float = game.team_race.ours.phase_seconds
	game.trainer_seen = true; game.connected = false; game.dropout_since = -100.0; game.last_telemetry = -100.0
	game._physics_process(0.5)
	check(game.clock == stopped_at and game.team_race.ours.phase_seconds == exchange_at, "Trainer pause freezes relay motion and race clock together")
	game.trainer_seen = false; game.dropout_since = -1.0
	while not game._all_riders_finished() and game.clock < 1000.0:
		game.watts = 0.0 if game.team_race.ours.player_is_out() else (340.0 if game.team_race.ours.order[0] == 0 else 180.0)
		if game.team_race.ours.order[0] == 0 and game.team_race.ours.turn_seconds >= 10.0: game.team_race.ours.request_exchange()
		game.clock += 0.1; game._update_race(0.1)
	game._refresh_fullscreen_results()
	check(game.finish_table.get_child_count() == 15 and game.pursuit_save_box.visible and game.finish_heading.text.begins_with("PLOEGENACHTERVOLGING"), "Team-only result table and save prompt after finish")
	game.finish_overlay.show()
	await process_frame; await process_frame
	check(game.finish_table.get_global_rect().size.x < 1000.0, "Team result table wraps lap times within available width")
	var directory := "res://tests/tmp_team_ui_%d" % Time.get_ticks_usec()
	game.team_library.directory = directory; options.library.directory = directory
	game.pursuit_save_name.text = "Mijn viermansploeg"
	game.pursuit_save_button.pressed.emit()
	check(not game.pursuit_saved_id.is_empty() and game.pursuit_save_button.disabled, "Real result save button stores named team performance once")
	var saved_path: String = directory.path_join(game.pursuit_saved_id + ".json")
	game._reset(); game.setup_panel.select_mode(2)
	options.opponent_choice.select(1); options.refresh_rides()
	check(options.can_start(), "Saved performance available in team menu")
	game._confirm_start(); game.broadcast_intro.finish()
	check(game.race_mode == 5 and not game.team_race.replay.is_empty(), "Saved team opponent starts through actual menu")
	game._reset(); options.opponent_choice.select(0); options.refresh_state()
	game._reset(); game.setup_panel.select_mode(0); game._confirm_start(); game.broadcast_intro.finish(); game._update_hud()
	check(game.race_mode == 0 and ui.power_meter.role_label.text.is_empty() and ui.power_label.get_theme_color("font_color") == ui.INK, "Scratch restores HUD and normal power colour")
	game._update_visuals(0.01)
	for item in game.team_race.badges: check(not item.visible, "Team power badges hidden in scratch")
	check(game.bikes[0].get_child(1) is Label3D, "Other modes keep normal name labels")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open("res://tests/team_results.json", FileAccess.WRITE); file.store_string(JSON.stringify(metrics, "  ")); file.close()
	print("TEAM_PURSUIT_OK" if failures == 0 else "TEAM_PURSUIT_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

