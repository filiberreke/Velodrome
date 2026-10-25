extends RefCounted
## Compact persistent personal Top 10s; independent of optional replay storage.
const Replays := preload("res://pursuit_records.gd")
var path := "user://personal_records.json"
var last_error := ""

static func valid(entry: Dictionary) -> bool:
	for field in ["mode", "distance_m", "team_size"]:
		if not Replays._number(entry.get(field)) or float(entry[field]) != float(int(entry[field])): return false
	if int(entry["mode"]) not in [4, 5] or int(entry["distance_m"]) not in [1000, 4000]: return false
	if int(entry.get("mode", 0)) == 5 and int(entry.get("team_size", 0)) not in [3, 4]: return false
	if int(entry.get("mode", 0)) == 4 and int(entry.get("team_size", 0)) != 0: return false
	if not Replays._number(entry.get("seconds")) or float(entry["seconds"]) <= 0.0 or float(entry["seconds"]) > 3600.0: return false
	if not Replays._number(entry.get("finished_at")) or float(entry["finished_at"]) <= 0.0: return false
	for key in ["id", "player_name", "finished_local"]:
		if not entry.get(key) is String or String(entry[key]).strip_edges().is_empty() or String(entry[key]).length() > 128: return false
	return true

static func bucket(entry: Dictionary) -> String:
	return "%d_%d_%d" % [int(entry["mode"]), int(entry["distance_m"]), int(entry.get("team_size", 0))]

func _read_file(filename: String) -> Variant:
	if not FileAccess.file_exists(filename): return null
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null or file.get_length() > 2000000: return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return null
	var value = parser.data
	if not value is Dictionary or value.get("version", 0) != 1 or not value.get("entries") is Array: return null
	if value["entries"].size() > 60: return null
	for item in value["entries"]:
		if not item is Dictionary or not valid(item): return null
	return value["entries"]

func _read() -> Array:
	last_error = ""
	if not FileAccess.file_exists(path): return []
	var entries = _read_file(path)
	if entries != null: return entries
	entries = _read_file(path + ".bak")
	if entries != null: return entries
	last_error = "Het recordsbestand kon niet worden gelezen. De bestaande bestanden zijn behouden."
	return []

func _write(entries: Array) -> bool:
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		last_error = "De map voor records kon niet worden gemaakt."
		return false
	# Keep the last readable version; never replace it with a corrupt primary.
	if _read_file(path) != null:
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			last_error = "De reservekopie van je records kon niet worden bijgewerkt."
			return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Je records konden niet worden opgeslagen."
		return false
	file.store_string(JSON.stringify({"version": 1, "entries": entries}))
	file.flush()
	var error: Error = file.get_error(); file.close()
	if error != OK or DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		last_error = "Opslaan van je records is niet voltooid."
		return false
	return true

static func _trim(entries: Array) -> Array:
	var seen := {}; var unique: Array = []
	for entry in entries:
		if not seen.has(entry["id"]):
			seen[entry["id"]] = true; unique.append(entry)
	entries = unique
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["seconds"]) != float(b["seconds"]): return float(a["seconds"]) < float(b["seconds"])
		if float(a["finished_at"]) != float(b["finished_at"]): return float(a["finished_at"]) < float(b["finished_at"])
		return str(a["id"]) < str(b["id"]))
	var counts := {}; var ids := {}; var result: Array = []
	for entry in entries:
		var key: String = bucket(entry)
		if ids.has(entry["id"]) or int(counts.get(key, 0)) >= 10: continue
		ids[entry["id"]] = true; counts[key] = int(counts.get(key, 0)) + 1
		result.append(entry)
	return result

func add(entry: Dictionary) -> bool:
	if not valid(entry):
		last_error = "Alleen een volledige achtervolgingsprestatie kan in de records."
		return false
	var entries: Array = _read()
	if not last_error.is_empty(): return false
	var before := JSON.stringify(_trim(entries.duplicate(true)))
	entries.append(entry.duplicate(true))
	entries = _trim(entries)
	if JSON.stringify(entries) == before: return true
	return _write(entries)

func top(mode: int, distance: int, count: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _trim(_read()):
		if int(entry["mode"]) == mode and int(entry["distance_m"]) == distance and int(entry.get("team_size", 0)) == count:
			result.append(entry)
	return result

func import_saved(libraries: Array = []) -> void:
	var sources: Array = libraries
	if sources.is_empty():
		var solo := Replays.new(); sources.append(solo)
		for count in [3, 4]:
			var team := Replays.new(); team.configure_team(count); sources.append(team)
	var entries: Array = _read()
	if not last_error.is_empty(): return
	var before: String = JSON.stringify(_trim(entries.duplicate(true)))
	for source in sources:
		for distance in [1000, 4000]:
			for ride in source.list_rides(distance):
				var stamp: float = float(ride.get("finished_at", ride.get("created_at", 0.0)))
				if not Replays._number(stamp) or stamp <= 0.0: continue
				var legacy: bool = not ride.has("player_name")
				var entry := {"id": str(ride.get("performance_id", "legacy_" + str(ride["id"]))), "mode": 5 if source.event_kind == "team" else 4, "distance_m": distance, "team_size": source.squad_size, "seconds": float(ride["time_s"]), "player_name": str(ride.get("player_name", "Onbekende speler")), "finished_at": stamp, "finished_local": str(ride.get("finished_local", Time.get_datetime_string_from_unix_time(int(stamp)).replace("T", " ") + " UTC")), "legacy": legacy}
				if valid(entry): entries.append(entry)
	entries = _trim(entries)
	if JSON.stringify(entries) != before: _write(entries)
