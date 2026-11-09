extends RefCounted
## Local activity archive. Every started session has its own recoverable JSON file.
var folder := "user://training_sessions"
var error := ""
func _path(id: String) -> String:
	if id.is_empty() or id != id.validate_filename() or id.contains(".."): return ""
	return folder.path_join(id + ".json")
func save(activity: Dictionary) -> bool:
	error = ""
	var path := _path(str(activity.get("id", "")))
	if path.is_empty(): error = "Ongeldige trainingsnaam"; return false
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if result != OK: error = "Trainingsmap niet beschikbaar"; return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = "Training kon niet worden opgeslagen"; return false
	file.store_string(JSON.stringify(activity))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: error = "Schrijven van training mislukt"; return false
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if result != OK: error = "Training kon niet worden bijgewerkt"; return false
	return true
func load_activity(id: String) -> Dictionary:
	var path := _path(id)
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("samples") is Array: return {}
	return data
func recent(limit: int = 30) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(folder)
	if directory == null: return result
	var files := directory.get_files()
	files.sort()
	files.reverse()
	for filename in files:
		if not filename.ends_with(".json"): continue
		var activity := load_activity(filename.get_basename())
		if not activity.is_empty(): result.append(activity)
		if result.size() >= limit: break
	return result
static func fit_payload(activity: Dictionary) -> PackedByteArray:
	var samples: Array[Dictionary] = []
	for sample in activity.get("samples", []):
		if sample is Dictionary: samples.append(sample)
	return preload("res://fit_export.gd").build(samples, int(activity.get("started_unix", 0)), false)
