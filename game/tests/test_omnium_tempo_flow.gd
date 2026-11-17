extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game := Game.new(); root.add_child(game)
	game.set_physics_process(false)
	var menu = game.setup_panel
	var page = menu.tournament_page
	page.manager.store.folder = "user://omnium_flow_test_" + str(Time.get_ticks_usec())
	page.manager.state = {"version":1,"active":{},"archive":[]}
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 30
	var riders := catalog.generate(page.player(), 8, "mixed", rng)
	assert(page.manager.create(riders, "women", 95, int(Time.get_unix_time_from_system())))
	menu.show_omnium_details()
	await process_frame
	menu.start_omnium_scratch()
	assert(game.omnium_race.enabled())
	assert(game.race_mode == 0 and game.race_laps == 40 and game.rider_count == 8)
	assert(game.ai_difficulty == 95)
	assert(game.start_state == "INTRO")
	game.omnium_race.update_hud(game)
	assert(game.omnium_race.hud.rows.get_child_count() == 9)
	await process_frame
	assert(not menu.visible)
	for i in range(8): assert(game.rider_identities[i].id == riders[i].id)
	game._reset()
	await process_frame
	assert(not game.omnium_race.enabled())
	assert(menu.visible and menu.page == 7 and page.opened)
	assert(page.manager.state.active.results.is_empty() and page.manager.state.active.attempt.is_empty())
	assert(int(page.manager.state.active.started) > 0)
	# Retry the invalid scratch within the existing deadlines.
	menu.start_omnium_scratch()
	assert(game.omnium_race.enabled() and game.race_laps == 40)
	game._finish_neutral_start()
	for i in range(8): game.finish_times[i] = 100 + i
	game.omnium_race.sample(game)
	assert(game.omnium_race.committed)
	game._reset()
	await process_frame
	assert(menu.page == 7 and page.opened)
	assert(page.manager.state.active.results.size() == 1)
	# Tempo is reachable only after the committed scratch.
	var scratch_energy: Dictionary = page.manager.state.active.energy.duplicate(true)
	menu.start_omnium_tempo()
	assert(game.race_mode == 8 and game.race_laps == 40 and game.ai_difficulty == 95)
	await process_frame
	game._begin_riding(); game._finish_neutral_start()
	game.x_ai.wprime[1] = 0
	game._reset(); await process_frame
	assert(page.manager.state.active.results.size() == 1)
	assert(page.manager.state.active.energy == scratch_energy)
	menu.start_omnium_tempo(); await process_frame
	game._begin_riding(); game._finish_neutral_start()
	assert(game.pc_energy_model.wprime[1] == game.pc_energy_model.wmax[1])
	for i in range(8): assert(game.rider_identities[i].id == riders[i].id)
	game.tempo_rules.points[0] = 1
	game.tempo_rules.points[1] = 10
	game.tempo_rules.points[2] = 5
	var live: Array = game.omnium_race.standings(game)
	for row in live:
		if row.player: assert(row.score == 76) # Scratch win 40 + provisional third 36.
	game.tempo_rules._award_lap(0, 1, 1.0)
	live = game.omnium_race.standings(game)
	for row in live:
		if row.player: assert(row.score == 80) # Lap gain changes discipline rank to first.
	game._update_hud()
	assert(not game.race_overlay.points_panel.visible)
	assert(game.omnium_race.hud.visible)
	var ids: Array = []; var times: Array = []; var awards: Array = []
	for i in range(8):
		game.finish_times[i] = 100 + i
		ids.append(i); times.append(100 + i); awards.append(1 if i == 0 else 0)
	game.tempo_rules.sprints.append({"lap":40,"seconds":100.0,"order":ids,"times":times,"awards":awards})
	game.omnium_race.sample(game)
	assert(game.omnium_race.committed and page.manager.state.active.results.size() == 2)
	assert(page.manager.state.active.results[1].race_points.player == 21)
	assert(game._strava_activity_title() == "Vélodrome - Omnium - Temporace")
	game.finished = true; game.finish_overlay.show(); game._refresh_fullscreen_results()
	assert(game.finish_results.text.contains("OMNIUM"))
	var first_name_cell: Node = game.finish_table.get_child(6)
	assert(first_name_cell.get_child(0).get_child(0) is TextureRect)
	game._reset(); await process_frame
	assert(menu.page == 7 and page.opened and page.manager.state.active.results.size() == 2)
	for suffix in ["state.json", "state.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	await process_frame
	game.queue_free(); await process_frame
	print("PASS Scratch to Tempo menu flow: fixed settings/IDs, abort/retry, live ranks/lap gain, HUD, flags and result persistence")
	quit()
