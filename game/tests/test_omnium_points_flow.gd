extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Controller := preload("res://omnium/omnium_points_controller.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for scenario in [[8,"short",40],[12,"women",80],[24,"men",100]]: await check_flow(scenario)
	print("PASS omnium points flow: all formats, 8/12/24 riders, sequence lock, abort/retry, Wprime, real-time bonuses, CPU completion, archive, sprint details, matrix and standalone isolation")
	quit()
func find_row(hud: Node, id: String) -> Node:
	for row in hud.rows.get_children():
		if row.get_meta("rider_id","") == id: return row
	return null
func check_flow(scenario: Array) -> void:
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	var menu = game.setup_panel; var page = menu.tournament_page
	page.manager.store.folder = "user://omnium_points_flow_" + str(Time.get_ticks_usec())
	page.manager.state = {"version":1,"active":{},"archive":[]}
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 30
	var count: int = scenario[0]; var laps: int = scenario[2]
	var riders := catalog.generate(page.player(),count,"mixed",rng)
	var stamp := int(Time.get_unix_time_from_system())
	assert(page.manager.create(riders,scenario[1],95,stamp))
	assert(not Controller.new().start(game,page.manager))
	var ids: Array = []; var energy := {}
	for rider in riders:
		ids.append(rider.id)
		if not rider.get("is_player",false): energy[rider.id] = {"reserve":0.2,"timestamp":stamp-3600}
	for kind in ["scratch","tempo","elimination"]:
		var attempt: Dictionary = page.manager.begin_attempt(stamp)
		assert(page.manager.finish_attempt(attempt.id,{"discipline":kind,"order":ids},energy,stamp))
	menu.show_omnium_details(); await process_frame
	menu.start_omnium_points(); await process_frame
	assert(game.race_mode == 1 and game.race_laps == laps and game.rider_count == count and game.ai_difficulty == 95)
	game.omnium_race.clock_source = func(): return stamp
	game._begin_riding(); game._finish_neutral_start()
	for i in range(1,count): assert(absf(game.x_ai.wprime[i]/game.x_ai.wmax[i]-0.84) < 0.000001)
	assert(game.pc_energy_model.wprime[1] == game.pc_energy_model.wmax[1])
	assert(game.x_ai.omnium_tactics != null)
	game._reset(); await process_frame
	assert(page.manager.state.active.results.size() == 3 and page.manager.state.active.energy == energy)
	menu.start_omnium_points(); await process_frame
	game.omnium_race.clock_source = func(): return stamp
	game._begin_riding(); game._finish_neutral_start()
	var now := [1000]; game.omnium_race.bonus_clock = func(): return now[0]
	game.points_rules._award_lap(0,1,10.0)
	game.points_rules.sprints.append({"lap":10,"seconds":10.0,"order":[0],"times":[10.0],"awards":[5]}); game.points_rules.points[0] += 5
	game.omnium_race.update_hud(game)
	var hud = game.omnium_race.hud; var row: Node = find_row(hud,"player")
	assert(row.get_child(4).text == "145" and row.get_child(5).text == "+25")
	game.omnium_race.update_hud(game); assert(find_row(hud,"player").get_child(5).text == "+25")
	now[0] = 9999; game.points_rules._award_lap(1,-1,20.0)
	game.omnium_race.update_hud(game)
	assert(find_row(hud,String(riders[1].id)).get_child(5).text == "-20")
	now[0] = 11000; game.omnium_race.update_hud(game)
	assert(find_row(hud,"player").get_child(5).text == "")
	# New event replaces the previous notice; expiry uses wall time, not race time.
	game.points_rules.sprints.append({"lap":20,"seconds":21.0,"order":[0],"times":[21.0],"awards":[3]}); game.points_rules.points[0] += 3
	game.omnium_race.update_hud(game); assert(find_row(hud,"player").get_child(5).text == "+3")
	game.clock += 500.0; game.omnium_race.update_hud(game); assert(find_row(hud,"player").get_child(5).text == "+3")
	await process_frame; assert(hud.size.x <= 322.1)
	# Seed already adjudicated earlier sprints and the player's final passage;
	# the remaining final sprint is completed by actual race physics at CPU speed.
	var jury = game.points_rules; jury.sprints.clear(); jury.points.fill(0)
	jury.points[0] = 20; jury.points[1] = -20
	for lap in range(10,laps,10):
		var order: Array = []; var times: Array = []; var awards: Array = []
		for i in range(count):
			order.append(i); times.append(float(lap)+i*0.1); awards.append([5,3,2,1][i] if i < 4 else 0); jury.points[i] += int(awards[-1])
		jury.sprints.append({"lap":lap,"seconds":float(lap),"order":order,"times":times,"awards":awards})
	jury.sprints.append({"lap":laps,"seconds":1000.0,"order":[0],"times":[1000.0],"awards":[10]}); jury.points[0] += 10
	jury.finish_clock = 1000.0; jury.last_sprint_clock = 1000.0
	game.clock = 1001.0; game.finish_times[0] = 1000.0; game.finished = true
	for i in range(count): game.distances[i] = game._race_length()-1.0+i*0.001; game.speeds[i] = 12.0
	game.finish_overlay.show(); game._refresh_fullscreen_results()
	assert(game.results_completion.active)
	for frame in range(5000):
		await process_frame
		if not game.results_completion.active: break
	assert(jury.complete() and game.omnium_race.committed)
	assert(page.manager.state.active.is_empty() and page.manager.state.archive.size() == 1)
	var tournament: Dictionary = page.manager.state.archive[0]
	assert(tournament.results.size() == 4 and tournament.status == "completed")
	var result: Dictionary = tournament.results[3]
	assert(result.points.size() == count and result.sprints.size() == laps/10)
	assert(result.final_sprint_order.size() == count and result.final_sprint_times.size() == count)
	assert(tournament.energy.size() == count-1)
	assert(Scores.totals(riders,tournament.results).player == 120+20+5*(laps/10-1)+10)
	assert(game.finish_heading.text.contains("Eindklassement"))
	assert(game._strava_activity_title() == "Vélodrome - Omnium - Puntenkoers")
	var button := game.finish_overlay.find_child("ReplayRaceButton",true,false) as Button
	assert(not button.disabled); button.pressed.emit(); await process_frame
	assert(not page.archived_tournament.is_empty() and page.body.find_child("OmniumArchiveMatrix",true,false) != null)
	var archived_before := JSON.stringify(page.manager.state.archive[0])
	page.archive_view.change_sort(page,4); await process_frame
	page.archive_view.change_sort(page,4); await process_frame
	assert(JSON.stringify(page.manager.state.archive[0]) == archived_before)
	page.open_result(3); await process_frame
	var table: Node = page.body.find_child("OmniumSavedResultTable",true,false)
	var detail_row: Button = table.find_child("OmniumResult_player",true,false)
	detail_row.button_pressed = true
	assert(table.find_child("OmniumSprintDetails_player",true,false).visible)
	assert(table.find_child("OmniumSprintDetails_player",true,false).get_child(0).text.contains("FINISH ×2"))
	page.go_back(); await process_frame
	assert(page.result_index == -1 and not page.archived_tournament.is_empty())
	assert(page.manager.load_session(stamp)); assert(page.manager.state.archive.size() == 1)
	menu.show_tournaments(); await process_frame
	page.open_archive_list(); await process_frame
	assert(page.archive_list)
	# A new standalone AI has no omnium demand/strategy object.
	game.race_mode = 1; game._configure_peloton(); assert(game.x_ai.omnium_tactics == null)
	for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(page.manager.store.folder))
	game.queue_free(); await process_frame
