extends SceneTree
## Regression: 24 riders, player eliminated in 19th; finish the real remaining race.
const Catalog := preload("res://omnium/omnium_catalog.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class UncachedGame extends Game:
	func _at(distance: float, offset: float) -> Vector3: return _at_uncached(distance, offset)
	func _elimination_metric_for(i: int, lane: float) -> float: return _path_metric(distances[i], lane)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cached: Dictionary = await scenario(false)
	var uncached: Dictionary = await scenario(true)
	assert(cached.order == uncached.order)
	for id in cached.finish_times:
		assert(absf(cached.finish_times[id] - uncached.finish_times[id]) < 0.000001)
	for id in cached.energy:
		assert(absf(cached.energy[id].reserve - uncached.energy[id].reserve) < 0.000000001)
	print("PASS 24-rider elimination CPU completion: exact cached/uncached results and Wprime, frozen player, persistence, enabled buttons and return to omnium")
	quit()
func scenario(uncached: bool) -> Dictionary:
	var game: Game = UncachedGame.new() if uncached else Game.new()
	root.add_child(game); game.set_physics_process(false)
	var menu = game.setup_panel; var page = menu.tournament_page
	page.manager.store.folder = "user://omnium_elimination_completion_" + str(Time.get_ticks_usec())
	page.manager.state = {"version":1,"active":{},"archive":[]}
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 30
	var riders := catalog.generate(page.player(),24,"mixed",rng)
	var stamp := int(Time.get_unix_time_from_system())
	assert(page.manager.create(riders,"men",95,stamp))
	var ids: Array = []; var energy := {}
	for rider in riders:
		ids.append(rider.id)
		if not rider.get("is_player",false): energy[rider.id] = {"reserve":0.2,"timestamp":stamp-3600}
	for discipline in ["scratch","tempo"]:
		var attempt: Dictionary = page.manager.begin_attempt(stamp)
		assert(page.manager.finish_attempt(attempt.id,{"discipline":discipline,"order":ids},energy,stamp))
	menu.show_omnium_details(); await process_frame
	menu.start_omnium_elimination(); await process_frame
	game.omnium_race.clock_source = func(): return stamp
	game._begin_riding(); game._finish_neutral_start()
	game.trainer_seen = true; game.watts = 268.0; game.baseline_speed = 11.11
	# Reproduce the reported result position, not an eight-rider final-pair fixture.
	game.clock = 325.0; game.finished = true
	game.elimination_rules.eliminated.assign([23,22,21,20,19,0])
	for i in game.elimination_rules.eliminated:
		game.elimination_rules.active[i] = false; game.finish_times[i] = 325.0
	game.elimination_rules.next_line_m = 3500.0
	for i in range(24):
		game.distances[i] = 3490.0 + float(i)*0.2; game.speeds[i] = 12.0
		game.elimination_rules.last_rear_m[i] = game.distances[i] - game.REAR_TRAILING_EDGE_M
	var player_distance: float = game.distances[0]
	game.finish_overlay.show(); game._refresh_fullscreen_results()
	var primary := game.finish_overlay.find_child("ReplayRaceButton",true,false) as Button
	var back := game.finish_overlay.find_child("MainMenuButton",true,false) as Button
	assert(game.results_completion.active and primary.disabled and back.disabled)
	assert(game.finish_results.text.contains("versneld berekend"))
	var started_us := Time.get_ticks_usec(); var frames := 0
	for frame in range(10000):
		await process_frame; frames += 1
		if not game.results_completion.active: break
	assert(game._all_riders_finished() and game.omnium_race.committed)
	assert(not primary.disabled and not back.disabled)
	assert(game.finish_times[0] == 325.0 and game.distances[0] == player_distance)
	assert(game.elimination_rules.eliminated.size() == 22)
	var result: Dictionary = page.manager.state.active.results[2].duplicate(true)
	assert(result.order.size() == 24 and result.order[18] == riders[0].id)
	assert(page.manager.state.active.energy.size() == 23)
	result["energy"] = page.manager.state.active.energy.duplicate(true)
	print("COMPLETED uncached=%s wall_s=%.3f simulated_s=%.3f frames=%d" % [uncached,(Time.get_ticks_usec()-started_us)/1e6,game.clock-325.0,frames])
	assert(page.manager.load_session(stamp))
	assert(page.manager.state.active.results.size() == 3)
	assert(page.manager.state.active.results[2].order == result.order)
	primary.pressed.emit(); await process_frame
	assert(menu.visible and menu.page == 7 and page.opened)
	for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	game.queue_free(); await process_frame
	return result
