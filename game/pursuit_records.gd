extends RefCounted
## Local named attempts. Names never become paths; only completed compatible rides load.
const VERSION := 1
const PHYSICS := "pursuit_v1"
var directory := "user://pursuit_rides"
var event_kind := "individual"
var squad_size := 0

func configure_team(count: int) -> void:
	event_kind = "team"
	squad_size = clampi(count, 3, 4)
	directory = "user://team_pursuit_%d_rides" % squad_size

static func valid(record: Dictionary) -> bool:
	if record.get("version", 0) != VERSION or record.get("physics", "") != PHYSICS:
		return false
	# JSON restores numeric fields as floats; Array membership is type-sensitive.
	var distance = record.get("distance_m")
	if not _number(distance) or (float(distance) != 1000.0 and float(distance) != 4000.0):
		return false
	var time_value = record.get("time_s")
	if not _number(time_value) or time_value <= 0.0 or time_value > 3600.0:
		return false
	if not record.get("name", null) is String or String(record["name"]).strip_edges().is_empty():
		return false
	var samples = record.get("samples")
	if not samples is Array or samples.size() < 2 or samples.size() > 40000:
		return false
	var last_t := -1.0
	var last_d := -1.0
	for sample in samples:
		if not sample is Dictionary:
			return false
		for field in ["t", "d", "p", "lane"]:
			if not _number(sample.get(field)):
				return false
		if sample["t"] <= last_t or sample["d"] < last_d or sample["d"] < 0.0 or sample["d"] > record["distance_m"] + 0.001 or sample["p"] < 0.0 or sample["lane"] < 1.0 or sample["lane"] > 8.0:
			return false
		last_t = sample["t"]
		last_d = sample["d"]
	return absf(samples[0]["t"]) < 0.0001 and absf(samples[0]["d"]) < 0.0001 and absf(last_t - time_value) < 0.0001 and absf(last_d - record["distance_m"]) < 0.001

static func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))

