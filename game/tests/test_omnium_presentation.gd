extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Results := preload("res://omnium/omnium_results.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: run.call_deferred()
func cell_text(game: Node, index: int) -> String:
	return game.finish_table.get_child(index).get_child(0).text
func run() -> void:
	assert(Results.clock(991.53) == "16:31.530")
	assert(Results.clock(59.9996) == "1:00.000")
	assert(Results.clock(0) == "0:00.000")
	for action in ["ReplayRaceButton", "MainMenuButton"]:
		await check_screen(action)
	print("PASS omnium presentation: compact translucent ranked HUD, lap deltas, clock/gaps, 24 score rows, both return buttons and standalone labels")
	quit()
func check_screen(action: String) -> void:
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	var menu = game.setup_panel; var page = menu.tournament_page
	page.manager.store.folder = "user://omnium_presentation_" + str(Time.get_ticks_usec())
	page.manager.state = {"version":1,"active":{},"archive":[]}
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 30
	var riders := catalog.generate(page.player(),24,"mixed",rng)
	assert(page.manager.create(riders,"men",95,int(Time.get_unix_time_from_system())))
	menu.show_omnium_details(); await process_frame
	menu.start_omnium_scratch(); await process_frame
	game._begin_riding(); game._finish_neutral_start()
	game.scratch_rules.credits[0] = 3; game.scratch_rules.credits[1] = 3
	game.scratch_rules.credits[2] = 2; game.scratch_rules.credits[-1] = -2
	game.omnium_race.update_hud(game); await process_frame
	var hud = game.omnium_race.hud
	assert(hud.rows.get_child_count() == 25)
	assert(hud.size.x <= 280.1 and hud.get_minimum_size().x <= 280.1)
	assert(absf(hud.get_theme_stylebox("panel").bg_color.a - 0.75) < 0.001)
	assert(hud.rows.get_child(1).get_child(0).text == "1.")
	assert(hud.rows.get_child(1).get_child(1) is TextureRect)
	assert(hud.rows.get_child(1).get_child(3).text == "+3 ronden")
	assert(hud.rows.get_child(24).get_child(3).text == "-2 ronden")
	game.finish_times[0] = 991.53; game.finished = true
	game.finish_overlay.show(); game._refresh_fullscreen_results()
	var primary := game.finish_overlay.find_child("ReplayRaceButton",true,false) as Button
	var back := game.finish_overlay.find_child("MainMenuButton",true,false) as Button
	assert(primary.text == "Ga verder met omnium" and back.text == "← Omnium")
	assert(primary.disabled and back.disabled)
	game.results_completion.cancel()
	for i in range(1,24): game.finish_times[i] = 991.53 + i * 0.29
	game._refresh_fullscreen_results()
	assert(game.omnium_race.committed and not primary.disabled and not back.disabled)
	assert(game.finish_table.columns == 4 and game.finish_table.get_child_count() == 100)
	assert(cell_text(game,2) == "TIJD / ACHTERSTAND" and cell_text(game,3) == "OMNIUMPUNTEN")
	assert(cell_text(game,6) == "16:31.530" and cell_text(game,7) == "40")
	assert(cell_text(game,10) == "+0:00.290")
	assert(cell_text(game,14) == "+1 ronde")
	assert(cell_text(game,98) == "+5 ronden" and cell_text(game,99) == "1")
	assert(game.finish_heading.text.begins_with("Omnium"))
	await process_frame
	(primary if action == "ReplayRaceButton" else back).pressed.emit()
	await process_frame
	assert(menu.visible and menu.page == 7 and page.opened)
	assert(not game.omnium_race.enabled() and not game.finish_overlay.visible)
	assert(page.manager.state.active.results.size() == 1)
	game._refresh_fullscreen_results()
	assert(primary.text == "Wedstrijd opnieuw rijden" and back.text == "← Hoofdmenu")
	assert(cell_text(game,2) == "EINDTIJD" and cell_text(game,3) == "VERSCHIL")
	for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	await process_frame; game.queue_free(); await process_frame
