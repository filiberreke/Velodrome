extends SceneTree
const Venues := preload("res://venues/venue_catalog.gd")
const Replays := preload("res://pursuit_records.gd")
const Performances := preload("res://performance_records.gd")
const History := preload("res://time_trial_records.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void:
	var replay := Replays.new(); replay.directory = "user://venue_replays_%d" % Time.get_ticks_usec()
	var samples: Array[Dictionary] = [{"t":0.0,"d":0.0,"p":300.0,"lane":1.18},{"t":100.0,"d":1000.0,"p":300.0,"lane":1.18}]
	var saved := {}
	for id in Venues.available_ids():
		replay.venue_id = id
		saved[id] = replay.save(id, 1000, 100.0, samples)
		check(saved[id].has("id"), "Save venue-aware replay")
	for id in Venues.available_ids():
		replay.venue_id = id
		check(not replay.load_ride(saved[id].id).is_empty(), "Matching replay loads")
		check(replay.load_ride(saved["gent" if id == "velodrome" else "velodrome"].id).is_empty(), "Other stadium cannot be used as replay opponent")
		check(replay.list_rides(1000).size() == 1, "Replay list filters stadium")
	var records := Performances.new(); records.path = "user://venue_performances_%d.json" % Time.get_ticks_usec()
	for id in Venues.available_ids():
		var entry := {"id":id,"mode":4,"distance_m":1000,"team_size":0,"seconds":100.0,"player_name":"Player","finished_at":1000.0,"finished_local":"2026-11-26"}
		entry.merge(Venues.metadata(id))
		check(records.add(entry), "Save venue-aware performance")
	for id in Venues.available_ids():
		records.venue_id = id
		check(records.top(4,1000).size() == 1 and records.top(4,1000)[0].venue_id == id, "Personal records do not mix stadia")
	var history := History.new()
	for id in Venues.available_ids():
		var splits: Array = []
		var count := roundi(500.0 / (Venues.find(id).lap_length_m * .5))
		for i in count: splits.append(float(i + 1) * 60.0 / count)
		check(history.add(500, 60.0, splits, "standing", id), "Time trial uses actual half-lap splits")
	for id in Venues.available_ids():
		check(history.references(500,-1.0,"standing",id).last.venue_id == id, "Time trial references match venue")
	var legacy := {"distance_m":500,"seconds":60.0,"finished_at":1000.0,"splits":[15.0,30.0,45.0,60.0]}
	check(History.valid(legacy) and Venues.compatible(legacy,"velodrome") and not Venues.compatible(legacy,"gent"), "Old history remains Vélodrome without rewriting")
	for invalid in [0.0, NAN, [], "166"]:
		var corrupted := legacy.duplicate(true); corrupted.lap_length_m = invalid
		check(not History.valid(corrupted), "Invalid venue geometry rejected safely")
	print("VENUE_RECORDS_OK" if failures == 0 else "VENUE_RECORDS_FAILED %d" % failures)
	quit(0 if failures == 0 else 1)
