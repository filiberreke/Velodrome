extends SceneTree
class Screen extends "res://main.gd":
	var quit_requested := false
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _quit_application() -> void: quit_requested = true
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var g := Screen.new()
	root.add_child(g)
	g.set_physics_process(false)
	await process_frame
	await process_frame
	var again: Button = g.finish_overlay.find_child("ReplayRaceButton", true, false)
	var menu: Button = g.finish_overlay.find_child("MainMenuButton", true, false)
	check(again.text == "Wedstrijd opnieuw rijden" and menu.text == "← Hoofdmenu", "Result buttons clearly describe different actions")
	for scenario in [[0,0], [3,0], [5,0], [7,0], [7,1], [1,0], [2,0]]:
		g._reset()
		await process_frame
		g.setup_panel.select_mode(scenario[0])
		if scenario[0] == 7: g.setup_panel.time_trial_start.select(scenario[1])
		if scenario[0] in [1,2]:
			g.setup_panel.pursuit_flow.select_distance(1000)
			if scenario[0] == 2: g.setup_panel.pursuit_flow.select_size(4)
			g.setup_panel.pursuit_flow.next_step()
		g._confirm_start()
		g.broadcast_intro.finish()
		check(not g.replay_setup.is_empty() and g.start_state == "WAIT_STOP", "Race settings captured before replay")
		var mode: int = g.race_mode
		var laps: int = g.race_laps
		var start_type: String = g.time_trial_start_type
		var names: Array[String] = g.rider_names.duplicate()
		var forms: Array[float] = g.rider_forms.duplicate()
		var identities: Array = g.rider_identities.duplicate(true)
		var previous_replay: Dictionary = g.pursuit_replay.duplicate(true)
		var factors: Array[float] = g.team_race.ours.position_factors.duplicate()
		for repeat in range(2):
			g.finished = true
			g.clock = 60.0
			g.distances.fill(g._race_length())
			g.speeds.fill(12.0)
			g.finish_times.fill(60.0)
			g.finish_overlay.show()
			again.pressed.emit()
			await process_frame
			check(g.start_state == "WAIT_STOP" and not g.broadcast_intro.active and not g.setup_panel.visible and not g.finish_overlay.visible, "Replay goes directly to start without menu or intro")
			check(g.race_mode == mode and g.race_laps == laps and g.time_trial_start_type == start_type, "Replay retains discipline, distance and start type")
			check(g.rider_names == names and g.rider_forms == forms and g.rider_identities == identities, "Replay retains exact opponents and their form")
			check(g.clock == 0.0 and g.speeds.max() == 0.0 and g.finish_times.max() == -1.0 and g.flying_start.elapsed == 0.0 and g.neutral_start.elapsed == 0.0, "Replay clears previous race movement and clocks")
			if mode in [4,5]: check(g.pursuit_replay == previous_replay, "Replay keeps the same saved opponent without rescaling")
			if mode == 5: check(g.team_race.ours.position_factors == factors and g.team_race.progress == [0.0,0.0], "Team replay retains resistance factors and resets formation")
		g.finished = true
		g.finish_overlay.show()
		menu.pressed.emit()
		check(g.exit_menu.returning_to_menu and g.finished and not g.setup_panel.visible, "Result stays open until leaving is confirmed")
		g.exit_menu._leave_pressed()
		check(g.start_state == "SETUP" and g.setup_panel.visible and g.setup_panel.page == 1 and not g.quit_requested, "Main menu button returns to game selection without quitting")
	g._reset()
	await process_frame
	g.setup_panel.select_mode(1)
	g.setup_panel.pursuit_flow.select_distance(1000)
	g.setup_panel.pursuit_flow.next_step()
	g.setup_panel.pursuit_options.library.directory = "user://test_result_navigation_replays"
	var samples: Array[Dictionary] = [{"t":0.0,"d":0.0,"p":200.0,"lane":1.18},{"t":10.0,"d":1000.0,"p":400.0,"lane":1.18}]
	var saved: Dictionary = g.setup_panel.pursuit_options.library.save("Vaste tegenstander",1000,10.0,samples)
	check(not saved.has("error"), "Saved opponent fixture is available")
	g.setup_panel.pursuit_flow.select_kind(1)
	g.setup_panel.pursuit_flow.strength_input.value = 50
	g._confirm_start()
	g.broadcast_intro.finish()
	check(not g.pursuit_replay.is_empty() and g.pursuit_replay.time_s == 20.0, "Saved opponent is scaled once for original event")
	var scaled: Dictionary = g.pursuit_replay.duplicate(true)
	for repeat in range(2):
		g.finished = true
		g._restart_same_race()
		await process_frame
		check(g.pursuit_replay == scaled and g.pursuit_replay.time_s == 20.0, "Repeating saved opponent does not apply strength scaling again")
	g._set_menu_visible(false)
	g.finished = true
	g.finish_overlay.show()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_R
	g._unhandled_key_input(key)
	check(g.start_state == "WAIT_STOP" and not g.setup_panel.visible, "R on result screen repeats the same race")
	await process_frame
	g.free()
	await process_frame
	print("RESULT_NAVIGATION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
