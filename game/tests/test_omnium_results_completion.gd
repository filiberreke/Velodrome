extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
class Race extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _record_ai_performances() -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass

func _initialize() -> void: run.call_deferred()
func run() -> void:
	for scenario in [[8, false], [24, false], [24, true]]:
		var count: int = scenario[0]
		var omnium: bool = scenario[1]
		var game := Race.new(); root.add_child(game)
		game.race_mode = 0; game.rider_count = count; game.race_laps = 20
		var manager := Manager.new()
		manager.store.folder = "user://omnium_completion_test_" + str(Time.get_ticks_usec())
		if omnium:
			var riders: Array = []
			for i in range(count): riders.append({"id":str(i), "country":str(i), "name":"Rider " + str(i), "profile":0 if i == 0 else 1, "is_player":i == 0})
			assert(manager.create(riders, "short", 80, int(Time.get_unix_time_from_system())))
			game.omnium_race.manager = manager
			game.omnium_race.attempt = manager.begin_attempt(int(Time.get_unix_time_from_system()))
			game.omnium_race.context = manager.state.active.duplicate(true)
		game._configure_peloton()
		game.start_state = "RACING"; game.finished = true; game.clock = 100
		game.finish_times[0] = 99; game.distances[0] = 5000
		game.scratch_rules.finish_clock = 99
		for i in range(1, count):
			game.distances[i] = 3000.01 + i * 0.3
			game.speeds[i] = 8
			game.scratch_rules.credits[i] = -8
		game.finish_overlay = ColorRect.new(); game.add_child(game.finish_overlay)
		game.finish_overlay.hide(); game._refresh_fullscreen_results()
		assert(not game.results_completion.active)
		game.finish_overlay.show()
		var started := Time.get_ticks_usec()
		game._refresh_fullscreen_results()
		assert(game.results_completion.active)
		var frames := 0
		while game.results_completion.active and frames < 5000:
			await process_frame
			frames += 1
		var wall_s: float = (Time.get_ticks_usec() - started) / 1000000.0
		assert(game._all_riders_finished())
		assert(game.distances[0] == 5000 and game.finish_times[0] == 99)
		if omnium:
			assert(game.omnium_race.committed)
			assert(manager.state.active.results.size() == 1)
			assert(manager.state.active.results[0].order.size() == count)
			assert(manager.state.active.energy.size() == count - 1)
		var final_clock: float = game.clock
		game._refresh_fullscreen_results(); await process_frame
		assert(game.clock == final_clock)
		print("CPU_COMPLETION riders=%d omnium=%s simulated_s=%.3f wall_s=%.3f frames=%d speedup=%.1fx" % [count, omnium, final_clock - 100, wall_s, frames, (final_clock - 100) / maxf(wall_s, 0.000001)])
		game.omnium_race.clear(); game.free()
		if omnium:
			for suffix in ["state.json", "state.json.bak"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
	print("PASS CPU completion for lapped riders in standalone and omnium scratch")
	quit()
