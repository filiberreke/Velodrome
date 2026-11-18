extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
const SavedResults := preload("res://omnium/omnium_result_page.gd")
const Results := preload("res://omnium/omnium_results.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: run.call_deferred()
func cell_text(game: Node, index: int) -> String:
	return game.finish_table.get_child(index).get_child(0).text
func cards_in(node: Node) -> Array[Button]:
	var cards: Array[Button] = []
	if node is Button and node.has_meta("discipline_index"): cards.append(node)
	for child in node.get_children(): cards.append_array(cards_in(child))
	return cards
func check_card_focus(page: Node, next_index: int) -> void:
	var cards := cards_in(page.body)
	assert(cards.size() == 5)
	for card in cards:
		assert(not card.disabled)
		var next: bool = int(card.get_meta("discipline_index")) == next_index
		assert(card.get_theme_stylebox("normal").border_width_left == (3 if next else 1))
		assert(card.get_theme_stylebox("normal").bg_color != card.get_theme_stylebox("hover").bg_color)
		card.mouse_entered.emit()
		assert(card.has_focus())
		card.mouse_exited.emit()
		assert(not card.has_focus())
func run() -> void:
	assert(Results.clock(991.53) == "16:31.530")
	assert(Results.clock(59.9996) == "1:00.000")
	assert(Results.clock(0) == "0:00.000")
	for action in ["ReplayRaceButton", "MainMenuButton"]:
		await check_screen(action)
	print("PASS omnium presentation: compact translucent ranked HUD, lap deltas, clock/gaps, 24 score rows, both return buttons, hover/focus, saved full results after reload, legacy saves and standalone labels")
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
	check_card_focus(page, 0)
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
	check_card_focus(page, 1)
	# Reopen from disk, not from the simulation: preserve the full classification.
	assert(page.manager.load_session(int(Time.get_unix_time_from_system())))
	page.refresh(); await process_frame
	var saved: Dictionary = page.manager.state.active.results[0]
	assert(saved.lap_credits[saved.order[0]] == 3)
	assert(saved.lap_credits[saved.order[-1]] == -2)
	for card in cards_in(page.body):
		if int(card.get_meta("discipline_index")) == 0: card.pressed.emit(); break
	await process_frame
	assert(page.result_index == 0 and page.back_button.text == "← Omnium")
	var table := page.body.find_child("OmniumSavedResultTable", true, false) as GridContainer
	assert(table != null and table.columns == 4 and table.get_child_count() == 100)
	assert(table.get_child(6).get_child(0).text == "16:31.530")
	assert(table.get_child(10).get_child(0).text == "+0:00.290")
	assert(table.get_child(14).get_child(0).text == "+1 ronde")
	assert(table.get_child(98).get_child(0).text == "+5 ronden")
	assert(table.get_child(99).get_child(0).text == "1")
	assert(not game.omnium_race.enabled() and not game.finish_overlay.visible)
	assert(page.handle_navigation("B")); await process_frame
	assert(page.result_index == -1 and cards_in(page.body).size() == 5)
	# Old saves remain readable; missing lap credits must never be invented.
	var legacy := saved.duplicate(true); legacy.erase("lap_credits")
	assert(SavedResults.time_text(legacy, String(legacy.order[2])) == "+0:00.580")
	assert(page.manager.state.active.results.size() == 1)
	game._refresh_fullscreen_results()
	assert(primary.text == "Wedstrijd opnieuw rijden" and back.text == "← Hoofdmenu")
	assert(cell_text(game,2) == "EINDTIJD" and cell_text(game,3) == "VERSCHIL")
	for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	await process_frame; game.queue_free(); await process_frame
