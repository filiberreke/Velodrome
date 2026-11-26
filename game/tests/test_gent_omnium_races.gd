extends SceneTree
## Complete all four real race motors, retaining the tournament's Gent venue.
const Fixture := preload("res://tests/test_multiple_venue_selection.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Fixture.Game.new(); root.add_child(game)
	var menu = game.setup_panel
	var manager = menu.tournament_page.manager
	manager.store.folder = "user://gent_complete_omnium"
	manager.state = {"version":1, "active":{}, "archive":[]}
	var catalog := preload("res://omnium/omnium_catalog.gd").new()
	check(catalog.load_catalog(), "Omnium riders available")
	var rng := RandomNumberGenerator.new(); rng.seed = 2091
	var roster := catalog.generate(menu.tournament_page.player(), 8, "mixed", rng)
	check(manager.create(roster, "short", 85, int(Time.get_unix_time_from_system()), "gent"), "Create Gent omnium")
	var stages := ["scratch", "tempo", "elimination", "points"]
	for i in 4:
		menu.call("start_omnium_" + stages[i])
		check(game.venue.id == "gent" and game.omnium_race.enabled(), "Discipline starts in Gent: " + stages[i])
		game.broadcast_intro.finish(); game.demo_launch_watts = 320; game.watts = 320
		game._begin_riding(); game._finish_neutral_start()
		if i == 2: check(absf(game.elimination_rules.interval_m - game.LAP) < .001, "Short omnium eliminates every actual lap")
		var ticks := 0
		while not game._all_riders_finished() and ticks < 40000:
			game.clock += .1; game._advance_race(.1); game.omnium_race.sample(game)
			ticks += 1
		check(game._all_riders_finished() and game.omnium_race.committed, "Real Gent omnium discipline completes: " + stages[i])
		if i < 3:
			check(manager.state.active.venue_id == "gent" and manager.state.active.results.size() == i + 1, "Intermediate results retain Gent")
		else:
			check(manager.state.active.is_empty() and manager.state.archive[-1].venue_id == "gent" and manager.state.archive[-1].results.size() == 4, "Completed omnium archives its venue and four results")
		print("GENT_OMNIUM ", stages[i], " ticks=", ticks)
		game._reset(); await process_frame
	game.free(); await process_frame
	print("GENT_OMNIUM_RACES_OK" if failures == 0 else "GENT_OMNIUM_RACES_FAILED %d" % failures)
	quit(0 if failures == 0 else 1)