func save(name: String, distance: int, seconds: float, samples: Array[Dictionary], metadata: Dictionary = {}) -> Dictionary:
	var title: String = name.strip_edges().replace("\n", " ").replace("\r", " ").left(48)
	if title.is_empty():
		return {"error": "Geef je rit eerst een naam."}
	var id: String = Crypto.new().generate_random_bytes(12).hex_encode()
	var record := {"version": VERSION, "physics": PHYSICS, "id": id, "name": title, "distance_m": distance, "time_s": seconds, "created_at": Time.get_unix_time_from_system(), "created_local": Time.get_datetime_string_from_system(false, true), "samples": samples.duplicate(true)}
	for key in ["performance_id", "player_name", "finished_at", "finished_local"]:
		if metadata.has(key): record[key] = metadata[key]
	if event_kind == "team":
		record["event"] = "team"
		record["team_size"] = squad_size
		record["team_timing"] = "first_wheel_v1"
	if not valid(record):
		return {"error": "Alleen een volledig afgewerkte achtervolging kan worden bewaard."}
	var absolute: String = ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return {"error": "De map voor opgeslagen ritten kon niet worden gemaakt."}
	var path: String = directory.path_join(id + ".json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"error": "De rit kon niet worden opgeslagen. Probeer opnieuw."}
	file.store_string(JSON.stringify(record))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		return {"error": "Opslaan is niet voltooid. Probeer opnieuw."}
	return {"id": id, "name": title}

func load_ride(id: String) -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{24}$")
	if pattern.search(id) == null:
		return {}
	var file := FileAccess.open(directory.path_join(id + ".json"), FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > 12000000:
		return {}
	var value = JSON.parse_string(file.get_as_text())
	if value is Dictionary and value.get("id", "") == id and valid(value):
		if event_kind == "team":
			if value.get("event", "") != "team" or int(value.get("team_size", 0)) != squad_size:
				return {}
			return first_wheel_record(value)
		elif value.get("event", "") == "team":
			return {}
		return value
	return {}

static func first_wheel_record(record: Dictionary) -> Dictionary:
	# Old team traces recorded both the virtual third position (d) and the head
	# (front). Reconstruct their first-wheel finish in memory; preserve disk files.
	var result: Dictionary = record.duplicate(true)
	if result.is_empty(): return result
	var samples: Array = result.get("samples", [])
	if samples.size() < 2: return result
	var distance: float = float(result.get("distance_m", 0.0))
	if not _number(samples[-1].get("front")) or float(samples[-1]["front"]) <= distance + 0.001: return result
	var converted: Array[Dictionary] = []
	for i in range(samples.size()):
		var sample: Dictionary = samples[i].duplicate(true)
		if not _number(sample.get("front")): return record.duplicate(true)
		var front: float = float(sample["front"])
		if i > 0 and front >= distance:
			var previous: Dictionary = samples[i - 1]
			var fraction: float = clampf((distance - float(previous["front"])) / maxf(0.000001, front - float(previous["front"])), 0.0, 1.0)
			sample["t"] = lerpf(float(previous["t"]), float(sample["t"]), fraction)
			for key in ["p", "lane"]: sample[key] = lerpf(float(previous[key]), float(sample[key]), fraction)
			sample["front"] = distance; sample["d"] = distance
			converted.append(sample)
			result["samples"] = converted
			result["time_s"] = sample["t"]
			result["team_timing"] = "first_wheel_v1"
			return result if valid(result) else record.duplicate(true)
		sample["d"] = maxf(0.0, front)
		converted.append(sample)
	return record.duplicate(true)

func list_rides(distance: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var folder := DirAccess.open(directory)
	if folder == null:
		return result
	for filename in folder.get_files():
		if not filename.ends_with(".json"):
			continue
		var record: Dictionary = load_ride(filename.trim_suffix(".json"))
		if not record.is_empty() and int(record["distance_m"]) == distance:
			result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("created_at", 0.0)) > float(b.get("created_at", 0.0)))
	return result

static func at_time(record: Dictionary, seconds: float) -> Dictionary:
	var samples: Array = record["samples"]
	var time: float = clampf(seconds, 0.0, float(record["time_s"]))
	var low := 0
	var high: int = samples.size() - 1
	while low + 1 < high:
		var middle: int = (low + high) / 2
		if float(samples[middle]["t"]) <= time:
			low = middle
		else:
			high = middle
	var a: Dictionary = samples[low]
	var b: Dictionary = samples[high]
	var dt: float = float(b["t"]) - float(a["t"])
	var mix: float = clampf((time - float(a["t"])) / dt, 0.0, 1.0)
	return {"d": lerpf(float(a["d"]), float(b["d"]), mix), "speed": (float(b["d"]) - float(a["d"])) / dt, "p": lerpf(float(a["p"]), float(b["p"]), mix), "lane": lerpf(float(a["lane"]), float(b["lane"]), mix)}

static func time_at_distance(record: Dictionary, distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var samples: Array = record["samples"]
	var low := 0
	var high: int = samples.size() - 1
	while low + 1 < high:
		var middle: int = (low + high) / 2
		if float(samples[middle]["d"]) < distance:
			low = middle
		else:
			high = middle
	var a: Dictionary = samples[low]
	var b: Dictionary = samples[high]
	var fraction: float = clampf((distance - float(a["d"])) / maxf(0.000001, float(b["d"]) - float(a["d"])), 0.0, 1.0)
	return lerpf(float(a["t"]), float(b["t"]), fraction)

static func average_power(record: Dictionary) -> float:
	var samples: Array = record.get("samples", [])
	var joules := 0.0
	for i in range(1, samples.size()):
		var dt: float = float(samples[i].t) - float(samples[i-1].t)
		joules += maxf(0.0, dt) * (float(samples[i].p) + float(samples[i-1].p)) * 0.5
	return joules / maxf(0.000001, float(record.get("time_s", 0.0)))

static func scaled_replay(record: Dictionary, percent: float) -> Dictionary:
	# Transform an in-memory copy; the saved personal achievement is never edited.
	var result := record.duplicate(true)
	var factor := clampf(percent, 40.0, 120.0) / 100.0
	result["source_time_s"] = float(record.time_s)
	result["playback_percent"] = percent
	if is_equal_approx(factor, 1.0): return result
	result["time_s"] = float(record.time_s) / factor
	for sample in result.samples: sample["t"] = float(sample.t) / factor
	return result
