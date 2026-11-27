extends SceneTree
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var uploads := root.get_node("ActivityUploads")
	var original: String = uploads.store.folder
	uploads.store.folder = "user://lifecycle_%d" % Time.get_ticks_usec()
	var game := Game.new(); root.add_child(game)
	game.trainer_seen = true
	var samples: Array[Dictionary] = [{"time_s":0,"distance_m":0,"power_w":120,"game_speed_kmh":30,"cadence_rpm":80},{"time_s":10,"distance_m":90,"power_w":220,"game_speed_kmh":35,"cadence_rpm":90}]
	for mode in [0,1,2,3,4,5,7,8]:
		game.race_mode = mode; game.rider_count = 16; game.race_laps = 20; game._configure_peloton()
		game.ride_activity_id = "race_%d" % mode; game.ride_activity_saved = ""; game.ride_completed = false
		game.recording_saved = true; game.recording_active = true
		game.ride_start_unix = 1730000000; game.ride_records.assign(samples)
		for i in range(game.rider_count): game.finish_times[i] = 10+i
		game._save_recording("elimination" if mode == 2 else "finish")
		check(game.ride_activity_saved == game.ride_activity_id, "Race mode %d archives FIT even if CSV was already saved" % mode)
		check(not game.recording_active, "Recording ends at player finish/elimination")
		var fit := FileAccess.get_file_as_bytes(uploads.store.path(game.ride_activity_saved,"fit"))
		game.clock = 50000
		game._archive_completed_ride()
		check(FileAccess.get_file_as_bytes(uploads.store.path(game.ride_activity_saved,"fit")) == fit, "AI fast-forward never changes saved FIT")
	game.ride_activity_id = "aborted"; game.ride_activity_saved = ""; game.ride_completed = false
	game._save_recording("exit")
	check(uploads.store.load_activity("aborted").is_empty(), "Aborted race never queues an upload")
	game.ride_activity_id = "virtual"; game.trainer_virtual = true
	game._save_recording("finish")
	check(uploads.store.load_activity("virtual").is_empty(), "Virtual trainer race never queues an upload")
	game.trainer_virtual = false
	game.omnium_race.context = {"id":"test_tournament"}; game.omnium_race.attempt = {"id":"test_attempt"}
	game.ride_activity_id = "omnium_scratch"; game.ride_activity_saved = ""; game.race_mode = 0
	game._save_recording("finish")
	var saved: Dictionary = uploads.store.load_activity("omnium_scratch")
	check(saved.get("omnium_id") == "test_tournament" and saved.get("attempt_id") == "test_attempt" and saved.get("discipline") == "scratch", "Omnium links exact tournament, discipline and attempt")
	var manager := preload("res://omnium/omnium_manager.gd").new()
	manager.store.folder = uploads.store.folder + "_omnium"
	var riders: Array = []; var ids: Array = []
	for i in range(16):
		riders.append({"id":str(i), "country":str(i), "is_player":i == 0, "profile":0 if i == 0 else 1, "name":"Rider " + str(i)}); ids.append(str(i))
	check(manager.create(riders, "short", 80, 1730000000), "Create omnium for archived reference verification")
	for discipline in ["scratch", "tempo", "elimination", "points"]:
		game.omnium_race = load("res://omnium/omnium_%s_controller.gd" % discipline).new()
		var attempt: Dictionary = manager.begin_attempt(1730000000)
		game.omnium_race.context = manager.state.active.duplicate(true); game.omnium_race.attempt = attempt
		game.race_mode = game.omnium_race.mode(); game.rider_count = 16; game.race_laps = 40
		game._configure_peloton()
		for i in range(game.rider_count): game.finish_times[i] = 10+i
		game.ride_activity_id = "omnium_" + discipline + "_archive"; game.ride_activity_saved = ""
		game._save_recording("finish")
		var result: Dictionary = game.omnium_race.result_data(game)
		check(result.get("activity_id") == game.ride_activity_id, "Discipline %s result keeps exact activity reference" % discipline)
		check(manager.finish_attempt(attempt.id, {"discipline":discipline,"order":ids,"activity_id":result.activity_id}, {}, 1730000000), "Save result %s" % discipline)
		if not manager.state.active.is_empty():
			check(uploads.store.load_activity(manager.state.active.results[-1].activity_id).discipline == discipline, "Active omnium resolves saved FIT")
	var reloaded := preload("res://omnium/omnium_manager.gd").new(); reloaded.store.folder = manager.store.folder
	reloaded.load_session(1730000000)
	check(reloaded.state.active.is_empty() and reloaded.state.archive.size() == 1, "Complete tournament survives restart in archive")
	for result in reloaded.state.archive[0].results:
		check(FileAccess.file_exists(uploads.store.path(result.activity_id, "fit")), "Archived discipline retains real FIT")
	for filename in DirAccess.open(manager.store.folder).get_files(): DirAccess.remove_absolute(manager.store.folder.path_join(filename))
	DirAccess.remove_absolute(manager.store.folder)
	for kind in ["derny","free_ride","flying_start","peloton","ftp_test","erg_workout","madison"]:
		var activity := {"id":kind,"kind":kind,"started_unix":1730000000,"title":kind,"samples":samples}
		check(uploads.capture_training(activity) == kind, "Training kind %s archives FIT" % kind)
		activity.id = kind + "_demo"; activity.demo = true
		check(uploads.capture_training(activity).is_empty(), "Training demo %s excluded" % kind)
	var warmup := {"id":"warmup","kind":"free_ride","omnium_id":"test_tournament","started_unix":1730000000,"samples":samples}
	check(uploads.capture_training(warmup) == "warmup", "Omnium warmup archived")
	check(uploads.store.load_activity("warmup").title == tr("STRAVA_VE_LODROME_OMNIUM_WARM_UP_RIDE"), "Warmup retains existing Strava title")
	var old_row := preload("res://activity_actions.gd").new(); root.add_child(old_row)
	check(not old_row.export.visible and not old_row.upload.visible, "Older result offers no fictitious export")
	var row := preload("res://activity_actions.gd").new(); row.activity_id = "omnium_scratch"; root.add_child(row)
	check(row.export.visible and row.upload.visible and not row.view.visible, "Saved active/archive result offers FIT and upload")
	saved.status = "uploaded"; saved.activity_id = "12345678900"; uploads.store.save(saved); uploads.changed.emit(saved.id)
	check(row.export.visible and not row.upload.visible and row.view.visible, "Uploaded result offers Strava link and FIT")
	var directory := DirAccess.open(uploads.store.folder)
	for filename in directory.get_files(): directory.remove(filename)
	DirAccess.remove_absolute(uploads.store.folder)
	uploads.store.folder = original
	old_row.free(); row.free(); game.free()
	print("ACTIVITY_LIFECYCLE failures=",failures)
	quit(1 if failures else 0)
