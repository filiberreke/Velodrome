extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Formats := preload("res://omnium/omnium_formats.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
const Elimination := preload("res://omnium/omnium_elimination_controller.gd")
class Race extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_elimination_photo(_rider: int, _line: float) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	for scenario in [[8,"short",0],[8,"men",3600],[24,"short",3600],[24,"women",14400]]:
		var count: int = scenario[0]; var format_id: String = scenario[1]; var rest: int = scenario[2]
		var manager := Manager.new(); manager.store.folder = "user://omnium_elimination_native_" + str(Time.get_ticks_usec())
		var rng := RandomNumberGenerator.new(); rng.seed = count
		var riders := catalog.generate({"id":"player","name":"Player","profile":0,"country":"belgium","is_player":true},count,"mixed",rng)
		var base_time := int(Time.get_unix_time_from_system())
		assert(manager.create(riders,format_id,80,base_time))
		var ids: Array = []; var energy := {}
		for rider in riders:
			ids.append(rider.id)
			if not rider.get("is_player", false): energy[rider.id] = {"reserve":0.5,"timestamp":base_time}
		for discipline in ["scratch","tempo"]:
			var attempt := manager.begin_attempt(base_time)
			assert(manager.finish_attempt(attempt.id,{"discipline":discipline,"order":ids},energy,base_time))
		var game := Race.new(); root.add_child(game)
		game.omnium_race = Elimination.new(); game.omnium_race.manager = manager
		var stamp := base_time + rest
		game.omnium_race.clock_source = func(): return stamp
		game.omnium_race.attempt = manager.begin_attempt(stamp)
		game.omnium_race.context = manager.state.active.duplicate(true)
		game.race_mode = 2; game.race_laps = Formats.race_laps(format_id,"elimination",count); game.rider_count = count; game.ai_difficulty = 80
		game.elimination_notice = Label.new(); game.add_child(game.elimination_notice)
		game._configure_peloton()
		for i in range(count): game.distances[i] = -2.4*(i/2); game.speeds[i] = 11.11
		game._finish_neutral_start()
		assert(game.elimination_rules.interval_m == 250.0*int(Formats.settings(format_id).elimination_interval))
		for i in range(1,count):
			assert(game.rider_identities[i].id == riders[i].id)
			assert(absf(game.x_ai.wprime[i]/game.x_ai.wmax[i] - manager.recovered_energy(stamp)[riders[i].id]) < 0.00001)
		game.running = true; game.watts = 250; game.baseline_speed = 11.11
		var steps := 0
		while not game._all_riders_finished() and steps < 120000:
			game.clock += 1.0/30.0; game._update_race(1.0/30.0); steps += 1
		assert(game._all_riders_finished() and game.omnium_race.committed)
		assert(game.elimination_rules.eliminated.size() == count-2)
		assert(game.x_ai.elimination_interval_m == game.elimination_rules.interval_m)
		var result: Dictionary = manager.state.active.results[2]
		assert(result.discipline == "elimination" and result.order.size() == count)
		assert(result.elimination_order.size() == count-2 and manager.state.active.energy.size() == count-1)
		for i in range(count-2): assert(result.order[count-1-i] == result.elimination_order[i])
		var totals := Scores.totals(manager.state.active.riders,manager.state.active.results)
		for id in ids: assert(totals[id] == 2*Scores.place_points(ids.find(id)+1) + Scores.place_points(result.order.find(id)+1))
		print("PASS native omnium elimination: %d riders, %s, %d laps, %.1f race seconds, %d cuts, Wprime and scores saved" % [count,format_id,game.race_laps,game.clock,count-2])
		game.omnium_race.clear(); game.free()
		for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
	quit()
