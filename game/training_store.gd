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
	if result != OK: error = String(TranslationServer.translate("TRAINING_FOLDER_UNAVAILABLE")); return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = String(TranslationServer.translate("TRAINING_SAVE_FAILED")); return false
	file.store_string(JSON.stringify(activity))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: error = String(TranslationServer.translate("TRAINING_WRITE_FAILED")); return false
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if result != OK: error = String(TranslationServer.translate("TRAINING_UPDATE_FAILED")); return false
	return true
func load_activity(id: String) -> Dictionary:
	var path := _path(id)
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("samples") is Array: return {}
	return data
static func activity_time(activity: Dictionary) -> int:
	var timestamp := int(activity.get("started_unix",0))
	if timestamp > 0: return timestamp
	var local := str(activity.get("started_local","")).replace(" ","T")
	return int(Time.get_unix_time_from_datetime_string(local)) if not local.is_empty() else 0

func recent(limit: int = 30, kinds: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(folder)
	if directory == null: return result
	for filename in directory.get_files():
		if not filename.ends_with(".json"): continue
		var activity := load_activity(filename.get_basename())
		if activity.is_empty(): continue
		# Older derny recordings predate the explicit kind field.
		if not kinds.is_empty() and str(activity.get("kind","derny")) not in kinds: continue
		result.append(activity)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first := activity_time(a)
		var second := activity_time(b)
		return first > second if first != second else str(a.get("id","")) > str(b.get("id",""))
	)
	if limit > 0 and result.size() > limit: result.resize(limit)
	return result
static func fit_payload(activity: Dictionary) -> PackedByteArray:
	var samples: Array[Dictionary] = []
	for sample in activity.get("samples", []):
		if sample is Dictionary: samples.append(sample)
	return preload("res://fit_export.gd").build(samples, int(activity.get("started_unix", 0)), false)
