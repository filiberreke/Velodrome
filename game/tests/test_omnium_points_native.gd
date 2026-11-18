extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Controller := preload("res://omnium/omnium_points_controller.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _register_performance() -> void: pass
	func _record_ai_performances() -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var scenarios: Array = []
	for seed_value in [11,12,13]:
		for enabled in [false,true]: scenarios.append([8,"short",40,seed_value,enabled])
	scenarios.append([12,"women",80,14,true]); scenarios.append([24,"men",100,15,true])
	var report: Array = []
	for scenario in scenarios:
		var count: int = scenario[0]; var laps: int = scenario[2]
		var manager := Manager.new(); manager.store.folder = "user://omnium_points_native_"+str(Time.get_ticks_usec())
		var rng := RandomNumberGenerator.new(); rng.seed = int(scenario[3])
		var riders := catalog.generate({"id":"player","name":"Player","country":"belgium","profile":0,"is_player":true},count,"mixed",rng)
		var stamp := int(Time.get_unix_time_from_system())
		assert(manager.create(riders,scenario[1],80,stamp))
		var ids: Array = []; var energy := {}
		for rider in riders:
			ids.append(rider.id)
			if not rider.get("is_player",false): energy[rider.id] = {"reserve":0.5,"timestamp":stamp-3600}
		for kind in ["scratch","tempo","elimination"]:
			var attempt := manager.begin_attempt(stamp)
			assert(manager.finish_attempt(attempt.id,{"discipline":kind,"order":ids.duplicate()},energy,stamp))
			ids.push_front(ids.pop_back())
		var game := Game.new(); root.add_child(game)
		game.omnium_race = Controller.new(); game.omnium_race.manager = manager
		game.omnium_race.clock_source = func(): return stamp
		game.omnium_race.attempt = manager.begin_attempt(stamp); game.omnium_race.context = manager.state.active.duplicate(true)
		game.race_mode = 1; game.race_laps = laps; game.rider_count = count; game.ai_difficulty = 80
		game._configure_peloton(); game._finish_neutral_start()
		game.x_ai.rng.seed = int(scenario[3])
		# reset() normally randomizes personality; pair identical initial AI states.
		for i in range(count):
			var kind: int = game.rider_profiles[i]
			game.x_ai.cooldown[i] = game.x_ai.rng.randf_range(50.0,120.0)
			game.x_ai.cooperation[i] = game.x_ai.rng.randf_range(0.20,0.70) if kind == 2 else game.x_ai.rng.randf_range(0.35,0.95)
			game.x_ai.aggression[i] = game.x_ai.rng.randf_range(0.25,0.65)+(0.22 if kind == 3 else 0.0)
		if not bool(scenario[4]): game.x_ai.omnium_tactics = null
		for i in range(count): game.distances[i] = -2.4*(i/2); game.speeds[i] = 11.11
		game.running = true; game.watts = 250; game.baseline_speed = 11.11
		var steps := 0; var began := Time.get_ticks_msec()
		while not game._all_riders_finished() and steps < 120000:
			game.clock += 1.0/30.0; game._update_race(1.0/30.0); steps += 1
		assert(game._all_riders_finished() and game.omnium_race.committed)
		assert(game.points_rules.complete() and manager.state.active.is_empty() and manager.state.archive.size() == 1)
		var tournament: Dictionary = manager.state.archive[0]; var result: Dictionary = tournament.results[3]
		assert(result.sprints.size() == laps/10 and result.final_sprint_order.size() == count)
		for sprint in result.sprints: assert(sprint.order.size() == count)
		var expected := 11*(laps/10-1)+22+20*(int(game.points_rules.gains.reduce(func(a,b): return a+b,0))-int(game.points_rules.losses.reduce(func(a,b): return a+b,0)))
		assert(int(game.points_rules.points.reduce(func(a,b): return a+b,0)) == expected)
		var totals := Scores.totals(riders,tournament.results)
		var rows := preload("res://omnium/omnium_points_presentation.gd").ranking(riders,tournament.results.slice(0,3),result)
		var profiles := {}
		for i in range(1,count):
			assert(game.x_ai.wprime[i] >= 0 and game.x_ai.wprime[i] <= game.x_ai.wmax[i]+0.001)
			var kind := str(game.rider_profiles[i]); var entry: Dictionary = profiles.get(kind,{"riders":0,"attacks":0,"gains":0,"points":0,"reserve_sum":0.0})
			entry.riders += 1; entry.attacks += game.x_ai.attacks[i]; entry.gains += game.points_rules.gains[i]; entry.points += game.points_rules.points[i]; entry.reserve_sum += game.x_ai.wprime[i]/game.x_ai.wmax[i]; profiles[kind] = entry
		var metrics := {"count":count,"format":scenario[1],"laps":laps,"seed":scenario[3],"tactics":scenario[4],"race_seconds":game.clock,"wall_seconds":(Time.get_ticks_msec()-began)/1000.0,"winner":rows[0].rider.id,"winning_score":rows[0].total,"profiles":profiles,"sprints":result.sprints.size()}
		report.append(metrics); print("PASS native points ",JSON.stringify(metrics))
		assert(manager.load_session(stamp))
		for id in result.points: assert(int(manager.state.archive[0].results[3].points[id]) == int(result.points[id]))
		game.free()
		for suffix in ["state.json","state.json.bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://verification/omnium_points")
	var file := FileAccess.open("res://verification/omnium_points/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"runs":report},"\t")); file.close()
	print("PASS repeated native omnium points simulations: all formats, paired policy baselines, full sprints, Wprime, final archive and score conservation")
	quit()
