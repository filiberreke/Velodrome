extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
const Catalog := preload("res://omnium/omnium_catalog.gd")
class NativeRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _register_performance() -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := Catalog.new()
	assert(catalog.load_catalog(), catalog.error)
	for count in [8, 12, 24]:
		var manager := Manager.new()
		manager.store.folder = "user://omnium_native_test_" + str(Time.get_ticks_usec())
		var rng := RandomNumberGenerator.new(); rng.seed = count
		var riders := catalog.generate({"id":"player", "name":"Player", "profile":0, "country":"belgium", "is_player":true}, count, "mixed", rng)
		var now := int(Time.get_unix_time_from_system())
		assert(manager.create(riders, "short", 80, now))
		var game := NativeRace.new(); root.add_child(game)
		game.omnium_race.manager = manager
		game.omnium_race.attempt = manager.begin_attempt(now)
		game.omnium_race.context = manager.state.active.duplicate(true)
		game.race_mode = 0; game.race_laps = 20; game.rider_count = count; game.ai_difficulty = 80
		game._configure_peloton()
		for i in range(count):
			assert(game.rider_identities[i].id == riders[i].id)
			assert(game.rider_forms[i] == 1)
			game.distances[i] = -2.4 * (i / 2)
			game.speeds[i] = 11.11
		game._finish_neutral_start()
		game.x_ai.rng.seed = count
		game.running = true; game.watts = 250; game.baseline_speed = 11.11
		var iterations := 0
		while not game._all_riders_finished() and iterations < 120000:
			game.clock += 1.0 / 30.0
			game._update_race(1.0 / 30.0)
			iterations += 1
		assert(game._all_riders_finished(), "Native scratch did not finish")
		assert(game.omnium_race.committed)
		assert(manager.state.active.results.size() == 1)
		assert(manager.state.active.results[0].order.size() == count)
		assert(manager.state.active.energy.size() == count - 1)
		print("PASS native omnium scratch: %d riders, %d simulation steps, %.1f race seconds" % [count, iterations, game.clock])
		game.omnium_race.clear(); game.free()
		for suffix in ["state.json", "state.json.bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
	quit()
