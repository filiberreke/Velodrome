extends RefCounted
## Complete history for solo 500 m / 1000 m time trials.
## No top-10 trimming: recent and last ride must survive all-time record changes.
const PATH := "user://time_trial_history.json"
const WINDOW_SECONDS := 60 * 24 * 60 * 60

static func valid(ride: Dictionary) -> bool:
	if str(ride.get("start_type", "standing")) not in ["standing", "flying"]: return false
	if int(ride.get("distance_m", 0)) not in [500, 1000]: return false
	if float(ride.get("seconds", 0.0)) <= 0.0: return false
	if float(ride.get("finished_at", 0.0)) <= 0.0: return false
	var splits: Array = ride.get("splits", [])
	if splits.size() != int(ride["distance_m"]) / 125: return false
	var previous := 0.0
	for value in splits:
		if not (value is float or value is int): return false
		if float(value) <= previous: return false
		previous = float(value)
	if absf(previous - float(ride["seconds"])) > 0.02: return false
	return true

func all_rides() -> Array:
	if not FileAccess.file_exists(PATH): return []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_length() > 4000000: return []
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("rides") is Array: return []
	var result: Array = []
	for ride in parsed["rides"]:
		if ride is Dictionary and valid(ride): result.append(ride)
	return result

func add(distance_m: int, seconds: float, crossings: Array, start_type: String = "standing") -> bool:
	var record := {"id": Crypto.new().generate_random_bytes(12).hex_encode(), "distance_m": distance_m, "start_type": start_type, "seconds": seconds, "finished_at": Time.get_unix_time_from_system(), "splits": crossings.duplicate()}
	if not valid(record): return false
	var rides := all_rides()
	rides.append(record)
	var folder := ProjectSettings.globalize_path(PATH).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": 1, "rides": rides}))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH)) == OK

func references(distance_m: int, now: float = -1.0, start_type: String = "standing") -> Dictionary:
	if now < 0.0: now = Time.get_unix_time_from_system()
	var rides: Array = all_rides().filter(func(r): return int(r["distance_m"]) == distance_m and str(r.get("start_type", "standing")) == start_type and float(r["finished_at"]) <= now)
	rides.sort_custom(func(a, b): return float(a["finished_at"]) > float(b["finished_at"]))
	var result := {"last": {}, "alltime": {}, "recent": {}}
	if rides.is_empty(): return result
	result["last"] = rides[0]
	var by_time := rides.duplicate()
	by_time.sort_custom(func(a, b): return float(a["seconds"]) < float(b["seconds"]))
	result["alltime"] = by_time[0]
	for ride in by_time:
		if float(ride["finished_at"]) >= now - WINDOW_SECONDS:
			result["recent"] = ride
			break
	return result

static func crossing_delta(reference: Dictionary, checkpoint: int, actual_seconds: float) -> Variant:
	var splits: Array = reference.get("splits", [])
	if checkpoint < 1 or checkpoint > splits.size(): return null
	# Positive means slower than reference; negative means ahead.
	return actual_seconds - float(splits[checkpoint - 1])
