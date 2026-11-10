extends SceneTree
const Progress := preload("res://madison_progress.gd")
class Training extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _load_rider_config() -> void: rider_config_ready = true
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
var path := "user://test_madison_progress.cfg"
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for sample in [[10,6,false], [10,7,true], [20,13,false], [20,14,true]]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var model := Progress.new(path)
		model.load_progress()
		check(not model.advanced_unlocked, "New player starts locked")
		model.reset_session(sample[0])
		for i in range(sample[0]):
			model.record(i < sample[1], true)
			if i < sample[0] - 1: check(not model.advanced_unlocked, "A whole session must be completed")
		check(model.complete() and model.advanced_unlocked == sample[2], "70 percent threshold for 10/20 attempts")
		var loaded := Progress.new(path)
		loaded.load_progress()
		check(loaded.advanced_unlocked == sample[2] and loaded.last_successes == sample[1], "Session result survives restart")
		model.record(true, true)
		check(model.attempts == sample[0], "Completed session cannot count extra attempts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var advanced := Progress.new(path)
	advanced.reset_session(10)
	for i in range(10): advanced.record(true, false)
	check(not advanced.advanced_unlocked and not FileAccess.file_exists(path), "Advanced practice cannot unlock itself")
	# Feed real controller outcomes into scoring, then the real race finish path.
	var game := Training.new()
	root.add_child(game)
	game.race_mode = 6
	game.madison_progress = Progress.new(path)
	game._configure_peloton()
	game.running = true; game.start_state = "RACING"; game.clock = 100.0
	for i in range(10):
		game.madison.reset()
		game.distances.assign([20.0,20.0]); game.speeds.assign([12.0,10.0]); game.lane_offsets.assign([2.38,3.58]); game.baseline_speed = 12.0
		for tick in range(100): game.madison.step(game, 0.01)
		if i < 7:
			game.madison.button(true)
			game.madison.step(game, game.madison.grab_seconds)
			game.madison.step(game, game.madison.sling_seconds * 0.6)
			game.madison.step(game, game.madison.release_seconds)
		else: game.madison.cancel("Gemiste poging")
		game.madison.step(game, game.madison.separate_seconds)
	check(game.madison_progress.attempts == 10 and game.madison_progress.successes == 7, "Released and missed opportunities count once each")
	game._advance_race(0.01)
	check(game.finished and not game.running and game.madison_progress.advanced_unlocked, "Training ends after 10 opportunities and unlocks Advanced at 7/10")
	game.free()
	await process_frame
	var continuing := Training.new()
	root.add_child(continuing)
	continuing.race_mode = 6; continuing.race_laps = 1
	continuing._configure_peloton()
	continuing.distances.assign([249.0,240.0]); continuing.speeds.assign([12.0,10.0]); continuing.baseline_speed = 12.0
	continuing.watts = 300.0; continuing.clock = 50.0
	continuing._advance_race(1.0)
	check(continuing.distances[0] > 250.0 and continuing.finish_times[0] < 0.0 and not continuing.finished, "Crossing the lap line does not finish an exchange-count session")
	continuing.free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MADISON_PROGRESS_OK" if failures == 0 else "MADISON_PROGRESS_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
