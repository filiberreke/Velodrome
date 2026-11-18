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
	for suffix in ["state.json", "state.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	await process_frame
	game.queue_free(); await process_frame
	print("PASS omnium scratch flow: direct start, fixed settings/IDs, abort, return to details and retry")
	quit()
