extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
const Scratch := preload("res://omnium/omnium_scratch_controller.gd")
const Tempo := preload("res://omnium/omnium_tempo_controller.gd")
class Race extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _register_performance() -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	for count in [8, 24]:
		var manager := Manager.new()
		manager.store.folder = "user://omnium_tempo_native_" + str(Time.get_ticks_usec())
		var rng := RandomNumberGenerator.new(); rng.seed = count
		var riders := catalog.generate({"id":"player","name":"Player","profile":0,"country":"belgium","is_player":true}, count, "mixed", rng)
		assert(manager.create(riders, "short", 80, int(Time.get_unix_time_from_system())))
		var saved_energy := {}
		for stage in range(2):
			var game := Race.new(); root.add_child(game)
			var stamp := int(Time.get_unix_time_from_system()) + (3600 if stage == 1 else 0)
			if stage == 1:
				var restored := Manager.new(); restored.store.folder = manager.store.folder
				assert(restored.load_session(stamp)); manager = restored
			game.omnium_race = Scratch.new() if stage == 0 else Tempo.new()
			game.omnium_race.clock_source = func(): return stamp
			game.omnium_race.manager = manager
			game.omnium_race.attempt = manager.begin_attempt(stamp)
			game.omnium_race.context = manager.state.active.duplicate(true)
			game.race_mode = 0 if stage == 0 else 8
			game.race_laps = 20; game.rider_count = count; game.ai_difficulty = 80
			game._configure_peloton()
			for i in range(count):
				assert(game.rider_identities[i].id == riders[i].id)
				game.distances[i] = -2.4 * (i / 2); game.speeds[i] = 11.11
			game._finish_neutral_start()
			if stage == 1:
				for i in range(1,count):
					var id: String = game.rider_identities[i].id
					assert(absf(game.x_ai.wprime[i]/game.x_ai.wmax[i] - manager.recovered_energy(stamp)[id]) < 0.00001)
			game.running = true; game.watts = 250; game.baseline_speed = 11.11
			var steps := 0
			while not game._all_riders_finished() and steps < 120000:
				game.clock += 1.0/30.0; game._update_race(1.0/30.0); steps += 1
			assert(game._all_riders_finished() and game.omnium_race.committed)
			assert(manager.state.active.results.size() == stage + 1)
			if stage == 0: saved_energy = manager.state.active.energy.duplicate(true)
			else:
				assert(game.tempo_rules.complete())
				var result: Dictionary = manager.state.active.results[1]
				assert(result.discipline == "tempo" and result.race_points.size() == count)
				assert(result.sprints.size() == 16 and result.sprints[-1].order.size() == count)
				var totals := Scores.totals(manager.state.active.riders, manager.state.active.results)
				for rider in riders:
					var expected: int = Scores.place_points(manager.state.active.results[0].order.find(rider.id)+1) + Scores.place_points(result.order.find(rider.id)+1)
					assert(totals[rider.id] == expected)
			print("PASS native %s: %d riders, %.1f race seconds, result and Wprime persisted" % [game.omnium_race.discipline(), count, game.clock])
			game.omnium_race.clear(); game.free()
		for suffix in ["state.json", "state.json.bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
	print("PASS complete Scratch to Tempo transitions with one-hour recovery and reload")
	quit()
