extends SceneTree
const Formats := preload("res://omnium/omnium_formats.gd")
const Manager := preload("res://omnium/omnium_manager.gd")
const Catalog := preload("res://omnium/omnium_catalog.gd")
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

func expected_reserve(initial: float, elapsed: int) -> float:
	return 1.0 if elapsed >= 14400 else initial + (1.0 - initial) * (1.0 - pow(0.2, float(elapsed) / 3600.0))
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 30
	var riders := catalog.generate({"id":"player", "name":"Player", "profile":0, "country":"belgium", "is_player":true}, 24, "mixed", rng)
	var checks := 0
	for format_id in ["short", "men", "women"]:
		var manager := Manager.new()
		manager.store.folder = "user://omnium_tempo_recovery_" + str(Time.get_ticks_usec())
		var base_time := int(Time.get_unix_time_from_system())
		assert(manager.create(riders, format_id, 95, base_time))
		var scratch := Race.new(); root.add_child(scratch)
		scratch.omnium_race = Scratch.new()
		scratch.omnium_race.clock_source = func(): return base_time
		scratch.omnium_race.manager = manager
		scratch.omnium_race.attempt = manager.begin_attempt(base_time)
		scratch.omnium_race.context = manager.state.active.duplicate(true)
		scratch.race_mode = 0; scratch.race_laps = Formats.race_laps(format_id, "scratch", 24); scratch.rider_count = 24; scratch.ai_difficulty = 95
		scratch._configure_peloton(); scratch._finish_neutral_start()
		var levels := [0.0, 0.2, 0.5, 0.8, 1.0]
		for i in range(24):
			scratch.finish_times[i] = 100 + i
			if i > 0:
				scratch.x_ai.wprime[i] = scratch.x_ai.wmax[i] * float(levels[(i - 1) % levels.size()])
				scratch.x_ai.fatigue[i] = 0.75
		scratch.omnium_race.sample(scratch)
		assert(scratch.omnium_race.committed)
		var saved_energy: Dictionary = manager.state.active.energy.duplicate(true)
		assert(saved_energy.size() == 23)
		scratch.omnium_race.clear(); scratch.free()
		for elapsed in [0, 1800, 3600, 7200, 14400]:
			var restored := Manager.new(); restored.store.folder = manager.store.folder
			var start_time: int = base_time + elapsed
			assert(restored.load_session(start_time))
			var reloaded_energy: Dictionary = restored.state.active.energy.duplicate(true)
			for id in saved_energy:
				assert(absf(restored.recovered_energy(start_time)[id] - manager.recovered_energy(start_time)[id]) < 0.00001)
			var tempo := Race.new(); root.add_child(tempo)
			tempo.omnium_race = Tempo.new()
			tempo.omnium_race.clock_source = func(): return start_time
			tempo.omnium_race.manager = restored
			tempo.omnium_race.attempt = restored.begin_attempt(start_time)
			assert(tempo.omnium_race.attempt.discipline == "tempo")
			tempo.omnium_race.context = restored.state.active.duplicate(true)
			# Deliberately change local slots: reserve lookup must use stable rider IDs.
			var opponents: Array = tempo.omnium_race.context.riders.slice(1); opponents.reverse()
			tempo.omnium_race.context.riders = [riders[0]] + opponents
			tempo.race_mode = 8; tempo.race_laps = Formats.race_laps(format_id, "tempo", 24); tempo.rider_count = 24; tempo.ai_difficulty = 95
			tempo._configure_peloton()
			tempo._reset_pc_energy(); tempo.pc_energy_model.wprime[1] = 0
			tempo._begin_riding()
			assert(tempo.pc_energy_model.wprime[1] == tempo.pc_energy_model.wmax[1])
			tempo._finish_neutral_start()
			for i in range(1,24):
				var id: String = tempo.rider_identities[i].id
				var initial: float = saved_energy[id].reserve
				assert(absf(tempo.x_ai.wmax[i] - float(saved_energy[id].capacity_j)) < 0.001)
				assert(absf(tempo.x_ai.wprime[i] / tempo.x_ai.wmax[i] - expected_reserve(initial, elapsed)) < 0.00001)
				assert(tempo.x_ai.fatigue[i] == 0.0)
				checks += 1
			# Reloading/applying repeatedly cannot compound the recovery curve.
			for repeat in range(3): tempo.omnium_race.apply_reserves(tempo)
			for i in range(1,24):
				var id: String = tempo.rider_identities[i].id
				assert(absf(tempo.x_ai.wprime[i] / tempo.x_ai.wmax[i] - expected_reserve(float(saved_energy[id].reserve), elapsed)) < 0.00001)
			assert(tempo.omnium_race.may_leave(tempo))
			assert(restored.state.active.results.size() == 1 and restored.state.active.attempt.is_empty())
			assert(restored.state.active.energy == reloaded_energy)
			tempo.omnium_race.clear(); tempo.free()
		print("PASS tempo recovery format=%s: 0/30/60/120/240 minutes, 23 AI, mixed profiles, reversed slots, reload and abort" % format_id)
		for suffix in ["state.json", "state.json.bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
	print("PASS %d actual AI reserve checks after neutral-start reset; player always starts fresh" % checks)
	quit()
