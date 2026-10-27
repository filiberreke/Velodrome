extends SceneTree
const Game := preload("res://main.gd")
const HUD := preload("res://race_hud.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	check(HUD.clock_text(59.999) == "00:59.9", "Time does not round up to 60 seconds")
	check(HUD.clock_text(60.0) == "01:00.0", "Minute rollover")
	var ids: Array[int] = [1, 2, 3, 4, 5, 0, 6, 7, 8, 9, 10, 11]
	check(HUD.nearby_ids(ids) == [1, 4, 5, 0, 6, 7], "Leader plus five ranks around player, no duplicates")
	ids = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
	check(HUD.nearby_ids(ids) == [0, 1, 2, 3, 4, 5], "First six when player leads")
	ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0]
	check(HUD.nearby_ids(ids) == [1, 8, 9, 10, 11, 0], "Leader remains visible when player is last")
	ids = [1, 0, 2]
	check(HUD.nearby_ids(ids).size() == 3, "Small field has no empty fake rider rows")
	check(Game._gear_from_packet({}) == "—", "Missing gear not invented")
	check(Game._gear_from_packet({"gear": 12}) == "12", "Numeric telemetry gear")
	check(Game._gear_from_packet({"gear_label": " 50×15 "}) == "50×15", "Text transmission ratio")
	check(Game._gear_from_packet({"gear": INF}) == "—", "Invalid gear ignored")
	var game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	check(not game.race_overlay.is_visible_in_tree(), "HUD hidden in opening menu")
	game.setup_panel.select_mode(0)
	game.rider_count_input.value = 12
	game.laps_input.value = 6
	game._confirm_start()
	game.start_state = "RACING"
	game.running = true
	game.clock = 85.4
	game.watts = 412.0
	var positions: Array[float] = [300.0, 350.0, 340.0, 330.0, 320.0, 310.0, 290.0, 280.0, 270.0, 260.0, 250.0, 240.0]
	game.distances = positions
	game.speeds[0] = 10.0
	game.draft_strengths[0] = 0.5
	game._update_hud()
	await process_frame
	await process_frame
	var ui = game.race_overlay
	check(ui.is_visible_in_tree() and not ui.developer_panel.is_visible_in_tree(), "Compact HUD is the default")
	check(ui.power_label.text == "412 W", "Actual player power")
	check(ui.speed_label.text == "36.0", "Actual game speed above player power")
	check(absf(ui.slipstream_bar.value - game._draft_drag_reduction(0) * 100.0) <= 0.011, "Bar shows actual speed-dependent drag reduction within its 0.01-percent display precision")
	game.draft_strengths[0] = 0.0
	game._update_hud()
	check(ui.slipstream_bar.value == 0.0, "No draft means empty slipstream bar")
	game.draft_strengths[0] = 1.0
	game.speeds[0] = 50.0 / 3.6
	game._update_hud()
	check(is_equal_approx(ui.slipstream_bar.value, 69.0) and ui.slipstream_label.text == "69%", "Maximum available slipstream fills bar")
	check(ui.heart_label.text == "— bpm", "Heart rate remains explicit placeholder")
	check(ui.gear_label.text == "—", "No telemetry gear in demo")
	check(ui.lap_label.text == "2/6" and ui.position_label.text == "6/12", "Correct round and actual race rank")
	check(ui.time_label.text == "01:25.4", "Running clock")
	check(ui.gap_caption.text == "PELOTON" and ui.gap_label.text == "In het peloton", "Bunch gap is separate from distance to race leader")
	check(ui.map.progress.size() == 12 and ui.map.rider_colours.size() == 12, "Every rider remains on minimap")
	check(ui.rider_rows.size() == 6 and ui.rider_rows[3]["shell"].get_meta("rider_id") == 0, "Player included and highlighted among six rows")
	check(ui.rider_rows[0]["shell"].get_meta("rider_id") == 3 and ui.rider_rows[0]["rank"].text == "3", "Closest opponents retain their actual race ranks")
	check(not game.hud.is_visible_in_tree() and not game.rankings.is_visible_in_tree(), "Legacy diagnostics absent from normal view")
	for panel in [ui.power_panel, ui.nearby_panel, ui.map_panel, ui.bottom_bar]:
		var bounds: Rect2 = panel.get_global_rect()
		check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= 1920.1 and bounds.end.y <= 1080.1, "Compact HUD stays within reference screen")
	check(ui.bottom_bar.get_global_rect().position.y >= ui.nearby_panel.get_global_rect().end.y, "Rider list does not overlap bottom bar")
	check(ui.nearby_panel.get_global_rect().position.x == ui.power_panel.get_global_rect().position.x and ui.nearby_panel.get_global_rect().position.y >= ui.power_panel.get_global_rect().end.y + 15.0, "Nearby riders sit left below personal box")
	check(ui.map_panel.get_global_rect().position.x > 1400.0, "Miniature track stays top right")
	var key := InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	key.echo = true
	game._unhandled_key_input(key)
	check(not ui.developer_enabled, "Holding X does not flicker developer HUD")
	key.echo = false
	game._unhandled_key_input(key)
	check(ui.developer_enabled and game.hud.is_visible_in_tree() and game.rankings.is_visible_in_tree(), "X reveals all original diagnostics")
	check("Cadans" in game.hud.text and "LAATSTE RONDE" in game.rankings.text, "Original cadence and lap debug info retained")
	game._unhandled_key_input(key)
	check(not ui.developer_enabled, "Second X hides developer HUD")
	game.connected = true
	game.trainer_gear = "12"
	game._update_hud()
	check(ui.gear_label.text == "12", "Connected gear appears in standard HUD")
	# Close the player's former middle slot so the reference bunch stays connected.
	for i in range(6,12): game.distances[i] += 10.0
	game.distances[0] = 400.0
	game._update_hud()
	check(ui.position_label.text == "1/12" and ui.gap_label.text == "50 m vóór peloton", "Escaped leader sees distance ahead of main bunch")
	game.finish_times[0] = 130.456
	game.finished = true
	game.clock = 200.0
	game._update_hud()
	check(ui.time_label.text == "02:10.4", "Player clock freezes at own finish while AI continues")
	game.scratch_rules.credits[0] = -1
	game.distances[0] = 100.0
	game._update_hud()
	check(ui.position_label.text == "1/12" and ui.gap_label.text == "In het peloton" and not game._race_better(0,1), "Nearby race position normalizes lap loss while scratch classification keeps lap credit")
	ui.toggle_developer()
	game._set_race_hud_visible(false)
	check(not ui.is_visible_in_tree() and not ui.developer_panel.is_visible_in_tree(), "Results hide every HUD layer")
	game._reset()
	check(not ui.developer_enabled and not ui.is_visible_in_tree(), "New race resets debug toggle and returns to menus")
	# Pursuit presentation: matching rounds, named replay, lead changes and reset.
	game.race_mode = 4
	game.rider_count = 2
	game.distances.assign([500.0, 500.0])
	game.pursuit_half_crossings = [[15.0, 32.0], [16.0]]
	game.pursuit_replay = {"name": "Mijn opgeslagen recordrit met lange naam"}
	game.clock = 63.429
	game.finish_times.assign([-1.0, -1.0])
	var pursuit_order: Array[int] = [0, 1]
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_center.visible and not ui.scratch_center.visible and not ui.position_label.visible, "Pursuit replaces standard center and position")
	check(ui.right_caption.text == "TOTALE TIJD" and ui.pursuit_time_label.text == "01:03.42", "Total time moves right with hundredths")
	check(ui.pursuit_names[1].text == "Mijn opgeslagen reco", "Saved ride name limited to 20 characters")
	check(ui.pursuit_laps[0].text == "17.00 s" and ui.pursuit_laps[1].text == "", "First arrival shown immediately; slower time cleared at new half lap")
	check(ui.pursuit_gap_label.text == "+31.43 s", "Advantage counts live from player crossing")
	game.clock += 0.25
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_gap_label.text == "+31.68 s", "Live difference increases while waiting")
	check(ui.pursuit_sides[0].get_theme_stylebox("panel") == ui.pursuit_lead_style, "Player leader is white")
	game.pursuit_half_crossings = [[15.0, 32.0], [16.0, 31.0]]
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_laps[1].text == "15.00 s" and ui.pursuit_gap_label.text == "-1.00 s", "Second arrival freezes signed equal-distance difference")
	game.clock += 1.0
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_gap_label.text == "-1.00 s", "Confirmed gap stays fixed until next checkpoint")
	game.pursuit_half_crossings = [[15.0], [16.0, 31.0]]
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_gap_label.text.begins_with("-") and ui.pursuit_laps[0].text == "", "Opponent first counts negative live deficit")
	check(ui.pursuit_sides[1].get_theme_stylebox("panel") == ui.pursuit_lead_style, "Opponent takes white when cumulative lead changes")
	check(ui.pursuit_names[0].text == game._rider_name(0), "Names remain on fixed sides")
	game.pursuit_half_crossings = [[16.0], [16.0]]
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_gap_label.text == "0.00 s" and ui.pursuit_sides[0].get_theme_stylebox("panel") == ui.pursuit_tie_style, "Equal times show neutral sides")
	game.pursuit_half_stats = [[{"kmh": 28.125, "watts": 340.0}], [{"kmh": 28.125, "watts": 250.0}]]
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_stats[0].text == "28.1 km/u · 340 W" and ui.pursuit_stats[1].text == "28.1 km/u · 250 W", "Small segment average speed and power below times")
	game.pursuit_half_crossings = [[], []]
	game.pursuit_replay = {}
	game._update_compact_hud(pursuit_order)
	check(ui.pursuit_names[1].text == "AI" and ui.pursuit_gap_label.text == "", "AI label and no invented pre-lap difference")
	check(ui.pursuit_lead_style.bg_color.a < 0.72 and ui.pursuit_trail_style.bg_color.a < 0.72, "White and red are translucent")
	await process_frame
	await process_frame
	check(ui.bottom_bar.get_global_rect().end.x <= 1920.1, "Pursuit bar remains within viewport")
	for item in ui.pursuit_laps:
		check(item.get_global_rect().end.x <= ui.bottom_bar.get_global_rect().end.x, "Lap time within bottom bar")
	game.race_mode = 0
	game._update_compact_hud(pursuit_order)
	check(not ui.pursuit_center.visible and ui.scratch_center.visible and ui.position_label.visible, "Scratch layout restored")
	game.free()
	print("RACE_HUD_OK" if failures == 0 else "RACE_HUD_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

