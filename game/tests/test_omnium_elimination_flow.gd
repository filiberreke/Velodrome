extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Manager := preload("res://omnium/omnium_manager.gd")
const Controller := preload("res://omnium/omnium_elimination_controller.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	var menu = game.setup_panel; var page = menu.tournament_page
	page.manager.store.folder = "user://omnium_elimination_flow_" + str(Time.get_ticks_usec())
	page.manager.state = {"version":1,"active":{},"archive":[]}
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 30
	var riders := catalog.generate(page.player(),8,"mixed",rng)
	var stamp := int(Time.get_unix_time_from_system())
	assert(page.manager.create(riders,"short",95,stamp))
	var too_early := Controller.new()
	assert(not too_early.start(game,page.manager))
	assert(page.manager.state.active.attempt.is_empty())
	var ids: Array = []; var energy := {}
	for rider in riders:
		ids.append(rider.id)
		if not rider.get("is_player",false): energy[rider.id] = {"reserve":0.2,"timestamp":stamp-3600}
	for discipline in ["scratch","tempo"]:
		var attempt: Dictionary = page.manager.begin_attempt(stamp)
		assert(page.manager.finish_attempt(attempt.id,{"discipline":discipline,"order":ids},energy,stamp))
	var restored := Manager.new(); restored.store.folder = page.manager.store.folder
	assert(restored.load_session(stamp)); page.manager = restored
	var original_energy: Dictionary = restored.state.active.energy.duplicate(true)
	menu.show_omnium_details(); await process_frame
	menu.start_omnium_elimination(); await process_frame
	assert(game.race_mode == 2 and game.rider_count == 8 and game.race_laps == 8 and game.ai_difficulty == 95)
	game.omnium_race.clock_source = func(): return stamp
	game._begin_riding(); game._finish_neutral_start()
	assert(game.elimination_rules.interval_m == 250 and game.elimination_rules.next_line_m == 250)
	for i in range(1,8):
		assert(game.rider_identities[i].id == riders[i].id)
		assert(absf(game.x_ai.wprime[i]/game.x_ai.wmax[i] - 0.84) < 0.00001)
	assert(game.pc_energy_model.wprime[1] == game.pc_energy_model.wmax[1])
	game.elimination_rules.active[1] = false; game.elimination_rules.eliminated.append(1)
	game.finish_times[1] = 1; game.distances[1] = 100000
	for row in game.omnium_race.standings(game):
		if row.id == riders[1].id: assert(row.score == 102) # 38 + 38 + fixed eighth (26).
	game._update_hud()
	assert(not game.race_overlay.eliminated_panel.visible and game.omnium_race.hud.visible)
	game._reset(); await process_frame
	assert(menu.page == 7 and page.opened)
	assert(page.manager.state.active.results.size() == 2 and page.manager.state.active.attempt.is_empty())
	assert(page.manager.state.active.energy == original_energy)
	menu.start_omnium_elimination(); await process_frame
	game.omnium_race.clock_source = func(): return stamp
	game._begin_riding(); game._finish_neutral_start()
	# Player is first out. The real remaining race must finish at CPU speed.
	game.clock = 100; game.finished = true; game.finish_times[0] = 99
	game.distances[0] = 250 + game.REAR_TRAILING_EDGE_M
	game.elimination_rules.active[0] = false; game.elimination_rules.eliminated.assign([0]); game.elimination_rules.next_line_m = 500
	for i in range(1,8): game.distances[i] = 495+i*0.2; game.speeds[i] = 12
	for i in range(8): game.elimination_rules.last_rear_m[i] = game.distances[i]-game.REAR_TRAILING_EDGE_M
	game.finish_overlay.show(); game._refresh_fullscreen_results()
	assert(game.results_completion.active)
	assert(game.finish_results.text.contains("versneld berekend"))
	var worker_clock: float = game.clock
	game._physics_process(1.0/60.0)
	assert(game.clock == worker_clock) # Only the CPU worker owns the remaining race.
	for frame in range(10000):
		await process_frame
		if not game.results_completion.active: break
	assert(game._all_riders_finished() and game.omnium_race.committed)
	var result: Dictionary = page.manager.state.active.results[2]
	assert(result.order[-1] == riders[0].id and result.elimination_order.size() == 6)
	assert(result.elimination_interval_m == 250)
	assert(page.manager.state.active.results.size() == 3 and page.manager.state.active.energy.size() == 7)
	assert(game._strava_activity_title() == "Vélodrome - Omnium - Afvalling")
	assert(game.finish_results.text.contains("OMNIUM") and game.finish_results.text.contains("106"))
	var name_cell: Node = game.finish_table.get_child(6)
	assert(name_cell.get_child(0).get_child(0) is TextureRect)
	game._reset(); await process_frame
	assert(menu.page == 7 and page.opened and page.manager.state.active.results.size() == 3)
	assert(not game.omnium_race.enabled() and game.elimination_rules.interval_m == 500)
	var reloaded := Manager.new(); reloaded.store.folder = page.manager.store.folder
	assert(reloaded.load_session(int(Time.get_unix_time_from_system())))
	assert(reloaded.state.active.results.size() == 3 and reloaded.state.active.energy.size() == 7)
	assert(reloaded.state.active.results[2].order == result.order)
	for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	await process_frame; game.queue_free(); await process_frame
	print("PASS elimination menu: stage lock, one-hour Wprime recovery, player fresh, fixed eliminated rank, HUD, abort/retry, CPU completion, scoring, flags and return")
	quit()
