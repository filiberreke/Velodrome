extends RefCounted
## Immutable FIT files and atomic, independently recoverable upload receipts.
var folder := "user://activities"
var error := ""

func path(id: String, extension: String = "json") -> String:
	if id.is_empty() or id != id.validate_filename() or id.contains(".."): return ""
	return folder.path_join(id + "." + extension)

func load_activity(id: String) -> Dictionary:
	var filename := path(id)
	if filename.is_empty() or (not FileAccess.file_exists(filename) and not FileAccess.file_exists(filename + ".bak")): return {}
	for suffix in ["", ".bak"]:
		if not FileAccess.file_exists(filename + suffix): continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(filename + suffix))
		if data is Dictionary and data.get("version") == 1 and data.get("id") == id:
			if suffix == ".bak" and data.get("status") != "uploaded" and str(data.get("upload_id", "")).is_empty():
				data.status = "uncertain"
				data["submitted_at"] = FileAccess.get_modified_time(filename + suffix)
			return data
	return {}

func save(activity: Dictionary) -> bool:
	error = ""
	var filename := path(str(activity.get("id", "")))
	if filename.is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK: return false
	var file := FileAccess.open(filename + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(activity)); file.flush()
	var result := file.get_error(); file.close()
	if result != OK: return false
	if FileAccess.file_exists(filename):
		var previous := JSON.new()
		if previous.parse(FileAccess.get_file_as_string(filename)) == OK and previous.data is Dictionary:
			if DirAccess.copy_absolute(filename, filename + ".bak") != OK: return false
	return DirAccess.rename_absolute(filename + ".tmp", filename) == OK

func capture(metadata: Dictionary, samples: Array[Dictionary], gps: bool = true) -> Dictionary:
	var id := str(metadata.get("id", ""))
	var existing := load_activity(id)
	if not existing.is_empty(): return existing
	if path(id).is_empty() or samples.size() < 2 or int(metadata.get("started_unix", 0)) <= 0: return {}
	var details := metadata.duplicate(true)
	details["with_gps"] = gps
	if gps and details.get("location", {}).is_empty():
		details["location"] = {"latitude":53.0, "longitude":-30.0, "virtual":true}
	var payload := preload("res://fit_export.gd").build(samples, int(details.started_unix), gps, details.get("location", {}))
	if payload.is_empty(): return {}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK: return {}
	var file := FileAccess.open(path(id, "fit") + ".tmp", FileAccess.WRITE)
	if file == null: return {}
	file.store_buffer(payload); file.flush()
	var result := file.get_error(); file.close()
	if result != OK or DirAccess.rename_absolute(path(id, "fit") + ".tmp", path(id, "fit")) != OK: return {}
	var activity := details
	activity.merge({"version":1, "status":"pending", "upload_id":"", "activity_id":"", "attempts":0, "retry_at":0}, true)
	return activity if save(activity) else {}

func all() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var directory := DirAccess.open(folder)
	if directory == null: return entries
	var seen := {}
	for filename in directory.get_files():
		if filename.ends_with(".json") or filename.ends_with(".json.bak"):
			var id := filename.trim_suffix(".bak").get_basename()
			if seen.has(id): continue
			seen[id] = true
			var entry := load_activity(id)
			if not entry.is_empty(): entries.append(entry)
	entries.sort_custom(func(a, b): return int(a.started_unix) < int(b.started_unix))
	return entries

func export_fit(id: String, destination: String) -> Error:
	if load_activity(id).is_empty() or not FileAccess.file_exists(path(id, "fit")): return ERR_FILE_NOT_FOUND
	return DirAccess.copy_absolute(path(id, "fit"), destination)
