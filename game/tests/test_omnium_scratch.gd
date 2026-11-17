extends SceneTree
const Controller := preload("res://omnium/omnium_scratch_controller.gd")
const Manager := preload("res://omnium/omnium_manager.gd")
const AI := preload("res://x_scratch_ai.gd")
# Test the adapter contract using the real AI energy model and manager/store.
class Race extends Node:
	var rider_count := 0
	var rider_identities: Array[Dictionary] = []
	var finish_times: Array[float] = []
	var start_state := "RACING"
	var x_ai = AI.new()
	func _race_better(a: int, b: int) -> bool: return a < b
	func _all_riders_finished() -> bool:
		for time in finish_times:
			if time < 0: return false
		return true

func _initialize() -> void: run.call_deferred()
func run() -> void:
	for count in [8, 12, 24]:
		var manager := Manager.new()
		manager.store.folder = "user://omnium_scratch_test_" + str(count) + "_" + str(Time.get_ticks_usec())
		var race := Race.new(); root.add_child(race)
		race.rider_count = count
		var profiles: Array[int] = []; var forms: Array[float] = []; var lanes: Array[float] = []
		for i in range(count):
			race.rider_identities.append({"id":"rider_" + str(i), "country":"country_" + str(i), "name":"Rider " + str(i), "is_player":i == 0})
			race.finish_times.append(-1.0)
			profiles.append(0 if i == 0 else 1); forms.append(1.0); lanes.append(1.18)
		race.x_ai.reset(profiles, forms, lanes)
		race.x_ai.apply_ai_strength(80)
		var now := int(Time.get_unix_time_from_system())
		assert(manager.create(race.rider_identities, "short", 80, now))
		var controller := Controller.new()
		controller.manager = manager
		controller.attempt = manager.begin_attempt(now)
		controller.context = manager.state.active.duplicate(true)
		manager.state.active.energy = {"rider_1":{"reserve":0.25,"timestamp":now}}
		controller.apply_reserves(race)
		assert(absf(race.x_ai.wprime[1] / race.x_ai.wmax[1] - 0.25) < 0.001)
		var rows := controller.standings(race)
		assert(rows.size() == count and rows[0].score == 40 and rows[-1].score == (1 if count > 20 else 42 - 2 * count))
		race.finish_times[0] = 100
		controller.sample(race)
		assert(not controller.committed and manager.state.active.results.is_empty())
		assert(not controller.may_leave(race))
		# Individual finish snapshots remain frozen while other riders finish.
		race.finish_times[1] = 101; controller.sample(race)
		var finish_reserve: float = controller.finish_energy.rider_1.reserve
		race.x_ai.wprime[1] = 0
		for i in range(2, count): race.finish_times[i] = 100 + i
		controller.sample(race)
		assert(controller.committed)
		assert(manager.state.active.results.size() == 1)
		assert(manager.state.active.results[0].order[1] == "rider_1")
		assert(manager.state.active.energy.rider_1.reserve == finish_reserve)
		controller.sample(race)
		assert(manager.state.active.results.size() == 1)
		var restored := Manager.new(); restored.store.folder = manager.store.folder
		assert(restored.load_session(now))
		assert(restored.state.active.results.size() == 1)
		controller.clear()
		controller.context = restored.state.active.duplicate(true); controller.manager = restored
		controller.attempt = restored.begin_attempt(now)
		race.finish_times.fill(-1)
		assert(controller.may_leave(race))
		assert(restored.state.active.results.size() == 1 and restored.state.active.attempt.is_empty())
		controller.clear()
		for suffix in ["state.json", "state.json.bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
		race.queue_free()
	print("PASS omnium scratch adapter: 8/12/24 riders, live scores, Wprime, finish transaction, reload and abort")
	quit()
